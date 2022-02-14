//
//  MarkupWKWebView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/12/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import WebKit

/// A specialized WKWebView used to support WYSIWYG editing in Swift.
///
/// All init methods invoke setupForEditing, which loads markup.html that in turn loads
/// markup.css and markup.js. All interaction from Swift to the WKWebView comes through
/// this class which knows how to evaluateJavaScript to get things done.
///
/// When some event happens on the JavaScript side, it is handled by the WKScriptMessageHandler,
/// which is the MarkupCoordinator.
///
/// All interaction with JavaScript is asynchronous. So, for example, the WKToolbar might invoke `bold(handler:)`
/// on the selectedWebView. The handler on the call into JavaScript is optional. On the JavaScript side, we run
/// `MU.toggleBold()`. The last thing `toggleBold()` does is invoke `_callback('input')`. This
/// results in `userContentController(_:didReceive)' being invoked in the MarkupCoordinator to
/// let us know something happened on the JavaScript side . In this way, we we maintain up-to-date information
/// as-needed in Swift about what is in the MarkupWKWebView.
public class MarkupWKWebView: WKWebView, ObservableObject {
    static let DefaultInnerLineHeight: Int = 18
    let bodyMargin: Int = 8         // As specified in markup.css. Needed to adjust clientHeight
    public var hasFocus: Bool = false
    private var editorHeight: Int = 0
    /// The HTML that is currently loaded, if it is loaded. If it has not been loaded yet, it is the
    /// HTML that will be loaded once it finishes initializing.
    private var html: String?
    private var resourcesUrl: URL?
    public var id: String = UUID().uuidString
    public var userScripts: [String]? {
        didSet {
            if let userScripts = userScripts {
                for script in userScripts {
                    let wkUserScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                    configuration.userContentController.addUserScript(wkUserScript)
                }
            }
        }
    }
    // Doesn't seem like any way around holding on to markupDelegate here, as forced by drop support
    private var markupDelegate: MarkupDelegate?
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        initForEditing()
    }
    
    public required init?(coder: NSCoder) {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        initForEditing()
    }
    
    public init(html: String? = nil, resourcesUrl: URL? = nil, id: String? = nil, markupDelegate: MarkupDelegate? = nil) {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        self.html = html
        self.resourcesUrl = resourcesUrl
        if id != nil {
            self.id = id!
        }
        self.markupDelegate = markupDelegate
        initForEditing()
    }
    
    /// Set things up properly for editing.
    ///
    /// Setting things up means populating a cache directory with the "root" files: markup.html,
    /// markup.css, and markup.js. In addition, if resourcesUrl is specified, then its contents are copied into
    /// the same relativePath below the cache directory. This means the resourcesUrl generally should
    /// have a baseUrl where the html-being-edited came from. If it resourcesUrl does not have a baseUrl,
    /// then everything in resourcesUrl will be copied into the cache directory along with the "root" files.
    ///
    /// Once all the files are properly set up in the cacheDir, we loadFileURL on the markup.html
    /// which in turn loads the css and js scripts itself. The markup.html defines the "editor" element, which
    /// is later populated with html.
    private func initForEditing() {
        initRootFiles()
        markupDelegate?.markupSetup(self)
        // Enable drop interaction
        let dropInteraction = UIDropInteraction(delegate: self)
        addInteraction(dropInteraction)
        // Load markup.html to kick things off
        let tempRootHtml = cacheUrl().appendingPathComponent("markup.html")
        loadFileURL(tempRootHtml, allowingReadAccessTo: tempRootHtml.deletingLastPathComponent())
        // Resolving the tintColor in this way lets the WKWebView
        // handle dark mode without any explicit settings in css
        tintColor = tintColor.resolvedColor(with: .current)
    }
    
    /// Return the bundle that is appropriate for the packaging.
    func bundle() -> Bundle {
        // If you use the framework as a dependency, the bundle can be identified from
        // the place where MarkupWKWebView is found. If you use the Swift package as a
        // dependency, it does some BundleFinder hocus pocus behind the scenes to allow
        // Bundle to respond to module.
        #if SWIFT_PACKAGE
        return Bundle.module
        #else
        return Bundle(for: MarkupWKWebView.self)
        #endif
    }
    
    /// Initialize the directory at cacheUrl with a clean copy of the root resource files. 
    ///
    /// Any failure to find or copy the root resource files results in an assertion failure, since no editing is possible.
    private func initRootFiles() {
        let bundle = bundle()
        guard
            let rootHtml = bundle.url(forResource: "markup", withExtension: "html"),
            let rootCss = bundle.url(forResource: "markup", withExtension: "css"),
            let rootJs = bundle.url(forResource: "markup", withExtension: "js") else {
                assertionFailure("Could not find markup.html, css, and js for this bundle.")
                return
            }
        let fileManager = FileManager.default
        // The cacheDir is a "id" subdirectory below the app's cache directory
        // If not supplied, then id will be a UUID().uuidString
        let cacheUrl = cacheUrl()
        let cacheUrlPath = cacheUrl.path
        do {
            try fileManager.createDirectory(atPath: cacheUrlPath, withIntermediateDirectories: true, attributes: nil)
            for srcUrl in [rootHtml, rootCss, rootJs] {
                let dstUrl = cacheUrl.appendingPathComponent(srcUrl.lastPathComponent)
                try? fileManager.removeItem(at: dstUrl)
                try fileManager.copyItem(at: srcUrl, to: dstUrl)
            }
        } catch let error {
            assertionFailure("Failed to set up cacheDir with root resource files: \(error.localizedDescription)")
        }
    }
    
    /// Populate the resources as copied from resourcesUrl.
    ///
    /// The markupDelegate invokes this method by default in markupSetup(). To customize population of the cacheUrl, override in markupSetup() in
    /// the markupDelegate. Otherwise, the default behavior is to copy everything from resourcesUrl into the same relativePath below the cacheUrl.
    public func setup() {
        // Copy the content of resourcesUrl into the relativePath below cacheUrl or to cacheUrl itself.
        // While failing to set up the root files properly results in an assertion failure, failing
        // to get the files at resourceUrl copied properly is silent.
        guard let resourcesUrl = resourcesUrl else {
            return
        }
        let fileManager = FileManager.default
        let cacheUrl = cacheUrl()
        var tempResourcesUrl: URL
        if resourcesUrl.baseURL == nil {
            tempResourcesUrl = cacheUrl
        } else {
            tempResourcesUrl = cacheUrl.appendingPathComponent(resourcesUrl.relativePath)
        }
        let tempResourcesUrlPath = tempResourcesUrl.path
        do {
            try fileManager.createDirectory(atPath: tempResourcesUrlPath, withIntermediateDirectories: true, attributes: nil)
            // If we specify the resourceUrl but there are no resources, it's not an error
            let resources = (try? fileManager.contentsOfDirectory(at: resourcesUrl, includingPropertiesForKeys: nil, options: [])) ?? []
            for srcUrl in resources {
                let dstUrl = tempResourcesUrl.appendingPathComponent(srcUrl.lastPathComponent)
                try? fileManager.removeItem(at: dstUrl)
                try fileManager.copyItem(at: srcUrl, to: dstUrl)
            }
            
        } catch let error {
            print("Failure copying resource files: \(error.localizedDescription)")
        }
    }
    
    /// Tear down what we set up to use the MarkupEditor.
    ///
    /// By default, we remove everything at cacheUrl. Fail silently if there is a problem.
    public func teardown() {
        try? FileManager.default.removeItem(atPath: cacheUrl().path)
    }
    
    /// Return the URL for an "id" subdirectory below the app's cache directory
    private func cacheUrl() -> URL {
        let cacheUrls = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
        return cacheUrls[0].appendingPathComponent(id)
    }
    
    public func loadInitialHtml() {
        setHtml(html ?? "") {
            if let delegate = self.markupDelegate {
                delegate.markupDidLoad(self) {
                    self.becomeFirstResponder()
                }
            } else {
                self.becomeFirstResponder()
            }
        }
    }
    
    //MARK: Overrides
    
    /// Override hitTest to enable drop events.
    ///
    /// The view receives UIDragEvents, which appear to be a private type of
    /// UIEvent.EventType. When the hitTest responds normally to these events,
    /// they return the MarkupWKWebView instance, which never receives the
    /// sessionDidUpdate or performDrop message, even though it does respond
    /// that it canHandle the drop. This just seems to be a bug. The solution is to
    /// handle "normal" drag events in the parent view, which is a WKWebView, and
    /// handle the UIDragEvent in MarkupWKWebView.
    ///
    /// To avoid accessing a private event type directly, we check for all publicly
    /// identifiable events first, letting the superclass handle them. The default case
    /// captures everything else (which AFAICT is only UIDragEvent), and just returns
    /// self (this instance of MarkupWKWebView). The end result is that we see the
    /// drop here.
    ///
    /// Not sure if this hack will survive over the long run. It would be better
    /// if there was a way to tell if the event.type was part of the public
    /// UIEvent.EventType enum, but this doesn't seem to be possible.
    open override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        guard let event = event else { return nil }
        switch event.type {
        case .hover, .motion, .presses, .remoteControl, .scroll, .touches, .transform:
            // Let the superclass handle all the publicly recognized event types
            //if event.type != .hover { // Else mouse movement over the view produces a zillion hover prints
            //    print("Letting WKWebView handle: \(event.description)")
            //}
            return super.hitTest(point, with: event)
        default:
            // We will handle the UIDragEvent ourselves
            //print("MarkupWKWebView handling: \(event.description)")
            return self
        }
    }
    
    //MARK: Responder Handling
    
    public override var canBecomeFirstResponder: Bool {
        return hasFocus
    }
    
    public override var canResignFirstResponder: Bool {
        return !hasFocus
    }
    
    //MARK: Testing support
    
    public func setTestHtml(value: String, handler: (() -> Void)? = nil) {
        evaluateJavaScript("MU.setHTML('\(value.escaped)')") { result, error in handler?() }
    }
    
    public func setTestRange(startId: String, startOffset: Int, endId: String, endOffset: Int, handler: @escaping (Bool) -> Void) {
        evaluateJavaScript("MU.setRange('\(startId)', '\(startOffset)', '\(endId)', '\(endOffset)')") { result, error in
            handler(result as? Bool ?? false)
        }
    }
    
    public func testUndo(handler: (()->Void)? = nil) {
        // Invoke the _undoOperation directly, but delay to allow
        // the async operation being undone to have completed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.evaluateJavaScript("MU.testUndo()") { result, error in handler?() }
        }
    }
    
    public func testRedo(handler: (()->Void)? = nil) {
        // Invoke the _redoOperation directly, but delay to allow
        // the async operation being undone to have completed.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.evaluateJavaScript("MU.testRedo()") { result, error in handler?() }
        }
    }
    
    //MARK: Javascript interactions
    
    public func setLineHeight(_ lineHeight: Int? = nil) {
        evaluateJavaScript("MU.setLineHeight('\(lineHeight ?? Self.DefaultInnerLineHeight)px')")
    }
    
    public func getHtml(_ handler: ((String?)->Void)?) {
        evaluateJavaScript("MU.getHTML()") { result, error in
            handler?(result as? String)
        }
    }
    
    public func getPrettyHtml(_ handler: ((String?)->Void)?) {
        evaluateJavaScript("MU.getPrettyHTML()") { result, error in
            handler?(result as? String)
        }
    }
    
//    public func getMarkdown(_ handler: ((String?)->Void)?) {
//        evaluateJavaScript("MU.getMarkdown()") { result, error in
//            handler?(result as? String)
//        }
//    }
//
//    public func getRoundTrip(_ handler: ((String?)->Void)?) {
//        evaluateJavaScript("MU.getRoundTrip()") { result, error in
//            handler?(result as? String)
//        }
//    }
    
    public func emptyDocument(handler: (()->Void)?) {
        evaluateJavaScript("MU.emptyDocument()") { result, error in
            handler?()
        }
    }
    
    public func setHtml(_ html: String, handler: (()->Void)? = nil) {
        self.html = html    // Our local record of what we set, used by setHtmlIfChanged
        evaluateJavaScript("MU.setHTML('\(html.escaped)')") { result, error in
            handler?()
        }
    }
    
    public func setHtmlIfChanged(_ html: String, handler: (()->Void)? = nil) {
        if html != self.html {
            setHtml(html, handler: handler)
        } else {
            handler?()
        }
    }
    
    public func updateHeight(handler: ((Int)->Void)?) {
        getClientHeight() { clientHeight in
            if self.editorHeight != clientHeight {
                self.editorHeight = clientHeight
                handler?(self.contentHeight(from: clientHeight))
            }
        }
    }
    
    public func cleanUpHtml(handler: ((Error?)->Void)?) {
        evaluateJavaScript("MU.cleanUpHTML()") { result, error in
            handler?(error)
        }
    }
    
    public func insertLink(_ href: String?, handler: (()->Void)? = nil) {
        if href == nil {
            evaluateJavaScript("MU.deleteLink()") { result, error in handler?() }
        } else {
            evaluateJavaScript("MU.insertLink('\(href!.escaped)')") { result, error in handler?() }
        }
    }
    
    public func insertImage(src: String?, alt: String?, handler: (()->Void)? = nil) {
        if src == nil {
            modifyImage(src: nil, alt: nil, scale: nil, handler: handler)
        } else {
            var args = "'\(src!.escaped)'"
            if alt != nil {
                args += ", '\(alt!.escaped)'"
            }
            evaluateJavaScript("MU.insertImage(\(args))") { result, error in handler?() }
        }
    }
    
    public func insertLocalImage(url: URL, handler: (()->Void)? = nil) {
        // TODO: Use extended attributes for alt text if available
        // (see https://stackoverflow.com/a/38343753/8968411)
        // Make a new unique ID for the image to save in the cacheUrl directory
        let path = "\(UUID().uuidString).\(url.pathExtension)"
        var baseResourceUrl: URL
        var relativeSrc: String
        //if let resourcesUrl = resourcesUrl {
        //    baseResourceUrl = URL(fileURLWithPath: resourcesUrl.relativePath, relativeTo: cacheUrl())
        //    relativeSrc = baseResourceUrl.appendingPathComponent(path).relativePath
        //} else {
            baseResourceUrl = cacheUrl()
            relativeSrc = path
        //}
        let cachedImageUrl = URL(fileURLWithPath: path, relativeTo: baseResourceUrl)
        do {
            try FileManager.default.copyItem(at: url, to: cachedImageUrl)
            insertImage(src: relativeSrc, alt: nil) {
                self.markupDelegate?.markupImageAdded(url: cachedImageUrl)
                handler?()
            }
        } catch let error {
            print("Error inserting local image: \(error.localizedDescription)")
            handler?()
        }
    }
    
    private func getClientHeight(_ handler: @escaping ((Int)->Void)) {
        evaluateJavaScript("document.getElementById('editor').clientHeight") { result, error in
            handler(result as? Int ?? 0)
        }
    }
    
    //MARK: Undo/redo
    
    public func undo(handler: (()->Void)? = nil) {
        // Invoke the undo function from the undo button, same as occurs with Command-S.
        // Note that this operation interleaves the browser-native undo (e.g., undoing typing)
        // with the _undoOperation implemented in markup.js.
        evaluateJavaScript("MU.undo()") { result, error in handler?() }
    }
    
    public func redo(handler: (()->Void)? = nil) {
        // Invoke the undo function from the undo button, same as occurs with Command-Shift-S.
        // Note that this operation interleaves the browser-native redo (e.g., redoing typing)
        // with the _redoOperation implemented in markup.js.
        evaluateJavaScript("MU.redo()") { result, error in handler?() }
    }
    
    //MARK: Table editing
    
    public func nextCell(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.nextCell()") { result, error in handler?() }
    }
    
    public func prevCell(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.prevCell()") { result, error in handler?() }
    }
    
    public func insertTable(rows: Int, cols: Int, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.insertTable(\(rows), \(cols))") { result, error in handler?() }
    }
    
    public func addRow(_ direction: TableDirection, handler: (()->Void)? = nil) {
        switch direction {
        case .before:
            evaluateJavaScript("MU.addRow('BEFORE')") { result, error in handler?() }
        case .after:
            evaluateJavaScript("MU.addRow('AFTER')") { result, error in handler?() }
        }
    }
    
    public func deleteRow(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.deleteRow()") { result, error in handler?() }
    }
    
    public func addCol(_ direction: TableDirection, handler: (()->Void)? = nil) {
        switch direction {
        case .before:
            evaluateJavaScript("MU.addCol('BEFORE')") { result, error in handler?() }
        case .after:
            evaluateJavaScript("MU.addCol('AFTER')") { result, error in handler?() }
        }
    }
    
    public func deleteCol(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.deleteCol()") { result, error in handler?() }
    }
    
    public func addHeader(colspan: Bool = true, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.addHeader(\(colspan))") { result, error in handler?() }
    }
    
    public func deleteTable(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.deleteTable()") { result, error in handler?() }
    }
    
    //MARK: Image editing
    
    public func modifyImage(src: String?, alt: String?, scale: Int?, handler: (()->Void)?) {
        // If src is nil, then no arguments are passed and the image will be removed
        // Otherwise, the src, alt, and scale will be applied to the selected image
        // (or removed if alt or scale are nil)
        var args = ""
        if let src = src {
            args += "'\(src)'"
            if let alt = alt {
                args += ", '\(alt)'"
            } else {
                args += ", null"
            }
            if let scale = scale {
                args += ", \(scale)"
            } else {
                args += ", null"
            }
        }
        evaluateJavaScript("MU.modifyImage(\(args))") { result, error in
            handler?()
        }
    }
    
    //MARK: Autosizing
    
    public func setHtmlAndHeight(_ html: String, handler: ((Int) -> Void)? = nil) {
        evaluateJavaScript("MU.setHtml('\(html.escaped)')") { result, error in
            self.getClientHeight() { clientHeight in
                // Note that clientHeight does not reflect css-specified body margin
                // which is present at top and bottom in addition to clientHeight
                handler?(self.contentHeight(from: clientHeight))
            }
        }
    }
    
    private func contentHeight(from clientHeight: Int) -> Int {
        return clientHeight + 2 * bodyMargin
    }
    
    //MARK: Formatting
    
    public func bold(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleBold()") { result, error in
            handler?()
        }
    }
    
    public func italic(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleItalic()") { result, error in
            handler?()
        }
    }
    
    public func underline(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleUnderline()") { result, error in
            handler?()
        }
    }
    
    public func code(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleCode()") { result, error in
            handler?()
        }
    }

    public func strike(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleStrike()") { result, error in
            handler?()
        }
    }
    
    public func subscriptText(handler: (()->Void)? = nil) {      // "superscript" is a keyword
        evaluateJavaScript("MU.toggleSubscript()") { result, error in
            handler?()
        }
    }
    
    public func superscript(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleSuperscript()") { result, error in
            handler?()
        }
    }
    
    //MARK: Selection state
    
    public func getSelectionState(handler: ((SelectionState)->Void)? = nil) {
        evaluateJavaScript("MU.getSelectionState()") { result, error in
            var selectionState = SelectionState()
            guard error == nil, let stateString = result as? String else {
                handler?(selectionState)
                return
            }
            if !stateString.isEmpty {
                if let data = stateString.data(using: .utf8) {
                    do {
                        let state = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                        selectionState = self.selectionState(from: state)
                    } catch let error {
                        print("Error decoding selectionState data: \(error.localizedDescription)")
                    }
                }
            }
            handler?(selectionState)
        }
    }
    
    private func selectionState(from state: [String : Any]?) -> SelectionState {
        let selectionState = SelectionState()
        guard let state = state else {
            print("State decoded from JSON was nil")
            return selectionState
        }
        // Selected text
        if let selectedText = state["selection"] as? String {
            selectionState.selection = selectedText.isEmpty ? nil : selectedText
        } else {
            selectionState.selection = nil
        }
        // Links
        selectionState.href = state["href"] as? String
        selectionState.link = state["link"] as? String
        // Images
        selectionState.src = state["src"] as? String
        selectionState.alt = state["alt"] as? String
        selectionState.scale = state["scale"] as? Int
        selectionState.frame = rectFromFrame(state["frame"] as? [String : CGFloat])
        // Tables
        selectionState.table = state["table"] as? Bool ?? false
        selectionState.thead = state["thead"] as? Bool ?? false
        selectionState.tbody = state["tbody"] as? Bool ?? false
        selectionState.header = state["header"] as? Bool ?? false
        selectionState.colspan = state["colspan"] as? Bool ?? false
        selectionState.rows = state["rows"] as? Int ?? 0
        selectionState.cols = state["cols"] as? Int ?? 0
        selectionState.row = state["row"] as? Int ?? 0
        selectionState.col = state["col"] as? Int ?? 0
        // Styles
        if let tag = state["style"] as? String {
            selectionState.style = StyleContext.with(tag: tag)
        } else {
            selectionState.style = StyleContext.Undefined
        }
        if let tag = state["list"] as? String {
            selectionState.list = ListContext.with(tag: tag)
        } else {
            selectionState.list = ListContext.Undefined
        }
        selectionState.li = state["li"] as? Bool ?? false
        selectionState.quote = state["quote"] as? Bool ?? false
        // Formats
        selectionState.bold = state["bold"] as? Bool ?? false
        selectionState.italic = state["italic"] as? Bool ?? false
        selectionState.underline = state["underline"] as? Bool ?? false
        selectionState.strike = state["strike"] as? Bool ?? false
        selectionState.sub = state["sub"] as? Bool ?? false
        selectionState.sup = state["sup"] as? Bool ?? false
        selectionState.code = state["code"] as? Bool ?? false
        return selectionState
    }
    
    private func rectFromFrame(_ frameDict: [String : CGFloat]?) -> CGRect? {
        guard let frameDict = frameDict else { return nil }
        guard
            let x = frameDict["x"],
            let y = frameDict["y"],
            let width = frameDict["width"],
            let height = frameDict["height"] else { return nil }
            return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
    
    //MARK: Styling
    
    /// Replace the existing style of the selection with the new style (e.g., from <p> to <h3>)
    public func replaceStyle(in selectionState: SelectionState, with newStyle: StyleContext, handler: (()->Void)? = nil) {
        let oldStyle = selectionState.style
        guard newStyle != oldStyle else {
            handler?()
            return
        }
        evaluateJavaScript("MU.replaceStyle('\(oldStyle)', '\(newStyle)')") { result, error in
            handler?()
        }
    }
    
    /// Indent the selection based on the context.
    ///
    /// If in a list, move list item to the next nested level if appropriate.
    /// Otherwise, increase the quote level by inserting a new blockquote.
    public func indent(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.indent()") { result, error in
            handler?()
        }
    }
    
    /// Outdent the selection based on the context.
    ///
    /// If in a list, move list item to the previous nested level if appropriate.
    /// Otherwise, decrease the quote level by removing a blockquote if one exists.
    public func outdent(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.outdent()") { result, error in
            handler?()
        }
    }
    
    /// Switch between ordered and unordered list styles.
    public func toggleListItem(type: ListContext, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleListItem('\(type.tag)')") { result, error in
            handler?()
        }
    }
    
}

//MARK: UIResponderStandardEditActions overrides

extension MarkupWKWebView {
    
    /// Replace standard action with the MarkupWKWebView implementation.
    public override func toggleBoldface(_ sender: Any?) {
        bold()
    }
    
    /// Replace standard action with the MarkupWKWebView implementation.
    public override func toggleItalics(_ sender: Any?) {
        italic()
    }
    
    /// Replace standard action with the MarkupWKWebView implementation.
    public override func toggleUnderline(_ sender: Any?) {
        underline()
    }
    
    /// Replace standard action with the MarkupWKWebView implementation.
    public override func increaseSize(_ sender: Any?) {
        // Do nothing
    }
    
    /// Replace standard action with the MarkupWKWebView implementation.
    public override func decreaseSize(_ sender: Any?) {
        // Do nothing
    }
    
}

//MARK: Drop support

extension MarkupWKWebView: UIDropInteractionDelegate {
    
    /// Delegate the handling decision for DropInteraction to the markupDelegate.
    public func dropInteraction(_ interaction: UIDropInteraction, canHandle session: UIDropSession) -> Bool {
        markupDelegate?.markupDropInteraction(interaction, canHandle: session) ?? false
    }
    
    /// Delegate the type of DropProposal to the markupDelegate, or return .copy by default.
    public func dropInteraction(_ interaction: UIDropInteraction, sessionDidUpdate session: UIDropSession) -> UIDropProposal {
        markupDelegate?.markupDropInteraction(interaction, sessionDidUpdate: session) ?? UIDropProposal(operation: .copy)
    }
    
    /// Delegate the actual drop action to the markupDelegate.
    public func dropInteraction(_ interaction: UIDropInteraction, performDrop session: UIDropSession) {
        markupDelegate?.markupDropInteraction(interaction, performDrop: session)
    }
    
}

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
/// result in `userContentController(_:didReceive)' to be invoked in the MarkupCoordinator to
/// let us know something happened on the JavaScript side that requires us to get the html from the
/// MarkupWKWebView so we maintain up-to-date information in Swift about what is in the MarkupWKWebView.
public class MarkupWKWebView: WKWebView, ObservableObject {
    static let DefaultInnerLineHeight: Int = 18
    let bodyMargin: Int = 8         // As specified in markup.css. Needed to adjust clientHeight
    public var hasFocus: Bool = false
    private var editorHeight: Int = 0
    /// The HTML that is currently loaded, if it is loaded. If it has not been loaded yet, it is the
    /// HTML that will be loaded once it finishes initializing.
    public var html: String?
    
    public init() {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        setupForEditing()
    }
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        setupForEditing()
    }
    
    public required init?(coder: NSCoder) {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        setupForEditing()
    }
    
    private func setupForEditing() {
        // The markup.html loads the css and js scripts itself
        // The MarkupEditor.framework is built with USEFRAMEWORK in its build settings.
        // If you use the framework as a dependency, the bundle can be identified from
        // the place where MarkupWKWebView is found. If you use the Swift package as a
        // dependency, it does some BundleFinder hocus pocus behind the scenes to allow
        // Bundle to respond to module. Unfortunately, you cannot even compile
        // "Bundle.module" without the package as a dependency, so I am forced into this
        // build time hackery.
        var bundle: Bundle
        #if USEFRAMEWORK
        bundle = Bundle(for: MarkupWKWebView.self)
        #else
        bundle = Bundle.module
        #endif
        if let filePath = bundle.path(forResource: "markup", ofType: "html") {
            let url = URL(fileURLWithPath: filePath, isDirectory: false)
            loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        // Resolving the tintColor in this way lets the WKWebView
        // handle dark mode without any explicit settings in css
        tintColor = tintColor.resolvedColor(with: .current)
    }
    
    //public override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    //    guard let event = event else { return nil }
    //    switch event.type {
    //    case .touches:
    //        print("WKWebView was hit with: \(event.description)")
    //        return super.hitTest(point, with: event)
    //    default:
    //        return super.hitTest(point, with: event)
    //    }
    //}
    
    //MARK:- Responder Handling
    
    //@discardableResult override public func becomeFirstResponder() -> Bool {
    //    print(">becomeFirstResponder")
    //    if canBecomeFirstResponder {
    //        return super.becomeFirstResponder()
    //    } else {
    //        return false
    //    }
    //}
    
    public override var canBecomeFirstResponder: Bool {
        return hasFocus
    }
    
    public override var canResignFirstResponder: Bool {
        return !hasFocus
    }
    
    //MARK:- Testing support
    
    public func setTestHtml(value: String, handler: (() -> Void)? = nil) {
        evaluateJavaScript("MU.setHTML('\(value.escaped)')") { result, error in
            handler?()
        }
    }
    
    public func setTestRange(startId: String, startOffset: Int, endId: String, endOffset: Int, handler: @escaping (Bool) -> Void) {
        evaluateJavaScript("MU.setRange('\(startId)', '\(startOffset)', '\(endId)', '\(endOffset)')") { result, error in
            handler(result as? Bool ?? false)
        }
    }
    
    //MARK:- Javascript interactions
    
    public func setLineHeight(_ lineHeight: Int? = nil) {
        evaluateJavaScript("MU.setLineHeight('\(lineHeight ?? Self.DefaultInnerLineHeight)px')")
    }
    
    //public func initializeRange() {
    //    evaluateJavaScript("MU.initializeRange()")
    //}
    
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
    
    public func setHtml(_ html: String, handler: ((String)->Void)? = nil) {
        let contents = html.escaped
        evaluateJavaScript("MU.setHTML('\(contents)')") { result, error in
            guard error == nil else { return }
            handler?(contents)
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
    
    //TODO:- Remove this call as it really should be internal to markup.js
    public func backupRange(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.backupRange()") { result, error in
            handler?()
        }
    }
    
    public func restoreRange(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.restoreRange()") { result, error in
            handler?()
        }
    }
    
    public func insertLink(_ href: String?, handler: (()->Void)? = nil) {
        if href == nil {
            evaluateJavaScript("MU.removeLink()") { result, error in handler?() }
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
    
    private func getClientHeight(_ handler: @escaping ((Int)->Void)) {
        evaluateJavaScript("document.getElementById('editor').clientHeight") { result, error in
            handler(result as? Int ?? 0)
        }
    }
    
    //MARK:- Table editing
    
    public enum TableDirection {
        case before
        case after
    }
    
    public func insertTable(rows: Int, cols: Int, hander: (()->Void)? = nil) {
        evaluateJavaScript("MU.insertTable(\(rows), \(cols))") { result, error in hander?() }
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
    
    public func addHeader(colspan: Bool = false, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.addHeader(\(colspan))") { result, error in handler?() }
    }
    
    //MARK:- Image editing
    
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
    
    //MARK:- Autosizing
    
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
    
    //MARK:- Formatting
    
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
    
    //MARK:- Selection state
    
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
    
    //MARK:- Styling
    
    public func replaceStyle(in selectionState: SelectionState, with newStyle: StyleContext, handler: (()->Void)? = nil) {
        let oldStyle = selectionState.style
        guard newStyle != oldStyle else { return }
        evaluateJavaScript("MU.replaceStyle('\(oldStyle)', '\(newStyle)')") { result, error in
            handler?()
        }
    }
    
    public func replaceList(in selectionState: SelectionState, with newList: ListContext, handler: (()->Void)? = nil) {
        let oldList = selectionState.list
        guard newList != oldList else { return }
        // We want to pass empty string as the argument into Javascript if .Undefined
        let oldOrEmpty = oldList == .Undefined ? "" : oldList.tag
        let newOrEmpty = newList == .Undefined ? "" : newList.tag
        evaluateJavaScript("MU.replaceList('\(oldOrEmpty)', '\(newOrEmpty)')") { result, error in
            handler?()
        }
    }
    
    public func toggleListItem(type: ListContext, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.toggleListItem('\(type.tag)')") { result, error in
            handler?()
        }
    }
    
    public func increaseQuoteLevel(_ handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.increaseQuoteLevel()") { result, error in
            handler?()
        }
    }
    
    public func decreaseQuoteLevel(_ handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.decreaseQuoteLevel()") { result, error in
            handler?()
        }
    }
    
}


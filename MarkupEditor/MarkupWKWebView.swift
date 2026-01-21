//
//  MarkupWKWebView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/12/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import WebKit
import Combine
import OSLog
import UniformTypeIdentifiers

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

/// A specialized WKWebView used to support WYSIWYG editing in Swift.
///
/// All init methods invoke setupForEditing, which loads markup.html that in turn loads
/// markup.css and markup.js. All interaction from Swift to the WKWebView comes through
/// this class which knows how to executeJavaScript to get things done.
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
///
/// The MarkupWKWebView does the keyboard handling that presents the MarkupToolbarUIView using inputAccessoryView.
/// By default, the MarkupEditor.toolbarPosition is set to .top for all but phone, but we still need a way to dismiss the keyboard
/// on devices that have no keyboard or menu access. Thus, by default, the inputAccessoryView has the MarkupToolbar.shared,
/// plus the hide keyboard button.
///
/// If you have your own inputAccessoryView, then you must set MarkupEditor.toolbarPosition to .none and deal with
/// everything yourself.
public class MarkupWKWebView: WKWebView, ObservableObject {
    public typealias TableBorder = MarkupEditor.TableBorder
    public typealias TableDirection = MarkupEditor.TableDirection
    public typealias FindDirection = MarkupEditor.FindDirection
    private let selectionState = SelectionState()       // Locally cached, specific to this view
    public var clientHeightPad: Int = 8                 // Value to adjust html clientHeight
    public private(set) var isReady: Bool = false       // Ready for editing
    public var hasFocus: Bool = false
    /// The HTML that is currently loaded, if it is loaded. If it has not been loaded yet, it is the
    /// HTML that will be loaded once it finishes initializing.
    private var html: String?
    private var placeholder: String?            // A string to show when html is nil or empty
    public var selectAfterLoad: Bool = true     // Whether to set the selection after loading html
    public var baseUrl: URL { cacheUrl() }      // The working directory for this WKWebView, where markup.html etc are loaded-from
    private var resourcesUrl: URL?
    public var id: String = UUID().uuidString
    /// User scripts that are injected at the end of document.
    public var userScripts: [String]? {
        didSet {
            if let userScripts {
                configuration.userContentController.removeAllUserScripts()
                for script in userScripts {
                    let wkUserScript = WKUserScript(source: script, injectionTime: .atDocumentEnd, forMainFrameOnly: true)
                    configuration.userContentController.addUserScript(wkUserScript)
                }
            }
        }
    }
    public var markupConfiguration: MarkupWKWebViewConfiguration?
    /// A js file provided by the user, loaded when this view `isReady` but before `loadInitialHtml`.
    ///
    /// The file should be included as a resource of the app that consumes the MarkupEditor. The file
    /// specified here is independent of the userScripts strings. Either, both, or none can be specified.
    private var userScriptFile: String? { markupConfiguration?.userScriptFile }
    /// A css file provided by the user, loaded when this view `isReady` but before `loadInitialHtml`.
    ///
    /// The file should be included as a resource of the app that consumes the MarkupEditor.
    private var userCssFile: String? { markupConfiguration?.userCssFile }
    // Doesn't seem like any way around holding on to markupDelegate here, as forced by drop support
    private var markupDelegate: MarkupDelegate?
    /// Track whether a paste action has been invoked so as to avoid double-invocation per https://developer.apple.com/forums/thread/696525
    var pastedAsync = false

    #if canImport(UIKit)
    /// An accessoryView to override the inputAccessoryView of UIResponder.
    public var accessoryView: UIView? {
        didSet {
            guard let accessoryView else {
                // Remove height constraints and notification observers if accessoryView was set to nil
                markupToolbarHeightConstraint = nil
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardWillShowNotification, object: nil)
                NotificationCenter.default.removeObserver(self, name: UIResponder.keyboardDidHideNotification, object: nil)
                return
            }
            markupToolbarHeightConstraint = NSLayoutConstraint(item: accessoryView, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .height, multiplier: 1, constant: 0)
            markupToolbarHeightConstraint.isActive = true
            // Use the keyboard notifications to resize the markupToolbar as the accessoryView
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow), name: UIResponder.keyboardWillShowNotification, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(keyboardDidHide), name: UIResponder.keyboardDidHideNotification, object: nil)
        }
    }
    #else
    public var accessoryView: PlatformView? = nil
    #endif

    private var oldContentOffset: CGPoint?

    #if canImport(UIKit)
    private var markupToolbarHeightConstraint: NSLayoutConstraint!
    #else
    private var markupToolbarHeightConstraint: NSLayoutConstraint? = nil
    #endif
    private var firstResponder: AnyCancellable?
    
    /// Types of content that can be pasted in a MarkupWKWebView
    public enum PasteableType {
        case Text
        case Html
        case Rtf
        case ExternalImage
        case LocalImage
        case Url
    }
    
    public override init(frame: CGRect, configuration: WKWebViewConfiguration) {
        super.init(frame: frame, configuration: configuration)
        initForEditing()
    }
    
    public required init?(coder: NSCoder) {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        initForEditing()
    }
    
    public init(html: String? = nil, placeholder: String? = nil, selectAfterLoad: Bool = true, resourcesUrl: URL? = nil, id: String? = nil, markupDelegate: MarkupDelegate? = nil, configuration: MarkupWKWebViewConfiguration? = nil) {
        super.init(frame: CGRect.zero, configuration: WKWebViewConfiguration())
        self.html = html
        self.placeholder = placeholder
        self.selectAfterLoad = selectAfterLoad
        self.resourcesUrl = resourcesUrl
        if id != nil {
            self.id = id!
        }
        self.markupDelegate = markupDelegate
        // If configuration arrives as nil, set it to the default.
        // This way the setTopLevelAttributes will set editor to be contenteditable.
        markupConfiguration = configuration ?? MarkupWKWebViewConfiguration()
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
        #if canImport(UIKit)
        isOpaque = false                        // Eliminate flash in dark mode
        backgroundColor = .systemBackground     // Eliminate flash in dark mode
        #endif
        initRootFiles()
        markupDelegate?.markupSetup(self)
        // Enable drop interaction
        //let dropInteraction = UIDropInteraction(delegate: self)
        //addInteraction(dropInteraction)
        // Load markup.html to kick things off
        let tempRootHtml = cacheUrl().appendingPathComponent("markup.html")
        loadFileURL(tempRootHtml, allowingReadAccessTo: tempRootHtml.deletingLastPathComponent())
        #if canImport(UIKit)
        // Resolving the tintColor in this way lets the WKWebView
        // handle dark mode without any explicit settings in css
        tintColor = tintColor.resolvedColor(with: .current)
        // Set up the accessoryView to be a MarkupToolbarUIView only if toolbarLocation == .keyboard
        if MarkupEditor.toolbarLocation == .keyboard {
            inputAccessoryView = MarkupToolbarUIView.inputAccessory(markupDelegate: markupDelegate)
        }
        #endif
        observeFirstResponder()
    }
    
    /// Monitor the setting for MarkupEditor.observedFirstResponder, and set this MarkupWKWebView to be the first responder
    /// when the id matches.
    ///
    /// Becoming the first reponder also means that focus and selection state are set properly.
    private func observeFirstResponder() {
        firstResponder = MarkupEditor.observedFirstResponder.$id.sink { [weak self] selectedId in
            guard let selectedId, let self, self.id == selectedId else {
                return
            }
            self.becomeFirstResponderIfReady()
        }
    }
    
    public func setCoordinatorConfiguration(_ coordinator: MarkupCoordinator) {
        configuration.userContentController.add(coordinator, name: "markup")
        // The following are needed for the web component to load as a module.
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        configuration.setValue(true, forKey: "allowUniversalAccessFromFileURLs")
    }
    
    /// Have this MarkupWKWebView becomeFirstResponder if loadInitialHtml has been called after the coordinator sees "ready" callback.
    ///
    /// If we can becomeFirstResponder, then we let MarkupEditor know this is the selectedWebView,
    /// and we set the selection, focusing first if necessary.
    public func becomeFirstResponderIfReady() {
        guard isReady else { return }
        if becomeFirstResponder() {
            MarkupEditor.selectedWebView = self
            //Logger.webView.debug("*** Became first responder \(id)")
            if !hasFocus {     // Do nothing if we are already focused
                focus {        // Else focus and setSelection properly
                    self.setSelection()
                }
            } else {
                setSelection()
            }
        }
    }
    
    public func executeJavaScript(_ muFunction: String, completionHandler: ((@MainActor @Sendable (Any?, (any Error)?)->Void))? = nil) {
        let wrappedFunction = """
        (() => {
                    let element = document.getElementById("markupeditor")
                    return element?.\(muFunction)
        })()
        """
        evaluateJavaScript(wrappedFunction, completionHandler: completionHandler)
    }
    
    @discardableResult public func executeJavaScript(_ muFunction: String) async throws -> Any? {
        let wrappedFunction = """
        (() => {
                    let element = document.getElementById("markupeditor")
                    return element?.\(muFunction)
        })()
        """
        return try await evaluateJavaScript(wrappedFunction)
    }
    
    /// Set the selection properly if we are focused.
    ///
    /// If the selection is invalid (e.g., it has never been focused/selected before), then we attempt to set the selection into an
    /// initial state, positioning selection at the beginning of the document. If selection state is valid, we reset the
    /// local cache and the global MarkupEditor.selectionState.
    private func setSelection() {
        guard hasFocus else { return }
        getSelectionState { selectionState in
            if selectionState.isValid {
                self.selectionState.reset(from: selectionState)             // cache it here
                MarkupEditor.selectionState.reset(from: selectionState)     // and set globally
            } else {    // Should not happen
                self.resetSelection {
                    self.getSelectionState { newSelectionState in
                        if newSelectionState.isValid {
                            self.selectionState.reset(from: newSelectionState)         // cache it here
                            MarkupEditor.selectionState.reset(from: newSelectionState) // and set globally
                        } else {
                            // This can be a normal case when selecting outside of an editable area,
                            // so log info if needed. Theoretically, the editor should keep you from
                            // selecting outside of a selectable area, but there are initial conditions
                            // where this occurs and will result in a disabled MarkupToolbar, which will
                            // be what you want. In this case, why annoy yourself over and over with the info?
                            // Logger.webview.info(" Could not reset selectionState")
                        }
                    }
                }
            }
        }
    }
    
    /// Reset the selection to the beginning of the document.
    func resetSelection(handler: (()->Void)? = nil) {
        executeJavaScript("MU.resetSelection()") { result, error in
            if let error {
                Logger.webview.error("resetSelection error: \(error.localizedDescription)")
            }
            handler?()
        }
    }
    
    /// Focus on MU.editor, which triggers a focus event and sets hasFocus
    func focus(handler: (()->Void)? = nil) {
        executeJavaScript("MU.focus()") { result, error in
            if let error {
                Logger.webview.error("focus error: \(error)")
                self.hasFocus = false
            } else {
                self.hasFocus = true
            }
            handler?()
        }
    }
    
    /// Return the bundle that is appropriate for the packaging.
    ///
    /// If you use the framework as a dependency, the bundle can be identified from
    /// the place where MarkupWKWebView is found. If you use the Swift package as a
    /// dependency, it does some BundleFinder hocus pocus behind the scenes to allow
    /// Bundle to respond to module, where we can find markup.html etc that are
    /// part of the package.
    func bundle() -> Bundle {
#if SWIFT_PACKAGE
        return Bundle.module
#else
        return Bundle(for: MarkupWKWebView.self)
#endif
    }
    
    /// Return the url for the named resource, always using the one in Bundle.main first if it exists.
    ///
    /// Users can package their own markup.html, css, and js to replace the ones that are used by
    /// default in the MarkupEditor.
    func url(forResource name: String, withExtension ext: String?) -> URL? {
        let url = bundle().url(forResource: name, withExtension: ext)
        return Bundle.main.url(forResource: name, withExtension: ext) ?? url
    }
    
    /// Initialize the directory at cacheUrl with a clean copy of the root resource files.
    ///
    /// Any failure to find or copy the root resource files results in an assertion failure, since no editing is possible.
    private func initRootFiles() {
        guard
            let rootJs = url(forResource: "markup-editor", withExtension: "js") else {
            assertionFailure("Could not find markup-editor.js for this bundle.")
            return
        }
        var srcUrls = [rootJs]
        // If specified, the userCSS comes from the app's main bundle, not something MarkupEditor provides
        if let userCssFile, let userCss = url(forResource: userCssFile, withExtension: nil) {
            srcUrls.append(userCss)
        }
        if let userScriptFile, let userScript = url(forResource: userScriptFile, withExtension: nil) {
            srcUrls.append(userScript)
        }
        if let userResourceFiles = markupConfiguration?.userResourceFiles {
            for file in userResourceFiles {
                if let userResource = url(forResource: file, withExtension: nil) {
                    srcUrls.append(userResource)
                }
            }
        }
        let fileManager = FileManager.default
        // The cacheDir is a "id" subdirectory below the app's cache directory
        // If not supplied, then id will be a UUID().uuidString
        let cacheUrl = cacheUrl()
        let cacheUrlPath = cacheUrl.path
        do {
            try fileManager.createDirectory(atPath: cacheUrlPath, withIntermediateDirectories: true, attributes: nil)
            for srcUrl in srcUrls {
                let dstUrl = cacheUrl.appendingPathComponent(srcUrl.lastPathComponent)
                try? fileManager.removeItem(at: dstUrl)
                try fileManager.copyItem(at: srcUrl, to: dstUrl)
            }
            populateMarkupHtml(cacheUrl: cacheUrl)
        } catch let error {
            assertionFailure("Failed to set up cacheDir with root resource files: \(error.localizedDescription)")
        }
    }
    
    /// Create markup.html in the cache directory. By loading this file, everything else is kicked off.
    ///
    /// We use  the `<markup-editor>` web component, and because we copy the standard
    /// `markup-editor.js` and `markupeditor.css` (and the css files it imports) into the
    /// cache directory, we don't need to specify `muscript` or `mustyle`. The Swift config values
    /// for `placeholder`, `resourcesUrl`, and `selectedAfterLoad` are supplied as attributes
    /// to the web component. Also note:
    ///
    /// * The Swift value for `delegate` is not useful to pass as an attribute, since the "swift" message
    /// handler (i.e., the MarkupCoordinator) does all the calls to the Swift-native delegate.
    /// * The JavaScript-created toolbar available from the MarkupEditor is turned off for the Swift
    /// MarkupEditor, which has its own SwiftUI MarkupToolbar.
    /// * The initial HTML is inserted as the content of the web component.
    func populateMarkupHtml(cacheUrl: URL) {
        let componentscript = cacheUrl.appendingPathComponent("markup-editor.js").path
        let dstUrl = cacheUrl.appendingPathComponent("markup.html")
        let html = """
        <!DOCTYPE html>
        <html>
            <head>
                <meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no">
                <meta name="supported-color-schemes" content="light dark">
                <meta http-equiv="Content-Type" content="text/html; charset=UTF-8">
            </head>
            <body>
                <markup-editor
                    id="markupeditor"
                    \(placeholder != nil ? "placeholder=\"\(placeholder!)\"" : "")
                    \(resourcesUrl != nil ? "base=\"\(resourcesUrl!.path)\"" : "")
                    \(userScriptFile != nil ? "userscript=\"\(userScriptFile!)\"" : "")
                    \(userCssFile != nil ? "userstyle=\"\(userCssFile!)\"" : "")
                    selectafterload="\"\(selectAfterLoad)\"")
                    toolbar="none"
                    handler="swift">
                \(html != nil ? html! : "<p></p>")
                </markup-editor>
                <script src="\(componentscript)" type="module"></script>
            </body>
        </html>
        """
        let fileManager = FileManager.default
        do {
            try? fileManager.removeItem(at: dstUrl)
            try html.write(to: dstUrl, atomically: true, encoding: String.Encoding.utf8)
        } catch let error {
            assertionFailure("Failed to populate \(dstUrl.path): \(error.localizedDescription)")
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
            Logger.webview.error("Failure copying resource files: \(error.localizedDescription)")
        }
    }
    
    /// Return whether a resource file exists where it is expected.
    ///
    /// Resources are referenced relative to the cacheUrl, and we use this method during testing.
    public func resourceExists(_ fileName: String) -> Bool {
        return FileManager.default.fileExists(atPath: cacheUrl().appendingPathComponent(fileName).path)
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
    
    /// Set the EditableAttributes for the editor element.
    public func setTopLevelAttributes(_ handler: (()->Void)? = nil) {
        guard
            let attributes = markupConfiguration?.topLevelAttributes,
            !attributes.isEmpty,
            let jsonData = try? JSONSerialization.data(withJSONObject: attributes.options),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            handler?()
            return
        }
        executeJavaScript("MU.setTopLevelAttributes('\(jsonString)')") { result, error in
            handler?()
        }
    }
    
    /// Invoke `loadUserFiles` with the `userScriptFile` and `userCssFile` regardless of whether either is
    /// specified. The result will be a callback to `loadedUserFiles`, which causes `loadInitialHtml` and the
    /// call to MarkupDelegate.markupLoaded to happen.
    public func loadUserFiles(_ handler: (()->Void)? = nil) {
        let scriptFile = userScriptFile == nil ? "null": "'\(userScriptFile!)'"
        let cssFile = userCssFile == nil ? "null" : "'\(userCssFile!)'"
        executeJavaScript("MU.loadUserFiles(\(scriptFile), \(cssFile))") { result, error in
            handler?()
        }
    }
    
    /// Load the initialHtml, let the delegate know, and becomeFirstResponder if
    /// selectAfterLoad is true.
    ///
    /// In some cases, you won't want to select after load. For example, if you are
    /// using multiple MarkupWKWebViews in a single View/UIView or even a List,
    /// then you want to set MarkupEditor.firstResponder by id, not just have each
    /// MarkupWKWebView becomeFirstResponder and trigger a SelectionState
    /// update to refresh the MarkupToolbar as each one loads its HTML.
    public func loadInitialHtml() {
        self.markupDelegate?.markupWillLoad(self)
        self.setHtml(self.html ?? "") {
            //Logger.webview.debug("isReady: \(self.id)")
            self.updateHeight() {
                self.isReady = true
                if let delegate = self.markupDelegate {
                    delegate.markupDidLoad(self) {
                        if self.selectAfterLoad {
                            self.becomeFirstResponderIfReady()
                        }
                    }
                } else {
                    if self.selectAfterLoad {
                        self.becomeFirstResponderIfReady()
                    }
                }
            }
        }
    }
    
    //MARK: Keyboard handling and accessoryView setup

    #if canImport(UIKit)
    /// Respond to keyboardWillShow event.
    ///
    /// We adjust toolbar height constraint so it shows properly and scroll the selection so it is not obscured by
    /// the keyboard.
    ///
    /// We want to restore any contentOffset we started with when the keyboard hides. However, we get multiple keyboardWillShow
    /// events, and during ones after the first, the contentOffset may have been magically changed to something we don't want to
    /// reset-to. For this reason, we only capture and restore the contentOffset that was present at the first keyboardWillShow event.
    @objc private func keyboardWillShow(_ notification: NSNotification) {
        markupToolbarHeightConstraint.constant = MarkupEditor.toolbarStyle.height()
        // Gate the oldContentOffset setting so it only happens once; reset to nil at keyboardDidHide time
        if oldContentOffset == nil { oldContentOffset = scrollView.contentOffset }
        if hasFocus, let oldContentOffset, let actualSourceRect = selectionState.sourceRect {
            let sourceRect = CGRect(origin: actualSourceRect.origin, size: CGSize(width: actualSourceRect.width, height: actualSourceRect.height))
            guard let userInfo = notification.userInfo else { return }
            // In iOS 16.1 and later, the keyboard notification object is the screen the keyboard appears on.
            guard let screen = notification.object as? UIScreen,
                  // Get the keyboard's frame at the end of its animation
                  let keyboardFrameEnd = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            // Use the screen to get the coordinate space to convert from
            let fromCoordinateSpace = screen.coordinateSpace
            // Get this view's coordinate space
            let toCoordinateSpace: UICoordinateSpace = self
            // Convert the extended keyboard frame from the screen's coordinate space to this view's coordinate space
            let convertedKeyboardFrameEnd = fromCoordinateSpace.convert(keyboardFrameEnd, to: toCoordinateSpace)
            // Get the intersection between the keyboard's frame and the view's bounds. Unlike, say a TextView
            // where we would want to use that view's scrollview to push it up out of the keyboard's way, here
            // we want to scroll the text inside of the MarkupWKWenbView up if the keyboard overlaps the selection
            // which is held in sourceRect.
            let viewIntersection = bounds.intersection(convertedKeyboardFrameEnd)
            let sourceIntersection = sourceRect.intersection(convertedKeyboardFrameEnd)
            // Check whether the keyboard intersects the selection before announcing the offset needed. We
            // don't need to do anything if the keyboard isn't covering the sourceRect at all.
            if !sourceIntersection.isEmpty {
                let bottomOffset = sourceIntersection.maxY - viewIntersection.minY
                if bottomOffset > 0 {
                    scrollView.setContentOffset(CGPoint(x: oldContentOffset.x, y: oldContentOffset.y + bottomOffset), animated: true)
                }
            }
        }
    }

    /// Respond to the keyboardDidHide event.
    ///
    /// Adjust the height contstraint on the MarkupToolbar and reset the contentOffset.
    /// Reset oldContentOffset so we can key off of it being nil the next time keyBoardWillShow happens.
    @objc private func keyboardDidHide() {
        markupToolbarHeightConstraint.constant = 0
        scrollView.setContentOffset(oldContentOffset ?? CGPoint.zero, animated: true)
        oldContentOffset = nil
    }
    #endif
    
    //MARK: Overrides
    
    #if canImport(UIKit)
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
            //if event.type != .hover { // Else mouse movement over the view produces a zillion hover log messages
            //    Logger.webview.debug("Letting WKWebView handle: \(event.description)")
            //}
            return super.hitTest(point, with: event)
        default:
            // We will handle the UIDragEvent ourselves
            //Logger.webview.debug("MarkupWKWebView handling: \(event.description)")
            return self
        }
    }
    #endif
    
    //MARK: Responder Handling
    
    // The following two overrides were removed because (perhaps among other weirdnesses)
    // they cause the keyboardWillShow event to be fired too many times, and sometimes when
    // it isn't going to show (such as on rotation while no keyboard is showing).
    //public override var canBecomeFirstResponder: Bool {
    //    return hasFocus
    //}
    
    //public override var canResignFirstResponder: Bool {
    //    return !hasFocus
    //}
    
    #if canImport(UIKit)
    public override var inputAccessoryView: UIView? {
        get { accessoryView }
        set { accessoryView = newValue }
    }

    /// Return false to disable various menu items depending on selectionState
    @objc override public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        guard selectionState.isValid else { return false }
        switch action {
        case #selector(getter: undoManager):
            return true
        case #selector(UIResponderStandardEditActions.select(_:)), #selector(UIResponderStandardEditActions.selectAll(_:)):
            return super.canPerformAction(action, withSender: sender)
        case #selector(UIResponderStandardEditActions.copy(_:)), #selector(UIResponderStandardEditActions.cut(_:)):
            return selectionState.canCopyCut
        case #selector(UIResponderStandardEditActions.paste(_:)), #selector(UIResponderStandardEditActions.pasteAndMatchStyle(_:)):
            return pasteableType() != nil
        case #selector(indent), #selector(outdent):
            return selectionState.canDent
        case #selector(bullets), #selector(numbers):
            return selectionState.canList
        case #selector(pStyle), #selector(h1Style), #selector(h2Style), #selector(h3Style), #selector(h4Style), #selector(h5Style), #selector(h6Style), #selector(pStyle):
            return selectionState.canStyle
        case #selector(showPluggableLinkPopover), #selector(showPluggableImagePopover), #selector(showPluggableTablePopover):
            return true     // Toggles off and on
        case #selector(bold), #selector(italic), #selector(underline), #selector(code), #selector(strike), #selector(subscriptText), #selector(superscript):
            return selectionState.canFormat
        default:
            //Logger.webview.debug("Unknown action: \(action)")
            return false
        }
    }
    #endif
    
    @available(*, deprecated, message: "No longer needed for modal input operations.")
    public func startModalInput(_ handler: (() -> Void)? = nil) {
        executeJavaScript("MU.startModalInput()") { result, error in
            handler?()
        }
    }
    
    @available(*, deprecated, message: "No longer needed for modal input operations.")
    public func endModalInput(_ handler: (() -> Void)? = nil) {
        executeJavaScript("MU.endModalInput()") { result, error in
            handler?()
        }
    }
    
    #if canImport(UIKit)
    /// Indirect the presentation of the link popover thru the markupDelegate to allow overriding.
    @objc public func showPluggableLinkPopover() {
        markupDelegate?.markupShowLinkPopover(self)
    }

    /// Indirect the presentation of the image popover thru the markupDelegate to allow overriding.
    @objc public func showPluggableImagePopover() {
        markupDelegate?.markupShowImagePopover(self)
    }

    /// Indirect the presentation of the table popover thru the markupDelegate to allow overriding.
    @objc public func showPluggableTablePopover() {
        markupDelegate?.markupShowTablePopover(self)
    }

    /// Show the default link popover using the LinkViewController.
    @objc public func showLinkPopover() {
        MarkupEditor.showInsertPopover.type = .link     // Does nothing by default
        let linkVC = LinkViewController()
        linkVC.modalPresentationStyle = .popover
        linkVC.preferredContentSize = CGSize(width: 300, height: 100 + 2.0 * MarkupEditor.toolbarStyle.buttonHeight())
        guard let popover = linkVC.popoverPresentationController else { return }
        popover.delegate = self
        popover.sourceView = self
        // The sourceRect needs a non-zero width/height, but when selection is collapsed, we get a zero width.
        // The selectionState.sourceRect makes sure selRect has non-zero width/height.
        popover.sourceRect = MarkupEditor.selectionState.sourceRect ?? bounds
        closestVC()?.present(linkVC, animated: true)
    }

    /// Show the default link popover using the ImageViewController.
    @objc public func showImagePopover() {
        MarkupEditor.showInsertPopover.type = .image    // Does nothing by default
        let imageVC = ImageViewController()
        imageVC.modalPresentationStyle = .popover
        imageVC.preferredContentSize = CGSize(width: 300, height: 140 + 2.0 * MarkupEditor.toolbarStyle.buttonHeight())
        guard let popover = imageVC.popoverPresentationController else { return }
        popover.delegate = self
        popover.sourceView = self
        // The sourceRect needs a non-zero width/height, but when selection is collapsed, we get a zero width.
        // The selectionState.sourceRect makes sure selRect has non-zero width/height.
        popover.sourceRect = MarkupEditor.selectionState.sourceRect ?? bounds
        closestVC()?.present(imageVC, animated: true)
    }

    /// Show the default table popover by setting the state of `MarkupEditor.showInsertPopover` to `.table`,
    /// which will in turn `forcePopover` of either the TableSizer or TableToolbar.
    @objc public func showTablePopover() {
        guard selectionState.canInsert else { return }
        MarkupEditor.showInsertPopover.type = .table    // Triggers default SwiftUI TableSizer or TableToolbar
    }
    #endif
    
    //MARK: Testing support
    
    /// Return unformatted but clean HTML contained in this MarkupWKWebView, with selection points
    /// indicated by `sel`.
    ///
    /// Except for the `sel` markers, the HTML is functionally equivalent to `getHtml()` but is not prettified..
    public func getTestHtml(sel: String = "|", handler: ((String?)->Void)? = nil) {
        executeJavaScript("MU.getTestHTML('\(sel)')") { result, error in
            handler?(result as? String)
        }
    }
    
    public func getTestHtml(sel: String) async -> String? {
        await withCheckedContinuation { continuation in
            getTestHtml(sel: sel) { html in
                continuation.resume(with: .success(html))
            }
        }
    }
    
    /// Set the html content for testing and return the sel-marked-up string.
    ///
    /// The small delay seems to avoid intermitted problems when running many tests together.
    public func setTestHtml(_ value: String, sel: String = "|", handler: ((String?) -> Void)? = nil) {
        executeJavaScript("MU.setTestHTML('\(value.escaped)', '\(sel)')") { result, error in
            if error == nil {
                self.getTestHtml(sel: sel) { string in
                    handler?(string)
                }
            } else {
                handler?(nil)
            }
        }
    }
    
    public func setTestHtml(_ value: String, sel: String) async -> String? {
        await withCheckedContinuation { continuation in
            setTestHtml(value) { html in
                continuation.resume(with: .success(html))
            }
        }
    }
    
    /// Invoke the preprocessing step for MU.pasteHTML directly.
    public func testPasteHtmlPreprocessing(html: String, handler: ((String?)->Void)? = nil) {
        executeJavaScript("MU.testPasteHTMLPreprocessing('\(html.escaped)')") { result, error in
            handler?(result as? String)
        }
    }
    
    public func testPasteHtmlPreprocessing(html: String) async -> String? {
        await withCheckedContinuation { continuation in
            testPasteHtmlPreprocessing(html: html) { endHtml in
                continuation.resume(with: .success(endHtml))
            }
        }
    }
    
    /// Invoke the preprocessing step for MU.pasteText directly.
    public func testPasteTextPreprocessing(html: String, handler: ((String?)->Void)? = nil) {
        executeJavaScript("MU.testPasteTextPreprocessing('\(html.escaped)')") { result, error in
            handler?(result as? String)
        }
    }
    
    public func testPasteTextPreprocessing(html: String) async -> String? {
        await withCheckedContinuation { continuation in
            testPasteTextPreprocessing(html: html) { endHtml in
                continuation.resume(with: .success(endHtml))
            }
        }
    }
    
    /// Invoke the \_doBlockquoteEnter operation directly.
    public func testBlockquoteEnter(handler: (()->Void)? = nil) {
        executeJavaScript("MU.testBlockquoteEnter()") { result, error in handler?() }
    }
    
    /// Invoke the \_doListEnter operation directly.
    public func testListEnter(handler: (()->Void)? = nil) {
        executeJavaScript("MU.testListEnter()") { result, error in handler?() }
    }
    
    public func testListEnter() async {
        await withCheckedContinuation { continuation in
            testListEnter {
                continuation.resume()
            }
        }
    }
    
    /// Ensure extractContents behaves as expected, since we depend on it.
    public func testExtractContents(handler: (()->Void)? = nil) {
        executeJavaScript("MU.testExtractContents()") { result, error in handler?() }
    }
    
    //MARK: Javascript interactions
    
    /// Return the HTML contained in this MarkupWKWebView.
    ///
    /// By default, we return nicely formatted HTML stripped of DIVs, SPANs, and empty text nodes.
    public func getHtml(pretty: Bool = true, clean: Bool = true, divID: String? = nil, _ handler: ((String?)->Void)?) {
        // By default, we get "pretty" and "clean" HTML.
        //  Pretty HTML is formatted to be readable.
        //  Clean HTML has divs, spans, and empty text nodes removed.
        let argString = divID == nil ? "'\(pretty)', '\(clean)'" : "'\(pretty)', '\(clean)', '\(divID!)'"
        executeJavaScript("MU.getHTML(\(argString))") { result, error in
            handler?(result as? String)
        }
    }
    
    public func emptyDocument(handler: (()->Void)? = nil) {
        executeJavaScript("MU.emptyDocument()") { result, error in
            handler?()
        }
    }
    
    public func setPlaceholder(text: String? = nil, _ handler: (()->Void)? = nil) {
        guard let newPlaceholder = text ?? placeholder else {
            handler?()
            return
        }
        executeJavaScript("MU.setPlaceholder('\(newPlaceholder.escaped)')") { result, error in
            handler?()
        }
    }
    
    public func setHtml(_ html: String, handler: (()->Void)? = nil) {
        self.html = html    // Our local record of what we set, used by setHtmlIfChanged
        // FYI, we use the term selectAfterLoad here, but on the JavaScript side, it is focusAfterLoad.
        executeJavaScript("MU.setHTML('\(html.escaped)', \(selectAfterLoad))") { result, error in
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
    
    /// Set the CSS padding-block bottom so that the padding fills the frame height. We do this based on markupConfiguration,
    /// which is set to true for iOS, else false.
    private func padBottom(handler: (()->Void)? = nil) {
        executeJavaScript("MU.padBottom('\(frame.height - CGFloat(clientHeightPad))')") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    /// Update the padding on the client side.
    public func updateHeight(handler: (()->Void)? = nil) {
        self.getHeight() { clientHeight in
            let paddedHeight = clientHeight + self.clientHeightPad
            #if canImport(UIKit)
            if self.markupConfiguration?.padBottom ?? false {
                self.padBottom() {
                    self.markupDelegate?.markup(self, heightDidChange: paddedHeight)
                    handler?()
                }
            } else {
                self.markupDelegate?.markup(self, heightDidChange: paddedHeight)
                handler?()
            }
            #else
            self.markupDelegate?.markup(self, heightDidChange: paddedHeight)
            handler?()
            #endif
        }
    }
    
    public func insertLink(_ href: String?, handler: (()->Void)? = nil) {
        if href == nil {
            executeJavaScript("MU.deleteLink()") { result, error in handler?() }
        } else {
            executeJavaScript("MU.insertLink('\(href!.escaped)')") { result, error in handler?() }
        }
    }
    
    public func insertLink(_ href: String?) async {
        await withCheckedContinuation { continuation in
            insertLink(href) {
                continuation.resume()
            }
        }
    }
    
    public func insertImage(src: String?, alt: String?, handler: (()->Void)? = nil) {
        var args = "'\(src!.escaped)'"
        if alt != nil {
            args += ", '\(alt!.escaped)'"
        }
        becomeFirstResponder()
        executeJavaScript("MU.insertImage(\(args))") { result, error in
            handler?() }
    }
    
    public func insertImage(src: String?, alt: String?) async {
        await withCheckedContinuation { continuation in
            insertImage(src: src, alt: alt) {
                continuation.resume()
            }
        }
    }
    
    public func insertLocalImage(url: URL, handler: ((URL)->Void)? = nil) {
        // TODO: Use extended attributes for alt text if available
        // (see https://stackoverflow.com/a/38343753/8968411)
        // Make a new unique ID for the image to save in the cacheUrl directory
        var path = "\(UUID().uuidString).\(url.pathExtension)"
        if let resourcesUrl {
            path = resourcesUrl.appendingPathComponent(path).relativePath
        }
        let cachedImageUrl = URL(fileURLWithPath: path, relativeTo: cacheUrl())
        do {
            try FileManager.default.copyItem(at: url, to: cachedImageUrl)
            insertImage(src: path, alt: nil) {
                handler?(cachedImageUrl)
            }
        } catch let error {
            Logger.webview.error("Error inserting local image: \(error.localizedDescription)")
            handler?(cachedImageUrl)
        }
    }
    
    /// Copy both the html for the image and the image itself to the clipboard.
    ///
    /// Why copy both? For copy/paste within the document itself, we always want to paste the HTML. The html
    /// points to the same image file at the same scale as exists in the document already. But, if the user wants
    /// to copy an image from the document and paste it into some other app, then they need the image from src
    /// at its full resolution. However, if the image in the MarkupEditor document is an external image, then we
    /// populate the public.html, not the public.png, so external pasting uses the url.
    public func copyImage(src: String, alt: String?, width: Int?, height: Int?) {
        guard let url = URL(string: src) else {
            markupDelegate?.markupError(code: "Invalid image URL", message: "The url for the image to copy was invalid.", info: "src: \(src)", alert: true)
            return
        }
        var html = ""
        var items = [String : Any]()
        // First, get the pngData for any local element, and start populating html with src
        if url.isFileURL, let fileUrl = URL(string: url.path) {
            // File urls need to reside at the cacheUrl or we don't put it in the pasteboard.
            // The src is specified relative to the cacheUrl().
            if (url.path.starts(with: cacheUrl().path)) {
                let cachedImageUrl = URL(fileURLWithPath: fileUrl.lastPathComponent, relativeTo: cacheUrl())
                if let urlData = try? Data(contentsOf: cachedImageUrl) {
                    let ext = cachedImageUrl.pathExtension
                    if let publicName = ext.isEmpty ? nil : "public." + ext {
                        items[publicName] = urlData
                    }
                    html += "<img src=\"\(cachedImageUrl.relativePath)\""
                }
            }
            guard !items.isEmpty else {
                markupDelegate?.markupError(code: "Invalid local image", message: "Could not copy image data to pasteboard.", info: "src: \(src)", alert: true)
                return
            }
        } else {
            // Src is the full path
            html += "<img src=\"\(src)\""
        }
        if let alt = alt { html += " alt=\"\(alt)\""}
        if let width = width, let height = height { html += " width=\"\(width)\" height=\"\(height)\""}
        html += ">"
        guard let htmlData = html.data(using: .utf8) else { // Should never happen
            markupDelegate?.markupError(code: "Invalid image HTML", message: "The html for the image to copy was invalid.", info: "html: \(html)", alert: true)
            return
        }
        items["markup.image"] = htmlData        // Always load up our custom pasteboard element
        if !url.isFileURL {
            items["public.html"] = htmlData     // And for external images, load up the html
        }
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        pasteboard.setItems([items])
        #else
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        // For macOS, we'll set the HTML data if available
        if let htmlData = items["public.html"] as? Data, let htmlString = String(data: htmlData, encoding: .utf8) {
            pasteboard.setString(htmlString, forType: .html)
        }
        #endif
    }
    
    private func getHeight(_ handler: @escaping ((Int)->Void)) {
        executeJavaScript("MU.getHeight()") { result, error in
            handler(result as? Int ?? 0)
        }
    }
    
    /// Search for text in the direction specified.
    ///
    /// *NOTE*: If you specify `activate: true`, then It is very important to `deactivateSearch` or `cancelSearch`
    /// when you're done searching. When `activate: true` is specified, on the JavaScript side a search becomes "active",
    /// and subsequent input of Enter in the MarkupWKWebView will search for the next occurrence of `text` in the `direction`
    /// specified until `deactivateSearch` or `cancelSearch` is called.
    public func search(for text: String, direction: FindDirection, activate: Bool = false, handler: (()->Void)? = nil) {
        becomeFirstResponder()
        // Remove the "smartquote" stuff that happens when inputting search into a TextField.
        // On the Swift side, replace the search string characters with the proper equivalents
        // for the MarkupEditor. To pass mixed apostrophes and quotes in the JavaScript call,
        // replace all apostrophe/quote-like things with "&quot;"/"&apos;", which we will
        // replace with "\"" and "'" on the JavaScript side before doing a search.
        let patchedText = text
            .replacingOccurrences(of: "\u{0027}", with: "&apos;")   // '
            .replacingOccurrences(of: "\u{2018}", with: "&apos;")   // ‘
            .replacingOccurrences(of: "\u{2019}", with: "&apos;")   // ‘
            .replacingOccurrences(of: "\u{0022}", with: "&quot;")   // "
            .replacingOccurrences(of: "\u{201C}", with: "&quot;")   // “
            .replacingOccurrences(of: "\u{201D}", with: "&quot;")   // ”
        executeJavaScript("MU.searchFor(\"\(patchedText)\", \"\(direction)\", \"\(activate)\")") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    public func search(for text: String, direction: FindDirection, activate: Bool = false) async {
        await withCheckedContinuation { continuation in
            search(for: text, direction: direction, activate: activate) {
                continuation.resume()
            }
        }
    }
    
    /// Stop intercepting Enter to invoke searchForNext().
    public func deactivateSearch(handler: (()->Void)? = nil) {
        executeJavaScript("MU.deactivateSearch()") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    /// Cancel the search that is underway, so that Enter is no longer intercepted and indexes are cleared on the JavaScript side.
    public func cancelSearch(handler: (()->Void)? = nil) {
        executeJavaScript("MU.cancelSearch()") { result, error in
            if let error {
                Logger.webview.error("Error: \(error)")
            }
            handler?()
        }
    }
    
    /// Scroll the view so that the selection is visible.
    ///
    /// We use the selrect found in selection state, pad it by 8 vertically, and scroll a minimum
    /// amount to keep put that padded rectangle fully in the view. Scrolling never moves the
    /// top below 0 or the bottom above the scrollView.contentHeight.
    #if canImport(UIKit)
    public func makeSelectionVisible(handler: (()->Void)? = nil) {
        getSelectionState() { state in
            guard let selrect = state.selrect else {
                handler?()
                return
            }
            // We pad selrect because we don't want to scroll so it is right at the top
            // or bottom, but instead is a reasonable amount inset.
            let padrect = selrect.insetBy(dx: 0, dy: -8)
            // Find intersection of padrect and visible portion of document. The selrect is always
            // relative to the frame, so we can use frame for the intersection.
            let intersection = padrect.intersection(self.frame)
            // If the intersection is the full padrect, then it is fully visible and we can return
            // without scrolling.
            if intersection == padrect {
                handler?()
                return
            }
            // Set the scroll targets so that padRect's bottom is fully within the frame, but scroll
            // by as little as needed to bring it in frame.
            let topTarget = padrect.origin.y + padrect.height + self.scrollView.contentOffset.y - self.frame.height
            // Keep the target so that it doesn't scroll the content above the bottom.
            let bottomTarget = self.scrollView.contentSize.height - self.frame.height
            let target = min(bottomTarget, max(0, topTarget))
            let scrollPoint = CGPoint(x: 0, y: target)
            self.scrollView.setContentOffset(scrollPoint, animated: true)
            handler?()
        }
    }
    #else
    public func makeSelectionVisible(handler: (()->Void)? = nil) {
        // Not supported on macOS yet
        handler?()
    }
    #endif

    //MARK: Undo/redo
    
    /// Invoke the undo function from the undo button, same as occurs with Command-S.
    public func undo(handler: (()->Void)? = nil) {
        executeJavaScript("MU.doUndo()") { result, error in handler?() }
    }
    
    public func undo() async {
        await withCheckedContinuation { continuation in
            undo {
                continuation.resume()
            }
        }
    }
    
    /// Invoke the undo function from the undo button, same as occurs with Command-Shift-S.
    public func redo(handler: (()->Void)? = nil) {
        executeJavaScript("MU.doRedo()") { result, error in handler?() }
    }
    
    public func redo() async {
        await withCheckedContinuation { continuation in
            redo {
                continuation.resume()
            }
        }
    }
    
    //MARK: Table editing
    
    public func nextCell(handler: (()->Void)? = nil) {
        executeJavaScript("MU.nextCell()") { result, error in handler?() }
    }
    
    public func prevCell(handler: (()->Void)? = nil) {
        executeJavaScript("MU.prevCell()") { result, error in handler?() }
    }
    
    public func insertTable(rows: Int, cols: Int, handler: (()->Void)? = nil) {
        executeJavaScript("MU.insertTable(\(rows), \(cols))") { result, error in handler?() }
    }
    
    public func insertTable(rows: Int, cols: Int) async {
        await withCheckedContinuation { continuation in
            insertTable(rows: rows, cols: cols) {
                continuation.resume()
            }
        }
    }
    
    public func addRow(_ direction: TableDirection, handler: (()->Void)? = nil) {
        switch direction {
        case .before:
            executeJavaScript("MU.addRow('BEFORE')") { result, error in handler?() }
        case .after:
            executeJavaScript("MU.addRow('AFTER')") { result, error in handler?() }
        }
    }
    
    public func addRow(_ direction: TableDirection) async {
        await withCheckedContinuation { continuation in
            addRow(direction) {
                continuation.resume()
            }
        }
    }
    
    public func deleteRow(handler: (()->Void)? = nil) {
        executeJavaScript("MU.deleteTableArea('ROW')") { result, error in handler?() }
    }
    
    public func deleteRow() async {
        await withCheckedContinuation { continuation in
            deleteRow() {
                continuation.resume()
            }
        }
    }
    
    public func addCol(_ direction: TableDirection, handler: (()->Void)? = nil) {
        switch direction {
        case .before:
            executeJavaScript("MU.addCol('BEFORE')") { result, error in handler?() }
        case .after:
            executeJavaScript("MU.addCol('AFTER')") { result, error in handler?() }
        }
    }
    
    public func addCol(_ direction: TableDirection) async {
        await withCheckedContinuation { continuation in
            addCol(direction) {
                continuation.resume()
            }
        }
    }
    
    public func deleteCol(handler: (()->Void)? = nil) {
        executeJavaScript("MU.deleteTableArea('COL')") { result, error in handler?() }
    }
    
    public func deleteCol() async {
        await withCheckedContinuation { continuation in
            deleteCol() {
                continuation.resume()
            }
        }
    }
    
    public func addHeader(colspan: Bool = true, handler: (()->Void)? = nil) {
        executeJavaScript("MU.addHeader(\(colspan))") { result, error in handler?() }
    }
    
    public func addHeader(colspan: Bool = true) async {
        await withCheckedContinuation { continuation in
            addHeader(colspan: colspan) {
                continuation.resume()
            }
        }
    }
    
    public func deleteTable(handler: (()->Void)? = nil) {
        executeJavaScript("MU.deleteTableArea('TABLE')") { result, error in handler?() }
    }
    
    public func deleteTable() async {
        await withCheckedContinuation { continuation in
            deleteTable() {
                continuation.resume()
            }
        }
    }
    
    public func borderTable(_ border: TableBorder, handler: (()->Void)? = nil) {
        executeJavaScript("MU.borderTable(\"\(border)\")")  { result, error in handler?() }
    }
    
    public func borderTable(_ border: TableBorder) async {
        await withCheckedContinuation { continuation in
            borderTable(border) {
                continuation.resume()
            }
        }
    }
    
    //MARK: Image editing
    
    public func modifyImage(src: String?, alt: String?, handler: (()->Void)?) {
        var args = ""
        if let src = src {
            args += "'\(src)'"
            if let alt = alt {
                args += ", '\(alt)'"
            } else {
                args += ", null"
            }
        }
        executeJavaScript("MU.modifyImage(\(args))") { result, error in
            handler?()
        }
    }
    
    //MARK: Paste
    
    /// Return the Pasteable type based on the types found in the UIPasteboard.general.
    ///
    /// The order is important, since it identifies what will be pasted, and multiple of these
    /// pasteboard types may be included. Thus, the ordering translates to:
    ///
    /// 1. Paste a local image from the MarkupEditor if present.
    /// 2. Paste an image copied from an external source/app if present.
    /// 3. Paste an image that exists at a URL if present.
    /// 4. Paste html if present, which might be pasted as text or html depending on choice.
    /// 5. Paste text if present.
    ///
    /// When we copy from the MarkupEditor itself, we populate both the "markup.image" of the
    /// pasteboard as well as the "image". This lets us paste the image to an external app,
    /// where it will show up full size. However, if we have "markup.image" populated, then
    /// we prioritize it for pasting, because it retains the sizing of the original.
    public func pasteableType() -> PasteableType? {
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        if pasteboard.contains(pasteboardTypes: ["markup.image"]) {
            return .LocalImage
        } else if pasteboard.image != nil {
            // We have copied an image into the pasteboard
            return .ExternalImage
        } else if pasteboard.url != nil {
            // We have a url which might be an image we can display or not
            return .Url
        } else if pasteboard.contains(pasteboardTypes: ["public.html"]) {
            // We have HTML, which we will have to sanitize before pasting
            return .Html
        } else if pasteboard.contains(pasteboardTypes: ["public.rtf"]) {
            return .Rtf
        } else if pasteboard.hasStrings {
            // We have a string that we can paste
            return .Text
        }
        #else
        let pasteboard = NSPasteboard.general
        if let _ = pasteboard.availableType(from: [.tiff, .png]) {
            return .ExternalImage
        } else if let _ = pasteboard.availableType(from: [.html]) {
            return .Html
        } else if pasteboard.availableType(from: [.string]) != nil {
            return .Text
        }
        #endif
        return nil
    }
    
    public func pasteText(_ text: String?, handler: (()->Void)? = nil) {
        guard let text = text, !pastedAsync else { return }
        pastedAsync = true
        executeJavaScript("MU.pasteText('\(text.escaped)')") { result, error in
            self.pastedAsync = false
            handler?()
        }
    }
    
    public func pasteHtml(_ html: String?, handler: (()->Void)? = nil) {
        guard let html = html, !pastedAsync else { return }
        pastedAsync = true
        executeJavaScript("MU.pasteHTML('\(html.escaped)')") { result, error in
            self.pastedAsync = false
            handler?()
        }
    }
    
    public func pasteHtml(_ html: String?) async {
        await withCheckedContinuation { continuation in
            pasteHtml(html) {
                continuation.resume()
            }
        }
    }
    
    public func pasteImage(_ image: PlatformImage?, handler: (()->Void)? = nil) {
        guard let image = image, !pastedAsync else { return }

        #if canImport(UIKit)
        guard let contents = image.pngData() else { return }
        #else
        guard let tiffRepresentation = image.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffRepresentation),
              let contents = bitmapImage.representation(using: .png, properties: [:]) else { return }
        #endif

        // Make a new unique ID for the image to save in the cacheUrl directory
        pastedAsync = true
        var path = "\(UUID().uuidString).png"
        if let resourcesUrl {
            path = resourcesUrl.appendingPathComponent(path).relativePath
        }
        let cachedImageUrl = URL(fileURLWithPath: path, relativeTo: cacheUrl())
        do {
            if FileManager.default.fileExists(atPath: path) {
                // Update an existing data file (Which should never happen!)
                try contents.write(to: cachedImageUrl)
            } else {
                // Create a new data file
                FileManager.default.createFile(atPath: cachedImageUrl.path, contents: contents, attributes: nil)
            }
            insertImage(src: path, alt: nil) {
                self.pastedAsync = false
                handler?()
            }
        } catch let error {
            Logger.webview.error("Error inserting local image: \(error.localizedDescription)")
            handler?()
        }
    }

    public func pasteImage(_ image: PlatformImage?) async {
        await withCheckedContinuation { continuation in
            pasteImage(image) {
                continuation.resume()
            }
        }
    }
    
    //MARK: Formatting
    
    // Required for menu support
    @objc public func bold() {
        bold(handler: nil)
    }
    
    public func bold(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleBold()") { result, error in
            if let error { print("ERROR: \(error.localizedDescription)") }
            handler?()
        }
    }
    
    public func bold() async throws {
        return executeJavaScript("MU.toggleBold()")
    }
    
    // Required for menu support
    @objc public func italic() {
        italic(handler: nil)
    }
    
    public func italic(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleItalic()") { result, error in
            handler?()
        }
    }
    
    public func italic() async throws {
        try await executeJavaScript("MU.toggleItalic()")
    }
    
    // Required for menu support
    @objc public func underline() {
        underline(handler: nil)
    }
    
    public func underline(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleUnderline()") { result, error in
            handler?()
        }
    }
    
    public func underline() async throws {
        try await executeJavaScript("MU.toggleUnderline()")
    }
    
    // Required for menu support
    @objc public func code() {
        code(handler: nil)
    }
    
    public func code(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleCode()") { result, error in
            handler?()
        }
    }

    public func code() async throws {
        try await executeJavaScript("MU.toggleCode()")
    }
    
    // Required for menu support
    @objc public func strike() {
        strike(handler: nil)
    }
    
    public func strike(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleStrike()") { result, error in
            handler?()
        }
    }
    
    public func strike() async throws {
        try await executeJavaScript("MU.toggleStrike()")
    }
    
    // Required for menu support
    @objc public func subscriptText() {
        subscriptText(handler: nil)
    }
    
    public func subscriptText(handler: (()->Void)? = nil) {      // "superscript" is a keyword
        executeJavaScript("MU.toggleSubscript()") { result, error in
            handler?()
        }
    }
    
    public func subscriptText() async throws {
        try await executeJavaScript("MU.toggleSubscript()")
    }
    
    // Required for menu support
    @objc public func superscript() {
        superscript(handler: nil)
    }
    
    public func superscript(handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleSuperscript()") { result, error in
            handler?()
        }
    }
    
    public func superscript() async throws {
        try await executeJavaScript("MU.toggleSuperscript()")
    }
    
    //MARK: Selection state
    
    /// Get the selectionState async and execute a handler with it.
    ///
    /// Note we keep a local copy up-to-date so we can use it for handling actions coming in from
    /// the MarkupMenu and hot-keys. Calls to getSelectionState here only affect the locally cached
    /// selectionState, not the MarkupEditor.selectionState that is reflected in the MarkupToolbar.
    public func getSelectionState(handler: ((SelectionState)->Void)? = nil) {
        executeJavaScript("MU.getSelectionState()") { result, error in
            guard
                error == nil,
                let stateString = result as? String,
                !stateString.isEmpty,
                let data = stateString.data(using: .utf8) else {
                self.selectionState.reset(from: SelectionState())
                handler?(self.selectionState)
                return
            }
            var newSelectionState: SelectionState
            do {
                let stateDictionary = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any]
                newSelectionState = self.selectionState(from: stateDictionary)
            } catch let error {
                Logger.webview.error("Error decoding selectionState data: \(error.localizedDescription)")
                newSelectionState = SelectionState()
            }
            self.selectionState.reset(from: newSelectionState)
            handler?(newSelectionState)
        }
    }
    
    public func getSelectionState() async -> SelectionState {
        await withCheckedContinuation { continuation in
            getSelectionState() { selectionState in
                continuation.resume(with: .success(selectionState))
            }
        }
    }
    
    private func selectionState(from stateDictionary: [String : Any]?) -> SelectionState {
        let selectionState = SelectionState()
        guard let stateDictionary = stateDictionary else {
            Logger.webview.error("State decoded from JSON was nil")
            return selectionState
        }
        // Validity (i.e., document.getSelection().rangeCount > 0
        selectionState.valid = stateDictionary["valid"] as? Bool ?? false
        // The contenteditable div ID or the enclosing DIV id if not contenteditable
        selectionState.divid = stateDictionary["divid"] as? String
        // Selected text
        if let selectedText = stateDictionary["selection"] as? String {
            selectionState.selection = selectedText.isEmpty ? nil : selectedText
            selectionState.selrect = rectFromDict(stateDictionary["selrect"] as? [String : CGFloat])
        } else {
            selectionState.selection = nil
            selectionState.selrect = nil
        }
        // Links
        selectionState.href = stateDictionary["href"] as? String
        selectionState.link = stateDictionary["link"] as? String
        // Images
        selectionState.src = stateDictionary["src"] as? String
        selectionState.alt = stateDictionary["alt"] as? String
        selectionState.width = stateDictionary["width"] as? Int
        selectionState.height = stateDictionary["height"] as? Int
        selectionState.scale = stateDictionary["scale"] as? Int
        // Tables
        selectionState.table = stateDictionary["table"] as? Bool ?? false
        selectionState.thead = stateDictionary["thead"] as? Bool ?? false
        selectionState.tbody = stateDictionary["tbody"] as? Bool ?? false
        selectionState.header = stateDictionary["header"] as? Bool ?? false
        selectionState.colspan = stateDictionary["colspan"] as? Bool ?? false
        selectionState.rows = stateDictionary["rows"] as? Int ?? 0
        selectionState.cols = stateDictionary["cols"] as? Int ?? 0
        selectionState.row = stateDictionary["row"] as? Int ?? 0
        selectionState.col = stateDictionary["col"] as? Int ?? 0
        if let rawValue = stateDictionary["border"] as? String {
            selectionState.border = TableBorder(rawValue: rawValue) ?? .cell
        } else {
            selectionState.border = .cell
        }
        // Styles
        if let tag = stateDictionary["style"] as? String {
            selectionState.style = StyleContext.with(tag: tag)
        } else {
            selectionState.style = StyleContext.Undefined
        }
        if let tag = stateDictionary["list"] as? String {
            selectionState.list = ListContext.with(tag: tag)
        } else {
            selectionState.list = ListContext.Undefined
        }
        selectionState.li = stateDictionary["li"] as? Bool ?? false
        selectionState.quote = stateDictionary["quote"] as? Bool ?? false
        // Formats
        selectionState.bold = stateDictionary["bold"] as? Bool ?? false
        selectionState.italic = stateDictionary["italic"] as? Bool ?? false
        selectionState.underline = stateDictionary["underline"] as? Bool ?? false
        selectionState.strike = stateDictionary["strike"] as? Bool ?? false
        selectionState.sub = stateDictionary["sub"] as? Bool ?? false
        selectionState.sup = stateDictionary["sup"] as? Bool ?? false
        selectionState.code = stateDictionary["code"] as? Bool ?? false
        return selectionState
    }
    
    public func rectFromDict(_ rectDict: [String : CGFloat]?) -> CGRect? {
        guard let rectDict = rectDict else { return nil }
        guard
            let x = rectDict["x"],
            let y = rectDict["y"],
            let width = rectDict["width"],
            let height = rectDict["height"] else { return nil }
            return CGRect(origin: CGPoint(x: x, y: y), size: CGSize(width: width, height: height))
    }
    
    //MARK: Styling

    #if canImport(UIKit)
    @objc public func pStyle(sender: UICommand) {
        replaceStyle(selectionState.style, with: .P)
    }
    #else
    @objc public func pStyle() {
        replaceStyle(selectionState.style, with: .P)
    }
    #endif
    
    @objc public func h1Style() {
        replaceStyle(selectionState.style, with: .H1)
    }
    
    @objc public func h2Style() {
        replaceStyle(selectionState.style, with: .H2)
    }
    
    @objc public func h3Style() {
        replaceStyle(selectionState.style, with: .H3)
    }
    
    @objc public func h4Style() {
        replaceStyle(selectionState.style, with: .H4)
    }
    
    @objc public func h5Style() {
        replaceStyle(selectionState.style, with: .H5)
    }
    
    @objc public func h6Style() {
        replaceStyle(selectionState.style, with: .H6)
    }
    
    /// Set the selection style to newStyle (e.g., <h3>)
    public func setStyle(to newStyle: StyleContext, handler: (()->Void)? = nil) {
        executeJavaScript("MU.setStyle('\(newStyle)')") { result, error in
            handler?()
        }
    }
    
    public func setStyle(to newStyle: StyleContext) async {
        await withCheckedContinuation { continuation in
            setStyle(to: newStyle) {
                continuation.resume()
            }
        }
    }
    
    /// Replace the oldStyle of the selection with the newStyle (e.g., from <p> to <h3>)
    /// Function provided for backward compatibility. Use setStyle.
    public func replaceStyle(_: StyleContext? = nil, with newStyle: StyleContext, handler: (()->Void)? = nil) {
        setStyle(to: newStyle, handler: handler)
    }
    
    public func replaceStyle(_: StyleContext? = nil, with newStyle: StyleContext) async {
        await withCheckedContinuation { continuation in
            setStyle(to: newStyle) {
                continuation.resume()
            }
        }
    }
    
    // Required for menu support
    @objc public func indent() {
        indent(handler: nil)
    }
    
    /// Indent the selection based on the context.
    ///
    /// If in a list, move list item to the next nested level if appropriate.
    /// Otherwise, increase the quote level by inserting a new blockquote.
    public func indent(handler: (()->Void)? = nil) {
        executeJavaScript("MU.indent()") { result, error in
            handler?()
        }
    }
    
    public func indent() async throws {
        try await executeJavaScript("MU.indent()")
    }

    // Required for menu support
    @objc public func outdent() {
        outdent(handler: nil)
    }
    
    /// Outdent the selection based on the context.
    ///
    /// If in a list, move list item to the previous nested level if appropriate.
    /// Otherwise, decrease the quote level by removing a blockquote if one exists.
    public func outdent(handler: (()->Void)? = nil) {
        executeJavaScript("MU.outdent()") { result, error in
            handler?()
        }
    }
    
    public func outdent() async throws {
        try await executeJavaScript("MU.outdent()")
    }
    
    @objc public func bullets() {
        toggleListItem(type: .UL)
    }
    
    @objc public func numbers() {
        toggleListItem(type: .OL)
    }
    
    /// Switch between ordered and unordered list styles.
    public func toggleListItem(type: ListContext, handler: (()->Void)? = nil) {
        executeJavaScript("MU.toggleListItem('\(type.tag)')") { result, error in
            handler?()
        }
    }
    
    public func toggleListItem(type: ListContext) async {
        await withCheckedContinuation { continuation in
            toggleListItem(type: type) {
                continuation.resume()
            }
        }
    }
    
}

//MARK: UIResponderStandardEditActions overrides

#if canImport(UIKit)
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

    @objc public override func copy(_ sender: Any?) {
        if selectionState.isInImage {
            copyImage(src: selectionState.src!, alt: selectionState.alt, width: selectionState.width, height: selectionState.height)
        } else {
            super.copy(sender)
        }
    }

    @objc public override func cut(_ sender: Any?) {
        if selectionState.isInImage {
            executeJavaScript("MU.cutImage()") { result, error in }
        } else {
            super.cut(sender)
        }
    }
    
    /// Invoke the paste method in the editor directly, passing the clipboard contents
    /// that would otherwise be obtained via the JavaScript event.
    ///
    /// Customize the type of paste operation on the JavaScript side based on the type
    /// of data available in UIPasteboard.general.
    public override func paste(_ sender: Any?) {
        guard let pasteableType = pasteableType() else { return }
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        switch pasteableType {
        case .Text:
            pasteText(pasteboard.string)
        case .Html:
            if let data = pasteboard.data(forPasteboardType: "public.html") {
                pasteHtml(String(data: data, encoding: .utf8))
            }
        case .Rtf:
            if let rtfData = pasteboard.data(forPasteboardType: "public.rtf") {
                do {
                    let attrString = try NSAttributedString(
                        data: rtfData,
                        options: [.documentType: NSAttributedString.DocumentType.rtf],
                        documentAttributes: nil)
                    let htmlData = try attrString.data(
                        from: NSRange(location: 0, length: attrString.length),
                        documentAttributes: [.documentType : NSAttributedString.DocumentType.html])
                    let html = String(data: htmlData, encoding: .utf8)
                    pasteHtml(html)
                } catch let error {
                    Logger.webview.error("Error getting html from rtf: \(error.localizedDescription)")
                }
            }
        case .ExternalImage:
            pasteImage(pasteboard.image)
        case .LocalImage:
            // Note that a LocalImage is just HTML; i.e., the html of the
            // image element we copied in the MarkupEditor, that also specifies
            // the dimensions.
            if let data = pasteboard.data(forPasteboardType: "markup.image") {
                pasteHtml(String(data: data, encoding: .utf8))
            }
        case .Url:
            pasteUrl(url: pasteboard.url)
        }
        #else
        let pasteboard = NSPasteboard.general
        switch pasteableType {
        case .Text:
            if let text = pasteboard.string(forType: .string) {
                pasteText(text)
            }
        case .Html:
            if let html = pasteboard.string(forType: .html) {
                pasteHtml(html)
            }
        case .ExternalImage:
            if let tiffData = pasteboard.data(forType: .tiff) ?? pasteboard.data(forType: .png) {
                if let nsImage = NSImage(data: tiffData) {
                    pasteImage(nsImage)
                }
            }
        default:
            break
        }
        #endif
    }
    
    /// Paste the url as an img or as a link depending on its content.
    ///
    /// This method is public so it can be used from tests and the tests can ensure the
    /// logic does the right thing for various URL forms.
    public func pasteUrl(url: URL?, handler: (()->Void)? = nil) {
        guard let url else {
            handler?()
            return
        }
        let urlString = url.absoluteString
        if isImageUrl(url: url) {
            insertImage(src: urlString, alt: nil) {
                handler?()
            }
        } else {
            insertLink(urlString) {
                handler?()
            }
        }
    }
    
    /// Return true if the url points to an image or movie that can be inserted into the document
    private func isImageUrl(url: URL?) -> Bool {
        guard let url else { return false }
        if url.isFileURL {
            return isLocalImage(url: url)
        } else {
            return isRemoteImage(url: url)
        }
    }
    
    /// Return true if the url points to an image in a local file.
    ///
    /// We can use `resourceValues(forKeys:)` on local files, whereas we have to infer whether the file is an image
    /// from the extension on non-local files.
    private func isLocalImage(url: URL) -> Bool {
        do {
            guard let typeID = try url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else { return false }
            guard let supertypes = UTType(typeID)?.supertypes else { return false }
            return supertypes.contains(.image) || supertypes.contains(.movie)
        } catch {
            return false
        }
    }
    
    /// Return true if the url points to a remote image file, based only on the file extension.
    private func isRemoteImage(url: URL) -> Bool {
        guard let utType = UTType(tag: url.pathExtension, tagClass: .filenameExtension, conformingTo: nil) else { return false }
        return utType.conforms(to: .image) || utType.conforms(to: .movie)
    }
    
    /// Paste the HTML or text only from the clipboard, but in a minimal "unformatted" manner
    public override func pasteAndMatchStyle(_ sender: Any?) {
        guard let pasteableType = pasteableType() else { return }
        #if canImport(UIKit)
        let pasteboard = UIPasteboard.general
        switch pasteableType {
        case .Text, .Rtf:
            pasteText(pasteboard.string)
        case .Html:
            if let data = pasteboard.data(forPasteboardType: "public.html") {
                pasteText(String(data: data, encoding: .utf8))
            }
        default:
            break
        }
        #else
        let pasteboard = NSPasteboard.general
        switch pasteableType {
        case .Text:
            if let text = pasteboard.string(forType: .string) {
                pasteText(text)
            }
        case .Html:
            if let html = pasteboard.string(forType: .html) {
                pasteText(html)
            }
        default:
            break
        }
        #endif
    }

}
#endif

//MARK: Drop support

#if canImport(UIKit)
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
#endif

//MARK: Popover support

#if canImport(UIKit)
extension MarkupWKWebView: UIPopoverPresentationControllerDelegate {

    public func adaptivePresentationStyle(for controller: UIPresentationController) -> UIModalPresentationStyle {
        .none
    }
}
#endif

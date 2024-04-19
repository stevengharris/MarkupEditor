//
//  MarkupCoordinator.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import WebKit
import OSLog

/// Tracks changes to a single MarkupWKWebView, updating the selectionState and informing the MarkupDelegate of what happened.
///
/// Communication between the MarkupWKWebView and MarkupCoordinator is done using a UserContentController.
/// The MarkupCoordinator functions as the WKScriptMessageHandler, receiving userContentController(_:didReceive:)
/// messages.
///
/// One of the key functions of the MarkupCoordinator is to handle the initialization of the MarkupWKWebView as it
/// loads its initial html, css, and JavaScript. The 'editor' element of the document is what we interact with in the
/// MarkupWKWebView. The MarkupCoordinator receives the 'ready' message when the html document loads fully, at
/// which point it is ready to be interacted-with.
///
/// The MarkupCoordinator is used both in SwiftUI and non-SwiftUI apps. In SwiftUI, the MarkupEditorView creates the
/// MarkupCoordinator itself, since the MarkupWKWebView (a subclass of WKWebView) is a UIKit component and has
/// to be dealt with by a Coordinator of some kind. In UIKit, the MarkupEditorUIView does the analogous work.
///
/// As events arrive here in the MarkupCoordinator, it takes various steps to ensure our knowledge in Swift of
/// what is in the MarkupWKWebView is maintained properly. Its other function is to inform the MarkupDelegate
/// of what's gone on, so the MarkupDelegate can do whatever is needed.  So, for example, when a focus event
/// is received by this MarkupCoordinator, it notifies the MarkupDelegate, which might want to take some other
/// action as the focus changes, such as updating the selectedWebView.
public class MarkupCoordinator: NSObject, WKScriptMessageHandler {
    weak public var webView: MarkupWKWebView!
    public var markupDelegate: MarkupDelegate?
    
    public init(markupDelegate: MarkupDelegate? = nil, webView: MarkupWKWebView? = nil) {
        self.markupDelegate = markupDelegate
        self.webView = webView
        super.init()
    }
    
    /// The height changed on the JavaScript side, so update our local value held by the webView, and set the
    /// bottom padding (https://developer.mozilla.org/en-US/docs/Web/CSS/padding-bottom)
    /// height so that it fills the full height of webView.
    @MainActor
    private func updateHeight() {
        webView.updateHeight() { height in
            self.webView.padBottom() {
                self.markupDelegate?.markup(self.webView, heightDidChange: height)
            }
        }
    }
    
    /// Take action based on the message body received from JavaScript via the userContentController.
    /// Messages with arguments were encoded using JSON.
    @MainActor
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? String else {
            Logger.coordinator.error("Unknown message received: \(String(describing: message.body))")
            return
        }
        guard let webView = message.webView as? MarkupWKWebView else {
            Logger.coordinator.error("message.webView was not a MarkupWKWebView")
            return
        }
        // Given it occurs with every change, treat "input" separately up front
        if messageBody.hasPrefix("input") {
            // We encode divId within the input message. Generally it will be "editor".
            let index = messageBody.index(messageBody.startIndex, offsetBy: 5)
            let divId = String(messageBody[index...])
            if divId.isEmpty || divId == "editor" {
                markupDelegate?.markupInput(webView)
                updateHeight()
            } else if !divId.isEmpty {
                markupDelegate?.markupInput(webView, divId: divId)
            } else {
                Logger.coordinator.error("Error: The div id could not be decoded for input.")
            }
            return
        }
        switch messageBody {
        case "ready":
            //Logger.coordinator.debug("ready")
            // When the root files are properly loaded, we can load user-supplied css and js.
            // Afterward, the "loadedUserFiles" callback will be invoked. Without the separate
            // callback to "loadedUserFiles", we can end up with the functions defined by user
            // scripts to not be defined when invoked from the MarkupDelegate.markupLoaded method.
            webView.loadUserFiles()
        case "loadedUserFiles":
            //Logger.coordinator.debug("loadedUserFiles")
            // After the user css and js are loaded, we set the top-level "editor" attributes,
            // and load the initial HTML, which will result in the MarkupDelegate.markupLoaded call.
            webView.setTopLevelAttributes() {
                webView.loadInitialHtml()
            }
        case "updateHeight":
            updateHeight()
        case "blur":
            //Logger.coordinator.debug("* blur")
            webView.hasFocus = false        // Track focus state so delegate can find it if needed
            markupDelegate?.markupLostFocus(webView)
            // TODO: Determine whether to clean up HTML or perhaps leave that to a markupDelegate
            // For now, we clean up the HTML when we lose focus
            //webView.cleanUpHtml() { error in
            //    if error != nil {
            //        Logger.coordinator.error("Error cleaning up html: \(error!.localizedDescription)")
            //    }
            //    self.markupDelegate?.markupLostFocus(webView)
            //}
        case "focus":
            //Logger.coordinator.debug("* focus")
            webView.hasFocus = true         // Track focus state so delegate can find it if needed
            // NOTE: Just because the webView here has focus does not mean it becomes the
            // selectedWebView, just like losing focus does not mean selectedWebView becomes nil.
            // Use markupDelegate.markupTookFocus to reset selectedWebView if needed, since
            // it will have logic specific to the application.
            markupDelegate?.markupTookFocus(webView)
        case "selectionChange":
            // If this webView does not have focus, we ignore selectionChange.
            // So, for example, if we select some other view or a TextField becomes first responder, we
            // don't want to modify selectionState. There may be other implications, such a programmatically
            // doing something to change selection in the WKWebView.
            // Note that selectionState remains the same object; just the state it holds onto is updated.
            if webView.hasFocus {
                webView.getSelectionState() { selectionState in
                    //Logger.coordinator.debug("* selectionChange")
                    MarkupEditor.selectionState.reset(from: selectionState)
                    self.markupDelegate?.markupSelectionChanged(webView)
                }
            //} else {
            //    Logger.coordinator.debug("* ignored selection change")
            }
        case "click":
            //Logger.coordinator.debug("click")
            webView.becomeFirstResponder()
            markupDelegate?.markupClicked(webView)
        case "undoSet":
            //Logger.coordinator.debug("undoSet")
            markupDelegate?.markupUndoSet(webView)
        case "searched":
            webView.makeSelectionVisible()  // Scroll to what we found and selected
        case "activateSearch":
            markupDelegate?.markupActivateSearch(webView)
        case "deactivateSearch":
            markupDelegate?.markupDeactivateSearch(webView)
        default:
            // Try to decode a complex JSON stringified message
            if let data = messageBody.data(using: .utf8) {
                do {
                    if let messageData = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        receivedMessageData(messageData)
                    } else {
                        Logger.coordinator.error("Error: Decoded message data was nil")
                    }
                } catch let error {
                    Logger.coordinator.error("Error decoding message data: \(error.localizedDescription)")
                }
            } else {
                Logger.coordinator.error("Error: Data could not be derived from message body")
            }
        }
    }
    
    /// Take action on messages with arguments that were received from JavaScript via the userContentController.
    /// On the JavaScript side, the messageType with string key 'messageType', and the argument has
    /// the key of the messageType.
    @MainActor
    private func receivedMessageData(_ messageData: [String : Any]) {
        guard let messageType = messageData["messageType"] as? String else {
            Logger.coordinator.error("Unknown message received: \(messageData)")
            return
        }
        switch messageType {
        case "action":
            if let message = messageData["action"] as? String {
                Logger.coordinator.info("\(message)")
            } else {
                Logger.coordinator.error("Bad action message.")
            }
        case "log":
            if let message = messageData["log"] as? String {
                Logger.coordinator.info("\(message)")
            } else {
                Logger.coordinator.error("Bad log message.")
            }
        case "error":
            guard let code = messageData["code"] as? String, let message = messageData["message"] as? String else {
                Logger.coordinator.error("Bad error message.")
                return
            }
            let info = messageData["info"] as? String
            let alert = (messageData["alert"] as? Bool) ?? true
            markupDelegate?.markupError(code: code, message: message, info: info, alert: alert)
        case "copyImage":
            guard
                let src = messageData["src"] as? String,
                let dimensions = messageData["dimensions"] as? [String : Int]
            else {
                Logger.coordinator.error("Src or dimensions was missing")
                return
            }
            let alt = messageData["alt"] as? String
            let width = dimensions["width"]
            let height = dimensions["height"]
            webView.copyImage(src: src, alt: alt, width: width, height: height)
        case "addedImage":
            guard let src = messageData["src"] as? String, let url = URL(string: src) else {
                Logger.coordinator.error("Src was missing or malformed")
                return
            }
            if let divId = messageData["divId"] as? String {
                // Even if divid is identified, if it's empty or the editor element, then
                // use the old call without divid to maintain compatibility with earlier versions
                // that did not support multi-contenteditable divs.
                if divId.isEmpty || divId == "editor" {
                    markupDelegate?.markupImageAdded(url: url)
                    updateHeight()
                } else if !divId.isEmpty {
                    markupDelegate?.markupImageAdded(webView, url: url, divId: divId)
                } else {
                    Logger.coordinator.error("Error: The div id for the image could not be decoded.")
                }
            } else {
                markupDelegate?.markupImageAdded(url: url)
            }
        case "deletedImage":
            guard let src = messageData["src"] as? String, let url = URL(string: src) else {
                Logger.coordinator.error("Src was missing or malformed")
                return
            }
            if let divId = messageData["divId"] as? String {
                // Even if divid is identified, if it's empty or the editor element, then
                // use the old call without divid to maintain compatibility with earlier versions
                // that did not support multi-contenteditable divs.
                if divId.isEmpty || divId == "editor" {
                    markupDelegate?.markupImageDeleted(url: url)
                    updateHeight()
                } else if !divId.isEmpty {
                    markupDelegate?.markupImageDeleted(webView, url: url, divId: divId)
                } else {
                    Logger.coordinator.error("Error: The div id for the image could not be decoded.")
                }
            } else {
                markupDelegate?.markupImageDeleted(url: url)
            }
        case "buttonClicked":
            guard
                let id = messageData["id"] as? String,
                let rectDict = messageData["rect"] as? [String : CGFloat],
                let rect = webView.rectFromDict(rectDict)
            else {
                Logger.coordinator.error("Button id or rect was missing")
                return
            }
            markupDelegate?.markupButtonClicked(webView, id: id, rect: rect)
        default:
            Logger.coordinator.error("Unknown message of type \(messageType): \(messageData).")
        }
    }
    
    @MainActor public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == WKNavigationType.linkActivated {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
}

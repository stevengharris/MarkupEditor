//
//  MarkupCoordinator.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import WebKit

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
/// The MarkupCoordinator is used both in SwiftUI and non-SwiftUI apps. In SwiftUI, the MarkupWebView creates the
/// MarkupCoordinator itself, since the MarkupWKWebView (a subclass of WKWebView) is a UIKit component and has
/// to be dealt with by a Coordinator of some kind.
///
/// While the SwiftMarkupEditor is designed to handle multiple MarkupWKWebViews with a single MarkupToolbar,
/// a MarkupCoordinator is coordinating between a single UIKit MarkupWKWebView and something that holds onto
/// the state of the app that is using the MarkupEditor. The SelectionState and selectedWebView are need to be
/// held in the top-level View for SwiftUI as StateObject or as properties of something that will be present
/// for the proper lifetime in a UIKit app (e.g., the top-level UIViewController).
///
/// As events arrive here in the MarkupCoordinator, it takes various steps to ensure our knowledge in Swift of
/// what is in the MarkupWKWebView is maintained properly. Its other function is to inform the MarkupDelegate
/// of what's gone on, so the MarkupDelegate can do whatever is needed.  So, for example, when a focus event
/// is received by this MarkupCoordinator, it notifies the MarkupDelegate, which might want to take some other
/// action as the focus changes, such as updating the selectedWebView.
public class MarkupCoordinator: NSObject, WKScriptMessageHandler {
    private var selectionState: SelectionState
    public var webView: MarkupWKWebView!
    public var markupDelegate: MarkupDelegate?
    
    public init(selectionState: SelectionState, markupDelegate: MarkupDelegate? = nil, webView: MarkupWKWebView? = nil) {
        self.selectionState = selectionState
        self.markupDelegate = markupDelegate
        self.webView = webView
        super.init()
    }
    
    private func updateHeight() {
        webView.updateHeight() { height in
            self.markupDelegate?.markup(self.webView, heightDidChange: height)
        }
    }
    
    private func loadInitialHtml() {
        // Load the html held by the webView, let the markupDelegate know, and then becomeFirstResponder.
        // If we don't becomeFirstResponder, then our first selection in the webView causes scrolling.
        let initialContent = webView.html ?? ""
        webView.setHtml(initialContent) { content in
            self.markupDelegate?.markupDidLoad(self.webView) {
                self.webView.becomeFirstResponder()
            }
        }
    }
    
    /// Take action based on the message body received from JavaScript via the userContentController.
    /// Messages with arguments were encoded using JSON.
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? String else {
            print("Unknown message received: \(message.body)")
            return
        }
        guard let webView = message.webView as? MarkupWKWebView else {
            print("message.webView was not a MarkupWKWebView")
            return
        }
        switch messageBody {
        case "ready":
            //print("ready")
            loadInitialHtml()
        case "input":
            markupDelegate?.markupInput(webView)
            updateHeight()
        case "updateHeight":
            updateHeight()
        case "blur":
            //print("* blur")
            webView.hasFocus = false        // Track focus state so delegate can find it if needed
            markupDelegate?.markupLostFocus(webView)
            // TODO:- Determine whether to clean up HTML or perhaps leave that to a markupDelegate
            // For now, we clean up the HTML when we lose focus
            //webView.cleanUpHtml() { error in
            //    if error != nil {
            //        print("Error cleaning up html: \(error!.localizedDescription)")
            //    }
            //    self.markupDelegate?.markupLostFocus(webView)
            //}
        case "focus":
            //print("* focus")
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
                    //webView.becomeFirstResponder()
                    self.selectionState.reset(from: selectionState)
                    self.markupDelegate?.markupSelectionChanged(webView)
                }
            //} else {
            //    print("no focus")
            }
        case "click":
            //print("click")
            webView.becomeFirstResponder()
            markupDelegate?.markupClicked(webView)
        default:
            // Try to decode a complex JSON stringified message
            if let data = messageBody.data(using: .utf8) {
                do {
                    if let messageData = try JSONSerialization.jsonObject(with: data, options: []) as? [String : Any] {
                        receivedMessageData(messageData)
                    } else {
                        print("Error: Decoded message data was nil")
                    }
                } catch let error {
                    print("Error decoding message data: \(error.localizedDescription)")
                }
            } else {
                print("Error: Data could not be derived from message body")
            }
        }
    }
    
    /// Take action on messages with arguments that were received from JavaScript via the userContentController.
    /// On the JavaScript side, the messageType with string key 'messageType', and the argument has
    /// the key of the messageType.
    private func receivedMessageData(_ messageData: [String : Any]) {
        guard let messageType = messageData["messageType"] as? String else {
            print("Unknown message received: \(messageData)")
            return
        }
        switch messageType {
        case "action":
            print(messageData["action"] as? String ?? "Bad action message")
        case "log":
            print(messageData["log"] as? String ?? "Bad log message")
        default:
            print("Unknown message of type \(messageType): \(messageData)")
        }
    }
    
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if navigationAction.navigationType == WKNavigationType.linkActivated {
            webView.load(navigationAction.request)
            decisionHandler(.cancel)
            return
        }
        decisionHandler(.allow)
    }
    
}

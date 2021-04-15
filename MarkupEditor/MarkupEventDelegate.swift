//
//  MarkupEventDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// MarkupEventDelegate defines app-specific functionality that will be invoked as the MarkupWKWebView state changes.
///
/// Default implementations of MarkupEventDelegate methods are provided, so all are optional.
public protocol MarkupEventDelegate {
    
    /// Called whenever input is received in the view (e.g., typing)
    func markupInput(_ view: MarkupWKWebView)
    
    /// Called when the inner height of the text being displayed changes
    /// Can be used to update the UI
    func markup(_ view: MarkupWKWebView, heightDidChange height: Int)
    
    /// Called whenever the content inside the view changes
    func markup(_ view: MarkupWKWebView, contentDidChange content: String)
    
    /// Called when the MarkupWKWebView starts editing
    func markupTookFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView stops editing or loses focus
    func markupLostFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView has become ready to receive input
    /// More concretely, is called when the internal WKWebView loads for the first time, and contentHtml is set
    func markupDidLoad(_ view: MarkupWKWebView)
    
    /// Called when custom actions are called by callbacks in the JS
    /// By default, this method is not used unless called by some custom JS that you add
    func markup(_ view: MarkupWKWebView, handle action: String)
    
    /// Called when the selection changes in the webView
    func markupSelectionChanged(_ view: MarkupWKWebView)
    
    /// Called when user clicks in the view
    /// Used to differentiate clicking on a link, image, table from selectionChange
    func markupClicked(_ view: MarkupWKWebView, uiDelegate: MarkupUIDelegate?)
    
}

extension MarkupEventDelegate {
    public func markupInput(_ view: MarkupWKWebView) {}
    public func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {}
    public func markup(_ view: MarkupWKWebView, contentDidChange content: String) {}
    public func markupTookFocus(_ view: MarkupWKWebView) {}
    public func markupLostFocus(_ view: MarkupWKWebView) {}
    public func markupDidLoad(_ view: MarkupWKWebView) {}
    public func markup(_ view: MarkupWKWebView, handle action: String) {}
    public func markupSelectionChanged(_ view: MarkupWKWebView) {}
    
    /// The user clicked on something. Get the selectionState and then let the uiDelegate decide how to handle the situation.
    ///
    /// This default behavior means the uiDelegate will be notified of a specific type of selection having occurred.
    /// This allows the MarkupUIDelegate behavior to be overridden as one path. Or, this MarkupEventDelegate
    /// default behavior can be overridden/customized.
    /// Note that an image can be linked, so the uiDelegate may receive multiple messages.
    public func markupClicked(_ view: MarkupWKWebView, uiDelegate: MarkupUIDelegate?) {
        guard let uiDelegate = uiDelegate else { return }
        view.getSelectionState() { selectionState in
            // If the selection is a followable link, then let the markupUIDelegate decide what to do.
            // The default behavior for the markupUIDelegate is to open the href found in selectionState.
            if selectionState.isFollowable {
                uiDelegate.markupLinkSelected(view, selectionState: selectionState)
            }
            // If the selection is in an image, let the markupUIDelegate decide what to do
            if selectionState.isInImage {
                uiDelegate.markupImageSelected(view, selectionState: selectionState)
            }
            // If the selection is in a table, let the markupUIDelegate decide what to do
            if selectionState.isInTable {
                uiDelegate.markupTableSelected(view, selectionState: selectionState)
            }
        }
    }
    
}

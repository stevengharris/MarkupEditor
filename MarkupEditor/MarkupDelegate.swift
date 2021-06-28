//
//  MarkupDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/16/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit

/// MarkupDelegate defines app-specific functionality that will be invoked as the MarkupWKWebView state changes.
///
/// Default implementations of MarkupDelegate methods are provided, so all are optional.
/// Most of the default methods do nothing, although some take care of simple behaviors.
/// Implement any of these methods in your MarkupDelegate to customize the bahavior for your app.
public protocol MarkupDelegate {
    
    /// Called whenever input is received in the view (e.g., typing).
    func markupInput(_ view: MarkupWKWebView)
    
    /// Called when the inner height of the text being displayed changes.
    /// Can be used to update the UI.
    func markup(_ view: MarkupWKWebView, heightDidChange height: Int)
    
    /// Called when the MarkupWKWebView starts editing.
    func markupTookFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView stops editing or loses focus.
    func markupLostFocus(_ view: MarkupWKWebView)
    
    /// Called when the MarkupWKWebView has become ready to receive input.
    /// More concretely, is called when the internal WKWebView loads for the first time, and contentHtml is set.
    ///
    /// Be sure to execute the handler if you override. The default behavior is to do nothing other than
    /// execute the handler. The MarkupCoordinator uses the handler to have the MarkupWKWebView
    /// becomeFirstResponder.
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?)
    
    /// Called when custom actions are called by callbacks in the JS.
    /// By default, this method is not used unless called by some custom JS that you add.
    func markup(_ view: MarkupWKWebView, handle action: String)
    
    /// Called when the selection changes in the webView.
    func markupSelectionChanged(_ view: MarkupWKWebView)
    
    /// Called when user clicks in the view.
    /// Used to differentiate clicking on a link, image, table from selectionChange.
    func markupClicked(_ view: MarkupWKWebView)
    
    /// Take action when the user selects a link.
    func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects an image.
    func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when the user selects a table.
    func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState)
    
    /// Take action when a toolbar appeared.
    func markupToolbarAppeared(type: SubToolbar.ToolbarType)
    
    /// Take action when a toolbar disappeared.
    func markupToolbarDisappeared()
    
}

extension MarkupDelegate {
    public func markupInput(_ view: MarkupWKWebView) {}
    public func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {}
    public func markupTookFocus(_ view: MarkupWKWebView) {}
    public func markupLostFocus(_ view: MarkupWKWebView) {}
    public func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) { handler?() }
    public func markup(_ view: MarkupWKWebView, handle action: String) {}
    public func markupSelectionChanged(_ view: MarkupWKWebView) {}
    
    /// The user clicked on something. 
    ///
    /// This default behavior examines the selectionState and invokes more specific methods based on
    /// what is selected. Note that an image can be linked, so the delegate may receive multiple messages.
    public func markupClicked(_ view: MarkupWKWebView) {
        view.getSelectionState() { selectionState in
            // If the selection is a followable link, then let the delegate decide what to do.
            // The default behavior for the delegate is to open the href found in selectionState.
            if selectionState.isFollowable {
                markupLinkSelected(view, selectionState: selectionState)
            }
            // If the selection is in an image, let the delegate decide what to do
            if selectionState.isInImage {
                markupImageSelected(view, selectionState: selectionState)
            }
            // If the selection is in a table, let the delegate decide what to do
            if selectionState.isInTable {
                markupTableSelected(view, selectionState: selectionState)
            }
        }
    }
    
    /// A link was selected, and selectionState contains information about it.
    ///
    /// This function is used by UIKit and SwiftUI apps, but we just use the UIApplication.shared here for simplicity.
    /// This does, however, force us to import UIKit.
    public func markupLinkSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {
        // If no handler is provided, the default action is to open the url at href if it can be opened
        guard
            let href = selectionState.href,
            let url = URL(string: href),
            UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }
    
    /// An image was selected, and selectionState contains information about it.
    public func markupImageSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}
    
    
    /// A table was selected, and selectionState contains information about it.
    public func markupTableSelected(_ view: MarkupWKWebView?, selectionState: SelectionState) {}

    public func markupToolbarAppeared(type: SubToolbar.ToolbarType) {}
    public func markupToolbarDisappeared() {}
    
}

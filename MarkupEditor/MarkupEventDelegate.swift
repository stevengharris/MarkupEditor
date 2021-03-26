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
    func markupSelectionChanged(_ view: MarkupWKWebView, selectionState: SelectionState)
    
}

extension MarkupEventDelegate {
    public func markup(_ view: MarkupWKWebView, heightDidChange height: Int) {}
    public func markup(_ view: MarkupWKWebView, contentDidChange content: String) {}
    public func markupTookFocus(_ view: MarkupWKWebView) {}
    public func markupLostFocus(_ view: MarkupWKWebView) {}
    public func markupDidLoad(_ view: MarkupWKWebView) {}
    public func markup(_ view: MarkupWKWebView, handle action: String) {}
    public func markupSelectionChanged(_ view: MarkupWKWebView, selectionState: SelectionState) {}
    
}

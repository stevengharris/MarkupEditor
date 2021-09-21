//
//  MarkupWebView.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import WebKit

/// The UIViewRepresentable for a UIKit-based MarkupWKWebView instance so MarkupWKWebView can be used in SwiftUI.
///
/// In general, we don't want WebKit abstractions to leak into the SwiftUI world. When the WKWebView is instantiated, you can optionally
/// specify the WKUIDelegate and WKNavigationDelegate if needed, which will be assigned to the underlying MarkupWKWebView.
///
/// The Coordinator will be a WKScriptMessageHandler and handle callbacks that come in from calls in markup.js to
/// window.webkit.messageHandlers.markup.postMessage(message);
public struct MarkupWebView: UIViewRepresentable {
    public typealias Coordinator = MarkupCoordinator
    private var selectionState: SelectionState
    private var observedWebView: ObservedWebView
    /// The initial HTML content to be shown in the MarkupWKWebView.
    private var initialContent: String
    public var markupDelegate: MarkupDelegate?
    private var wkNavigationDelegate: WKNavigationDelegate?
    private var wkUIDelegate: WKUIDelegate?
    private var userScripts: [String]?
    
    public init(
        selectionState: SelectionState = SelectionState(),
        observedWebView: ObservedWebView = ObservedWebView(),
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        initialContent: String? = nil) {
        self.selectionState = selectionState
        self.observedWebView = observedWebView
        self.markupDelegate = markupDelegate
        self.wkNavigationDelegate = wkNavigationDelegate
        self.wkUIDelegate = wkUIDelegate
        self.userScripts = userScripts
        self.initialContent = initialContent ?? ""
    }

    public func makeCoordinator() -> Coordinator {
        return Coordinator(selectionState: selectionState, markupDelegate: markupDelegate)
    }

    public func makeUIView(context: Context) -> MarkupWKWebView  {
        let webView = MarkupWKWebView()
        // By default, the webView responds to no navigation events unless the navigationDelegate is set
        // during initialization of MarkupWebView.
        webView.navigationDelegate = wkNavigationDelegate
        webView.uiDelegate = wkUIDelegate
        // The coordinator acts as the WKScriptMessageHandler and will receive callbacks
        // from markup.js using window.webkit.messageHandlers.markup.postMessage(<message>);
        let coordinator = context.coordinator
        webView.configuration.userContentController.add(coordinator, name: "markup")
        coordinator.webView = webView
        webView.userScripts = userScripts
        return webView
    }

    public func updateUIView(_ webView: MarkupWKWebView, context: Context) {
        // Set the html, which will be loaded after the "ready" message is received
        webView.html = initialContent
    }
    
}

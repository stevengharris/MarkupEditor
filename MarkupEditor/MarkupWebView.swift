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
///
/// Note we use markupEnv here, which does not publish changes. Then, from it, we pass the selectionState to the
/// Coordinator. This way MarkupWebView does not refresh as SelectionState updates. The SelectionState updates
/// as you type and click around, but there is no need to trigger updateUIView when it changes.
///
/// See the explanation in updateView for a better understanding of when it is called. TL;DR: Hold onto the html in
/// state somewhere external to the MarkupWebView, and pass a binding to that state in init.
public struct MarkupWebView: UIViewRepresentable {
    @EnvironmentObject var markupEnv: MarkupEnv
    public typealias Coordinator = MarkupCoordinator
    /// The initial HTML content to be shown in the MarkupWKWebView.
    public var markupDelegate: MarkupDelegate?
    private var wkNavigationDelegate: WKNavigationDelegate?
    private var wkUIDelegate: WKUIDelegate?
    private var userScripts: [String]?
    private var resourcesUrl: URL?
    private var id: String?
    @Binding private var html: String
    
    /// Initialize with html content that is bound to an externally-held String (and therefore changable)
    ///
    /// When html is updated externally, it will trigger updateUIView, which sets webView's html.
    public init(
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        boundContent: Binding<String>? = nil,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            self.markupDelegate = markupDelegate
            self.wkNavigationDelegate = wkNavigationDelegate
            self.wkUIDelegate = wkUIDelegate
            self.userScripts = userScripts
            _html = boundContent ?? .constant("")
            self.resourcesUrl = resourcesUrl
            self.id = id
        }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(selectionState: markupEnv.selectionState, markupDelegate: markupDelegate)
    }

    public func makeUIView(context: Context) -> MarkupWKWebView  {
        let webView = MarkupWKWebView(html: html, resourcesUrl: resourcesUrl, id: id, markupDelegate: markupDelegate)
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

    /// Called explicitly when html is changed.
    ///
    /// When boundContent was nil in init, updateUIView will be called multiple times as the view appears
    /// as well as when the view goes to background or returns to foreground. This seems to be a byproduct
    /// of nobody holding onto the html binding externally, and creating it on-the-fly in init using .constant.
    /// The same excessive calls to updateView occur if you use .constant in the caller without holding the
    /// html in state properly. The bottom line is that for anything other than a quick demo, you really should
    /// hold the html in state someplace properly and then pass the binding to that state to init.
    public func updateUIView(_ webView: MarkupWKWebView, context: Context) {
        //print("MarkupWebView updateUIView")
        webView.setHtmlIfChanged(html)
    }
    
    /// Dismantle the MarkupWKWebView by stopping loading, removing the userContentController, and letting
    /// the markupDelegate know to teardown the view.
    ///
    /// Note: this doesn't happen in UIKit apps, because they don't use MarkupWebView. Users will need to hook
    /// into the UIViewController lifecycle to accomplish this manually.
    public static func dismantleUIView(_ uiView: MarkupWKWebView, coordinator: MarkupCoordinator) {
        uiView.stopLoading()
        uiView.configuration.userContentController.removeAllScriptMessageHandlers()
        coordinator.markupDelegate?.markupTeardown(uiView)
    }
    
}

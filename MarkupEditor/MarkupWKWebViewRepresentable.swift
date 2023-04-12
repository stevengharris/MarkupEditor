//
//  MarkupWKWebViewRepresentable.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/18/22.
//

import SwiftUI
import WebKit

/// The MarkupWKWebViewRepresentable is the UIViewRepresentable for a UIKit-based MarkupWKWebView instance
/// so MarkupWKWebView can be used in SwiftUI.
///
/// The MarkupWKWebViewRepresentable is used by the MarkupEditorView, but it's a public class in case people want to
/// construct their own SwiftUI views from it.
///
/// The Coordinator will be a WKScriptMessageHandler and handle callbacks that come in from calls in markup.js to
/// window.webkit.messageHandlers.markup.postMessage(message);
///
/// See the explanation in updateView for a better understanding of when updateView is called. TL;DR: Hold onto the
/// html in state somewhere external to the MarkupEditorView, and pass a binding to that state in init.
public struct MarkupWKWebViewRepresentable: UIViewRepresentable {
    public typealias Coordinator = MarkupCoordinator
    /// The initial HTML content to be shown in the MarkupWKWebView.
    public var markupDelegate: MarkupDelegate?
    private var wkNavigationDelegate: WKNavigationDelegate?
    private var wkUIDelegate: WKUIDelegate?
    private var userScripts: [String]?
    private var resourcesUrl: URL?
    private var id: String?
    @Binding private var html: String
    private var selectAfterLoad: Bool
    private var placeholder: String?
    
    /// Initialize with html content that is bound to an externally-held String (and therefore changable)
    ///
    /// When html is updated externally, it will trigger updateUIView, which sets webView's html.
    public init(
        markupDelegate: MarkupDelegate? = nil,
        wkNavigationDelegate: WKNavigationDelegate? = nil,
        wkUIDelegate: WKUIDelegate? = nil,
        userScripts: [String]? = nil,
        html: Binding<String>? = nil,
        placeholder: String? = nil,
        selectAfterLoad: Bool = true,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            self.markupDelegate = markupDelegate
            self.wkNavigationDelegate = wkNavigationDelegate
            self.wkUIDelegate = wkUIDelegate
            self.userScripts = userScripts
            _html = html ?? .constant("")
            self.placeholder = placeholder
            self.selectAfterLoad = selectAfterLoad
            self.resourcesUrl = resourcesUrl
            self.id = id
        }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(markupDelegate: markupDelegate)
    }

    public func makeUIView(context: Context) -> MarkupWKWebView  {
        let webView = MarkupWKWebView(html: html, placeholder: placeholder, selectAfterLoad: selectAfterLoad, resourcesUrl: resourcesUrl, id: id, markupDelegate: markupDelegate)
        // By default, the webView responds to no navigation events unless the navigationDelegate is set
        // during initialization of MarkupEditorUIView.
        webView.navigationDelegate = wkNavigationDelegate
        webView.uiDelegate = wkUIDelegate
        // The coordinator acts as the WKScriptMessageHandler and will receive callbacks
        // from markup.js using window.webkit.messageHandlers.markup.postMessage(<message>);
        let coordinator = context.coordinator
        webView.configuration.userContentController.add(coordinator, name: "markup")
        #if os(iOS)     // Prevent GitHub Actions failure on build
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        coordinator.webView = webView
        webView.userScripts = userScripts
        return webView
    }

    /// Called explicitly when html is changed.
    ///
    /// When boundContent is nil in init, updateUIView will be called multiple times as the view appears
    /// as well as when the view goes to background or returns to foreground. This seems to be a byproduct
    /// of nobody holding onto the html binding externally, and creating it on-the-fly in init using .constant.
    /// The same excessive calls to updateView occur if you use .constant in the caller without holding the
    /// html in state properly. The bottom line is that for anything other than a quick demo, you really should
    /// hold the html in state someplace properly and then pass the binding to that state to init.
    public func updateUIView(_ webView: MarkupWKWebView, context: Context) {
        //print("MarkupWKWebViewRepresentable updateUIView")
        webView.setHtmlIfChanged(html)
    }
    
    /// Dismantle the MarkupWKWebView by stopping loading, removing the userContentController, and letting
    /// the markupDelegate know to teardown the view.
    ///
    /// Note: this doesn't happen in UIKit apps, because they don't use MarkupEditorView. Users will need to hook
    /// into the UIViewController lifecycle to accomplish this manually.
    public static func dismantleUIView(_ uiView: MarkupWKWebView, coordinator: MarkupCoordinator) {
        uiView.stopLoading()
        uiView.configuration.userContentController.removeAllScriptMessageHandlers()
        coordinator.markupDelegate?.markupTeardown(uiView)
    }
    
}

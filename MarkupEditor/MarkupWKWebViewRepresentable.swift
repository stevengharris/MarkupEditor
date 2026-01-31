//
//  MarkupWKWebViewRepresentable.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/18/22.
//

#if !os(macOS)

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
    private var markupConfiguration: MarkupWKWebViewConfiguration?
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
        configuration: MarkupWKWebViewConfiguration? = nil,
        html: Binding<String>? = nil,
        placeholder: String? = nil,
        selectAfterLoad: Bool = true,
        resourcesUrl: URL? = nil,
        id: String? = nil) {
            self.markupDelegate = markupDelegate
            self.wkNavigationDelegate = wkNavigationDelegate
            self.wkUIDelegate = wkUIDelegate
            self.userScripts = userScripts
            self.markupConfiguration = configuration
            _html = html ?? .constant("")
            self.placeholder = placeholder
            self.selectAfterLoad = selectAfterLoad
            self.resourcesUrl = resourcesUrl
            self.id = id
        }
    
    public func makeCoordinator() -> Coordinator {
        return Coordinator(markupDelegate: markupDelegate)
    }

    /// Return the MarkupWKWebView.
    ///
    /// The `isInspectable` attribute for WKWebView was added in iOS 16.4. However, code won't
    /// compile in MacOS versions prior to Ventura (MacOS 10.13). Just checking at runtime for iOS 16.4 doesn't
    /// work for macCatalyst builds on Monterey (MacOS 12.6), because `#available(iOS 16.4, *)`
    /// returns `true`. The only way to make builds work for both macCatalyst and iOS on Ventura+ and
    /// Monterey that I could find was to check on `compiler(>=5.8)` to avoid compiling
    /// `webView.isInspectable = true` on Monterey. Then on Ventura+, we still need a check
    /// on `#available(iOS 16.4, *)`. Now we can build on Ventura+ for iOS 15.5 and 16.4, and for
    /// macCatalyst 16.4, and we can build on Monterey for iOS 15.5 for pre-iOS 16.4 versions. This gating
    /// also allows GitHub actions that use the older MacOS version to work, even if you're working locally on Ventura.
    public func makeUIView(context: Context) -> MarkupWKWebView  {
        let webView = MarkupWKWebView(html: html, placeholder: placeholder, selectAfterLoad: selectAfterLoad, resourcesUrl: resourcesUrl, id: id, markupDelegate: markupDelegate, configuration: markupConfiguration)
        // By default, the webView responds to no navigation events unless the navigationDelegate is set
        // during initialization of MarkupEditorUIView.
        webView.navigationDelegate = wkNavigationDelegate
        webView.uiDelegate = wkUIDelegate
        // The coordinator acts as the WKScriptMessageHandler and will receive callbacks
        // from markup.js using window.webkit.messageHandlers.markup.postMessage(<message>);
        let coordinator = context.coordinator
        webView.setCoordinatorConfiguration(coordinator)
#if compiler(>=5.8)
        if #available(iOS 16.4, *) {
            webView.isInspectable = MarkupEditor.isInspectable
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
        //Logger.webview.debug("MarkupWKWebViewRepresentable updateUIView")
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

#endif

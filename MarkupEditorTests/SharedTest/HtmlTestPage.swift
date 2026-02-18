//
//  HtmlTestPage.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/30/26.
//

import MarkupEditor

/// A class to hold onto a MarkupWKWebView instance that is in the "ready" state.
public class HtmlTestPage: MarkupDelegate {
    var webView: MarkupWKWebView!
    private var coordinator: MarkupCoordinator!
    private var continuation: CheckedContinuation<MarkupWKWebView, Never>?
    var isReady: Bool = false
    
    public init() {}
    
    deinit {
        webView = nil
        coordinator = nil
    }

    /// Return the `webView` after `markupDidLoad` is received.
    public func start(delegate: MarkupDelegate? = nil) async throws -> MarkupWKWebView {
        return await withCheckedContinuation { continuation in
            if isReady {
                continuation.resume(with: .success(self.webView!))
                return
            }
            self.continuation = continuation
            webView = MarkupWKWebView(markupDelegate: delegate ?? self)
            coordinator = MarkupCoordinator(markupDelegate: delegate ?? self, webView: webView)
            webView.setCoordinatorConfiguration(coordinator)
        }
    }

    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    public func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        continuation?.resume(with: .success(view))
        isReady = true
        continuation = nil
    }
}

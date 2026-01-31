//
//  TableActions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import MarkupEditor
import Testing
import WebKit

fileprivate class TableActionsSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("table-actions.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.deleteRow() },
        { webview in webview.deleteCol() },
        { webview in webview.deleteTable() },
        { webview in webview.addRow(.before) },
        { webview in webview.addRow(.after) },
        { webview in webview.addCol(.before) },
        { webview in webview.addCol(.after) },
        { webview in webview.addHeader() },
        { webview in webview.borderTable(.cell) },
        { webview in webview.borderTable(.header) },
        { webview in webview.borderTable(.outer) },
        { webview in webview.borderTable(.none) },
    ]
}
fileprivate typealias Suite = TableActionsSuite

@Suite()
class TableActions: MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var continuation: CheckedContinuation<Bool, Never>?

    /// Once-per test initialization, which is frankly ridiculous, but there is no way to do a once-per-suite initialization
    init() async throws {
        _ = await withCheckedContinuation { continuation in
            self.continuation = continuation
            webView = MarkupWKWebView(markupDelegate: self)
            coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
            webView.setCoordinatorConfiguration(coordinator)
        }
    }
    
    deinit {
        webView = nil
        coordinator = nil
    }
    
    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        continuation?.resume(returning: true)
        continuation = nil
    }
    
    /// Run all the HtmlTests
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

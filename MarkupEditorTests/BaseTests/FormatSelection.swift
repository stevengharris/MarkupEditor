//
//  FormatSelection.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing
import WebKit

fileprivate class FormatSelectionSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("format-selection.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.getSelectionState() { state in #expect(state.bold == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.italic == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.underline == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.strike == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.sup == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.sub == true) } },
        { webview in webview.getSelectionState() { state in #expect(state.code == true) } },
    ]
}
fileprivate typealias Suite = FormatSelectionSuite

@Suite()
class FormatSelection: MarkupDelegate {
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

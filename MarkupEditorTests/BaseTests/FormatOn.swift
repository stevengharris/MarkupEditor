//
//  FormatOn.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/9/25.
//

import MarkupEditor
import Testing

fileprivate class FormatOnSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("format-on.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.bold() },
        { webview in webview.italic() },
        { webview in webview.underline() },
        { webview in webview.strike() },
        { webview in webview.superscript() },
        { webview in webview.subscriptText() },
        { webview in webview.code() },
    ]
}
fileprivate typealias Suite = FormatOnSuite

@Suite()
class FormatOn: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

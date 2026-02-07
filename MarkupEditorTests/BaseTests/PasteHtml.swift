//
//  PasteHtml.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

fileprivate class PasteHtmlSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("paste-html.json").tests
    static var actions: Array<(MarkupWKWebView) -> Void> {
        var actions: Array<(MarkupWKWebView) -> Void> = []
        for test in tests {
            actions.append({ webview in webview.pasteHtml(test.pasteString) })
        }
        return actions
    }
}
fileprivate typealias Suite = PasteHtmlSuite

@Suite()
class PasteHtml: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

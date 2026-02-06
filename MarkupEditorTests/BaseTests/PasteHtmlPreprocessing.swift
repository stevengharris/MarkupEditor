//
//  PasteHtmlPreprocessing.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import MarkupEditor
import Testing

fileprivate class PasteHtmlPreprocessingSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("paste-html-preprocessing.json").tests
    static var actions: Array<((MarkupWKWebView) async -> String?)> {
        var actions: Array<((MarkupWKWebView) async -> String?)> = []
        for test in tests {
            actions.append({ webview in await webview.testPasteHtmlPreprocessing(html: test.startHtml) })
        }
        return actions
    }
}
fileprivate typealias Suite = PasteHtmlPreprocessingSuite

@Suite()
class PasteHtmlPreprocessing: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

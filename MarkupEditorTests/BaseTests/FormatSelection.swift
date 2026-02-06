//
//  FormatSelection.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

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
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

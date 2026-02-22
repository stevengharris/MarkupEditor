//
//  FormatSelection.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class FormatSelectionSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "format-selection", ofType: "json")).tests
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

@Suite(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class FormatSelection {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

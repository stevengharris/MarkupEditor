//
//  PasteText.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class PasteTextSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "paste-text", ofType: "json")).tests
    static var actions: Array<(MarkupWKWebView) -> Void> {
        var actions: Array<(MarkupWKWebView) -> Void> = []
        for test in tests {
            actions.append({ webview in webview.pasteText(test.pasteString) })
        }
        return actions
    }
}
fileprivate typealias Suite = PasteTextSuite

@Suite(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class PasteText {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

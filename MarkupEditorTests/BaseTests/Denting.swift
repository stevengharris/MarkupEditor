//
//  Denting.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/11/25.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class DentingSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "denting", ofType: "json")).tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.indent() },
        { webview in webview.indent() },
        { webview in webview.outdent() },
        { webview in webview.outdent() },
        { webview in webview.indent() },
    ]
}
fileprivate typealias Suite = DentingSuite

@Suite()
@MainActor
class Denting {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

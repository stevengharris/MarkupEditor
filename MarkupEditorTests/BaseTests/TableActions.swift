//
//  TableActions.swift
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

fileprivate class TableActionsSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "table-actions", ofType: "json")).tests
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
@MainActor
class TableActions {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

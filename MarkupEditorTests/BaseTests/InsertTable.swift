//
//  InsertTable.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/12/25.
//

import MarkupEditor
import Testing

fileprivate class InsertTableSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("insert-table.json").tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.insertTable(rows: 2, cols: 2) },
        { webview in webview.insertTable(rows: 2, cols: 2) },
        { webview in webview.insertTable(rows: 2, cols: 2) },
    ]
}
fileprivate typealias Suite = InsertTableSuite

@Suite()
class InsertTable: MarkupDelegate {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

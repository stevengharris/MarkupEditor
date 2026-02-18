//
//  List.swift
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

fileprivate class ListSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "list", ofType: "json")).tests
    static let actions: [(MarkupWKWebView) -> Void] = [
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .OL) },
        { webview in webview.toggleListItem(type: .UL) },
        { webview in webview.outdent() },
        { webview in webview.outdent() },
    ]
}
fileprivate typealias Suite = ListSuite

@Suite(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class List {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

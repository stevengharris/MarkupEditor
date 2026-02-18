//
//  Search.swift
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

fileprivate class SearchSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "search", ofType: "json")).tests
    static let actions: Array<(MarkupWKWebView) async -> String?> = [
        { webview in await search(in: webview, for: tests[0].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[1].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[2].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[3].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[4].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[5].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[6].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[7].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[8].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[9].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[10].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[11].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[12].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[13].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[14].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[15].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[16].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[17].pasteString!, direction: .backward, activate: false)() },
        { webview in await search(in: webview, for: tests[18].pasteString!, direction: .forward, activate: false)() },
        { webview in await search(in: webview, for: tests[19].pasteString!, direction: .backward, activate: false)() },
    ]
    
    static func search(in webview: MarkupWKWebView, for text: String, direction: MarkupEditor.FindDirection, activate: Bool) -> () async -> String? {
        return {
            await webview.search(for: text, direction: direction, activate: activate)
            let state = await webview.getSelectionState()
            return state.selection
        }
    }
}
fileprivate typealias Suite = SearchSuite

@Suite()
@MainActor
class Search {
    static let page: HtmlTestPage = HtmlTestPage()
    
    @Test(.serialized, .timeLimit(.minutes(HtmlTest.timeLimit)), arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        let webView = try await Self.page.start()
        try await htmlTest.run(action: Suite.actions[index], in: webView)
    }

}

//
//  LinkAttributes.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/3/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class LinkAttributesSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "link-attributes", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async -> Void] = [
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "just")
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "pic")
            #expect(state.isFollowable)
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == nil)
            #expect(!state.isFollowable)
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "just")
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "just")
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "just")
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == nil)
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == "https://example.com/x")
            #expect(state.link == "just")
        },
        { webview in
            let state = await webview.getSelectionState()
            #expect(state.href == nil)
        },
    ]
}
fileprivate typealias Suite = LinkAttributesSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class LinkAttributes {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}

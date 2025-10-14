//
//  Search.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/13/25.
//

import MarkupEditor
import Testing
import WebKit

@Suite(.serialized)
class Search: MarkupDelegate {
    // Avoid instantating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("search.json").tests
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loaded = false

    /// Once-per test initialization, which is frankly ridiculous, but there is no way to do a once-per-suite initialization.
    init() async throws {
        try await waitForReady()
        setActions()
    }

    /// Again, ridiculous to set these for every test, but since they need access to `webView`, I don't see
    /// any way around it.
    func setActions() {
        Self.tests[0].stringAction = search(for: Self.tests[0].pasteString!, direction: .forward, activate: false)
        Self.tests[1].stringAction = search(for: Self.tests[1].pasteString!, direction: .backward, activate: false)
        Self.tests[2].stringAction = search(for: Self.tests[2].pasteString!, direction: .forward, activate: false)
        Self.tests[3].stringAction = search(for: Self.tests[3].pasteString!, direction: .backward, activate: false)
        Self.tests[4].stringAction = search(for: Self.tests[4].pasteString!, direction: .forward, activate: false)
        Self.tests[5].stringAction = search(for: Self.tests[5].pasteString!, direction: .backward, activate: false)
        Self.tests[6].stringAction = search(for: Self.tests[6].pasteString!, direction: .forward, activate: false)
        Self.tests[7].stringAction = search(for: Self.tests[7].pasteString!, direction: .backward, activate: false)
        Self.tests[8].stringAction = search(for: Self.tests[8].pasteString!, direction: .forward, activate: false)
        Self.tests[9].stringAction = search(for: Self.tests[9].pasteString!, direction: .backward, activate: false)
        Self.tests[10].stringAction = search(for: Self.tests[10].pasteString!, direction: .forward, activate: false)
        Self.tests[11].stringAction = search(for: Self.tests[11].pasteString!, direction: .backward, activate: false)
        Self.tests[12].stringAction = search(for: Self.tests[12].pasteString!, direction: .forward, activate: false)
        Self.tests[13].stringAction = search(for: Self.tests[13].pasteString!, direction: .backward, activate: false)
        Self.tests[14].stringAction = search(for: Self.tests[14].pasteString!, direction: .forward, activate: false)
        Self.tests[15].stringAction = search(for: Self.tests[15].pasteString!, direction: .backward, activate: false)
        Self.tests[16].stringAction = search(for: Self.tests[16].pasteString!, direction: .forward, activate: false)
        Self.tests[17].stringAction = search(for: Self.tests[17].pasteString!, direction: .backward, activate: false)
        Self.tests[18].stringAction = search(for: Self.tests[18].pasteString!, direction: .forward, activate: false)
        Self.tests[19].stringAction = search(for: Self.tests[19].pasteString!, direction: .backward, activate: false)
    }
    
    func search(for text: String, direction: MarkupEditor.FindDirection, activate: Bool) -> () async -> String? {
        return {
            await self.webView.search(for: text, direction: direction, activate: activate)
            let state = await self.webView.getSelectionState()
            return state.selection
        }
    }

    /// Set up the `webView` and `coordinator` and then wait for them to be ready.
    func waitForReady() async throws {
        try await confirmation { confirmation in
            webView = MarkupWKWebView(markupDelegate: self)
            coordinator = MarkupCoordinator(
                markupDelegate: self,
                webView: webView
            )
            // The coordinator will receive callbacks from markup.js
            // using window.webkit.messageHandlers.test.postMessage(<message>);
            webView.configuration.userContentController.add(
                coordinator,
                name: "markup"
            )
            _ = try await ready(timeout: .seconds(HtmlTest.timeout), confirm: confirmation)
        }
    }

    /// Just yield until `loaded` has been set in the `markupDidLoad` callback. Somewhat adapted from
    /// https://gist.github.com/janodev/32217b09f307da8c96e2cf629c31a8eb
    func ready(timeout: Duration, confirm: Confirmation) async throws {
        let startTime = ContinuousClock.now
        while ContinuousClock.now - startTime < timeout {
            if loaded {
                confirm()
                break
            }
            await Task.yield()
        }
        if !loaded {
            throw TestError.timeout(
                "Load did not succeed within \(timeout) seconds"
            )
        }
    }

    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    func markupDidLoad(_ view: MarkupWKWebView, handler: (() -> Void)?) {
        loaded = true
        handler?()
    }

    /// Run all of the HtmlTests, but serialize them because , once again, we can't do once-per-suite initialization
    @Test(arguments: Self.tests)
    func run(htmlTest: HtmlTest) async throws {
        await htmlTest.run(in: webView)
    }

}

//
//  FormatOn.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/9/25.
//

import MarkupEditor
import Testing
import WebKit

@Suite(.serialized)
class FormatOn: MarkupDelegate {
    // Avoid instantating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("format-on.json").tests
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
        Self.tests[0].action = webView.bold
        Self.tests[1].action = webView.italic
        Self.tests[2].action = webView.underline
        Self.tests[3].action = webView.strike
        Self.tests[4].action = webView.superscript
        Self.tests[5].action = webView.subscriptText
        Self.tests[6].action = webView.code
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

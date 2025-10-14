//
//  Baseline.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/6/25.
//

import Testing
import MarkupEditor
import WebKit

@Suite(.serialized)
class Baseline: MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loaded = false

    /// Once-per test initialization, which is frankly ridiculous, but there is no way to do a once-per-suite initialization
    init() async throws {
        try await waitForReady()
    }
    
    func waitForReady() async throws {
        try await confirmation() { confirmation in
            webView = MarkupWKWebView(markupDelegate: self)
            coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
            // The coordinator will receive callbacks from markup.js
            // using window.webkit.messageHandlers.test.postMessage(<message>);
            webView.configuration.userContentController.add(coordinator, name: "markup")
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
            throw TestError.timeout("Load did not succeed within \(timeout) seconds")
        }
    }
    
    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        loaded = true
        handler?()
    }
    
    @Test(arguments: HtmlTestSuite.from("baseline.json").tests)
    @MainActor
    func run(htmlTest: HtmlTest) async throws {
        await htmlTest.run(in: webView)
    }

}

//
//  DentingMulti.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/11/25.
//

import MarkupEditor
import Testing
import WebKit

@Suite(.serialized)
class DentingMulti: MarkupDelegate {
    // Avoid instantating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
    static let tests = HtmlTestSuite.from("denting-multi.json").tests
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
        Self.tests[0].action = webView.indent
        Self.tests[1].action = webView.outdent
        Self.tests[2].action = webView.indent
        Self.tests[3].action = webView.outdent
        Self.tests[4].action = webView.indent
        Self.tests[5].action = webView.outdent
        Self.tests[6].action = webView.indent
        Self.tests[7].action = webView.outdent
        Self.tests[8].action = webView.indent
        Self.tests[9].action = webView.outdent
        Self.tests[10].action = webView.indent
        Self.tests[11].action = webView.outdent
        Self.tests[12].action = webView.outdent
    }
    
    /*
     "description": "Formatting of selections across nested formats.",
     "tests": [
         {
             "description": "Unbold <p><strong><u>Wo|rd 1 Word 2 Wo|rd 3</u></strong></p>",
             "startHtml": "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
             "endHtml": "<p><u><strong>Wo|</strong>rd 1 Word 2 Wo|<strong>rd 3</strong></u></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
             "startHtml": "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
             "endHtml": "<p><u><strong>Wo|</strong></u><strong>rd 1 Word 2 Wo|</strong><u><strong>rd 3</strong></u></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
             "startHtml": "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
             "endHtml": "<p><u><strong>Wo|</strong></u><em><u><strong>rd 1 Word 2 Wo|</strong></u></em><u><strong>rd 3</strong></u></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "startHtml": "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "endHtml": "<p><strong>Hello </strong><u><strong>bold |</strong>and|<strong> underline</strong></u><strong> world</strong></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "startHtml": "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "endHtml": "<p><strong>Hello </strong><u><strong>bold |</strong></u><strong>and|</strong><u><strong> underline</strong></u><strong> world</strong></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "startHtml": "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
             "endHtml": "<p><strong>Hello </strong><u><strong>bold |</strong></u><em><u><strong>and|</strong></u></em><u><strong> underline</strong></u><strong> world</strong></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "startHtml": "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "endHtml": "<p><em>|Hello </em>wo|<strong>rld</strong></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "startHtml": "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "endHtml": "<p><em><u><strong>|Hello </strong></u></em><u><strong>wo|</strong></u><strong>rld</strong></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "startHtml": "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
             "endHtml": "<p><strong>|Hello wo|rld</strong></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold <p>|Hello <em>world|</em></p>",
             "startHtml": "<p>|Hello <em>world|</em></p>",
             "endHtml": "<p><strong>|Hello </strong><em><strong>world|</strong></em></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline <p>|Hello <em>world|</em></p>",
             "startHtml": "<p>|Hello <em>world|</em></p>",
             "endHtml": "<p><u>|Hello </u><em><u>world|</u></em></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic <p>|Hello <em>world|</em></p>",
             "startHtml": "<p>|Hello <em>world|</em></p>",
             "endHtml": "<p>|Hello world|</p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold <p><u><strong>He|llo wo|rld</strong></u></p>",
             "startHtml": "<p><u><strong>He|llo wo|rld</strong></u></p>",
             "endHtml": "<p><u><strong>He|</strong>llo wo|<strong>rld</strong></u></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline <p><u><strong>He|llo wo|rld</strong></u></p>",
             "startHtml": "<p><u><strong>He|llo wo|rld</strong></u></p>",
             "endHtml": "<p><u><strong>He|</strong></u><strong>llo wo|</strong><u><strong>rld</strong></u></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic <p><u><strong>He|llo wo|rld</strong></u></p>",
             "startHtml": "<p><u><strong>He|llo wo|rld</strong></u></p>",
             "endHtml": "<p><u><strong>He|</strong></u><em><u><strong>llo wo|</strong></u></em><u><strong>rld</strong></u></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "startHtml": "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "endHtml": "<p>|Hello <em>world</em></p><p>Hello <em>wo|<strong>rld</strong></em></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "startHtml": "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "endHtml": "<p><u>|Hello </u><em><u>world</u></em></p><p><u><strong>Hello </strong></u><em><u><strong>wo|</strong></u><strong>rld</strong></em></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "startHtml": "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
             "endHtml": "<p>|Hello world</p><p><strong>Hello wo|</strong><em><strong>rld</strong></em></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Bold across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "startHtml": "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "endHtml": "<p>|Hello <em>world</em></p><p>Hello <em>world|</em></p>",
             "action": "MU.toggleBold()"
         },
         {
             "description": "Underline across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "startHtml": "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "endHtml": "<p><u><strong>|Hello </strong></u><em><u><strong>world</strong></u></em></p><p><u><strong>Hello </strong></u><em><u><strong>world|</strong></u></em></p>",
             "action": "MU.toggleUnderline()"
         },
         {
             "description": "Italic across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "startHtml": "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
             "endHtml": "<p><strong>|Hello world</strong></p><p><strong>Hello world|</strong></p>",
             "action": "MU.toggleItalic()"
         },
         {
             "description": "Unset all italic across paragraphs <p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
             "startHtml": "<p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
             "endHtml": "<p>This <em>is|</em> italic</p><p>Ex|<em>tending across</em> paragraphs</p>",
             "action": "MU.toggleItalic()"
         }
     */

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

    /// Run all the HtmlTests
    @Test(arguments: Self.tests)
    func run(htmlTest: HtmlTest) async throws {
        await htmlTest.run(in: webView)
    }

}

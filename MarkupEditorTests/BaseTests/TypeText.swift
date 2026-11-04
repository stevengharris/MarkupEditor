//
//  TypeText.swift
//  MarkupEditor
//
//  Created by Steven Harris on 11/4/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class TypeTextSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "type-text", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in try await webview.executeJavaScript("MU.testTypeText('> ')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('## ')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('abc')") },
        { webview in try await webview.executeJavaScript("MU.testTypeText('XYZ')") },
        { webview in
            try await webview.executeJavaScript("MU.testTypeText('> ')")
            try await webview.executeJavaScript("MU.testTypeKey('Backspace')")
        },
        { webview in try await webview.executeJavaScript("MU.testTypeText('XYZ')") },
        { webview in
            for key in ["Mod-Enter", "Bogus-Enter", "Ctrl-Mod--"] {
                await #expect(throws: (any Error).self) { try await webview.executeJavaScript("MU.testTypeKey('\(key)')") }
            }
        },
        { webview in
            for key in ["-", "Ctrl--"] {
                await #expect(throws: Never.self) { try await webview.executeJavaScript("MU.testTypeKey('\(key)')") }
            }
        },
        { webview in try await webview.executeJavaScript("MU.testTypeText('c\\nd')") },
        { webview in
            let handled = try await webview.executeJavaScript("MU.testTypeKey('Ctrl-Shift-1')") as? Bool
            #expect(handled == true)
        },
        { webview in
            let handled = try await webview.executeJavaScript("MU.testTypeKey('Ctrl-s')") as? Bool
            #expect(handled == true)
        },
    ]
}
fileprivate typealias Suite = TypeTextSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class TypeText {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}

//
//  Correction.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/18/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class CorrectionSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "correction", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in if await webview.canUndo() { webview.setHtml("<p>canUndo: true</p>") } else { webview.setHtml("<p>canUndo: false</p>") } },
        { webview in if await webview.canRedo() { webview.setHtml("<p>canRedo: true</p>") } else { webview.setHtml("<p>canRedo: false</p>") } },
        { webview in try await webview.bold(); if await webview.canUndo() { webview.setHtml("<p>canUndo: true</p>") } else { webview.setHtml("<p>canUndo: false</p>") } },
        { webview in try await webview.bold(); if await webview.canRedo() { webview.setHtml("<p>canRedo: true</p>") } else { webview.setHtml("<p>canRedo: false</p>") } },
        { webview in try await webview.bold(); await webview.undo(); if await webview.canRedo() { webview.setHtml("<p>canRedo: true</p>") } else { webview.setHtml("<p>canRedo: false</p>") } },
        { webview in try await webview.bold(); await webview.undo(); if await webview.canUndo() { webview.setHtml("<p>canUndo: true</p>") } else { webview.setHtml("<p>canUndo: false</p>") } },
        { webview in try await webview.bold(); await webview.undo(); await webview.redo(); if await webview.canUndo() { webview.setHtml("<p>canUndo: true</p>") } else { webview.setHtml("<p>canUndo: false</p>") } },
        { webview in try await webview.bold(); await webview.undo(); await webview.redo(); if await webview.canRedo() { webview.setHtml("<p>canRedo: true</p>") } else { webview.setHtml("<p>canRedo: false</p>") } },
    ]
}
fileprivate typealias Suite = CorrectionSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class Correction {
    let page: HtmlTestPage = HtmlTestPage()
    
    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }

}

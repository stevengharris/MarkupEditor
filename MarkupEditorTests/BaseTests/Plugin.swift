//
//  Plugin.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/27/26.
//

import Foundation
import MarkupEditor
import Testing
#if SWIFT_PACKAGE
import SharedTest
#endif

fileprivate class PluginSuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "plugin", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in try await registerPlugin(in: webview) },
        { webview in try await checkManifestShape(in: webview) },
    ]

    /// Register a test plugin inline and verify that getPluginManifest exposes name and
    /// extension but strips the export and import function references.
    @MainActor
    static func registerPlugin(in webview: MarkupWKWebView) async throws {
        try await webview.executeJavaScript(
            "MU.registerPlugin({name: 'Reg Test', extension: 'rt', export: async (c) => c, import: async (c) => c}, 'Reg Test')"
        )
        let manifest = await getManifest(from: webview)
        let entry = manifest?.first { $0["name"] == "Reg Test" }
        #expect(entry != nil)
        #expect(entry?["name"] == "Reg Test")
        #expect(entry?["extension"] == "rt")
        #expect(entry?["export"] == nil)
        #expect(entry?["import"] == nil)
    }

    /// Register a test plugin inline and verify that every manifest entry contains only
    /// the name and extension keys — no function references leak through.
    @MainActor
    static func checkManifestShape(in webview: MarkupWKWebView) async throws {
        try await webview.executeJavaScript(
            "MU.registerPlugin({name: 'Reg Test', extension: 'rt', export: async (c) => c, import: async (c) => c}, 'Reg Test')"
        )
        let manifest = await getManifest(from: webview)
        for entry in manifest ?? [] {
            #expect(Set(entry.keys) == ["name", "extension"])
        }
    }

    @MainActor
    private static func getManifest(from webview: MarkupWKWebView) async -> [[String: String]]? {
        await withCheckedContinuation { continuation in
            webview.getPluginManifest { continuation.resume(returning: $0) }
        }
    }
}
fileprivate typealias Suite = PluginSuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class Plugin {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }
}

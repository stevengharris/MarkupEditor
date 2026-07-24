//
//  PluginRegistry.swift
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

fileprivate class PluginRegistrySuite {
    // Avoid instantiating the test suite for every @Test, because Swift Testing has no
    // built-in support for once-per-Suite initialization.
#if SWIFT_PACKAGE
    static let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
#else
    static let bundle = Bundle(for: HtmlTestSuite.self)
#endif
    static let tests = HtmlTestSuite.from(path: bundle.path(forResource: "pluginregistry", ofType: "json")).tests
    @MainActor static let actions: [@MainActor (MarkupWKWebView) async throws -> Void] = [
        { webview in try await registerAndGetPlugins(in: webview) },
        { webview in try await getPluginsByType(in: webview) },
        { webview in try await getPluginByName(in: webview) },
        { webview in try await unregisterRemovesPlugin(in: webview) },
    ]

    /// Register a plugin and verify getPlugins() reports it with the fields it was registered with.
    @MainActor
    static func registerAndGetPlugins(in webview: MarkupWKWebView) async throws {
        try await webview.registerPlugin(Plugin(name: "Reg Test", type: "renderer", filename: "reg-test.js"))
        let entry = await webview.getPlugins().first { $0.name == "Reg Test" }
        #expect(entry != nil)
        #expect(entry?.type == "renderer")
        #expect(entry?.filename == "reg-test.js")
    }

    /// getPlugins(type:) returns only plugins matching that type.
    @MainActor
    static func getPluginsByType(in webview: MarkupWKWebView) async throws {
        try await webview.registerPlugin(Plugin(name: "Exporter Test", type: "exporter", filename: "exporter-test.js"))
        let entries = await webview.getPlugins(type: "exporter")
        #expect(entries.contains { $0.name == "Exporter Test" })
        #expect(!entries.contains { $0.name == "Reg Test" })
    }

    /// getPlugin(name:) returns the plugin with that name, or nil if not found.
    @MainActor
    static func getPluginByName(in webview: MarkupWKWebView) async throws {
        try await webview.registerPlugin(Plugin(name: "Solo Test", type: "importer", filename: "solo-test.js"))
        let entry = await webview.getPlugin(name: "Solo Test")
        #expect(entry != nil)
        #expect(entry?.type == "importer")
        #expect(entry?.filename == "solo-test.js")
        let missing = await webview.getPlugin(name: "No Such Plugin")
        #expect(missing == nil)
    }

    /// unregisterPlugin removes the plugin from the registry.
    @MainActor
    static func unregisterRemovesPlugin(in webview: MarkupWKWebView) async throws {
        let plugin = Plugin(name: "Removable Test", type: "renderer", filename: "removable-test.js")
        try await webview.registerPlugin(plugin)
        try await webview.unregisterPlugin(plugin)
        let entry = await webview.getPlugin(name: "Removable Test")
        #expect(entry == nil)
    }
}
fileprivate typealias Suite = PluginRegistrySuite

@Suite(.timeLimit(.minutes(HtmlTest.timeLimit)))
@MainActor
class PluginRegistry {
    let page: HtmlTestPage = HtmlTestPage()

    @Test(arguments: zip(Suite.tests, 0..<Suite.tests.count))
    func run(htmlTest: HtmlTest, index: Int) async throws {
        try await page.start()
        if let webView = page.webView {
            try await htmlTest.run(action: Suite.actions[index], in: webView)
        }
    }
}

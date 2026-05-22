import Testing
import Foundation
@testable import MarkupEditor

@Suite
struct PluginFileEntryTests {

    @Test func codableRoundTrip() throws {
        let entry = PluginFileEntry(name: "Markdown", path: "/plugins/markup-editor-markdown.js")
        let data = try JSONEncoder().encode(entry)
        let decoded = try JSONDecoder().decode(PluginFileEntry.self, from: data)
        #expect(decoded.name == entry.name)
        #expect(decoded.path == entry.path)
    }

    @Test func pluginFilesDefaultsToNil() {
        let config = MarkupWKWebViewConfiguration()
        #expect(config.pluginFiles == nil)
    }

    @Test func pluginFilesCanBeSet() {
        var config = MarkupWKWebViewConfiguration()
        config.pluginFiles = [PluginFileEntry(name: "Markdown", path: "/plugins/markup-editor-markdown.js")]
        #expect(config.pluginFiles?.count == 1)
        #expect(config.pluginFiles?.first?.name == "Markdown")
    }

    // MARK: - pluginsAttribute

    @Test func pluginsAttributeIsNilWhenPluginFilesIsNil() {
        #expect(MarkupWKWebView.pluginsAttribute(for: nil) == nil)
    }

    @Test func pluginsAttributeIsNilWhenPluginFilesIsEmpty() {
        #expect(MarkupWKWebView.pluginsAttribute(for: []) == nil)
    }

    @Test func pluginsAttributeContainsFilenameOnly() {
        let entry = PluginFileEntry(name: "Markdown", path: "/some/absolute/path/markup-editor-markdown.js")
        let result = MarkupWKWebView.pluginsAttribute(for: [entry])
        // Expect a JSON array with only the last path component, HTML-attribute-encoded
        #expect(result == "[&quot;markup-editor-markdown.js&quot;]")
    }

    @Test func pluginsAttributeContainsMultipleFilenames() {
        let entries = [
            PluginFileEntry(name: "Markdown", path: "/path/markup-editor-markdown.js"),
            PluginFileEntry(name: "Highlight", path: "/other/markup-editor-highlight.js")
        ]
        let result = MarkupWKWebView.pluginsAttribute(for: entries)
        #expect(result == "[&quot;markup-editor-markdown.js&quot;,&quot;markup-editor-highlight.js&quot;]")
    }

}

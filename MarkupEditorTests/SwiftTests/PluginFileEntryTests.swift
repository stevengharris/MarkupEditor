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

}

//
//  Plugin.swift
//  MarkupEditor
//

/// A single plugin entry as recorded in MU's plugin registry.
/// `filename` is a bare filename (e.g. "markupeditor-mermaid.js") when the
/// plugin is backed by a JS module; nil otherwise.
public struct Plugin: Codable, Equatable, Hashable {

    public static func == (lhs: Plugin, rhs: Plugin) -> Bool {
        lhs.name == rhs.name && lhs.type == rhs.type && lhs.filename == rhs.filename
    }

    public let name: String         // Name to display for the plugin
    public let type: String         // Plugin type, e.g. "renderer" or "exporter"
    public let filename: String?    // JS module filename, if backed by one
    public let ext: String?         // For an exporter, the file extension to be used by default

    public init(name: String, type: String, filename: String? = nil, ext: String? = nil) {
        self.name = name
        self.type = type
        self.filename = filename
        self.ext = ext
    }

    public nonisolated init(from decoder: any Decoder) throws {
        enum Keys: String, CodingKey { case name, type, filename, ext }
        let c = try decoder.container(keyedBy: Keys.self)
        name = try c.decode(String.self, forKey: .name)
        type = try c.decode(String.self, forKey: .type)
        filename = try c.decodeIfPresent(String.self, forKey: .filename)
        ext = try c.decodeIfPresent(String.self, forKey: .ext)
    }

}

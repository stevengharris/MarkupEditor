//
//  ToolbarConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/24/26.
//

import OSLog

/// A struct that is populated from Resources/toolbarconfig.json and provides easy access to its settings. The json file
/// is the source of truth, and its settings will be used by the MarkupWKWebView unless overridden. The settings can
/// be conveniently modified using the various static methods, such as `markdown`.
///
/// Note that toolbarconfig.json originates in [markupeditor-base](https://github.com/stevengharris/markupeditor-base)
/// but is modified locally to conform more with the original MarkupEditor and Mac user expectations of SFSymbols icons.
public struct ToolbarConfig: JSONConfigurable {
    public var visibility: [String: Bool]
    public var ordering: [String: Int]
    public var insertBar: [String: Bool]
    public var formatBar: [String: Bool]
    public var styleMenu: [String: String?]
    public var styleBar: [String: Bool]
    public var tableMenu: [String: Bool]
    public var augmentation: [String: Bool?]
    public var icons: [String: String]
    
    private static func load() -> ToolbarConfig {
    #if SWIFT_PACKAGE
        let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
    #else
        let bundle = Bundle(for: MarkupWKWebView.self)
    #endif
        do {
            guard let path = bundle.path(forResource: "toolbarconfig", ofType: "json") else {
                fatalError("The toolbarconfig.json resource could not be found in bundle")
            }
            let url = URL(filePath: path, directoryHint: .notDirectory)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ToolbarConfig.self, from: data)
        } catch let error {
            Logger.config.error("\(error.localizedDescription)")
            return none()
        }
    }
    
    public static func full() -> ToolbarConfig {
        load()
    }
    
    public static func markdown(_ correction: Bool = false) -> ToolbarConfig {
        var markdown = load()
        markdown.visibility["correctionBar"] = correction
        markdown.formatBar["underline"] = false
        markdown.formatBar["subscript"] = false
        markdown.formatBar["superscript"] = false
        return markdown
    }
    
    public static func none() -> ToolbarConfig {
        ToolbarConfig(
            visibility: [:],
            ordering: [:],
            insertBar: [:],
            formatBar: [:],
            styleMenu: [:],
            styleBar: [:],
            tableMenu: [:],
            augmentation: [:],
            icons: [:]
        )
    }
    
    /// Override the protocol default to return `none()` on decode failure instead of nil.
    public static func fromJSON(_ string: String) -> ToolbarConfig {
        (self as JSONConfigurable.Type).fromJSON(string) as? ToolbarConfig ?? none()
    }
    
    /// A nil value for `styleMenu[tag.lowerCased()]` means the tag should not be in the menu
    public func name(forTag tag: String) -> String? {
        styleMenu[tag.lowercased()]!
    }
    
}

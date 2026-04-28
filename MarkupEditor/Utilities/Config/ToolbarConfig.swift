//
//  ToolbarConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/24/26.
//

import OSLog

/// A struct that is loaded from toolbarconfig.json and provides easy access to its settings. The loading operation
/// first looks for the json file in the `main` bundle, and if it is not present, falls back to the json file provided
/// in the Resources directory of the MarkupEditor package. This provides a simple mechanism for applications
/// to change the defaults, by providing their own version of the json file in their application. The json file
/// is the source of truth, and its settings will be used by the MarkupWKWebView.
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
    public var help: [String : String]
    public var augmentation: [String: Bool?]
    public var icons: [String: String]
    
    public init(
        visibility: [String: Bool],
        ordering: [String: Int],
        insertBar: [String: Bool],
        formatBar: [String: Bool],
        styleMenu: [String: String?],
        styleBar: [String: Bool],
        tableMenu: [String: Bool],
        help: [String : String],
        augmentation: [String: Bool?],
        icons: [String: String]
    ) {
        self.visibility = visibility
        self.ordering = ordering
        self.insertBar = insertBar
        self.formatBar = formatBar
        self.styleMenu = styleMenu
        self.styleBar = styleBar
        self.tableMenu = tableMenu
        self.help = help
        self.augmentation = augmentation
        self.icons = icons
    }
    
    public init() {
        let config = ToolbarConfig.load()
        visibility = config.visibility
        ordering = config.ordering
        insertBar = config.insertBar
        formatBar = config.formatBar
        styleMenu = config.styleMenu
        styleBar = config.styleBar
        tableMenu = config.tableMenu
        help = config.help
        augmentation = config.augmentation
        icons = config.icons
    }
    
    private static func load() -> ToolbarConfig {
        let mainBundle = Bundle.main
        #if SWIFT_PACKAGE
                let packageBundle = Bundle.module   // Bundle.module is only accessible within BaseTests
        #else
                let packageBundle = Bundle(for: MarkupWKWebView.self)
        #endif
        guard let path =
                mainBundle.path(forResource: "toolbarconfig", ofType: "json") ??
                packageBundle.path(forResource: "toolbarconfig", ofType: "json") else {
            Logger.config.error("The toolbarconfig.json resource could not be found in bundle")
            return ToolbarConfig.empty()
        }
        let url = URL(filePath: path, directoryHint: .notDirectory)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ToolbarConfig.self, from: data)
        } catch let error {
            Logger.config.error("Error decoding ToolbarConfig from \(path): \(error.localizedDescription)")
            return ToolbarConfig.empty()
        }
    }
    
    private static func empty() -> ToolbarConfig {
        ToolbarConfig(
            visibility: [:],
            ordering: [:],
            insertBar: [:],
            formatBar: [:],
            styleMenu: [:],
            styleBar: [:],
            tableMenu: [:],
            help: [:],
            augmentation: [:],
            icons: [:]
        )
    }
    
    /// Override the protocol default to return `none()` on decode failure instead of nil.
    public static func fromJSON(_ string: String) -> ToolbarConfig {
        (self as JSONConfigurable.Type).fromJSON(string) as? ToolbarConfig ?? ToolbarConfig.empty()
    }
    
    /// A nil value for `styleMenu[tag.lowerCased()]` means the tag should not be in the menu
    public func name(forTag tag: String) -> String? {
        styleMenu[tag.lowercased()]!
    }
    
}

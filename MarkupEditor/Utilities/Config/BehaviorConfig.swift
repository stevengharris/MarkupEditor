//
//  BehaviorConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/26.
//

import Foundation
import OSLog

/// A struct that is loaded from behaviorconfig.json and provides easy access to its settings. The loading operation
/// first looks for the json file in the `main` bundle, and if it is not present, falls back to the json file provided
/// in the Resources directory of the MarkupEditor package. This provides a simple mechanism for applications
/// to change the defaults, by providing their own version of the json file in their application. The json file
/// is the source of truth, and its settings will be used by the MarkupWKWebView.
///
/// Note that behaviorconfig.json originates in [markupeditor-base](https://github.com/stevengharris/markupeditor-base).
public struct BehaviorConfig: JSONConfigurable {
    public var focusAfterLoad: Bool
    public var selectImage: Bool
    public var insertLink: Bool
    public var insertImage: Bool
    public var insertTable: Bool
    public var highlightCode: Bool
    public var markdownShorthand: Bool

    public init(
        focusAfterLoad: Bool,
        selectImage: Bool,
        insertLink: Bool,
        insertImage: Bool,
        insertTable: Bool,
        highlightCode: Bool,
        markdownShorthand: Bool
    ) {
        self.focusAfterLoad = focusAfterLoad
        self.selectImage = selectImage
        self.insertLink = insertLink
        self.insertImage = insertImage
        self.insertTable = insertTable
        self.highlightCode = highlightCode
        self.markdownShorthand = markdownShorthand
    }

    public init() {
        let config = BehaviorConfig.load()
        focusAfterLoad = config.focusAfterLoad
        selectImage = config.selectImage
        insertLink = config.insertLink
        insertImage = config.insertImage
        insertTable = config.insertTable
        highlightCode = config.highlightCode
        markdownShorthand = config.markdownShorthand
    }

    private enum CodingKeys: String, CodingKey {
        case focusAfterLoad, selectImage, insertLink, insertImage, insertTable, highlightCode, markdownShorthand
    }

    /// Custom decoder so a behaviorconfig.json predating markdownShorthand or insertTable still decodes
    /// successfully instead of failing the whole struct (and falling back to `empty()`, discarding every
    /// other setting in that file) over one missing key.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        focusAfterLoad = try container.decode(Bool.self, forKey: .focusAfterLoad)
        selectImage = try container.decode(Bool.self, forKey: .selectImage)
        insertLink = try container.decode(Bool.self, forKey: .insertLink)
        insertImage = try container.decode(Bool.self, forKey: .insertImage)
        insertTable = try container.decodeIfPresent(Bool.self, forKey: .insertTable) ?? false
        highlightCode = try container.decode(Bool.self, forKey: .highlightCode)
        markdownShorthand = try container.decodeIfPresent(Bool.self, forKey: .markdownShorthand) ?? true
    }

    private static func load() -> BehaviorConfig {
        let mainBundle = Bundle.main
        #if SWIFT_PACKAGE
                let packageBundle = Bundle.module   // Bundle.module is only accessible within BaseTests
        #else
                let packageBundle = Bundle(for: MarkupWKWebView.self)
        #endif
        guard let path =
                mainBundle.path(forResource: "behaviorconfig", ofType: "json") ??
                packageBundle.path(forResource: "behaviorconfig", ofType: "json") else {
            Logger.config.error("The behaviorconfig.json resource could not be found in bundle")
            return BehaviorConfig.empty()
        }
        let url = URL(filePath: path, directoryHint: .notDirectory)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BehaviorConfig.self, from: data)
        } catch let error {
            Logger.config.error("Error decoding BehaviorConfig from \(path): \(error.localizedDescription)")
            return BehaviorConfig.empty()
        }
    }

    private static func empty() -> BehaviorConfig {
        BehaviorConfig(
            focusAfterLoad: false,
            selectImage: false,
            insertLink: false,
            insertImage: false,
            insertTable: false,
            highlightCode: true,
            markdownShorthand: true
        )
    }
    
    /// Override the protocol default to return `none()` on decode failure instead of nil.
    public static func fromJSON(_ string: String) -> BehaviorConfig {
        (self as JSONConfigurable.Type).fromJSON(string) as? BehaviorConfig ?? empty()
    }

}

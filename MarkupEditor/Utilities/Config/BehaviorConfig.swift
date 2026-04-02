//
//  BehaviorConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/26.
//

import Foundation
import OSLog

/// A struct that is populated from Resources/behaviorconfig.json and provides easy access to its settings. The json file
/// is the source of truth, and its settings will be used by the MarkupWKWebView unless overridden. The settings can
/// be conveniently modified using the various static methods, such as `desktop`.
///
/// Note that behaviorconfig.json originates in [markupeditor-base](https://github.com/stevengharris/markupeditor-base).
public struct BehaviorConfig: JSONConfigurable {
    public var focusAfterLoad: Bool
    public var selectImage: Bool
    public var insertLink: Bool
    public var insertImage: Bool
    public var showStyle: Bool

    private static func load() -> BehaviorConfig {
    #if SWIFT_PACKAGE
        let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
    #else
        let bundle = Bundle(for: MarkupWKWebView.self)
    #endif
        do {
            guard let path = bundle.path(forResource: "behaviorconfig", ofType: "json") else {
                fatalError("The behaviorconfig.json resource could not be found in bundle")
            }
            let url = URL(filePath: path, directoryHint: .notDirectory)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(BehaviorConfig.self, from: data)
        } catch let error {
            Logger.config.error("\(error.localizedDescription)")
            return none()
        }
    }
    
    public static func standard() -> BehaviorConfig {
        load()
    }
    
    public static func desktop() -> BehaviorConfig {
        BehaviorConfig(
            focusAfterLoad: true,
            selectImage: true,
            insertLink: false,
            insertImage: false,
            showStyle: true
        )
    }

    public static func none() -> BehaviorConfig {
        BehaviorConfig(
            focusAfterLoad: false,
            selectImage: false,
            insertLink: false,
            insertImage: false,
            showStyle: false
        )
    }
    
    /// Override the protocol default to return `none()` on decode failure instead of nil.
    public static func fromJSON(_ string: String) -> BehaviorConfig {
        (self as JSONConfigurable.Type).fromJSON(string) as? BehaviorConfig ?? none()
    }

}

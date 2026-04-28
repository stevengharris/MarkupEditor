//
//  KeymapConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/27/26.
//

import Foundation
import OSLog

#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

/// A struct that is loaded from keymapconfig.json and provides easy access to its settings. The loading operation
/// first looks for the json file in the `main` bundle, and if it is not present, falls back to the json file provided
/// in the Resources directory of the MarkupEditor package. This provides a simple mechanism for applications
/// to change the defaults, by providing their own version of the json file in their application. The json file
/// is the source of truth, and its settings will be used by the MarkupWKWebView.
///
/// The keymap format uses modifier prefixes:
/// - `Mod-` maps to Command
/// - `Ctrl-` maps to Control
/// - `Shift-` maps to Shift
///
/// Values can be a single string or an array of strings; only the first binding is used for menus.
///
/// Note that keymapconfig.json originates in [markupeditor-base](https://github.com/stevengharris/markupeditor-base).
public struct KeymapConfig: JSONConfigurable {
    public var bindings: [String: [KeyBinding]]
    
    public init() {
        let config = KeymapConfig.load()
        bindings = config.bindings
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)
        var result = [String: [KeyBinding]]()
        for key in container.allKeys {
            if let array = try? container.decode([KeyBinding].self, forKey: key) {
                result[key.stringValue] = array
            } else if let single = try? container.decode(KeyBinding.self, forKey: key) {
                result[key.stringValue] = [single]
            }
        }
        bindings = result
    }
    
    private init(bindings: [String: [KeyBinding]]) {
        self.bindings = bindings
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        for (key, value) in bindings {
            let codingKey = AnyCodingKey(stringValue: key)
            if value.count == 1, let single = value.first {
                try container.encode(single, forKey: codingKey)
            } else {
                try container.encode(value, forKey: codingKey)
            }
        }
    }
    
    private static func load() -> KeymapConfig {
        let mainBundle = Bundle.main
        #if SWIFT_PACKAGE
                let packageBundle = Bundle.module   // Bundle.module is only accessible within BaseTests
        #else
                let packageBundle = Bundle(for: MarkupWKWebView.self)
        #endif
        guard let path =
                mainBundle.path(forResource: "keymapconfig", ofType: "json") ??
                packageBundle.path(forResource: "keymapconfig", ofType: "json") else {
            Logger.config.error("The keymapconfig.json resource could not be found in bundle")
            return KeymapConfig.empty()
        }
        let url = URL(filePath: path, directoryHint: .notDirectory)
        do {
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeymapConfig.self, from: data)
        } catch let error {
            Logger.config.error("Error decoding KeymapConfig from \(path): \(error.localizedDescription)")
            return KeymapConfig.empty()
        }
    }
    
    private static func empty() -> KeymapConfig {
        KeymapConfig(bindings: [:])
    }
    
    /// Look up a binding by action name. Returns nil if no binding exists.
    public func binding(for action: String) -> KeyBinding? {
        bindings[action]?.first
    }
    
    /// Override the protocol default to return `none()` on decode failure instead of nil.
    public static func fromJSON(_ string: String) -> KeymapConfig {
        (self as JSONConfigurable.Type).fromJSON(string) as? KeymapConfig ?? empty()
    }
}

/// A general-purpose CodingKey for dynamic string keys.
private struct AnyCodingKey: CodingKey {
    let stringValue: String
    var intValue: Int? { nil }
    
    init(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { return nil }
}

/// Represents a parsed key binding with its key equivalent and modifier string.
///
/// The modifier string uses the same prefix format as the JSON config:
/// `Mod-` for Command, `Ctrl-` for Control, `Shift-` for Shift.
/// Use the `modifierMask` computed property to get platform-appropriate modifier flags.
public struct KeyBinding: Codable {
    public let keyEquivalent: String
    public let modifierString: String
    
    /// The spec string representation (e.g. "Mod-b", "Ctrl-Shift-3").
    public var spec: String { modifierString + keyEquivalent }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let spec = try container.decode(String.self)
        let parsed = KeyBinding.from(spec: spec)
        self.keyEquivalent = parsed.keyEquivalent
        self.modifierString = parsed.modifierString
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(spec)
    }
    
    public init(keyEquivalent: String, modifierString: String) {
        self.keyEquivalent = keyEquivalent
        self.modifierString = modifierString
    }
    
    #if canImport(AppKit) && !targetEnvironment(macCatalyst)
    /// Parse the modifier string into NSEvent.ModifierFlags (macOS).
    public var modifierMask: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        var remaining = modifierString
        while true {
            if remaining.hasPrefix("Mod-") {
                flags.insert(.command)
                remaining = String(remaining.dropFirst(4))
            } else if remaining.hasPrefix("Ctrl-") {
                flags.insert(.control)
                remaining = String(remaining.dropFirst(5))
            } else if remaining.hasPrefix("Shift-") {
                flags.insert(.shift)
                remaining = String(remaining.dropFirst(6))
            } else {
                break
            }
        }
        return flags
    }
    #else
    /// Parse the modifier string into UIKeyModifierFlags (iOS / Mac Catalyst).
    public var modifierMask: UIKeyModifierFlags {
        var flags: UIKeyModifierFlags = []
        var remaining = modifierString
        while true {
            if remaining.hasPrefix("Mod-") {
                flags.insert(.command)
                remaining = String(remaining.dropFirst(4))
            } else if remaining.hasPrefix("Ctrl-") {
                flags.insert(.control)
                remaining = String(remaining.dropFirst(5))
            } else if remaining.hasPrefix("Shift-") {
                flags.insert(.shift)
                remaining = String(remaining.dropFirst(6))
            } else {
                break
            }
        }
        return flags
    }
    #endif
    
    /// Parse a spec string like "Ctrl-Shift-3" or "Mod-b" into a KeyBinding.
    public static func from(spec: String) -> KeyBinding {
        var modifierParts = ""
        var remaining = spec
        while true {
            if remaining.hasPrefix("Mod-") {
                modifierParts += "Mod-"
                remaining = String(remaining.dropFirst(4))
            } else if remaining.hasPrefix("Ctrl-") {
                modifierParts += "Ctrl-"
                remaining = String(remaining.dropFirst(5))
            } else if remaining.hasPrefix("Shift-") {
                modifierParts += "Shift-"
                remaining = String(remaining.dropFirst(6))
            } else {
                break
            }
        }
        return KeyBinding(keyEquivalent: remaining.lowercased(), modifierString: modifierParts)
    }
}

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

/// A struct that is populated from Resources/keymapconfig.json and provides easy access to its settings.
/// The json file is the source of truth, and its settings will be used by the MarkupWKWebView unless overridden.
///
/// The keymap format uses modifier prefixes:
/// - `Mod-` maps to Command
/// - `Ctrl-` maps to Control
/// - `Shift-` maps to Shift
///
/// Values can be a single string or an array of strings; only the first binding is used for menus.
public struct KeymapConfig: JSONConfigurable {
    public let bindings: [String: [KeyBinding]]
    
    public init(bindings: [String: [KeyBinding]]) {
        self.bindings = bindings
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
        self.bindings = result
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

    /// Load from the bundled keymapconfig.json resource.
    private static func load() -> KeymapConfig {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: MarkupWKWebView.self)
        #endif
        do {
            guard let path = bundle.path(forResource: "keymapconfig", ofType: "json") else {
                fatalError("The keymapconfig.json resource could not be found in bundle")
            }
            let url = URL(filePath: path, directoryHint: .notDirectory)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(KeymapConfig.self, from: data)
        } catch let error {
            Logger.config.error("\(error.localizedDescription)")
            return none()
        }
    }
    
    public static func standard() -> KeymapConfig {
        load()
    }
    
    public static func none() -> KeymapConfig {
        KeymapConfig(bindings: [:])
    }
    
    /// Look up a binding by action name. Returns nil if no binding exists.
    public func binding(for action: String) -> KeyBinding? {
        bindings[action]?.first
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




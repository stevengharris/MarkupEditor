//
//  KeymapConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/27/26.
//

import Foundation

#if os(macOS)
import AppKit

/// Represents a parsed key binding with its key equivalent and modifier mask for NSMenuItem.
public struct KeyBinding {
    public let keyEquivalent: String
    public let modifierMask: NSEvent.ModifierFlags
}

/// Loads and parses keymapconfig.json to provide key bindings for menu items.
///
/// The keymap format uses modifier prefixes:
/// - `Mod-` maps to Command
/// - `Ctrl-` maps to Control
/// - `Shift-` maps to Shift
///
/// Values can be a single string or an array of strings; only the first binding is used for menus.
public struct KeymapConfig {
    public let bindings: [String: KeyBinding]

    /// Load from the bundled keymapconfig.json resource.
    public static func load() -> KeymapConfig? {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: MarkupWKWebView.self)
        #endif
        guard let path = bundle.path(forResource: "keymapconfig", ofType: "json") else { return nil }
        let url = URL(filePath: path, directoryHint: .notDirectory)
        guard let data = try? Data(contentsOf: url) else { return nil }
        guard let raw = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        var bindings = [String: KeyBinding]()
        for (key, value) in raw {
            let spec: String
            if let str = value as? String {
                spec = str
            } else if let arr = value as? [String], let first = arr.first {
                spec = first
            } else {
                continue
            }
            bindings[key] = parseSpec(spec)
        }
        return KeymapConfig(bindings: bindings)
    }

    /// Parse a single keymap spec string like "Ctrl-Shift-3" or "Mod-b" into a KeyBinding.
    static func parseSpec(_ spec: String) -> KeyBinding {
        var modifiers: NSEvent.ModifierFlags = []
        var remaining = spec

        while true {
            if remaining.hasPrefix("Mod-") {
                modifiers.insert(.command)
                remaining = String(remaining.dropFirst(4))
            } else if remaining.hasPrefix("Ctrl-") {
                modifiers.insert(.control)
                remaining = String(remaining.dropFirst(5))
            } else if remaining.hasPrefix("Shift-") {
                modifiers.insert(.shift)
                remaining = String(remaining.dropFirst(6))
            } else {
                break
            }
        }

        // The remaining string is the key character
        let key = remaining.lowercased()
        return KeyBinding(keyEquivalent: key, modifierMask: modifiers)
    }

    /// Look up a binding by action name. Returns nil if no binding exists.
    public func binding(for action: String) -> KeyBinding? {
        bindings[action]
    }
}

#endif

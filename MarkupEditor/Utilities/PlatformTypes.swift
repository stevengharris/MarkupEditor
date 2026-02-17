//
//  PlatformTypes.swift
//  MarkupEditor
//
//  Platform-agnostic type aliases and helpers for cross-platform support.
//  Provides unified interfaces for UIKit (iOS/MacCatalyst) and AppKit (macOS).
//

import Foundation
import CoreGraphics

#if canImport(UIKit)
import UIKit

/// Platform-specific image type - UIImage on iOS/MacCatalyst
public typealias PlatformImage = UIImage

/// Platform-specific view type - UIView on iOS/MacCatalyst
public typealias PlatformView = UIView

/// Platform-specific color type - UIColor on iOS/MacCatalyst
public typealias PlatformColor = UIColor

/// Platform-specific responder type - UIResponder on iOS/MacCatalyst
public typealias PlatformResponder = UIResponder

#else
import AppKit

/// Platform-specific image type - NSImage on macOS
public typealias PlatformImage = NSImage

/// Platform-specific view type - NSView on macOS
public typealias PlatformView = NSView

/// Platform-specific color type - NSColor on macOS
public typealias PlatformColor = NSColor

/// Platform-specific responder type - NSResponder on macOS
public typealias PlatformResponder = NSResponder

#endif

// MARK: - Pasteboard Helper

/// Platform-agnostic pasteboard access and operations
public struct PasteboardHelper {

    /// Get the general/shared pasteboard
    public static var general: Any {
        #if canImport(UIKit)
        return UIPasteboard.general
        #else
        return NSPasteboard.general
        #endif
    }

    /// Check if pasteboard has string content
    public static func hasString() -> Bool {
        #if canImport(UIKit)
        return UIPasteboard.general.string != nil
        #else
        return NSPasteboard.general.availableType(from: [.string]) != nil
        #endif
    }

    /// Get string from pasteboard
    public static func getString() -> String? {
        #if canImport(UIKit)
        return UIPasteboard.general.string
        #else
        return NSPasteboard.general.string(forType: .string)
        #endif
    }

    /// Check if pasteboard has image content
    public static func hasImage() -> Bool {
        #if canImport(UIKit)
        return UIPasteboard.general.image != nil
        #else
        let pb = NSPasteboard.general
        return pb.availableType(from: [.tiff, .png]) != nil
        #endif
    }

    /// Get image from pasteboard
    public static func getImage() -> PlatformImage? {
        #if canImport(UIKit)
        return UIPasteboard.general.image
        #else
        let pb = NSPasteboard.general
        if let tiffData = pb.data(forType: .tiff) ?? pb.data(forType: .png) {
            return NSImage(data: tiffData)
        }
        return nil
        #endif
    }

    /// Set string on pasteboard
    public static func setString(_ string: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = string
        #else
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(string, forType: .string)
        #endif
    }

    /// Set image on pasteboard
    public static func setImage(_ image: PlatformImage) {
        #if canImport(UIKit)
        UIPasteboard.general.image = image
        #else
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setData(image.tiffRepresentation, forType: .tiff)
        #endif
    }
}

// MARK: - URL Opening Helper

/// Platform-agnostic URL opening
public struct URLHelper {

    /// Check if URL can be opened
    public static func canOpen(_ url: URL) -> Bool {
        #if canImport(UIKit)
        return UIApplication.shared.canOpenURL(url)
        #else
        return NSWorkspace.shared.open(url)
        #endif
    }

    /// Open URL with completion handler
    public static func open(_ url: URL, completion: ((Bool) -> Void)? = nil) {
        #if canImport(UIKit)
        UIApplication.shared.open(url) { success in
            completion?(success)
        }
        #else
        let success = NSWorkspace.shared.open(url)
        completion?(success)
        #endif
    }
}

//
//  MarkupWKWebViewConfiguration.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/23/23.
//

import Foundation

/// A collection of properties that you use to initialize a MarkupEditor web view.
///
/// A MarkupWKWebViewConfiguration object provides information about how to configure a MarkupWKWebView object. 
/// Use your configuration object to specify:
///
/// * A Javascript file script that should be loaded after the MarkupWKWebView has loaded the `markup.js` file.
/// The file name is specified and must be provided as part of the app bundle using the MarkupEditor.
///
/// * A CSS file that should be loaded after the MarkupWKWebView has loaded the `markup.css` file. 
/// The file name is specified and must be provided as part of the app bundle using the MarkupEditor.
///
/// * Top-level attributes for the `editor` element in `markup.html`. By default, the entire `editor` 
/// is editable, but will not perform spell check. Autocorrect is enabled by default because without it,
/// the iOS keyboard will not supply suggestions.
///
/// You create a MarkupWKWebViewConfiguration object in your code, configure its properties, and pass it to the initializer
/// of your WKWebView object. The web view incorporates your configuration settings only at creation time; you cannot change
/// those settings dynamically later.
/// A plugin file to be loaded by the MarkupEditor web view.
///
/// A `PluginFileEntry` identifies a JavaScript plugin by name and file-system path.
/// The `name` is used as a stable key for registry lookup; the `path` is the absolute
/// path to the plugin's `.js` file that will be dynamically imported by the editor.
public struct PluginFileEntry: Codable {
    public var name: String
    public var path: String
    public init(name: String, path: String) {
        self.name = name
        self.path = path
    }
}

public class MarkupWKWebViewConfiguration {
    
    public var userScriptFile: String? = nil
    public var userCssFile: String? = nil
    public var userResourceFiles: [String]? = nil
    public var topLevelAttributes = EditableAttributes.standard
    public var toolbarConfig: ToolbarConfig? = nil
    public var keymapConfig: KeymapConfig? = nil
    public var behaviorConfig: BehaviorConfig? = nil
    public var pluginFiles: [PluginFileEntry]? = nil
    #if targetEnvironment(macCatalyst)
    public var padBottom = false
    #elseif os(iOS)
    public var padBottom = true
    #endif
    
    public init() {}
}

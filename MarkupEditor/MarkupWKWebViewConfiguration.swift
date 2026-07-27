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
/// * Whether the underlying WKWebView allows inline predictive text. Off by default, matching the
/// WKWebViewConfiguration default.
///
/// You create a MarkupWKWebViewConfiguration object in your code, configure its properties, and pass it to the initializer
/// of your WKWebView object. The web view incorporates your configuration settings only at creation time; you cannot change
/// those settings dynamically later.
///
/// Any number of plugin files can be identified to be loaded by the MarkupEditor web view.

public class MarkupWKWebViewConfiguration {
    
    public var userScriptFile: String? = nil
    public var userCssFile: String? = nil
    public var userResourceFiles: [String]? = nil
    public var topLevelAttributes = EditableAttributes.standard
    public var allowsInlinePredictions = false
    public var toolbarConfig: ToolbarConfig? = nil
    public var keymapConfig: KeymapConfig? = nil
    public var behaviorConfig: BehaviorConfig? = nil
    public var pluginFiles: [String]? = nil
    #if targetEnvironment(macCatalyst)
    public var padBottom = false
    #elseif os(iOS)
    public var padBottom = true
    #endif
    
    public init() {}
}

//
//  MarkupEnv.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/20/21.
//

import Foundation
import UniformTypeIdentifiers

/// The available environmentObjects for the MarkupEditor.
///
/// Note that the MarkupEnv does not publish changes itself. Only the ObservableObjects it holds onto publish their changes.
public class MarkupEnv: ObservableObject {
    
    public let observedWebView = ObservedWebView()
    public let selectionState = SelectionState()
    public let toolbarPreference: ToolbarPreference
    public var toolbarPreferenceStyle: ToolbarPreference.Style { toolbarPreference.style }
    public let selectImage = SelectImage()
    public let supportedImageTypes: [UTType] = [.image, .movie]
    public let showSubToolbar = ShowSubToolbar()
    public var allowLocalImages: Bool
    
    public init(style: ToolbarPreference.Style = .compact, allowLocalImages: Bool = false) {
        toolbarPreference = ToolbarPreference(style: style)
        self.allowLocalImages = allowLocalImages
    }
}

/// The observable object containing the selectedWebView.
///
/// In cases where a single MarkupToolbar is being used with multiple MarkupWKWebViews, we need
/// to be able to track which is selected so that the MarkupToolbar reflects its state properly.
public class ObservedWebView: ObservableObject, Identifiable {
    @Published public var selectedWebView: MarkupWKWebView?
    public var id: UUID = UUID()
    
    public init(_ webView: MarkupWKWebView? = nil) {
        selectedWebView = webView
    }
}

/// The observable object containing the Bool that tells us whether the DocumentPicker should be
/// shown to select a local image.
public class SelectImage: ObservableObject {
    @Published public var value: Bool
    
    public init(_ value: Bool = false) {
        self.value = value
    }
}

/// The observable object containing the type of SubToolbar to show, or nil for none.
public class ShowSubToolbar: ObservableObject {
    @Published public var type: SubToolbar.ToolbarType?
    
    public init() {}
}

//
//  MarkupEditor.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/8/22.
//

import SwiftUI
import UniformTypeIdentifiers

/// The MarkupEditor struct holds onto all the state needed across the toolbars, views, and other
/// machinery encompassed in it.
///
/// The state is all held in statics to provide convenient access. The MarkupEditor holds onto several
/// ObservableObjects used by the toolbars.
public struct MarkupEditor {
    public static var observedFirstResponder = ObservedFirstResponder()
    public static var firstResponder: String? {
        get { observedFirstResponder.id }
        set { observedFirstResponder.id = newValue }
    }
    public static let markupMenu = MarkupMenu()
    public static let toolbarContents = ToolbarContents.shared
    public static let toolbarStyle = ToolbarStyle()
    public static var toolbarLocation = ToolbarLocation.automatic
    public static var leftToolbar: AnyView? {
        didSet {
            toolbarContents.leftToolbar = leftToolbar != nil
        }
    }
    public static var rightToolbar: AnyView? {
        didSet {
            toolbarContents.rightToolbar = rightToolbar != nil
        }
    }
    public static let observedWebView = ObservedWebView()
    public static var selectedWebView: MarkupWKWebView? {
        get { observedWebView.selectedWebView }
        set { observedWebView.selectedWebView = newValue }
    }
    public static let selectionState = SelectionState()
    public static let selectImage = SelectImage()
    public static let showInsertPopover = ShowInsertPopover()
    public static let supportedImageTypes: [UTType] = [.image, .movie]
    public static var style: ToolbarStyle.Style = .labeled {
        didSet {
            toolbarStyle.style = style
        }
    }
    public static var allowLocalImages: Bool = false
    
    public static func initMenu(with builder: UIMenuBuilder) {
        markupMenu.initMenu(with: builder)
    }
    
    /// Enum to identify search direction
    public enum FindDirection {
        case forward
        case backward
    }
    
    /// Enum to identify directions for adding rows and columns.
    ///
    /// Used by both icons and MarkupWKWebView.
    ///
    /// Case "before" means to the left, and "after" means to the right for columns.
    /// Case "before" means above, and "after' means below for rows.
    public enum TableDirection {
        case before
        case after
    }

    /// Enum to identify border styling for tables; i.e., what gets a border.
    ///
    /// Used by both icons and MarkupWKWebView.
    public enum TableBorder: String {
        case outer
        case header
        case cell
        case none
    }

    /// Emum used to control the toolbar location when using the MarkupEditorView and MarkupEditorUIView
    public enum ToolbarLocation {
        case top
        case bottom
        case keyboard
        case none
        
        /// Always return .top, but logic left here in case it needs more specialization later
        static var automatic: ToolbarLocation {
            switch UIDevice.current.userInterfaceIdiom {
            case .mac, .pad:
                return .top
            case .phone:
                return .keyboard
            default:
                return .top
            }
        }
    }

}

public class ObservedFirstResponder: ObservableObject {
    @Published public var id: String?
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

/// The observable object containing the type of popover that should be shown or nil for none.
///
/// The value is used by the InsertToolbar to show the default TableSizer and TableToolbar.
public class ShowInsertPopover: ObservableObject, Equatable {
    
    public static func == (lhs: ShowInsertPopover, rhs: ShowInsertPopover) -> Bool {
        guard let lType = lhs.type, let rType = rhs.type else { return false }
        return lType == rType
    }
    
    @Published var type: ToolbarContents.PopoverType?
}

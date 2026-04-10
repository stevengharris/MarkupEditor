//
//  MarkupToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

#if !os(macOS)

import SwiftUI

/// The MarkupToolbar shows the current selectionState and acts on the selectedWebView held
/// by the observedWebView.
///
/// The MarkupToolbar observes the selectionState so that its display reflects the current state.
/// For example, when selectedWebView is nil, the toolbar is disabled, and when the selectionState shows
/// that the selection is inside of a bolded element, then the bold (B) button is active and filled-in.
/// The MarkupToolbar contains multiple other toolbars, such as StyleToolbar and FormatToolbar
/// which invoke methods in the selectedWebView, an instance of MarkupWKWebView.
public struct MarkupToolbar: View {
    
    public static var managed: MarkupToolbar?   // The toolbar created when using MarkupEditorView or MarkupEditorUIView
    public let toolbarStyle: ToolbarStyle
    private let withKeyboardButton: Bool
    @ObservedObject private var observedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState = MarkupEditor.selectionState
    @ObservedObject private var searchActive = MarkupEditor.searchActive
    private var contents: ToolbarContents
    public var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        ZStack(alignment: .topLeading) {
            HStack {
                ScrollView(.horizontal) {
                    HStack {
                        if contents.leftToolbar {
                            MarkupEditor.leftToolbar!
                        }
                        if contents.correction {
                            if contents.leftToolbar { Divider() }
                            CorrectionToolbar()
                        }
                        if contents.insert {
                            if contents.leftToolbar || contents.correction { Divider() }
                            InsertToolbar()
                        }
                        if contents.style {
                            if contents.leftToolbar || contents.correction  || contents.insert { Divider() }
                            StyleToolbar()
                        }
                        if contents.format {
                            if contents.leftToolbar || contents.correction  || contents.insert || contents.style { Divider() }
                            FormatToolbar()
                        }
                        if contents.rightToolbar {
                            if contents.leftToolbar || contents.correction  || contents.insert || contents.style || contents.format { Divider() }
                            MarkupEditor.rightToolbar!
                        }
                        Spacer()                // Push everything to the left
                    }
                    .environmentObject(toolbarStyle)
                    .padding(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                    .disabled(observedWebView.selectedWebView == nil || !selectionState.isValid || searchActive.value)
                }
                .onTapGesture {}    // To make the buttons responsive inside of the ScrollView
                if withKeyboardButton {
                    Spacer()
                    Divider()
                    ToolbarImageButton(
                        systemName: "keyboard.chevron.compact.down",
                        action: {
                            _ = MarkupEditor.selectedWebView?.resignFirstResponder()
                        }
                    )
                    Spacer()
                }
            }
        }
        // Because the icons in toolbars are sized based on font, we need to limit their dynamicTypeSize
        // or they become illegible at very large sizes.
        .dynamicTypeSize(.small ... .xLarge)
        .frame(height: MarkupEditor.toolbarStyle.height())
        .zIndex(999)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, contents: ToolbarContents? = nil, markupDelegate: MarkupDelegate? = nil, withKeyboardButton: Bool = false) {
        let toolbarStyle = style == nil ? MarkupEditor.toolbarStyle : ToolbarStyle(style!)
        self.toolbarStyle = toolbarStyle
        let toolbarContents = contents == nil ? MarkupEditor.toolbarContents : contents!
        self.contents = toolbarContents
        self.withKeyboardButton = withKeyboardButton
        self.markupDelegate = markupDelegate
    }
    
    public func makeManaged() -> MarkupToolbar {
        MarkupToolbar.managed = self
        return self
    }

}

//MARK: Previews

struct MarkupToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        VStack(alignment: .leading) {
            MarkupToolbar(.compact)
            MarkupToolbar(.labeled)
            Spacer()
        }
        .onAppear {
            MarkupEditor.selectedWebView = MarkupWKWebView()
            MarkupEditor.selectionState.valid = true
        }
    }
}

#endif

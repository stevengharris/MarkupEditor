//
//  MarkupToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/28/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The MarkupToolbar shows the current selectionState and acts on the selectedWebView held
/// by the observedWebView.
///
/// The MarkupToolbar observes the selectionState so that its display reflects the current state.
/// For example, when selectedWebView is nil, the toolbar is disabled, and when the selectionState shows
/// that the selection is inside of a bolded element, then the bold (B) button is active and filled-in.
/// The MarkupToolbar contains multiple other toolbars, such as StyleToolbar and FormatToolbar
/// which invoke methods in the selectedWebView, an instance of MarkupWKWebView.
/// The InsertToolbar sets showSubToolbar.type, which in turn uncovers one of the specific
/// subtoolbars that require additional user interaction.
public struct MarkupToolbar: View {
    @State private var toolbarStyle: ToolbarStyle
    @ObservedObject private var observedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState = MarkupEditor.selectionState
    private let contents = MarkupEditor.toolbarContents
    @State var markupDelegate: MarkupDelegate?
    /// User-supplied view to be shown on the left side of the default MarkupToolbar
    private var leftToolbar: AnyView?
    /// User-supplied view to be shown on the right side of the default MarkupToolbar
    private var rightToolbar: AnyView?
    
    public var body: some View {
        HStack {
            if leftToolbar != nil {
                leftToolbar
                Divider()
            }
            Group {
                if contents.correction {
                    CorrectionToolbar()
                    Divider()
                }
                if contents.insert {
                    InsertToolbar()
                    Divider()
                }
                if contents.style {
                    StyleToolbar()
                    Divider()
                }
                if contents.format {
                    FormatToolbar()
                    Divider()           // Vertical on the right
                }
            }
            if rightToolbar != nil {
                rightToolbar
                Divider()
            }
            Spacer()                // Push everything to the left
        }
        .environmentObject(toolbarStyle)
        .frame(height: toolbarStyle.height())
        .disabled(observedWebView.selectedWebView == nil || !selectionState.valid)
    }
    
    public init(_ style: ToolbarStyle.Style? = nil, markupDelegate: MarkupDelegate? = nil, leftToolbar: AnyView? = nil, rightToolbar: AnyView? = nil) {
        let toolbarStyle = style == nil ? MarkupEditor.toolbarStyle : ToolbarStyle(style!)
        _toolbarStyle = State(initialValue: toolbarStyle)
        self.markupDelegate = markupDelegate
        self.leftToolbar = leftToolbar
        self.rightToolbar = rightToolbar
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



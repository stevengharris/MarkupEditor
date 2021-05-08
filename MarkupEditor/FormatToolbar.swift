//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

public struct FormatToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    public var body: some View {
        LabeledToolbar(label: Text("Format").font(.system(size: 10, weight: .light))) {
            ToolbarImageButton(
                action: { selectedWebView?.bold() },
                active: $selectionState.bold
            ) {
                Image.forToolbar(systemName: "bold")
            }
            ToolbarImageButton (
                action: { selectedWebView?.italic() },
                active: $selectionState.italic
            ) {
                Image.forToolbar(systemName: "italic")
            }
            ToolbarImageButton(
                action: { selectedWebView?.underline() },
                active: $selectionState.underline
            ) {
                Image.forToolbar(systemName: "underline")
            }
            ToolbarImageButton(
                action: { selectedWebView?.code() },
                active: $selectionState.code
            ) {
                Image.forToolbar(systemName: "curlybraces")
            }
            ToolbarImageButton(
                action: { selectedWebView?.strike() },
                active: $selectionState.strike
            ) {
                Image.forToolbar(systemName: "strikethrough")
            }
            ToolbarImageButton(
                action: { selectedWebView?.subscriptText() },
                active: $selectionState.sub
            ) {
                Image.forToolbar(systemName: "textformat.subscript")
            }
            ToolbarImageButton(
                action: { selectedWebView?.superscript() },
                active: $selectionState.sup
            ) {
                Image.forToolbar(systemName: "textformat.superscript")
            }
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
}

struct FormatToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FormatToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}

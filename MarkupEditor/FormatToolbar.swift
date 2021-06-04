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
    @State private var hoverLabel: Text = Text("Text Format")
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                action: { selectedWebView?.bold() },
                active: $selectionState.bold,
                onHover: { over in hoverLabel = Text(over ? "Bold" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "bold")
            }
            ToolbarImageButton (
                action: { selectedWebView?.italic() },
                active: $selectionState.italic,
                onHover: { over in hoverLabel = Text(over ? "Italic" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "italic")
            }
            ToolbarImageButton(
                action: { selectedWebView?.underline() },
                active: $selectionState.underline,
                onHover: { over in hoverLabel = Text(over ? "Underline" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "underline")
            }
            ToolbarImageButton(
                action: { selectedWebView?.code() },
                active: $selectionState.code,
                onHover: { over in hoverLabel = Text(over ? "Code" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "curlybraces")
            }
            ToolbarImageButton(
                action: { selectedWebView?.strike() },
                active: $selectionState.strike,
                onHover: { over in hoverLabel = Text(over ? "Strikethrough" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "strikethrough")
            }
            ToolbarImageButton(
                action: { selectedWebView?.subscriptText() },
                active: $selectionState.sub,
                onHover: { over in hoverLabel = Text(over ? "Subscript" : "Text Format") }
            ) {
                Image.forToolbar(systemName: "textformat.subscript")
            }
            ToolbarImageButton(
                action: { selectedWebView?.superscript() },
                active: $selectionState.sup,
                onHover: { over in hoverLabel = Text(over ? "Superscript" : "Text Format") }
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

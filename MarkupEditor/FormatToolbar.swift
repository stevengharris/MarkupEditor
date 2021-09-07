//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct FormatToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @State private var hoverLabel: Text = Text("Text Format")
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                systemName: "bold",
                action: { selectedWebView?.bold() },
                active: $selectionState.bold,
                onHover: { over in hoverLabel = Text(over ? "Bold" : "Text Format") }
            )
            ToolbarImageButton (
                systemName: "italic",
                action: { selectedWebView?.italic() },
                active: $selectionState.italic,
                onHover: { over in hoverLabel = Text(over ? "Italic" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "underline",
                action: { selectedWebView?.underline() },
                active: $selectionState.underline,
                onHover: { over in hoverLabel = Text(over ? "Underline" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "curlybraces",
                action: { selectedWebView?.code() },
                active: $selectionState.code,
                onHover: { over in hoverLabel = Text(over ? "Code" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "strikethrough",
                action: { selectedWebView?.strike() },
                active: $selectionState.strike,
                onHover: { over in hoverLabel = Text(over ? "Strikethrough" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "textformat.subscript",
                action: { selectedWebView?.subscriptText() },
                active: $selectionState.sub,
                onHover: { over in hoverLabel = Text(over ? "Subscript" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "textformat.superscript",
                action: { selectedWebView?.superscript() },
                active: $selectionState.sup,
                onHover: { over in hoverLabel = Text(over ? "Superscript" : "Text Format") }
            )
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

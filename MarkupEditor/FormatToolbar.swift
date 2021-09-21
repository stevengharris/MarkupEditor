//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct FormatToolbar: View {
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
    @State private var hoverLabel: Text = Text("Text Format")
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                systemName: "bold",
                action: { observedWebView.selectedWebView?.bold() },
                active: $selectionState.bold,
                onHover: { over in hoverLabel = Text(over ? "Bold" : "Text Format") }
            )
            ToolbarImageButton (
                systemName: "italic",
                action: { observedWebView.selectedWebView?.italic() },
                active: $selectionState.italic,
                onHover: { over in hoverLabel = Text(over ? "Italic" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "underline",
                action: { observedWebView.selectedWebView?.underline() },
                active: $selectionState.underline,
                onHover: { over in hoverLabel = Text(over ? "Underline" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "curlybraces",
                action: { observedWebView.selectedWebView?.code() },
                active: $selectionState.code,
                onHover: { over in hoverLabel = Text(over ? "Code" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "strikethrough",
                action: { observedWebView.selectedWebView?.strike() },
                active: $selectionState.strike,
                onHover: { over in hoverLabel = Text(over ? "Strikethrough" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "textformat.subscript",
                action: { observedWebView.selectedWebView?.subscriptText() },
                active: $selectionState.sub,
                onHover: { over in hoverLabel = Text(over ? "Subscript" : "Text Format") }
            )
            ToolbarImageButton(
                systemName: "textformat.superscript",
                action: { observedWebView.selectedWebView?.superscript() },
                active: $selectionState.sup,
                onHover: { over in hoverLabel = Text(over ? "Superscript" : "Text Format") }
            )
        }
    }
}

struct FormatToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FormatToolbar()
    }
}

//
//  FormatToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct FormatToolbar: View {
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private let contents: FormatContents = MarkupEditor.toolbarContents.formatContents
    @State private var hoverLabel: Text = Text("Text Format")

    public init() {}

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
            // MARK: - We don't use underline in the app, that's why it's commented out
//            ToolbarImageButton(
//                systemName: "underline",
//                action: { observedWebView.selectedWebView?.underline() },
//                active: $selectionState.underline,
//                onHover: { over in hoverLabel = Text(over ? "Underline" : "Text Format") }
//            )
            if contents.code {
                ToolbarImageButton(
                    systemName: "curlybraces",
                    action: { observedWebView.selectedWebView?.code() },
                    active: $selectionState.code,
                    onHover: { over in hoverLabel = Text(over ? "Code" : "Text Format") }
                )
            }
            if contents.strike {
                ToolbarImageButton(
                    systemName: "strikethrough",
                    action: { observedWebView.selectedWebView?.strike() },
                    active: $selectionState.strike,
                    onHover: { over in hoverLabel = Text(over ? "Strikethrough" : "Text Format") }
                )
            }
            if contents.subSuper {
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
}

struct FormatToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            HStack {
                FormatToolbar()
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                FormatToolbar()
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

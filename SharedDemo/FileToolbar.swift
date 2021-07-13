//
//  FileToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/9/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI
import MarkupEditor

/// The toolbar to open new or existing files and to expose the raw HTML in the selectedWebView.
struct FileToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @State private var hoverLabel: Text = Text("File")
    private var fileToolbarDelegate: FileToolbarDelegate?
    
    var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                action: { fileToolbarDelegate?.newDocument(handler: nil) },
                onHover: { over in hoverLabel = Text(over ? "New" : "File") }
            ) {
                Image.forToolbar(systemName: "plus")
            }
            ToolbarImageButton(
                action: { fileToolbarDelegate?.existingDocument(handler: nil) },
                onHover: { over in hoverLabel = Text(over ? "Existing" : "File") }
            ) {
                Image.forToolbar(systemName: "newspaper")
            }
            ToolbarImageButton(
                action: { fileToolbarDelegate?.rawDocument() },
                onHover: { over in hoverLabel = Text(over ? "Raw HTML" : "File") }
            ) {
                Image.forToolbar(systemName: "chevron.left.slash.chevron.right")
            }
        }
    }

    init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, fileToolbarDelegate: FileToolbarDelegate? = nil) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.fileToolbarDelegate = fileToolbarDelegate
    }
    
}

struct FileToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FileToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


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
    @State private var hoverLabel: Text = Text("File")
    private var fileToolbarDelegate: FileToolbarDelegate?
    
    var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                systemName: "plus",
                action: { fileToolbarDelegate?.newDocument(handler: nil) },
                onHover: { over in hoverLabel = Text(over ? "New" : "File") }
            )
            ToolbarImageButton(
                systemName: "newspaper",
                action: { fileToolbarDelegate?.existingDocument(handler: nil) },
                onHover: { over in hoverLabel = Text(over ? "Existing" : "File") }
            )
            ToolbarImageButton(
                systemName: "chevron.left.slash.chevron.right",
                action: { fileToolbarDelegate?.rawDocument() },
                onHover: { over in hoverLabel = Text(over ? "Raw HTML" : "File") }
            )
        }
    }

    init(fileToolbarDelegate: FileToolbarDelegate? = nil) {
        self.fileToolbarDelegate = fileToolbarDelegate
    }
    
}

struct FileToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FileToolbar()
    }
}


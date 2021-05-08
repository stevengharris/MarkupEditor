//
//  FileToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/9/21.
//

import SwiftUI
import MarkupEditor

struct FileToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    private var fileToolbarDelegate: FileToolbarDelegate?
    
    var body: some View {
        LabeledToolbar(label: Text("File").font(.system(size: 10, weight: .light))) {
            ToolbarImageButton(action: { fileToolbarDelegate?.newDocument(handler: nil) } ) {
                Image.forToolbar(systemName: "plus")
            }
            ToolbarImageButton(action: { fileToolbarDelegate?.existingDocument(handler: nil) } ) {
                Image.forToolbar(systemName: "newspaper")
            }
            ToolbarImageButton(action: { fileToolbarDelegate?.rawDocument() } ) {
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


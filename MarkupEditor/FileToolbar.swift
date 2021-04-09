//
//  FileToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/9/21.
//

import SwiftUI

public struct FileToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    private var markupUIDelegate: MarkupUIDelegate?
    
    public var body: some View {
        VStack(spacing: 2) {
            Text("File")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                ToolbarImageButton(
                    image: Image(systemName: "plus"),
                    action: { markupUIDelegate?.markupNewDocument() }
                )
                .id(UUID())
                ToolbarImageButton(
                    image: Image(systemName: "newspaper"),
                    action: { markupUIDelegate?.markupExistingDocument() }
                )
                .id(UUID())
                ToolbarImageButton(
                    image:  Image(systemName: "square.and.arrow.down"),
                    action: { markupUIDelegate?.markupSaveDocument() }
                )
                .id(UUID())
            }
        }
    }

    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupUIDelegate = markupUIDelegate
    }
    
}

struct FileToolbar_Previews: PreviewProvider {
    static var previews: some View {
        FileToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}


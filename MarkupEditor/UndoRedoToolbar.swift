//
//  UndoRedoToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

struct UndoRedoToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    var body: some View {
        VStack(spacing: 2) {
            Text("Undo/Redo")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                ToolbarImageButton(
                    image: Image(systemName: "arrow.uturn.backward"),
                    action: { print("markupView?.undo()") }
                )
                .id(UUID())
                ToolbarImageButton(
                    image:  Image(systemName: "arrow.uturn.forward"),
                    action: { print("markupView?.redo()") }
                )
                .id(UUID())
            }
        }
    }

    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
    
}

struct UndoRedoToolbar_Previews: PreviewProvider {
    static var previews: some View {
        UndoRedoToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}

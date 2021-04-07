//
//  SwiftUIView.swift
//  
//
//  Created by Steven Harris on 3/24/21.
//

import SwiftUI

public struct InsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    private var markupUIDelegate: MarkupUIDelegate?
    @Binding public var showImageToolbar: Bool
    public var body: some View {
        VStack(spacing: 2) {
            Text("Insert")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                ToolbarImageButton(
                    image:  Image(systemName: "link"),
                    action: { print("Show link toolbar") },
                    active: selectionState.isInLink
                )
                .id(UUID())
                .disabled(!selectionState.isLinkable)
                ToolbarImageButton(
                    image: Image(systemName: "photo"),
                    action: { showImageToolbar.toggle() },
                    active: selectionState.isInImage
                )
                .id(UUID())
                .disabled(!selectionState.isInsertable && !selectionState.isInImage)
                ToolbarImageButton(
                    image:  Image(systemName: "tablecells"),
                    action: { print("Show table toolbar") },
                    active: selectionState.isInTable
                )
                .id(UUID())
                .disabled(!selectionState.isInsertable)
                /*
                Button(action: {
                    showAlert(type: .line)
                }) {
                    Image(systemName: "line.horizontal.3")
                }
                .disabled(!selectionState.isInsertable)
                Button(action: {
                    showAlert(type: .sketch)
                }) {
                    Image(systemName: "scribble")
                }
                .disabled(!selectionState.isInsertable)
                Button(action: {
                    showAlert(type: .codeblock)
                }) {
                    Image(systemName: "curlybraces")
                }
                .disabled(!selectionState.isInsertable)
                */
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil, showImageToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupUIDelegate = markupUIDelegate
        _showImageToolbar = showImageToolbar
    }
    
}

struct InsertToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        InsertToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showImageToolbar: .constant(false))
    }
    
}

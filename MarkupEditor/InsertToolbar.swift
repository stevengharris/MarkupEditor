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
    @Binding public var showLinkToolbar: Bool
    public var body: some View {
        VStack(spacing: 2) {
            Text("Insert")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                ToolbarImageButton(
                    image:  Image(systemName: "link"),
                    action: { withAnimation { showLinkToolbar.toggle() } },
                    active: selectionState.isInLink
                )
                .id(UUID())
                // Always enabled if we are showing this toolbar, so we can hide it again.
                .disabled(!showLinkToolbar && (showImageToolbar || !selectionState.isLinkable))
                ToolbarImageButton(
                    image: Image(systemName: "photo"),
                    action: { withAnimation { showImageToolbar.toggle() } },
                    active: selectionState.isInImage
                )
                .id(UUID())
                // Always enabled if we are showing this toolbar, so we can hide it again.
                .disabled(!showImageToolbar && (showLinkToolbar || (!selectionState.isInsertable && !selectionState.isInImage)))
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
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil, showImageToolbar: Binding<Bool>, showLinkToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupUIDelegate = markupUIDelegate
        _showImageToolbar = showImageToolbar
        _showLinkToolbar = showLinkToolbar
    }
    
}

struct InsertToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        InsertToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showImageToolbar: .constant(false), showLinkToolbar: .constant(false))
    }
    
}

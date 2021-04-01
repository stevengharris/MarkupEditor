//
//  SwiftUIView.swift
//  
//
//  Created by Steven Harris on 3/24/21.
//

import SwiftUI

public struct MarkupInsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    private var markupUIDelegate: MarkupUIDelegate?
    @Binding public var showImageToolbar: Bool
    public var body: some View {
        VStack(spacing: 2) {
            Text("Insert")
                .font(.system(size: 10, weight: .light))
            HStack {
                Button(action: {
                    print("Show link toolbar")
                }) {
                    Image(systemName: "link")
                }
                .buttonStyle(ToolbarImageButtonStyle(active: selectionState.isInLink))
                .disabled(!selectionState.isLinkable)
                Button(action: {
                    withAnimation { showImageToolbar.toggle() }
                }) {
                    Image(systemName: "photo")
                }
                .buttonStyle(ToolbarImageButtonStyle(active: selectionState.isInImage))
                .disabled(!selectionState.isInsertable && !selectionState.isInImage)
                Button(action: {
                    print("Show table toolbar")
                }) {
                    Image(systemName: "tablecells")
                }
                .buttonStyle(ToolbarImageButtonStyle(active: selectionState.isInTable))
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
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil, showImageToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupUIDelegate = markupUIDelegate
        _showImageToolbar = showImageToolbar
    }
    
}

struct MarkupInsertToolbar_Previews: PreviewProvider {
    
    static var previews: some View {
        MarkupInsertToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showImageToolbar: .constant(false))
    }
    
}

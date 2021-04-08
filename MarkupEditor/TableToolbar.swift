//
//  TableToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/8/21.
//

import SwiftUI

struct TableToolbar: View {
    @Binding var showToolbar: Bool
    @Binding private var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupUIDelegate: MarkupUIDelegate?
    
    public var body: some View {
        Text("This is going to be the table toolbar")
        .frame(height: 47)
        .padding([.leading, .trailing], 8)
        .padding([.top, .bottom], 2)
        Divider()
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupUIDelegate: MarkupUIDelegate? = nil, showToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupUIDelegate = markupUIDelegate
        _showToolbar = showToolbar
    }
    
}

struct TableToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LinkToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showToolbar: .constant(true))
    }
}

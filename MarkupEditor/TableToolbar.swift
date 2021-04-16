//
//  TableToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/8/21.
//

import SwiftUI

public struct TableToolbar: View {
    @Binding var showToolbar: Bool
    @Binding private var selectedWebView: MarkupWKWebView?
    @ObservedObject private var selectionState: SelectionState
    private var markupDelegate: MarkupDelegate?
    
    public var body: some View {
        Text("This is going to be the table toolbar")
        .frame(height: 47)
        .padding([.leading, .trailing], 8)
        .padding([.top, .bottom], 2)
        Divider()
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, markupDelegate: MarkupDelegate? = nil, showToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        self.markupDelegate = markupDelegate
        _showToolbar = showToolbar
    }
    
}

struct TableToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LinkToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showToolbar: .constant(true))
    }
}

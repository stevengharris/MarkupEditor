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
    
    public var body: some View {
        HStack(alignment: .bottom) {
            LabeledToolbar(label: Text("Size")) {
                VStack(alignment: .leading) {
                    Text("\(selectionState.rows) rows")
                    Text("\(selectionState.cols) columns")
                }
            }
            Divider()
            ToolbarTextButton(title: "+Header", action: addHeader)
            ToolbarTextButton(title: "+Row", action: addRow)
            Divider()
            Spacer()
        }
        .frame(height: 47)
        .padding([.leading, .trailing], 8)
        .padding([.top, .bottom], 2)
        Divider()
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showToolbar = showToolbar
    }
    
    private func addHeader() {
        
    }
    
    private func addRow() {
        selectedWebView?.addRow(.after) {
            print("woohoo")
        }
    }
    
}

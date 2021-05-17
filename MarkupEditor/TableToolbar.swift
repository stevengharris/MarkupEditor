//
//  TableToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/8/21.
//

import SwiftUI

public enum TableDirection {
    case before
    case after
}

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
            LabeledToolbar(label: Text("Add")) {
                ToolbarImageButton(action: { selectedWebView?.addHeader() }) {
                    AddHeader(rows: 2, cols: 3)
                }
                .disabled(selectionState.header)
                ToolbarImageButton(action: { selectedWebView?.addRow(.after) }) {
                    AddRow(direction: .after)
                }
                ToolbarImageButton(action: { selectedWebView?.addRow(.before) }) {
                    AddRow(direction: .before)
                }
                .disabled(selectionState.thead)
                ToolbarImageButton(action: { selectedWebView?.addCol(.after) }) {
                    AddCol(direction: .after)
                }
                .disabled(selectionState.thead && selectionState.colspan)
                ToolbarImageButton(action: { selectedWebView?.addCol(.before) }) {
                    AddCol(direction: .before)
                }
                .disabled(selectionState.thead && selectionState.colspan)
            }
            Divider()
            LabeledToolbar(label: Text("Delete")) {
                ToolbarImageButton(action: { selectedWebView?.deleteRow() }) {
                    DeleteRow()
                }
                ToolbarImageButton(action: { selectedWebView?.deleteCol() }) {
                    DeleteCol()
                }
            }
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
    
}

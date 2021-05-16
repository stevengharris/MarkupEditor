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
            LabeledToolbar(label: Text("Add")) {
                ToolbarTextButton(title: "Header", action: { selectedWebView?.addHeader() })
                    .disabled(selectionState.header)
                ToolbarTextButton(title: "RowBelow", action: { selectedWebView?.addRow(.after) })
                ToolbarTextButton(title: "RowAbove", action: { selectedWebView?.addRow(.before) })
                    .disabled(selectionState.thead)
                ToolbarTextButton(title: "ColAfter", action: { selectedWebView?.addCol(.after) })
                    .disabled(selectionState.thead && selectionState.colspan)
                ToolbarTextButton(title: "ColBefore", action: { selectedWebView?.addCol(.before) })
                    .disabled(selectionState.thead && selectionState.colspan)
            }
            Divider()
            LabeledToolbar(label: Text("Delete")) {
                ToolbarTextButton(title: "Row", action: { selectedWebView?.deleteRow() })
                ToolbarTextButton(title: "Column", action: { selectedWebView?.deleteCol() })
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

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
    @State private var showTableSizer: Bool = false
    @State private var tappedInTableSizer: Bool = false
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    @State private var addHoverLabel: Text = Text("Add")
    @State private var deleteHoverLabel: Text = Text("Delete")

    
    public var body: some View {
        HStack(alignment: .bottom) {
            LabeledToolbar(label: Text("Create")) {
                ToolbarImageButton(action: { showTableSizer.toggle() } ) {
                    CreateTable()
                }
                .disabled(selectionState.isInTable)
                .popover(isPresented: $showTableSizer) {
                    TableSizer(rows: $rows, cols: $cols, showing: $showTableSizer, tapped: $tappedInTableSizer)
                        .onAppear() {
                            rows = 0
                            cols = 0
                        }
                        .onDisappear() {
                            if tappedInTableSizer && rows > 0 && cols > 0 {
                                selectedWebView?.insertTable(rows: rows, cols: cols)
                            }
                        }
                }
            }
            Divider()
            LabeledToolbar(label: addHoverLabel) {
                ToolbarImageButton(
                    action: { selectedWebView?.addHeader() },
                    onHover: { over in addHoverLabel = Text(over ? "Add Header" : "Add") }
                ) {
                    AddHeader(rows: 2, cols: 3)
                }
                .disabled(!selectionState.isInTable || selectionState.header)
                ToolbarImageButton(
                    action: { selectedWebView?.addRow(.after) },
                    onHover: { over in addHoverLabel = Text(over ? "Add Row Below" : "Add") }
                ) {
                    AddRow(direction: .after)
                }
                .disabled(!selectionState.isInTable)
                ToolbarImageButton(
                    action: { selectedWebView?.addRow(.before) },
                    onHover: { over in addHoverLabel = Text(over ? "Add Row Above" : "Add") }
                ) {
                    AddRow(direction: .before)
                }
                .disabled(!selectionState.isInTable || selectionState.thead)
                ToolbarImageButton(
                    action: { selectedWebView?.addCol(.after) },
                    onHover: { over in addHoverLabel = Text(over ? "Add Column After" : "Add") }
                ) {
                    AddCol(direction: .after)
                }
                .disabled(!selectionState.isInTable || (selectionState.thead && selectionState.colspan))
                ToolbarImageButton(
                    action: { selectedWebView?.addCol(.before) },
                    onHover: { over in addHoverLabel = Text(over ? "Add Column Before" : "Add") }
                ) {
                    AddCol(direction: .before)
                }
                .disabled(!selectionState.isInTable || (selectionState.thead && selectionState.colspan))
            }
            Divider()
            LabeledToolbar(label: deleteHoverLabel) {
                ToolbarImageButton(
                    action: { selectedWebView?.deleteRow() },
                    onHover: { over in deleteHoverLabel = Text(over ? "Delete Row" : "Delete") }
                ) {
                    DeleteRow()
                }
                .disabled(!selectionState.isInTable)
                ToolbarImageButton(
                    action: { selectedWebView?.deleteCol() },
                    onHover: { over in deleteHoverLabel = Text(over ? "Delete Column" : "Delete") }
                ) {
                    DeleteCol()
                }
                .disabled(!selectionState.isInTable)
                ToolbarImageButton(
                    action: { selectedWebView?.deleteTable() },
                    onHover: { over in deleteHoverLabel = Text(over ? "Delete Table" : "Delete") }
                ) {
                    DeleteTable()
                }
                .disabled(!selectionState.isInTable)
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

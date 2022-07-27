//
//  TableToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// Enum to identify directions for adding rows and columns.
///
/// Case "before" means to the left, and "after" means to the right for columns.
/// Case "before" means above, and "after' means below for rows.
public enum TableDirection {
    case before
    case after
}

/// Enum to identiry border styling for tables
public enum TableBorders {
    case outer
    case header
    case cell
    case none
}

/// The toolbar used for creating and editing a table.
public struct TableToolbar: View {
    @EnvironmentObject var toolbarPreference: ToolbarPreference
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
    @State private var showTableSizer: Bool = false
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    @State private var addHoverLabel: Text = Text("Add")
    @State private var deleteHoverLabel: Text = Text("Delete")
    @State private var borderHoverLabel: Text = Text("Border")
    
    public var body: some View {
        VStack(spacing: 2) {
            HStack(alignment: .bottom) {
                LabeledToolbar(label: Text("Create")) {
                    ToolbarImageButton(action: { showTableSizer.toggle() } ) {
                        CreateTable()
                    }
                    .disabled(selectionState.isInTable)
                    .forcePopover(isPresented: $showTableSizer) {
                        TableSizer(rows: $rows, cols: $cols, showing: $showTableSizer)
                            .onAppear() {
                                rows = 0
                                cols = 0
                            }
                            .onDisappear() {
                                if rows > 0 && cols > 0 {
                                    observedWebView.selectedWebView?.insertTable(rows: rows, cols: cols)
                                }
                            }
                    }
                }
                Divider()
                LabeledToolbar(label: addHoverLabel) {
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.addHeader() },
                        onHover: { over in addHoverLabel = Text(over ? "Add Header" : "Add") }
                    ) {
                        AddHeader(rows: 2, cols: 3)
                    }
                    .disabled(!selectionState.isInTable || selectionState.header)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.addRow(.after) },
                        onHover: { over in addHoverLabel = Text(over ? "Add Row Below" : "Add") }
                    ) {
                        AddRow(direction: .after)
                    }
                    .disabled(!selectionState.isInTable)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.addRow(.before) },
                        onHover: { over in addHoverLabel = Text(over ? "Add Row Above" : "Add") }
                    ) {
                        AddRow(direction: .before)
                    }
                    .disabled(!selectionState.isInTable || selectionState.thead)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.addCol(.after) },
                        onHover: { over in addHoverLabel = Text(over ? "Add Column After" : "Add") }
                    ) {
                        AddCol(direction: .after)
                    }
                    .disabled(!selectionState.isInTable || (selectionState.thead && selectionState.colspan))
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.addCol(.before) },
                        onHover: { over in addHoverLabel = Text(over ? "Add Column Before" : "Add") }
                    ) {
                        AddCol(direction: .before)
                    }
                    .disabled(!selectionState.isInTable || (selectionState.thead && selectionState.colspan))
                }
                Divider()
                LabeledToolbar(label: deleteHoverLabel) {
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.deleteRow() },
                        onHover: { over in deleteHoverLabel = Text(over ? "Delete Row" : "Delete") }
                    ) {
                        DeleteRow()
                    }
                    .disabled(!selectionState.isInTable)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.deleteCol() },
                        onHover: { over in deleteHoverLabel = Text(over ? "Delete Column" : "Delete") }
                    ) {
                        DeleteCol()
                    }
                    .disabled(!selectionState.isInTable || (selectionState.thead && selectionState.colspan))
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.deleteTable() },
                        onHover: { over in deleteHoverLabel = Text(over ? "Delete Table" : "Delete") }
                    ) {
                        DeleteTable()
                    }
                    .disabled(!selectionState.isInTable)
                }
                Divider()
                LabeledToolbar(label: borderHoverLabel) {
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.borderTable(.outer) },
                        onHover: { over in borderHoverLabel = Text(over ? "Outer" : "Border") }
                    ) {
                        BorderIcon(.outer)
                    }
                    .disabled(!selectionState.isInTable)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.borderTable(.header) },
                        onHover: { over in borderHoverLabel = Text(over ? "Header" : "Border") }
                    ) {
                        BorderIcon(.header)
                    }
                    .disabled(!selectionState.isInTable)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.borderTable(.cell) },
                        onHover: { over in borderHoverLabel = Text(over ? "Cells" : "Border") }
                    ) {
                        BorderIcon(.cell)
                    }
                    .disabled(!selectionState.isInTable)
                    ToolbarImageButton(
                        action: { observedWebView.selectedWebView?.borderTable(.none) },
                        onHover: { over in borderHoverLabel = Text(over ? "None" : "Border") }
                    ) {
                        BorderIcon(.none)
                    }
                    .disabled(!selectionState.isInTable)
                }
                Divider()
                Spacer()
            }
            Divider()
        }
        .frame(height: toolbarPreference.height())
        .padding([.leading, .trailing], 8)
        .padding([.top, .bottom], 2)
        .background(Blur(style: .systemUltraThinMaterial))
    }
    
}

struct TableToolbar_Previews: PreviewProvider {
    static var previews: some View {
        let compactMarkupEnv = MarkupEnv(style: .compact)
        let compactPreference = compactMarkupEnv.toolbarPreference
        let labeledMarkupEnv = MarkupEnv(style: .labeled)
        let labeledPreference = labeledMarkupEnv.toolbarPreference
        VStack(alignment: .leading) {
            HStack {
                TableToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(compactPreference)
                    .frame(height: compactPreference.height())
                Spacer()
            }
            HStack {
                TableToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(labeledPreference)
                    .frame(height: labeledPreference.height())
                Spacer()
            }
            Spacer()
        }
    }
}

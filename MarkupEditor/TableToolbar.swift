//
//  TableToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar used for creating and editing a table.
public struct TableToolbar: View {
    @EnvironmentObject private var toolbarStyle: ToolbarStyle
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private var contents: TableContents { MarkupEditor.toolbarContents.tableContents }
    @State private var addHoverLabel: Text = Text("Add")
    @State private var deleteHoverLabel: Text = Text("Delete")
    @State private var borderHoverLabel: Text = Text("Border")
    @Binding var showing: Bool
    
    public var body: some View {
        ScrollView(.horizontal) {
            VStack(spacing: 2) {
                HStack {
                    LabeledToolbar(label: addHoverLabel) {
                        ToolbarImageButton(
                            action: { observedWebView.selectedWebView?.addHeader() },
                            onHover: { over in addHoverLabel = Text(over ? "Add Header" : "Add") }
                        ) {
                            AddHeader()
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
                            action: {
                                showing = false
                                observedWebView.selectedWebView?.focus {
                                    observedWebView.selectedWebView?.deleteTable()
                                }
                            },
                            onHover: { over in deleteHoverLabel = Text(over ? "Delete Table" : "Delete") }
                        ) {
                            DeleteTable()
                        }
                        .disabled(!selectionState.isInTable)
                    }
                    if contents.border {
                        Divider()
                        LabeledToolbar(label: borderHoverLabel) {
                            // cellActive needs check on .isInTable because it is the default
                            let cellActive = Binding<Bool>(get: { selectionState.isInTable && selectionState.border == .cell }, set: { _ = $0 })
                            let headerActive = Binding<Bool>(get: { selectionState.border == .header }, set: { _ = $0 })
                            let outerActive = Binding<Bool>(get: { selectionState.border == .outer }, set: { _ = $0 })
                            let noneActive = Binding<Bool>(get: { selectionState.border == .none }, set: { _ = $0 })
                            ToolbarImageButton(
                                action: { observedWebView.selectedWebView?.borderTable(.cell) },
                                active: cellActive,
                                onHover: { over in borderHoverLabel = Text(over ? "Cells" : "Border") }
                            ) {
                                BorderIcon(.cell, active: cellActive)
                            }
                            .disabled(!selectionState.isInTable)
                            ToolbarImageButton(
                                action: { observedWebView.selectedWebView?.borderTable(.header) },
                                active: headerActive,
                                onHover: { over in borderHoverLabel = Text(over ? "Header" : "Border") }
                            ) {
                                BorderIcon(.header, active: headerActive)
                            }
                            .disabled(!selectionState.isInTable)
                            ToolbarImageButton(
                                action: { observedWebView.selectedWebView?.borderTable(.outer) },
                                active: outerActive,
                                onHover: { over in borderHoverLabel = Text(over ? "Outer" : "Border") }
                            ) {
                                BorderIcon(.outer, active: outerActive)
                            }
                            .disabled(!selectionState.isInTable)
                            ToolbarImageButton(
                                action: { observedWebView.selectedWebView?.borderTable(.none) },
                                active: noneActive,
                                onHover: { over in borderHoverLabel = Text(over ? "None" : "Border") }
                            ) {
                                BorderIcon(.none, active: noneActive)
                            }
                            .disabled(!selectionState.isInTable)
                        }
                    }
                    Spacer()
                }
            }
            .frame(height: toolbarStyle.height())
            .padding([.leading], 8)
            .disabled(observedWebView.selectedWebView == nil || !selectionState.valid)
        }
        .background(Blur(style: .systemUltraThinMaterial))
        .onTapGesture {}
    }
}

struct TableToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            HStack {
                TableToolbar(showing: .constant(true))
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                TableToolbar(showing: .constant(true))
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

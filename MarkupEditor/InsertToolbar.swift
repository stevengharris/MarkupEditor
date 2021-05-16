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
    @Binding private var showLinkToolbar: Bool
    @Binding private var showImageToolbar: Bool
    @Binding private var showTableToolbar: Bool
    @State private var showTableSizer: Bool = false
    @State private var tappedInTableSizer: Bool = false
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    public var body: some View {
        LabeledToolbar(label: Text("Insert")) {
            ToolbarImageButton(
                action: { withAnimation { showLinkToolbar.toggle() } },
                active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "link") }
            .disabled(!enabledToolbar(type: .link))
            ToolbarImageButton(
                action: { withAnimation { showImageToolbar.toggle() } },
                active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "photo") }
            .disabled(!enabledToolbar(type: .image))
            // If we are creating a table, then we need to show the TableSizer first and then
            // show the TableToolbar if we created one. If we are already in a table, then
            // just toggle the TableToolbar.
            ToolbarImageButton(
                action: {
                    withAnimation {
                        if showTableToolbar || selectionState.isInTable {
                            showTableToolbar.toggle()
                        } else {
                            showTableSizer.toggle()
                        }
                    }
                },
                active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "tablecells") }
            .disabled(!enabledToolbar(type: .table))
            .popover(isPresented: $showTableSizer) {
                TableSizer(rows: $rows, cols: $cols, showing: $showTableSizer, tapped: $tappedInTableSizer)
                    .onAppear() {
                        rows = 0
                        cols = 0
                    }
                    .onDisappear() {
                        if tappedInTableSizer && rows > 0 && cols > 0 {
                            selectedWebView?.insertTable(rows: rows, cols: cols) {
                                withAnimation { showTableToolbar.toggle() }
                            }
                        }
                    }
            }
        }
    }
    
    private func enabledToolbar(type: MarkupToolbar.ToolbarType) -> Bool {
        // The disabled logic is too hard to wrap my head around, so this is the enabled logic.
        // Always enabled if we are showing this type of toolbar, so we can hide it again.
        // Otherwise, enabled if we are not showing one of the other toolbars and the selectionState is proper
        switch type {
        case .link:
            return showLinkToolbar || (!(showImageToolbar || showTableToolbar) && selectionState.isLinkable)
        case .image:
            return showImageToolbar || (!(showLinkToolbar || showTableToolbar) && selectionState.isInsertable)
        case .table:
            return showTableToolbar || (!(showLinkToolbar || showImageToolbar) && selectionState.isInsertable)
        }
    }
    
    private func createTable() {
        
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showLinkToolbar: Binding<Bool>, showImageToolbar: Binding<Bool>, showTableToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showLinkToolbar = showLinkToolbar
        _showImageToolbar = showImageToolbar
        _showTableToolbar = showTableToolbar
    }
    
}

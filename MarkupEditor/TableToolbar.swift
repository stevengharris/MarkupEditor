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
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    
    public var body: some View {
        HStack(alignment: .bottom) {
            Group {
                LabeledToolbar(label: Text("Rows")) {
                    Stepper(onIncrement: incrementRows, onDecrement: decrementRows) {
                        Text("\(rows)")
                            .frame(width: 20, alignment: .trailing)
                    }
                    .scaledToFit()
                }
                LabeledToolbar(label: Text("Columns")) {
                    Stepper(onIncrement: incrementCols, onDecrement: decrementCols) {
                        Text("\(cols)")
                            .frame(width: 20, alignment: .trailing)
                    }
                    .scaledToFit()
                }
            }
            .disabled(selectionState.isInTable)
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
        _rows = State(initialValue: selectionState.rows)
        _cols = State(initialValue: selectionState.cols)
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
    
    private func incrementRows() {
        // Rows and columns both must always be > 0 when either is > 0
        print("incrementRows")
        rows += 1
        if rows == 1 {
            cols = 1
        }
        insertOrModify()
    }
    
    private func decrementRows() {
        // Rows and columns must both be zero when either is 0
        let oldRows = rows
        rows -= 1
        if rows <= 0 {
            rows = 0
            cols = 0
        }
        if rows < oldRows {
            insertOrModify()
        }
    }
    
    private func incrementCols() {
        // Rows and columns both must always be > 0 when either is > 0
        cols += 1
        if cols == 1 {
            rows = 1
        }
        insertOrModify()
    }
    
    private func decrementCols() {
        // Rows and columns must both be zero when either is 0
        let oldCols = cols
        cols -= 1
        if cols <= 0 {
            cols = 0
            rows = 0
        }
        if cols < oldCols {
            insertOrModify()
        }
    }
    
    private func insertOrModify() {
        if selectionState.isInTable {
            //selectedWebView?.modifyTable(rows: rows, cols: cols)
        } else {
            selectedWebView?.insertTable(rows: rows, cols: cols)
        }
    }
    
}

struct TableToolbar_Previews: PreviewProvider {
    static var previews: some View {
        LinkToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showToolbar: .constant(true))
    }
}

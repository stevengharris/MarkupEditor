//
//  InsertToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/24/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar used for creating/editing links, images, and tables.
public struct InsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    let contents: InsertContents = MarkupEditor.toolbarContents.insertContents
    @State private var hoverLabel: Text = Text("Insert")
    @State private var showTablePopover: Bool = false
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    
    public var body: some View {
        //if #available(iOS 15.0, macCatalyst 15.0, *) {
        //    let _ = Self._printChanges()
        //}
        LabeledToolbar(label: hoverLabel) {
            if contents.link {
                ToolbarImageButton(
                    systemName: "link",
                    action: { MarkupEditor.selectedWebView?.showLinkPopover() },
                    active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text("Insert Link") } else { hoverLabel = Text("Insert") } }
                )
            }
            if contents.image {
                ToolbarImageButton(
                    systemName: "photo",
                    action: { MarkupEditor.selectedWebView?.showImagePopover() },
                    active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text("Insert Image") } else { hoverLabel = Text("Insert") } }
                )
            }
            if contents.table {
                ToolbarImageButton(
                    systemName: "squareshape.split.3x3",
                    action: {
                        MarkupEditor.selectedWebView?.startModalInput()
                        showTablePopover = true
                    },
                    active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text(selectionState.isInTable ? "Edit Table" : "Insert Table") } else { hoverLabel = Text("Insert") } }
                )
                .forcePopover(isPresented: $showTablePopover) {
                    if selectionState.isInTable {
                        TableToolbar(showing: $showTablePopover)
                            .padding()
                            .environmentObject(MarkupEditor.toolbarStyle)
                    } else {
                        TableSizer(rows: $rows, cols: $cols, showing: $showTablePopover)
                            .onAppear() {
                                rows = 0
                                cols = 0
                            }
                            .onDisappear() {
                                if rows > 0 && cols > 0 {
                                    MarkupEditor.selectedWebView?.insertTable(rows: rows, cols: cols)
                                }
                            }
                    }
                }
            }
        }
    }
    
}

struct InsertToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            HStack {
                InsertToolbar()
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                InsertToolbar()
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

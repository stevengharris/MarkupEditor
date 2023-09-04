//
//  InsertToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/24/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar used for creating/editing links, images, and tables.
///
/// Note the flow of control. The button actions invoke the `showPluggable[Link/Image/Table]Toolbar` method
/// in the `selectedWebView`. These in turn invoke the MarkupDelegate's `show[Link/Image/Table]Toolbar` method.
/// You can override those methods in your delegate to plug in your own views instead of the defaults. By default, the
/// MarkupDelegate calls back to the `selectedWebView.show[Link/Image/Table]Toolbar` method, which
/// uses a UIKit or SwiftUI method depending on the type of insert popover chosen. This way we also get consistent
/// behavior between buttons in the InsertToolbar and the menu selections while giving flexibility on user-supplied
/// presentation.
public struct InsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    @ObservedObject private var showPopoverType: ShowInsertPopover = MarkupEditor.showInsertPopover
    let contents: InsertContents = MarkupEditor.toolbarContents.insertContents
    @State private var hoverLabel: Text = Text("Insert")
    @State private var showTablePopover: Bool = false
    @State private var rows: Int = 0
    @State private var cols: Int = 0
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            if contents.link {
                ToolbarImageButton(
                    systemName: "link",
                    action: { MarkupEditor.selectedWebView?.showPluggableLinkPopover() },
                    active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text("Insert Link") } else { hoverLabel = Text("Insert") } }
                )
            }
            if contents.image {
                ToolbarImageButton(
                    systemName: "photo",
                    action: { MarkupEditor.selectedWebView?.showPluggableImagePopover() },
                    active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text("Insert Image") } else { hoverLabel = Text("Insert") } }
                )
            }
            if contents.table {
                ToolbarImageButton(
                    systemName: "squareshape.split.3x3",
                    action: { MarkupEditor.selectedWebView?.showPluggableTablePopover() },
                    active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                    onHover: { over in if over { hoverLabel = Text(selectionState.isInTable ? "Edit Table" : "Insert Table") } else { hoverLabel = Text("Insert") } }
                )
                .forcePopover(isPresented: $showTablePopover) {
                    // We pass $showTablePopover so that the view can dismiss itself
                    if selectionState.isInTable {
                        TableToolbar(showing: $showTablePopover)
                            .padding()
                            .environmentObject(MarkupEditor.toolbarStyle)
                            .onDisappear {
                                MarkupEditor.showInsertPopover.type = nil
                            }
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
                                MarkupEditor.showInsertPopover.type = nil
                            }
                    }
                }
            }
        }
        .onChange(of: showPopoverType.type) { type in
            switch type {
            case .table:
                showTablePopover = true
            case .link, .image, .none:
                showTablePopover = false
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

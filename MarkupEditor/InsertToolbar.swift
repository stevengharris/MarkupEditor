//
//  InsertToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/24/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar used to open the subtoolbars for creating/editing links, images, and tables.
public struct InsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    @ObservedObject private var showSubToolbar: ShowSubToolbar = MarkupEditor.showSubToolbar
    let contents: InsertContents = MarkupEditor.toolbarContents.insertContents
    private var showAnyToolbar: Bool { showSubToolbar.type != nil }
    @State private var hoverLabel: Text = Text("Insert")
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            if contents.link {
                ToolbarImageButton(
                    systemName: "link",
                    action: { withAnimation { showOnly(.link) } },
                    active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 }),
                    onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .link : nil)) } }
                )
            }
            if contents.image {
                ToolbarImageButton(
                    systemName: "photo",
                    action: { withAnimation { showOnly(.image) } },
                    active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                    onHover:  { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .image : nil)) } }
                )
            }
            if contents.table {
                ToolbarImageButton(
                    systemName: "squareshape.split.3x3",
                    action: { withAnimation { showOnly(.table)} },
                    active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                    onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .table : nil)) } }
                )
            }
        }
    }
    
    private func showOnly(_ type: SubToolbar.ToolbarType) {
        if showSubToolbar.type == nil || showSubToolbar.type != type {
            showSubToolbar.type = type
            hoverLabel = Text(labelString(for: type))
        } else {
            showSubToolbar.type = nil
            hoverLabel = Text(labelString(for: .none))
        }
    }
    
    private func labelString(for type: SubToolbar.ToolbarType?) -> String {
        switch type {
        case .link:
            return "Insert Link"
        case .image:
            return "Insert Image"
        case .table:
            return "Insert Table"
        case .none:
            return "Insert"
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

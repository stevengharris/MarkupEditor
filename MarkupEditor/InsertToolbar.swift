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
    @ObservedObject private var showSubToolbar: ShowSubToolbar
    let contents: InsertContents = MarkupEditor.toolbarContents.insertContents
    private var showAnyToolbar: Bool { showSubToolbar.type != .none }
    @State private var hoverLabel: Text = Text("Insert")
    
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
                    onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .link : .none)) } }
                )
            }
            if contents.image {
                ToolbarImageButton(
                    systemName: "photo",
                    action: { MarkupEditor.selectedWebView?.showImagePopover()  },
                    active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                    onHover:  { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .image : .none)) } }
                )
            }
            if contents.table {
                ToolbarImageButton(
                    systemName: "squareshape.split.3x3",
                    action: { withAnimation { showOnly(.table)} },
                    active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                    onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .table : .none)) } }
                )
            }
        }
    }
    
    public init(for markupToolbar: MarkupToolbar) {
        showSubToolbar = markupToolbar.showSubToolbar
    }
    
    private func showOnly(_ type: SubToolbar.ToolbarType) {
        if showSubToolbar.type == .none || showSubToolbar.type != type {
            showSubToolbar.type = type
            hoverLabel = Text(labelString(for: type))
        } else {
            showSubToolbar.type = .none
            hoverLabel = Text(labelString(for: .none))
        }
    }
    
    private func labelString(for type: SubToolbar.ToolbarType) -> String {
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
                InsertToolbar(for: MarkupToolbar(.compact))
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                InsertToolbar(for: MarkupToolbar(.labeled))
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

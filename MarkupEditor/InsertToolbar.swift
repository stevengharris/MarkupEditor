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
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @EnvironmentObject private var showSubToolbar: ShowSubToolbar
    private var showAnyToolbar: Bool { showSubToolbar.type != nil }
    @State private var hoverLabel: Text = Text("Insert")
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                systemName: "link",
                action: { withAnimation { showOnly(.link) } },
                active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 }),
                onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .link : nil)) } }
            )
            ToolbarImageButton(
                systemName: "photo",
                action: { withAnimation { showOnly(.image) } },
                active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                onHover:  { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .image : nil)) } }
            )
            ToolbarImageButton(
                systemName: "squareshape.split.3x3",
                action: { withAnimation { showOnly(.table)} },
                active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .table : nil)) } }
            )
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
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
    
}

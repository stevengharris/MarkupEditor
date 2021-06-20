//
//  InsertToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/24/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct InsertToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @Binding private var showLinkToolbar: Bool
    @Binding private var showImageToolbar: Bool
    @Binding private var showTableToolbar: Bool
    private var showAnyToolbar: Bool { showLinkToolbar || showImageToolbar || showTableToolbar }
    @State private var hoverLabel: Text = Text("Insert")
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                action: { withAnimation { showOnly(.link) } },
                active: Binding<Bool>(get: { selectionState.isInLink }, set: { _ = $0 }),
                onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .link : nil)) } }
            ) { Image.forToolbar(systemName: "link") }
            ToolbarImageButton(
                action: { withAnimation { showOnly(.image) } },
                active: Binding<Bool>(get: { selectionState.isInImage }, set: { _ = $0 }),
                onHover:  { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .image : nil)) } }
            ) { Image.forToolbar(systemName: "photo") }
            ToolbarImageButton(
                action: { withAnimation { showOnly(.table)} },
                active: Binding<Bool>(get: { selectionState.isInTable }, set: { _ = $0 }),
                onHover: { over in if !showAnyToolbar { hoverLabel = Text(labelString(for: over ? .table : nil)) } }
            ) { Image.forToolbar(systemName: "squareshape.split.3x3") }
        }
    }
    
    private func showOnly(_ type: MarkupToolbar.ToolbarType) {
        switch type {
        case .link:
            if showImageToolbar { showImageToolbar.toggle() }
            if showTableToolbar { showTableToolbar.toggle() }
            showLinkToolbar.toggle()
            hoverLabel = Text(labelString(for: .link))
        case .image:
            if showLinkToolbar { showLinkToolbar.toggle() }
            if showTableToolbar { showTableToolbar.toggle() }
            showImageToolbar.toggle()
            hoverLabel = Text(labelString(for: .image))
        case .table:
            if showLinkToolbar { showLinkToolbar.toggle() }
            if showImageToolbar { showImageToolbar.toggle() }
            showTableToolbar.toggle()
            hoverLabel = Text(labelString(for: .table))
        }
    }
    
    private func labelString(for type: MarkupToolbar.ToolbarType?) -> String {
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
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showLinkToolbar: Binding<Bool>, showImageToolbar: Binding<Bool>, showTableToolbar: Binding<Bool>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showLinkToolbar = showLinkToolbar
        _showImageToolbar = showImageToolbar
        _showTableToolbar = showTableToolbar
    }
    
}

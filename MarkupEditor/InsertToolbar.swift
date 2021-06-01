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
    public var body: some View {
        LabeledToolbar(label: Text("Insert")) {
            ToolbarImageButton(
                action: { withAnimation { showOnly(.link) } },
                active: Binding<Bool>(get: { showLinkToolbar || selectionState.isInLink }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "link") }
            ToolbarImageButton(
                action: { withAnimation { showOnly(.image) } },
                active: Binding<Bool>(get: { showImageToolbar || selectionState.isInImage }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "photo") }
            ToolbarImageButton(
                action: { withAnimation { showOnly(.table)} },
                active: Binding<Bool>(get: { showTableToolbar || selectionState.isInTable }, set: { _ = $0 })
            ) { Image.forToolbar(systemName: "squareshape.split.3x3") }
        }
    }
    
    private func showOnly(_ type: MarkupToolbar.ToolbarType) {
        switch type {
        case .link:
            if showImageToolbar { showImageToolbar.toggle() }
            if showTableToolbar { showTableToolbar.toggle() }
            showLinkToolbar.toggle()
        case .image:
            if showLinkToolbar { showLinkToolbar.toggle() }
            if showTableToolbar { showTableToolbar.toggle() }
            showImageToolbar.toggle()
        case .table:
            if showLinkToolbar { showLinkToolbar.toggle() }
            if showImageToolbar { showImageToolbar.toggle() }
            showTableToolbar.toggle()
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

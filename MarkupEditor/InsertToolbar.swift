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
    @Binding private var showToolbarByType: [MarkupToolbar.ToolbarType : Bool]
    private var showLinkToolbar: Bool { showToolbarByType[.link] ?? false }
    private var showImageToolbar: Bool { showToolbarByType[.image] ?? false }
    private var showTableToolbar: Bool { showToolbarByType[.table] ?? false }
    public var body: some View {
        VStack(spacing: 2) {
            Text("Insert")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                ToolbarImageButton(
                    image:  Image(systemName: "link"),
                    action: { toggleToolbar(type: .link) },
                    active: selectionState.isInLink
                )
                .id(UUID())
                .disabled(!enabledToolbar(type: .link))
                ToolbarImageButton(
                    image: Image(systemName: "photo"),
                    action: { toggleToolbar(type: .image) },
                    active: selectionState.isInImage
                )
                .id(UUID())
                .disabled(!enabledToolbar(type: .image))
                ToolbarImageButton(
                    image:  Image(systemName: "tablecells"),
                    action: { toggleToolbar(type: .table) },
                    active: selectionState.isInTable
                )
                .id(UUID())
                .disabled(!enabledToolbar(type: .table))
                /*
                Button(action: {
                    showAlert(type: .line)
                }) {
                    Image(systemName: "line.horizontal.3")
                }
                .disabled(!selectionState.isInsertable)
                Button(action: {
                    showAlert(type: .sketch)
                }) {
                    Image(systemName: "scribble")
                }
                .disabled(!selectionState.isInsertable)
                Button(action: {
                    showAlert(type: .codeblock)
                }) {
                    Image(systemName: "curlybraces")
                }
                .disabled(!selectionState.isInsertable)
                */
            }
        }
    }
    
    private func toggleToolbar(type: MarkupToolbar.ToolbarType) {
        withAnimation {
            showToolbarByType[type] = !(showToolbarByType[type] ?? false)
        }
    }
    
    private func enabledToolbar(type: MarkupToolbar.ToolbarType) -> Bool {
        // The disabled logic is too hard to wrap my head around, so this is the enabled logic.
        // Always enabled if we are showing this type of toolbar, so we can hide it again.
        // Otherwise, enabled if we are not showing one of the other toolbars and the selectionState is proper
        switch type {
        case .image:
            return showImageToolbar || (!(showLinkToolbar || showTableToolbar) && selectionState.isInsertable)
        case .link:
            return showLinkToolbar || (!(showImageToolbar || showTableToolbar) && selectionState.isLinkable)
        case .table:
            return showTableToolbar || (!(showLinkToolbar || showImageToolbar) && selectionState.isInsertable)
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showToolbarByType: Binding<[MarkupToolbar.ToolbarType : Bool]>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showToolbarByType = showToolbarByType
    }
    
}

struct InsertToolbar_Previews: PreviewProvider {
    
    static let showToolbarByType: [MarkupToolbar.ToolbarType : Bool] = [
        .image : false,
        .link : false,
        .table : false
    ]
    
    static var previews: some View {
        InsertToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil), showToolbarByType: .constant(showToolbarByType))
    }
    
}

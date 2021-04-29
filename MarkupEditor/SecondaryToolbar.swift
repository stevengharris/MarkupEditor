//
//  SecondaryToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/29/21.
//

import SwiftUI

public struct SecondaryToolbar: View, Identifiable {
    typealias ToolbarType = MarkupToolbar.ToolbarType
    public let id = UUID()
    @Binding private var showToolbarByType: [ToolbarType : Bool]
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>, showToolbarByType: Binding<[MarkupToolbar.ToolbarType : Bool]>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
        _showToolbarByType = showToolbarByType
    }
    
    public var body: some View {
        Group {
            if showToolbarByType[.image] ?? false {
                ImageToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .image))
            }
            if showToolbarByType[.link] ?? false {
                LinkToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .link))
            }
            if showToolbarByType[.table] ?? false {
                TableToolbar(selectionState: selectionState, selectedWebView: $selectedWebView, showToolbar: showToolbarBinding(type: .table))
            }
        }
    }
    
    private func showToolbarBinding(type: ToolbarType) -> Binding<Bool> {
        return Binding(get: {showToolbarByType[type] ?? false}, set: { showToolbarByType[type] = $0 })
    }
    
}

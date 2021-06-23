//
//  CorrectionToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar for undo and redo.
public struct CorrectionToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @State private var hoverLabel: Text = Text("Correction")
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                action: { selectedWebView?.undo() },
                onHover: { over in hoverLabel = Text(over ? "Undo" : "Correction") }
            ) {
                Image.forToolbar(systemName: "arrow.uturn.backward")
            }
            ToolbarImageButton(
                action: { selectedWebView?.redo() },
                onHover: { over in hoverLabel = Text(over ? "Redo" : "Correction") }
            ) {
                Image.forToolbar(systemName: "arrow.uturn.forward")
            }
        }
    }

    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
    
}

struct CorrectionToolbar_Previews: PreviewProvider {
    static var previews: some View {
        CorrectionToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}

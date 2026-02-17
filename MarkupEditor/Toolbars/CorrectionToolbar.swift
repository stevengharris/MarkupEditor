//
//  CorrectionToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

#if !os(macOS)

import SwiftUI

/// The toolbar for undo and redo.
public struct CorrectionToolbar: View {
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @State private var hoverLabel: Text = Text("Correction")
    
    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            ToolbarImageButton(
                systemName: "arrow.uturn.backward",
                action: { observedWebView.selectedWebView?.undo() },
                onHover: { over in hoverLabel = Text(over ? "Undo" : "Correction") }
            )
            ToolbarImageButton(
                systemName: "arrow.uturn.forward",
                action: { observedWebView.selectedWebView?.redo() },
                onHover: { over in hoverLabel = Text(over ? "Redo" : "Correction") }
            )
        }
    }
    
}

struct CorrectionToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            HStack {
                CorrectionToolbar()
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                CorrectionToolbar()
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

#endif

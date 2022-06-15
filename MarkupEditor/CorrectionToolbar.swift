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
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
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
        let compactMarkupEnv = MarkupEnv(style: .compact)
        let compactPreference = compactMarkupEnv.toolbarPreference
        let labeledMarkupEnv = MarkupEnv(style: .labeled)
        let labeledPreference = labeledMarkupEnv.toolbarPreference
        VStack(alignment: .leading) {
            HStack {
                CorrectionToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(compactPreference)
                    .frame(height: compactPreference.height())
                Spacer()
            }
            HStack {
                CorrectionToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(labeledPreference)
                    .frame(height: labeledPreference.height())
                Spacer()
            }
            Spacer()
        }
    }
}

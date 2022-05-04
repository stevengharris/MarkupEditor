//
//  StyleToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// The toolbar for setting the paragraph style.
public struct StyleToolbar: View {
    @EnvironmentObject private var toolbarPreference: ToolbarPreference
    @EnvironmentObject private var observedWebView: ObservedWebView
    @EnvironmentObject private var selectionState: SelectionState
    @State private var hoverLabel: Text = Text("Paragraph Style")

    public init() {}

    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            // I spent a long time trying to make the drop-down buttons show in the proper font.
            // AFAICT, Apple is doing something aggressive to prevent that from happening.
            // Maybe it messes something up on MacOS. OTOH, I see it on OneNote as a kind of
            // tooltip-looking thing. I suppose the only way to work around it for now would
            // be to build it myself and not use Menu. I might do this using a drop-down toolbar
            // like I did for insert operations.
            // Note that the "Optimize Interface for Mac" deployment choice looks the same
            // as "Scale Interface from iPad" due to the BorderlessButtonMenuStyle.
            // Like other uses of Button, I added contentShape here try to prevent responsiveness
            // problems per https://stackoverflow.com/a/67377002/8968411
            Menu {
                ForEach(StyleContext.StyleCases, id: \.self) { styleContext in
                    Button(action: { observedWebView.selectedWebView?.replaceStyle(in: selectionState, with: styleContext) }) {
                        Text(styleContext.name)
                            .font(.system(size: styleContext.fontSize))
                    }
                    .contentShape(Rectangle())
                }
            } label: {
                Text(selectionState.style.name)
                    .frame(width: 88, height: toolbarPreference.buttonHeight(), alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 88, height: toolbarPreference.buttonHeight())
            .overlay(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
            )
            .contentShape(Rectangle())
            .disabled(selectionState.style == .Undefined)
            Divider()
            ToolbarImageButton(
                systemName: "list.bullet",
                action: { observedWebView.selectedWebView?.toggleListItem(type: .UL) },
                active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .UL }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Bullets" : "Paragraph Style") }
            )
            ToolbarImageButton(
                systemName: "list.number",
                action: { observedWebView.selectedWebView?.toggleListItem(type: .OL) },
                active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .OL }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Numbers" : "Paragraph Style") }
            )
            ToolbarImageButton(
                systemName: "increase.quotelevel",
                action: { observedWebView.selectedWebView?.indent() },
                active: Binding<Bool>(get: { selectionState.quote }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Indent" : "Paragraph Style") }
            )
            ToolbarImageButton(
                systemName: "decrease.quotelevel",
                action: { observedWebView.selectedWebView?.outdent() },
                active: Binding<Bool>(get: { selectionState.quote }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Outdent" : "Paragraph Style") }
            )
        }
    }
    
}

struct StyleToolbar_Previews: PreviewProvider {
    static var previews: some View {
        let compactMarkupEnv = MarkupEnv(style: .compact)
        let compactPreference = compactMarkupEnv.toolbarPreference
        let labeledMarkupEnv = MarkupEnv(style: .labeled)
        let labeledPreference = labeledMarkupEnv.toolbarPreference
        VStack(alignment: .leading) {
            HStack {
                StyleToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(compactPreference)
                    .frame(height: compactPreference.height())
                Spacer()
            }
            HStack {
                StyleToolbar()
                    .environmentObject(SelectionState())
                    .environmentObject(labeledPreference)
                    .frame(height: labeledPreference.height())
                Spacer()
            }
            Spacer()
        }
    }
}

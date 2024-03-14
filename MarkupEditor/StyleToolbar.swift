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
    @EnvironmentObject private var toolbarStyle: ToolbarStyle
    @ObservedObject private var observedWebView: ObservedWebView = MarkupEditor.observedWebView
    @ObservedObject private var selectionState: SelectionState = MarkupEditor.selectionState
    private let contents: StyleContents = MarkupEditor.toolbarContents.styleContents
    @State private var hoverLabel: Text = Text("Paragraph Style")
    private var height: CGFloat { toolbarStyle.height() }

    public init() {}

    public var body: some View {
        LabeledToolbar(label: hoverLabel) {
            // I spent a long time trying to make the drop-down buttons show in the proper font.
            // AFAICT, Apple is doing something aggressive to prevent that from happening.
            // Maybe it messes something up on MacOS. OTOH, I see it on OneNote as a kind of
            // tooltip-looking thing. I suppose the only way to work around it for now would
            // be to build it myself and not use Menu.
            // Note that for Mac Catalyst, the "Optimize Interface for Mac" deployment choice
            // looks different than "Scale Interface from iPad". They used to look the same,
            // but as of iOS 16, the "Optimize Interface for Mac" always has the drop-down
            // arrow next to the title.
            if contents.paragraph {
                if #available(iOS 16, macCatalyst 16, *) {
                    Menu {
                        ForEach(StyleContext.StyleCases, id: \.self) { styleContext in
                            Button(action: { observedWebView.selectedWebView?.replaceStyle(selectionState.style, with: styleContext) }) {
                                Text(styleContext.name)
                                    .font(.system(size: styleContext.fontSize))
                            }
                        }
                    } label: {
                        // Note foreground color is black on Mac Catalyst, which
                        // doesn't seem to be settable at all with "Optimized for Mac"
                        Text(selectionState.style.name)
                            .frame(width: 88, height: toolbarStyle.buttonHeight(), alignment: .center)
                    }
                    .buttonStyle(.borderless)
                    .menuStyle(.button)         // Not available until iOS 16
                    .frame(width: 88, height: toolbarStyle.buttonHeight())
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .stroke(Color.accentColor)
                    )
                    .disabled(!selectionState.canStyle)
                } else {
                    Menu {
                        ForEach(StyleContext.StyleCases, id: \.self) { styleContext in
                            Button(action: { observedWebView.selectedWebView?.replaceStyle(selectionState.style, with: styleContext) }) {
                                Text(styleContext.name)
                                    .font(.system(size: styleContext.fontSize))
                            }
                        }
                    } label: {
                        Text(selectionState.style.name)
                            .frame(width: 88, height: toolbarStyle.buttonHeight(), alignment: .center)
                    }
                    .menuStyle(.borderlessButton)   // Deprecated as of iOS14
                    .frame(width: 88, height: toolbarStyle.buttonHeight())
                    .overlay(
                        RoundedRectangle(
                            cornerRadius: 3,
                            style: .continuous
                        )
                        .stroke(Color.accentColor)
                    )
                    .disabled(!selectionState.canStyle)
                }
                if !contents.listType.isEmpty || contents.dent {
                    Divider()
                }
            }

            ForEach(contents.listType, id: \.self) { type in
                switch type {
                case .bullet:
                    ToolbarImageButton(
                        systemName: "list.bullet",
                        action: { observedWebView.selectedWebView?.toggleListItem(type: .UL) },
                        active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .UL }, set: { _ = $0 }),
                        onHover: { over in hoverLabel = Text(over ? "Bullets" : "Paragraph Style") }
                    )
                case .number:
                    ToolbarImageButton(
                        systemName: "list.number",
                        action: { observedWebView.selectedWebView?.toggleListItem(type: .OL) },
                        active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .OL }, set: { _ = $0 }),
                        onHover: { over in hoverLabel = Text(over ? "Numbers" : "Paragraph Style") }
                    )
                }
            }

            if contents.dent {
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
        .frame(height: height)
    }
    
}

struct StyleToolbar_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading) {
            HStack {
                StyleToolbar()
                    .environmentObject(ToolbarStyle.compact)
                Spacer()
            }
            HStack {
                StyleToolbar()
                    .environmentObject(ToolbarStyle.labeled)
                Spacer()
            }
            Spacer()
        }
    }
}

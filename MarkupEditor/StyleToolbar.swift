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
            // be to build it myself and not use Menu. I might do this using a drop-down toolbar
            // like I did for insert operations.
            // Note that the "Optimize Interface for Mac" deployment choice looks the same
            // as "Scale Interface from iPad" due to the BorderlessButtonMenuStyle.
            // Like other uses of Button, I added contentShape here try to prevent responsiveness
            // problems per https://stackoverflow.com/a/67377002/8968411
            Menu {
                ForEach(StyleContext.StyleCases, id: \.self) { styleContext in
                    Button(action: { observedWebView.selectedWebView?.replaceStyle(selectionState.style, with: styleContext) }) {
                        Text(styleContext.name)
                            .font(.system(size: styleContext.fontSize))
                    }
                    .contentShape(Rectangle())
                }
            } label: {
                Text(selectionState.style.name)
                    .frame(width: 88, height: toolbarStyle.buttonHeight(), alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 88, height: toolbarStyle.buttonHeight())
            .overlay(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
            )
            .contentShape(Rectangle())
            .disabled(!selectionState.canStyle)
            if contents.list || contents.dent {
                Divider()
            }
            if contents.list {
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

//
//  StyleToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public struct StyleToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    @State private var hoverLabel: Text = Text("Paragraph Style")
    
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
                ForEach(StyleContext.StyleCases.filter( { $0 != selectionState.style }) , id: \.self) { styleContext in
                    Button(action: { selectedWebView?.replaceStyle(in: selectionState, with: styleContext) }) {
                        Text(styleContext.name)
                            .font(.system(size: styleContext.fontSize))
                    }
                    .contentShape(Rectangle())
                }
            } label: {
                Text(selectionState.style.name)
                    .frame(width: 88, height: 20, alignment: .center)
            }
            .menuStyle(BorderlessButtonMenuStyle())
            .frame(width: 88, height: 30)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
            )
            .disabled(selectionState.style == .Undefined)
            Divider()
            ToolbarImageButton(
                action: { selectedWebView?.toggleListItem(type: .UL) },
                active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .UL }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Bullets" : "Paragraph Style") }
            ) {
                Image.forToolbar(systemName: "list.bullet")
            }
            ToolbarImageButton(
                action: { selectedWebView?.toggleListItem(type: .OL) },
                active: Binding<Bool>(get: { selectionState.isInListItem && selectionState.list == .OL }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Numbers" : "Paragraph Style") }
            ) {
                Image.forToolbar(systemName: "list.number")
            }
            ToolbarImageButton(
                action: { selectedWebView?.increaseQuoteLevel() },
                active: Binding<Bool>(get: { selectionState.quote }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Indent" : "Paragraph Style") }
            ) {
                Image.forToolbar(systemName: "increase.quotelevel")
            }
            ToolbarImageButton(
                action: { selectedWebView?.decreaseQuoteLevel() },
                active: Binding<Bool>(get: { selectionState.quote }, set: { _ = $0 }),
                onHover: { over in hoverLabel = Text(over ? "Outdent" : "Paragraph Style") }
            ) {
                Image.forToolbar(systemName: "decrease.quotelevel")
            }
            .disabled(!selectionState.quote)
        }
    }
    
    public init(selectionState: SelectionState, selectedWebView: Binding<MarkupWKWebView?>) {
        self.selectionState = selectionState
        _selectedWebView = selectedWebView
    }
    
}

struct StyleToolbar_Previews: PreviewProvider {
    static var previews: some View {
        StyleToolbar(selectionState: SelectionState(), selectedWebView: .constant(nil))
    }
}

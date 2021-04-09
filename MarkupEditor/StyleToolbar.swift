//
//  StyleToolbar.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/7/21.
//

import SwiftUI

public struct StyleToolbar: View {
    @ObservedObject private var selectionState: SelectionState
    @Binding private var selectedWebView: MarkupWKWebView?
    
    public var body: some View {
        VStack(spacing: 2) {
            Text("Style")
                .font(.system(size: 10, weight: .light))
            HStack(alignment: .bottom) {
                // I spent a long time trying to make the drop-down buttons show in the proper font.
                // AFAICT, Apple is doing something aggressive to prevent that from happening.
                // Maybe it messes something up on MacOS. OTOH, I see it on OneNote as a kind of
                // tooltip-looking thing. I suppose the only way to work around it for now would
                // be to build it myself and not use Menu. OTOH, even labels with icons don't work
                // on Catalyst, so it just seems too much like fighting a battle.
                // Currently this menu right-justifies in a fixed width.
                // The build needs to use "Scale Interface to Match iPad" for the menu to appear
                // properly. If "Optimize Interface for Mac" is used, then the Menu has a drop-down
                // arrow next to it and ends up with a weird outline-within-outline look because of
                // the ToolbarMenuStyle.
                Menu {
                    ForEach(StyleContext.StyleCases.filter( { $0 != selectionState.style }) , id: \.self) { styleContext in
                        Button(action: { selectedWebView?.replaceStyle(in: selectionState, with: styleContext) }) {
                            Text(styleContext.name)
                                .font(.system(size: styleContext.fontSize))
                        }
                    }
                } label: {
                    Text(selectionState.style.name)
                        .frame(width: 88, height: 20, alignment: .center)
                }
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
                    image: Image(systemName: "list.bullet"),
                    action: { selectedWebView?.toggleListItem(type: .UL) },
                    active: selectionState.isInListItem && selectionState.list == .UL
                )
                .id(UUID())
                ToolbarImageButton(
                    image: Image(systemName: "list.number"),
                    action: { selectedWebView?.toggleListItem(type: .OL) },
                    active: selectionState.isInListItem && selectionState.list == .OL
                )
                .id(UUID())
                ToolbarImageButton(
                    image: Image(systemName: "increase.quotelevel"),
                    action: { selectedWebView?.increaseQuoteLevel() },
                    active: selectionState.quote
                )
                .id(UUID())
                ToolbarImageButton(
                    image: Image(systemName: "decrease.quotelevel"),
                    action: { selectedWebView?.decreaseQuoteLevel() },
                    active: selectionState.quote
                )
                .id(UUID())
                .disabled(!selectionState.quote)
            }
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

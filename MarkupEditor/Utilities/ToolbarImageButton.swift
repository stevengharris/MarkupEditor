//
//  ToolbarImageButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

#if !os(macOS)

import SwiftUI

/// A square button typically used with a system image in the toolbar.
///
/// These RoundedRect buttons show text and outline in activeColor (.accentColor by default), with the
/// backgroundColor of UIColor.systemBackground. When active, the text and background switch.
public struct ToolbarImageButton<Content: View>: View {
    private let image: Content
    private let systemName: String?
    private let action: ()->Void
    @Binding private var active: Bool
    private let activeColor: Color
    private let help: String
    private let onHover: ((Bool)->Void)?
    
    public var body: some View {
        Button(action: action, label: {
            label()
                .frame(width: MarkupEditor.toolbarStyle.buttonHeight(), height: MarkupEditor.toolbarStyle.buttonHeight())
        })
        .help(help)
        .onHover { over in onHover?(over) }
        // For MacOS buttons (Optimized Interface for Mac), specifying .contentShape
        // fixes some flaky problems in surrounding SwiftUI views that are presented
        // below this one, altho AFAICT not in ones adjacent horizontally.
        // Ref: https://stackoverflow.com/a/67377002/8968411
        .contentShape(RoundedRectangle(cornerRadius: 3))
        .buttonStyle(ToolbarButtonStyle(active: $active, activeColor: activeColor))
    }

    /// Initialize a button using content. See the extension where Content == EmptyView for the systemName style initialization.
    public init(action: @escaping ()->Void, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor, help: String? = nil, onHover: ((Bool)->Void)? = nil, @ViewBuilder content: ()->Content) {
        self.systemName = nil
        self.image = content()
        self.action = action
        _active = active
        self.activeColor = activeColor
        self.help = help ?? ""
        self.onHover = onHover
    }
    
    private func label() -> AnyView {
        // Return either the image derived from content or the properly-sized systemName image based on style
        if systemName == nil {
            return AnyView(image)
        } else {
            return AnyView(Image(systemName: systemName!).imageScale(.large))
        }
    }

}

extension ToolbarImageButton where Content == EmptyView {
    
    /// Initialize a button using a systemImage which will override content, even if passed-in. Intended for use without a content block.
    public init(systemName: String, action: @escaping ()->Void, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor, help: String? = nil, onHover: ((Bool)->Void)? = nil, @ViewBuilder content: ()->Content = { EmptyView() }) {
        self.systemName = systemName
        self.image = content()
        self.action = action
        _active = active
        self.activeColor = activeColor
        self.help = help ?? ""
        self.onHover = onHover
    }
    
}

public struct ToolbarButtonStyle: ButtonStyle {
    @Binding var active: Bool
    let activeColor: Color
    
    public init(active: Binding<Bool>, activeColor: Color) {
        _active = active
        self.activeColor = activeColor
    }
    
    public func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .cornerRadius(3)
            .foregroundColor(active ? Color(UIColor.systemBackground) : activeColor)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
            )
            .background(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .fill(active ? activeColor: Color.clear)
            )
            // On Mac Catalyst, a non-transparent background is required so UIKit/AppKit has
            // a rendered layer to hit-test against. Without it, hits fall through to whatever
            // is behind the toolbar when hosted in a UIKit navigation bar ToolbarItem.
            // systemBackground adapts to light/dark mode and is visually invisible here.
            .background(Color(UIColor.systemBackground))
            .contentShape(Rectangle())
    }
}

#endif

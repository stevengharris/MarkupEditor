//
//  ToolbarButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

/// A square button typically used with a system image in the toolbar.
///
/// These RoundedRect buttons show text and outline in activeColor (.accentColor by default), with the
/// backgroundColor of UIColor.systemBackground. When active, the text and background switch.
/// The buttons should look nearly identical on for UIDevice.current.userInterfaceIdiom == .mac and .pad,
/// but the Image passed-in using ViewBuilder should be set using Image.forToolbar() to have the image
/// sizes match.
public struct ToolbarImageButton<Content: View>: View {
    @EnvironmentObject var toolbarPreference: ToolbarPreference
    let image: Content
    let systemName: String?
    let action: ()->Void
    @Binding var active: Bool
    let activeColor: Color
    let onHover: ((Bool)->Void)?
    
    public var body: some View {
        Button(action: action, label: {
            label()
                .frame(width: toolbarPreference.buttonHeight(), height: toolbarPreference.buttonHeight())
        })
        .onHover { over in onHover?(over) }
        // For MacOS buttons (Optimized Interface for Mac), specifying .contentShape
        // fixes some flaky problems in surrounding SwiftUI views that are presented
        // below this one, altho AFAICT not in ones adjacent horizontally.
        // Ref: https://stackoverflow.com/a/67377002/8968411
        .contentShape(RoundedRectangle(cornerRadius: 3))
        .buttonStyle(ToolbarButtonStyle(active: $active, activeColor: activeColor))
    }

    /// Initialize a button using content. See the extension where Content == EmptyView for the systemName style initialization.
    public init(action: @escaping ()->Void, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor, onHover: ((Bool)->Void)? = nil, @ViewBuilder content: ()->Content) {
        self.systemName = nil
        self.image = content()
        self.action = action
        _active = active
        self.activeColor = activeColor
        self.onHover = onHover
    }
    
    private func label() -> AnyView {
        // Return either the image derived from content or the properly-sized systemName image based on style
        if systemName == nil {
            return AnyView(image)
        } else {
            return AnyView(Image.forToolbar(systemName: systemName!, style: toolbarPreference.style))
        }
    }

}

extension ToolbarImageButton where Content == EmptyView {
    
    /// Initialize a button using a systemImage which will override content, even if passed-in. Intended for use without a content block.
    public init(systemName: String, action: @escaping ()->Void, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor, onHover: ((Bool)->Void)? = nil, @ViewBuilder content: ()->Content = { EmptyView() }) {
        self.systemName = systemName
        self.image = content()
        self.action = action
        _active = active
        self.activeColor = activeColor
        self.onHover = onHover
    }
    
}

public struct ToolbarTextButton: View {
    @EnvironmentObject var toolbarPreference: ToolbarPreference
    let title: String
    let action: ()->Void
    let width: CGFloat?
    @Binding var active: Bool
    let activeColor: Color
    
    public var body: some View {
        Button(action: action, label: {
            Text(title)
                .frame(width: width, height: toolbarPreference.buttonHeight())
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(
                        cornerRadius: 3,
                        style: .continuous
                    )
                    .stroke(Color.accentColor)
                    .background(Color(UIColor.systemGray6))
                )
        })
        .contentShape(RoundedRectangle(cornerRadius: 3))
        .buttonStyle(ToolbarButtonStyle(active: $active, activeColor: activeColor))
    }
    
    public init(title: String, action: @escaping ()->Void, width: CGFloat? = nil, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor) {
        self.title = title
        self.action = action
        self.width = width
        _active = active
        self.activeColor = activeColor
    }
    
}

struct ToolbarButtonStyle: ButtonStyle {
    @Binding var active: Bool
    let activeColor: Color
    
    func makeBody(configuration: Self.Configuration) -> some View {
        configuration.label
            .cornerRadius(3)
            .foregroundColor(active ? Color.clear : activeColor)
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
    }
}

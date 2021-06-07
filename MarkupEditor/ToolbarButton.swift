//
//  ToolbarButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//

import SwiftUI

/// A 30x30 button typically used with a system image in the toolbar.
///
/// These RoundedRect buttons show text and outline in activeColor (.accentColor by default), with the
/// backgroundColor of UIColor.systemBackground. When active, the text and background switch.
/// The buttons should look nearly identical on for UIDevice.current.userInterfaceIdiom == .mac and .pad,
/// but the Image passed-in using ViewBuilder should be set using Image.forToolbar() to have the image
/// sizes match.
public struct ToolbarImageButton<Content: View>: View {
    let image: Content
    let action: ()->Void
    @Binding var active: Bool
    let activeColor: Color
    let onHover: ((Bool)->Void)?
    
    public var body: some View {
        Button(action: action, label: {
            image
                .frame(width: 30, height: 30)
        })
        .onHover { over in onHover?(over) }
        // For MacOS buttons (Optimized Interface for Mac), specifying .contentShape
        // fixes some flaky problems in surrounding SwiftUI views that are presented
        // below this one, altho AFAICT not in ones adjacent horizontally.
        // Ref: https://stackoverflow.com/a/67377002/8968411
        .contentShape(RoundedRectangle(cornerRadius: 3))
        .buttonStyle(ToolbarButtonStyle(active: $active, activeColor: activeColor))
    }

    public init(action: @escaping ()->Void, active: Binding<Bool> = .constant(false), activeColor: Color = .accentColor, onHover: ((Bool)->Void)? = nil, @ViewBuilder content: ()->Content) {
        self.image = content()
        self.action = action
        _active = active
        self.activeColor = activeColor
        self.onHover = onHover
    }

}

public struct ToolbarTextButton: View {
    let title: String
    let action: ()->Void
    let width: CGFloat?
    @Binding var active: Bool
    let activeColor: Color
    
    public var body: some View {
        Button(action: action, label: {
            Text(title)
                .frame(width: width, height: 30)
                .padding([.leading, .trailing], 8)
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
            .foregroundColor(active ? Color(UIColor.systemBackground) : activeColor)
            .background(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
                .background(active ? activeColor: Color(UIColor.systemBackground))
            )
    }
}

//
//  MarkupToolbarStyles.swift
//  
//
//  Created by Steven Harris on 3/24/21.
//

import SwiftUI

/// A ButtonStyle that fills-in or outlines depending on what active is set to. Filled-in indicates active is true.
/// The type of alerts that can be shown by the MarkupToolbar, primarily for insert operations
public struct ToolbarImageButtonStyle: ButtonStyle {
    var active: Bool = false
    
    public func makeBody(configuration: Configuration) -> some View {
        // Fill the button when active; else outline in accent color
        configuration.label
            .frame(width: 30, height: 30)
            .background(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
                .background(active ? Color.accentColor : Color(UIColor.systemBackground))
            )
            .foregroundColor(active ? Color(UIColor.systemBackground) : Color.accentColor)
    }

}

/// A ButtonStyle for text buttons
/// The type of alerts that can be shown by the MarkupToolbar, primarily for insert operations
public struct ToolbarTextButtonStyle: ButtonStyle {
    var active: Bool = false
    
    public func makeBody(configuration: Configuration) -> some View {
        // Fill the button when active; else outline in accent color
        configuration.label
            .frame(height: 30)
            .background(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
                .background(Color(UIColor.systemGray6))
            )
    }

}

/// A MenuStyle with a RoundedRectangle surrounding it, to match the ToolbarImageButtonStyle
public struct ToolbarMenuStyle: MenuStyle {
    
    public func makeBody(configuration: Configuration) -> some View {
        // Fill the button when active; else outline in accent color
        // Use overlay for the outline, and since we only use this menu
        // for style, it is always set to the current style or disabled,
        // so no need to deal with active.
        Menu(configuration)
            .frame(width: 88, height: 30)
            .overlay(
                RoundedRectangle(
                    cornerRadius: 3,
                    style: .continuous
                )
                .stroke(Color.accentColor)
            )
    }

}



//
//  ToolbarButton.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/5/21.
//

import SwiftUI

public struct ToolbarTextButton: View, Identifiable {
    public let id = UUID()
    let title: String
    let action: ()->Void
    let width: CGFloat?
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
    }
    
    public init(title: String, action: @escaping ()->Void, width: CGFloat? = nil) {
        self.title = title
        self.action = action
        self.width = width
    }
    
}

/// A 30x30 button typically used with a system image in the toolbar.
///
/// It's important for users of these buttons to specify a proper id for them, or they can randomly
/// cause bad behavior in other areas. Specifically, when using these buttons in the MarkupToolbar
/// and TextFields in the MarkupImageToolbar below it that would appear/disappear, the entire
/// MarkupImageToolbar would cease responding to clicks except in Buttons. So, for example,
/// the TextFields could not obtain focus, and even the MarkupWKWebView would stop responding
/// to selection.
public struct ToolbarImageButton: View, Identifiable {
    public let id = UUID()
    let image: Image
    let action: ()->Void
    var active: Bool = false
    public var body: some View {
        Button(action: action, label: {
            image
                .frame(width: 30, height: 30)
                .contentShape(RoundedRectangle(cornerRadius: 3))
        })
        .cornerRadius(3)
        .foregroundColor(active ? Color(UIColor.systemBackground) : Color.accentColor)
        .background(
            RoundedRectangle(
                cornerRadius: 3,
                style: .continuous
            )
            .stroke(Color.accentColor)
            .background(active ? Color.accentColor : Color(UIColor.systemBackground))
        )
    }

    public init(image: Image, action:  @escaping ()->Void, active: Bool = false) {
        self.image = image
        self.action = action
        self.active = active
    }

}

struct ToolbarButton_Previews: PreviewProvider {
    static var previews: some View {
        ToolbarTextButton(title: "Test", action: { print("Test Text Button") }, width: nil)
        ToolbarImageButton(image: Image(systemName: "photo"), action: { print("Test Image Button") })
    }
}

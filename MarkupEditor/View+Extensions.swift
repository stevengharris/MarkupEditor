//
//  View+Modifiers.swift
//  MarkupEditor
//
//  Modeled after https://pspdfkit.com/blog/2022/presenting-popovers-on-iphone-with-swiftui/
//

import SwiftUI

extension View {
    
    public func forcePopover<Content>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View {
        modifier(ForcePopoverModifier(isPresented: isPresented, contentBlock: content))
    }

}

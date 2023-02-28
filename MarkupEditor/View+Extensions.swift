//
//  View+Modifiers.swift
//  MarkupEditor
//
//  Modeled after https://pspdfkit.com/blog/2022/presenting-popovers-on-iphone-with-swiftui/
//

import SwiftUI

extension View {
    
    public func forcePopover<Content>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View where Content : View {
        // On macCatalyst, the standard .popover works properly, and the ForcePopoverModifier presents
        // across the entire screen.
        #if targetEnvironment(macCatalyst)
            self.popover(isPresented: isPresented, content: content)
        #else
            modifier(ForcePopoverModifier(isPresented: isPresented, content: content))
        #endif
    }

}

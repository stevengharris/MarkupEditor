//
//  ToolbarPreference.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/3/21.
//

import SwiftUI

public class ToolbarPreference: ObservableObject {

    static let shared = ToolbarPreference()

    public enum Style {
        case compact
        case labeled
    }
    
    @Published var style: Style
    
    public init() {
        self.style = .labeled
    }
    
    public init(style: Style) {
        self.style = style
    }
    
}

//public struct StylePreferenceKey: PreferenceKey {
//
//
//
//    public static var defaultValue: style = .labeled
//
//    public static func reduce(value: inout style, nextValue: ()->style) {
//        value = nextValue()
//    }
//
//}

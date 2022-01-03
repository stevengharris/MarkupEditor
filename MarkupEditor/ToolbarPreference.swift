//
//  ToolbarPreference.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/3/21.
//

import SwiftUI

public class ToolbarPreference: ObservableObject {

    public enum Style {
        case compact
        case labeled
    }
    
    @Published var style: Style
    public var allowLocalImages: Bool = true
    
    public init() {
        self.style = .labeled
    }
    
    public init(style: Style) {
        self.style = style
    }
    
    public func height() -> CGFloat {
        switch style {
        case .compact:
            return 30
        case .labeled:
            return 47
        }
    }
    
    public func buttonHeight() -> CGFloat {
        switch style {
        case .compact:
            return 24
        case .labeled:
            return 30
        }
    }
    
    public static func symbolScale(for style: Style) -> UIImage.SymbolScale {
        switch style {
        case .compact:
            return .medium
        case .labeled:
            return .large
        }
    }
    
}

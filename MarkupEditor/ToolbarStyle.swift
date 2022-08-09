//
//  ToolbarStyle.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/8/22.
//

import UIKit

public class ToolbarStyle: ObservableObject {
    
    static let compact = ToolbarStyle(.compact)
    static let labeled = ToolbarStyle(.labeled)
    
    var style: Style
    
    public enum Style {
        case compact
        case labeled
    }
    
    public init(_ style: Style = .labeled) {
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

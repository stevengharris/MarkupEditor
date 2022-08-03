//
//  ToolbarPreference.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/3/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

public class ToolbarPreference: ObservableObject {

    public enum Style {
        case compact
        case labeled
    }
    
    @Published var style: Style
    // Altho we expose allowLocalImages here, imageContents is always the source of truth
    public var allowLocalImages: Bool {
        get { contents.imageContents.allowLocalImages }
        set(value) { contents.imageContents.allowLocalImages = value }
    }
    public var contents: ToolbarContents
    
    public init() {
        self.style = .labeled
        self.contents = ToolbarContents()
    }
    
    public init(style: Style, allowLocalImages: Bool? = nil, contents: ToolbarContents? = nil) {
        self.style = style
        self.contents = contents ?? ToolbarContents()
        self.contents.imageContents.allowLocalImages = allowLocalImages ?? false
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

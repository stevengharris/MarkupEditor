//
//  Image+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/3/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

extension Image {
    
    /// Return an image that is properly scaled for the userInterfaceIdiom and sensitive to the ToolbarStyle
    public static func forToolbar(systemName: String, style: ToolbarStyle.Style = .labeled) -> Image {
        if UIDevice.current.userInterfaceIdiom == .mac {
            let config = UIImage.SymbolConfiguration(scale: ToolbarStyle.symbolScale(for: style))
            let uiImage = UIImage(systemName: systemName, withConfiguration: config)!
            return Image(uiImage: uiImage).renderingMode(.template)
        } else {
            return Image(systemName: systemName)
        }
    }
    
}

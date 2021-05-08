//
//  Image+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/3/21.
//

import SwiftUI

extension Image {
    
    public static func forToolbar(systemName: String) -> Image {
        if UIDevice.current.userInterfaceIdiom == .mac {
            let config = UIImage.SymbolConfiguration(scale: .large)
            return Image(uiImage: UIImage(systemName: systemName, withConfiguration: config)!)
                .renderingMode(.template)
        } else {
            return Image(systemName: systemName)
        }
    }
    
}

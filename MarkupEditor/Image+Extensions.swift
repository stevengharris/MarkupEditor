//
//  Image+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 5/3/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import SwiftUI

extension Image {
    
    /// Return an image that is properly scaled for the userInterfaceIdiom
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

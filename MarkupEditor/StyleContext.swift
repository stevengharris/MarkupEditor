//
//  StyleContext.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import Combine

/// HTML tags treated as styles in the MarkupToolbar. The names are displayed to the user, but the html trucks in tags
public class StyleContext: ObservableObject, Identifiable, Hashable, Equatable, CustomStringConvertible {
    // From log_entry.css, needs templatizing
    // h1 { font-size: 26px; }
    // h2 { font-size: 24px; }
    // h3 { font-size: 22px; }
    // h4 { font-size: 20px; }
    // h5 { font-size: 18px; }
    // h6 { font-size: 16px; }
    // p { font-size: 14px; }

    public static let Undefined = StyleContext(tag: "Undefined", name: "Style", fontSize: P.fontSize)
    public static let P = StyleContext(tag: "P", name: "Normal", fontSize: 14)
    public static let H1 = StyleContext(tag: "H1", name: "Header 1", fontSize: 26)
    public static let H2 = StyleContext(tag: "H2", name: "Header 2", fontSize: 24)
    public static let H3 = StyleContext(tag: "H3", name: "Header 3", fontSize: 22)
    public static let H4 = StyleContext(tag: "H4", name: "Header 4", fontSize: 20)
    public static let H5 = StyleContext(tag: "H5", name: "Header 5", fontSize: 18)
    public static let H6 = StyleContext(tag: "H6", name: "Header 6", fontSize: 16)
    public static let AllCases = [Undefined, P, H1, H2, H3, H4, H5, H6]
    public static let StyleCases = [P, H1, H2, H3, H4, H5, H6]
    public static let SizeCases = [P, H6, H5, H4, H3, H2, H1]  // In order smallest to largest
    
    public static func == (lhs: StyleContext, rhs: StyleContext) -> Bool {
        return lhs.tag == rhs.tag
    }
    
    public static func with(tag: String) -> StyleContext {
        if let styleContext = AllCases.first(where: { $0.tag == tag }) {
            return styleContext
        } else {
            return P        // Default to P rather than Undefined
        }
    }
    
    public var id: String { tag }
    @Published public var tag: String
    @Published public var name: String
    @Published public var fontSize: CGFloat
    public var description: String { tag }
    
    private init(tag: String, name: String, fontSize: CGFloat) {
        self.tag = tag
        self.name = name
        self.fontSize = fontSize
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }
}

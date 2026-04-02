//
//  StyleContext.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Combine
import CoreGraphics

/// HTML tags treated as styles in the StyleToolbar. The names are displayed to the user, but the html trucks in tags
@MainActor
public class StyleContext: @unchecked Sendable, ObservableObject, Identifiable, Hashable, Equatable, CustomStringConvertible {
    public static let Undefined = StyleContext(tag: "Undefined", name: "Style", fontSize: P.fontSize)
    public static let Multiple = StyleContext(tag: "Multiple", name: "Multiple", fontSize: P.fontSize)
    public static let P = StyleContext(tag: "P", name: ToolbarContents.shared.name(forTag: "P") ?? "Undefined", fontSize: 14)
    public static let H1 = StyleContext(tag: "H1", name: ToolbarContents.shared.name(forTag: "H1") ?? "Undefined", fontSize: 26)
    public static let H2 = StyleContext(tag: "H2", name: ToolbarContents.shared.name(forTag: "H2") ?? "Undefined", fontSize: 24)
    public static let H3 = StyleContext(tag: "H3", name: ToolbarContents.shared.name(forTag: "H3") ?? "Undefined", fontSize: 22)
    public static let H4 = StyleContext(tag: "H4", name: ToolbarContents.shared.name(forTag: "H4") ?? "Undefined", fontSize: 20)
    public static let H5 = StyleContext(tag: "H5", name: ToolbarContents.shared.name(forTag: "H5") ?? "Undefined", fontSize: 18)
    public static let H6 = StyleContext(tag: "H6", name: ToolbarContents.shared.name(forTag: "H6") ?? "Undefined", fontSize: 16)
    public static let PRE = StyleContext(tag: "PRE", name: ToolbarContents.shared.name(forTag: "PRE") ?? "Undefined", fontSize: 14)
    public static let AllCases = [Undefined, Multiple, P, H1, H2, H3, H4, H5, H6, PRE]
    public static let StyleCases = [P, H1, H2, H3, H4, H5, H6, PRE]
    public static let SizeCases = [P, PRE, H6, H5, H4, H3, H2, H1]  // In order smallest to largest
    
    nonisolated public static func == (lhs: StyleContext, rhs: StyleContext) -> Bool {
        return lhs.id == rhs.id
    }
    
    public static func styleCases() -> [StyleContext] {
        StyleCases.filter { ToolbarContents.shared.name(forTag: $0.tag) != nil }
    }
    
    @MainActor public static func with(tag: String) -> StyleContext {
        if let styleContext = AllCases.first(where: { $0.tag == tag }) {
            return styleContext
        } else {
            return P        // Default to P rather than Undefined
        }
    }
    
    nonisolated public let id: String
    @Published public var tag: String
    @Published public var name: String
    @Published public var fontSize: CGFloat
    nonisolated public var description: String { id }
    
    private init(tag: String, name: String, fontSize: CGFloat) {
        self.id = tag
        self.tag = tag
        self.name = name
        self.fontSize = fontSize
    }

    nonisolated public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

//
//  ListContext.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// Tracks list types in the StyleToolbar.
public class ListContext: @unchecked Sendable, ObservableObject, Identifiable, Hashable, Equatable, CustomStringConvertible {
    
    public static func == (lhs: ListContext, rhs: ListContext) -> Bool {
        return lhs.tag == rhs.tag
    }
    
    public static let Undefined = ListContext(tag: "Undefined")
    public static let UL = ListContext(tag: "UL")
    public static let OL = ListContext(tag: "OL")
    public static let AllCases = [Undefined, UL, OL]
    
    public static func with(tag: String) -> ListContext {
        if let listContext = AllCases.first(where: { $0.tag == tag }) {
            return listContext
        } else {
            return Undefined
        }
    }
    
    public var id: String { tag }
    @Published public var tag: String
    public var description: String { tag }
    
    private init(tag: String) {
        self.tag = tag
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tag)
    }
}

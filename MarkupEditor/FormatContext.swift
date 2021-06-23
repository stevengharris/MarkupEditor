//
//  FormatContext.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/8/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// HTML tags treated as formats in the FormatToolbar.
public class FormatContext: ObservableObject, Identifiable, Hashable, Equatable, CustomStringConvertible {
    
    public static func == (lhs: FormatContext, rhs: FormatContext) -> Bool {
        return lhs.tag == rhs.tag
    }
    
    public static let B = FormatContext(tag: "B")
    public static let I = FormatContext(tag: "I")
    public static let U = FormatContext(tag: "U")
    public static let STRIKE = FormatContext(tag: "DEL")
    public static let SUB = FormatContext(tag: "SUB")
    public static let SUP = FormatContext(tag: "SUP")
    public static let CODE = FormatContext(tag: "CODE")
    public static let AllCases = [B, I, U, STRIKE, SUB, SUP, CODE]
    
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


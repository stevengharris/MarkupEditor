//
//  SelectionState.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/19/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation
import UIKit

/// The state of the selection in a LogEntryView
public class SelectionState: ObservableObject, Identifiable, CustomStringConvertible {
    // Selected text
    @Published public var selection: String? = nil
    // Links
    @Published public var href: String? = nil
    @Published public var link: String? = nil
    // Images
    @Published public var src: String? = nil
    @Published public var alt: String? = nil
    @Published public var scale: Int? = nil  // Percent
    @Published public var frame: CGRect? = nil
    // Tables
    @Published public var table: Bool = false
    @Published public var thead: Bool = false
    @Published public var tbody: Bool = false
    @Published public var colspan: Bool = false
    @Published public var rows: Int = 0
    @Published public var cols: Int = 0
    @Published public var row: Int = 0
    @Published public var col: Int = 0
    // Styles
    @Published public var style: StyleContext = StyleContext.Undefined
    @Published public var list: ListContext = ListContext.Undefined
    @Published public var li: Bool = false
    @Published public var quote: Bool = false
    // Formates
    @Published public var bold: Bool = false
    @Published public var italic: Bool = false
    @Published public var underline: Bool = false
    @Published public var strike: Bool = false
    @Published public var sub: Bool = false
    @Published public var sup: Bool = false
    @Published public var code: Bool = false
    
    // Selection state queries
    public var isLinkable: Bool {
        return link != nil || selection != nil
    }
    public var isFollowable: Bool { // Whether selecting will follow the link
         isInLink && selection == nil
    }
    public var isInLink: Bool {
        return link != nil && href != nil
    }
    public var isInsertable: Bool {
        return selection == nil || selection?.isEmpty ?? true
    }
    public var isStyleNormal: Bool {
        style == .P || style == .Undefined
    }
    public var isStyleLargest: Bool {
        style == .H1
    }
    public var isStyleSmallest: Bool {
        isStyleNormal   // At this point, "normal" is smallest
    }
    public var isInList: Bool {
        list != .Undefined
    }
    public var isInListItem: Bool {
        // Would be an error for li to be true while isInList was false;
        // However, isInList can be true and li false
        isInList && li
    }
    public var isInImage: Bool {
        src != nil  // Possible missing alt
    }
    public var isInTable: Bool {
        return table
    }
    
    // CustomStringConvertible conformance
    public var description: String {
        """
        selection: \(selection ?? "none")
          style: \(style.tag)
          formats: \(formatString())
          list: \(listString())
          quote: \(quote)
          link: \(linkString())
          image: \(imageString())
          table: \(tableString())
        """
    }
    
    public init() {}
    
    public func reset(from selectionState: SelectionState?) {
        selection = selectionState?.selection
        href = selectionState?.href
        link = selectionState?.link
        src = selectionState?.src
        alt = selectionState?.alt
        scale = selectionState?.scale ?? 100
        frame = selectionState?.frame
        table = selectionState?.table ?? false
        thead = selectionState?.thead ?? false
        tbody = selectionState?.tbody ?? false
        colspan = selectionState?.colspan ?? false
        rows = selectionState?.rows ?? 0
        cols = selectionState?.cols ?? 0
        row = selectionState?.row ?? 0
        col = selectionState?.col ?? 0
        style = selectionState?.style ?? StyleContext.Undefined
        list = selectionState?.list ?? ListContext.Undefined
        li = selectionState?.li ?? false
        quote = selectionState?.quote ?? false
        bold = selectionState?.bold ?? false
        italic = selectionState?.italic ?? false
        underline = selectionState?.underline ?? false
        strike = selectionState?.strike ?? false
        sub = selectionState?.sub ?? false
        sup = selectionState?.sup ?? false
        code = selectionState?.code ?? false
    }
    
    func formatString() -> String {
        let formatValues = [bold, italic, underline, strike, sub, sup, code]
        let formats = FormatContext.AllCases
        var tags = [String]()
        for index in formatValues.indices { if formatValues[index] { tags.append("\(formats[index])")} }
        return tags.isEmpty ? "none" : tags.joined(separator: ", ")
    }
    
    func listString() -> String {
        if li {
            return "Inside of <LI> in \(list.tag) list"   // This is an error
        } else {
            if list == .Undefined {
                return "none"
            } else {
                return "Outside of <LI> in \(list.tag) list"
            }
        }
    }
    
    func linkString() -> String {
        guard let href = href, let link = link else { return "none" }
        return "\(href) linksTo: \(link)"
    }
    
    func imageString() -> String {
        guard let src = src else { return "none" }
        return "\(src), alt: \(alt ?? "none"), scale: \(scale ?? 100)%, frame: \(frame ?? CGRect.zero)"
    }
    
    func tableString() -> String {
        guard table else { return "none" }
        let tableSize = "\(rows)x\(cols)"
        let headerType = colspan ? "spanning header" : "non-spanning header"
        if tbody {
            return "in body row \(row), col \(col) of \(tableSize) table with \(headerType)"
        } else {
            if colspan {
                return "in \(headerType) of \(tableSize) table"
            } else {
                return "in col \(col) of \(headerType) of \(tableSize) table"
            }
        }
    }
    
}

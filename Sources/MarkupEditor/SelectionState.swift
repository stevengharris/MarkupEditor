//
//  SelectionState.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/19/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// The state of the selection in a LogEntryView
public class SelectionState: ObservableObject, Identifiable, CustomStringConvertible {
    @Published public var style: StyleContext = StyleContext.Undefined
    @Published public var selection: String? = nil
    @Published public var href: String? = nil
    @Published public var link: String? = nil
    @Published public var bold: Bool = false
    @Published public var italic: Bool = false
    @Published public var underline: Bool = false
    @Published public var strike: Bool = false
    @Published public var sub: Bool = false
    @Published public var sup: Bool = false
    @Published public var code: Bool = false
    @Published public var list: ListContext = ListContext.Undefined
    @Published public var li: Bool = false
    @Published public var quote: Bool = false
    public var isLinkable: Bool {
        return link != nil || selection != nil
    }
    public var isFollowable: Bool {
        return link != nil && href != nil && selection == nil
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
    public var description: String {
        """
        selection: \(selection ?? "none")
          style: \(style.tag)
          formats: \(formatString())
          list: \(listString())
          quote: \(quote)
          link: \(linkString())
        """
    }
    
    public init() {}
    
    public func reset() {
        reset(from: nil)
    }
    
    public func reset(from selectionState: SelectionState?) {
        style = selectionState?.style ?? StyleContext.Undefined
        selection = selectionState?.selection
        href = selectionState?.href
        link = selectionState?.link
        bold = selectionState?.bold ?? false
        italic = selectionState?.italic ?? false
        underline = selectionState?.underline ?? false
        strike = selectionState?.strike ?? false
        sub = selectionState?.sub ?? false
        sup = selectionState?.sup ?? false
        code = selectionState?.code ?? false
        list = selectionState?.list ?? ListContext.Undefined
        li = selectionState?.li ?? false
        quote = selectionState?.quote ?? false
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
    
}

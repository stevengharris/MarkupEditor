//
//  SelectionState.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/19/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit

/// The state of the selection in a MarkupWKWebView
public class SelectionState: ObservableObject, Identifiable, CustomStringConvertible {
    // Validity
    @Published public var valid: Bool = false
    // ID of the contenteditable of the selection or of the enclosing div
    @Published public var divid: String? = nil
    // Selected text
    @Published public var selection: String? = nil
    @Published public var selrect: CGRect? = nil
    // Links
    @Published public var href: String? = nil
    @Published public var link: String? = nil
    // Images
    @Published public var src: String? = nil
    @Published public var alt: String? = nil
    @Published public var width: Int? = nil
    @Published public var height: Int? = nil
    @Published public var scale: Int? = nil  // Percent
    // Tables
    @Published public var table: Bool = false
    @Published public var thead: Bool = false
    @Published public var tbody: Bool = false
    @Published public var header: Bool = false
    @Published public var colspan: Bool = false
    @Published public var rows: Int = 0
    @Published public var cols: Int = 0
    @Published public var row: Int = 0
    @Published public var col: Int = 0
    @Published public var border: MarkupEditor.TableBorder = .cell
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
    
    //MARK: Source rect for popovers
    public var sourceRect: CGRect? {
        guard let selrect else {
            return nil
        }
        // Popover source rect must have non-zero width/height
        return CGRect(origin: selrect.origin, size: CGSize(width: max(selrect.width, 1), height: max(selrect.height, 1)))
    }
    
    //MARK: Selection state queries
    public var isValid: Bool { valid }
    public var isEditable: Bool {
        valid && divid != nil
    }
    public var isLinkable: Bool {
        href == nil          // Can't link when selection is in a link
    }
    public var isFollowable: Bool { // Whether selecting will follow the link
        isInLink && selection == nil
    }
    public var isInLink: Bool {
        link != nil && href != nil
    }
    public var isInsertable: Bool {
        selection == nil || selection?.isEmpty ?? true
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
        table
    }
    
    //MARK: Enable/disable menu options and buttons
    
    public var canDent: Bool { true }
    public var canStyle: Bool { style != .Undefined }
    public var canList: Bool { true }
    public var canInsert: Bool { isInsertable }
    public var canLink: Bool { !isInLink }
    public var canFormat: Bool { true }
    public var canCopyCut: Bool { selection != nil || isInImage }
    
    // CustomStringConvertible conformance
    public var description: String {
        valid ?
        """
          selection: \(selection ?? "none")
          divid: \(divid ?? "none")
          style: \(style.tag)
          formats: \(formatString())
          list: \(listString())
          quote: \(quote ? "true" : "none")
          link: \(linkString())
          image: \(imageString())
          table: \(tableString())
        """ : "invalid, divid: \(divid ?? "none"))"
    }
    
    public init() {}
    
    public func reset(from selectionState: SelectionState?) {
        selection = selectionState?.selection
        selrect = selectionState?.selrect               // rect containing the selection if selected
        valid = selectionState?.valid ?? false          // true if document.getSelection().rangeCount > 0
        divid = selectionState?.divid                   // Usually "editor", but could be another enclosing div id
        href = selectionState?.href                     // href for <a> if selected
        link = selectionState?.link                     // text linked to href in <a> if selected
        src = selectionState?.src                       // src for <img> if selected
        alt = selectionState?.alt                       // alt for <img> if selected
        width = selectionState?.width                   // width for <img> if selected and defined
        height = selectionState?.height                 // height for <img> if selected and defined
        scale = selectionState?.scale ?? 100            // scale for <img> if selected
        table = selectionState?.table ?? false          // Is selection in a table
        thead = selectionState?.thead ?? false          // Is selection in table header
        tbody = selectionState?.tbody ?? false          // Is selection in table body
        header = selectionState?.header ?? false        // Does table have a header
        colspan = selectionState?.colspan ?? false      // If so, does header have colspan
        rows = selectionState?.rows ?? 0                // Number of rows in table if selected
        cols = selectionState?.cols ?? 0                // Number of cols in table if selected
        row = selectionState?.row ?? 0                  // Row number selected in body (0 if header)
        col = selectionState?.col ?? 0                  // Col number selected in body or header
        border = selectionState?.border ?? .cell        // TableBorder for selected table
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
        let width = width == nil ? "undefined" : "\(width!)"
        let height = height == nil ? "undefined" : "\(height!)"
        return "\(src), alt: \(alt ?? "none"), width: \(width), height: \(height), scale: \(scale ?? 100)%"
    }
    
    func tableString() -> String {
        guard table else { return "none" }
        let tableSize = "\(rows)x\(cols)"
        let headerType = header ? (colspan ? "spanning header" : "non-spanning header") : "no header"
        if tbody {
            return "in body row \(row), col \(col) of \(tableSize) table with \(headerType), border: \(border)"
        } else if thead {
            if colspan {
                return "in \(headerType) of \(tableSize) table, border: \(border)"
            } else {
                return "in col \(col) of \(headerType) of \(tableSize) table, border: \(border)"
            }
        } else {
            return "Error: in \(tableSize) table, but in neither tbody nor thead"
        }
    }
    
}

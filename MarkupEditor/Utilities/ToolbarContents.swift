//
//  ToolbarContents.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/3/22.
//

import Foundation

/// ToolbarContents controls the contents of the MarkupToolbar and the MarkupMenu.
///
/// The ToolbarContents contains a set of Bools that are used in the various toolbars to determine
/// whether contents are shown. The top-level `correction`, `insert`,  `style`, and `format`
/// entries indicate whether those toolbars are included at all in the MarkupToolbar. The other `*contents`
/// entries point to similar structs for the individual toolbar contents.
///
/// Set `custom` to use your own instance of ToolbarContents to customize the contents of your
/// MarkupToolbar and MarkupMenu. Internally, the toolbars and menus access `shared`, which
/// will be your `custom` ToolbarContents or the default ToolbarContents instance if you did not
/// specify `custom`.
@MainActor
public class ToolbarContents {
    public static var custom: ToolbarContents?
    public static let shared = custom ?? ToolbarContents()

    public var leftToolbar: Bool
    public var correction: Bool
    public var insert: Bool
    public var style: Bool
    public var format: Bool
    public var rightToolbar: Bool

    public var insertContents: InsertContents
    public var styleContents: StyleContents
    public var styleMenu: StyleMenu
    public var formatContents: FormatContents
    public var tableContents: TableContents
    public var helpContents: HelpContents

    public enum PopoverType: String, CaseIterable {
        case link
        case image
        case table
    }

    public init(
        leftToolbar: Bool = false,
        correction: Bool = false,
        insert: Bool = true,
        style: Bool = true,
        format: Bool = true,
        rightToolbar: Bool = false,
        insertContents: InsertContents = InsertContents(),
        styleContents: StyleContents = StyleContents(),
        styleMenu: StyleMenu = StyleMenu(),
        formatContents: FormatContents = FormatContents(),
        tableContents: TableContents = TableContents(),
        helpContents: HelpContents = HelpContents()
    ) {
        self.leftToolbar = leftToolbar ? MarkupEditor.leftToolbar != nil : false
        self.correction = correction
        self.insert = insert
        self.style = style
        self.format = format
        self.rightToolbar = rightToolbar ? MarkupEditor.rightToolbar != nil : false
        self.insertContents = insertContents
        self.styleContents = styleContents
        self.styleMenu = styleMenu
        self.formatContents = formatContents
        self.tableContents = tableContents
        self.helpContents = helpContents
        
    }

    public init(toolbarConfig: ToolbarConfig, leftToolbar: Bool = false, rightToolbar: Bool = false) {
        self.leftToolbar = leftToolbar
        correction = toolbarConfig.visibility["correctionBar"] ?? false
        insert = toolbarConfig.visibility["insertBar"] ?? true
        style = toolbarConfig.visibility["styleBar"] ?? true
        format = toolbarConfig.visibility["formatBar"] ?? true
        self.rightToolbar = rightToolbar
        insertContents = InsertContents(
            link: toolbarConfig.insertBar["link"] ?? true,
            image: toolbarConfig.insertBar["image"] ?? true,
            table: toolbarConfig.insertBar["tableMenu"] ?? true,
        )
        styleContents = StyleContents(
            paragraph: toolbarConfig.visibility["styleMenu"] ?? true,
            list: toolbarConfig.styleBar["list"] ?? true,
            dent: toolbarConfig.styleBar["dent"] ?? true
        )
        styleMenu = StyleMenu(toolbarConfig: toolbarConfig)
        formatContents = FormatContents(
            code: toolbarConfig.formatBar["code"] ?? true,
            strike: toolbarConfig.formatBar["strikethrough"] ?? true,
            subSuper: (toolbarConfig.formatBar["subscript"] ?? false) || (toolbarConfig.formatBar["superscript"] ?? false)
        )
        tableContents = TableContents(border: toolbarConfig.tableMenu["border"] ?? true)
        helpContents = HelpContents(toolbarConfig.help)
    }

    public static func from(_ toolbarContents: ToolbarContents) -> ToolbarContents{
        ToolbarContents(
            leftToolbar: toolbarContents.leftToolbar,
            correction: toolbarContents.correction,
            insert: toolbarContents.insert,
            style: toolbarContents.style,
            format: toolbarContents.format,
            rightToolbar: toolbarContents.rightToolbar,
            insertContents: toolbarContents.insertContents,
            styleContents: toolbarContents.styleContents,
            styleMenu: toolbarContents.styleMenu,
            formatContents: toolbarContents.formatContents,
            tableContents: toolbarContents.tableContents
        )
    }

    /// A nil value for `styleMenu.items[tag.lowerCased()]` means the tag should not be in the menu
    public func name(forTag tag: String) -> String? {
        styleMenu.items[tag.lowercased()]!
    }

}

/// Identify which of the InsertToolbar items will show up
public struct InsertContents {
    public var link: Bool
    public var image: Bool
    public var table: Bool

    public init(link: Bool = true, image: Bool = true, table: Bool = true) {
        self.link = link
        self.image = image
        self.table = table
    }
}

/// Identify whether the list and indent/outdent items will show up
public struct StyleContents {

    /// Determine which kind of list format we want
    public enum ListType {
        case bullet, number
    }

    public var paragraph: Bool
    public var listType: [ListType]
    public var dent: Bool

    public init(paragraph: Bool = true, listType: [ListType], dent: Bool = true) {
        self.paragraph = paragraph
        self.listType = listType
        self.dent = dent
    }

    public init(paragraph: Bool = true, list: Bool = true, dent: Bool = true) {
        self.paragraph = paragraph
        self.listType = list ? [.bullet, .number] : []
        self.dent = dent
    }
}

public struct StyleMenu {
    public var items: [String: String?]

    public init(toolbarConfig: ToolbarConfig = ToolbarConfig()) {
        items = toolbarConfig.styleMenu
    }
}

/// Identify whether the code, strikethrough, and sub/superscript items will show up
public struct FormatContents {
    public var code: Bool
    public var strike: Bool
    public var subSuper: Bool

    public init(code: Bool = true, strike: Bool = true, subSuper: Bool = false) {
        self.code = code
        self.strike = strike
        self.subSuper = subSuper
    }
}

/// Identify whether to allow table borders to be specified
public struct TableContents {
    public var border: Bool

    public init(border: Bool = true) {
        self.border = border
    }
}

/// The help/hover labels for ToolbarImageButtons
public struct HelpContents {
    public var style: String
    public var bold: String
    public var italic: String
    public var underline: String
    public var code: String
    public var strikethrough: String
    public var `subscript`: String
    public var superscript: String
    public var bullet: String
    public var number: String
    public var indent: String
    public var outdent: String
    public var link: String
    public var image: String
    public var table: String
    public var search: String
    public var searchForward: String
    public var searchBackward: String
    public var matchCase: String
    public var undo: String
    public var redo: String
    
    public init(_ help: [String : String] = [:]) {
        style = help["style"] ?? ""
        bold = help["bold"] ?? ""
        italic = help["italic"] ?? ""
        underline = help["underline"] ?? ""
        code = help["code"] ?? ""
        strikethrough = help["strikethrough"] ?? ""
        `subscript` = help["subscript"] ?? ""
        superscript = help["superscript"] ?? ""
        bullet = help["bullet"] ?? ""
        number = help["number"] ?? ""
        indent = help["indent"] ?? ""
        outdent = help["outdent"] ?? ""
        link = help["link"] ?? ""
        image = help["image"] ?? ""
        table = help["table"] ?? ""
        search = help["search"] ?? ""
        searchForward = help["searchForward"] ?? ""
        searchBackward = help["searchBackward"] ?? ""
        matchCase = help["matchCase"] ?? ""
        undo = help["undo"] ?? ""
        redo = help["redo"] ?? ""
    }
}

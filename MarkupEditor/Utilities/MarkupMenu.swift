//
//  MarkupMenu.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/3/22.
//

#if !os(macOS)

import UIKit

/// The MarkupMenu creates the UIMenu content for an environment that supports a menu bar.
///
/// The contents of the MarkupMenu corresponds to the ToolbarContents. The actions and
/// canPerformAction logic all reside in MarkupWKWebView. As menu items are invoked and hot-keys are
/// pressed, the selectedWebView (a MarkupWKWebView) is encountered in the responder chain and executes
/// the action.
///
/// The MarkupMenu will have a title of "Format" by default and will be placed following the Edit menu.
/// The initMenu method removes the default Format menu.
///
/// Note that some hotkeys will work without the menu being enabled, but most will not. For example, command+B
/// will bold/unbold even if there is no MarkupMenu, but command+] will not indent. This is a byproduct of the
/// "native" support of WKWebView.
///
@MainActor
public class MarkupMenu {
    let contents = MarkupEditor.toolbarContents
    let keymap = KeymapConfig.standard()
    
    public init() {}
    
    /// Create a UIKeyCommand using the keymap binding for the given action, or a UICommand if no binding exists.
    private func command(title: String, image: UIImage?, action: Selector, keymapAction: String) -> UICommand {
        if let binding = keymap.binding(for: keymapAction) {
            return UIKeyCommand(title: title, image: image, action: action, input: binding.keyEquivalent, modifierFlags: binding.modifierMask)
        }
        return UICommand(title: title, image: image, action: action)
    }
    
    public func initMenu(with builder: UIMenuBuilder) {
        // Remove the existing Format menu and replace it
        builder.remove(menu: .format)
        var children = [UIMenu]()
        if contents.insert { children.append(insertMenu()) }
        if contents.style {
            if contents.styleContents.paragraph { children.append(styleMenu()) }
            if !contents.styleContents.listType.isEmpty { children.append(listMenu()) }
            if contents.styleContents.dent { children.append(dentMenu()) }
        }
        if contents.format { children.append(formatMenu()) }
        if children.isEmpty { return }  // Show no markupMenu
        let markupMenu = UIMenu(title: "Format", children: children)
        builder.insertSibling(markupMenu, afterMenu: .edit)
    }
    
    private func insertMenu() -> UIMenu {
        var children = [UIMenuElement]()
        if contents.insertContents.link {
            children.append(command(title: "Link", image: UIImage(systemName: "link"), action: #selector(MarkupWKWebView.showPluggableLinkPopover), keymapAction: "link"))
        }
        if contents.insertContents.image {
            children.append(command(title: "Image", image: UIImage(systemName: "photo"), action: #selector(MarkupWKWebView.showPluggableImagePopover), keymapAction: "image"))
        }
        if contents.insertContents.table {
            children.append(tableMenu())
        }
        return UIMenu(title: "Insert", image: UIImage(systemName: "text.insert"), children: children)
    }
    
    private func tableMenu() -> UIMenu {
        // Create submenu — rows x cols grid
        let createChildren: [UIMenu] = (1...4).map { rows in
            let colCommands: [UICommand] = (1...4).map { cols in
                return UICommand(title: "\(cols) Col\(cols > 1 ? "s" : "")", action: #selector(MarkupWKWebView.insertTableFromMenu(_:)), propertyList: [rows, cols])
            }
            return UIMenu(title: "\(rows) Row\(rows > 1 ? "s" : "")", children: colCommands)
        }
        let createMenu = UIMenu(title: "Create", children: createChildren)
        
        // Add submenu
        var addChildren: [UICommand] = [
            UICommand(title: "Row Above", action: #selector(MarkupWKWebView.addRowBefore)),
            UICommand(title: "Row Below", action: #selector(MarkupWKWebView.addRowAfter)),
            UICommand(title: "Column Before", action: #selector(MarkupWKWebView.addColBefore)),
            UICommand(title: "Column After", action: #selector(MarkupWKWebView.addColAfter)),
        ]
        if contents.tableContents.border {
            addChildren.append(UICommand(title: "Header", action: #selector(MarkupWKWebView.addTableHeader)))
        }
        let addMenu = UIMenu(title: "Add", children: addChildren)
        
        // Delete submenu
        let deleteMenu = UIMenu(title: "Delete", children: [
            UICommand(title: "Row", action: #selector(MarkupWKWebView.deleteTableRow)),
            UICommand(title: "Column", action: #selector(MarkupWKWebView.deleteTableCol)),
            UICommand(title: "Table", action: #selector(MarkupWKWebView.deleteEntireTable)),
        ])
        
        var tableChildren: [UIMenu] = [createMenu, addMenu, deleteMenu]
        
        // Border submenu
        if contents.tableContents.border {
            let borderMenu = UIMenu(title: "Border", children: [
                UICommand(title: "All", action: #selector(MarkupWKWebView.borderTableAll)),
                UICommand(title: "Outer", action: #selector(MarkupWKWebView.borderTableOuter)),
                UICommand(title: "Header", action: #selector(MarkupWKWebView.borderTableHeader)),
                UICommand(title: "None", action: #selector(MarkupWKWebView.borderTableNone)),
            ])
            tableChildren.append(borderMenu)
        }
        
        return UIMenu(title: "Table", image: UIImage(systemName: "squareshape.split.3x3"), children: tableChildren)
    }
    
    private func styleMenu() -> UIMenu {
        var children: [UICommand] = []
        if let pTitle = contents.name(forTag: "p") { children.append(command(title: pTitle, image: nil, action: #selector(MarkupWKWebView.pStyle), keymapAction: "p")) }
        if let h1Title = contents.name(forTag: "h1") { children.append(command(title: h1Title, image: nil, action: #selector(MarkupWKWebView.h1Style), keymapAction: "h1")) }
        if let h2Title = contents.name(forTag: "h2") { children.append(command(title: h2Title, image: nil, action: #selector(MarkupWKWebView.h2Style), keymapAction: "h2")) }
        if let h3Title = contents.name(forTag: "h3") { children.append(command(title: h3Title, image: nil, action: #selector(MarkupWKWebView.h3Style), keymapAction: "h3")) }
        if let h4Title = contents.name(forTag: "h4") { children.append(command(title: h4Title, image: nil, action: #selector(MarkupWKWebView.h4Style), keymapAction: "h4")) }
        if let h5Title = contents.name(forTag: "h5") { children.append(command(title: h5Title, image: nil, action: #selector(MarkupWKWebView.h5Style), keymapAction: "h5")) }
        if let h6Title = contents.name(forTag: "h6") { children.append(command(title: h6Title, image: nil, action: #selector(MarkupWKWebView.h6Style), keymapAction: "h6")) }
        if let preTitle = contents.name(forTag: "pre") { children.append(command(title: preTitle, image: nil, action: #selector(MarkupWKWebView.preStyle), keymapAction: "pre")) }
        return UIMenu(title: "Style", image: UIImage(systemName: "paragraphsign"), children: children)
    }
    
    private func dentMenu() -> UIMenu {
        let children: [UICommand] = [
            command(title: "Indent", image: UIImage(systemName: "increase.indent"), action: #selector(MarkupWKWebView.indentFromMenu), keymapAction: "indent"),
            command(title: "Outdent", image: UIImage(systemName: "decrease.indent"), action: #selector(MarkupWKWebView.outdentFromMenu), keymapAction: "outdent")
        ]
        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
    private func listMenu() -> UIMenu {
        let children: [UICommand] = contents.styleContents.listType.map { type in
            switch type {
            case .bullet:
                return command(title: "Bullets", image: UIImage(systemName: "list.bullet"), action: #selector(MarkupWKWebView.bullets), keymapAction: "bullet")
            case .number:
                return command(title: "Numbers", image: UIImage(systemName: "list.number"), action: #selector(MarkupWKWebView.numbers), keymapAction: "number")
            }
        }

        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
    private func formatMenu() -> UIMenu {
        var children: [UICommand] = []
        children.append(command(title: "Bold", image: UIImage(systemName: "bold"), action: #selector(MarkupWKWebView.bold), keymapAction: "bold"))
        children.append(command(title: "Italic", image: UIImage(systemName: "italic"), action: #selector(MarkupWKWebView.italic), keymapAction: "italic"))
        children.append(command(title: "Underline", image: UIImage(systemName: "underline"), action: #selector(MarkupWKWebView.underline), keymapAction: "underline"))
        if contents.formatContents.code {
            children.append(command(title: "Code", image: UIImage(systemName: "curlybraces"), action: #selector(MarkupWKWebView.code), keymapAction: "code"))
        }
        if contents.formatContents.strike {
            children.append(command(title: "Strikethrough", image: UIImage(systemName: "strikethrough"), action: #selector(MarkupWKWebView.strike), keymapAction: "strikethrough"))
        }
        if contents.formatContents.subSuper {
            children.append(command(title: "Subscript", image: UIImage(systemName: "textformat.subscript"), action: #selector(MarkupWKWebView.subscriptText), keymapAction: "subscript"))
            children.append(command(title: "Superscript", image: UIImage(systemName: "textformat.superscript"), action: #selector(MarkupWKWebView.superscript), keymapAction: "superscript"))
        }
        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
}

#endif

//
//  MarkupMenus.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/3/22.
//

import UIKit

public class MarkupMenu {
    public var markupEnv: MarkupEnv?
    private var selectedWebView: MarkupWKWebView? { markupEnv?.observedWebView.selectedWebView }
    private var selectionState: SelectionState? { markupEnv?.selectionState }
    private let actions: [Selector] = [
        #selector(insertLink),
        #selector(insertImage),
        #selector(insertTable),
        #selector(pStyle),
        #selector(h1Style),
        #selector(h2Style),
        #selector(h3Style),
        #selector(h4Style),
        #selector(h5Style),
        #selector(h6Style),
        #selector(indent),
        #selector(outdent),
        #selector(bullets),
        #selector(numbers),
        #selector(bold),
        #selector(italic),
        #selector(underline),
        #selector(code),
        #selector(strike),
        #selector(subscriptText),
        #selector(superscript)
    ]
    
    public init() {}
    
    public func initMainMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .services)
        builder.remove(menu: .format)
        builder.remove(menu: .toolbar)
    }
    
    public func initMarkupMenu(with builder: UIMenuBuilder) {
        let formatMenu = UIMenu(title: "Format", children: [insertMenu(), styleMenu(), dentMenu(), listMenu(), formatMenu()])
        builder.insertSibling(formatMenu, afterMenu: .edit)
    }
    
    private func insertMenu() -> UIMenu {
        let linkCommand = UIKeyCommand(
            title: "Link",
            image: nil,
            action: #selector(insertLink),
            input: "K",
            modifierFlags: .command
        )
        let imageCommand = UICommand(
            title: "Image",
            action: #selector(insertImage)
        )
        let tableCommand = UICommand(
            title: "Table",
            action: #selector(insertTable)
        )
        return UIMenu(title: "Insert", children: [linkCommand, imageCommand, tableCommand])
    }
    
    private func styleMenu() -> UIMenu {
        let pCommand = UICommand(
            title: "Normal",
            action: #selector(pStyle)
        )
        let h1Command = UICommand(
            title: "Header 1",
            action: #selector(h1Style)
        )
        let h2Command = UICommand(
            title: "Header 2",
            action: #selector(h2Style)
        )
        let h3Command = UICommand(
            title: "Header 3",
            action: #selector(h3Style)
        )
        let h4Command = UICommand(
            title: "Header 4",
            action: #selector(h4Style)
        )
        let h5Command = UICommand(
            title: "Header 5",
            action: #selector(h5Style)
        )
        let h6Command = UICommand(
            title: "Header 6",
            action: #selector(h6Style)
        )
        return UIMenu(title: "Style", children: [pCommand, h1Command, h2Command, h3Command, h4Command, h5Command, h6Command])
    }
    
    private func dentMenu() -> UIMenu {
        let indentCommand = UIKeyCommand(
            title: "Indent",
            image: nil,
            action: #selector(indent),
            input: "]",
            modifierFlags: .command
        )
        let outdentCommand = UIKeyCommand(
            title: "Outdent",
            image: nil,
            action: #selector(outdent),
            input: "[",
            modifierFlags: .command
        )
        return UIMenu(title: "Dent", options: .displayInline, children: [indentCommand, outdentCommand])
    }
    
    private func listMenu() -> UIMenu {
        let bulletCommand = UIKeyCommand(
            title: "Bullets",
            image: nil,
            action: #selector(bullets),
            input: ".",
            modifierFlags: .command
        )
        let numbersCommand = UIKeyCommand(
            title: "Numbers",
            image: nil,
            action: #selector(numbers),
            input: "/",
            modifierFlags: .command
        )
        return UIMenu(title: "List", options: .displayInline, children: [bulletCommand, numbersCommand])
    }
    
    private func formatMenu() -> UIMenu {
        let boldCommand = UIKeyCommand(
            title: "Bold",
            image: nil,
            action: #selector(bold),
            input: "B",
            modifierFlags: .command
        )
        let italicCommand = UIKeyCommand(
            title: "Italic",
            image: nil,
            action: #selector(italic),
            input: "I",
            modifierFlags: .command
        )
        // TODO: Why is command+U a conflicting mapping but command+B is not?
        //let underlineCommand = UIKeyCommand(
        //    title: "Underline",
        //    image: nil,
        //    action: #selector(italic),
        //    input: "U",
        //    modifierFlags: .command
        //)
        let underlineCommand = UICommand(
            title: "Underline",
            action: #selector(underline)
        )
        let codeCommand = UIKeyCommand(
            title: "Code",
            image: nil,
            action: #selector(code),
            input: "{",
            modifierFlags: .command
        )
        let strikeCommand = UIKeyCommand(
            title: "Strikethrough",
            image: nil,
            action: #selector(strike),
            input: "-",
            modifierFlags: [.control, .command]
        )
        let subscriptCommand = UIKeyCommand(
            title: "Subscript",
            image: nil,
            action: #selector(subscriptText),
            input: "=",
            modifierFlags: [.alternate, .command]
        )
        let superscriptCommand = UIKeyCommand(
            title: "Superscript",
            image: nil,
            action: #selector(superscript),
            input: "=",
            modifierFlags: [.shift, .alternate, .command]
        )
        return UIMenu(title: "Format", options: .displayInline, children: [boldCommand, italicCommand, underlineCommand, codeCommand, strikeCommand, subscriptCommand, superscriptCommand])
    }
    
    public func handles(_ action: Selector, withSender sender: Any?) -> Bool {
        return actions.contains(action)
    }
    
    /// Return false to disable various menu items depending on selectionState
    @objc public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        //print(action.description)
        switch action {
        case #selector(indent), #selector(outdent):
            return selectionState?.canDent ?? false
        case #selector(bullets), #selector(numbers):
            return selectionState?.canList ?? false
        case #selector(pStyle), #selector(h1Style), #selector(h2Style), #selector(h3Style), #selector(h4Style), #selector(h5Style), #selector(h6Style):
            return selectionState?.canStyle ?? false
        case #selector(insertLink):
            return selectionState?.canLink ?? false
        case #selector(insertImage), #selector(insertTable):
            return selectionState?.canInsert ?? false
        case #selector(bold), #selector(italic), #selector(underline), #selector(code), #selector(strike), #selector(subscriptText), #selector(superscript):
            return selectionState?.canFormat ?? false
        default:
            return false
        }
    }
    
    @objc public func insertLink() {
        markupEnv?.showSubToolbar.type = .link
    }
    
    @objc public func insertImage() {
        markupEnv?.showSubToolbar.type = .image
    }
    
    @objc public func insertTable() {
        markupEnv?.showSubToolbar.type = .table
    }
    
    @objc public func pStyle() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .P)
    }
    
    @objc public func h1Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H1)
    }
    
    @objc public func h2Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H2)
    }
    
    @objc public func h3Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H3)
    }
    
    @objc public func h4Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H4)
    }
    
    @objc public func h5Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H5)
    }
    
    @objc public func h6Style() {
        selectedWebView?.replaceStyle(selectionState?.style, with: .H6)
    }
    
    @objc public func indent() {
        selectedWebView?.indent()
    }
    
    @objc public func outdent() {
        selectedWebView?.outdent()
    }
    
    @objc public func bullets() {
        selectedWebView?.toggleListItem(type: .UL)
    }
    
    @objc public func numbers() {
        selectedWebView?.toggleListItem(type: .OL)
    }
    
    @objc public func bold() {
        selectedWebView?.bold()
    }
    
    @objc public func italic() {
        selectedWebView?.italic()
    }
    
    @objc public func underline() {
        selectedWebView?.underline()
    }
    
    @objc public func code() {
        selectedWebView?.code()
    }
    
    @objc public func strike() {
        selectedWebView?.strike()
    }
    
    @objc public func subscriptText() {
        selectedWebView?.subscriptText()
    }
    
    @objc public func superscript() {
        selectedWebView?.superscript()
    }
    
}


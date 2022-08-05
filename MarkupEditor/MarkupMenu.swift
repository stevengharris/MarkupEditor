//
//  MarkupMenu.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/3/22.
//

import UIKit

/// The MarkupMenu creates the UIMenu content for an environment that supports a menu bar. It dispatches
/// menu actions to the selectedWebView and determines whether we canPerformAction based on the
/// selectionState.
///
/// The MarkupMenu will have a title of "Format" by default and will be placed following the Edit menu.
///
/// Note that some hotkeys will work without the menu being enabled, but most will not. For example, command+B
/// will bold/unbold even if there is no MarkupMenu, but command+] will not indent. This is a byproduct of the
/// "native" support of WKWebView.
///
/// The MarkupMenu needs access to the MarkupEnv to find the selectedWebView and selectionState. The
/// contents of the menu is adjusted at creation time to correspond to ToolbarContents. The various toolbars
/// use the same mechanism to determine what their contents are and whether buttons should be disabled.
///
public class MarkupMenu {
    public let title: String
    public let markupEnv: MarkupEnv
    private var selectedWebView: MarkupWKWebView? { markupEnv.observedWebView.selectedWebView }
    private var selectionState: SelectionState? { markupEnv.selectionState }
    let contents = ToolbarContents.shared
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
    
    public init(title: String? = nil, markupEnv: MarkupEnv) {
        self.title = title ?? "Format"
        self.markupEnv = markupEnv
    }
    
    public func initMarkupMenu(with builder: UIMenuBuilder) {
        var children = [UIMenu]()
        if contents.insert { children.append(insertMenu()) }
        if contents.style {
            children.append(styleMenu())
            if contents.styleContents.list { children.append(listMenu()) }
            if contents.styleContents.dent { children.append(dentMenu()) }
        }
        if contents.format { children.append(formatMenu()) }
        if children.isEmpty { return }  // Show no markupMenu
        let markupMenu = UIMenu(title: title, children: children)
        builder.insertSibling(markupMenu, afterMenu: .edit)
    }
    
    private func insertMenu() -> UIMenu {
        var children = [UICommand]()
        if contents.insertContents.link {
            children.append(UIKeyCommand(title: "Link", action: #selector(insertLink), input: "K", modifierFlags: .command))
        }
        if contents.insertContents.image {
            children.append(UICommand(title: "Image", action: #selector(insertImage)))
        }
        if contents.insertContents.table {
            children.append(UICommand(title: "Table", action: #selector(insertTable)))
        }
        return UIMenu(title: "Insert", children: children)
    }
    
    private func styleMenu() -> UIMenu {
        let children: [UICommand] = [
            UICommand(title: "Normal", action: #selector(pStyle)),
            UICommand(title: "Header 1", action: #selector(h1Style)),
            UICommand(title: "Header 2", action: #selector(h2Style)),
            UICommand(title: "Header 3", action: #selector(h3Style)),
            UICommand(title: "Header 4", action: #selector(h4Style)),
            UICommand(title: "Header 5", action: #selector(h5Style)),
            UICommand(title: "Header 6", action: #selector(h6Style))
        ]
        return UIMenu(title: "Style", children: children)
    }
    
    private func dentMenu() -> UIMenu {
        let children: [UICommand] = [
            UIKeyCommand(title: "Indent", action: #selector(indent), input: "]", modifierFlags: .command),
            UIKeyCommand(title: "Outdent", action: #selector(outdent), input: "[", modifierFlags: .command)
        ]
        return UIMenu(title: "Dent", options: .displayInline, children: children)
    }
    
    private func listMenu() -> UIMenu {
        let children: [UICommand] = [
            UIKeyCommand(title: "Bullets", action: #selector(bullets), input: ".", modifierFlags: .command),
            UIKeyCommand(title: "Numbers", action: #selector(numbers), input: "/", modifierFlags: .command)
        ]
        return UIMenu(title: "List", options: .displayInline, children: children)
    }
    
    private func formatMenu() -> UIMenu {
        var children: [UICommand] = []
        children.append(UIKeyCommand(title: "Bold", action: #selector(bold), input: "B", modifierFlags: .command))
        children.append(UIKeyCommand(title: "Italic", action: #selector(italic), input: "I", modifierFlags: .command))
        // TODO: Why is command+U a conflicting mapping but command+B is not?
        // children.append(UIKeyCommand(title: "Underline", action: #selector(underline), input: "U", modifierFlags: .command))
        children.append(UICommand(title: "Underline", action: #selector(underline)))
        if contents.formatContents.code {
            children.append(UIKeyCommand(title: "Code", action: #selector(code), input: "{", modifierFlags: .command))
        }
        if contents.formatContents.strike {
            children.append(UIKeyCommand(title: "Strikethrough", action: #selector(strike), input: "-", modifierFlags: [.control, .command]))
        }
        if contents.formatContents.subSuper {
            children.append(UIKeyCommand(title: "Subscript", action: #selector(subscriptText), input: "=", modifierFlags: [.alternate, .command]))
            children.append(UIKeyCommand(title: "Superscript", action: #selector(superscript), input: "=", modifierFlags: [.shift, .alternate, .command]))
        }
        return UIMenu(title: "Format", options: .displayInline, children: children)
    }
    
    public func handles(_ action: Selector, withSender sender: Any?) -> Bool {
        return actions.contains(action)
    }
    
    /// Return false to disable various menu items depending on selectionState
    @objc public func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
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
        markupEnv.showSubToolbar.type = .link
    }
    
    @objc public func insertImage() {
        markupEnv.showSubToolbar.type = .image
    }
    
    @objc public func insertTable() {
        markupEnv.showSubToolbar.type = .table
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


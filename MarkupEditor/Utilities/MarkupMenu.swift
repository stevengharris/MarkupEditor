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
    
    public init() {}
    
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
        var children = [UICommand]()
        if contents.insertContents.link {
            children.append(UIKeyCommand(title: "Link", image: UIImage(systemName: "link"), action: #selector(MarkupWKWebView.showPluggableLinkPopover), input: "K", modifierFlags: .command))
        }
        if contents.insertContents.image {
            children.append(UICommand(title: "Image", image: UIImage(systemName: "photo"), action: #selector(MarkupWKWebView.showPluggableImagePopover)))
        }
        if contents.insertContents.table {
            children.append(UICommand(title: "Table", image: UIImage(systemName: "squareshape.split.3x3"), action: #selector(MarkupWKWebView.showPluggableTablePopover)))
        }
        return UIMenu(title: "Insert", children: children)
    }
    
    private func styleMenu() -> UIMenu {
        let children: [UICommand] = [
            UICommand(title: "Normal", action: #selector(MarkupWKWebView.pStyle)),
            UICommand(title: "Header 1", action: #selector(MarkupWKWebView.h1Style)),
            UICommand(title: "Header 2", action: #selector(MarkupWKWebView.h2Style)),
            UICommand(title: "Header 3", action: #selector(MarkupWKWebView.h3Style)),
            UICommand(title: "Header 4", action: #selector(MarkupWKWebView.h4Style)),
            UICommand(title: "Header 5", action: #selector(MarkupWKWebView.h5Style)),
            UICommand(title: "Header 6", action: #selector(MarkupWKWebView.h6Style))
        ]
        return UIMenu(title: "Style", children: children)
    }
    
    private func dentMenu() -> UIMenu {
        let children: [UICommand] = [
            UIKeyCommand(title: "Indent", image: UIImage(systemName: "increase.quotelevel"), action: #selector(MarkupWKWebView.indentFromMenu), input: "]", modifierFlags: .command),
            UIKeyCommand(title: "Outdent", image: UIImage(systemName: "decrease.quotelevel"), action: #selector(MarkupWKWebView.outdentFromMenu), input: "[", modifierFlags: .command)
        ]
        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
    private func listMenu() -> UIMenu {
        let children: [UICommand] = contents.styleContents.listType.map { type in
            switch type {
            case .bullet:
                return UIKeyCommand(title: "Bullets", image: UIImage(systemName: "list.bullet"), action: #selector(MarkupWKWebView.bullets), input: ".", modifierFlags: .command)
            case .number:
                return UIKeyCommand(title: "Numbers", image: UIImage(systemName: "list.number"), action: #selector(MarkupWKWebView.numbers), input: "/", modifierFlags: .command)
            }
        }

        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
    private func formatMenu() -> UIMenu {
        var children: [UICommand] = []
        children.append(UIKeyCommand(title: "Bold", image: UIImage(systemName: "bold"), action: #selector(MarkupWKWebView.bold), input: "B", modifierFlags: .command))
        children.append(UIKeyCommand(title: "Italic", image: UIImage(systemName: "italic"), action: #selector(MarkupWKWebView.italic), input: "I", modifierFlags: .command))
        children.append(UIKeyCommand(title: "Underline", image: UIImage(systemName: "underline"), action: #selector(MarkupWKWebView.underline), input: "U", modifierFlags: .command))
        if contents.formatContents.code {
            children.append(UIKeyCommand(title: "Code", image: UIImage(systemName: "curlybraces"), action: #selector(MarkupWKWebView.code), input: "`", modifierFlags: .command))
        }
        if contents.formatContents.strike {
            children.append(UIKeyCommand(title: "Strikethrough", image: UIImage(systemName: "strikethrough"), action: #selector(MarkupWKWebView.strike), input: "-", modifierFlags: [.control, .command]))
        }
        if contents.formatContents.subSuper {
            children.append(UIKeyCommand(title: "Subscript", image: UIImage(systemName: "textformat.subscript"), action: #selector(MarkupWKWebView.subscriptText), input: "=", modifierFlags: [.alternate, .command]))
            children.append(UIKeyCommand(title: "Superscript", image: UIImage(systemName: "textformat.superscript"), action: #selector(MarkupWKWebView.superscript), input: "=", modifierFlags: [.shift, .alternate, .command]))
        }
        return UIMenu(title: "", options: .displayInline, children: children)
    }
    
}

#endif

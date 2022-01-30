//
//  MarkupEditorMenu.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/24/22.
//

import UIKit

class MarkupEditorMenu {
    // Note individual menu items are enabled/disabled based on the canPerformAction method.
    
    init(with builder: UIMenuBuilder) {
        initMainMenu(with: builder)
        initEditMenu(with: builder)
    }
    
    private func initMainMenu(with builder: UIMenuBuilder) {
        builder.remove(menu: .services)
        builder.remove(menu: .format)
        builder.remove(menu: .toolbar)
    }
    
    private func initEditMenu(with builder: UIMenuBuilder) {
        let indentCommand = UIKeyCommand(
            title: "Indent",
            image: nil,
            action: #selector(SceneDelegate.indent),
            input: "]",
            modifierFlags: .command)
        let outdentCommand = UIKeyCommand(
            title: "Indent",
            image: nil,
            action: #selector(SceneDelegate.outdent),
            input: "[",
            modifierFlags: .command)
        let styleMenu = UIMenu(title: "Style", children: [indentCommand, outdentCommand])
        builder.insertSibling(styleMenu, afterMenu: .undoRedo)
    }
    
}


//
//  AppDelegate.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/26/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import MarkupEditor

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    let markupEnv = MarkupEnv(style: .compact, allowLocalImages: true)
    var markupMenu: MarkupMenu!
    
    // Specify custom ToolbarContents *before* initializing the MarkupMenu.
    // An easy way to do this is overriding init().
    // Here is an example that eliminates the CorrectionToolbar and InsertToolbar,
    // and some of the FormatToolbar contents. Note that the MarkupMenu adjusts
    // its contents properly to correspond to ToolbarContents.custom
    //
    //      override init() {
    //          let myToolbarContents = ToolbarContents(
    //              correction: false,  // No undo/redo buttons, but will still show up in Edit menu
    //              insert: false,      // Eliminate the entire InsertToolbar
    //              // Remove code, strikethrough, subscript, and superscript as formatting options
    //              formatContents: FormatContents(code: false, strike: false, subSuper: false)
    //          )
    //          ToolbarContents.custom = myToolbarContents
    //      }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    //MARK: Menu and hotkey support
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        // Clean up some unused menus
        builder.remove(menu: .services)
        builder.remove(menu: .format)
        builder.remove(menu: .toolbar)
        // And the create and initialize the MarkupMenu.
        // Note the MarkupMenu uses the markupEnv to access
        // info about SelectionState, etc.
        markupMenu = MarkupMenu(markupEnv: markupEnv)
        markupMenu.initMarkupMenu(with: builder)
    }
    
    /// Let the sceneDelegate, which has access to MarkupEnv, decide whether an action can be performed.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        if markupMenu.handles(action, withSender: sender) {
            return markupMenu.canPerformAction(action, withSender: sender)
        } else {
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    private func sceneDelegate() -> SceneDelegate? {
        UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
    }
    
    //MARK: Menu actions dispatched to markupMenu
    
    @objc public func insertLink() {
        markupMenu.insertLink()
    }
    
    @objc public func insertImage() {
        markupMenu.insertImage()
    }
    
    @objc public func insertTable() {
        markupMenu.insertTable()
    }
    
    @objc public func pStyle() {
        markupMenu.pStyle()
    }
    
    @objc public func h1Style() {
        markupMenu.h1Style()
    }
    
    @objc public func h2Style() {
        markupMenu.h2Style()
    }
    
    @objc public func h3Style() {
        markupMenu.h3Style()
    }
    
    @objc public func h4Style() {
        markupMenu.h4Style()
    }
    
    @objc public func h5Style() {
        markupMenu.h5Style()
    }
    
    @objc public func h6Style() {
        markupMenu.h6Style()
    }
    
    @objc func indent() {
        markupMenu.indent()
    }
    
    @objc func outdent() {
        markupMenu.outdent()
    }
    
    @objc func bullets() {
        markupMenu.bullets()
    }
    
    @objc func numbers() {
        markupMenu.numbers()
    }
    
    @objc func bold() {
        markupMenu.bold()
    }
    
    @objc func italic() {
        markupMenu.italic()
    }
    
    @objc func underline() {
        markupMenu.underline()
    }
    
    @objc func code() {
        markupMenu.code()
    }
    
    @objc func strike() {
        markupMenu.strike()
    }
    
    @objc func subscriptText() {
        markupMenu.subscriptText()
    }
    
    @objc func superscript() {
        markupMenu.superscript()
    }

}


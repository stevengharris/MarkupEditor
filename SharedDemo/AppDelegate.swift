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
    let markupMenu = MarkupMenu.shared
    
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
        builder.remove(menu: .toolbar)
        // Initialize the MarkupMenu.
        // Note the MarkupMenu uses the markupEnv to access
        // info about SelectionState, etc.
        markupMenu.markupEnv = markupEnv
        markupMenu.initMarkupMenu(with: builder)
    }
    
}


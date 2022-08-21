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
    
    override init() {
        MarkupEditor.style = .compact
        MarkupEditor.allowLocalImages = true
        //
        // Here is an example that adds in the CorrectionToolbar and some
        // of the FormatToolbar contents. Note that the MarkupEditor adjusts
        // the MarkupMenu properly to correspond to ToolbarContents.custom
        //          let myToolbarContents = ToolbarContents(
        //              correction: true,  // Put the undo/redo buttons in
        //              // Remove code, strikethrough, subscript, and superscript as formatting options
        //              formatContents: FormatContents(code: false, strike: false, subSuper: false)
        //          )
        //          ToolbarContents.custom = myToolbarContents
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    //MARK: Menu and hotkey support
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        // Clean up some unused menus
        builder.remove(menu: .services)
        builder.remove(menu: .toolbar)
        // Initialize the MarkupMenu as the Format menu
        MarkupEditor.initMenu(with: builder)
    }
    
}


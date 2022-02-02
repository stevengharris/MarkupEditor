//
//  AppDelegate.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/26/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    var markupEditorMenu: MarkupEditorMenu!
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    //MARK: Menu and hotkey support
    
    override func buildMenu(with builder: UIMenuBuilder) {
        super.buildMenu(with: builder)
        markupEditorMenu = MarkupEditorMenu(with: builder)
    }
    
    /// Let the sceneDelegate, which has access to MarkupEnv, decide whether an action can be performed.
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        sceneDelegate()?.canPerformAction(action, withSender: sender) ?? false
    }
    
    private func sceneDelegate() -> SceneDelegate? {
        UIApplication.shared.connectedScenes.first?.delegate as? SceneDelegate
    }
    
    @objc func indent() {
        sceneDelegate()?.indent()
    }
    
    @objc func outdent() {
        sceneDelegate()?.outdent()
    }

}


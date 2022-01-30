//
//  SceneDelegate.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/26/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import UIKit
import MarkupEditor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    let markupEnv = MarkupEnv(style: .compact)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Our markupEnv allows local images
        markupEnv.toolbarPreference.allowLocalImages = true
        
        // No storyboard
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }
    
    //MARK: Menu
    
    @objc func indent() {
        markupEnv.observedWebView.selectedWebView?.increaseQuoteLevel()
    }
    
    @objc func outdent() {
        markupEnv.observedWebView.selectedWebView?.decreaseQuoteLevel()
    }


}


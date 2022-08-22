//
//  SceneDelegate.swift
//  SwiftUIDemo
//
//  Created by Steven Harris on 1/24/22.
//

import UIKit
import SwiftUI
import MarkupEditor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let _ = (scene as? UIWindowScene) else { return }
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = DemoContentView()
        
        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            
            window.backgroundColor = .systemBackground
            
            let hostingController = UIHostingController(rootView: contentView)
            hostingController.view.backgroundColor = .clear
            hostingController.view.isOpaque = false
            
            window.rootViewController = hostingController
            
            self.window = window
            window.makeKeyAndVisible()
        }
            
    }
    
}

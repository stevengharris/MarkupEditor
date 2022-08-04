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
    let markupEnv = MarkupEnv(style: .compact, allowLocalImages: true)

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        // Specify your own ToolbarContents directly if you want. Here is an example
        // that eliminates the CorrectionToolbar and some of the FormatToolbar contents.
        // Note that the default for allowLocalImages is false, so you need to specify
        // it directly in ImageContents to set it properly.
        //
        //      let myToolbarContents = ToolbarContents(
        //          correction: false,
        //          formatContents: FormatContents(code: false, strike: false, subSuper: false),
        //          imageContents: ImageContents(allowLocalImages: true)
        //      )
        //      markupEnv.toolbarPreference.contents = myToolbarContents

        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        // Connect the markupMenu to the markupEnv
        (UIApplication.shared.delegate as! AppDelegate).markupMenu.markupEnv = markupEnv
        
        // No storyboard
        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.rootViewController = ViewController()
        self.window = window
        window.makeKeyAndVisible()
    }


}


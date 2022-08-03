//
//  SceneDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/24/22.
//

import UIKit
import SwiftUI
import MarkupEditor

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    
    var window: UIWindow?
    let markupEnv = MarkupEnv(style: .compact, allowLocalImages: true)
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        
        guard let _ = (scene as? UIWindowScene) else { return }
        
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
        
        // Create the SwiftUI view that provides the window contents.
        let contentView = ContentView(url: demoUrl())
            .environmentObject(markupEnv)
            .environmentObject(markupEnv.observedWebView)
            .environmentObject(markupEnv.selectionState)
            .environmentObject(markupEnv.toolbarPreference)
            .environmentObject(markupEnv.selectImage)
            .environmentObject(markupEnv.showSubToolbar)
        
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

    
    func demoUrl() -> URL? {
        return Bundle.main.resourceURL?.appendingPathComponent("demo.html")
    }
    
    //MARK: Menu actions
    
    /// Return false to disable various menu items depending on selectionState
    @objc override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        //print(action.description)
        switch action {
        case #selector(indent):
            return true
        case #selector(outdent):
            return true
        default:
            return super.canPerformAction(action, withSender: sender)
        }
    }
    
    @objc func indent() {
        markupEnv.observedWebView.selectedWebView?.indent()
    }
    
    @objc func outdent() {
        markupEnv.observedWebView.selectedWebView?.outdent()
    }
    
}

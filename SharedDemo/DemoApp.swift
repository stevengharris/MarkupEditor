//
//  DemoApp.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/20/26.
//

#if os(macOS)

import SwiftUI
import MarkupEditor

/// The main entry point only for MacOS.
@main
struct DemoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
            DemoContentView()
        }
    }
    
    init() {
        MarkupEditor.allowLocalImages = true
        // Set to true to allow the MarkupWKWebView to be inspectable from the Safari Development
        // menu in iOS/macCatalyst 16.4 or higher.
        MarkupEditor.isInspectable = true
    }
}

#endif

//
//  AppDelegate.swift
//  UIKitDemo
//
//  Created by Steven Harris on 3/26/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

#if !os(macOS)

import UIKit
import MarkupEditor

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    override init() {
        MarkupEditor.style = .compact
        MarkupEditor.allowLocalImages = true
        // Set to true to allow the MarkupWKWebView to be inspectable from the Safari Development
        // menu in iOS/macCatalyst 16.4 or higher.
        MarkupEditor.isInspectable = true
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

#else

import AppKit
import MarkupEditor

class AppDelegate: NSObject, NSApplicationDelegate {

    private var keymap: KeymapConfig?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        keymap = KeymapConfig.load()
        let mainMenu = buildMenu()
        DispatchQueue.main.async {
            NSApplication.shared.mainMenu = mainMenu
        }
    }
    
    private func buildMenu() -> NSMenu {
        let mainMenu = NSMenu()

        // Standard app menu
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        let appName = ProcessInfo.processInfo.processName
        appMenu.addItem(NSMenuItem(title: "About \(appName)", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
        servicesItem.submenu = NSMenu(title: "Services")
        NSApp.servicesMenu = servicesItem.submenu
        appMenu.addItem(servicesItem)
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        let hideOthers = NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
        hideOthers.keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(hideOthers)
        appMenu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        appMenu.addItem(.separator())
        appMenu.addItem(NSMenuItem(title: "Quit \(appName)", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        appMenuItem.submenu = appMenu

        // Standard file menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New", action: #selector(NSDocumentController.newDocument(_:)), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "Open…", action: #selector(NSDocumentController.openDocument(_:)), keyEquivalent: "o"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem(title: "Save…", action: #selector(NSDocument.save(_:)), keyEquivalent: "s"))
        fileMenuItem.submenu = fileMenu

        // Standard edit menu
        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(NSMenuItem(title: "Undo", action: Selector(("undo:")), keyEquivalent: "z"))
        let redoItem = NSMenuItem(title: "Redo", action: Selector(("redo:")), keyEquivalent: "z")
        redoItem.keyEquivalentModifierMask = [.command, .shift]
        editMenu.addItem(redoItem)
        editMenu.addItem(.separator())
        editMenu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        editMenu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        editMenu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        editMenu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))
        editMenuItem.submenu = editMenu

        // Format menu driven by toolbarconfig.json
        var config = ToolbarConfig.markdown()
        // For consistency with the original Mac Catalyst demo, add underscore back in,
        // altho strictly speaking it ain't Markdown.
        config.formatBar["underline"] = true
        if let formatMenu = buildFormatMenu(from: config) {
            let formatMenuItem = NSMenuItem()
            formatMenuItem.submenu = formatMenu
            mainMenu.addItem(formatMenuItem)
        }

        // Standard view menu
        let viewMenuItem = NSMenuItem()
        mainMenu.addItem(viewMenuItem)
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(NSMenuItem(title: "Actual Size", action: #selector(MarkupWKWebView.zoomToActualSize(_:)), keyEquivalent: "0"))
        let zoomIn = NSMenuItem(title: "Zoom In", action: #selector(MarkupWKWebView.zoomIn(_:)), keyEquivalent: "+")
        zoomIn.keyEquivalentModifierMask = .command
        viewMenu.addItem(zoomIn)
        let zoomOut = NSMenuItem(title: "Zoom Out", action: #selector(MarkupWKWebView.zoomOut(_:)), keyEquivalent: "-")
        zoomOut.keyEquivalentModifierMask = .command
        viewMenu.addItem(zoomOut)
        viewMenu.addItem(.separator())
        let toggleFullScreen = NSMenuItem(title: "Enter Full Screen", action: #selector(NSWindow.toggleFullScreen(_:)), keyEquivalent: "f")
        toggleFullScreen.keyEquivalentModifierMask = [.command, .control]
        viewMenu.addItem(toggleFullScreen)
        viewMenuItem.submenu = viewMenu

        // Standard window menu
        let windowMenuItem = NSMenuItem()
        mainMenu.addItem(windowMenuItem)
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
        windowMenu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:)), keyEquivalent: ""))
        windowMenu.addItem(.separator())
        windowMenu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))
        windowMenuItem.submenu = windowMenu
        NSApp.windowsMenu = windowMenu

        // Standard help menu
        let helpMenuItem = NSMenuItem()
        mainMenu.addItem(helpMenuItem)
        let helpMenu = NSMenu(title: "Help")
        let helpItem = NSMenuItem(title: "\(appName) Help", action: #selector(NSApplication.showHelp(_:)), keyEquivalent: "?")
        helpMenu.addItem(helpItem)
        helpMenuItem.submenu = helpMenu
        NSApp.helpMenu = helpMenu
        
        return mainMenu
    }

    // MARK: - Config-driven menu building

    /// Create an NSMenuItem with key binding from the keymap config.
    private func menuItem(title: String, action: Selector, keymapAction: String) -> NSMenuItem {
        if let binding = keymap?.binding(for: keymapAction) {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: binding.keyEquivalent)
            item.keyEquivalentModifierMask = binding.modifierMask
            return item
        }
        return NSMenuItem(title: title, action: action, keyEquivalent: "")
    }

    private func buildFormatMenu(from config: ToolbarConfig) -> NSMenu? {
        let visibility = config.visibility
        guard visibility["toolbar"] == true else { return nil }

        // Collect submenus in order specified by the ordering config
        var orderedEntries: [(Int, NSMenuItem)] = []

        if visibility["insertBar"] == true, let submenuItem = buildInsertSubmenuItem(from: config) {
            let order = config.ordering["insertBar"] ?? 20
            orderedEntries.append((order, submenuItem))
        }
        if visibility["styleMenu"] == true, let submenuItem = buildStyleSubmenuItem(from: config) {
            let order = config.ordering["styleMenu"] ?? 30
            orderedEntries.append((order, submenuItem))
        }
        if visibility["styleBar"] == true {
            let styleBar = config.styleBar
            if styleBar["list"] == true {
                let order = config.ordering["styleBar"] ?? 40
                for item in buildListItems() {
                    orderedEntries.append((order, item))
                }
            }
            if styleBar["dent"] == true {
                let order = (config.ordering["styleBar"] ?? 40) + 1
                for item in buildDentItems() {
                    orderedEntries.append((order, item))
                }
            }
        }
        if visibility["formatBar"] == true {
            let order = config.ordering["formatBar"] ?? 50
            for item in buildFormatItems(from: config) {
                orderedEntries.append((order, item))
            }
        }

        guard !orderedEntries.isEmpty else { return nil }

        // Stable sort by order
        orderedEntries.sort { $0.0 < $1.0 }

        let formatMenu = NSMenu(title: "Format")
        var lastOrder: Int?
        for (order, item) in orderedEntries {
            if let last = lastOrder, last != order {
                formatMenu.addItem(.separator())
            }
            formatMenu.addItem(item)
            lastOrder = order
        }
        return formatMenu
    }

    private func buildInsertSubmenuItem(from config: ToolbarConfig) -> NSMenuItem? {
        let items = config.insertBar
        let submenu = NSMenu(title: "Insert")

        if items["link"] == true {
            submenu.addItem(menuItem(title: "Link", action: Selector(("showPluggableLinkPopover")), keymapAction: "link"))
        }
        if items["image"] == true {
            submenu.addItem(menuItem(title: "Image", action: Selector(("showPluggableImagePopover")), keymapAction: "image"))
        }
        if items["tableMenu"] == true {
            submenu.addItem(NSMenuItem(title: "Table", action: Selector(("showPluggableTablePopover")), keyEquivalent: ""))
        }

        guard submenu.numberOfItems > 0 else { return nil }
        let item = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func buildStyleSubmenuItem(from config: ToolbarConfig) -> NSMenuItem? {
        let styleEntries: [(key: String, selector: Selector, defaultTitle: String)] = [
            ("p", #selector(MarkupWKWebView.pStyle), "Normal"),
            ("h1", #selector(MarkupWKWebView.h1Style), "Header 1"),
            ("h2", #selector(MarkupWKWebView.h2Style), "Header 2"),
            ("h3", #selector(MarkupWKWebView.h3Style), "Header 3"),
            ("h4", #selector(MarkupWKWebView.h4Style), "Header 4"),
            ("h5", #selector(MarkupWKWebView.h5Style), "Header 5"),
            ("h6", #selector(MarkupWKWebView.h6Style), "Header 6"),
        ]

        let submenu = NSMenu(title: "Style")
        for entry in styleEntries {
            if let label = config.styleMenu[entry.key] {
                let title = label ?? entry.defaultTitle
                submenu.addItem(menuItem(title: title, action: entry.selector, keymapAction: entry.key))
            }
        }

        guard submenu.numberOfItems > 0 else { return nil }
        let item = NSMenuItem(title: "Style", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func buildListItems() -> [NSMenuItem] {
        [
            menuItem(title: "Bullets", action: #selector(MarkupWKWebView.bullets), keymapAction: "bullet"),
            menuItem(title: "Numbers", action: #selector(MarkupWKWebView.numbers), keymapAction: "number"),
        ]
    }

    private func buildDentItems() -> [NSMenuItem] {
        [
            menuItem(title: "Indent", action: #selector(MarkupWKWebView.indentFromMenu), keymapAction: "indent"),
            menuItem(title: "Outdent", action: #selector(MarkupWKWebView.outdentFromMenu), keymapAction: "outdent"),
        ]
    }

    private func buildFormatItems(from config: ToolbarConfig) -> [NSMenuItem] {
        let items = config.formatBar
        var children = [NSMenuItem]()

        if items["bold"] == true {
            children.append(menuItem(title: "Bold", action: #selector(MarkupWKWebView.bold), keymapAction: "bold"))
        }
        if items["italic"] == true {
            children.append(menuItem(title: "Italic", action: #selector(MarkupWKWebView.italic), keymapAction: "italic"))
        }
        if items["underline"] == true {
            children.append(menuItem(title: "Underline", action: #selector(MarkupWKWebView.underline), keymapAction: "underline"))
        }
        if items["code"] == true {
            children.append(menuItem(title: "Code", action: #selector(MarkupWKWebView.code), keymapAction: "code"))
        }
        if items["strikethrough"] == true {
            children.append(menuItem(title: "Strikethrough", action: #selector(MarkupWKWebView.strike), keymapAction: "strikethrough"))
        }
        if items["subscript"] == true {
            children.append(menuItem(title: "Subscript", action: #selector(MarkupWKWebView.subscriptText), keymapAction: "subscript"))
        }
        if items["superscript"] == true {
            children.append(menuItem(title: "Superscript", action: #selector(MarkupWKWebView.superscript), keymapAction: "superscript"))
        }

        return children
    }
}

#endif

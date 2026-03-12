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
        // Add File menu items (New, Open, Save, Save As) matching the macOS version
        buildFileMenu(with: builder)

        // Customize View and Window menus to match macOS version.
        buildViewMenu(with: builder)
        buildWindowMenu(with: builder)
    }
    
    private func buildViewMenu(with builder: UIMenuBuilder) {
        // Strip the View menu down to just our zoom items and the system full screen item.
        // First, remove everything except .fullscreen from the system View menu.
        builder.replaceChildren(ofMenu: .view) { elements in
            elements.filter { element in
                guard let menu = element as? UIMenu else { return false }
                return menu.identifier == .fullscreen
            }
        }
        // Then add our zoom items at the start of the View menu.
        let zoomActual = UIKeyCommand(
            title: "Actual Size",
            action: Selector(("zoomToActualSize:")),
            input: "0",
            modifierFlags: .command
        )
        let zoomIn = UIKeyCommand(
            title: "Zoom In",
            action: Selector(("zoomIn:")),
            input: "+",
            modifierFlags: .command
        )
        let zoomOut = UIKeyCommand(
            title: "Zoom Out",
            action: Selector(("zoomOut:")),
            input: "-",
            modifierFlags: .command
        )
        let zoomMenu = UIMenu(title: "", options: .displayInline, children: [zoomActual, zoomIn, zoomOut])
        builder.insertChild(zoomMenu, atStartOfMenu: .view)
        // Add Show HTML at the end of the View menu
        let showHtml = UIKeyCommand(
            title: "Show HTML",
            image: UIImage(systemName: "chevron.left.slash.chevron.right"),
            action: #selector(menuShowHtml),
            input: "U",
            modifierFlags: [.command, .shift]
        )
        let showHtmlMenu = UIMenu(title: "", options: .displayInline, children: [showHtml])
        builder.insertChild(showHtmlMenu, atEndOfMenu: .view)
    }
    
    private func buildFileMenu(with builder: UIMenuBuilder) {
        let newDoc = UIKeyCommand(
            title: "New",
            image: UIImage(systemName: "plus"),
            action: #selector(menuNewDocument),
            input: "N",
            modifierFlags: .command
        )
        let openDoc = UIKeyCommand(
            title: "Open…",
            image: UIImage(systemName: "folder"),
            action: #selector(menuOpenDocument),
            input: "O",
            modifierFlags: .command
        )
        let saveDoc = UIKeyCommand(
            title: "Save",
            image: UIImage(systemName: "square.and.arrow.down"),
            action: #selector(menuSaveDocument),
            input: "S",
            modifierFlags: .command
        )
        let saveAsDoc = UIKeyCommand(
            title: "Save As…",
            image: UIImage(systemName: "square.and.arrow.down.on.square"),
            action: #selector(menuSaveAsDocument),
            input: "S",
            modifierFlags: [.command, .shift]
        )
        // The system .file menu may not exist in Catalyst. Remove it if present
        // and insert our own File menu after the app menu.
        builder.remove(menu: .file)
        let closeWindow = UIKeyCommand(
            title: "Close",
            image: UIImage(systemName: "xmark"),
            action: Selector(("performClose:")),
            input: "W",
            modifierFlags: .command
        )
        let fileMenu = UIMenu(
            title: "File",
            identifier: .file,
            children: [newDoc, openDoc, closeWindow, saveDoc, saveAsDoc]
        )
        builder.insertSibling(fileMenu, afterMenu: .application)
    }

    @objc private func menuNewDocument() {
        NotificationCenter.default.post(name: .menuNewDocument, object: nil)
    }

    @objc private func menuOpenDocument() {
        NotificationCenter.default.post(name: .menuOpenDocument, object: nil)
    }

    @objc private func menuSaveDocument() {
        NotificationCenter.default.post(name: .menuSaveDocument, object: nil)
    }

    @objc private func menuSaveAsDocument() {
        NotificationCenter.default.post(name: .menuSaveAsDocument, object: nil)
    }

    @objc private func menuShowHtml() {
        NotificationCenter.default.post(name: .menuShowHtml, object: nil)
    }

    private func buildWindowMenu(with builder: UIMenuBuilder) {
        // Keep the system Window menu but strip it down to just
        // Minimize, Zoom, and Bring All to Front (matching macOS version).
        // Remove everything except the standard minimizeAndZoom and bringAllToFront groups.
        builder.replaceChildren(ofMenu: .window) { elements in
            // The system provides .minimizeAndZoom and .bringAllToFront as child menus.
            // Filter to keep only those, removing tab-related and other items.
            return elements.filter { element in
                guard let menu = element as? UIMenu else { return false }
                return menu.identifier == .minimizeAndZoom || menu.identifier == .bringAllToFront
            }
        }
    }
    
}

#else

import AppKit
import MarkupEditor

class AppDelegate: NSObject, NSApplicationDelegate {

    private var keymap: KeymapConfig?

    func applicationWillFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        // Set the menu early so it's available before SwiftUI creates its window.
        // Note: SwiftUI's WindowGroup mutates this NSMenu in-place between
        // willFinishLaunching and didFinishLaunching, stripping items it doesn't
        // manage (File, Edit, and any custom menus like Format). It keeps only
        // the menus it recognizes (app menu, View, Window, Help).
        keymap = KeymapConfig.load()
        NSApplication.shared.mainMenu = buildMenu()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Rebuild and reassign the full menu after SwiftUI has finished its
        // mutation pass. A fresh NSMenu is required because SwiftUI removed
        // items from the original — those NSMenuItems can't simply be re-added
        // since their parent reference was cleared during removal.
        NSApplication.shared.mainMenu = buildMenu()
    }

    // MARK: - File menu actions
    //
    // Menu items post notifications that DemoContentView handles, so the view
    // owns document state (hasChanges, currentFileURL) and file I/O logic.

    @objc private func newDocument(_ sender: Any?) {
        NotificationCenter.default.post(name: .menuNewDocument, object: nil)
    }

    @objc private func openDocument(_ sender: Any?) {
        NotificationCenter.default.post(name: .menuOpenDocument, object: nil)
    }

    @objc private func saveDocument(_ sender: Any?) {
        NotificationCenter.default.post(name: .menuSaveDocument, object: nil)
    }

    @objc private func saveAsDocument(_ sender: Any?) {
        NotificationCenter.default.post(name: .menuSaveAsDocument, object: nil)
    }

    @objc private func showHtml(_ sender: Any?) {
        NotificationCenter.default.post(name: .menuShowHtml, object: nil)
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

        // File menu
        let fileMenuItem = NSMenuItem()
        mainMenu.addItem(fileMenuItem)
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(NSMenuItem(title: "New", action: #selector(newDocument(_:)), keyEquivalent: "n"))
        fileMenu.addItem(NSMenuItem(title: "Open…", action: #selector(openDocument(_:)), keyEquivalent: "o"))
        fileMenu.addItem(.separator())
        fileMenu.addItem(NSMenuItem(title: "Close", action: #selector(NSWindow.performClose(_:)), keyEquivalent: "w"))
        fileMenu.addItem(NSMenuItem(title: "Save", action: #selector(saveDocument(_:)), keyEquivalent: "s"))
        let saveAsItem = NSMenuItem(title: "Save As…", action: #selector(saveAsDocument(_:)), keyEquivalent: "s")
        saveAsItem.keyEquivalentModifierMask = [.command, .shift]
        saveAsItem.image = NSImage(systemSymbolName: "square.and.arrow.down.on.square", accessibilityDescription: "Save As")
        fileMenu.addItem(saveAsItem)
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
        editMenu.addItem(.separator())
        let findItem = jsMenuItem(title: "Find", js: "MU.toggleSearch()", keyEquivalent: "f", modifierMask: .command)
        findItem.image = NSImage(systemSymbolName: "magnifyingglass", accessibilityDescription: "Find")
        editMenu.addItem(findItem)
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
        viewMenu.addItem(.separator())
        let showHtmlItem = NSMenuItem(title: "Show HTML", action: #selector(showHtml(_:)), keyEquivalent: "u")
        showHtmlItem.keyEquivalentModifierMask = [.command, .shift]
        showHtmlItem.image = NSImage(systemSymbolName: "chevron.left.slash.chevron.right", accessibilityDescription: "Show HTML")
        showHtmlItem.target = self
        viewMenu.addItem(showHtmlItem)
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

    // MARK: - Insert menu via executeJavaScript

    /// Execute a JavaScript command on the selected MarkupWKWebView.
    /// Menu items store their JS command string in representedObject.
    @MainActor @objc private func executeMenuJS(_ sender: NSMenuItem) {
        guard let js = sender.representedObject as? String else { return }
        MarkupEditor.selectedWebView?.executeJavaScript(js)
    }

    /// Create an NSMenuItem whose action calls executeJavaScript with the given JS command.
    private func jsMenuItem(title: String, js: String, keyEquivalent: String = "", modifierMask: NSEvent.ModifierFlags = .command) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(executeMenuJS(_:)), keyEquivalent: keyEquivalent)
        item.keyEquivalentModifierMask = modifierMask
        item.representedObject = js
        item.target = self
        return item
    }

    /// Create a JS menu item with key binding from the keymap config.
    private func jsMenuItem(title: String, js: String, keymapAction: String) -> NSMenuItem {
        if let binding = keymap?.binding(for: keymapAction) {
            let item = NSMenuItem(title: title, action: #selector(executeMenuJS(_:)), keyEquivalent: binding.keyEquivalent)
            item.keyEquivalentModifierMask = binding.modifierMask
            item.representedObject = js
            item.target = self
            return item
        }
        let item = NSMenuItem(title: title, action: #selector(executeMenuJS(_:)), keyEquivalent: "")
        item.representedObject = js
        item.target = self
        return item
    }

    private func buildInsertSubmenuItem(from config: ToolbarConfig) -> NSMenuItem? {
        let items = config.insertBar
        let submenu = NSMenu(title: "Insert")

        if items["link"] == true {
            let linkItem = jsMenuItem(title: "Link", js: "MU.openLinkDialog()", keymapAction: "link")
            linkItem.image = NSImage(systemSymbolName: "link", accessibilityDescription: "Link")
            submenu.addItem(linkItem)
        }
        if items["image"] == true {
            let imageItem = jsMenuItem(title: "Image", js: "MU.openImageDialog()", keymapAction: "image")
            imageItem.image = NSImage(systemSymbolName: "photo", accessibilityDescription: "Image")
            submenu.addItem(imageItem)
        }
        if items["tableMenu"] == true {
            let tableItem = buildTableSubmenuItem(from: config)
            tableItem.image = NSImage(systemSymbolName: "squareshape.split.3x3", accessibilityDescription: "Table")
            submenu.addItem(tableItem)
        }

        guard submenu.numberOfItems > 0 else { return nil }
        let item = NSMenuItem(title: "Insert", action: nil, keyEquivalent: "")
        item.image = NSImage(systemSymbolName: "text.insert", accessibilityDescription: "Insert")
        item.submenu = submenu
        return item
    }

    private func buildTableSubmenuItem(from config: ToolbarConfig) -> NSMenuItem {
        let tableItem = NSMenuItem(title: "Table", action: nil, keyEquivalent: "")
        let tableMenu = NSMenu(title: "Table")

        // Create submenu — rows x cols grid
        let createItem = NSMenuItem(title: "Create", action: nil, keyEquivalent: "")
        let createMenu = NSMenu(title: "Create")
        for rows in 1...4 {
            let rowItem = NSMenuItem(title: "\(rows) Row\(rows > 1 ? "s" : "")", action: nil, keyEquivalent: "")
            let rowMenu = NSMenu(title: "\(rows) Row\(rows > 1 ? "s" : "")")
            for cols in 1...4 {
                rowMenu.addItem(jsMenuItem(title: "\(cols) Col\(cols > 1 ? "s" : "")", js: "MU.insertTable(\(rows), \(cols))"))
            }
            rowItem.submenu = rowMenu
            createMenu.addItem(rowItem)
        }
        createItem.submenu = createMenu
        tableMenu.addItem(createItem)

        // Add submenu
        let addItem = NSMenuItem(title: "Add", action: nil, keyEquivalent: "")
        let addMenu = NSMenu(title: "Add")
        addMenu.addItem(jsMenuItem(title: "Row Above", js: "MU.addRow(\"BEFORE\")"))
        addMenu.addItem(jsMenuItem(title: "Row Below", js: "MU.addRow(\"AFTER\")"))
        addMenu.addItem(jsMenuItem(title: "Column Before", js: "MU.addCol(\"BEFORE\")"))
        addMenu.addItem(jsMenuItem(title: "Column After", js: "MU.addCol(\"AFTER\")"))
        if config.tableMenu["header"] == true {
            addMenu.addItem(jsMenuItem(title: "Header", js: "MU.addHeader()"))
        }
        addItem.submenu = addMenu
        tableMenu.addItem(addItem)

        // Delete submenu
        let deleteItem = NSMenuItem(title: "Delete", action: nil, keyEquivalent: "")
        let deleteMenu = NSMenu(title: "Delete")
        deleteMenu.addItem(jsMenuItem(title: "Row", js: "MU.deleteTableArea(\"ROW\")"))
        deleteMenu.addItem(jsMenuItem(title: "Column", js: "MU.deleteTableArea(\"COL\")"))
        deleteMenu.addItem(jsMenuItem(title: "Table", js: "MU.deleteTableArea(\"TABLE\")"))
        deleteItem.submenu = deleteMenu
        tableMenu.addItem(deleteItem)

        // Border submenu
        if config.tableMenu["border"] == true {
            let borderItem = NSMenuItem(title: "Border", action: nil, keyEquivalent: "")
            let borderMenu = NSMenu(title: "Border")
            borderMenu.addItem(jsMenuItem(title: "All", js: "MU.borderTable(\"cell\")"))
            borderMenu.addItem(jsMenuItem(title: "Outer", js: "MU.borderTable(\"outer\")"))
            borderMenu.addItem(jsMenuItem(title: "Header", js: "MU.borderTable(\"header\")"))
            borderMenu.addItem(jsMenuItem(title: "None", js: "MU.borderTable(\"none\")"))
            borderItem.submenu = borderMenu
            tableMenu.addItem(borderItem)
        }

        tableItem.submenu = tableMenu
        return tableItem
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
        item.image = NSImage(systemSymbolName: "paragraphsign", accessibilityDescription: "Style")
        item.submenu = submenu
        return item
    }

    private func buildListItems() -> [NSMenuItem] {
        let bullets = menuItem(title: "Bullets", action: #selector(MarkupWKWebView.bullets), keymapAction: "bullet")
        bullets.image = NSImage(systemSymbolName: "list.bullet", accessibilityDescription: "Bullets")
        let numbers = menuItem(title: "Numbers", action: #selector(MarkupWKWebView.numbers), keymapAction: "number")
        numbers.image = NSImage(systemSymbolName: "list.number", accessibilityDescription: "Numbers")
        return [bullets, numbers]
    }

    private func buildDentItems() -> [NSMenuItem] {
        let indent = menuItem(title: "Indent", action: #selector(MarkupWKWebView.indentFromMenu), keymapAction: "indent")
        indent.image = NSImage(systemSymbolName: "increase.quotelevel", accessibilityDescription: "Indent")
        let outdent = menuItem(title: "Outdent", action: #selector(MarkupWKWebView.outdentFromMenu), keymapAction: "outdent")
        outdent.image = NSImage(systemSymbolName: "decrease.quotelevel", accessibilityDescription: "Outdent")
        return [indent, outdent]
    }

    private func buildFormatItems(from config: ToolbarConfig) -> [NSMenuItem] {
        let items = config.formatBar
        var children = [NSMenuItem]()

        if items["bold"] == true {
            let item = menuItem(title: "Bold", action: #selector(MarkupWKWebView.bold), keymapAction: "bold")
            item.image = NSImage(systemSymbolName: "bold", accessibilityDescription: "Bold")
            children.append(item)
        }
        if items["italic"] == true {
            let item = menuItem(title: "Italic", action: #selector(MarkupWKWebView.italic), keymapAction: "italic")
            item.image = NSImage(systemSymbolName: "italic", accessibilityDescription: "Italic")
            children.append(item)
        }
        if items["underline"] == true {
            let item = menuItem(title: "Underline", action: #selector(MarkupWKWebView.underline), keymapAction: "underline")
            item.image = NSImage(systemSymbolName: "underline", accessibilityDescription: "Underline")
            children.append(item)
        }
        if items["code"] == true {
            let item = menuItem(title: "Code", action: #selector(MarkupWKWebView.code), keymapAction: "code")
            item.image = NSImage(systemSymbolName: "curlybraces", accessibilityDescription: "Code")
            children.append(item)
        }
        if items["strikethrough"] == true {
            let item = menuItem(title: "Strikethrough", action: #selector(MarkupWKWebView.strike), keymapAction: "strikethrough")
            item.image = NSImage(systemSymbolName: "strikethrough", accessibilityDescription: "Strikethrough")
            children.append(item)
        }
        if items["subscript"] == true {
            let item = menuItem(title: "Subscript", action: #selector(MarkupWKWebView.subscriptText), keymapAction: "subscript")
            item.image = NSImage(systemSymbolName: "textformat.subscript", accessibilityDescription: "Subscript")
            children.append(item)
        }
        if items["superscript"] == true {
            let item = menuItem(title: "Superscript", action: #selector(MarkupWKWebView.superscript), keymapAction: "superscript")
            item.image = NSImage(systemSymbolName: "textformat.superscript", accessibilityDescription: "Superscript")
            children.append(item)
        }

        return children
    }
}

#endif

extension Notification.Name {
    static let menuNewDocument = Notification.Name("menuNewDocument")
    static let menuOpenDocument = Notification.Name("menuOpenDocument")
    static let menuSaveDocument = Notification.Name("menuSaveDocument")
    static let menuSaveAsDocument = Notification.Name("menuSaveAsDocument")
    static let menuShowHtml = Notification.Name("menuShowHtml")
}

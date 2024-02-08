//
//  MarkupWKWebView+DivExtensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/15/24.
//

import OSLog

extension MarkupWKWebView {
    
    /// Add all the divs in `divStructure` into this view along with their resources which must be uniquely named.
    ///
    /// This method invokes many async JavaScript methods to add the `divStructure` divs, without waiting for any response.
    public func load(divStructure: MarkupDivStructure, index: Int = 0, handler: (()->Void)? = nil) {
        for div in divStructure.divs {
            if let resourcesUrl = div.resourcesUrl {
                copyResources(from: resourcesUrl)
            }
            addDiv(div)
        }
        handler?()
    }
    
    /// Unload all divs in the `divStructure`.
    ///
    /// This method invokes many async JavaScript methods to remove the `divStructure` divs, without waiting for any response.
    /// As an alternative, we could use `removeAllDivs`, but we do it explicitly this way because we want it to be obvious if
    /// the contents of divStructure does not correspond to what is in the view. This can happen if the view is SwiftUI view that holds
    /// the MarkupEditorView gets initialized because of a state change.
    public func unload(divStructure: MarkupDivStructure, index: Int = 0, handler: (()->Void)? = nil) {
        for div in divStructure.divs {
            // Note we do not remove resources from the temp directory
            removeDiv(div)
        }
        handler?()
    }
    
    /* Alternative to use recursion and wait for callbacks */
    /*
    /// Recursively load all divs in `divStructure` into this view, executing the handler when they are all done.
    public func load(divStructure: MarkupDivStructure, index: Int = 0, handler: (()->Void)? = nil) {
        loadDiv(divStructure: divStructure, atIndex: index) { nextIndex in
            if let nextIndex {
                self.load(divStructure: divStructure, index: nextIndex, handler: handler)
            } else {
                print("executing load handler")
                handler?()
            }
        }
    }
    
    /// Load the div found at index into the view and execute the handler with the next index when done.
    ///
    /// Note that "done" just means the async call into JavaScript returned, not that whatever we are loading
    /// on the JavaScript side actually loaded. The reason to execute the loading process in this way is to avoid
    /// triggering IPC throttling when executing hundreds of evaluateJavaScript calls without waiting for them to
    /// execute their handler. See https://forums.developer.apple.com/forums/thread/670959 as an example,
    /// but I have seen "IPC throttling was triggered (has 625 pending incoming messages, will only process 600 before yielding)".
    private func loadDiv(divStructure: MarkupDivStructure, atIndex index: Int, handler: @escaping (Int?)->Void) {
        guard index < divStructure.divs.count else {
            handler(nil)
            return
        }
        let div = divStructure.divs[index]
        if let resourcesUrl = div.resourcesUrl {
            copyResources(from: resourcesUrl)
        }
        addDiv(div) {
            handler(index + 1)
        }
    }
    
    public func unload(divStructure: MarkupDivStructure, index: Int = 0, handler: (()->Void)? = nil) {
        unloadDiv(divStructure: divStructure, atIndex: index) { nextIndex in
            if let nextIndex {
                self.unload(divStructure: divStructure, index: nextIndex, handler: handler)
            } else {
                print("executing unload handler")
                handler?()
            }
        }
    }
    
    private func unloadDiv(divStructure: MarkupDivStructure, atIndex index: Int, handler: @escaping (Int?)->Void) {
        guard index < divStructure.divs.count else {
            handler(nil)
            return
        }
        let div = divStructure.divs[index]
        // TODO: Remove resources
        removeDiv(div) {
            handler(index + 1)
        }
    }
    */
    
    /// Copy all the resources from the baseUrl into the temp path used for editing.
    ///
    /// Note that resources need to be uniquely named across all divs in the document.
    private func copyResources(from resourcesUrl: URL) {
        let fileManager = FileManager.default
        var tempResourcesUrl: URL
        if resourcesUrl.baseURL == nil {
            tempResourcesUrl = baseUrl
        } else {
            tempResourcesUrl = baseUrl.appendingPathComponent(resourcesUrl.relativePath)
        }
        let tempResourcesUrlPath = tempResourcesUrl.path
        do {
            try fileManager.createDirectory(atPath: tempResourcesUrlPath, withIntermediateDirectories: true, attributes: nil)
            // If we specify the resourceUrl but there are no resources, it's not an error
            let resources = (try? fileManager.contentsOfDirectory(at: resourcesUrl, includingPropertiesForKeys: nil, options: [])) ?? []
            for srcUrl in resources {
                let dstUrl = tempResourcesUrl.appendingPathComponent(srcUrl.lastPathComponent)
                try? fileManager.removeItem(at: dstUrl)
                try fileManager.copyItem(at: srcUrl, to: dstUrl)
            }
        } catch let error {
            Logger.webview.error("Failure copying resource files: \(error.localizedDescription)")
        }
    }
    
    /// Add the `div` into the view, including its buttons if they are not dynamically created.
    public func addDiv(_ div: HtmlDivHolder, handler: (()->Void)? = nil) {
        let id = div.id
        let parentId = div.parentId
        let cssClass = div.cssClass
        let attributes = div.attributes
        var jsonAttributes: String?
        if !attributes.isEmpty, let jsonData = try? JSONSerialization.data(withJSONObject: attributes.options) {
            jsonAttributes = String(data: jsonData, encoding: .utf8)
        }
        let htmlContents = div.htmlContents.escaped
        let buttonGroup = div.buttonGroup
        evaluateJavaScript("MU.addDiv('\(id)', '\(parentId)', '\(cssClass)', '\(jsonAttributes ?? "null")', '\(htmlContents)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlDiv: \(error)")
            }
            if let buttonGroup, !buttonGroup.isDynamic {
                self.addButtonGroup(buttonGroup) {
                    handler?()
                }
            } else {
                handler?()
            }
        }
    }
    
    /// Remove the `div` from the view.
    public func removeDiv(_ div: HtmlDivHolder, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.removeDiv('\(div.id)')") { result, error in
            if let error {
                Logger.webview.error("Error removing HtmlDiv: \(error)")
            }
            handler?()
        }
    }
    
    /// Add the `buttonGroup` to the view.
    ///
    /// A button group is a div containing buttons, so they can be positioned as a group.
    /// Button groups always reside in some parent, typically non-contenteditable header with a focusId of the contentEditable div.
    public func addButtonGroup(_ buttonGroup: HtmlButtonGroup, handler: (()->Void)? = nil) {
        let id = buttonGroup.id
        let parentId = buttonGroup.parentId
        let cssClass = buttonGroup.cssClass
        evaluateJavaScript("MU.addDiv('\(id)', '\(parentId)', '\(cssClass)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlButtonGroup: \(error)")
            } else {
                // We are going to be running handler before all the buttons are added, but we don't care
                for button in buttonGroup.buttons {
                    self.addButton(button, in: id)
                }
            }
            handler?()
        }
    }
    
    /// Remove the `buttonGroup` from the view.
    public func removeButtonGroup(_ buttonGroup: HtmlButtonGroup, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.removeDiv('\(buttonGroup.id)')") { result, error in
            if let error {
                Logger.webview.error("Error removing HtmlButtonGroup: \(error)")
            }
            handler?()
        }
    }

    /// Add a `button` into a parent HtmlButtonGroup div with id `parentId`.
private func addButton(_ button: HtmlButton, in parentId: String, handler: (()->Void)? = nil) {
        let id = button.id
        let cssClass = button.cssClass
        let label = button.label.escaped
        evaluateJavaScript("MU.addButton('\(id)', '\(parentId)', '\(cssClass)', '\(label)')") { result, error in
            if let error {
                Logger.webview.error("Error adding HtmlButton: \(error)")
            }
            handler?()
        }
    }
    
    /// Remove a `button` based on its id.
    private func removeButton(_ button: HtmlButton, handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.removeButton('\(button.id)')") { result, error in
            if let error {
                Logger.webview.error("Error removing HtmlButton: \(error)")
            }
            handler?()
        }
    }
    
    /// Focus on the element with `id`.
    ///
    /// Used to set the focus on a contenteditable div. After focusing, the selection state is reset.
    public func focus(on id: String?, handler: (()->Void)? = nil) {
        guard let id else {
            handler?()
            return
        }
        evaluateJavaScript("MU.focusOn('\(id)')") { result, error in
            if let error {
                Logger.webview.error("Error focusing on element with id \(id): \(error)")
            }
            self.becomeFirstResponder()
            self.getSelectionState { selectionState in
                MarkupEditor.selectionState.reset(from: selectionState)
                handler?()
            }
        }
    }
    
    /// Scroll the element with `id` into the view.
    public func scrollIntoView(id: String?, handler: (()->Void)? = nil) {
        guard let id else {
            handler?()
            return
        }
        evaluateJavaScript("MU.scrollIntoView('\(id)')") { result, error in
            if let error {
                Logger.webview.error("Error scrolling to element with id \(id): \(error)")
            }
            handler?()
        }
    }
    
    public func removeAllDivs(handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.removeAllDivs()") { result, error in
            if let error {
                Logger.webview.error("Error removing all divs: \(error)")
            }
            handler?()
        }
    }

}

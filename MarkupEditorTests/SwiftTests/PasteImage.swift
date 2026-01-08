//
//  PasteImage.swift
//  MarkupEditor
//
//  Created by Steven Harris on 10/14/25.
//

import Testing

import MarkupEditor
import Testing
import WebKit

/// This test ensures that when an image is pasted into a document in the Swift MarkupEditor, the image src points at a UUID string
/// name that was exists in the document directory. The test is Swift MarkupEditor specific. This functionality is not available in
/// markupeditor-base. In the markupeditor-desktop app, a roughly analogous approach is used wherein the data for the image is
/// embedded in the src, and that data is saved into a file in the document directory at save time for the document.
@Suite(.serialized)
class PasteImage: MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loaded = false
    var imageLoaded = false
    var htmlTest: HtmlTest!

    /// Once-per test initialization, which is frankly ridiculous, but there is no way to do a once-per-suite initialization.
    init() async throws {
        try await waitForReady()
        htmlTest = HtmlTest(
            description: "Image in P - Paste image at insertion point in a word",
            startHtml: "<p>This is ju|st a simple paragraph.</p>"
        )
        htmlTest.stringAction = paste()
    }
    
    deinit {
        webView = nil
        coordinator = nil
        htmlTest = nil
    }
    
    /// Paste a UIImage at the selection point. Paste is handled on the Swift side, where the clipboard contents
    /// produces a UIImage, and then the image contents is saved to a unique filename in the document directory.
    /// The filename is then passed to the JavaScript side as src pointing at the local filename. The name is
    /// uniquely generated, so the test just makes sure it is in an expected form and actually exists. When we
    /// paste an image this way, we have to wait for the MarkupDelegate markupImageAdded callback, because
    /// the addition of image size is done async based on the actual image size.
    func paste() -> () async throws -> String? {
        return {
            await self.webView.pasteImage(UIImage(systemName: "calendar"))
            try await self.imageAdded(timeout: .milliseconds(1000))
            let html = await self.webView.getTestHtml(sel: "|")
            if let imageFileName = self.imageFilename(in: html) {
                #expect(self.webView.resourceExists(imageFileName))
            }
            self.htmlTest.endHtml = html!
            return html
        }
    }

    /// Set up the `webView` and `coordinator` and then wait for them to be ready.
    func waitForReady() async throws {
        try await confirmation { confirmation in
            webView = MarkupWKWebView(markupDelegate: self)
            coordinator = MarkupCoordinator(
                markupDelegate: self,
                webView: webView
            )
            // The coordinator will receive callbacks from markup.js
            // using window.webkit.messageHandlers.test.postMessage(<message>)
            webView.setCoordinatorConfiguration(coordinator)
            _ = try await ready(timeout: .seconds(HtmlTest.timeout), confirm: confirmation)
        }
    }

    /// Just yield until `loaded` has been set in the `markupDidLoad` callback. Somewhat adapted from
    /// https://gist.github.com/janodev/32217b09f307da8c96e2cf629c31a8eb
    func ready(timeout: Duration, confirm: Confirmation) async throws {
        let startTime = ContinuousClock.now
        while ContinuousClock.now - startTime < timeout {
            if loaded {
                confirm()
                break
            }
            await Task.yield()
        }
        if !loaded {
            throw TestError.timeout(
                "Load did not succeed within \(timeout) seconds"
            )
        }
    }

    /// Since we marked self as the `markupDelegate`, we receive the `markupDidLoad` message
    func markupDidLoad(_ view: MarkupWKWebView, handler: (() -> Void)?) {
        loaded = true
        handler?()
    }

    func imageAdded(timeout: Duration) async throws {
        try await confirmation { confirm in
            let startTime = ContinuousClock.now
            while ContinuousClock.now - startTime < timeout {
                if imageLoaded {
                    confirm()
                    break
                }
                await Task.yield()
            }
            if !imageLoaded {
                throw TestError.timeout(
                    "Image did not load within \(timeout) seconds"
                )
            }
        }
    }

    func markupImageAdded(url: URL) {
        imageLoaded = true
    }
    
    func imageFilename(in tag: String?) -> String? {
        // The tag must be a valid <img> tag, like <img src="2537ACEF-A318-4395-8955-8F2C73701AD0.png">
        guard
            let tag,
            tag.contains("<img"),
            let srcRange = tag.range(of: "src=\"") else {
            return nil
        }
        let srcSize = UUID().uuidString.count + 4    // The image file name will always be a UUID + extension
        let startIndex = srcRange.upperBound
        let endIndex = tag.index(startIndex, offsetBy: srcSize)
        return String(tag[startIndex..<endIndex])
    }

    /// Run the HtmlTest
    @Test
    func run() async throws {
        await htmlTest.run(in: webView)
    }

}

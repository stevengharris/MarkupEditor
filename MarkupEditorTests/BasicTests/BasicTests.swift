//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
import MarkupEditor
import OSLog

@MainActor class BasicTests: XCTestCase, MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation!
    var inputHandler: (()->Void)?
    
    override func setUp() {
        continueAfterFailure = true
        loadedExpectation = XCTestExpectation(description: "Loaded")
        webView = MarkupWKWebView(markupDelegate: self)
        coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
    }
    
    func markupDidLoad(_ view: MarkupWKWebView, handler: (()->Void)?) {
        // Since we marked self as the markupDelegate, we receive the markupDidLoad message
        loadedExpectation.fulfill()
        handler?()
    }
    
    /// Execute the inputHandler once if defined, then nil it out
    func markupInput(_ view: MarkupWKWebView) {
        guard let inputHandler = inputHandler else {
            return
        }
        //print("*** handling input")
        inputHandler()
        self.inputHandler = nil
    }
    
    func assertEqualStrings(expected: String, saw: String?) {
        XCTAssert(expected == saw, "Expected \(expected), saw: \(saw ?? "nil")")
    }
    
    func addInputHandler(_ handler: @escaping (()->Void)) {
        inputHandler = handler
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
    
    func testLoad() throws {
        Logger.test.info("Test: Ensure loadInitialHtml has run.")
        // Do nothing other than run setupWithError
    }
    
    func testBaselineBehavior() throws {
        Logger.test.info("Test: Ensure setting contents, selection, and text extraction work as expected.")
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Simple test",
                startHtml: "<p>He|llo wor|ld</p>",
                endHtml: "<p>He|llo wor|ld</p>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testExtractContents {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Extract when selection begins in one styled list item, ends in another",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered item 1.</p></li><li><p>P Numbered ite2.</p></li><li><p>P |Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbereitem 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted ite2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered item 1.</p></li><li><p>P Numbered ite2.</p></li><li><p>P |Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbereitem 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted ite2.</h5></li></ul>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testExtractContents {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Extract when selection is in a table",
                startHtml: "<table><tr><td><p>|</p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>This is simple paragraph</p>",
                endHtml: "<table><tr><td><p>|</p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>This is simple paragraph</p>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testExtractContents {
                            handler()
                        }
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let expectation = XCTestExpectation(description: "Basic operations")
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        expectation.fulfill()
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testFormats() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Bold selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<strong>is|</strong> a start</p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<em>is|</em> a start</p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<u>is|</u> a start</p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Strikethrough selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<s>is|</s> a start</p>",
                action: { handler in
                    self.webView.strike() { handler() }
                }
            ),
            HtmlTest(
                description: "Superscript selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<sup>is|</sup> a start</p>",
                action: { handler in
                    self.webView.superscript() { handler() }
                }
            ),
            HtmlTest(
                description: "Subscript selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<sub>is|</sub> a start</p>",
                action: { handler in
                    self.webView.subscriptText() { handler() }
                }
            ),
            HtmlTest(
                description: "Code selection",
                startHtml: "<p>This |is| a start</p>",
                endHtml: "<p>This |<code>is|</code> a start</p>",
                action: { handler in
                    self.webView.code() { handler() }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Format selection")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to format the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testUnformats() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Inside bold selection",
                startHtml: "<p>This |<strong>is|</strong> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Inside italic selection",
                startHtml: "<p>This |<em>is|</em> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Inside underline selection",
                startHtml: "<p>This |<u>is|</u> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Inside strikethrough selection",
                startHtml: "<p>This |<s>is|</s> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.strike() { handler() }
                }
            ),
            HtmlTest(
                description: "Inside superscript selection",
                startHtml: "<p>This |<sup>is|</sup> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.superscript() { handler() }
                }
            ),
            HtmlTest(
                description: "Inside subscript selection",
                startHtml: "<p>This |<sub>is|</sub> a start</p>",
                endHtml: "<p>This |is| a start</p>",
                action: { handler in
                    self.webView.subscriptText() { handler() }
                }
            )
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformat selection")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to unformat the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testMultiFormats() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Unbold <p><strong><u>Wo|rd 1 Word 2 Wo|rd 3</u></strong></p>",
                startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                endHtml: "<p><u><strong>Wo|</strong>rd 1 Word 2 Wo|<strong>rd 3</strong></u></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                endHtml: "<p><u><strong>Wo|</strong></u><strong>rd 1 Word 2 Wo|</strong><u><strong>rd 3</strong></u></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic <p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                startHtml: "<p><u><strong>Wo|rd 1 Word 2 Wo|rd 3</strong></u></p>",
                endHtml: "<p><u><strong>Wo|</strong></u><em><u><strong>rd 1 Word 2 Wo|</strong></u></em><u><strong>rd 3</strong></u></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                endHtml: "<p><strong>Hello </strong><u><strong>bold |</strong>and|<strong> underline</strong></u><strong> world</strong></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                endHtml: "<p><strong>Hello </strong><u><strong>bold |</strong></u><strong>and|</strong><u><strong> underline</strong></u><strong> world</strong></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic <p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                startHtml: "<p><strong>Hello </strong><u><strong>bold |and| underline</strong></u><strong> world</strong></p>",
                endHtml: "<p><strong>Hello </strong><u><strong>bold |</strong></u><em><u><strong>and|</strong></u></em><u><strong> underline</strong></u><strong> world</strong></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                endHtml: "<p><em>|Hello </em>wo|<strong>rld</strong></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                endHtml: "<p><em><u><strong>|Hello </strong></u></em><u><strong>wo|</strong></u><strong>rld</strong></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic <p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                startHtml: "<p><em><strong>|Hello </strong></em><strong>wo|rld</strong></p>",
                endHtml: "<p><strong>|Hello wo|rld</strong></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold <p>|Hello <em>world|</em></p>",
                startHtml: "<p>|Hello <em>world|</em></p>",
                endHtml: "<p><strong>|Hello </strong><em><strong>world|</strong></em></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline <p>|Hello <em>world|</em></p>",
                startHtml: "<p>|Hello <em>world|</em></p>",
                endHtml: "<p><u>|Hello </u><em><u>world|</u></em></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic <p>|Hello <em>world|</em></p>",
                startHtml: "<p>|Hello <em>world|</em></p>",
                endHtml: "<p>|Hello world|</p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold <p><u><strong>He|llo wo|rld</strong></u></p>",
                startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                endHtml: "<p><u><strong>He|</strong>llo wo|<strong>rld</strong></u></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline <p><u><strong>He|llo wo|rld</strong></u></p>",
                startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                endHtml: "<p><u><strong>He|</strong></u><strong>llo wo|</strong><u><strong>rld</strong></u></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic <p><u><strong>He|llo wo|rld</strong></u></p>",
                startHtml: "<p><u><strong>He|llo wo|rld</strong></u></p>",
                endHtml: "<p><u><strong>He|</strong></u><em><u><strong>llo wo|</strong></u></em><u><strong>rld</strong></u></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                endHtml: "<p>|Hello <em>world</em></p><p>Hello <em>wo|<strong>rld</strong></em></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                endHtml: "<p><u>|Hello </u><em><u>world</u></em></p><p><u><strong>Hello </strong></u><em><u><strong>wo|</strong></u><strong>rld</strong></em></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic across partial paragraphs <p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                startHtml: "<p>|Hello <em>world</em></p><p><strong>Hello </strong><em><strong>wo|rld</strong></em></p>",
                endHtml: "<p>|Hello world</p><p><strong>Hello wo|</strong><em><strong>rld</strong></em></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Bold across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                endHtml: "<p>|Hello <em>world</em></p><p>Hello <em>world|</em></p>",
                action: { handler in
                    self.webView.bold() { handler() }
                }
            ),
            HtmlTest(
                description: "Underline across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                endHtml: "<p><u><strong>|Hello </strong></u><em><u><strong>world</strong></u></em></p><p><u><strong>Hello </strong></u><em><u><strong>world|</strong></u></em></p>",
                action: { handler in
                    self.webView.underline() { handler() }
                }
            ),
            HtmlTest(
                description: "Italic across all-bolded paragraphs <p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                startHtml: "<p><strong>|Hello </strong><em><strong>world</strong></em></p><p><strong>Hello </strong><em><strong>world|</strong></em></p>",
                endHtml: "<p><strong>|Hello world</strong></p><p><strong>Hello world|</strong></p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
            HtmlTest(
                description: "Unset all italic across paragraphs <p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
                startHtml: "<p>This <em>is| italic</em></p><p><em>Ex|tending across</em> paragraphs</p>",
                endHtml: "<p>This <em>is|</em> italic</p><p>Ex|<em>tending across</em> paragraphs</p>",
                action: { handler in
                    self.webView.italic() { handler() }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to format across the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testFormatSelections() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Bold selection",
                startHtml: "<p>This <strong>i|s</strong> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.bold)
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Italic selection",
                startHtml: "<p>This <em>i|s</em> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.italic)
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Underline selection",
                startHtml: "<p>This <u>i|s</u> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.underline)
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Strikethrough selection",
                startHtml: "<p>This <s>i|s</s> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.strike)
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Superscript selection",
                startHtml: "<p>This <sup>i|s</sup> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.sup)
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Subscript selection",
                startHtml: "<p>This <sub>i|s</sub> a start</p>",
                action: { handler in
                    self.webView.getSelectionState() { selectionState in
                        XCTAssert(selectionState.sub)
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Format selection")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to determine the format of the selection
                test.action?() {
                    expectation.fulfill()
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testStyles() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Replace p with h1",
                startHtml: "<p><em><strong>He|llo </strong></em><strong>world</strong></p>",
                endHtml: "<h1><em><strong>He|llo </strong></em><strong>world</strong></h1>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace h2 with h6",
                startHtml: "<h2>|Hello worl|d</h2>",
                endHtml: "<h6>|Hello worl|d</h6>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace h3 with p",
                startHtml: "<h3>He|llo wor|ld</h3>",
                endHtml: "<p>He|llo wor|ld</p>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace p with code",
                startHtml: "<p>He|llo wor|ld</p>",
                endHtml: "<pre><code>He|llo wor|ld</code></pre>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .PRE) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Fail to replace p containing formatted text with code",
                startHtml: "<p>He<strong>llo| wor</strong>ld</p>",
                endHtml: "<p>He<strong>llo| wor</strong>ld</p>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .PRE) {
                            handler()
                        }
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to style at the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testMultiStyles() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Replace p with h1, selection in embedded format",
                startHtml: "<p><em><strong>He|llo </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>He|llo </strong></em><strong>world3</strong></p>",
                endHtml: "<h1><em><strong>He|llo </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>He|llo </strong></em><strong>world3</strong></h1>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace p with h1, selection outside embedded format both ends",
                startHtml: "<p><em><strong>|Hello </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>Hello </strong></em><strong>world3|</strong></p>",
                endHtml: "<h1><em><strong>|Hello </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>Hello </strong></em><strong>world3|</strong></h1>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace p with h1, selection outside embedded format at start",
                startHtml: "<p><em><strong>|Hello </strong></em><strong>world1</strong></p><p><em><strong>Hello </strong></em><strong>world2</strong></p><p><em><strong>Hello </strong></em><strong>wo|rld3</strong></p>",
                endHtml: "<h1><em><strong>|Hello </strong></em><strong>world1</strong></h1><h1><em><strong>Hello </strong></em><strong>world2</strong></h1><h1><em><strong>Hello </strong></em><strong>wo|rld3</strong></h1>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            HtmlTest(
                description: "Replace p with h1, selection across indented paragraphs",
                startHtml: "<blockquote><p>Pa|ragraph 1</p></blockquote><blockquote><p>Paragraph 2</p></blockquote><blockquote><p>Pa|ragraph 3</p></blockquote>",
                endHtml: "<blockquote><h1>Pa|ragraph 1</h1></blockquote><blockquote><h1>Paragraph 2</h1></blockquote><blockquote><h1>Pa|ragraph 3</h1></blockquote>",
                action: { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles across multiple paragraphs")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to style across the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }

    func testDenting() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Indent, selection in text element",
                startHtml: "<p>He|llo <strong>world</strong></p>",
                endHtml: "<blockquote><p>He|llo <strong>world</strong></p></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent, selection in a formatted element",
                startHtml: "<p><em><strong>He|llo </strong></em><strong>world</strong></p>",
                endHtml: "<blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent from 1 to 0, selection in nested format",
                startHtml: "<blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                endHtml: "<p><em><strong>He|llo </strong></em><strong>world</strong></p>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent from 2 to 1, selection in nested format",
                startHtml: "<blockquote><blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote></blockquote>",
                endHtml: "<blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent in an embedded paragraph in a blockquote, selection in a non-text element",
                startHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote>",
                endHtml: "<blockquote><p><em><strong>Hello </strong></em><strong>world</strong></p><blockquote><p><em><strong>He|llo </strong></em><strong>world</strong></p></blockquote></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to indent/outdent at the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testMultiDenting() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Indent <p>He|llo world1</p><p>He|llo world2</p>",
                startHtml: "<p>He|llo world1</p><p>He|llo world2</p>",
                endHtml: "<blockquote><p>He|llo world1</p><p>He|llo world2</p></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op <blockquote><p>He|llo world1</p></blockquote><blockquote><p>He|llo world2</p></blockquote>",
                startHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><p>He|llo world2</p></blockquote>",
                endHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><p>He|llo world2</p></blockquote>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent <p>He|llo world1</p><h5>He|llo world2</h5>",
                startHtml: "<p>He|llo world1</p><h5>He|llo world2</h5>",
                endHtml: "<blockquote><p>He|llo world1</p><h5>He|llo world2</h5></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op <blockquote><p>He|llo world1</p></blockquote><blockquote><h5>He|llo world2</h5></blockquote>",
                startHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><h5>He|llo world2</h5></blockquote>",
                endHtml: "<blockquote><p>He|llo world1</p></blockquote><blockquote><h5>He|llo world2</h5></blockquote>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                endHtml: "<blockquote><p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></blockquote>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op <blockquote><p>He|llo paragraph</p></blockquote><ul><li><h5>He|llo header in list</h5></li></ul>",
                startHtml: "<blockquote><p>He|llo paragraph</p></blockquote><ul><li><h5>He|llo header in list</h5></li></ul>",
                endHtml: "<blockquote><p>He|llo paragraph</p></blockquote><ul><li><h5>He|llo header in list</h5></li></ul>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent no-op <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                endHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.<p></li></ol></li></ul>",
                startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ul>",
                endHtml: "<h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent interleaved paragraphs and lists",
                startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                endHtml: "<blockquote><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p></blockquote><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op interleaved paragraphs and lists",
                startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                endHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Indent no-op list with sublists",
                startHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                endHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                action: { handler in
                    self.webView.indent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op list with sublists",
                startHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                endHtml: "<ul><li><h5>Un|ordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>Wi|th two items.</h5></li></ul>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent no-op, start and end in styles surround list",
                startHtml: "<p>St|arting paragraph.</p><ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul><p>En|ding paragraph.</p>",
                endHtml: "<p>St|arting paragraph.</p><ul><li><h5>Unordered list.</h5><ol><li><p>Ordered sublist.</p></li><li><p>With two items.</p></li></ol></li><li><h5>With two items.</h5></li></ul><p>En|ding paragraph.</p>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Indent/outdent operations with selections spanning multiple elements")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                // Execute the action to indent/outdent at the selection
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    // TODO: The blockQuoteEnter tests are really not right in ProseMirror, even if I wanted to
    //          invent a way to invoke the operation for test purposes. For example, Enter at the
    //          beginning of a paragraph in a blockquote used to insert another blockquote, but now
    //          it just adds a paragraph inside of the existing blockquote, which is clearly correct.
    //          Not that the previous behavior was wrong, but it would cause the outdent operation to
    //          only apply to one of the quotes.
    func testBlockquoteEnter() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Enter at beginning of simple paragraph in blockquote",
                startHtml: "<blockquote><p>|This is a simple paragraph</p></blockquote>",
                endHtml: "<blockquote><p></p></blockquote><blockquote><p>|This is a simple paragraph</p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in middle of simple paragraph in blockquote",
                startHtml: "<blockquote><p>This is a sim|ple paragraph</p></blockquote>",
                endHtml: "<blockquote><p>This is a sim|</p></blockquote><blockquote><p>ple paragraph</p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at end of simple paragraph in blockquote",
                startHtml: "<blockquote><p>This is a simple paragraph|</p></blockquote>",
                endHtml: "<blockquote><p>This is a simple paragraph|</p></blockquote><blockquote><p></p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at beginning of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>|This is a simple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>|</p></blockquote><blockquote><p>This is a simple paragraph</p></blockquote></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in middle of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a sim|ple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a sim|</p></blockquote><blockquote><p>ple paragraph</p></blockquote></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at end of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a simple paragraph|</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p>|</p></blockquote></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at end of empty paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p>This is a simple paragraph|</p></blockquote><blockquote><p></p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p>|</p></blockquote><blockquote><p></p></blockquote></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent on enter at end of empty paragraph in unnested blockquotes",
                startHtml: "<blockquote><p>This is a simple paragraph</p></blockquote><blockquote><p>|</p></blockquote>",
                endHtml: "<blockquote><p>This is a simple paragraph</p></blockquote><p>|</p>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            // We don't wait for images to load or fail, so we specify the class, tabindex, width, and height on
            // input so we get the same thing back.
            HtmlTest(
                description: "Enter before image in blockquote",
                startHtml: "<blockquote><p>|<img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p>|</p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter after image in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\">|</p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p>|</p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter between images in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\">|<img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p>|<img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter between text and image in blockquote",
                startHtml: "<blockquote><p>Hello|<img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p>Hello</p></blockquote><blockquote><p>|<img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter between image and text in blockquote",
                startHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\">|Hello</p></blockquote>",
                endHtml: "<blockquote><p><img src=\"steve.png\" alt=\"Local image\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p>|Hello</p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at end of text in formatted element",
                startHtml: "<blockquote><p><strong>Hello|</strong></p></blockquote>",
                endHtml: "<blockquote><p><strong>Hello</strong></p></blockquote><blockquote><p><strong>|</strong></p></blockquote>",
                action: { handler in
                    self.webView.testBlockquoteEnter {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed inside of blockquotes")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }

    func testLists() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Make a paragraph into an ordered list",
                startHtml: "<p>He|llo <strong>world</strong></p>",
                endHtml: "<ol><li><p>He|llo <strong>world</strong></p></li></ol>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Make a paragraph into an unordered list",
                startHtml: "<p>He|llo <strong>world</strong></p>",
                endHtml: "<ul><li><p>He|llo <strong>world</strong></p></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                startHtml: "<ul><li><p>He|llo <strong>world</strong></p></li></ul>",
                endHtml: "<p>He|llo <strong>world</strong></p>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                startHtml: "<ol><li><p>He|llo <strong>world</strong></p></li></ol>",
                endHtml: "<p>He|llo <strong>world</strong></p>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                startHtml: "<ul><li><p>Hello <strong>wo|rld1</strong></p></li><li><p>Hello <strong>world2</strong></p></li></ul>",
                endHtml: "<p>Hello <strong>wo|rld1</strong></p><ul><li><p>Hello <strong>world2</strong></p></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Try but fail to change the top list item in a multi-element list to a different list type",
                startHtml: "<ul><li><p>Hello <strong>wo|rld1</strong></p></li><li><p>Hello <strong>world2</strong></p></li></ul>",
                endHtml: "<ul><li><p>Hello <strong>wo|rld1</strong></p></li><li><p>Hello <strong>world2</strong></p></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Change a sub list item in a multi-element list to a different list item",
                startHtml: "<ul><li><p>Hello <strong>world1</strong></p></li><li><p>Hel|lo <strong>world2</strong></p></li></ul>",
                endHtml: "<ul><li><p>Hello <strong>world1</strong></p><ol><li><p>Hel|lo <strong>world2</strong></p></li></ol></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove UL <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                startHtml: "<ul><li><p>AAHe|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                endHtml: "<p>AAHe|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                startHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                endHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Outdent <ul><li><p>Hello paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                startHtml: "<ul><li><p>Hello paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                endHtml: "<ul><li><p>Hello paragraph</p><h5>He|llo header in list</h5></li></ul>",
                action: { handler in
                    self.webView.outdent() {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: test.undoHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testMultiLists() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "UL <p>He|llo world1</p><p>He|llo world2</p>",
                startHtml: "<p>He|llo world1</p><p>He|llo world2</p>",
                endHtml: "<ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove UL <ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                startHtml: "<ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                endHtml: "<p>He|llo world1</p><p>He|llo world2</p>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "UL <p>He|llo world1</p><h5>He|llo world2</h5>",
                startHtml: "<p>He|llo world1</p><h5>He|llo world2</h5>",
                endHtml: "<ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove UL <ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                startHtml: "<ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                endHtml: "<p>He|llo world1</p><h5>He|llo world2</h5>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            //TODO: Fix so it's not a no-op
            HtmlTest(
                description: "No-op UL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                endHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                //endHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            //TODO: Fix so it's not a no-op
            HtmlTest(
                description: "No-op Remove UL <ul><li><p>He|llo paragraph</p></li><ul><li><h5>He|llo header in list</h5></li></ul></ul>",
                startHtml: "<ul><li><p>He|llo paragraph</p></li><ul><li><h5>He|llo header in list</h5></li></ul></ul>",
                endHtml: "<ul><li><p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "OL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                startHtml: "<p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                endHtml: "<ol><li><p>He|llo paragraph</p><ol><li><h5>He|llo header in list</h5></li></ol></li></ol>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            /*
            HtmlTest(
                description: "Remove OL <ol><li><p>He|llo paragraph</p></li><ol><li><h5>He|llo header in list</h5></li></ol></ol>",
                startHtml: "<ol><li><p>He|llo paragraph</p></li><ol><li><h5>He|llo header in list</h5></li></ol></ol>",
                endHtml: "<p>He|llo paragraph</p><h5>He|llo header in list</h5>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "UL <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                endHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ul><li>Or|dered sublist.</li></ul></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove UL <ul><li><h5>Unordered <em>H5</em> list.</h5><ul><li><p>Unordered sublist.</p></li></ul></li></ul>",
                startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ul><li><p>Un|ordered sublist.</p></li></ul></li></ul>",
                endHtml: "<h5>Un|ordered <em>H5</em> list.</h5><p>Un|ordered sublist.</p>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "OL <ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                startHtml: "<ul><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                endHtml: "<ol><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ol>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Remove OL <ol><li><h5>Unordered <em>H5</em> list.</h5><ol><li><p>Ordered sublist.</p></li></ol></li></ol>",
                startHtml: "<ol><li><h5>Un|ordered <em>H5</em> list.</h5><ol><li><p>Or|dered sublist.</p></li></ol></li></ol>",
                endHtml: "<h5>Un|ordered <em>H5</em> list.</h5><p>Or|dered sublist.</p>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "UL interleaved paragraphs and lists",
                startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                endHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Unset all UL interleaved paragraphs and lists",
                startHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                endHtml: "<p>To|p-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>To|p-level paragraph 2</p><p>Ordered list paragraph 1</p>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Set all OL lists and sublists",
                startHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                endHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "OL interleaved paragraphs and lists",
                startHtml: "<p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol>",
                endHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Unset all OL interleaved paragraphs and lists",
                startHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                endHtml: "<p>To|p-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>To|p-level paragraph 2</p><p>Ordered list paragraph 1</p>",
                action: { handler in
                    self.webView.toggleListItem(type: .OL) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Set all UL lists and sublists",
                startHtml: "<ol><li><p>To|p-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>To|p-level paragraph 2</p><ol><li><p>Ordered list paragraph 1</p></li></ol></li></ol>",
                endHtml: "<ul><li><p>To|p-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>To|p-level paragraph 2</p><ul><li><p>Ordered list paragraph 1</p></li></ul></li></ul>",
                action: { handler in
                    self.webView.toggleListItem(type: .UL) {
                        handler()
                    }
                }
            ),
             */
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "List operations with selections spanning multiple elements")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testListEnterCollapsed() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Enter at end of h5",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.|</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5></li><li><p>|</p><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter at beginning of h5",
                startHtml: "<ul><li><h5>|Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5></h5></li><li><h5>|Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in \"Bul|leted item 1.\"",
                startHtml: "<ul><li><h5>Bul|leted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bul</h5></li><li><h5>|leted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in \"Bulleted item 1|.\"",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1|.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1</h5></li><li><h5>|.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                startHtml: "<ul><li><h5>Bulleted <em>it|em</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>it</em></h5></li><li><h5><em>|em</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            /*
            TODO: Fix the test, which does not properly replicate actual Enter at the end of a list,
            //      even though it works properly when done by hand.
            HtmlTest(
                description: "Enter in empty p list item at end of list.",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><p>|</p></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li></ul><p>|</p>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Enter in empty h5 list item at end of list.",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li><li><h5>|</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>Numbered item 1.</p></li><li><p>Numbered item 2.</p></li></ol></li></ul><h5>|</h5>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            */
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed in a list with various collapsed selections")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testListEnterRange() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Word in single list item",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered |item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P </p></li><li><p>|item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Part of a formatted item in a list item",
                startHtml: "<ul><li><h5>Bulleted <em>i|te|m</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>i</em></h5></li><li><h5><em>|m</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "The entire formatted item in a list item",
                startHtml: "<ul><li><h5>Bulleted |<em>item|</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted </h5></li><li><h5>| 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            /*
             TODO: Doesn't work like it should in test, but does fine in editor
            HtmlTest(
                description: "Begin selection in one list item, end in another",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P |Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P |Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P </p><p>|Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Begin selection at start of one list item, end in another",
                startHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>|P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>|P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bulleted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>|P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Numbered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Begin selection in a bulleted list item, end in an ordered one",
                startHtml: "<ul><li><h5>Bul|leted <em>item</em> 1.</h5><ol><li><p>P Numbered item 1.</p></li><li><p>P Numbered item 2.</p></li><li><p>P Numbered item 3.</p></li><li><p>P Numbered item 4.</p></li><li><p>Numbered item 5.</p></li><li><p>Numbered item 6.</p></li><li><p>Num|bered item 7.</p></li><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                endHtml: "<ul><li><h5>Bul</h5><h5>bered item 7.</h5><ol><li><p>Numbered item 8.</p></li></ol></li><li><h5>Bulleted item 2.</h5></li></ul>",
                action: { handler in
                    self.webView.testListEnter {
                        handler()
                    }
                }
            ),
            */
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Enter being pressed in a list with various range selections")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testInsertTable() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Insert at beginning of a paragraph",
                startHtml: "<p>|This is a simple paragraph</p>",
                endHtml: "<table><tr><td><p>|</p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>This is a simple paragraph</p>",
                action: { handler in
                    self.webView.insertTable(rows: 2, cols: 2) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Insert in the middle of a paragraph",
                startHtml: "<p>This is a sim|ple paragraph</p>",
                endHtml: "<p>This is a sim</p><table><tr><td><p>|</p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table><p>ple paragraph</p>",
                action: { handler in
                    self.webView.insertTable(rows: 2, cols: 2) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Insert at the end of a paragraph",
                startHtml: "<p>This is a simple paragraph|</p>",
                endHtml: "<p>This is a simple paragraph</p><table><tr><td><p>|</p></td><td><p></p></td></tr><tr><td><p></p></td><td><p></p></td></tr></table>",
                action: { handler in
                    self.webView.insertTable(rows: 2, cols: 2) {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Insert a table")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testTableActions() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Delete row",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p>|Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.deleteRow() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Delete col",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p>|Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.deleteCol() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Delete table",
                startHtml: "<p>Hello</p><table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>world</p>",
                endHtml: "<p>Hello</p><p>|world</p>",
                action: { handler in
                    self.webView.deleteTable() {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Add row above",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p></p></td><td><p></p></td></tr><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.addRow(.before) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Add row below",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p></p></td><td><p></p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.addRow(.after) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Add col before",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p></p></td><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p></p></td><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.addCol(.before) {
                        handler()
                    }
                }
            ),
            HtmlTest(
                description: "Add col after",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p></p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p></p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.addCol(.after) {
                        handler()
                    }
                }
            ),
            //TODO: The selection is wrong after undo, undoHtml should not be set here
            HtmlTest(
                description: "Add header",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                endHtml: "<table><tr><th colspan=\"2\"><p></p></th></tr><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                undoHtml: "<table><tr><td><p>|Row 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table><p>Hello</p>",
                action: { handler in
                    self.webView.addHeader() {
                        handler()
                    }
                }
            ),
            //TODO: Undo isn't working, undoHtml should not be set here
            HtmlTest(
                description: "Set cell border",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                endHtml: "<table class=\"bordered-table-cell\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                undoHtml: "<table class=\"bordered-table-cell\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                action: { handler in
                    self.webView.borderTable(.cell) {
                        handler()
                    }
                }
            ),
            //TODO: Undo isn't working, undoHtml should not be set here
            HtmlTest(
                description: "Set header border",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                endHtml: "<table class=\"bordered-table-header\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                undoHtml: "<table class=\"bordered-table-header\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                action: { handler in
                    self.webView.borderTable(.header) {
                        handler()
                    }
                }
            ),
            //TODO: Undo isn't working, undoHtml should not be set here
            HtmlTest(
                description: "Set outer border",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                endHtml: "<table class=\"bordered-table-outer\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                undoHtml: "<table class=\"bordered-table-outer\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                action: { handler in
                    self.webView.borderTable(.outer) {
                        handler()
                    }
                }
            ),
            //TODO: Undo isn't working, undoHtml should not be set here
            HtmlTest(
                description: "Set no border",
                startHtml: "<table><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                endHtml: "<table class=\"bordered-table-none\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                undoHtml: "<table class=\"bordered-table-none\"><tr><td><p>Row| 0, Col 0</p></td><td><p>Row 0, Col 1</p></td></tr><tr><td><p>Row 1, Col 0</p></td><td><p>Row 1, Col 1</p></td></tr></table>",
                action: { handler in
                    self.webView.borderTable(.none) {
                        handler()
                    }
                }
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Perform actions on a table")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                test.action?() {
                    self.webView.getTestHtml { formatted in
                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: test.undoHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting.
    ///
    /// Text that comes in via the pasteboard contains a "proper" HTML document, including meta tags and extensive
    /// styling to capture the state from the source document. The MarkupEditor strictly controls the styling and other
    /// content of the document it works on, so much of this content needs to be stripped from the incoming HTML
    /// before pasting. By testing the preprocessing itself, the tests for HTML paste (and the corresponding text paste)
    /// can be done using "clean" strings.
    func testPasteHtmlPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5>This is just a simple paragraph.</h5>",
                endHtml: "<h5>This is just a simple paragraph.</h5>"
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<h1><strong>Welcome to the MarkupEditor Demo</strong></h1><p><br></p>"
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p>These are angle brackets: < and >.</p>",
                endHtml: "<p>These are angle brackets: &lt; and &gt;.</p>"
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>"
            ),
            HtmlTest(
                // From https://stackoverflow.com/a/50547246/8968411
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml:
                    """
                    <p><strong>List of One Liners</strong></p><p>Let's solve this problem for this array:</p><pre><code>var array = ['A', 'B', 'C'];
                    </code></pre><p><strong>1. Remove only the first:</strong>&nbsp;Use If you are sure that the item exist</p><pre><code>array.splice(array.indexOf('B'), 1);
                    </code></pre><p><strong>2. Remove only the last:</strong>&nbsp;Use If you are sure that the item exist</p><pre><code>array.splice(array.lastIndexOf('B'), 1);
                    </code></pre><p><strong>3. Remove all occurrences:</strong></p><pre><code>array = array.filter(v =&gt; v !== 'B'); </code></pre>
                    """
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>"
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>"
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml:
                    """
                    <p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a <a href="http://foo.com">link</a>.</p><p><br></p><ul><li><p>A checklist</p></li></ul><ul><li><p>With a checked item</p></li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li><p>A numbered list</p></li><li><p>With two items</p><ol><li><p>One of which has a subitem</p></li></ol></li></ol><p><br></p><ul><li><p>A bulleted list</p></li><li><p>With two items</p><ul><li><p>One of which has a subitem</p></li></ul></li></ul><p><br></p><table class="t1"><tr><td><p>A table</p></td><td><p>With two columns</p></td></tr><tr><td><p>And two rows</p></td><td><p>😜</p></td></tr></table><p>And here is an image…</p><p><br></p><p><img src="file:///Pasted%20Graphic.png" alt="Pasted Graphic.png"></p>
                    """
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Cleaning up html we get from the paste buffer")
            self.webView.testPasteHtmlPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testPasteHtml() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello world|st a simple paragraph.</p>",
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello &lt;b&gt;bold&lt;/b&gt; world|st a simple paragraph.</p>",
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello <strong>bold</strong> world|st a simple paragraph.</p>",
                pasteString: "Hello <strong>bold</strong> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello <em>bold</em> world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "Hello <em>bold</em> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello world|st a simple paragraph.</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello <strong>bold</strong> world|st a simple paragraph.</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello <em>bold</em> world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "<p>Hello <em>bold</em> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<p>Hello world|This is just a simple paragraph.</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<p>Hello <strong>bold</strong> world|This is just a simple paragraph.</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Hello <strong>bold</strong> world|</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello <strong>bold</strong> world|</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><h5>Hello world|</h5>",
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><h5>Hello <strong>bold</strong> world|</h5>",
                pasteString: "<h5>Hello <strong>bold</strong> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p>|</p>",
                endHtml: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.|</p>",
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
            // Tables
            HtmlTest(
                description: "TABLE in P - Paste a table at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><table><tr><td><p>The table body</p></td><td><p>with two columns|</p></td></tr></table>",
                pasteString: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table at beginning of a paragraph",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table><p>|This is just a simple paragraph.</p>",
                pasteString: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><table><tr><td><p>The table body</p></td><td><p>with two columns|</p></td></tr></table>",
                pasteString: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table in text of a paragraph",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is ju</p><table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table><p>|st a simple paragraph.</p>",
                pasteString: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table>"
            ),
            HtmlTest(
                description: "TABLE in P - Paste a table in formatted text of a paragraph",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong></p><table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table><p><strong>|st</strong> a simple paragraph.</p>",
                pasteString: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a table",
                startHtml: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table><p>|</p>",
                endHtml: "<table><tr><td><p>The table body</p></td><td><p>with two columns</p></td></tr></table><p>Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            // Lists
            HtmlTest(
                description: "OL in P - Paste a list at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><ol><li><p>Item 1</p></li><li><p>Item 2|</p></li></ol>",
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list at beginning of a paragraph",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2|This is just a simple paragraph.</p></li></ol>",
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Item 1</p><ol><li><p>Item 2|</p></li></ol>",
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list in text of a paragraph",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juItem 1</p><ol><li><p>Item 2|st a simple paragraph.</p></li></ol>",
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "OL in P - Paste a list in formatted text of a paragraph",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Item 1</p><ol><li><p>Item 2|<strong>st</strong> a simple paragraph.</p></li></ol>",
                pasteString: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a list",
                startHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p>|</p>",
                endHtml: "<ol><li><p>Item 1</p></li><li><p>Item 2</p></li></ol><p>Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            // Blockquotes
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><blockquote><blockquote><h5>Double-indented.|</h5></blockquote></blockquote>",
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at beginning of a paragraph",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<blockquote><blockquote><h5>Double-indented.|This is just a simple paragraph.</h5></blockquote></blockquote>",
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE at end of a paragraph",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Double-indented.|</p>",
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE in text of a paragraph",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juDouble-indented.|st a simple paragraph.</p>",
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "BLOCKQUOTE in P - Paste a BLOCKQUOTE in formatted text of a paragraph",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Double-indented.|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote>"
            ),
            HtmlTest(
                description: "P in P - Paste a simple paragraph at a blank line after a BLOCKQUOTE",
                startHtml: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p>|</p>",
                endHtml: "<blockquote><blockquote><h5>Double-indented.</h5></blockquote></blockquote><p>Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                self.webView.pasteHtml(test.pasteString) {
                    self.webView.getTestHtml() { pasted in
                        self.assertEqualStrings(expected: endHtml, saw: pasted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting text (aka "Paste and Match Style").
    ///
    /// See comments in the `testPasteHtmlPreprocessing` method.
    ///
    /// The "pasteText" function (via the "Paste and Match Style" edit menu) pastes the MarkupEditor
    /// equivalent of plain text. To do that, it uses <p> for all styling and removes all formatting (e.g., <strong>, <em>, etc).
    /// The text preprocessing does the same preprocessing as the HTML preprocessing, plus this additional
    /// style and format removal, along with link removal.
    func testPasteTextPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5>This is just a simple paragraph.</h5>",
                endHtml: "<p>This is just a simple paragraph.</p>"
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<p>Welcome to the MarkupEditor Demo</p><p><br></p>"
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p>These are angle brackets: < and >.</p>",
                endHtml: "<p>These are angle brackets: &lt; and &gt;.</p>"
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>"
            ),
            HtmlTest(
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml:
                    """
                    <p>List of One Liners</p><p>Let's solve this problem for this array:</p><p>var array = ['A', 'B', 'C'];
                    </p><p>1. Remove only the first:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.indexOf('B'), 1);
                    </p><p>2. Remove only the last:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.lastIndexOf('B'), 1);
                    </p><p>3. Remove all occurrences:</p><p>array = array.filter(v =&gt; v !== 'B'); </p>
                    """
            ),
            HtmlTest(
                description: "Clean up some text from Xcode",
                startHtml: "const _pasteHTML = function(html, oldUndoerData, undoable=true) {\n    const redoing = !undoable && (oldUndoerData !== null);\n    let sel = document.getSelection();\n    let anchorNode = (sel) ? sel.anchorNode : null;\n    if (!anchorNode) {\n        MUError.NoSelection.callback();\n        return null;\n    };",
                endHtml: "<p>const _pasteHTML = function(html, oldUndoerData, undoable=true) { const redoing = !undoable &amp;&amp; (oldUndoerData !== null); let sel = document.getSelection(); let anchorNode = (sel) ? sel.anchorNode : null; if (!anchorNode) { MUError.NoSelection.callback(); return null; };</p>"
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>"
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>"
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml:
                    """
                    <p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a link.</p><p><br></p><ul><li><p>A checklist</p></li></ul><ul><li><p>With a checked item</p></li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li><p>A numbered list</p></li><li><p>With two items</p><ol><li><p>One of which has a subitem</p></li></ol></li></ol><p><br></p><ul><li><p>A bulleted list</p></li><li><p>With two items</p><ul><li><p>One of which has a subitem</p></li></ul></li></ul><p><br></p><table class="t1"><tr><td><p>A table</p></td><td><p>With two columns</p></td></tr><tr><td><p>And two rows</p></td><td><p>😜</p></td></tr></table><p>And here is an image…</p><p><br></p><p><img src="file:///Pasted%20Graphic.png" alt="Pasted Graphic.png"></p>
                    """
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Get \"unformatted text\" from the paste buffer")
            self.webView.testPasteTextPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testPasteText() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello world|st a simple paragraph.</p>",
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello &lt;b&gt;bold&lt;/b&gt; world|st a simple paragraph.</p>",
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello bold world|st a simple paragraph.</p>",
                pasteString: "Hello <strong>bold</strong> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello bold world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "Hello <em>bold</em> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello world|st a simple paragraph.</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is juHello bold world|st a simple paragraph.</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p>This is <strong>ju|st</strong> a simple paragraph.</p>",
                endHtml: "<p>This is <strong>ju</strong>Hello bold world|<strong>st</strong> a simple paragraph.</p>",
                pasteString: "<p>Hello <em>bold</em> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<p>Hello world|This is just a simple paragraph.</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<p>Hello bold world|This is just a simple paragraph.</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.Hello bold world|</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world|</p>",
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello bold world|</p>",
                pasteString: "<p>Hello <strong>bold</strong> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello world|</p>",
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p>This is just a simple paragraph.</p><p>|</p>",
                endHtml: "<p>This is just a simple paragraph.</p><p>Hello bold world|</p>",
                pasteString: "<h5>Hello <strong>bold</strong> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p>|</p>",
                endHtml: "<p>A title</p><p>A subtitle</p><p>A paragraph.|</p>",
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                self.webView.pasteText(test.pasteString) {
                    self.webView.getTestHtml() { pasted in
                        self.assertEqualStrings(expected: endHtml, saw: pasted)
                        self.webView.undo {
                            self.webView.getTestHtml { formatted in
                                self.assertEqualStrings(expected: startHtml, saw: formatted)
                                self.webView.redo {
                                    self.webView.getTestHtml { formatted in
                                        self.assertEqualStrings(expected: endHtml, saw: formatted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testPasteImage() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Image in P - Paste image at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>"
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                self.webView.pasteImage(UIImage(systemName: "calendar")) {
                    self.webView.getTestHtml() { pasted in
                        if let imageFileName = self.imageFilename(in: pasted) {
                            XCTAssertTrue(self.webView.resourceExists(imageFileName))
                            self.webView.undo {
                                self.webView.getTestHtml { pasted in
                                    self.assertEqualStrings(expected: startHtml, saw: pasted)
                                    self.webView.redo {
                                        self.webView.getTestHtml { pasted in
                                            XCTAssertTrue(self.webView.resourceExists(imageFileName))
                                            expectation.fulfill()
                                        }
                                    }
                                }
                            }
                        } else {
                            XCTFail("The pasted HTML was not returned properly.")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testPasteImageUrl() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "MP4 URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.mp4\">|st a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.mp4"
            ),
            HtmlTest(
                description: "JPG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.jpg\">|st a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.jpg"
            ),
            HtmlTest(
                description: "PNG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p>This is ju|st a simple paragraph.</p>",
                endHtml: "<p>This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.png\">|st a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.png"
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image URL")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                    self.webView.getTestHtml() { pasted in
                        self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                        self.webView.undo {
                            self.webView.getTestHtml { pasted in
                                self.assertEqualStrings(expected: startHtml, saw: pasted)
                                self.webView.redo {
                                    self.webView.getTestHtml { pasted in
                                        self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    func testPasteLink() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Link in P - Paste link at a fully-selected word",
                startHtml: "<p>This is |just| a simple paragraph.</p>",
                endHtml: "<p>This is |<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">just</a>| a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of a word",
                startHtml: "<p>This is just| a simple paragraph.</p>",
                endHtml: "<p>This is just|<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>| a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of a word",
                startHtml: "<p>This is |just a simple paragraph.</p>",
                endHtml: "<p>This is |<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>|just a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of paragraph",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "<p>|<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>|This is just a simple paragraph.</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of paragraph",
                startHtml: "<p>This is just a simple paragraph.|</p>",
                endHtml: "<p>This is just a simple paragraph.|<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>|</p>",
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste a link")
            webView.setTestHtml(startHtml) { contents in
                self.assertEqualStrings(expected: startHtml, saw: contents)
                self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                    self.webView.getTestHtml() { pasted in
                        self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                        self.webView.undo {
                            self.webView.getTestHtml { pasted in
                                self.assertEqualStrings(expected: startHtml, saw: pasted)
                                self.webView.redo {
                                    self.webView.getTestHtml { pasted in
                                        self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                        expectation.fulfill()
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }
    
    // Repurpose the endHtml, undoHtml, and pasteString state in HtmlTest as commented below for search tests
    func testSearch() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Exact word match",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "just",        // Search forward result
                undoHtml: "just",       // Search backward result
                pasteString: "just"     // Search for
            ),
            HtmlTest(
                description: "Partial word match",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "us",          // Search forward result
                undoHtml: "us",         // Search backward result
                pasteString: "us"       // Search for
            ),
            HtmlTest(
                description: "Mixed case word match",
                startHtml: "<p>|This is just a SiMpLe paragraph.</p>",
                endHtml: "SiMpLe",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                pasteString: "simple"   // Search for
            ),
            HtmlTest(
                description: "Mixed case search for lowercase word",
                startHtml: "<p>|This is just a simple paragraph.</p>",
                endHtml: "simple",      // Search forward result
                undoHtml: "simple",     // Search backward result
                pasteString: "SiMpLe"   // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe",
                startHtml: "<p>This isn't just a simple paragraph.</p>",
                endHtml: "isn't",       // Search forward result
                undoHtml: "isn't",      // Search backward result
                pasteString: "isn't"     // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe and quotes",
                startHtml: "<p>|This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                pasteString: "isn't just a \"simple\""      // Search for
            ),
            HtmlTest(
                description: "Search with smart quotes",
                startHtml: "<p>|This isn't just a \"simple\" paragraph.</p>",
                endHtml: "\"simple\"",          // Search forward result
                undoHtml: "\"simple\"",         // Search backward result
                pasteString: "“simple”"         // Search for
            ),
            HtmlTest(
                description: "Search with smart apostrophe",
                startHtml: "<p>|This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't",               // Search forward result
                undoHtml: "isn't",              // Search backward result
                pasteString: "isn’t"            // Search for
            ),
            HtmlTest(
                description: "Search with mixed smart apostrophe and quotes",
                startHtml: "<p>|This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                pasteString: "isn’t just a “simple”"        // Search for
            ),
            HtmlTest(
                description: "Search relative to selection",
                startHtml: "<p>This is just a SiMpLe word| in a sImPlE paragraph.</p>",
                endHtml: "sImPlE",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                pasteString: "simple"   // Search for
            ),
        ]
        wait(for: [loadedExpectation], timeout: 10)
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let searchString = test.pasteString ?? ""
            let expectation = XCTestExpectation(description: "Search forward and backward")
            webView.setTestHtml(startHtml) { contents in
                // Because of smart quote processing being tested here, startHtml can be
                // different than contents. So, we skip that assertion, which is really just
                // there as an early warning if something goes wrong.
                self.webView.search(for: searchString, direction: .forward) {
                    self.webView.getSelectionState() { state in
                        XCTAssertTrue(state.selection == test.endHtml)   // Selection extends beyond word!
                        self.webView.setTestHtml(startHtml) { contents in
                            self.webView.search(for: searchString, direction: .backward) {
                                self.webView.getSelectionState() { state in
                                    XCTAssertTrue(state.selection == test.undoHtml)
                                    expectation.fulfill()
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 10)
        }
    }

}

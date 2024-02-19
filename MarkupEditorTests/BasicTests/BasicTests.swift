//
//  MarkupEditorTests.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 3/5/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import XCTest
// import SharedTest    <- Needed for "swift test" but breaks "xcodebuild test"
import MarkupEditor
import OSLog

class BasicTests: XCTestCase, MarkupDelegate {
    var webView: MarkupWKWebView!
    var coordinator: MarkupCoordinator!
    var loadedExpectation: XCTestExpectation = XCTestExpectation(description: "Loaded")
    var undoSetHandler: (()->Void)?
    var inputHandler: (()->Void)?
    
    override func setUpWithError() throws {
        continueAfterFailure = false
        webView = MarkupWKWebView(markupDelegate: self)
        coordinator = MarkupCoordinator(markupDelegate: self, webView: webView)
        // The coordinator will receive callbacks from markup.js
        // using window.webkit.messageHandlers.test.postMessage(<message>);
        webView.configuration.userContentController.add(coordinator, name: "markup")
        // Not sure what happened with XCTest, but somewhere along Xcode upgrades this initial
        // loading *in testing only, not in real life usage* takes a very long time.
        wait(for: [loadedExpectation], timeout: 30)
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
    
    /// Use the inputHandlers in order, removing them as we use them
    func markupUndoSet(_ view: MarkupWKWebView) {
        guard let undoSetHandler = undoSetHandler else {
            return
        }
        //print("*** handling undoSet")
        undoSetHandler()
        self.undoSetHandler = nil
    }
    
    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func assertEqualStrings(expected: String, saw: String?) {
        XCTAssert(expected == saw, "Expected \(expected), saw: \(saw ?? "nil")")
    }
    
    func addInputHandler(_ handler: @escaping (()->Void)) {
        inputHandler = handler
    }
    
    func addUndoSetHandler(_ handler: @escaping (()->Void)) {
        undoSetHandler = handler
    }
    
    func testLoad() throws {
        Logger.test.info("Test: Ensure loadInitialHtml has run.")
        // Do nothing other than run setupWithError
    }
    
    func testBaselineBehavior() throws {
        Logger.test.info("Test: Ensure baseline behaviors are correct.")
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Extract when selection begins in one styled list item, ends in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P </p></li><li id=\"ol3\"><p>Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "P |Numbered item 1."
                    startOffset: 2,
                    endId: "ol3",       // Select "P |Numbered item 3."
                    endOffset: 2,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testExtractContents {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Basic operations")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testFormats() throws {
        // Select a range in a P styled string, apply a format to it
        for format in FormatContext.AllCases {
            var test = HtmlTest.forFormatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        test.description = "Set format to \(format.description)"
                        test.printDescription()
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testUnformats() throws {
        // Given a range of formatted text, toggle the format off
        for format in FormatContext.AllCases {
            var test = HtmlTest.forUnformatting("This is a start.", style: .P, format: format, startingAt: 5, endingAt: 7)
            let expectation = XCTestExpectation(description: "Format \(format.tag)")
            webView.setTestHtml(value: test.startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: test.startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        XCTAssert(result)
                        let formatFollowUp = {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: test.endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        test.description = "Unformat from \(format.description)"
                        test.printDescription()
                        switch format {
                        case .B:
                            self.webView.bold(handler: formatFollowUp)
                        case .I:
                            self.webView.italic(handler: formatFollowUp)
                        case .U:
                            self.webView.underline(handler: formatFollowUp)
                        case .STRIKE:
                            self.webView.strike(handler: formatFollowUp)
                        case .SUB:
                            self.webView.subscriptText(handler: formatFollowUp)
                        case .SUP:
                            self.webView.superscript(handler: formatFollowUp)
                        case .CODE:
                            self.webView.code(handler: formatFollowUp)
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testFormatSelections() throws {
        // Select a caret location in a formatted string and make sure getSelection identifies the format properly
        // This is important for the toolbar indication of formatting as the cursor selection changes
        for format in FormatContext.AllCases {
            let rawString = "This is a start."
            let formattedString = rawString.formattedHtml(adding: format, startingAt: 5, endingAt: 7, withId: format.tag)
            let startHtml = formattedString.styledHtml(adding: .P)
            let description = "Select inside of format \(format.tag)"
            Logger.test.info("\(description)")
            let expectation = XCTestExpectation(description: description)
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: format.tag, startOffset: 1, endId: format.tag, endOffset: 1) { result in
                        XCTAssert(result)
                        switch format {
                        case .B:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.bold)
                                expectation.fulfill()
                            }
                        case .I:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.italic)
                                expectation.fulfill()
                            }
                        case .U:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.underline)
                                expectation.fulfill()
                            }
                        case .STRIKE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.strike)
                                expectation.fulfill()
                            }
                        case .SUB:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sub)
                                expectation.fulfill()
                            }
                        case .SUP:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.sup)
                                expectation.fulfill()
                            }
                        case .CODE:
                            self.webView.getSelectionState() { selectionState in
                                XCTAssert(selectionState.code)
                                expectation.fulfill()
                            }
                        default:
                            XCTFail("Unknown format action: \(format)")
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiFormats() throws {
        // Inline comments show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Bold <p><b><u>Wo|rd 1</u><u> Word 2 </u><u>Wo|rd 3</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Word 1</u><u> Word 2 </u><u id=\"u3\">Word 3</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">Wo</u></b><u>rd 1</u><u> Word 2 </u><u id=\"u3\">Wo</u><b><u>rd 3</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline <p><b><u>Wo|rd 1</u><u> Word 2 </u><u>Wo|rd 3</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Word 1</u><u> Word 2 </u><u id=\"u3\">Word 3</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">Wo</u>rd 1 Word 2 Wo<u>rd 3</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic <p><b><u>Wo|rd 1</u><u> Word 2 </u><u>Wo|rd 3</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Word 1</u><u> Word 2 </u><u id=\"u3\">Word 3</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">Wo<i>rd 1</i></u><u><i> Word 2 </i></u><u id=\"u3\"><i>Wo</i>rd 3</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold <b>Hello <u id=\"u\">bold |and| underline</u> world</b>",
                    startHtml: "<p><b>Hello <u id=\"u\">bold and underline</u> world</b></p>",
                    endHtml: "<p><b>Hello <u id=\"u\">bold </u></b><u>and</u><b><u> underline</u> world</b></p>",
                    startId: "u",
                    startOffset: 5,
                    endId: "u",
                    endOffset: 8
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline <b>Hello <u id=\"u\">bold |and| underline</u> world</b>",
                    startHtml: "<p><b>Hello <u id=\"u\">bold and underline</u> world</b></p>",
                    endHtml: "<p><b>Hello <u id=\"u\">bold </u>and<u> underline</u> world</b></p>",
                    startId: "u",
                    startOffset: 5,
                    endId: "u",
                    endOffset: 8
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic <b>Hello <u id=\"u\">bold |and| underline</u> world</b>",
                    startHtml: "<p><b>Hello <u id=\"u\">bold and underline</u> world</b></p>",
                    endHtml: "<p><b>Hello <u id=\"u\">bold <i>and</i> underline</u> world</b></p>",
                    startId: "u",
                    startOffset: 5,
                    endId: "u",
                    endOffset: 8
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold <p><b><i>He|llo </i>wo|rld</b></p>",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">He</i></b><i>llo </i>wo<b>rld</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2,
                    endChildNodeIndex: 1
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline <p><b><i>He|llo </i>wo|rld</b></p>",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">He<u>llo </u></i><u>wo</u>rld</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2,
                    endChildNodeIndex: 1
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic <p><b><i>He|llo </i>wo|rld</b></p>",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i><i>wo</i>rld</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2,
                    endChildNodeIndex: 1
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold <p>|Hello <i>world|</i></p>",
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><b>Hello </b><i id=\"i\"><b>world</b></i></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline <p>|Hello <i>world|</i></p>",
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><u>Hello </u><i id=\"i\"><u>world</u></i></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic <p>|Hello <i>world|</i></p>",
                    startHtml: "<p id=\"p\">Hello <i id=\"i\">world</i></p>",
                    endHtml: "<p id=\"p\"><i>Hello </i><i id=\"i\">world</i></p>",
                    startId: "p",
                    startOffset: 0,
                    endId: "i",
                    endOffset: 5
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold <p><b><u>He|llo </u></b><b><u>wo|rld</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Hello </u></b><b><u id=\"u2\">world</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">He</u></b><u>llo </u><u id=\"u2\">wo</u><b><u>rld</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline <p><b><u>He|llo </u></b><b><u>wo|rld</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Hello </u></b><b><u id=\"u2\">world</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">He</u>llo </b><b>wo<u>rld</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic <p><b><u>He|llo </u></b><b><u>wo|rld</u></b></p>",
                    startHtml: "<p><b><u id=\"u1\">Hello </u></b><b><u id=\"u2\">world</u></b></p>",
                    endHtml: "<p><b><u id=\"u1\">He<i>llo </i></u></b><b><u id=\"u2\"><i>wo</i>rld</u></b></p>",
                    startId: "u1",
                    startOffset: 2,
                    endId: "u2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold across partial paragraphs <p>|Hello <i>world</i></p><p><b>Hello </b><i><b>wo|rld</b></i></p>",
                    startHtml: "<p id=\"p1\">Hello <i id=\"i1\">world</i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><b>Hello </b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 2
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline across partial paragraphs <p>|Hello <i>world</i></p><p><b>Hello </b><i><b>wo|rld</b></i></p>",
                    startHtml: "<p id=\"p1\">Hello <i id=\"i1\">world</i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><u>Hello </u><i id=\"i1\"><u>world</u></i></p><p id=\"p2\"><b><u>Hello </u></b><i id=\"i2\"><b id=\"b1\"><u>wo</u>rld</b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 2
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic across partial paragraphs <p>|Hello <i>world</i></p><p><b>Hello </b><i><b>wo|rld</b></i></p>",
                    startHtml: "<p id=\"p1\">Hello <i id=\"i1\">world</i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><i>Hello </i><i id=\"i1\">world</i></p><p id=\"p2\"><b><i>Hello </i></b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Bold across all-bolded paragraphs <p><b>|Hello </b><i><b>world</b></i></p><p><b>Hello </b><i><b>world|</b></i></p>",
                    startHtml: "<p id=\"p1\"><b>Hello </b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\">Hello <i id=\"i1\">world</i></p><p id=\"p2\">Hello <i id=\"i2\">world</i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 5
                ),
                { handler in
                    self.webView.bold() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Underline across all-bolded paragraphs <p><b>|Hello </b><i><b>world</b></i></p><p><b>Hello </b><i><b>world|</b></i></p>",
                    startHtml: "<p id=\"p1\"><b>Hello </b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><b><u>Hello </u></b><i id=\"i1\"><b><u>world</u></b></i></p><p id=\"p2\"><b><u>Hello </u></b><i id=\"i2\"><b id=\"b1\"><u>world</u></b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 5
                ),
                { handler in
                    self.webView.underline() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "Italic across all-bolded paragraphs <p><b>|Hello </b><i><b>world</b></i></p><p><b>Hello </b><i><b>world|</b></i></p>",
                    startHtml: "<p id=\"p1\"><b>Hello </b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\"><b>Hello </b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    endHtml: "<p id=\"p1\"><b><i>Hello </i></b><i id=\"i1\"><b>world</b></i></p><p id=\"p2\"><b><i>Hello </i></b><i id=\"i2\"><b id=\"b1\">world</b></i></p>",
                    startId: "p1",
                    startOffset: 0,
                    endId: "b1",
                    endOffset: 5
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            (
                HtmlTest(
                    description: "UnsetAll italic across paragraphs <p>This <i>is| italic</i></p><p><i>Ex|tending across</i> paragraphs</p>",
                    startHtml: "<p>This <i id=\"i1\">is italic</i></p><p><i id=\"i2\">Extending across</i> paragraphs</p>",
                    endHtml: "<p>This <i id=\"i1\">is</i> italic</p><p>Ex<i>tending across</i> paragraphs</p>",
                    startId: "i1",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.italic() { handler() }
                }
            ),
            //<p>This <i id=\"i1\">is all italic</i></p><p><i id=\"i2\">Extending across</i> paragraphs</p>
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Unformatting nested tags")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testStyles() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<h1><b id=\"b\"><i id=\"i\">Hello </i>world</b></h1>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h2 with h6",
                    startHtml: "<h2 id=\"h2\">Hello world</h2>",
                    endHtml: "<h6>Hello world</h6>",
                    startId: "h2",
                    startOffset: 0,
                    endId: "h2",
                    endOffset: 10
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H6) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace h3 with p",
                    startHtml: "<h3 id=\"h3\">Hello world</h3>",
                    endHtml: "<p>Hello world</p>",
                    startId: "h3",
                    startOffset: 2,
                    endId: "h3",
                    endOffset: 8
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .P) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiStyles() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Replace p with h1, selection in embedded format",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "i1",
                    startOffset: 2,
                    endId: "i3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format both ends",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "b1",
                    startOffset: 1,
                    endId: "b3",
                    endOffset: 1,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format at start",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "b1",
                    startOffset: 1,
                    endId: "i3",
                    endOffset: 2,
                    startChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection outside embedded format at end",
                    startHtml: "<p><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></p><p><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></p>",
                    endHtml: "<h1><b id=\"b1\"><i id=\"i1\">Hello </i>world1</b></h1><h1><b id=\"b2\"><i id=\"i2\">Hello </i>world2</b></h1><h1><b id=\"b3\"><i id=\"i3\">Hello </i>world3</b></h1>",
                    startId: "i1",
                    startOffset: 2,
                    endId: "b3",
                    endOffset: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Replace p with h1, selection across indented paragraphs",
                    startHtml: "<blockquote><p id=\"p1\">Paragraph 1</p></blockquote><blockquote><p id=\"p2\">Paragraph 2</p></blockquote><blockquote><p id=\"p3\">Paragraph 3</p></blockquote>",
                    endHtml: "<blockquote><h1>Paragraph 1</h1></blockquote><blockquote><h1>Paragraph 2</h1></blockquote><blockquote><h1>Paragraph 3</h1></blockquote>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p3",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.replaceStyle(state.style, with: .H1) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Setting and replacing styles across multiple paragraphs")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testDenting() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Indent, selection in text element",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<blockquote><p id=\"p\">Hello <b id=\"b\">world</b></p></blockquote>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent, selection in a non-text element",
                    startHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent from 1 to 0, selection in a non-text element, no styling",
                    startHtml: "<blockquote><b id=\"b\"><i id=\"i\">Hello </i>world</b></blockquote>",
                    endHtml: "<b id=\"b\"><i id=\"i\">Hello </i>world</b>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent from 1 to 0, selection in a non-text element, with styling",
                    startHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent from 2 to 1, selection in a non-text element",
                    startHtml: "<blockquote><blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b\"><i id=\"i\">Hello </i>world</b></p></blockquote>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent in an embedded paragraph in a blockquote, selection in a non-text element",
                    startHtml: "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote>",
                    endHtml: "<blockquote><p><b id=\"b1\"><i id=\"i1\">Hello </i>world</b></p><blockquote><p><b id=\"b2\"><i id=\"i2\">Hello </i>world</b></p></blockquote></blockquote>",
                    startId: "i2",
                    startOffset: 2,
                    endId: "i2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Increasing and decreasing block levels")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiDenting() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Indent <p>He|llo world1</p><p>He|llo world2</p>",
                    startHtml: "<p id=\"p1\">Hello world1</p><p id=\"p2\">Hello world2</p>",
                    endHtml: "<blockquote><p id=\"p1\">Hello world1</p></blockquote><blockquote><p id=\"p2\">Hello world2</p></blockquote>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <blockquote><p id=\"p1\">He|llo world1</p></blockquote><blockquote><p id=\"p2\">He|llo world2</p></blockquote>",
                    startHtml: "<blockquote><p id=\"p1\">Hello world1</p></blockquote><blockquote><p id=\"p2\">Hello world2</p></blockquote>",
                    endHtml: "<p id=\"p1\">Hello world1</p><p id=\"p2\">Hello world2</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent <p>He|llo world1</p><h5>He|llo world2</h5>",
                    startHtml: "<p id=\"p1\">Hello world1</p><h5 id=\"p2\">Hello world2</h5>",
                    endHtml: "<blockquote><p id=\"p1\">Hello world1</p></blockquote><blockquote><h5 id=\"p2\">Hello world2</h5></blockquote>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <blockquote><p id=\"p1\">He|llo world1</p></blockquote><blockquote><h5 id=\"p2\">He|llo world2</h5></blockquote>",
                    startHtml: "<blockquote><p id=\"p1\">Hello world1</p></blockquote><blockquote><h5 id=\"p2\">Hello world2</h5></blockquote>",
                    endHtml: "<p id=\"p1\">Hello world1</p><h5 id=\"p2\">Hello world2</h5>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    endHtml: "<blockquote><p id=\"p\">Hello paragraph</p></blockquote><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <blockquote><p id=\"p\">He|llo paragraph</p></blockquote><ul><li><h5 id=\"h\">He|llo header in list</h5></li></ul>",
                    startHtml: "<blockquote><p id=\"p\">Hello paragraph</p></blockquote><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    endHtml: "<p id=\"p\">Hello paragraph</p><h5 id=\"h\">Hello header in list</h5>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent no-op <ul><li><h5>Un|ordered <i>H5</i> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    endHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    endHtml: "<h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent interleaved paragraphs and lists",
                    startHtml: "<p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<blockquote><p id=\"p1\">Top-level paragraph 1</p></blockquote><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><blockquote><p>Top-level paragraph 2</p></blockquote><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent interleaved paragraphs and lists",
                    startHtml: "<p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<p id=\"p1\">Top-level paragraph 1</p><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol><p>Top-level paragraph 2</p><p id=\"p2\">Ordered list paragraph 1</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Indent list with sublists",
                    startHtml: "<ul><li><h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.</li><li>With two unstyled items.</li></ol></li><li><h5 id=\"h2\">With two styled items.</h5></li></ul>",
                    endHtml: "<ul><li><h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.<ol><li>With two unstyled items.</li></ol></li></ol><ul><li><h5 id=\"h2\">With two styled items.</h5></li></ul></li></ul>",
                    startId: "h1",
                    startOffset: 2,
                    endId: "h2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.indent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent list with sublists",
                    startHtml: "<ul><li><h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.</li><li>With two unstyled items.</li></ol></li><li><h5 id=\"h2\">With two styled items.</h5></li></ul>",
                    endHtml: "<h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.</li><li>With two unstyled items.</li></ol><h5 id=\"h2\">With two styled items.</h5>",
                    startId: "h1",
                    startOffset: 2,
                    endId: "h2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent, start and end in styles surround list",
                    startHtml: "<p id=\"p1\">Starting paragraph.</p><ul><li><h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.</li><li>With two unstyled items.</li></ol></li><li><h5 id=\"h2\">With two styled items.</h5></li></ul><p id=\"p2\">Ending paragraph.</p>",
                    endHtml: "<p id=\"p1\">Starting paragraph.</p><h5 id=\"h1\">Unordered list.</h5><ol><li>Ordered sublist.</li><li>With two unstyled items.</li></ol><h5 id=\"h2\">With two styled items.</h5><p id=\"p2\">Ending paragraph.</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Indent/outdent operations with selections spanning multiple elements")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testBlockquoteEnter() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Enter at beginning of simple paragraph in blockquote",
                startHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote>",
                endHtml: "<blockquote><p><br></p></blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Enter in middle of simple paragraph in blockquote",
                startHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote>",
                endHtml: "<blockquote><p id=\"p\">This is a sim</p></blockquote><blockquote><p>ple paragraph</p></blockquote>",
                startId: "p",
                startOffset: 13,
                endId: "p",
                endOffset: 13
            ),
            HtmlTest(
                description: "Enter at end of simple paragraph in blockquote",
                startHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote>",
                endHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote>",
                startId: "p",
                startOffset: 26,
                endId: "p",
                endOffset: 26
            ),
            HtmlTest(
                description: "Enter at beginning of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p><br></p></blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote></blockquote>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Enter in middle of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p id=\"p\">This is a sim</p></blockquote><blockquote><p>ple paragraph</p></blockquote></blockquote>",
                startId: "p",
                startOffset: 13,
                endId: "p",
                endOffset: 13
            ),
            HtmlTest(
                description: "Enter at end of simple paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote></blockquote>",
                startId: "p",
                startOffset: 26,
                endId: "p",
                endOffset: 26
            ),
            HtmlTest(
                description: "Enter at end of empty paragraph in nested blockquotes",
                startHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><blockquote><p id=\"empty\"><br></p></blockquote></blockquote>",
                endHtml: "<blockquote><blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><blockquote><p><br></p></blockquote><blockquote><p id=\"empty\"><br></p></blockquote></blockquote>",
                startId: "empty",
                startOffset: 0,
                endId: "empty",
                endOffset: 0
            ),
            HtmlTest(
                description: "Outdent on enter at end of empty paragraph in unnested blockquotes",
                startHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><blockquote><p id=\"empty\"><br></p></blockquote>",
                endHtml: "<blockquote><p id=\"p\">This is a simple paragraph</p></blockquote><p id=\"empty\"><br></p>",
                startId: "empty",
                startOffset: 0,
                endId: "empty",
                endOffset: 0
            ),
            // We don't wait for images to load or fail, so we specify the class, tabindex, width, and height on
            // input so we get the same thing back.
            HtmlTest(
                description: "Enter before image in blockquote",
                startHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p><br></p></blockquote><blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Enter after image in blockquote",
                startHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p><br></p></blockquote>",
                startId: "p",
                startOffset: 1,
                endId: "p",
                endOffset: 1
            ),
            HtmlTest(
                description: "Enter between images in blockquote",
                startHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                startId: "p",
                startOffset: 1,
                endId: "p",
                endOffset: 1
            ),
            HtmlTest(
                description: "Enter between text and image in blockquote",
                startHtml: "<blockquote><p id=\"p\">Hello<img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                endHtml: "<blockquote><p id=\"p\">Hello</p></blockquote><blockquote><p><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote>",
                startId: "p",
                startOffset: 5,
                endId: "p",
                endOffset: 5,
                startChildNodeIndex: 0,
                endChildNodeIndex: 0
            ),
            HtmlTest(
                description: "Enter between image and text in blockquote",
                startHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\">Hello</p></blockquote>",
                endHtml: "<blockquote><p id=\"p\"><img src=\"steve.png\" alt=\"Local image\" class=\"resize-image\" tabindex=\"-1\" width=\"20\" height=\"20\"></p></blockquote><blockquote><p>Hello</p></blockquote>",
                startId: "p",
                startOffset: 1,
                endId: "p",
                endOffset: 1
            ),
            HtmlTest(
                description: "Enter at end of text in formatted element",
                startHtml: "<blockquote><p id=\"p\"><b id=\"b\">Hello</b></p></blockquote>",
                endHtml: "<blockquote><p id=\"p\"><b id=\"b\">Hello</b></p></blockquote><blockquote><p><b><br></b></p></blockquote>",
                startId: "b",
                startOffset: 5,
                endId: "b",
                endOffset: 5
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed inside of blockquotes")
            // We set a handler for when 'undoSet' is received, which happens after the undo stack is all set after _doListEnter.
             // Within that handler, we set a handler for when 'input' is received, which happens after the undo is complete.
             // When the undo is done, the html should be what we started with.
             webView.setTestHtml(value: startHtml) {
                 self.webView.getRawHtml { contents in
                     self.assertEqualStrings(expected: startHtml, saw: contents)
                     self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                         // Define the handler to execute after input is received (i.e., once the operation is
                         // complete and has changed the html).
                         self.addInputHandler {
                             self.webView.getRawHtml { formatted in
                                 self.assertEqualStrings(expected: endHtml, saw: formatted)
                                 expectation.fulfill()
                             }
                         }
                         // Kick off the enter operation in the blockquote we selected
                         self.webView.testBlockquoteEnter()
                     }
                 }
             }
            wait(for: [expectation], timeout: 30)
        }
    }

    func testLists() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Make a paragraph into an ordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Make a paragraph into an unordered list",
                    startHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    endHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element unordered list, thereby removing the list, too",
                    startHtml: "<ul><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ul>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a single-element ordered list, thereby removing the list, too",
                    startHtml: "<ol><li><p id=\"p\">Hello <b id=\"b\">world</b></p></li></ol>",
                    endHtml: "<p id=\"p\">Hello <b id=\"b\">world</b></p>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove a list item from a multi-element unordered list, leaving the list in place",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ul><p>Hello <b id=\"b\">world1</b></p><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Change one of the list items in a multi-element unordered list to an ordered list item",
                    startHtml: "<ul><li><p>Hello <b id=\"b\">world1</b></p></li><li><p>Hello <b>world2</b></p></li></ul>",
                    endHtml: "<ol><li><p>Hello <b id=\"b\">world1</b></p></li></ol><ul><li><p>Hello <b>world2</b></p></li></ul>",
                    startId: "b",
                    startOffset: 2,
                    endId: "b",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove UL <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul></li></ul>",
                    endHtml: "<p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <ul><li><p>He|llo paragraph</p><ul><li><h5>Hello header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul></li></ul>",
                    endHtml: "<p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "p",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Outdent <ul><li><p>Hello paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul></li></ul>",
                    startHtml: "<ul><li><p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul></li></ul>",
                    endHtml: "<ul><li><p id=\"p\">Hello paragraph</p></li><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    startId: "h",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.outdent() {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Mucking about with lists and selections in them")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testMultiLists() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "UL <p>He|llo world1</p><p>He|llo world2</p>",
                    startHtml: "<p id=\"p1\">Hello world1</p><p id=\"p2\">Hello world2</p>",
                    endHtml: "<ul><li><p id=\"p1\">Hello world1</p></li><li><p id=\"p2\">Hello world2</p></li></ul>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove UL <ul><li><p>He|llo world1</p></li><li><p>He|llo world2</p></li></ul>",
                    startHtml: "<ul><li><p id=\"p1\">Hello world1</p></li><li><p id=\"p2\">Hello world2</p></li></ul>",
                    endHtml: "<p id=\"p1\">Hello world1</p><p id=\"p2\">Hello world2</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "UL <p>He|llo world1</p><h5>He|llo world2</h5>",
                    startHtml: "<p id=\"p1\">Hello world1</p><h5 id=\"p2\">Hello world2</h5>",
                    endHtml: "<ul><li><p id=\"p1\">Hello world1</p></li><li><h5 id=\"p2\">Hello world2</h5></li></ul>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove UL <ul><li><p>He|llo world1</p></li><li><h5>He|llo world2</h5></li></ul>",
                    startHtml: "<ul><li><p id=\"p1\">Hello world1</p></li><li><h5 id=\"p2\">Hello world2</h5></li></ul>",
                    endHtml: "<p id=\"p1\">Hello world1</p><h5 id=\"p2\">Hello world2</h5>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "UL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    endHtml: "<ul><li><p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul></li></ul>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove UL <ul><li><p>He|llo paragraph</p></li><ul><li><h5>He|llo header in list</h5></li></ul></ul>",
                    startHtml: "<ul><li><p id=\"p\">Hello paragraph</p></li><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul></ul>",
                    endHtml: "<p id=\"p\">Hello paragraph</p><h5 id=\"h\">Hello header in list</h5>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "OL <p>He|llo paragraph</p><ul><li><h5>He|llo header in list</h5></li></ul>",
                    startHtml: "<p id=\"p\">Hello paragraph</p><ul><li><h5 id=\"h\">Hello header in list</h5></li></ul>",
                    endHtml: "<ol><li><p id=\"p\">Hello paragraph</p><ol><li><h5 id=\"h\">Hello header in list</h5></li></ol></li></ol>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove OL <ol><li><p>He|llo paragraph</p></li><ol><li><h5>He|llo header in list</h5></li></ol></ol>",
                    startHtml: "<ol><li><p id=\"p\">Hello paragraph</p></li><ol><li><h5 id=\"h\">Hello header in list</h5></li></ol></ol>",
                    endHtml: "<p id=\"p\">Hello paragraph</p><h5 id=\"h\">Hello header in list</h5>",
                    startId: "p",
                    startOffset: 2,
                    endId: "h",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "UL <ul><li><h5>Un|ordered <i>H5</i> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    endHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ul><li id=\"li\">Ordered sublist.</li></ul></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove UL <ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ul><li id=\"li\"><p>Unordered sublist.</p></li></ul></li></ul>",
                    startHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ul><li id=\"li\"><p>Unordered sublist.</p></li></ul></li></ul>",
                    endHtml: "<h5 id=\"h5\">Unordered <i>H5</i> list.</h5><p>Unordered sublist.</p>",
                    undoHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ul><li><p>Unordered sublist.</p></li></ul></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "OL <ul><li><h5>Un|ordered <i>H5</i> list.</h5><ol><li>Or|dered sublist.</li></ol></li></ul>",
                    startHtml: "<ul><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ul>",
                    endHtml: "<ol><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\">Ordered sublist.</li></ol></li></ol>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Remove OL <ol><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\"><p>Ordered sublist.</p></li></ol></li></ol>",
                    startHtml: "<ol><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li id=\"li\"><p>Ordered sublist.</p></li></ol></li></ol>",
                    endHtml: "<h5 id=\"h5\">Unordered <i>H5</i> list.</h5><p>Ordered sublist.</p>",
                    undoHtml: "<ol><li><h5 id=\"h5\">Unordered <i>H5</i> list.</h5><ol><li><p>Ordered sublist.</p></li></ol></li></ol>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "li",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "UL interleaved paragraphs and lists",
                    startHtml: "<p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<ul><li><p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p id=\"p2\">Ordered list paragraph 1</p></li></ul></li></ul>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Unset all UL interleaved paragraphs and lists",
                    startHtml: "<ul><li><p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p id=\"p2\">Ordered list paragraph 1</p></li></ul></li></ul>",
                    endHtml: "<p id=\"p1\">Top-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>Top-level paragraph 2</p><p id=\"p2\">Ordered list paragraph 1</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Set all OL lists and sublists",
                    startHtml: "<ul><li><p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p id=\"p2\">Ordered list paragraph 1</p></li></ul></li></ul>",
                    endHtml: "<ol><li><p id=\"p1\">Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol></li></ol>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "OL interleaved paragraphs and lists",
                    startHtml: "<p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ul><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol>",
                    endHtml: "<ol><li><p id=\"p1\">Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol></li></ol>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Unset all OL interleaved paragraphs and lists",
                    startHtml: "<ol><li><p id=\"p1\">Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol></li></ol>",
                    endHtml: "<p id=\"p1\">Top-level paragraph 1</p><p>Unordered list paragraph 1</p><p>Ordered sublist paragraph</p><p>Top-level paragraph 2</p><p id=\"p2\">Ordered list paragraph 1</p>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .OL) {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Set all UL lists and sublists",
                    startHtml: "<ol><li><p id=\"p1\">Top-level paragraph 1</p><ol><li><p>Unordered list paragraph 1</p><ol><li><p>Ordered sublist paragraph</p></li></ol></li></ol></li><li><p>Top-level paragraph 2</p><ol><li><p id=\"p2\">Ordered list paragraph 1</p></li></ol></li></ol>",
                    endHtml: "<ul><li><p id=\"p1\">Top-level paragraph 1</p><ul><li><p>Unordered list paragraph 1</p><ul><li><p>Ordered sublist paragraph</p></li></ul></li></ul></li><li><p>Top-level paragraph 2</p><ul><li><p id=\"p2\">Ordered list paragraph 1</p></li></ul></li></ul>",
                    startId: "p1",
                    startOffset: 2,
                    endId: "p2",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.toggleListItem(type: .UL) {
                            handler()
                        }
                    }
                }
            ),
            ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "List operations with selections spanning multiple elements")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset) { result in
                        // Execute the action to unformat at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testListEnterCollapsed() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Enter at end of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5></li><li><h5><br></h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of h5",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li><h5><br></h5></li><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 0,
                    endId: "h5",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bul|leted item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>leted&nbsp;<i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 3,
                    endId: "h5",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in \"Bulleted item 1|.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i>&nbsp;1</h5></li><li><h5>.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",
                    startOffset: 2,
                    endId: "h5",
                    endOffset: 2,
                    startChildNodeIndex: 2,
                    endChildNodeIndex: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in italicized \"item\" in \"Bulleted it|em 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>em</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",
                    startOffset: 2,
                    endId: "i",
                    endOffset: 2
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at end of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li><p><br></p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 16,
                    endId: "ol1",
                    endOffset: 16
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter at beginning of unstyled \"Numbered item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li><p><br></p></li><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 0,
                    endId: "ol1",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Split unstyled \"Number|ed item 1.\"",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Number</li><li><p>ed item 1.</p></li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",
                    startOffset: 6,
                    endId: "ol1",
                    endOffset: 6
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Enter in empty list item at end of list.",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li><li id=\"ul2\"><h5 id=\"h52\"><br></h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\">Numbered item 1.</li><li id=\"ol2\">Numbered item 2.</li></ol></li></ul><h5 id=\"h52\"><br></h5>",
                    startId: "h52",
                    startOffset: 0,
                    endId: "h52",
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Enter being pressed in a list with various collapsed selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testListEnterRange() throws {
        // The selection (startId, startOffset, endId, endOffset) is always identified
        // using the innermost element id and the offset into it. Inline comments
        // below show the selection using "|" for clarity.
        //
        // The startHtml includes styled items in the <ul> and unstyled items in the <ol>, and we test both.
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (
                HtmlTest(
                    description: "Word in single styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "Numbered "
                    startOffset: 2,
                    endId: "ol1",
                    endOffset: 11,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Word in single unstyled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered&nbsp;</li><li><p>6.</p></li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "item "
                    startOffset: 9,
                    endId: "ol6",
                    endOffset: 14
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Part of a formatted item in a styled list item",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">i</i></h5></li><li><h5><i>m</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select "<i id=\"i\">i|te|m</i>" which is itself inside of an <h5>
                    startOffset: 1,
                    endId: "i",
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "The entire formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">\u{200B}</i></h5></li><li><h5><i>\u{200B}</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",     // Select the entire "<i id=\"i\">item</i>" which is itself inside of an <h5>
                    startOffset: 9,
                    endId: "i",
                    endOffset: 4
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Only the enclosed formatted item in a styled list item (note the zero width chars in the result)",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">\u{200B}</i></h5></li><li><h5><i>\u{200B}</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",     // Select only the text "item" inside of <i>item</i> which is itself inside of an <h5>
                    startOffset: 0,
                    endId: "i",
                    endOffset: 4
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P&nbsp;</p></li><li><p>Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol1",     // Select "P |Numbered item 1."
                    startOffset: 2,
                    endId: "ol3",       // Select "P |Numbered item 3."
                    endOffset: 2,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one unstyled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li><p><br></p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol6",     // Select "|Numbered item 6."
                    startOffset: 0,
                    endId: "ol8",       // Select "|Numbered item 8."
                    endOffset: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection at start of one styled list item, end in another",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li><p><br></p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "|P Numbered item 2."
                    startOffset: 0,
                    endId: "ol4",       // Select "|P Numbered item 4."
                    endOffset: 0,
                    startChildNodeIndex: 0,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a styled list item, end in an unstyled one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Num</p></li><li><p>bered item 7.</p></li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "ol2",     // Select "P Num|bered item 2."
                    startOffset: 5,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    startChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h5\">Bul</h5></li><li><h5>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h5",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bul</h5></li><li><h5>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "h51",     // Select "Bul|leted item 2."
                    startOffset: 3,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered formatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>\u{200B}</i>bered item 3.</h5><ol><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",       // Select "<i id=\"i\">it!em</i>"
                    startOffset: 2,
                    endId: "ol3",       // Select "P Num|bered item 3."
                    endOffset: 5,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
            (
                HtmlTest(
                    description: "Begin selection in a formatted item in a bulleted list item, end in an ordered unformatted one",
                    startHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">item</i> 1.</h5><ol><li id=\"ol1\"><p>P Numbered item 1.</p></li><li id=\"ol2\"><p>P Numbered item 2.</p></li><li id=\"ol3\"><p>P Numbered item 3.</p></li><li id=\"ol4\"><p>P Numbered item 4.</p></li><li id=\"ol5\">Numbered item 5.</li><li id=\"ol6\">Numbered item 6.</li><li id=\"ol7\">Numbered item 7.</li><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    endHtml: "<ul><li id=\"ul1\"><h5 id=\"h51\">Bulleted <i id=\"i\">it</i></h5></li><li><h5><i>\u{200B}</i>bered item 7.</h5><ol><li id=\"ol8\">Numbered item 8.</li></ol></li><li id=\"ul2\"><h5>Bulleted item 2.</h5></li></ul>",
                    startId: "i",       // Select "<i id=\"i\">it!em</i>"
                    startOffset: 2,
                    endId: "ol7",       // Select "Num|bered item 7."
                    endOffset: 3,
                    endChildNodeIndex: 0
                ),
                { handler in
                    self.webView.getSelectionState() { state in
                        self.webView.testListEnter {
                            handler()
                        }
                    }
                }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: test.description ?? "Enter being pressed in a list with various range selections")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Execute the action to press Enter at the selection
                        action() {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testInsertTable() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Insert at beginning of a paragraph",
                startHtml: "<p id=\"p\">This is a simple paragraph</p>",
                endHtml: "<table><tbody><tr><td><br></td><td></td></tr><tr><td></td><td></td></tr></tbody></table><p id=\"p\">This is a simple paragraph</p>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Insert in the middle of a paragraph",
                startHtml: "<p id=\"p\">This is a simple paragraph</p>",
                endHtml: "<p id=\"p\">This is a simple paragraph</p><table><tbody><tr><td><br></td><td></td></tr><tr><td></td><td></td></tr></tbody></table>",
                startId: "p",
                startOffset: 13,
                endId: "p",
                endOffset: 13
            ),
            HtmlTest(
                description: "Insert in the end of a paragraph",
                startHtml: "<p id=\"p\">This is a simple paragraph</p>",
                endHtml: "<p id=\"p\">This is a simple paragraph</p><table><tbody><tr><td><br></td><td></td></tr><tr><td></td><td></td></tr></tbody></table>",
                startId: "p",
                startOffset: 26,
                endId: "p",
                endOffset: 26
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Insert a table")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        // Define the handler to execute after input is received (i.e., once the operation is
                        // complete and has changed the html).
                        self.addInputHandler {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                        // Kick off the insert table action
                        self.webView.insertTable(rows: 2, cols: 2)
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testTableActions() throws {
        let htmlTestAndActions: [(HtmlTest, ((@escaping ()->Void)->Void))] = [
            (HtmlTest(
                description: "Delete row",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteRow() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Delete col",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteCol() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Delete table",
                startHtml: "<p>Hello</p><table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>world</p>",
                endHtml: "<p>Hello</p><p>world</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.deleteTable() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add row above",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p><br></p></td><td><p><br></p></td></tr><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addRow(.before) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add row below",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p><br></p></td><td><p><br></p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addRow(.after) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add col before",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p><br></p></td><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p><br></p></td><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addCol(.before) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add col after",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p><br></p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p><br></p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addCol(.after) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Add header",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                endHtml: "<table><thead><tr><th colspan=\"2\"><p><br></p></th></tr></thead><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table><p>Hello</p>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.addHeader() {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set cell border",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-cell\"><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.cell) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set header border",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-header\"><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.header) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set outer border",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-outer\"><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.outer) {
                     handler()
                 }
             }
            ),
            (HtmlTest(
                description: "Set no border",
                startHtml: "<table><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                endHtml: "<table class=\"bordered-table-none\"><tbody><tr><td><p id=\"00\">Row 0, Col 0</p></td><td><p id=\"01\">Row 0, Col 1</p></td></tr><tr><td><p id=\"10\">Row 1, Col 0</p></td><td><p id=\"11\">Row 1, Col 1</p></td></tr></tbody></table>",
                startId: "00",
                startOffset: 3,
                endId: "00",
                endOffset: 3
            ),
             { handler in
                 self.webView.borderTable(.none) {
                     handler()
                 }
             }
            ),
        ]
        for (test, action) in htmlTestAndActions {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Perform actions on a table")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        action {
                            self.webView.getRawHtml { formatted in
                                self.assertEqualStrings(expected: endHtml, saw: formatted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
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
                startHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                endHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 id=\"h1\" style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<h1 id=\"h1\">Welcome to the MarkupEditor Demo</h1><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p id=\"p\">These are angle brackets: < and >.</p>",
                endHtml: "<p id=\"p\">These are angle brackets: &lt; and &gt;.</p>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                // From https://stackoverflow.com/a/50547246/8968411
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p><b>List of One Liners</b></p><p>Let\'s solve this problem for this array:</p><p><code>var array = [\'A\', \'B\', \'C\'];</code></p><p><b>1. Remove only the first:</b>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.indexOf(\'B\'), 1);</code></p><p><b>2. Remove only the last:</b>&nbsp;Use If you are sure that the item exist</p><p><code>array.splice(array.lastIndexOf(\'B\'), 1);</code></p><p><b>3. Remove all occurrences:</b></p><p><code>array = array.filter(v =&gt; v !== \'B\'); </code></p>",
                startId: "p", 
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml: "<p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>&nbsp;&nbsp;&nbsp;&nbsp;An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a <a href=\"http://foo.com\">link</a>.</p><p><br></p><ul><li>A checklist</li></ul><ul><li>With a checked item</li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li>A numbered list</li><li>With two items</li><ol><li>One of which has a subitem</li></ol></ol><p><br></p><ul><li>A bulleted list</li><li>With two items</li><ul><li>One of which has a subitem</li></ul></ul><p><br></p><table cellspacing=\"0\" cellpadding=\"0\"><tbody><tr><td valign=\"top\"><p>A table</p></td><td valign=\"top\"><p>With two columns</p></td></tr><tr><td valign=\"top\"><p>And two rows</p></td><td valign=\"top\"><p>😜</p></td></tr></tbody></table><p>And here is an image…</p><p><br></p><p><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Cleaning up html we get from the paste buffer")
            self.webView.testPasteHtmlPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteHtml() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello &lt;b&gt;bold&lt;/b&gt; worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello <b>bold</b> worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <b>bold</b> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello <i>bold</i> worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <i>bold</i> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello <b>bold</b> worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello <i>bold</i> worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <i>bold</i> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello <b>bold</b> worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello <b>bold</b> world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello <b>bold</b> world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><h5>Hello world</h5>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><h5>Hello <b>bold</b> world</h5>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <b>bold</b> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p id=\"blank\"><br></p>",
                endHtml: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>",
                startId: "blank",     // Select "|"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteHtml(test.pasteString) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    /// Test preprocessing of HTML that is performed before pasting text (aka "Paste and Match Style").
    ///
    /// See comments in the `testPasteHtmlPreprocessing` method.
    ///
    /// The "pasteText" function (via the "Paste and Match Style" edit menu) pastes the MarkupEditor
    /// equivalent of plain text. To do that, it uses <p> for all styling and removes all formatting (e.g., <b>, <i>, etc).
    /// The text preprocessing does the same preprocessing as the HTML preprocessing, plus this additional
    /// style and format removal, along with link removal.
    func testPasteTextPreprocessing() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Clean HTML should not change",
                startHtml: "<h5 id=\"h5\">This is just a simple paragraph.</h5>",
                endHtml: "<p>This is just a simple paragraph.</p>",
                startId: "h5",
                startOffset: 10,
                endId: "h5",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up a simple copy buffer of h1 from the MarkupEditor",
                startHtml: "<h1 id=\"h1\" style=\"font-size: 2.5em; font-weight: bold; margin: 0px 0px 10px; caret-color: rgb(0, 0, 255); color: rgba(0, 0, 0, 0.847); font-family: UICTFontTextStyleBody; font-style: normal; font-variant-caps: normal; letter-spacing: normal; orphans: auto; text-align: start; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-tap-highlight-color: rgba(26, 26, 26, 0.3); -webkit-text-size-adjust: none; -webkit-text-stroke-width: 0px; text-decoration: none;\">Welcome to the MarkupEditor Demo</h1><br class=\"Apple-interchange-newline\">",
                endHtml: "<p>Welcome to the MarkupEditor Demo</p><p><br></p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up text that includes HTML",
                startHtml: "<p id=\"p\">These are angle brackets: < and >.</p>",
                endHtml: "<p id=\"p\">These are angle brackets: &lt; and &gt;.</p>",
                startId: "p",
                startOffset: 0,
                endId: "p",
                endOffset: 0
            ),
            HtmlTest(
                description: "Copy/paste from VSCode",
                startHtml: "<meta charset='utf-8'><div style=\"color: #d4d4d4;background-color: #1e1e1e;font-family: Menlo, Monaco, 'Courier New', monospace;font-weight: normal;font-size: 12px;line-height: 18px;white-space: pre;\"><div><span style=\"color: #d4d4d4;\">Hello </span><span style=\"color: #808080;\">&lt;</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\">bold</span><span style=\"color: #808080;\">&lt;/</span><span style=\"color: #569cd6;\">b</span><span style=\"color: #808080;\">&gt;</span><span style=\"color: #d4d4d4;\"> world</span></div></div>",
                endHtml: "<p>Hello &lt;b&gt;bold&lt;/b&gt; world</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up complex content from StackOverflow",
                startHtml: "<meta charset=\"UTF-8\"><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">List of One Liners</strong></p><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\">Let\'s solve this problem for this array:</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\"><span class=\"hljs-keyword\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-keyword);\">var</span> array = [<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'A\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>, <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'C\'</span>];\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">1. Remove only the first:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">indexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">2. Remove only the last:</strong><span class=\"Apple-converted-space\"> </span>Use If you are sure that the item exist</p><pre class=\"lang-js s-code-block\" style=\"margin-top: 0px; margin-right: 0px; margin-bottom: calc(var(--s-prose-spacing) + 0.4em); margin-left: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">splice</span>(array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">lastIndexOf</span>(<span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>), <span class=\"hljs-number\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-namespace);\">1</span>);\n</code></pre><p style=\"margin-top: 0px; margin-right: 0px; margin-bottom: var(--s-prose-spacing); margin-left: 0px; padding: 0px; border: 0px; font-family: -apple-system, BlinkMacSystemFont, &quot;Segoe UI Adjusted&quot;, &quot;Segoe UI&quot;, &quot;Liberation Sans&quot;, sans-serif; font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit; clear: both; caret-color: rgb(35, 38, 41); color: rgb(35, 38, 41); letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; white-space: normal; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><strong style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: bold; font-stretch: inherit; line-height: inherit; font-size: 15px; vertical-align: baseline; box-sizing: inherit;\">3. Remove all occurrences:</strong></p><pre class=\"lang-js s-code-block\" style=\"margin: 0px; padding: 12px; border: 0px; font-family: var(--ff-mono); font-style: normal; font-variant-caps: normal; font-weight: 400; font-stretch: inherit; line-height: 1.30769231; font-size: 13px; vertical-align: baseline; box-sizing: inherit; width: auto; max-height: 600px; overflow: auto; background-color: var(--highlight-bg); border-radius: 5px; color: var(--highlight-color); word-wrap: normal; letter-spacing: normal; orphans: auto; text-align: left; text-indent: 0px; text-transform: none; widows: auto; word-spacing: 0px; -webkit-text-size-adjust: auto; -webkit-text-stroke-width: 0px; text-decoration: none;\"><code class=\"hljs language-javascript\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; background-color: transparent; white-space: inherit;\">array = array.<span class=\"hljs-title function_\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-literal);\">filter</span>(<span class=\"hljs-function\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\"><span class=\"hljs-params\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit;\">v</span> =&gt;</span> v !== <span class=\"hljs-string\" style=\"margin: 0px; padding: 0px; border: 0px; font-family: inherit; font-style: inherit; font-variant-caps: inherit; font-weight: inherit; font-stretch: inherit; line-height: inherit; font-size: 13px; vertical-align: baseline; box-sizing: inherit; color: var(--highlight-variable);\">\'B\'</span>); </code></pre>",
                endHtml: "<p>List of One Liners</p><p>Let\'s solve this problem for this array:</p><p>var array = [\'A\', \'B\', \'C\'];</p><p>1. Remove only the first:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.indexOf(\'B\'), 1);</p><p>2. Remove only the last:&nbsp;Use If you are sure that the item exist</p><p>array.splice(array.lastIndexOf(\'B\'), 1);</p><p>3. Remove all occurrences:</p><p>array = array.filter(v =&gt; v !== \'B\'); </p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Clean up some text from Xcode",
                startHtml: "const _pasteHTML = function(html, oldUndoerData, undoable=true) {\n    const redoing = !undoable && (oldUndoerData !== null);\n    let sel = document.getSelection();\n    let anchorNode = (sel) ? sel.anchorNode : null;\n    if (!anchorNode) {\n        MUError.NoSelection.callback();\n        return null;\n    };",
                endHtml: "<p>const _pasteHTML = function(html, oldUndoerData, undoable=true) {<br>&nbsp;&nbsp;&nbsp;&nbsp;const redoing = !undoable &amp;&amp; (oldUndoerData !== null);<br>&nbsp;&nbsp;&nbsp;&nbsp;let sel = document.getSelection();<br>&nbsp;&nbsp;&nbsp;&nbsp;let anchorNode = (sel) ? sel.anchorNode : null;<br>&nbsp;&nbsp;&nbsp;&nbsp;if (!anchorNode) {<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;MUError.NoSelection.callback();<br>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;return null;<br>&nbsp;&nbsp;&nbsp;&nbsp;};</p>",
                startId: "h1",
                startOffset: 10,
                endId: "h1",
                endOffset: 10
            ),
            HtmlTest(
                description: "Simple multiline text from MacOS Notes",
                startHtml: "This is a test<br><br>Of a note<br>But what is this?",
                endHtml: "<p>This is a test<br><br>Of a note<br>But what is this?</p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Trailing <BR> in MacOS Notes",
                startHtml: "This is a test<br>",
                endHtml: "<p>This is a test<br></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
            HtmlTest(
                description: "Rosetta Stone from iOS Notes",
                startHtml: "<!DOCTYPE html PUBLIC \"-//W3C//DTD HTML 4.01//EN\" \"http://www.w3.org/TR/html4/strict.dtd\">\n<html>\n<head>\n<meta http-equiv=\"Content-Type\" content=\"text/html; charset=UTF-8\">\n<meta http-equiv=\"Content-Style-Type\" content=\"text/css\">\n<title></title>\n<meta name=\"Generator\" content=\"Cocoa HTML Writer\">\n<style type=\"text/css\">\np.p1 {margin: 0.0px 0.0px 3.0px 0.0px; font: 28.0px \'.AppleSystemUIFont\'}\np.p2 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'; min-height: 22.0px}\np.p3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\np.p4 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.Apple Color Emoji UI\'}\np.p5 {margin: 9.0px 0.0px 8.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nli.li3 {margin: 0.0px 0.0px 0.0px 0.0px; font: 17.0px \'.AppleSystemUIFont\'}\nspan.s1 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 28.00px}\nspan.s2 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.s3 {font-family: \'UICTFontTextStyleEmphasizedBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s4 {font-family: \'UICTFontTextStyleItalicBody\'; font-weight: normal; font-style: italic; font-size: 17.00px}\nspan.s5 {font-family: \'UICTFontTextStyleBody\'; font-weight: normal; font-style: normal; font-size: 17.00px; text-decoration: underline}\nspan.s6 {font-family: \'UICTFontTextStyleEmphasizedItalicBody\'; font-weight: bold; font-style: italic; font-size: 17.00px; text-decoration: underline}\nspan.s7 {font-family: \'UICTFontTextStyleBody\'; font-weight: bold; font-style: normal; font-size: 17.00px}\nspan.s8 {font-family: \'.AppleColorEmojiUI\'; font-weight: normal; font-style: normal; font-size: 17.00px}\nspan.Apple-tab-span {white-space:pre}\ntable.t1 {border-collapse: collapse}\ntd.td1 {border-style: solid; border-width: 1.0px 1.0px 1.0px 1.0px; border-color: #aaaaaa #aaaaaa #aaaaaa #aaaaaa; padding: 1.0px 5.0px 1.0px 5.0px}\nol.ol1 {list-style-type: decimal}\nul.ul1 {list-style-type: circle}\nul.ul2 {list-style-type: \'✓  \'}\nul.ul3 {list-style-type: disc}\n</style>\n</head>\n<body>\n<p class=\"p1\"><span class=\"s1\">Notes Test for MarkupEditor</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\"><span class=\"Apple-tab-span\">\t</span>An indented paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph<span class=\"Apple-converted-space\"> </span></span></p>\n<p class=\"p3\"><span class=\"s2\">With another immediately below.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p3\"><span class=\"s2\">A paragraph with </span><span class=\"s3\">bold</span><span class=\"s2\">, </span><span class=\"s4\">italic</span><span class=\"s2\">, and </span><span class=\"s5\">underline</span><span class=\"s2\"> , and </span><span class=\"s6\">combo formatting</span><span class=\"s2\"> in it and a <a href=\"http://foo.com\">link</a>.</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul1\">\n<li class=\"li3\"><span class=\"s2\">A checklist</span></li>\n</ul>\n<ul class=\"ul2\">\n<li class=\"li3\"><span class=\"s2\">With a checked item</span></li>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p1\"><span class=\"s1\">A Title</span></p>\n<p class=\"p3\"><span class=\"s7\">A Subtitle</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">A numbered list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ol class=\"ol1\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ol>\n</ol>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">A bulleted list</span></li>\n<li class=\"li3\"><span class=\"s2\">With two items</span></li>\n<ul class=\"ul3\">\n<li class=\"li3\"><span class=\"s2\">One of which has a subitem</span></li>\n</ul>\n</ul>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<table cellspacing=\"0\" cellpadding=\"0\" class=\"t1\">\n<tbody>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">A table</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">With two columns</span></p>\n</td>\n</tr>\n<tr>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p3\"><span class=\"s2\">And two rows</span></p>\n</td>\n<td valign=\"top\" class=\"td1\">\n<p class=\"p4\"><span class=\"s8\">😜</span></p>\n</td>\n</tr>\n</tbody>\n</table>\n<p class=\"p3\"><span class=\"s2\">And here is an image…</span></p>\n<p class=\"p2\"><span class=\"s2\"></span><br></p>\n<p class=\"p5\"><span class=\"s2\"><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></span></p>\n</body>\n</html>\n",
                endHtml: "<p>Notes Test for MarkupEditor</p><p><br></p><p>A paragraph&nbsp;</p><p><br></p><p>&nbsp;&nbsp;&nbsp;&nbsp;An indented paragraph&nbsp;</p><p><br></p><p>A paragraph&nbsp;</p><p>With another immediately below.</p><p><br></p><p>A paragraph with bold, italic, and underline , and combo formatting in it and a link.</p><p><br></p><ul><li>A checklist</li></ul><ul><li>With a checked item</li></ul><p><br></p><p>A Title</p><p>A Subtitle</p><p><br></p><ol><li>A numbered list</li><li>With two items</li><ol><li>One of which has a subitem</li></ol></ol><p><br></p><ul><li>A bulleted list</li><li>With two items</li><ul><li>One of which has a subitem</li></ul></ul><p><br></p><table cellspacing=\"0\" cellpadding=\"0\"><tbody><tr><td valign=\"top\"><p>A table</p></td><td valign=\"top\"><p>With two columns</p></td></tr><tr><td valign=\"top\"><p>And two rows</p></td><td valign=\"top\"><p>😜</p></td></tr></tbody></table><p>And here is an image…</p><p><br></p><p><img src=\"file:///Pasted%20Graphic.png\" alt=\"Pasted Graphic.png\"></p>",
                startId: "p",
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Get \"unformatted text\" from the paste buffer")
            self.webView.testPasteTextPreprocessing(html: startHtml) { cleaned in
                self.assertEqualStrings(expected: endHtml, saw: cleaned)
                expectation.fulfill()
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteText() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded HTML at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello &lt;b&gt;bold&lt;/b&gt; worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello &lt;b&gt;bold&lt;/b&gt; world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded bold at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello bold worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "Hello <b>bold</b> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple text at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello world"
            ),
            HtmlTest(
                description: "P in P - Paste text with embedded italic at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello bold worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "Hello <i>bold</i> world"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello bold worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at insertion point in a bolded word",
                startHtml: "<p id=\"p\">This is <b id=\"b\">just</b> a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <b id=\"b\">juHello bold worldst</b> a simple paragraph.</p>",
                startId: "b",     // Select "ju|st "
                startOffset: 2,
                endId: "b",
                endOffset: 2,
                pasteString: "<p>Hello <i>bold</i> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at beginning of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">Hello bold worldThis is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at end of another",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.Hello bold world</p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste simple paragraph at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello world</p>"
            ),
            HtmlTest(
                description: "P in P - Paste paragraph with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<p>Hello <b>bold</b> world</p>"
            ),
            HtmlTest(
                description: "H5 in P - Paste simple h5 at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello world</p>",
                startId: "blank",     // Select "|<br>"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello world</h5>"
            ),
            HtmlTest(
                description: "H5 in P - Paste h5 with children at a blank paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p><p id=\"blank\"><br></p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.</p><p>Hello bold world</p>",
                startId: "blank",     // Select "|This"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h5>Hello <b>bold</b> world</h5>"
            ),
            HtmlTest(
                description: "P in Empty Document - Paste multiple paragraphs into an empty document",
                startHtml: "<p id=\"blank\"><br></p>",
                endHtml: "<p>A title</p><p>A subtitle</p><p>A paragraph.</p>",
                startId: "blank",     // Select "|"
                startOffset: 0,
                endId: "blank",
                endOffset: 0,
                pasteString: "<h1>A title</h1><h2>A subtitle</h2><p>A paragraph.</p>"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let endHtml = test.endHtml
            let expectation = XCTestExpectation(description: "Paste various html at various places")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteText(test.pasteString) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteImage() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Image in P - Paste image at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is juHello worldst a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteImage(UIImage(systemName: "calendar")) {
                            self.webView.getRawHtml() { pasted in
                                if let imageFileName = pasted?.imageFileNameInTag() {
                                    XCTAssertTrue(self.webView.resourceExists(imageFileName))
                                    expectation.fulfill()
                                } else {
                                    XCTFail("The pasted HTML was not returned properly.")
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteImageUrl() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "MP4 URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.mp4\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.mp4"
            ),
            HtmlTest(
                description: "JPG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.jpg\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.jpg"
            ),
            HtmlTest(
                description: "PNG URL in P - Paste image URL at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is ju<img src=\"https://github.com/stevengharris/MarkupEditor/foo.png\">st a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.png"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste an image URL")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    func testPasteLink() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Link in P - Paste link at insertion point in a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">just</a> a simple paragraph.</p>",
                startId: "p",     // Select "ju|st "
                startOffset: 10,
                endId: "p",
                endOffset: 10,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a> a simple paragraph.</p>",
                startId: "p",     // Select "just|"
                startOffset: 12,
                endId: "p",
                endOffset: 12,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of a word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is <a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>just a simple paragraph.</p>",
                startId: "p",     // Select "|just"
                startOffset: 8,
                endId: "p",
                endOffset: 8,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at beginning of paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\"><a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a>This is just a simple paragraph.</p>",
                startId: "p",     // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
            HtmlTest(
                description: "Link in P - Paste link at end of paragraph",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "<p id=\"p\">This is just a simple paragraph.<a href=\"https://github.com/stevengharris/MarkupEditor/foo.bogus\">https://github.com/stevengharris/MarkupEditor/foo.bogus</a></p>",
                startId: "p",     // Select "paragraph.|"
                startOffset: 32,
                endId: "p",
                endOffset: 32,
                pasteString: "https://github.com/stevengharris/MarkupEditor/foo.bogus"
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let expectation = XCTestExpectation(description: "Paste a link")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.pasteUrl(url: URL(string: test.pasteString!)) {
                            self.webView.getRawHtml() { pasted in
                                self.assertEqualStrings(expected: test.endHtml, saw: pasted)
                                expectation.fulfill()
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }
    
    // Repurpose the endHtml, undoHtml, and pasteString state in HtmlTest as commented below for search tests
    func testSearch() throws {
        let htmlTests: [HtmlTest] = [
            HtmlTest(
                description: "Exact word match",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "just",        // Search forward result
                undoHtml: "just",       // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "just"     // Search for
            ),
            HtmlTest(
                description: "Partial word match",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "us",          // Search forward result
                undoHtml: "us",         // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "us"       // Search for
            ),
            HtmlTest(
                description: "Mixed case word match",
                startHtml: "<p id=\"p\">This is just a SiMpLe paragraph.</p>",
                endHtml: "SiMpLe",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "simple"   // Search for
            ),
            HtmlTest(
                description: "Mixed case search for lowercase word",
                startHtml: "<p id=\"p\">This is just a simple paragraph.</p>",
                endHtml: "simple",      // Search forward result
                undoHtml: "simple",     // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "SiMpLe"   // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe",
                startHtml: "<p id=\"p\">This isn't just a simple paragraph.</p>",
                endHtml: "isn't",       // Search forward result
                undoHtml: "isn't",      // Search backward result
                startId: "p",           // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn't"     // Search for
            ),
            HtmlTest(
                description: "Search with apostrophe and quotes",
                startHtml: "<p id=\"p\">This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                startId: "p",                               // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn't just a \"simple\""      // Search for
            ),
            HtmlTest(
                description: "Search with smart quotes",
                startHtml: "<p id=\"p\">This isn't just a \"simple\" paragraph.</p>",
                endHtml: "\"simple\"",          // Search forward result
                undoHtml: "\"simple\"",         // Search backward result
                startId: "p",                   // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "“simple”"         // Search for
            ),
            HtmlTest(
                description: "Search with smart apostrophe",
                startHtml: "<p id=\"p\">This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't",               // Search forward result
                undoHtml: "isn't",              // Search backward result
                startId: "p",                   // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn’t"            // Search for
            ),
            HtmlTest(
                description: "Search with mixed smart apostrophe and quotes",
                startHtml: "<p id=\"p\">This isn't just a \"simple\" paragraph.</p>",
                endHtml: "isn't just a \"simple\"",         // Search forward result
                undoHtml: "isn't just a \"simple\"",        // Search backward result
                startId: "p",                               // Select "|This"
                startOffset: 0,
                endId: "p",
                endOffset: 0,
                pasteString: "isn’t just a “simple”"        // Search for
            ),
            HtmlTest(
                description: "Search relative to selection",
                startHtml: "<p id=\"p\">This is just a SiMpLe word in a sImPlE paragraph.</p>",
                endHtml: "sImPlE",      // Search forward result
                undoHtml: "SiMpLe",     // Search backward result
                startId: "p",           // Select "word|"
                startOffset: 26,
                endId: "p",
                endOffset: 26,
                pasteString: "simple"   // Search for
            ),
        ]
        for test in htmlTests {
            test.printDescription()
            let startHtml = test.startHtml
            let searchString = test.pasteString ?? ""
            let expectation = XCTestExpectation(description: "Search forward and backward")
            webView.setTestHtml(value: startHtml) {
                self.webView.getRawHtml { contents in
                    self.assertEqualStrings(expected: startHtml, saw: contents)
                    self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                        self.webView.search(for: searchString, direction: .forward) {
                            self.webView.getSelectionState() { state in
                                XCTAssertTrue(state.selection == test.endHtml)   // Selection extends beyond word!
                                self.webView.setTestRange(startId: test.startId, startOffset: test.startOffset, endId: test.endId, endOffset: test.endOffset, startChildNodeIndex: test.startChildNodeIndex, endChildNodeIndex: test.endChildNodeIndex) { result in
                                    self.webView.search(for: searchString, direction: .backward) {
                                        self.webView.getSelectionState() { state in
                                            // In some cases, selection extends beyond a word to include blanks. Not sure if this is a bug, frankly.
                                            XCTAssertTrue(state.selection == test.undoHtml)
                                            expectation.fulfill()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            wait(for: [expectation], timeout: 30)
        }
    }

}

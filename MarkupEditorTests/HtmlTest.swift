//
//  HtmlTest.swift
//  MarkupEditorTests
//
//  Created by Steven Harris on 4/6/22.
//

import Foundation
import MarkupEditor
import Testing

/// An HtmlTest embeds markers for the selection point(s) in the `startHtml`. The selection to/from are identified using `sel`.
/// On the JavaScript side, these markers are removed and the corresponding selection is set. The actual HTML that is tested and returned
/// from the test will not contain the embedded `sel` markers, so endHtml and undoHtml, if set, should not embed such markers.
///
/// The JSON file for each suite also contains `action` items for each test, which produces in function in JavaScript using the
/// Function constructor. Since we can't do that in Swift, we specify the `action` var as an async function, and then in each
/// test suite, we populate the `action` for each test. Occasionally (e.g., in `baseline`, no action is needed). Here we also
/// use `stringAction` in the case where the action return a String. In JavaScript, we can just test if the return is null, but in
/// Swift we have to type the return properly, and all of the existing MU methods execute a handler with argument if needed.
public class HtmlTest: Codable, CustomStringConvertible, CustomTestStringConvertible {
    public static var timeout: Double = 5
    public var description: String
    public var skipTest: String?
    public var skipSet: Bool
    public var skipUndoRedo: Bool
    public var sel: String
    public var startHtml: String
    public var endHtml: String
    public var undoHtml: String
    public var pasteString: String?
    public var action: (() async throws -> Void)?
    public var stringAction: (() async throws -> String?)?
    
    public var testDescription: String
    
    enum CodingKeys: String, CodingKey {
        case description = "description"
        case skipTest = "skipTest"
        case skipSet = "skipSet"
        case skipUndoRedo = "skipUndoRedo"
        case sel = "sel"
        case startHtml = "startHtml"
        case endHtml = "endHtml"
        case undoHtml = "undoHtml"
        case pasteString = "pasteString"
    }

    public init(
        description: String,
        skipTest: String? = nil,
        skipSet: Bool = false,
        skipUndoRedo: Bool = false,
        sel: String,
        startHtml: String,
        endHtml: String? = nil,
        undoHtml: String? = nil,
        pasteString: String? = nil
    ) {
        self.description = description
        self.skipTest = skipTest
        self.skipSet = skipSet
        self.skipUndoRedo = skipUndoRedo
        self.sel = sel
        self.startHtml = startHtml
        self.endHtml = endHtml ?? startHtml
        self.undoHtml = undoHtml ?? startHtml
        self.pasteString = pasteString
        self.testDescription = description
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        description = try values.decode(String.self, forKey: .description)
        skipTest = try values.decodeIfPresent(String.self, forKey: .skipTest)
        skipSet = try values.decodeIfPresent(Bool.self, forKey: .skipSet) ?? false
        skipUndoRedo = try values.decodeIfPresent(Bool.self, forKey: .skipUndoRedo) ?? false
        sel = try values.decodeIfPresent(String.self, forKey: .sel) ?? "|"
        startHtml = try values.decode(String.self, forKey: .startHtml)
        endHtml = try values.decodeIfPresent(String.self, forKey: .endHtml) ?? startHtml
        undoHtml = try values.decodeIfPresent(String.self, forKey: .undoHtml) ?? startHtml
        pasteString = try values.decodeIfPresent(String.self, forKey: .pasteString)
        testDescription = description
    }
    
    @MainActor
    public func run(in view: MarkupWKWebView) async {
        if skipTest != nil { return }
        if !skipSet {
            let html = await view.setTestHtml(startHtml, sel: sel)
            #expect(html == startHtml)
        }
        if let action {
            do {
                try await action()
            } catch {
                print("Error: \(error)")
                return
            }
            let html = await view.getTestHtml(sel: sel)
            #expect(html == endHtml)
        } else if let stringAction {
            let html: String?
            do {
                html = try await stringAction()
            } catch {
                print("Error: \(error)")
                return
            }
            #expect(html == endHtml)
        }
        if (action != nil || stringAction != nil) && !skipUndoRedo {
            await view.undo()
            let undoResult = await view.getTestHtml(sel: sel)
            #expect(undoResult == undoHtml)
            await view.redo()
            let redoResult = await view.getTestHtml(sel: sel)
            #expect(redoResult == endHtml)
        }
    }
    
}

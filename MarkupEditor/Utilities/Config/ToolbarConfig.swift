//
//  ToolbarConfig.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/24/26.
//

import OSLog

public struct ToolbarConfig: Codable {
    public var visibility: [String: Bool]
    public var ordering: [String: Int]
    public var insertBar: [String: Bool]
    public var formatBar: [String: Bool]
    public var styleMenu: [String: String?]
    public var styleBar: [String: Bool]
    public var tableMenu: [String: Bool]
    public var augmentation: [String: Bool?]
    public var icons: [String: String]
    
    
    private static func all() -> ToolbarConfig {
    #if SWIFT_PACKAGE
        let bundle = Bundle.module   // Bundle.module is only accessible within BaseTests
    #else
        let bundle = Bundle(for: MarkupWKWebView.self)
    #endif
        do {
            guard let path = bundle.path(forResource: "toolbarconfig", ofType: "json") else {
                fatalError("Toolbar config could not be found in bundle")
            }
            let url = URL(filePath: path, directoryHint: .notDirectory)
            let data = try Data(contentsOf: url)
            return try JSONDecoder().decode(ToolbarConfig.self, from: data)
        } catch let error {
            Logger.config.error("\(error.localizedDescription)")
            return none()
        }
    }
    
    public static func full() -> ToolbarConfig {
        return all()
    }
    
    public static func markdown(_ correction: Bool = false) -> ToolbarConfig {
        var markdown = all()
        markdown.visibility["correctionBar"] = correction
        markdown.formatBar["underline"] = false
        markdown.formatBar["subscript"] = false
        markdown.formatBar["superscript"] = false
        return markdown
    }
    
    public static func none() -> ToolbarConfig {
        ToolbarConfig(
            visibility: [:],
            ordering: [:],
            insertBar: [:],
            formatBar: [:],
            styleMenu: [:],
            styleBar: [:],
            tableMenu: [:],
            augmentation: [:],
            icons: [:]
        )
    }
    
    public static func fromJSON(_ string: String) -> ToolbarConfig {
        do {
            let json = removeJSONComments(string)    // In case it's JSONC
            let data = Data(json.utf8)
            return try JSONDecoder().decode(ToolbarConfig.self, from: data)
        } catch {
            return none()
        }
    }
    
    public func asJSON() -> String {
        let data = try! JSONEncoder().encode(self)
        return String(data: data, encoding: .utf8)!
    }
    
    static func removeJSONComments(_ input: String) -> String {
        var result = ""
        var index = input.startIndex
        
        while index < input.endIndex {
            let char = input[index]
            
            // Check for string literal - must skip over it without removing anything
            if char == "\"" {
                result.append(char)
                index = input.index(after: index)
                while index < input.endIndex {
                    let strChar = input[index]
                    result.append(strChar)
                    if strChar == "\\" {
                        // escaped character - append next char and skip
                        index = input.index(after: index)
                        if index < input.endIndex {
                            result.append(input[index])
                            index = input.index(after: index)
                        }
                    } else if strChar == "\"" {
                        index = input.index(after: index)
                        break
                    } else {
                        index = input.index(after: index)
                    }
                }
                continue
            }
            
            // Check for // single-line comment
            if char == "/" && input.index(after: index) < input.endIndex {
                let next = input[input.index(after: index)]
                if next == "/" {
                    // skip until end of line
                    while index < input.endIndex && input[index] != "\n" {
                        index = input.index(after: index)
                    }
                    continue
                }
                // Check for /* multi-line comment */
                if next == "*" {
                    index = input.index(after: index)
                    index = input.index(after: index)
                    while index < input.endIndex {
                        if input[index] == "*" {
                            let afterStar = input.index(after: index)
                            if afterStar < input.endIndex && input[afterStar] == "/" {
                                index = input.index(after: afterStar)
                                break
                            }
                        }
                        index = input.index(after: index)
                    }
                    continue
                }
            }
            
            result.append(char)
            index = input.index(after: index)
        }
        
        return result
    }
}

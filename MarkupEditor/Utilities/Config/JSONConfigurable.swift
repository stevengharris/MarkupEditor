//
//  JSONConfigurable.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/16/26.
//

import Foundation

/// A protocol for types that can be serialized to/from JSON strings with JSONC (commented JSON) support.
public protocol JSONConfigurable: Codable {
    static func fromJSON(_ string: String) -> Self?
    func asJSON() -> String?
    func asAttribute() -> String?
    static func removeJSONComments(_ input: String) -> String
}

public extension JSONConfigurable {
    
    /// Return Self derived by decoding the JSON `string`.
    /// The `string` can contain JSONC because comments are removed if present.
    static func fromJSON(_ string: String) -> Self? {
        let json = removeJSONComments(string)
        let data = Data(json.utf8)
        return try? JSONDecoder().decode(Self.self, from: data)
    }
    
    /// Return self encoded as a JSON string, or nil if there is an error.
    func asJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    /// Return self encoded as JSON but with double quotes escaped for use as an HTML attribute
    func asAttribute() -> String? {
        return asJSON()?.replacingOccurrences(of: "\"", with: "&quot;")
    }
    
    /// In the event `input` is JSONC, then return with comments removed so it is proper JSON.
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

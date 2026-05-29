//
//  String+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 2/27/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

extension String {
    
    /// A string with characters escaped for safe embedding in a JavaScript single-quoted string.
    /// Escapes single quotes, backslashes, and ASCII control characters.
    /// Backslash must be escaped so that sequences like `\<` in content
    /// are not silently consumed by JS string parsing.
    public var escaped: String {
        let unicode = self.unicodeScalars
        var newString = ""
        for char in unicode {
            if char.value == 39 || // 39 == ' in ASCII
                char.value == 92 || // 92 == \ in ASCII
                char.value < 9 ||  // 9 == horizontal tab in ASCII
                (char.value > 9 && char.value < 32) // < 32 == special characters in ASCII
            {
                let escaped = char.escaped(asASCII: true)
                newString.append(escaped)
            } else {
                newString.append(String(char))
            }
        }
        return newString
    }
    
    /// Return true if self is a valid URL
    public var isValidURL: Bool {
        guard !isEmpty else { return false }
        let detector = try! NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue)
        let matches = detector.matches(in: self, options: [], range: NSRange(location: 0, length: utf16.count))
        return matches.count == 1 && matches[0].range.length == utf16.count
    }
    
}

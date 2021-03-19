//
//  MarkupError.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/14/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// Errors specific to the MarkupEditor.
public enum MarkupError: Error {
    case notInsertable
    case notLinkable
    case prepareInsert
}

extension MarkupError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .notInsertable:
            return NSLocalizedString(
                "Selection must be between characters, not on a range of characters.",
                comment: ""
            )
            
        case .notLinkable:
            return NSLocalizedString(
                "Selection must be on a range of text or an existing link.",
                comment: ""
            )
        case .prepareInsert:
            return NSLocalizedString(
                "Could not prepare for the insert operation.",
                comment: ""
            )
        }
    }
}

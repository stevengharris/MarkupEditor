//
//  MarkupUIDelegate+Extensions.swift
//  UIKitDemo
//
//  Created by Steven Harris on 4/13/21.
//

import MarkupEditor

extension MarkupUIDelegate {
    
    /// Take action when the user wants to create a new document
    public func markupNewDocument(handler: ((URL?)->Void)? = nil) {}

    /// Take action when the user wants to edit an existing document
    public func markupExistingDocument(handler: ((URL?)->Void)? = nil) {}

    /// Take action when the user wants to save the document
    public func markupSaveDocument() {}
    
}

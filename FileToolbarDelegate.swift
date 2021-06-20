//
//  FileToolbarDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/13/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

protocol FileToolbarDelegate {
    func newDocument(handler: ((URL?)->Void)?)
    func existingDocument(handler: ((URL?)->Void)?)
    func rawDocument()
}

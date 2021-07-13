//
//  FileToolbarDelegate.swift
//  MarkupEditor
//
//  Created by Steven Harris on 4/13/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

import Foundation

/// The FileToolbarDelegate handles requests from the FileToolbar.
protocol FileToolbarDelegate {
    func newDocument(handler: ((URL?)->Void)?)
    func existingDocument(handler: ((URL?)->Void)?)
    func rawDocument()
}

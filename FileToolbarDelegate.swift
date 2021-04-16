//
//  UserToolbarDelegate.swift
//  UIKitDemo
//
//  Created by Steven Harris on 4/13/21.
//

import Foundation

protocol FileToolbarDelegate {
    func newDocument(handler: ((URL?)->Void)?)
    func existingDocument(handler: ((URL?)->Void)?)
    func rawDocument()
}

//
//  MarkupEditable.swift
//  MarkupEditor
//
//  Created by Steven Harris on 12/26/23.
//

import Foundation

public protocol MarkupEditable {
    var cssClass: String { get }
    var attributes: EditableAttributes { get }
}

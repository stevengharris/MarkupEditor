//
//  MarkupAlert.swift
//  MarkupEditor
//
//  Created by Steven Harris on 3/15/21.
//  Copyright © 2021 Steven Harris. All rights reserved.
//

public typealias MarkupAlertType = MarkupAlert.AlertType

/// The types of alerts that can be shown by the MarkupToolbar and which are acted upon my the MarkupUIDelegate.
public struct MarkupAlert: Identifiable {
    public enum AlertType {
        case codeblock
        case image
        case line
        case link
        case sketch
        case table
        case unknown
    }
    public var id: AlertType { type }
    public let type: AlertType
}

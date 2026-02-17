//
//  UIView+Extensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 9/5/22.
//

#if !os(macOS)

import UIKit

extension UIView {

    public func closestVC() -> UIViewController? {
        var responder: UIResponder? = self
        while responder != nil {
            if let vc = responder as? UIViewController {
                return vc
            }
            responder = responder?.next
        }
        return nil
    }
}

#endif

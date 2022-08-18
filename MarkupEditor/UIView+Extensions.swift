//
//  UIView+Modifiers.swift
//  MarkupEditor
//
//  Created by Steven Harris on 8/10/22.
//

import UIKit

extension UIView {
    
    public func findViewController() -> UIViewController? {
        if let nextResponder = self.next as? UIViewController {
            return nextResponder
        } else if let nextResponder = self.next as? UIView {
            return nextResponder.findViewController()
        } else {
            return nil
        }
    }
    
}

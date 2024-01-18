//
//  MarkupWKWebView+CustomExtensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

import MarkupEditor

extension MarkupWKWebView {
    
    /// Invoke the MU.assignClasses method on the JavaScript side that was added-in via custom.js.
    public func assignClasses(_ handler: (()->Void)? = nil) {
        evaluateJavaScript("MU.assignClasses()") { result, error in
            if let error {
                print(error.localizedDescription)
            }
            handler?()
        }
    }
    
}

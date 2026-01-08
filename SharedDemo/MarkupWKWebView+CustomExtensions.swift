//
//  MarkupWKWebView+CustomExtensions.swift
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

import MarkupEditor

extension MarkupWKWebView {
    
    /// Invoke the MU.wordcount method on the JavaScript side that was added-in via custom.js.
    public func wordcount(_ handler: ((Int?)->Void)? = nil) {
        executeJavaScript("MU.wordCount()") { result, error in
            if let error {
                print(error.localizedDescription)
            }
            handler?(result as? Int)
        }
    }
    
}

//
//  custom.js
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

import { MU } from "./markup-editor.js"

/**
 * A public method that can be invoked from MarkupWKWebView to return
 * the number of words in the HTML document using a simpleminded approach.
 * Invoking this method requires an extension to MarkupWKWebView.
 */
MU.wordCount = function() {
    const text = MU.activeView()?.state.doc.textContent
    return text ? text.trim().split(/\s+/).filter(Boolean).length : 0
};

//
//  custom.js
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

/**
 * A public method that can be invoked from MarkupWKWebView to return
 * the number of words in the HTML document using a simpleminded approach.
 * Invoking this method requires an extension to MarkupWKWebView.
 */
MU.wordCount = function() {
    let wordCount = 0;
    const styles = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'CODE'];
    for (const style of styles) {
        const elements = document.querySelectorAll(style);
        for (const element of elements) {
            wordCount += element.textContent.trim().split(' ').length;
        }
    };
    return wordCount;
};

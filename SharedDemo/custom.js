//
//  custom.js
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

/**
 * A public method that can be invoked from MarkupWKWebView to execute the
 * assignment of classes to h1 and h2 elements, so that custom.css styling
 * will show up. Invoking this method requires an extension to MarkupWKWebView
 * which can be called from the MarkupDelegate.markupLoaded method.
 */
MU.assignClasses = function() {
    const h1Elements = document.getElementsByTagName('h1');
    for (let i = 0; i < h1Elements.length; i++) {
        element = h1Elements[i];
        element.classList.add('title');
    };
    const h2Elements = document.getElementsByTagName('h2');
    for (let i = 0; i < h2Elements.length; i++) {
        element = h2Elements[i];
        element.classList.add('subtitle');
    };
};

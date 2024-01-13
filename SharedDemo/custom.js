//
//  custom.js
//  MarkupEditor
//
//  Created by Steven Harris on 1/13/24.
//

const _assignClasses = function() {
    const h1Elements = document.getElementsByTagName('h1');
    for (let i = 0; i < h1Elements.length; i++) {
        element = h1Elements[i];
        element.classList.add('title');
    };
    const h2Elements = document.getElementsByTagName('h2');
    for (let i = 0; i < h1Elements.length; i++) {
        element = h2Elements[i];
        element.classList.add('subtitle');
    };
};

_assignClasses()

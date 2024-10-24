/**
 * Copyright © 2021-2022 Steven Harris. All rights reserved.
 *
 * This code was inspired by the original RichEditorView by cjwirth
 * at https://github.com/cjwirth/RichEditorView. Subsequent versions by cbess
 * at https://github.com/cbess/RichEditorView/ and YoomamaFTW
 * at https://github.com/YoomamaFTW/RichEditorView were also very helpful.
 * The licenses for those repositories are BSD-3.
 * Code here has almost no recognizable parts from those repositories.
 *
 * The license for this code and the MarkupEditor repository is MIT,
 * found at https://github.com/stevengharris/MarkupEditor/blob/main/LICENSE.
 *
 * For a historical perspective, some of the changes from the original
 * RichEditorView include:
 *
 * 1. Replacement of all execCommand usage, with the exception of a very narrow
 *      case to support undo/redo.
 * 2. Use of window.webkit.messageHandlers for all callbacks to Swift.
 * 3. Use of selectionState to capture the state of document.getSelection()
 *      for usage on the Swift side.
 * 4. Extensive use of event listeners to call back into Swift when things
 *      happen on the Javascript side, avoiding round-trips.
 * 5. Proper support for undo/redo, which previously was handled by the browser
 *      when using execCommand.
 * 6. Full support for inserting, removing, and modifying links, images, and tables,
 *      including undo/redo operations.
 */

'use strict';

/********************************************************************************
 * Bootstrapping
 * MU is for Markup.
 * Public functions called from Swift are MU.*
 * Private functions used internally are const _*
 */
//MARK: Bootstrapping

const MU = {};

/**
 * _selectedID is the id of the contentEditable DIV containing the currently selected element.
 */
let _selectedID;

/**
 * Called to set attributes to the editor div, typically to make it contenteditable,
 * but also to set spellcheck and autocorrect.
 */
MU.setTopLevelAttributes = function(jsonString) {
};

/**
 * Called to load user script and CSS before loading html.
 *
 * The scriptFile and cssFile are loaded in sequence, with the single 'loadedUserFiles'
 * callback only happening after their load events trigger. If neither scriptFile
 * nor cssFile are specified, then the 'loadedUserFiles' callback happens anyway,
 * since this ends up driving the loading process further.
 */
MU.loadUserFiles = function(scriptFile, cssFile) {
    if (scriptFile) {
        if (cssFile) {
            _loadUserScriptFile(scriptFile, function() { _loadUserCSSFile(cssFile) });
        } else {
            _loadUserScriptFile(scriptFile, function() { _loadedUserFiles() });
        }
    } else if (cssFile) {
        _loadUserCSSFile(cssFile);
    } else {
        _loadedUserFiles();
    }
};

/**
 * Callback into Swift.
 * The message is handled by the WKScriptMessageHandler.
 * In our case, the WKScriptMessageHandler is the MarkupCoordinator,
 * and the userContentController(_ userContentController:didReceive:)
 * function receives message as a WKScriptMessage.
 *
 * @param {String} message     The message, which might be a JSONified string
 */
const _callback = function(message) {
    window.webkit.messageHandlers.markup.postMessage(message);
};

const _callbackInput = function() {
    window.webkit.messageHandlers.markup.postMessage('input' + (_selectedID ?? ''));
}

const _loadedUserFiles = function() {
    _callback('loadedUserFiles');
}

/**
 * Called to load user script before loading html.
 */
const _loadUserScriptFile = function(file, callback) {
    let body = document.getElementsByTagName('body')[0];
    let script = document.createElement('script');
    script.type = 'text/javascript';
    script.addEventListener('load', callback);
    script.setAttribute('src', file);
    body.appendChild(script);
};

/**
 * Called to load user CSS before loading html if userCSSFile has been defined for this MarkupWKWebView
 */
const _loadUserCSSFile = function(file) {
    let head = document.getElementsByTagName('head')[0];
    let link = document.createElement('link');
    link.rel = 'stylesheet';
    link.type = 'text/css';
    link.addEventListener('load', function() { _loadedUserFiles() });
    link.href = file;
    head.appendChild(link);
};

/**
 * The 'ready' callback lets Swift know the editor and this js is properly loaded.
 *
 * Note for history, replaced window.onload with this eventListener.
 */
window.addEventListener('load', function() {
    _callback('ready');
});

/**
 * Capture all unexpected runtime errors in this script, report to the Swift side for debugging.
 *
 * There is not any useful debug information for users, but as a developer,
 * you can place a break in this method to examine the call stack.
 * Please file issues for any errors captured by this function,
 * with the call stack and reproduction instructions if at all possible.
 */
window.addEventListener('error', function(ev) {
    const muError = new MUError('Internal', 'Break at MUError(\'Internal\'... in Safari Web Inspector to debug.');
    muError.callback()
});

/**
 * If the window is resized, let the Swift side know so that it can adjust its height tracking if needed.
 */
window.addEventListener('resize', function() {
    _callback('updateHeight');
});

/**
 * MUError captures internal errors and makes it easy to communicate them to the
 * Swift side.
 *
 * Usage is generally via the statics defined here, altho supplementary info can
 * be provided to the MUError instance when useful.
 *
 * Alert is set to true when the user might want to know an error occurred. Because
 * this is generally the case, it's set to true by default and certain MUErrors that
 * are more informational in nature are set to false. For example, BackupNullRange
 * happens when the user clicks outside of text, etc, so is fairly normal.
 *
 * Note that there is at least one instance of the Swift side notifying its MarkupDelegate
 * of an error using this same approach, but originating on the Swift side. That happens
 * in MarkupWKWebView.copyImage if anything goes wrong, because the copying to the
 * clipboard is handled on the Swift side.
 */
//MARK: Error Reporting
class MUError {
    static BackupNullRange = new MUError('BackupNullRange', 'Attempt to back up a null range.', null, false);
    static RestoreNullRange = new MUError('RestoreNullRange', 'Attempt to restore a null range.', null, false);
    static CantUndoListEnter = new MUError('CantUndoListEnter', 'Child node could not be found in childNodeIndices.');
    static CantInsertHtml = new MUError('CantInsertHtml', 'Top-level element could not be found from selection point.');
    static CantInsertInList = new MUError('CantInsertInList', 'Selection prior to insertList is not collapsed inside of a TEXT_NODE.');
    static CantFindElement = new MUError('CantFindElement', 'The element id could not be found.', null, false);
    static CantFindContainer = new MUError('CantFindContainer', 'The startContainer or endContainer for a range could not be found.', null, false);
    static InvalidFillEmpty = new MUError('InvalidFillEmpty', 'The node was not an ELEMENT_NODE or was not empty.');
    static InvalidJoinTextNodes = new MUError('InvalidJoinTextNodes', 'The text nodes to join did not conform to expectations.');
    static InvalidJoinElements = new MUError('InvalidJoinElements', 'The elements to join did not conform to expectations.');
    static InvalidSplitTextNode = new MUError('InvalidSplitTextNode', 'Node passed to _splitTextNode must be a TEXT_NODE.');
    static InvalidSplitTextRoot = new MUError('InvalidSplitTextRoot', 'Root name passed to _splitTextNode was not a parent of textNode.');
    static InvalidSplitElement = new MUError('InvalidSplitElement', 'Node passed to _splitElement must be an ELEMENT_NODE.');
    static InvalidSplitElementRoot = new MUError('InvalidSplitElementRoot', 'Root name passed to _splitElement was not a parent of element.');
    static NoDiv = new MUError('NoDiv', "A div could not be found to return HTML from.");
    static NoEndContainerInRange = new MUError('NoEndContainerInRange', 'Range endContainer not found in _nodesWithNamesInRange');
    static NoNewTag = new MUError('NoNewTag', 'No tag was specified to change the existing tag to.');
    static NoSelection = new MUError('NoSelection', 'Selection has been lost or is invalid.');
    static NotInList = new MUError('NotInList', 'Selection is not in a list or listItem.');
    static PatchFormatNodeNotEmpty = new MUError('PatchFormatNodeNotEmpty', 'Neither the anchorNode nor focusNode is empty.');
    static PatchFormatNodeNotSiblings = new MUError('PatchFormatNodeNotSiblings', 'The anchorNode and focusNode are not siblings.')
    
    constructor(name, message, info, alert=true) {
        this.name = name;
        this.message = message;
        this.info = info;
        this.alert = alert;
    };
    
    setInfo(info) {
        this.info = info
    };
    
    messageDict() {
        return {
            'messageType' : 'error',
            'code' : this.name,
            'message' : this.message,
            'info' : this.info,
            'alert' : this.alert
        };
    };
    
    callback() {
        _callback(JSON.stringify(this.messageDict()));
    };
};

/********************************************************************************
 * Public entry point for search.
 *
 * When text is empty, search is canceled.
 *
 * CAUTION: Search must be cancelled once started, or Enter will be intercepted
 * to mean searcher.searchForward()/searchBackward()
 */
//MARK: Search

MU.searchFor = function(text, direction, activate) {
};

MU.deactivateSearch = function() {
};

MU.cancelSearch = function() {
}

const minImageSize = 20;

/********************************************************************************
 * Paste
 */
//MARK: Paste

/**
 * Do a custom paste operation of "text only", which we will extract from the html
 * ourselves. The pasteboard text has newlines removed and we want something
 * prettier that behaves well in the MarkupEditor.
 *
 * The trick here is that we want to use the same code to paste text as we do for
 * HTML, but we want to paste something that is the MarkupEditor-equivalent of
 * unformatted text.
 */
MU.pasteText = function(html) {
    const fragment = _patchPasteHTML(html);             // Remove all the cruft first, leaving BRs
    const minimalHTML = _minimalHTML(fragment);         // Reduce to MarkupEditor-equivalent of "plain" text
    _pasteHTML(minimalHTML);
};

/**
 * Do a custom paste operation of html.
 */
MU.pasteHTML = function(html) {
    const fragment = _patchPasteHTML(html);             // Remove all the cruft first, leaving BRs
    const fragmentHTML = _fragmentHTML(fragment)        // Extract html again from cleaned up fragment
    _pasteHTML(fragmentHTML);
};

/**
 * Return the innerHTML string contained in fragment
 */
const _fragmentHTML = function(fragment) {
    const div = document.createElement('div');
    div.appendChild(fragment);
    return div.innerHTML;
};

/**
 * Return a minimal "unformatted equivalent" version of the HTML that is in fragment.
 *
 * This equivalent is derived by making all top-level nodes into <P> and removing
 * formatting and links. However, we leave TABLE, UL, and OL alone, so they still
 * come in as tables and lists, but with formatting removed.
 */
const _minimalHTML = function(fragment) {
    // Create a div to hold fragment so that we can getElementsByTagName on it
    const div = document.createElement('div');
    div.appendChild(fragment);
    // Then run thru the various minimization steps on the div
    _minimalStyle(div);
    _minimalFormat(div);
    _minimalLink(div);
    return div.innerHTML;
};

/**
 * Replace all styles in the div with 'P'.
 */
const _minimalStyle = function(div) {
    _minimalStyleTags.forEach(tag => {
        // Reset elements using getElementsByTagName as we go along or the
        // replaceWith potentially messes the up loop over elements.
        let elements = div.getElementsByTagName(tag);
        let element = (elements.length > 0) ? elements[0] : null;
        while (element) {
            let newElement = document.createElement('P');
            newElement.innerHTML = element.innerHTML;
            element.replaceWith(newElement);
            elements = div.getElementsByTagName(tag);
            element = (elements.length > 0) ? elements[0] : null;
        };
    });
};

/**
 * Replace all formats in the div with unformatted text
 */
const _minimalFormat = function(div) {
    _formatTags.forEach(tag => {
        // Reset elements using getElementsByTagName as we go along or the
        // replaceWith potentially messes the up loop over elements.
        let elements = div.getElementsByTagName(tag);
        let element = (elements.length > 0) ? elements[0] : null;
        while (element) {
            let template = document.createElement('template');
            template.innerHTML = element.innerHTML;
            const newElement = template.content;
            element.replaceWith(newElement);
            elements = div.getElementsByTagName(tag);
            element = (elements.length > 0) ? elements[0] : null;
        };
    });
};

/**
 * Replace all links with their text only
 */
const _minimalLink = function(div) {
    // Reset elements using getElementsByTagName as we go along or the
    // replaceWith potentially messes the up loop over elements.
    let elements = div.getElementsByTagName('A');
    let element = (elements.length > 0) ? elements[0] : null;
    while (element) {
        if (element.getAttribute('href')) {
            element.replaceWith(document.createTextNode(element.text));
        } else {
            // This link has no href and is therefore not allowed
            element.parentNode.removeChild(element);
        };
        elements = div.getElementsByTagName('A');
        element = (elements.length > 0) ? elements[0] : null;
    };
};

const _pasteHTML = function(html, oldUndoerData, undoable=true) {
};

/**
 * Patch html by removing all of the spans, etc, so that a template created from it
 * is "clean" by MarkupEditor standards.
 */
const _patchPasteHTML = function(html) {
    
    // We need a document fragment from the html so we can use its dom for cleaning up.
    const element = _fragmentFrom(html);
    
    // Sometimes (e.g., iOS Note) the fragment is an entire HTML document.
    // In this case, we only want the body, but let's clean up these items
    // that should be outside of it just in case something wacky is going on.
    _cleanUpTypesWithin(['head', 'meta', 'title', 'style'], element);
    const body = element.body ?? element;
    
    // Now do the extensive clean up required for the body
    _cleanUpSpansWithin(body);
    _cleanUpDivsWithin(body);
    _cleanUpTypesWithin(['label', 'button'], body)
    _cleanUpAttributesWithin('style', body);
    _cleanUpAttributesWithin('class', body);
    _cleanUpEmptyTextNodes(body);
    _cleanUpPREs(body);
    _cleanUpOrphanNodes(body);
    _cleanUpBRs(body);
    _cleanUpNewlines(body);
    _cleanUpTabs(body);
    _cleanUpAliases(body);
    _prepImages(body);
    return body;
};

/**
 * Return a document fragment element derived from the html.
 */
const _fragmentFrom = function(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    return template.content;
};

/********************************************************************************
 * Getting and setting document contents
 */
//MARK: Getting and Setting Document Contents

/**
 * Clean out the document and replace it with an empty paragraph
 */
MU.emptyDocument = function() {
};

/**
 * Set the contents of the editor element
 *
 * @param {String} contents The HTML for the editor element
 */
MU.setHTML = function(contents, select=true) {
};

/**
 * Placeholder
 */
MU.setPlaceholder = function(text) {
};

/**
 * Return the height of the editor element that encloses the text.
 *
 * The padding-block is set in CSS to allow touch selection outside of text on iOS.
 * An unfortunate side-effect of that setting is that getBoundingClientRect() returns
 * a height that has nothing to do with the actual text, because it's been padded.
 * A workaround for this is to get the computed style for editor using
 * window.getComputedStyle(editor, null), and then asking that for the height. It does
 * not include padding. This kind of works, except that I found the height changed as
 * soon as I add a single character to the text. So, for example, it shows 21px when it
 * opens with just a single <p>Foo</p>, but once you add a character to the text, the
 * height shows up as 36px. If you remove padding-block, then the behavior goes away.
 * To work around the problem, we set the padding block to 0 before getting height, and
 * then set it back afterward. With this change, both the touch-outside-of-text works
 * and the height is reported accurately. Height needs to be reported accurately for
 * auto-sizing of a WKWebView based on its contents.
 */
MU.getHeight = function() {
};

/*
 * Pad the bottom of the text in editor to fill fullHeight.
 *
 * Setting padBottom pads the editor all the way to the bottom, so that the
 * focus area occupies the entire view. This allows long-press on iOS to bring up the
 * context menu anywhere on the screen, even when text only occupies a small portion
 * of the screen.
 */
MU.padBottom = function(fullHeight) {
};

/**
 * Focus immediately, leaving range alone
 */
MU.focus = function() {
};

/**
 * Reset the selection to the beginning of the document
 */
MU.resetSelection = function() {
};

/**
 * Get the contents of the editor element.
 *
 * If pretty, then the text will be nicely formatted for reading.
 * If clean, the spans and empty text nodes will be removed first.
 *
 * Note: Clean is needed to avoid the selected ResizableImage from being
 * passed-back with spans around it, which is what are used internally to
 * represent the resizing handles and box around the selected image.
 * However, this content of the DOM is only for visualization within the
 * MarkupEditor and should not be included with the HTML contents. It is
 * left here as an option in case it's needed for debugging.
 *
 * @return {string} The HTML for the editor element
 */
MU.getHTML = function(pretty="true", clean="true", divID) {
    return "";
};

/**
 * Add a div with id to parentId.
 *
 * Return a string indicating what happened if there was a problem; else nil.
 */
MU.addDiv = function(id, parentId, cssClass, jsonAttributes, htmlContents) {
};

MU.removeDiv = function(id) {
};

MU.addButton = function(id, parentId, cssClass, label) {
};

MU.removeButton = function(id) {
};


MU.focusOn = function(id) {
};

MU.scrollIntoView = function(id) {
};

/**
 * Remove all divs in the document
 */
MU.removeAllDivs = function() {
}


/********************************************************************************
 * Formatting
 * 1. Formats (B, I, U, DEL, CODE, SUB, SUP) are toggled off and on
 * 2. Formats can be nested, but not inside themselves; e.g., B cannot be within B
 */
//MARK: Formatting

MU.toggleBold = function() {
    _toggleFormat('B');
};

MU.toggleItalic = function() {
    _toggleFormat('I');
};

MU.toggleUnderline = function() {
    _toggleFormat('U');
};

MU.toggleStrike = function() {
    _toggleFormat('DEL');
};

MU.toggleCode = function() {
    _toggleFormat('CODE');
};

MU.toggleSubscript = function() {
    _toggleFormat('SUB');
};

MU.toggleSuperscript = function() {
    _toggleFormat('SUP');
};

/**
 * Turn the format tag off and on for selection.
 * Called directly on undo/redo so that nothing new is pushed onto the undo stack
 *
 * type must be called using uppercase
 */
const _toggleFormat = function(type, undoable=true) {
};

/********************************************************************************
 * Styling
 * 1. Styles (P, H1-H6) are applied to blocks
 * 2. Unlike formats, styles are never nested (so toggling makes no sense)
 * 3. Every block should have some style
 */
//MARK: Styling

/**
 * Find/verify the oldStyle for the selection and replace it with newStyle.
 * Replacement for execCommand(formatBlock).
 *
 * @param {String}  oldStyle    One of the styles P or H1-H6 that exists at selection.
 * @param {String}  newStyle    One of the styles P or H1-H6 to replace oldStyle with.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.replaceStyle = function(oldStyle, newStyle, undoable=true) {
};

/********************************************************************************
 * Lists
 */
//MARK: Lists

/**
 * Turn the list tag off and on for selection, doing the right thing
 * for different cases of selections.
 * If the selection is in a list type that is different than newListTyle,
 * we need to create a new list and make the selection appear in it.
 *
 * @param {String}  newListType     The kind of list we want the list item to be in if we are turning it on or changing it.
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.toggleListItem = function(newListType, restoreContainingList=false, undoable=true) {
};

/********************************************************************************
 * Indenting and Outdenting
 */
//MARK: Indenting and Outdenting

const DentType = {
    Indent: 'Indent',
    Outdent: 'Outdent'
};

/**
 * Do a context-sensitive indent.
 *
 * If in a list, indent the item to a more nested level in the list if appropriate.
 * If in a blockquote, add another blockquote to indent further.
 * Else, put into a blockquote to indent.
 *
 */
MU.indent = function(undoable=true) {
};

/**
 * Do a context-sensitive outdent.
 *
 * If in a list, outdent the item to a less nested level in the list if appropriate.
 * If in a blockquote, remove a blockquote to outdent further.
 * Else, do nothing.
 *
 */
MU.outdent = function(undoable=true) {
};

/**
 * Called before beginning a modal popover on the Swift side, to enable the selection
 * to be restored by endModalInput
 */
MU.startModalInput = function() {
}

/**
 * Called typically after cancelling a modal popover on the Swift side, since
 * normally the result of using the popover is to modify the DOM and reset the
 * selection.
 */
MU.endModalInput = function() {
}

/********************************************************************************
 * Clean up to avoid ugly HTML
 */
//MARK: Clean Up

/**
 * Due to the presence of "-webkit-text-size-adjust: 100%;" in css,
 * WebKit may be inserting styling for elements many places, but particularly
 * on deletion as it tries to maintain the proper appearance. However, even
 * with that removed, we still end up with spans that try to enforce the
 * previous "style" (for example, H1) font size. We also end up with styles
 * imposed on format elements. All of these need to be removed, since we
 * don't support arbitrary font size changes.
 * Spans need to be removed and replaced with their innerHTML.
 */
MU.cleanUpHTML = function() {
};

const _cleanUpTypesWithin = function(names, node) {
    const ucNames = names.map((name) => name.toUpperCase());
    const childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        const child = childNodes[i];
        if (ucNames.includes(child.nodeName)) {
            node.removeChild(child);
        } else if (child.childNodes.length > 0) {
            _cleanUpTypesWithin(names, child);
        };
    };
};

/**
 * Remove meta tags contained in node, typically a document fragment.
 */
const _cleanUpMetas = function(node) {
    const childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        const child = childNodes[i];
        if (child.nodeName === 'META') {
            node.removeChild(child);
        } else {
            _cleanUpMetas(child);
        }
    };
};

/*
 * Put any direct childNodes of node that are in "standalone" BRs into paragraphs
 */
const _cleanUpBRs = function(node) {
    const childNodes = node.childNodes;
    let child = node.firstChild;
    while (child) {
        if (_isBRElement(child)) {
            const nextChild = child.nextSibling;
            const nextNextChild = (nextChild) ? nextChild.nextSibling : null;
            if ((!nextChild) || (nextChild && (!_isTextNode(nextChild) && !_isBRElement(nextChild)))) {
                // This BR is not part of a text string, it's just sitting alone
                const p = document.createElement('p');
                p.appendChild(document.createElement('br'));
                child.replaceWith(p);
            };
            child = nextNextChild;
        } else {
            child = child.nextSibling;
        };
    };
};

/**
 * Patch up text nodes that have newlines
 */
const _cleanUpNewlines = function(node) {
    const childNodes = node.childNodes;
    let child = node.firstChild;
    while (child) {
        if (_isTextNode(child)) {
            _patchNewlines(child);
        } else {
            _cleanUpNewlines(child);
        };
        child = child.nextSibling;
    };
};

/**
 * Patch up text nodes that have tabs
 */
const _cleanUpTabs = function(node) {
    let child = node.firstChild;
    while (child) {
        let nextChild = child.nextSibling;
        if (_isElementNode(child)) {
            _cleanUpTabs(child);
        } else if (_isTextNode(child)) {
            const rawContent = child.textContent;
            if (rawContent.includes('\t')) {
                child.textContent = rawContent.replaceAll('\t', '\xA0\xA0\xA0\xA0'); // Four spaces for tabs, don't @ me
            };
        };
        child = nextChild;
    };
};

/*
 * Replace PREs with Ps if they contain a text node; else,
 * leave their contents in place without the PRE.
 */
const _cleanUpPREs = function(node) {
    const childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        let child = childNodes[i];
        if (_isPreElement(child)) {
            const p = document.createElement('p');
            const template = document.createElement('template');
            template.innerHTML = child.innerHTML;
            const newElement = template.content;
            p.appendChild(newElement);
            child.replaceWith(p);
        } else if (_isElementNode(child)) {
            _cleanUpPREs(child);
        }
    };
};

/**
 * Replace all elements with names we don't recognize with ones we do.
 *
 * These are currently <strong> -> <b> and <em> -> <i>.
 */
const _cleanUpAliases = function(node) {
    const _aliases = {'STRONG' : 'B', 'EM' : 'I'}
    let childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        _cleanUpAliases(childNodes[i]);
    };
    let alias = _aliases[node.nodeName];
    if (alias) {
        const aliasElement = document.createElement(alias);
        const template = document.createElement('template');
        template.innerHTML = node.innerHTML;
        const newElement = template.content;
        aliasElement.appendChild(newElement);
        node.replaceWith(aliasElement);
    };
};

/**
 * Do a depth-first traversal from node, removing spans starting at the leaf nodes.
 *
 * @return {Int}    The number of spans removed
 */
const _cleanUpSpansWithin = function(node, spansRemoved) {
    return _cleanUpSpansDivsWithin(node, 'SPAN', spansRemoved);
};

/**
 * Do a depth-first traversal from node, removing divs starting at the leaf nodes.
 *
 * @return {Int}    The number of divs removed
 */
const _cleanUpDivsWithin = function(node, divsRemoved) {
    return _cleanUpSpansDivsWithin(node, 'DIV', divsRemoved);
}

/**
 * Do a depth-first traversal from node, removing divs/spans starting at the leaf nodes.
 *
 * @return {Int}    The number of divs/spans removed
 */
const _cleanUpSpansDivsWithin = function(node, type, removed) {
    removed = removed ?? 0;
    // Nested span/divs show up as children of a span/div.
    const children = node.children;
    let child = (children.length > 0) ? children[0] : null;
    while (child) {
        let nextChild = child.nextElementSibling;
        removed = _cleanUpSpansDivsWithin(child, type, removed);
        child = nextChild;
    };
    if (node.nodeName === type) {
        removed++;
        if (node.childNodes.length > 0) {   // Use childNodes because we need text nodes
            const template = document.createElement('template');
            template.innerHTML = node.innerHTML;
            const newElement = template.content;
            node.replaceWith(newElement);
        } else {
            node.parentNode.removeChild(node);
        };
    };
    return removed;
};

/**
 * Do a depth-first traversal from node, removing attributes starting at the leaf nodes.
 *
 * @return {Int}    The number of attributes removed
 */
const _cleanUpAttributesWithin = function(attribute, node) {
    let attributesRemoved = 0;
    const children = node.children;
    if (children.length > 0) {
        for (let i=0; i<children.length; i++) {
            attributesRemoved += _cleanUpAttributesWithin(attribute, children[i]);
        };
    };
    if ((node.nodeType === Node.ELEMENT_NODE) && (node.hasAttribute(attribute))) {
        attributesRemoved++;
        node.removeAttribute(attribute);
    };
    return attributesRemoved;
};

/*
 * Do a depth-first traversal from node, removing all empty text nodes at the leaf nodes.
 */
const _cleanUpEmptyTextNodes = function(node) {
    let child = node.firstChild;
    while (child) {
        let nextChild = child.nextSibling;
        if (_isElementNode(child)) {
            _cleanUpEmptyTextNodes(child);
        } else if (_isTextNode(child) && _isEmpty(child)) {
            child.parentNode.removeChild(child);
        };
        child = nextChild;
    };
};

/*
 * Traverse all immediate childnodes of node. If they are not part of _topLevelNodes,
 * then put the childNode in a <p> element and call it a day. During paste, we sometimes
 * receive <a> and text nodes that are not properly styled (by the MarkupEditor definition),
 * so we will put them in a "normal" paragraph so we don't lose them.
 */
const _cleanUpOrphanNodes = function(node) {
    const children = node.childNodes;
    let child = children.isEmpty ? null : children[0];
    while (child) {
        let nextSib = child.nextSibling;
        if (!_topLevelTags.includes(child.nodeName)) {
            // Create a new <p> and put this non-top-level node in it
            const newChild = document.createElement('p');
            node.insertBefore(newChild, nextSib);
            newChild.appendChild(child);
            // Keep putting children in the same p until we hit a top-level tag
            while (nextSib && !_topLevelTags.includes(nextSib.nodeName)) {
                let nextNextSib = nextSib.nextSibling;
                newChild.appendChild(nextSib);
                nextSib = nextNextSib;
            };
        }
        child = nextSib;
    };
};

const _prepImages = function(node) {
    const images = node.querySelectorAll('img');
    for (let i = 0; i < images.length; i++) {
        const image = images[i];
        image.addEventListener('load', function() {_prepImage(image)});
        image.addEventListener('error', function() {_prepImage(image)});
    };
};

/**
 * Replace newlines with <br> in a text node; return trailingText if patched, else node
 */
const _patchNewlines = function(node) {
    if (node.nodeType !== Node.TEXT_NODE) {
        return node;
    };
    const rawContent = node.textContent;
    // Ref: https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/String/split
    // If separator appears at the beginning (or end) of the string, it still
    // has the effect of splitting, resulting in an empty (i.e. zero length) string
    // appearing at the first (or last) position of the returned array.
    const lines = rawContent.split('\n');
    if (lines.length === 1) { return node };
    const insertTarget = node.nextSibling;
    let line, nextLine, p, textNode;
    for (let i = 0; i < lines.length; i++) {
        line = lines[i];
        nextLine = (i < lines.length - 1) ? lines[i + 1]  : null;
        if (((i === 0) || (i === lines.length - 1)) && (line.length === 0)) {
            // If we have a newline at beginning or end but are in a formatTag, then
            // do nothing; otherwise, insert an editable <p><br></p> line.
            if (!_formatTags.includes(node.parentNode.nodeName)) {
                p = document.createElement('p');
                textNode = document.createElement('br');
                p.appendChild(textNode);
                node.parentNode.insertBefore(p, insertTarget);
            };
        } else {
            textNode = document.createTextNode(_patchWhiteSpace(line, 'LEADING'));
            node.parentNode.insertBefore(textNode, insertTarget);
            if ((i < lines.length - 1) && (nextLine && (nextLine.length > 0))) {
                node.parentNode.insertBefore(document.createElement('br'), insertTarget);
            };
        };
    };
    node.parentNode.removeChild(node);
    return textNode;
};

/********************************************************************************
 * Selection
 */
//MARK: Selection

/**
 * Define various arrays of tags used to represent concepts on the Swift side and internally.
 *
 * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
 */
const _paragraphStyleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'];                  // All paragraph styles

const _formatTags = ['B', 'I', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];                       // All possible (nestable) formats

const _listTags = ['UL', 'OL'];                                                         // Types of lists

const _tableTags = ['TABLE', 'THEAD', 'TBODY', 'TD', 'TR', 'TH'];                       // All tags associated with tables

const _styleTags = _paragraphStyleTags.concat(_listTags.concat(['LI', 'BLOCKQUOTE']));  // Identify insert-before point in table/list

const _listStyleTags = _paragraphStyleTags.concat(['BLOCKQUOTE']);                      // Possible containing blocks in a list

const _minimalStyleTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE'];           // Convert to 'P' for MU.pasteText

const _monitorEnterTags = _listTags.concat(['TABLE', 'BLOCKQUOTE']);                    // Tags we monitor for Enter

const _monitorIndentTags = _listTags.concat(['BLOCKQUOTE']);                            // Tags we monitor for Tab or Ctrl+]

const _topLevelTags = _paragraphStyleTags.concat(_listTags.concat(['TABLE', 'BLOCKQUOTE']));    // Allowed top-level tags w/in editor

const _voidTags = ['BR', 'IMG', 'AREA', 'COL', 'EMBED', 'HR', 'INPUT', 'LINK', 'META', 'PARAM'] // Tags that are self-closing

/**
 * Populate a dictionary of properties about the current selection
 * and return it in a JSON form. This is the primary means that the
 * Swift side finds out what the selection is in the document, so we
 * can tell if the selection is in a bolded word or a list or a table, etc.
 *
 * @return {String}      The stringified dictionary of selectionState.
 */
MU.getSelectionState = function() {
    return JSON.stringify({});
};

/********************************************************************************
 * Testing support
 */
//MARK: Testing Support

/**
 * For testing purposes, set selection based on elementIds and offsets
 * Like range, the startOffset and endOffset are number of characters
 * when startElement is #text; else, child number. Optionally specify
 * startChildNodeIndex and/or endChildNodeIndex to identify a child
 * within startElement and/or endElement. These optional params are
 * useful for list testing particularly.
 *
 * @param   {String}  startElementId        The id of the element to use as startContainer for the range.
 * @param   {Int}     startOffset           The offset into the startContainer for the range.
 * @param   {String}  endElementId          The id of the element to use as endContainer for the range.
 * @param   {Int}     endOffset             The offset into the endContainer for the range.
 * @param   {Int}     startChildNodeIndex   Index into startElement.childNodes to find startChild.
 * @param   {Int}     endChildNodeIndex     Index into endElement.childNodes to find endChild.
 * @return  {Boolean}                       True if both elements are found; else, false.
 */
MU.setRange = function(startElementId, startOffset, endElementId, endOffset, startChildNodeIndex, endChildNodeIndex) {
    return false;
};

/**
 * For testing purposes, invoke undo by direct input to undoer.
 * Using MU.undo() from a test does not work properly.
 */
MU.testUndo = function() {
};

/**
 * For testing purposes, invoke redo by direct input to undoer.
 * Using MU.redo() from a test does not work properly.
 */
MU.testRedo = function() {
};

/**
 * For testing purposes, invoke _doBlockquoteEnter programmatically.
 *
 * After the _doBlockquoteEnter, subsequent ops for undo and redo need to
 * be done using MU.testUndo
 */
MU.testBlockquoteEnter = function() {
};

/**
 * For testing purposes, invoke _doListEnter programmatically.
 *
 * After the _doListEnter, subsequent ops for undo and redo need to
 * be done using MU.testUndo
 */
MU.testListEnter = function() {
};

/**
 * For testing purposes, invoke extractContents() on the selected range
 * to make sure the selection is as expected.
 */
MU.testExtractContents = function() {
};

/**
 * For testing purposes, execute _patchPasteHTML and return the resulting
 * html as a string. Testing in this way lets us do simple pasteHTML tests with
 * clean HTML and test the _patchPasteHTML functionality separately. The
 * purpose of _patchPasteHTML is to return "clean" HTML from arbitrary HTML
 * (typically) obtained from the paste buffer on the Swift side.
 */
MU.testPasteHTMLPreprocessing = function(html) {
    const fragment = _patchPasteHTML(html);
    const fragmentHTML = _fragmentHTML(fragment);
    return fragmentHTML;
};

/**
 * For testing purposes, execute _patchPasteHTML followed by _minimalHTML
 * and return the resulting html as a string. Testing in this way lets us do
 * simple pasteText tests with clean HTML and test the preprocessing functionality
 * separately. The purpose of _patchPasteHTML is to return "clean" HTML from
 * arbitrary HTML (typically) obtained from the paste buffer on the Swift side,
 * which is then combined with _minimalHTML to get a MarkupEditor-equivalent of
 * unformatted text.
 */
MU.testPasteTextPreprocessing = function(html) {
    const fragment = _patchPasteHTML(html);
    const minimalHTML = _minimalHTML(fragment);
    return minimalHTML;
};

/********************************************************************************
 * Links
 */
//MARK: Links

/**
 * Insert a link to url. When the selection is collapsed, the url is inserted
 * at the selection point as a link.
 *
 * When done, re-select the range and back it up.
 *
 * @param {String}  url             The url/href to use for the link
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.insertLink = function(url, undoable=true) {
};

/**
 * Remove the link at the selection.
 *
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.deleteLink = function(undoable=true) {
};

/********************************************************************************
 * Images
 */
//MARK: Images

/**
 * Insert the image at src with alt text, signaling updateHeight when done loading.
 * All insert operations that involve user interaction outside of JavaScript
 * need to be preceded by backupSelection so that selection can be restored prior
 * to the insert* operation.
 * We leave the selection after the inserted image.
 * The operation will cause a selectionChange event.
 *
 * @param {String}              src         The url of the image.
 * @param {String}              alt         The alt text describing the image.
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 * @return {HTML Image Element}             The image element that was created, used for undo/redo.
 */
MU.insertImage = function(src, alt, undoable=true) {
    return null;
};

/**
 * Modify the attributes of the image at selection.
 * Scale is a percentage like '80' where null means 100%.
 * Scale is always expressed relative to full scale.
 *
 * @param {String}              src         The url of the image.
 * @param {String}              alt         The alt text describing the image.
 * @param {Int}                 scale       The scale as a percentage of original's naturalWidth/Height.
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 */
MU.modifyImage = function(src, alt, scale, undoable=true) {
};


MU.cutImage = function() {
};

/**
 * Callback invoked after the load or error event on an image
 *
 * The purpose of this method is to set attributes of every image to be
 * selectable and resizable and to have width and height preset.
 */
const _prepImage = function(img) {
    let changedHTML = false;
    if (img.getAttribute('class') !== 'resize-image') {
        img.setAttribute('class', 'resize-image');          // Make it resizable
        changedHTML = true;
    }
    if (img.getAttribute('tabindex') !== "-1") {
        img.setAttribute('tabindex', -1);                   // Make it selectable
        changedHTML = true;
    }
    // Per https://www.youtube.com/watch?v=YM3KszYmn58, we always want dimensions
    if (!img.getAttribute('width')) {
        img.setAttribute('width', Math.max(img.naturalWidth ?? 0, minImageSize));
        changedHTML = true;
    };
    if (!img.getAttribute('height')) {
        img.setAttribute('height', Math.max(img.naturalHeight ?? 0, minImageSize));
        changedHTML = true;
    };
    // For history, 'focusout' just never fires, either for image or the resizeContainer
    img.addEventListener('focusin', _focusInImage);         // Allow resizing when focused
    // Only notify the Swift side if we modified the HTML
    if (changedHTML) {
        _callbackInput() // Because we changed the html
    } else {
        _callback('updateHeight')
    }
};

/********************************************************************************
 * Tables
 */
//MARK: Tables

/**
 * Insert an empty table with the specified number of rows and cols.
 * All insert operations that involve user interaction outside of JavaScript
 * need to be preceded by backupSelection so that range can be restored prior
 * to the insert* operation.
 * We leave the selection in the first cell of the first row.
 * The operation will cause a selectionChange event.
 *
 * @param   {Int}                 rows        The number of rows in the table to be created.
 * @param   {Int}                 cols        The number of columns in the table to be created.
 * @param   {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 * @return  {HTML Table Element}              The table element that was created, used for undo/redo.
 */
MU.insertTable = function(rows, cols, undoable=true) {
};

/**
 * Delete the entire table at the selection.
 *
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteTable = function(undoable=true) {
};

/**
 * Add a row before or after the current selection, whether it's in the header or body.
 * For rows, AFTER = below; otherwise above.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new row goes relative to the selection.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addRow = function(direction, undoable=true) {
};

/**
 * Add a column before or after the current selection, whether it's in the header or body.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new column goes relative to the selection.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addCol = function(direction, undoable=true) {
};

/**
 * Add a header to the table at the selection.
 *
 * @param {Boolean} colspan     Whether the header should span all columns of the table or not.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addHeader = function(colspan=true, undoable=true) {
};

/**
 * Delete the row at the selection point in the table.
 *
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteRow = function(undoable=true) {
};

/**
 * Delete the column at the selection point in the table.
 *
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteCol = function(undoable=true) {
};

/**
 * Set the class of the table to style it using CSS.
 * The default draws a border around everything.
 */
MU.borderTable = function(border, undoable=true) {
};

/********************************************************************************
 * Common private functions
 */
//MARK: Common Private Functions

/**
 * Return the depth of node in parents contained in nodeNames. If the node is
 * a top-level element, then depth===0.
 */
const _depthWithin = function(node, nodeNames) {
    let depth = 0;
    let parentElement = _findFirstParentElementInNodeNames(node, nodeNames);
    while (parentElement) {
        depth++;
        parentElement = _findFirstParentElementInNodeNames(parentElement.parentNode, nodeNames);
    };
    return depth;
};

/**
 * Return true if element and all of its children are empty or
 * if it is an empty text node.
 *
 * For example, <li><p></p></li> is empty, as is <li></li>, while
 * <li><p> <p></li> and <li> <li> will have text elements and are
 * therefore not empty.
 */
const _isEmpty = function(element) {
    let empty;
    if (_isTextNode(element)) {
        let textContent = element.textContent;
        // Text is empty if it's all whitespace and contains no nbsp
        empty = (textContent.trim().length === 0) && (!textContent.includes('\u00A0'));
    } else if (_isImageElement(element)) {
        empty = false;
    } else {
        empty = true;
        const childNodes = element.childNodes;
        for (let i = 0; i < childNodes.length; i++) {
            empty = _isEmpty(childNodes[i]);
            if (!empty) { break };
        };
    }
    return empty;
};

const _isEmptyParagraph = function(element) {
    return _isEmpty(element) && _isParagraphStyleElement(element) && _isBRElement(element.firstChild);
};

const _isEmptyPlaceholder = function(element) {
    return _isParagraphStyleElement(element) && (element.childNodes.length == 1) && _isNonPrintingCharacter(element.firstChild);
};

const _isNonPrintingCharacter = function(element) {
    return _isTextNode(element) && (element.textContent === '\u200B')
}

const _isEmptyTD = function(element) {
    return _isEmpty(element) && (element.nodeName === 'TD');
};

/**
 * Return whether node is a div
 */
const _isDiv = function(node) {
    return node && (node.nodeName === 'DIV');
};

/**
 * Return whether node is a fragment
 */
const _isFragment = function(node) {
    return node && (node.nodeName === '#document-fragment');
}

/**
 * Return whether node is a button
 */
const _isButton = function(node) {
    return node && (node.nodeName === 'BUTTON');
}

/**
 * Return whether node is a textNode or not
 */
const _isTextNode = function(node) {
    return node && (node.nodeType === Node.TEXT_NODE);
};

/**
 * Return whether node is an ELEMENT_NODE or not
 */
const _isElementNode = function(node) {
    return node && (node.nodeType === Node.ELEMENT_NODE);
};

const _isPreElement = function(node) {
    return node && (node.nodeName === 'PRE');
}

/**
 * Return whether node is a style element; i.e., its nodeName is in _styleTags
 */
const _isStyleElement = function(node) {
    return _isElementNode(node) && _styleTags.includes(node.nodeName);
};

/**
 * Return whether node is an allowable top-level node in MarkupEditor.
 *
 * These are nodes that are allowed children in a contentEditable area.
 */
const _isTopLevelElement = function(node) {
    return node && _topLevelTags.includes(node.nodeName);
};

/**
 * Return whether node is one of the _paragraphStyleTags
 */
const _isParagraphStyleElement = function(node) {
    return _paragraphStyleTags.includes(node.nodeName);
};

/**
 * Return whether node is a format element; i.e., its nodeName is in _formatTags
 */
const _isFormatElement = function(node) {
    return _isElementNode(node) && _formatTags.includes(node.nodeName);
};

/**
 * Return whether node is a list element (i.e., either UL or OL)
 */
const _isListElement = function(node) {
    return node && _listTags.includes(node.nodeName);
};

/**
 * Return whether a node is a list item element (LI)
 */
const _isListItemElement = function(node) {
    return node && (node.nodeName === 'LI');
};

/**
 * Return whether node is an image element
 */
const _isImageElement = function(node) {
    return node && (node.nodeName === 'IMG');
};

/**
 * Return whether node is a BR element
 */
const _isBRElement = function(node) {
    return node && (node.nodeName === 'BR');
};

/**
 * Return whether node is a TABLE element
 */
const _isTableElement = function(node) {
    return node && (node.nodeName === 'TABLE');
};

/**
 * Return whether node is an empty element with only a BR in it.
 *
 * This is the minimal selectable element, because we cannot set
 * selection inside of something like <p></p>, only <p><br></p>.
 */
const _isEmptyElement = function(node) {
    return _isElementNode(node) && (node.childNodes.length === 1) && _isBRElement(node.firstChild)
};

/**
 * Return whether node is a BLOCKQUOTE element
 */
const _isBlockquoteElement = function(node) {
    return node && (node.nodeName === 'BLOCKQUOTE')
};

/**
 * Return whether node has a void tag (i.e., does not need a terminator)
 */
const _isVoidNode = function(node) {
    return node && (_voidTags.includes(node.nodeName));
};

/**
 * Return whether node is a link
 */
const _isLinkNode = function(node) {
    return node && (node.nodeName === 'A');
};

/**
 * Return a boolean indicating if s is a white space
 *
 * @param   {String}      s     The string that might be white space
 * @return {Boolean}            Whether it's white space
 */
const _isWhiteSpace = function(s) {
    return /\s/g.test(s);
};

/**
 * Callback into Swift to show a string in the Xcode console, like console.log()
 */
const _consoleLog = function(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    _callback(JSON.stringify(messageDict));
};

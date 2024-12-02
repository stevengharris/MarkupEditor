/*
 Edit only from within MarkupEditor/rollup/src. After running "npm rollup build",
 the rollup/dist/markupmirror.umd.js is copied into MarkupEditor/Resources/markup.js.
 That file contains the combined ProseMirror code along with markup.js.
 */

import {AllSelection, TextSelection, NodeSelection} from 'prosemirror-state'
import {DOMParser, DOMSerializer} from 'prosemirror-model'
import {toggleMark, wrapIn, lift} from 'prosemirror-commands'
import {wrapInList, liftListItem} from 'prosemirror-schema-list'
import {
    addRowBefore, 
    addRowAfter, 
    addColumnBefore, 
    addColumnAfter, 
    deleteRow, 
    deleteColumn, 
    deleteTable, 
    CellSelection, 
    mergeCells,
    toggleHeaderRow,
} from 'prosemirror-tables'

export class DivView {
    constructor(node, view, getPos) {
        this.node = node;
        const div = document.createElement('div');
        div.setAttribute('id', node.attrs.id);
        div.setAttribute('parentId', node.attrs.parentId);
        div.setAttribute('class', node.attrs.cssClass);
        div.setAttribute('editable', node.attrs.editable.toString());
        div.innerHTML = node.attrs.htmlContents;
        // Note that the click is reported using handleClick on the EditorView.
        // Here we have access to the node id and can specialize for divs.
        div.addEventListener('click', (ev) => {
            _selectedID = node.attrs.id;
        })
        // Note: The div never sees an 'input' event. This is done using 
        // handleTextInput on the EditorView.
        this.dom = div;
        this.contentDOM = div;
    }

}

export class ButtonView {
    constructor(node, view, getPos) {
        const button = document.createElement('button');
        button.setAttribute('id', node.attrs.id);
        button.setAttribute('parentId', node.attrs.parentId);
        button.setAttribute('class', node.attrs.cssClass);
        button.setAttribute('type', 'button');
        button.innerHTML = node.attrs.label;
        button.addEventListener('click', () => {
            const id = node.attrs.id;
            const rect = view.coordsAtPos(getPos())
            _callback(
                JSON.stringify({
                    'messageType' : 'buttonClicked',
                    'id' : id,
                    'rect' : {x: rect.left, y: rect.top, width: rect.right - rect.left, height: rect.bottom - rect.top}
                })
            )
        });
        this.dom = button;
        this.contentDom = button;
    }
}

// The view used to support resizable images, as installed in main.js.
// Many thanks to this thread: https://discuss.prosemirror.net/t/image-resize/1489
// and the accompanying Glitch project https://glitch.com/edit/#!/toothsome-shoemaker
export class ImageView {
    constructor(node, view, getPos) {    
      const outer = document.createElement("span")
      outer.style.position = "relative"
      outer.style.display = "inline-block"
      outer.style.lineHeight = "0"; // necessary so the bottom right arrow is aligned nicely
      
      const img = document.createElement("img")
      img.setAttribute("src", node.attrs.src)
      img.style.width = "100%"
      // If the img node has no width attr, get it from naturalWidth after loading.
      // Note that outer.style.width is the same, but a CSS style is a string+px.
      if (node.attrs.width) {
        outer.style.width = `${node.attrs.width}px`
      } else {
        img.onload = function(e) {
            node.attrs.width = e.target.naturalWidth
            outer.style.width = `${node.attrs.width}px`
        }
      }

      const handle = document.createElement("span")
      handle.style.position = "absolute"
      handle.style.bottom = "0px"
      handle.style.right = "0px"
      handle.style.width = "10px"
      handle.style.height = "10px"
      handle.style.border = "3px solid black"
      handle.style.borderTop = "none"
      handle.style.borderLeft = "none"
      handle.style.display = "none"
      handle.style.cursor = "nwse-resize"
      
      // Establish the startWidth for the span containing the img
      handle.onmousedown = function(e){
        e.preventDefault()
        
        const startX = e.pageX;
        const startWidth = node.attrs.width ?? 20;
        
        // While mouse is down, track movement and update width    
        const onMouseMove = (e) => {
          const currentX = e.pageX;
          const diffInPx = currentX - startX
        
          node.attrs.width = startWidth + diffInPx
          outer.style.width = `${node.attrs.width}px`
        }
        
        // Modify the state when mouse comes up, reset selection
        const onMouseUp = (e) => {        
          e.preventDefault()
          
          document.removeEventListener("mousemove", onMouseMove)
          document.removeEventListener("mouseup", onMouseUp)
        
          const transaction = view.state.tr.setNodeMarkup(getPos(), null, {src: node.attrs.src, width: node.attrs.width})
          transaction.setSelection(new NodeSelection(transaction.doc.resolve(getPos())))
          view.dispatch(transaction)
          stateChanged()
        }
        
        document.addEventListener("mousemove", onMouseMove)
        document.addEventListener("mouseup", onMouseUp)
      }
      
      outer.appendChild(handle)
      outer.appendChild(img)
          
      this.dom = outer
      this.img = img
      this.handle = handle
    }
    
    selectNode() {
      this.img.classList.add("ProseMirror-selectednode")
      this.handle.style.display = ""
      selectionChanged()
    }
  
    deselectNode() {
      this.img.classList.remove("ProseMirror-selectednode")
      this.handle.style.display = "none"
      selectionChanged()
    }
}

const minImageSize = 20;

const DentType = {
    Indent: 'Indent',
    Outdent: 'Outdent'
};

/**
 * Define various arrays of tags used to represent concepts on the Swift side and internally.
 *
 * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
 */
const _paragraphStyleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'];                  // All paragraph styles

// Add STRONG and EM (leaving B and I) to support default ProseMirror output   
const _formatTags = ['B', 'STRONG', 'I', 'EM', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];       // All possible (nestable) formats

const _listTags = ['UL', 'OL'];                                                         // Types of lists

const _tableTags = ['TABLE', 'THEAD', 'TBODY', 'TD', 'TR', 'TH'];                       // All tags associated with tables

const _styleTags = _paragraphStyleTags.concat(_listTags.concat(['LI', 'BLOCKQUOTE']));  // Identify insert-before point in table/list

const _listStyleTags = _paragraphStyleTags.concat(['BLOCKQUOTE']);                      // Possible containing blocks in a list

const _minimalStyleTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE'];           // Convert to 'P' for pasteText

const _monitorEnterTags = _listTags.concat(['TABLE', 'BLOCKQUOTE']);                    // Tags we monitor for Enter

const _monitorIndentTags = _listTags.concat(['BLOCKQUOTE']);                            // Tags we monitor for Tab or Ctrl+]

const _topLevelTags = _paragraphStyleTags.concat(_listTags.concat(['TABLE', 'BLOCKQUOTE']));    // Allowed top-level tags w/in editor

const _voidTags = ['BR', 'IMG', 'AREA', 'COL', 'EMBED', 'HR', 'INPUT', 'LINK', 'META', 'PARAM'] // Tags that are self-closing

/**
 * _selectedID is the id of the contentEditable DIV containing the currently selected element.
 */
let _selectedID = null;

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
/*
class MUError {

    constructor(name, message, info, alert=true) {
        this.name = name;
        this.message = message;
        this.info = info;
        this.alert = alert;
    };
    
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
    static NoDiv = new MUError('NoDiv', 'A div could not be found to return HTML from.');
    static NoEndContainerInRange = new MUError('NoEndContainerInRange', 'Range endContainer not found in _nodesWithNamesInRange');
    static NoNewTag = new MUError('NoNewTag', 'No tag was specified to change the existing tag to.');
    static NoSelection = new MUError('NoSelection', 'Selection has been lost or is invalid.');
    static NotInList = new MUError('NotInList', 'Selection is not in a list or listItem.');
    static PatchFormatNodeNotEmpty = new MUError('PatchFormatNodeNotEmpty', 'Neither the anchorNode nor focusNode is empty.');
    static PatchFormatNodeNotSiblings = new MUError('PatchFormatNodeNotSiblings', 'The anchorNode and focusNode are not siblings.')
    
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
*/

/**
 * Called to set attributes to the editor div, typically to make it contenteditable,
 * but also to set spellcheck and autocorrect.
 */
export function setTopLevelAttributes(jsonString) {
};

/**
 * Called to load user script and CSS before loading html.
 *
 * The scriptFile and cssFile are loaded in sequence, with the single 'loadedUserFiles'
 * callback only happening after their load events trigger. If neither scriptFile
 * nor cssFile are specified, then the 'loadedUserFiles' callback happens anyway,
 * since this ends up driving the loading process further.
 */
export function loadUserFiles(scriptFile, cssFile) {
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
function _callback(message) {
    window.webkit.messageHandlers.markup.postMessage(message);
};

function _callbackInput() {
    // I'd like to use nullish coalescing on _selectedID, but rollup's tree-shaking
    // actively removes it, at least until I do something with it.
    let source = '';
    if (_selectedID !== null) {
        source = _selectedID;
    };
    window.webkit.messageHandlers.markup.postMessage('input' + source);
};

function _loadedUserFiles() {
    _callback('loadedUserFiles');
};

/**
 * Called to load user script before loading html.
 */
function _loadUserScriptFile(file, callback) {
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
function _loadUserCSSFile(file) {
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
    //const muError = new MUError('Internal', 'Break at MUError(\'Internal\'... in Safari Web Inspector to debug.');
    //muError.callback()
});

/**
 * If the window is resized, let the Swift side know so that it can adjust its height tracking if needed.
 */
window.addEventListener('resize', function() {
    _callback('updateHeight');
});

/********************************************************************************
 * Public entry point for search.
 *
 * When text is empty, search is canceled.
 *
 * CAUTION: Search must be cancelled once started, or Enter will be intercepted
 * to mean searcher.searchForward()/searchBackward()
 */
//MARK: Search

export function searchFor(text, direction, activate) {
};

export function deactivateSearch() {
};

export function cancelSearch() {
}

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
export function pasteText(html) {
    const fragment = _patchPasteHTML(html);             // Remove all the cruft first, leaving BRs
    const minimalHTML = _minimalHTML(fragment);         // Reduce to MarkupEditor-equivalent of "plain" text
    _pasteHTML(minimalHTML);
};

/**
 * Do a custom paste operation of html.
 */
export function pasteHTML(html) {
    const fragment = _patchPasteHTML(html);             // Remove all the cruft first, leaving BRs
    const fragmentHTML = _fragmentHTML(fragment)        // Extract html again from cleaned up fragment
    _pasteHTML(fragmentHTML);
};

/**
 * Return the innerHTML string contained in fragment
 */
function _fragmentHTML(fragment) {
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
function _minimalHTML(fragment) {
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
function _minimalStyle(div) {
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
function _minimalFormat(div) {
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
function _minimalLink(div) {
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

function _pasteHTML(html, oldUndoerData) {
};

/**
 * Patch html by removing all of the spans, etc, so that a template created from it
 * is "clean" by MarkupEditor standards.
 */
function _patchPasteHTML(html) {
    
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
function _fragmentFrom(html) {
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
export function emptyDocument() {
    _selectedID = null;
    setHTML('<p></p>');
};

/**
 * Get the contents of the div with id `divID` or of the full doc.
 *
 * If pretty, then the text will be nicely formatted for reading.
 * If clean, the spans and empty text nodes will be removed first.
 *
 * Note: Clean is needed to avoid the selected ResizableImage from being
 * passed-back with spans around it, which is what are used internally to
 * represent the resizing handles and box around the selected image.
 * However, this content of the DOM is only for visualization within the
 * MarkupEditor and should not be included with the HTML contents. It is
 * available here with clean !== true as an option in case it's needed 
 * for debugging.
 *
 * @return {string} The HTML for the div with id `divID` or of the full doc.
 */
export function getHTML(pretty='true', clean='true', divID) {
    const prettyHTML = pretty === 'true';
    const cleanHTML = clean === 'true';
    const divNode = (divID) ? _getNode(divID)?.node : view.state.doc;
    if (!divNode) return ""
    const editor = DOMSerializer.fromSchema(view.state.schema).serializeFragment(divNode.content);
    let text;
    if (cleanHTML) {
        _cleanUpDivsWithin(editor);
        _cleanUpSpansWithin(editor);
    };
	if (prettyHTML) {
        text = _allPrettyHTML(editor);
    } else {
        const div = document.createElement('div');
        div.appendChild(editor);
        text = div.innerHTML;
    };
    return text;
};

/**
 * Return a pretty version of editor contents.
 *
 * Insert a newline between each top-level element so they are distinct
 * visually and each top-level element is in a contiguous text block vertically.
 *
 * @return {String}     A string showing the raw HTML with tags, etc.
 */
const _allPrettyHTML = function(fragment) {
    let text = '';
    const childNodes = fragment.childNodes;
    const childNodesLength = childNodes.length;
    for (let i = 0; i < childNodesLength; i++) {
        let topLevelNode = childNodes[i];
        text += _prettyHTML(topLevelNode, '', '', i === 0);
        if (i < childNodesLength - 1) { text += '\n' };
    }
    return text;
};

/**
 * Return a decently formatted/indented version of node's HTML.
 *
 * The inlined parameter forces whether to put a newline at the beginning
 * of the text. By passing it in rather than computing it from node, we
 * can avoid putting a newline in front of the first element in _allPrettyHTML.
 */
const _prettyHTML = function(node, indent, text, inlined) {
    const nodeName = node.nodeName.toLowerCase();
    const nodeIsText = _isTextNode(node);
    const nodeIsElement = _isElementNode(node);
    const nodeIsInlined = inlined || _isInlined(node);  // allow inlined to force it
    const nodeHasTerminator = !_isVoidNode(node);
    const nodeIsEmptyElement = nodeIsElement && (node.childNodes.length === 0);
    if (nodeIsText) {
        text += _replaceAngles(node.textContent);
    } else if (nodeIsElement) {
        const terminatorIsInlined = nodeIsEmptyElement || (_isInlined(node.firstChild) && _isInlined(node.lastChild));
        if (!nodeIsInlined) { text += '\n' + indent };
        text += '<' + nodeName;
        const attributes = node.attributes;
        for (let i = 0; i < attributes.length; i++) {
            const attribute = attributes[i];
            text += ' ' + attribute.name + '=\"' + attribute.value + '\"';
        };
        text += '>';
        node.childNodes.forEach(childNode => {
            text = _prettyHTML(childNode, indent + '    ', text, _isInlined(childNode));
        });
        if (nodeHasTerminator) {
            if (!terminatorIsInlined) { text += '\n' + indent };
            text += '</' + nodeName + '>';
        };
        if (!nodeIsInlined && !terminatorIsInlined) {
            indent = indent.slice(0, -4);
        };
    };
    return text;
};

/**
 * Return a new string that has all < replaced with &lt; and all > replaced with &gt;
 */
const _replaceAngles = function(textContent) {
    return textContent.replaceAll('<', '&lt;').replaceAll('>', '&gt;');
};

/**
 * Return whether node should be inlined during the prettyHTML assembly. An inlined node
 * like <I> in a <P> ends up looking like <P>This is an <I>italic</I> node</P>.
 */
const _isInlined = function(node) {
    return _isTextNode(node) || _isFormatElement(node) || _isLinkNode(node) || _isVoidNode(node)
};

/**
 * Set the contents of the editor
 *
 * @param {String} contents The HTML for the editor
 */
export function setHTML(contents, select=true) {
    const state = window.view.state;
    const doc = state.doc;
    const tr = state.tr;
    const div = document.createElement('div');
    div.innerHTML = contents;
    const node = DOMParser.fromSchema(state.schema).parse(div, { preserveWhiteSpace: true });
    const selection = new AllSelection(doc);
    const transaction = tr
        .setSelection(selection)
        .replaceSelectionWith(node, false)
        .setSelection(TextSelection.near(tr.doc.resolve(0)))
        .scrollIntoView()
    const newState = state.apply(transaction);
    view.updateState(newState);
    if (select) view.focus();
};

/**
 * Placeholder
 */
export function setPlaceholder(text) {
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
export function getHeight() {
};

/*
 * Pad the bottom of the text in editor to fill fullHeight.
 *
 * Setting padBottom pads the editor all the way to the bottom, so that the
 * focus area occupies the entire view. This allows long-press on iOS to bring up the
 * context menu anywhere on the screen, even when text only occupies a small portion
 * of the screen.
 */
export function padBottom(fullHeight) {
};

/**
 * Focus immediately, leaving range alone
 */
export function focus() {
    view.focus()
};

/**
 * Reset the selection to the beginning of the document
 */
export function resetSelection() {
};

/**
 * Add a div with id to parentId.
 */
export function addDiv(id, parentId, cssClass, jsonAttributes, htmlContents) {
    const divNodeType = view.state.schema.nodes.div;
    const div = document.createElement('div');
    div.innerHTML = htmlContents ?? "";
    const divSlice = DOMParser.fromSchema(view.state.schema).parseSlice(div, { preserveWhiteSpace: true });
    const editableAttributes = (jsonAttributes && JSON.parse(jsonAttributes)) ?? {};
    const editable = editableAttributes.contenteditable === true;
    const divNode = divNodeType.create({id, parentId, cssClass, editable, htmlContents}, divSlice.content);
    const transaction = view.state.tr;
    if (parentId && (parentId !== 'editor')) {
        // Find the div that is the parent of the one we are adding
        const {node, pos} = _getNode(parentId)
        if (node) {
            // Insert the div inside of its parent as a new child of the existing div
            const divPos = pos + node.nodeSize - 1;
            transaction.insert(divPos, divNode)
            //transaction.setMeta("muDiv", {cssClass: cssClass, fromPos: divPos, toPos: divPos + divNode.nodeSize});
            view.dispatch(transaction);
        }
    } else {
        // Add the div to the end of the document, replacing the empty paragraph node 
        // at that position if it exists (e.g., when the doc is empty)
        const nodeSelection = NodeSelection.atEnd(transaction.doc);
        const node = nodeSelection.$anchor.node();
        if ((node.type == view.state.schema.nodes.paragraph) && (node.childCount === 0)) {
            // Replace the last empty paragraph with divNode
            const divPos = nodeSelection.from;
            nodeSelection.replaceWith(transaction, divNode);
            //transaction.setMeta("muDiv", {cssClass: cssClass, fromPos: divPos, toPos: divPos + divNode.nodeSize});
        } else {
            // Otherwise, append this div to the end of the document
            const divPos = transaction.doc.content.size;
            transaction.insert(divPos, divNode);
            //transaction.setMeta("muDiv", {cssClass: cssClass, fromPos: divPos, toPos: divPos + divNode.nodeSize});
        }
        view.dispatch(transaction);
    };
};

export function removeDiv(id) {
    const {node, pos} = _getNode(id)
    if (view.state.schema.nodes.div === node?.type) {
        const selection = view.state.selection;
        const nodeSelection = new NodeSelection(view.state.doc.resolve(pos));
        const transaction = view.state.tr
            .setSelection(nodeSelection)
            .deleteSelection();
        const newSelection = TextSelection.create(transaction.doc, selection.from, selection.to);
        transaction.setSelection(newSelection);
        view.dispatch(transaction);
    };
};

export function addButton(id, parentId, cssClass, label) {
    const buttonNodeType = view.state.schema.nodes.button;
    const button = document.createElement('button');
    button.setAttribute('id', id);
    button.setAttribute('parentId', parentId);
    button.setAttribute('class', cssClass);
    button.setAttribute('type', 'button');
    button.appendChild(document.createTextNode(label));
    const buttonSlice = DOMParser.fromSchema(view.state.schema).parseSlice(button);
    const buttonNode = buttonNodeType.create({id, parentId, cssClass, label}, buttonSlice.content);
    const transaction = view.state.tr;
    if (parentId && (parentId !== 'editor')) {
        // Find the div that is the parent of the button we are adding
        const {node, pos} = _getNode(parentId)
        if (node) {   // Will always be a buttonGroup div that might be empty
            // Insert the div inside of its parent as a new child of the existing div
            const divPos = pos + node.nodeSize - 1;
            transaction.insert(divPos, buttonNode);
            view.dispatch(transaction);
        }
    }
};

export function removeButton(id) {
    const {node, pos} = _getNode(id)
    if (view.state.schema.nodes.button === node?.type) {
        const nodeSelection = new NodeSelection(view.state.doc.resolve(pos));
        const transaction = view.state.tr
            .setSelection(nodeSelection)
            .deleteSelection()
        view.dispatch(transaction);
    };
};


export function focusOn(id) {
    //const {pos} = _getNode(id);
    //if (pos) {
    //    const nodeSelection = new TextSelection(view.state.doc.resolve(pos));
    //    const transaction = view.state.tr.setSelection(nodeSelection).scrollIntoView();
    //    view.dispatch(transaction);
    //};
};

export function scrollIntoView(id) {
};

/**
 * Remove all divs in the document
 */
export function removeAllDivs() {
}

/**
 * Return the node and position of a node with note.attrs of `id`
 * across the view.state.doc from position `from` to position `to`. 
 * If `from` or `to` are unspecified, they default to the beginning 
 * and end of view.state.doc.
 * @param {string} id           The attrs.id of the node we are looking for.
 * @param {number} from         The position in the document to search from.
 * @param {number} to           The position in the document to search to.
 * @returns {Object}            The node and position that matched the search.
 */
function _getNode(id, from, to) {
    const fromPos = from ?? TextSelection.atStart(view.state.doc).from;
    const toPos = to ?? TextSelection.atEnd(view.state.doc).to;
    let foundNode, foundPos;
    view.state.doc.nodesBetween(fromPos, toPos, (node, pos) => {
        if (node.attrs.id === id) {
            foundNode = node;
            foundPos = pos;
            return false;
        }
        // Only iterate over top-level nodes and drill in if a block
        return (!foundNode) && node.isBlock;
    });
    return {node: foundNode, pos: foundPos};
}


/********************************************************************************
 * Formatting
 * 1. Formats (B, I, U, DEL, CODE, SUB, SUP) are toggled off and on
 * 2. Formats can be nested, but not inside themselves; e.g., B cannot be within B
 */
//MARK: Formatting

export function toggleBold() {
    _toggleFormat('B');
};

export function toggleItalic() {
    _toggleFormat('I');
};

export function toggleUnderline() {
    _toggleFormat('U');
};

export function toggleStrike() {
    _toggleFormat('DEL');
};

export function toggleCode() {
    _toggleFormat('CODE');
};

export function toggleSubscript() {
    _toggleFormat('SUB');
};

export function toggleSuperscript() {
    _toggleFormat('SUP');
};

/**
 * Turn the format tag off and on for selection.
 * Called directly on undo/redo so that nothing new is pushed onto the undo stack
 *
 * type must be called using uppercase
 */
function _toggleFormat(type) {
    const state = window.view.state;
    let toggle;
    switch (type) {
        case 'B':
            toggle = toggleMark(state.schema.marks.strong);
            break;
        case 'I':
            toggle = toggleMark(state.schema.marks.em);
            break;
        case 'U':
            toggle = toggleMark(state.schema.marks.u);
            break;
        case 'CODE':
            toggle = toggleMark(state.schema.marks.code);
            break;
        case 'DEL':
            toggle = toggleMark(state.schema.marks.s);
            break;
    };  
    if (toggle) {
        toggle(state, view.dispatch);
        stateChanged()
    };
};

/********************************************************************************
 * Styling
 * 1. Styles (P, H1-H6) are applied to blocks
 * 2. Unlike formats, styles are never nested (so toggling makes no sense)
 * 3. Every block should have some style
 */
//MARK: Styling


/**
 * Set the paragraph style at the selection to `style` 
 * @param {String}  style    One of the styles P or H1-H6 to set the selection to.
 */
export function setStyle(style) {
    const node = _nodeFor(style);
    _setParagraphStyle(node);
};

/**
 * Find/verify the oldStyle for the selection and replace it with newStyle.
 * Replacement for execCommand(formatBlock).
 * @deprecated Use setStyle
 * @param {String}  oldStyle    One of the styles P or H1-H6 that exists at selection.
 * @param {String}  newStyle    One of the styles P or H1-H6 to replace oldStyle with.
 */
export function replaceStyle(oldStyle, newStyle) {
    setStyle(newStyle);
};

function _nodeFor(paragraphStyle) {
    const nodeTypes = view.state.schema.nodes;
    let node;
    switch (paragraphStyle) {
        case 'P':
            node = nodeTypes.paragraph.create();
            break;
        case 'H1':
            node = nodeTypes.heading.create({level: 1})
            break;
        case 'H2':
            node = nodeTypes.heading.create({level: 2})
            break;
        case 'H3':
            node = nodeTypes.heading.create({level: 3})
            break;
        case 'H4':
            node = nodeTypes.heading.create({level: 4})
            break;
        case 'H5':
            node = nodeTypes.heading.create({level: 5})
            break;
        case 'H6':
            node = nodeTypes.heading.create({level: 6})
            break;
    };
    return node;
};

/**
 * Set the paragraph style at the selection based on the settings of protonode.
 * @param {Node}  protonode    A Node with the attributes and type we want to set.
 */
function _setParagraphStyle(protonode) {
    const doc = view.state.doc;
    const selection = view.state.selection;
    const tr = view.state.tr;
    let transaction;
    doc.nodesBetween(selection.from, selection.to, (node, pos) => {
        if (node.type === view.state.schema.nodes.div) { 
            return true;
        } else if (node.isBlock) { 
            transaction = tr.setNodeMarkup(pos, protonode.type, protonode.attrs);
        };
        return false;   // We only need top-level nodes within doc
    });
    const newState = view.state.apply(transaction);
    view.updateState(newState);
    stateChanged();
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
 * @deprecated
 * @param {String}  newListType     The kind of list we want the list item to be in if we are turning it on or changing it.
 */
export function toggleListItem(newListType) {
    if (_getListType() === newListType) {
        _outdentListItems()
    } else {
        _setListType(newListType);
    }
};

/**
 * Set the list style at the selection to the `listType`.
 * @param {String}  listType    The list type { 'UL' | 'OL' } we want to set.
 */
function _setListType(listType) {
    const nodeType = _nodeTypeFor(listType);
    if (nodeType !== null) {
        const command = wrapInList(nodeType);
        command(view.state, (transaction) => {
            const newState = view.state.apply(transaction);
            view.updateState(newState);
            stateChanged();
        });
    };
};

/**
 * Outdent all the list items in the selection.
 */
function _outdentListItems() {
    const selection = view.state.selection;
    const nodeTypes = view.state.schema.nodes;
    let newState;
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.type === nodeTypes.list_item) {   
            const command = liftListItem(node.type);
            command(view.state, (transaction) => {
                newState = view.state.apply(transaction);
            });
        };
        return true;        // Lists can nest, so we need to recurse
    });
    if (newState) {
        view.updateState(newState);
        stateChanged();
    }
};

/**
 * Return the type of list the selection is in, else null.
 * @return { 'UL' | 'OL' | null }
 */
function _getListType() {
    const selection = view.state.selection;
    const ul = view.state.schema.nodes.bullet_list;
    const ol = view.state.schema.nodes.ordered_list;
    const nodeTypes = [];
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.isBlock) {
            if ((node.type === ul) || (node.type === ol)) { 
                nodeTypes.push(node.type)
            }
            return true;  // Lists can nest, so we need to recurse
        }
        return false; 
    });
    return (nodeTypes.length > 0) ? _listTypeFor(nodeTypes[nodeTypes.length - 1]) : null;
};

/**
 * Return the NodeType corresponding to `listType`, else null.
 * @param {"UL" | "OL" | String} listType The Swift-side String corresponding to the NodeType
 * @returns {NodeType | null}
 */
function _nodeTypeFor(listType) {
    if (listType === 'UL') {
        return view.state.schema.nodes.bullet_list;
    } else if (listType === 'OL') {
        return view.state.schema.nodes.ordered_list;
    } else {
        return null;
    };
};

/**
 * Return the String corresponding to `nodeType`, else null.
 * @param {NodeType} nodeType The NodeType corresponding to the Swift-side String
 * @returns {'UL' | 'OL' | null}
 */
function _listTypeFor(nodeType) {
    if (nodeType === view.state.schema.nodes.bullet_list) {
        return 'UL';
    } else if (nodeType === view.state.schema.nodes.ordered_list) {
        return 'OL';
    } else {
        return null;
    }
};

/********************************************************************************
 * Indenting and Outdenting
 */
//MARK: Indenting and Outdenting

/**
 * Do a context-sensitive indent.
 *
 * If in a list, indent the item to a more nested level in the list if appropriate.
 * If in a blockquote, add another blockquote to indent further.
 * Else, put into a blockquote to indent.
 *
 */
export function indent() {
    const selection = view.state.selection;
    const nodeTypes = view.state.schema.nodes;
    let newState;
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.isBlock) {   
            const command = wrapIn(nodeTypes.blockquote);
            command(view.state, (transaction) => {
                newState = view.state.apply(transaction);
            });
            return true;
        };
        return false;
    });
    if (newState) {
        view.updateState(newState);
        stateChanged();
    }
};

/**
 * Do a context-sensitive outdent.
 *
 * If in a list, outdent the item to a less nested level in the list if appropriate.
 * If in a blockquote, remove a blockquote to outdent further.
 * Else, do nothing.
 *
 */
//TODO: Do the right thing for lists
export function outdent() {
    const selection = view.state.selection;
    const blockquote = view.state.schema.nodes.blockquote;
    const ul = view.state.schema.nodes.bullet_list;
    const ol = view.state.schema.nodes.ordered_list;
    let newState;
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if ((node.type === blockquote) || (node.type == ul) || (node.type == ol)) {   
            lift(view.state, (transaction) => {
                newState = view.state.apply(transaction);
            });
        };
        return true;
    });
    if (newState) {
        view.updateState(newState);
        stateChanged();
    }
};

/********************************************************************************
 * Deal with modal input from the Swift side
 */
//MARK: Modal Input

/**
 * Called before beginning a modal popover on the Swift side, to enable the selection
 * to be restored by endModalInput
 */
export function startModalInput() {
}

/**
 * Called typically after cancelling a modal popover on the Swift side, since
 * normally the result of using the popover is to modify the DOM and reset the
 * selection.
 */
export function endModalInput() {
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
export function cleanUpHTML() {
};

function _cleanUpTypesWithin(names, node) {
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
function _cleanUpMetas(node) {
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
function _cleanUpBRs(node) {
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
function _cleanUpNewlines(node) {
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
function _cleanUpTabs(node) {
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
function _cleanUpPREs(node) {
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
function _cleanUpAliases(node) {
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
function _cleanUpSpansWithin(node, spansRemoved) {
    return _cleanUpSpansDivsWithin(node, 'SPAN', spansRemoved);
};

/**
 * Do a depth-first traversal from node, removing divs starting at the leaf nodes.
 *
 * @return {Int}    The number of divs removed
 */
function _cleanUpDivsWithin(node, divsRemoved) {
    return _cleanUpSpansDivsWithin(node, 'DIV', divsRemoved);
}

/**
 * Do a depth-first traversal from node, removing divs/spans starting at the leaf nodes.
 *
 * @return {Int}    The number of divs/spans removed
 */
function _cleanUpSpansDivsWithin(node, type, removed) {
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
function _cleanUpAttributesWithin(attribute, node) {
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
function _cleanUpEmptyTextNodes(node) {
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
function _cleanUpOrphanNodes(node) {
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

function _prepImages(node) {
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
function _patchNewlines(node) {
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
 * Populate a dictionary of properties about the current selection
 * and return it in a JSON form. This is the primary means that the
 * Swift side finds out what the selection is in the document, so we
 * can tell if the selection is in a bolded word or a list or a table, etc.
 *
 * @return {String}      The stringified dictionary of selectionState.
 */
export function getSelectionState() {
    const state = _getSelectionState();
    return JSON.stringify(state);
};

/**
 * Populate a dictionary of properties about the current selection and return it.
 *
 * @return {String: String}     The dictionary of properties describing the selection
 */
const _getSelectionState = function() {
    const state = {};
    // When we have multiple contentEditable elements within editor, we need to
    // make sure we selected something that is editable. If we didn't
    // then just return state, which will be invalid but have the enclosing div ID.
    // Note: _callbackInput() uses a cached value of the *editable* div ID
    // because it is called at every keystroke and change, whereas here we take
    // the time to find the enclosing div ID from the selection so we are sure it
    // absolutely reflects the selection state at the time of the call regardless
    // of whether it is editable or not.
    const contentEditable = _getContentEditable();
    state['divid'] = contentEditable.id;            // Will be 'editor' or a div ID
    state['valid'] = contentEditable.editable;      // Valid means the selection is in something editable
    if (!contentEditable.editable) return state;    // No need to do more with state if it's not editable

    // Selected text
    state['selection'] = _getSelectionText();
    // The selrect tells us where the selection can be found
    const selrect = _getSelectionRect();
    const selrectDict = {
        'x' : selrect.left,
        'y' : selrect.top,
        'width' : selrect.right - selrect.left,
        'height' : selrect.bottom - selrect.top
    };
    state['selrect'] = selrectDict;
    // Link
    const linkAttributes = _getLinkAttributes();
    state['href'] = linkAttributes['href'];
    state['link'] = linkAttributes['link'];
    // Image
    const imageAttributes = _getImageAttributes();
    state['src'] = imageAttributes['src'];
    state['alt'] = imageAttributes['alt'];
    state['width'] = imageAttributes['width'];
    state['height'] = imageAttributes['height'];
    state['scale'] = imageAttributes['scale'];
    //// Table
    const tableAttributes = _getTableAttributes();
    state['table'] = tableAttributes.table;
    state['thead'] = tableAttributes.thead;
    state['tbody'] = tableAttributes.tbody;
    state['header'] = tableAttributes.header;
    state['colspan'] = tableAttributes.colspan;
    state['rows'] = tableAttributes.rows;
    state['cols'] = tableAttributes.cols;
    state['row'] = tableAttributes.row;
    state['col'] = tableAttributes.col;
    state['border'] = tableAttributes.border
    //// Style
    state['style'] = _getParagraphStyle();
    state['list'] = _getListType();
    state['li'] = state['list'] !== null;   // We are always in a li by definition for ProseMirror, right?
    state['quote'] = _getIndented();
    // Format
    const markTypes = _getMarkTypes();
    const schema = view.state.schema;
    state['bold'] = markTypes.has(schema.marks.strong);
    state['italic'] = markTypes.has(schema.marks.em);
    state['underline'] = markTypes.has(schema.marks.u);
    state['strike'] = markTypes.has(schema.marks.s);
    state['sub'] = markTypes.has(schema.marks.sub);
    state['sup'] = markTypes.has(schema.marks.sup);
    state['code'] = markTypes.has(schema.marks.code);
    // DEBUGGING
    //const focusNode = document.getSelection().focusNode;
    //if (focusNode) {
    //    state['focusNodeType'] = focusNode.nodeType;
    //}
    //const focusOffset = document.getSelection().focusOffset;
    //if (focusOffset) {
    //    state['focusOffset'] = focusOffset;
    //}
    return state;
};

/**
 * Return the id and editable state of the selection.
 * @returns {Object} The id and editable state that is selected.
 */
function _getContentEditable() {
    const anchor = view.state.selection.$anchor;
    const sharedDepth = anchor.sharedDepth(view.state.selection.to);
    // We can walk up the tree starting at anchor, looking for a div with its 
    // editable attribute set to true. If we hit the root doc without finding 
    // any div, then we are in a fully editable doc and will return 'editor'.
    // If we hit any div marked editable, then we will return its id and whether
    // it is editable or null if not.
    for (let depth = sharedDepth; depth > 0; depth--) {
        const node = view.state.doc.resolve(anchor.before(depth)).node();
        if (node.type === view.state.schema.nodes.div) {
            return {id: node.attrs.id, editable: node.attrs.editable ?? false}
        }
    }
    return {id: 'editor', editable: true}
}

/**
 * Return the text at the selection.
 * @returns {String} The text that is selected.
 */
function _getSelectionText() {
    const doc = view.state.doc;
    const selection = view.state.selection;
    if (selection.isText) {
        return selection.text;
    } else {
        const cut = doc.cut(selection.from, selection.to);
        return cut.text ?? ""
    };
};

/**
 * Return the rectangle that encloses the selection.
 * @returns {Object} The selection rectangle's top, bottom, left, right.
 */
function _getSelectionRect() {
    const selection = view.state.selection;
    const fromCoords = view.coordsAtPos(selection.from);
    if (selection.empty) return fromCoords;
    // TODO: If selection spans lines, then left should be zero and right should be view width
    const toCoords = view.coordsAtPos(selection.to);
    const top = Math.min(fromCoords.top, toCoords.top);
    const bottom = Math.max(fromCoords.bottom, toCoords.bottom);
    const left = Math.min(fromCoords.left, toCoords.left);
    const right = Math.max(fromCoords.right, toCoords.right);
    return {top: top, bottom: bottom, left: left, right: right};
};

/**
 * Return the MarkTypes that exist at the selection.
 * @returns {Set<MarkType>}   The set of MarkTypes at the selection.
 */
function _getMarkTypes() {
    const selection = view.state.selection;
    const markTypes = new Set();
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        node.marks.forEach(mark => markTypes.add(mark.type));
    });
    return markTypes;
};

/**
 * Return the link attributes at the selection.
 * @returns {Object}   An Object whose properties are <a> attributes (like href, link) at the selection.
 */
function _getLinkAttributes() {
    const selection = view.state.selection;
    const selectedNodes = [];
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.isText) selectedNodes.push(node);
    });
    const selectedNode = (selectedNodes.length === 1) && selectedNodes[0];
    if (selectedNode) {
        const linkMarks = selectedNode.marks.filter(mark => mark.type === view.state.schema.marks.link)
        if (linkMarks.length === 1) {
            return {href: linkMarks[0].attrs.href, link: selectedNode.text};
        };
    };
    return {};
};

/**
 * Return the image attributes at the selection
 * @returns {Object}   An Object whose properties are <img> attributes (like src, alt, width, height, scale) at the selection.
 */
function _getImageAttributes() {
    const selection = view.state.selection;
    const selectedNodes = [];
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.type === view.state.schema.nodes.image)  {
            selectedNodes.push(node);
            return false;
        };
        return true;
    });
    const selectedNode = (selectedNodes.length === 1) && selectedNodes[0];
    return selectedNode ? selectedNode.attrs : {};
};

/**
 * If the selection is inside a table, populate attributes with the information
 * about the table and what is selected in it.
 * 
 * In the MarkupEditor, if there is a header, it is always colspanned across the number 
 * of columns, and normal rows are never colspanned.
 *
 * @returns {Object}   An object with properties populated that are consumable in Swift.
 */
function _getTableAttributes() {
    const selection = view.state.selection;
    const nodeTypes = view.state.schema.nodes;
    const attributes = {};
    view.state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
        let $pos = view.state.doc.resolve(pos);
        switch (node.type) {
            case nodeTypes.table:
                attributes.table = true;
                attributes.from = pos;
                attributes.to = pos + node.nodeSize;
                // Determine the shape of the table. Altho the selection is within a table, 
                // the node.type switching above won't include a table_header unless the 
                // selection is within the header itself. For this reason, we need to look 
                // for the table_header by looking at nodesBetween from and to.
                attributes.rows = node.childCount;
                attributes.cols = 0;
                view.state.doc.nodesBetween(attributes.from, attributes.to, (node) => {
                    switch (node.type) {
                        case nodeTypes.table_header:
                            attributes.header = true;
                            attributes.colspan = node.attrs.colspan;
                            if (attributes.colspan) {
                                attributes.cols = Math.max(attributes.cols, attributes.colspan);
                            } else {
                                attributes.cols = Math.max(attributes.cols, node.childCount);
                            };
                            return false;
                        case nodeTypes.table_row:
                            attributes.cols = Math.max(attributes.cols, node.childCount);
                            return true;
                    };
                    return true;
                });
                // And its border settings
                attributes.border = _getBorder(node);
                return true;
            case nodeTypes.table_header:
                attributes.thead = true;                        // We selected the header
                attributes.tbody = false;
                attributes.row = $pos.index() + 1;              // The row will be 1 by definition
                attributes.col = 1;                             // Headers are always colspanned, so col=1
                return true;
            case nodeTypes.table_row:
                attributes.row = $pos.index() + 1;              // We are in some row, but could be the header row
                return true;
            case nodeTypes.table_cell:
                attributes.tbody = true;                        // We selected the body
                attributes.thead = false;
                attributes.col = $pos.index() + 1;              // We selected a body cell
                return false;
        };
        return true;
    });
   return attributes;
}

/**
 * Return the paragraph style at the selection.
 *
 * @return {String}   {Tag name | 'Multiple'} that represents the selected paragraph style on the Swift side.
 */
function _getParagraphStyle() {
    const selection = view.state.selection;
    const nodeTypes = new Set();
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.isBlock) { 
            nodeTypes.add(node.type)
        };
        return false;   // We only need top-level nodes
    });
    return (nodeTypes.size <= 1) ? _paragraphStyleFor(selection.$anchor.parent) : 'Multiple';
};

/**
 * 
 * @param {Node} node The node we want the Swift-side paragraph style for
 * @returns {String}    { "P" | "H1" | "H2" | "H3" | "H4" | "H5" | "H6" | null }
 */
function _paragraphStyleFor(node) {
    var style;
    switch (node.type.name) {
        case 'paragraph':
            style = "P";
            break;
        case 'heading':
            style = "H" + node.attrs.level;
            break;
    };
    return style;
};

/**
 * Return whether the selection is indented.
 *
 * @return {Boolean}   Whether the selection is in a blockquote.
 */
function _getIndented() {
    const selection = view.state.selection;
    let indented = false;
    view.state.doc.nodesBetween(selection.from, selection.to, node => {
        if (node.type == view.state.schema.nodes.blockquote) { 
            indented = true;
        };
        return false;   // We only need top-level nodes
    });
    return indented;
};

/**
 * Report a selection change to the Swift side.
 */
export function selectionChanged() {
    _callback('selectionChanged')
}

/**
 * Report a click to the Swift side.
 */
export function clicked() {
    _callback('clicked')
}

/**
 * Report a change in the ProseMirror document state to the Swift side. The 
 * change might be from typing or formatting or styling, etc.
 */
export function stateChanged() {
    _callbackInput()
}

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
export function setRange(startElementId, startOffset, endElementId, endOffset, startChildNodeIndex, endChildNodeIndex) {
    return false;
};

/**
 * For testing purposes, invoke undo by direct input to undoer.
 */
export function testUndo() {
};

/**
 * For testing purposes, invoke redo by direct input to undoer.
 */
export function testRedo() {
};

/**
 * For testing purposes, invoke _doBlockquoteEnter programmatically.
 */
export function testBlockquoteEnter() {
};

/**
 * For testing purposes, invoke _doListEnter programmatically.
 */
export function testListEnter() {
};

/**
 * For testing purposes, invoke extractContents() on the selected range
 * to make sure the selection is as expected.
 */
export function testExtractContents() {
};

/**
 * For testing purposes, execute _patchPasteHTML and return the resulting
 * html as a string. Testing in this way lets us do simple pasteHTML tests with
 * clean HTML and test the _patchPasteHTML functionality separately. The
 * purpose of _patchPasteHTML is to return "clean" HTML from arbitrary HTML
 * (typically) obtained from the paste buffer on the Swift side.
 */
export function testPasteHTMLPreprocessing(html) {
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
export function testPasteTextPreprocessing(html) {
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
 * When done, leave the link selected.
 *
 * @param {String}  url             The url/href to use for the link
 */
export function insertLink(url) {
    const selection = view.state.selection;
    const linkMark = view.state.schema.marks.link.create({ href: url });
    if (selection.empty) {
        const textNode = view.state.schema.text(url).mark([linkMark]);
        const transaction = view.state.tr.replaceSelectionWith(textNode, false);
        const linkSelection = TextSelection.create(transaction.doc, selection.from, selection.from + textNode.nodeSize);
        transaction.setSelection(linkSelection);
        view.dispatch(transaction);
    } else {
        const toggle = toggleMark(linkMark.type, linkMark.attrs);
        if (toggle) toggle(view.state, view.dispatch);
    };
    stateChanged();
};

/**
 * Remove the link at the selection, maintaining the same selection.
 * 
 * The selection can be at any point within the link or contain the full link, but cannot include 
 * areas outside of the link.
 */
export function deleteLink() {
    const linkType = view.state.schema.marks.link;
    const selection = view.state.selection;

    // Make sure the selection is in a single text node with a linkType Mark
    const nodePos = [];
    view.state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
        if (node.isText) {
            nodePos.push({node: node, pos: pos});
            return false;
        };
        return true;
    });
    if (nodePos.length !== 1) return;
    const selectedNode = nodePos[0].node;
    const selectedPos = nodePos[0].pos;
    const linkMarks = selectedNode && selectedNode.marks.filter(mark => mark.type === linkType);
    if (linkMarks.length !== 1) return;

    // Select the entire text of selectedNode
    const anchor = selectedPos;
    const head = anchor + selectedNode.nodeSize;
    const linkSelection = TextSelection.create(view.state.doc, anchor, head);
    const transaction = view.state.tr.setSelection(linkSelection);
    let state = view.state.apply(transaction);

    // Then toggle the link off and reset the selection
    const toggle = toggleMark(linkType);
    if (toggle) {
        toggle(state, (tr) => {
            state = state.apply(tr);   // Toggle the link off
            const textSelection = TextSelection.create(state.doc, selection.from, selection.to);
            tr.setSelection(textSelection);
            view.dispatch(tr);
            stateChanged();
        });
    };
};

/********************************************************************************
 * Images
 */
//MARK: Images

/**
 * Insert the image at src with alt text, signaling state changed when done loading.
 * We leave the selection after the inserted image.
 *
 * @param {String}              src         The url of the image.
 * @param {String}              alt         The alt text describing the image.
 */
export function insertImage(src, alt) {
    const imageNode = view.state.schema.nodes.image.create({src: src, alt: alt})
    const transaction = view.state.tr.replaceSelectionWith(imageNode, false);
    view.dispatch(transaction);
    stateChanged();
};

/**
 * Modify the attributes of the image at selection.
 * Scale is a percentage like '80' where null means 100%.
 * Scale is always expressed relative to full scale.
 *
 * @param {String}              src         The url of the image.
 * @param {String}              alt         The alt text describing the image.
 * @param {Int}                 scale       The scale as a percentage of original's naturalWidth/Height.
 */
export function modifyImage(src, alt, scale) {
};


export function cutImage() {
};

/**
 * Callback invoked after the load or error event on an image
 *
 * The purpose of this method is to set attributes of every image to be
 * selectable and resizable and to have width and height preset.
 */
function _prepImage(img) {
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
 *
 * @param   {Int}                 rows        The number of rows in the table to be created.
 * @param   {Int}                 cols        The number of columns in the table to be created.
 */
export function insertTable(rows, cols) {
    let state = view.state;
    const selection = state.selection;
    const nodeTypes = state.schema.nodes;
    // Create a table with a single empty cell
    const paragraph = state.schema.node('paragraph');
    const cell = nodeTypes.table_cell.create(null, paragraph);
    const row = nodeTypes.table_row.create(null, cell);
    const table = nodeTypes.table.createChecked(null, row);
    if (!table) return;     // Something went wrong, like we tried to insert it at a disallowed spot
    // Replace the existing selection range and track the transaction
    const transaction = state.tr.replaceRangeWith(selection.from, selection.to, table);
    // Locate the paragraph position in the transaction's doc
    let pPos;
    transaction.doc.nodesBetween(selection.from, selection.from + table.nodeSize, (node, pos) => {
        if (node.type === paragraph.type) {
            pPos = pos;
            return false;
        };
        return true;
    });
    // Set the selection in the empty cell, apply it to the state and dispatch to the view
    transaction.setSelection(new TextSelection(transaction.doc.resolve(pPos)));
    state.apply(transaction);
    view.dispatch(transaction);
    // The selection is in the one empty cell, so add new rows/columns in the view
    for (let j = 0; j < rows - 1; j++) {
        addRowAfter(view.state, view.dispatch);
    };
    for (let i = 0; i < cols - 1; i++) {
        addColumnAfter(view.state, view.dispatch);
    };
};

/**
 * Add a row before or after the current selection, whether it's in the header or body.
 * For rows, AFTER = below; otherwise above.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new row goes relative to the selection.
 */
export function addRow(direction) {
    if (!_tableSelected()) return;
    if (direction === 'BEFORE') {
        addRowBefore(view.state, view.dispatch);
    } else {
        addRowAfter(view.state, view.dispatch);
    };
    view.focus();
    stateChanged();
};

/**
 * Add a column before or after the current selection, whether it's in the header or body.
 * 
 * In MarkupEditor, the header is always colspanned fully, so we need to merge the headers if adding 
 * a column in created a new element in the header row.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new column goes relative to the selection.
 */
export function addCol(direction) {
    if (!_tableSelected()) return;
    if (direction === 'BEFORE') {
        addColumnBefore(view.state, view.dispatch);
    } else {
        addColumnAfter(view.state, view.dispatch);
    };
    _mergeHeaders();
    view.focus();
    stateChanged();
};

/**
 * Add a header to the table at the selection.
 *
 * @param {boolean} colspan     Whether the header should span all columns of the table or not.
 */
export function addHeader(colspan=true) {
    const tableAttributes = _getTableAttributes();
    if (!tableAttributes.table || tableAttributes.header) return;   // We're not in a table or we are but it has a header already
    _selectInFirstCell();
    addRowBefore(view.state, view.dispatch);
    _selectInFirstCell();
    toggleHeaderRow(view.state, view.dispatch);
    if (colspan) {
        _mergeHeaders();
        _selectInFirstCell();
    };
    view.focus();
    stateChanged();
};

/**
 * Delete the area at the table selection, either the row, col, or the entire table.
 * @param {'ROW' | 'COL' | 'TABLE'} area The area of the table to be deleted.
 */
export function deleteTableArea(area) {
    if (!_tableSelected()) return;
    switch (area) {
        case 'ROW':
            deleteRow(view.state, view.dispatch);
            break;
        case 'COL':
            deleteColumn(view.state, view.dispatch);
            break;
        case 'TABLE':
            deleteTable(view.state, view.dispatch);
            break;
    };
    view.focus();
    stateChanged();
};

/**
 * Set the class of the table to style it using CSS.
 * The default draws a border around everything.
 */
export function borderTable(border) {
    if (_tableSelected()) {
        _setBorder(border);
    }
};

/**
 * Return whether the selection is within a table.
 * @returns {boolean} True if the selection is within a table
 */
function _tableSelected() {
    return _getTableAttributes().table;
};

/**
 * Set the selection to the first cell of the table or 
 * do nothing if we can't.
 */
function _selectInFirstCell() {
    const tableAttributes = _getTableAttributes();
    if (!tableAttributes.table) return;
    const nodeTypes = view.state.schema.nodes; 
    // Find the position of the first paragraph in the table
    let pPos;
    view.state.doc.nodesBetween(tableAttributes.from, tableAttributes.to, (node, pos) => {
        if ((!pPos) && (node.type === nodeTypes.paragraph)) {
            pPos = pos;
            return false;
        }
        return true;
    });
    if (!pPos) return;
    // Set the selection in the first paragraph in the first cell
    const $pos = view.state.doc.resolve(pPos);
    // When the first cell is an empty colspanned header, the $pos resolves to a table_cell,
    // so we need to use NodeSelection in that case.
    let selection;
    if ($pos.node().type === nodeTypes.table_cell) {
        selection = new NodeSelection($pos);
    } else {
        selection = new TextSelection($pos);
    };
    const transaction = view.state.tr.setSelection(selection);
    view.state.apply(transaction);
    view.dispatch(transaction);
};

/**
 * Merge any extra headers created after inserting a column.
 * 
 * When inserting at the left or right column of a table, the addColumnBefore and 
 * addColumnAfter also insert a new cell/td within the header row. Since in 
 * the MarkupEditor, the row is always colspanned across all columns, we need to 
 * merge the cells together when this happens. The operations that insert internal 
 * columns don't cause the header row to have a new cell.
 */
function _mergeHeaders() {
    const selection = view.state.selection;
    const tableAttributes = _getTableAttributes();
    const headers = [];
    view.state.doc.nodesBetween(tableAttributes.from, tableAttributes.to, (node, pos) => {
        switch (node.type) {
            case view.state.schema.nodes.table_header:
                headers.push(pos)
                return false;
        };
        return true;
    });
    if (headers.length > 1) {
        const firstHeaderPos = headers[0];
        const lastHeaderPos = headers[headers.length - 1];
        const delta = lastHeaderPos - firstHeaderPos;
        const rowSelection = CellSelection.create(view.state.doc, firstHeaderPos, lastHeaderPos);
        const transaction = view.state.tr.setSelection(rowSelection);
        let state = view.state.apply(transaction);
        mergeCells(state, (tr) => {
            state = state.apply(tr);   // Merge the cells in the header row
            // And then reselect what was selected before
            const textSelection = TextSelection.create(state.doc, selection.from - delta, selection.to - delta);
            tr.setSelection(textSelection);
            view.dispatch(tr);
        });
    };
};

/**
 * Set the border around and within the cell.
 * @param {'outer' | 'header' | 'cell' | 'none'} border Set the class of the table to correspond to Swift-side notion of border, so css displays it properly.
 */
function _setBorder(border) {
    const selection = view.state.selection;
    let table, fromPos, toPos;
    view.state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
        if (node.type === view.state.schema.nodes.table) {
            table = node;
            fromPos = pos;
            toPos = pos + node.nodeSize;
            return false;
        };
        return false;
    });
    if (!table) return;
    switch (border) {
        case 'outer':
            table.attrs.class = 'bordered-table-outer';
            break;
        case 'header':
            table.attrs.class = 'bordered-table-header';
            break;
        case 'cell':
            table.attrs.class = 'bordered-table-cell';
            break;
        case 'none':
            table.attrs.class = 'bordered-table-none';
            break;
        default:
            table.attrs.class = 'bordered-table-cell';
            break;
    };
    const transaction = view.state.tr
        .setNodeMarkup(fromPos, table.type, table.attrs)
        .setMeta("bordered-table", {border: border, fromPos: fromPos, toPos: toPos})
    view.dispatch(transaction);
    view.focus();
};

/**
 * Get the border around and within the cell.
 * @returns {'outer' | 'header' | 'cell' | 'none'} The type of table border known on the Swift side
 */
function _getBorder(table) {
    let border;
    switch (table.attrs.class) {
        case 'bordered-table-outer':
            border = 'outer';
            break;
        case 'bordered-table-header':
            border = 'header';
            break;
        case 'bordered-table-cell':
            border = 'cell';
            break;
        case 'bordered-table-none':
            border = 'none';
            break;
        default:
            border = 'cell';
            break;
    };
    return border;
};

/********************************************************************************
 * Common private functions
 */
//MARK: Common Private Functions

/**
 * Return the depth of node in parents contained in nodeNames. If the node is
 * a top-level element, then depth===0.
 */
function _depthWithin(node, nodeNames) {
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
function _isEmpty(element) {
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

function _isEmptyParagraph(element) {
    return _isEmpty(element) && _isParagraphStyleElement(element) && _isBRElement(element.firstChild);
};

function _isEmptyPlaceholder(element) {
    return _isParagraphStyleElement(element) && (element.childNodes.length == 1) && _isNonPrintingCharacter(element.firstChild);
};

function _isNonPrintingCharacter(element) {
    return _isTextNode(element) && (element.textContent === '\u200B')
}

function _isEmptyTD(element) {
    return _isEmpty(element) && (element.nodeName === 'TD');
};

/**
 * Return whether node is a div
 */
function _isDiv(node) {
    return node && (node.nodeName === 'DIV');
};

/**
 * Return whether node is a fragment
 */
function _isFragment(node) {
    return node && (node.nodeName === '#document-fragment');
}

/**
 * Return whether node is a button
 */
function _isButton(node) {
    return node && (node.nodeName === 'BUTTON');
}

/**
 * Return whether node is a textNode or not
 */
function _isTextNode(node) {
    return node && (node.nodeType === Node.TEXT_NODE);
};

/**
 * Return whether node is an ELEMENT_NODE or not
 */
function _isElementNode(node) {
    return node && (node.nodeType === Node.ELEMENT_NODE);
};

function _isPreElement(node) {
    return node && (node.nodeName === 'PRE');
}

/**
 * Return whether node is a style element; i.e., its nodeName is in _styleTags
 */
function _isStyleElement(node) {
    return _isElementNode(node) && _styleTags.includes(node.nodeName);
};

/**
 * Return whether node is an allowable top-level node in MarkupEditor.
 *
 * These are nodes that are allowed children in a contentEditable area.
 */
function _isTopLevelElement(node) {
    return node && _topLevelTags.includes(node.nodeName);
};

/**
 * Return whether node is one of the _paragraphStyleTags
 */
function _isParagraphStyleElement(node) {
    return _paragraphStyleTags.includes(node.nodeName);
};

/**
 * Return whether node is a format element; i.e., its nodeName is in _formatTags
 */
function _isFormatElement(node) {
    return _isElementNode(node) && _formatTags.includes(node.nodeName);
};

/**
 * Return whether node is a list element (i.e., either UL or OL)
 */
function _isListElement(node) {
    return node && _listTags.includes(node.nodeName);
};

/**
 * Return whether a node is a list item element (LI)
 */
function _isListItemElement(node) {
    return node && (node.nodeName === 'LI');
};

/**
 * Return whether node is an image element
 */
function _isImageElement(node) {
    return node && (node.nodeName === 'IMG');
};

/**
 * Return whether node is a BR element
 */
function _isBRElement(node) {
    return node && (node.nodeName === 'BR');
};

/**
 * Return whether node is a TABLE element
 */
function _isTableElement(node) {
    return node && (node.nodeName === 'TABLE');
};

/**
 * Return whether node is an empty element with only a BR in it.
 *
 * This is the minimal selectable element, because we cannot set
 * selection inside of something like <p></p>, only <p><br></p>.
 */
function _isEmptyElement(node) {
    return _isElementNode(node) && (node.childNodes.length === 1) && _isBRElement(node.firstChild)
};

/**
 * Return whether node is a BLOCKQUOTE element
 */
function _isBlockquoteElement(node) {
    return node && (node.nodeName === 'BLOCKQUOTE')
};

/**
 * Return whether node has a void tag (i.e., does not need a terminator)
 */
function _isVoidNode(node) {
    return node && (_voidTags.includes(node.nodeName));
};

/**
 * Return whether node is a link
 */
function _isLinkNode(node) {
    return node && (node.nodeName === 'A');
};

/**
 * Return a boolean indicating if s is a white space
 *
 * @param   {String}      s     The string that might be white space
 * @return {Boolean}            Whether it's white space
 */
function _isWhiteSpace(s) {
    return /\s/g.test(s);
};

/**
 * Callback into Swift to show a string in the Xcode console, like console.log()
 */
function _consoleLog(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    _callback(JSON.stringify(messageDict));
};

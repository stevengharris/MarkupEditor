/**
 * Copyright © 2021 Steven Harris. All rights reserved.
 *
 * Initial code cloned from https://github.com/YoomamaFTW/RichEditorView
 * which was itself derived from https://github.com/cbess/RichEditorView/
 * which was in turn derived from cjwirth's original at
 * https://github.com/cjwirth/RichEditorView. This is a bit of a twisty
 * maze of licenses, but in an attempt to abide by all of them, here are
 * their license statements:
 * First cjwirth's:
 
/**
 * Copyright (C) 2015 Wasabeef
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

/**
 * Then, cbess's, which is BSD3:
 *
 Copyright (c) 2019, C. Bess - Soli Deo gloria - perfectGod.com Copyright (c) 2015, Caesar Wirth All rights reserved.

 Redistribution and use in source and binary forms, with or without modification, are permitted provided that the following conditions are met:

 Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.

 Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution.

 Neither the name of the copyright holder nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/**
 * Then YoomamaFTW's, which is BSD3:
 *
 BSD 3-Clause License

 Copyright (c) 2015, YoomamaFTW, Caesar Wirth
 All rights reserved.

 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met:

 1. Redistributions of source code must retain the above copyright notice, this
    list of conditions and the following disclaimer.

 2. Redistributions in binary form must reproduce the above copyright notice,
    this list of conditions and the following disclaimer in the documentation
    and/or other materials provided with the distribution.

 3. Neither the name of the copyright holder nor the names of its
    contributors may be used to endorse or promote products derived from
    this software without specific prior written permission.

 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

'use strict';

const MU = {};

/**
 * The editor element contains the HTML being edited
 */
MU.editor = document.getElementById('editor');

/**
 * The 'ready' callback lets Swift know the editor and this js is properly loaded
 */
window.onload = function() {
    _callback('ready');
};


/// Call back into Swift
/// The message is handled by the WKScriptMessageHandler.
/// In our case, the WKScriptMessageHandler is the MarkupCoordinator,
/// and the userContentController(_ userContentController:didReceive:)
/// function receives message as a WKScriptMessage.
var _callback = function(message) {
    window.webkit.messageHandlers.markup.postMessage(message);
}

/// Returns the cursor position relative to its current position onscreen.
/// Can be negative if it is above what is visible
MU.getRelativeCaretYPosition = function() {
    var y = 0;
    var sel = window.getSelection();
    if (sel.rangeCount) {
        var range = sel.getRangeAt(0);
        var needsWorkAround = (range.startOffset == 0)
        /* Removing fixes bug when node name other than 'div' */
        // && range.startContainer.nodeName.toLowerCase() == 'div');
        if (needsWorkAround) {
            y = range.startContainer.offsetTop - window.pageYOffset;
        } else {
            if (range.getClientRects) {
                var rects = range.getClientRects();
                if (rects.length > 0) {
                    y = rects[0].top;
                }
            }
        }
    }

    return y;
};

/// Looks specifically for a Range selection and not a Caret selection
MU.rangeSelectionExists = function() {
    //!! coerces a null to bool
    var sel = document.getSelection();
    if (sel && sel.type == 'Range') {
        return true;
    }
    return false;
};

/// Return the first tag the selection is inside of
MU.selectionTag = function() {
    var sel = window.getSelection();
    if (sel) {
        if (sel.type === 'None') {
            return '';
        } else {    // sel.type will be Caret or Range
            var focusNode = sel.focusNode;
            if (focusNode) {
                var selElement = focusNode.parentElement;
                if (selElement) {
                    return selElement.tagName;
                }
            }
        }
    }
    return '';
};

/// Return the first tag contained in matchNames that the selection is inside of, without encountering one in excludeNames
var _firstSelectionTagMatching = function(matchNames, excludeNames) {
    var matchingNode = _firstSelectionNodeMatching(matchNames, excludeNames);
    if (matchingNode) {
        return matchingNode.tagName;
    } else {
        return '';
    }
};

/// Return the first node that the selection is inside of whose tagName matches matchNames, without encountering one in excludeNames
var _firstSelectionNodeMatching = function(matchNames, excludeNames) {
    var sel = window.getSelection();
    if (sel) {
        if (sel.type === 'None') {
            return null;
        } else {    // sel.type will be Caret or Range
            var focusNode = sel.focusNode;
            if (focusNode) {
                var selElement = _findFirstParentElementInTagNames(focusNode, matchNames, excludeNames);
                if (selElement) {
                    return selElement;
                }
            }
        }
    }
    return null;
};

/// Return the all tags in tagNames that the selection is inside of
var _selectionTagsMatching = function(tagNames) {
    var sel = window.getSelection();
    var tags = [];
    if (sel) {
        if (sel.type === 'None') {
            return tags;
        } else {    // sel.type will be Caret or Range
            var focusNode = sel.focusNode;
            while (focusNode) {
                var selElement = _findFirstParentElementInTagNames(focusNode, tagNames);
                if (selElement) {
                    tags.push(selElement.tagName);
                }
                focusNode = focusNode.parentNode;
            }
        }
    }
    return tags;
};

//MARK:- Event listeners

document.addEventListener('selectionchange', function() {
    _callback('selectionChange');
});

MU.editor.addEventListener('input', function() {
    MU.updatePlaceholder();
    MU.backupRange();
    _callback('input');
});

MU.editor.addEventListener('focus', function() {
    _callback('focus');
});

MU.editor.addEventListener('blur', function() {
    MU.backupRange();
    _callback('blur');
});

MU.editor.addEventListener('click', function(event) {
    // Handle the case of multiple clicks being received without
    // doing selection.
    if (event.detail > 1) {
        _multiClickSelect(event.detail);
    }
});

MU.editor.addEventListener('keyup', function(event) {
    const key = event.key;
    if ((key === 'Backspace') || (key === 'Delete')) {
        _cleanUpSpans();
        _cleanUpAttributes('style');
    }
});

/* Here is some experimentation on using the EventListener
 * to replace execCommand and avoid excessive formatting
 * Ref: https://w3c.github.io/input-events/
 *
document.addEventListener('beforecopy', function(event) {
    //event.preventDefault();
    MU.callback('beforecopy');
});

document.addEventListener('beforecut', function(event) {
    //event.preventDefault();
    MU.callback('beforecut');
});

document.addEventListener('beforepaste', function(event) {
    event.preventDefault();
    MU.callback('beforepaste');
});

document.addEventListener('copy', function() {
    MU.callback('copy');
});

document.addEventListener('cut', function() {
    MU.callback('cut');
});

document.addEventListener('paste', function() {
    navigator.clipboard.readText().then( clipText => {
        var pasteText;
        var content = clipText.getElementsByTagName('span');
        for (i = 0; i < content.length; i++) {
            if (content) {
                pasteText = content[i].innerText;
                content[i].style.display = '';
            } else {
                content[i].style.display = 'none';
            }
        }
        var sel = document.getSelection();
        if (sel && (sel.type !== 'None')) {
            var focusNode = sel.focusNode;
            if (focusNode) {
                var selElement = focusNode.parentElement;
                if (selElement) {
                    selElement.innerText = pasteText;
                    MU.callback('input')
                }
            }
        }
    });
});
*/

//MARK:- Callbacks

MU.customAction = function(action) {
    let messageDict = {
        'messageType' : 'action',
        'action' : action
    }
    var message = JSON.stringify(messageDict);
    _callback(message);
};

MU.updateHeight = function() {
    _callback('updateHeight');
}

var _consoleLog = function(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    var message = JSON.stringify(messageDict);
    _callback(message);
}

/**
 * Set the contents of the editor element
 * @param {String} contents The HTML for the editor element
 */
MU.setHTML = function(contents) {
    var tempWrapper = document.createElement('div');
    tempWrapper.innerHTML = contents;
    var images = tempWrapper.querySelectorAll('img');
    for (var i = 0; i < images.length; i++) {
        images[i].onload = MU.updateHeight;
    }
    MU.editor.innerHTML = tempWrapper.innerHTML;
    MU.updatePlaceholder();
};

/**
 * Gets the contents of the editor element
 * @return {String} The HTML for the editor element
 */
MU.getHTML = function() {
    return MU.editor.innerHTML;
};

MU.setPlaceholderText = function(text) {
    MU.editor.setAttribute('placeholder', text);
};

MU.updatePlaceholder = function() {
    if (MU.editor.innerHTML.indexOf('img') !== -1 || MU.editor.innerHTML.length > 0) {
        MU.editor.classList.remove('placeholder');
    } else {
        MU.editor.classList.add('placeholder');
    }
};

MU.setFontSize = function(size) {
    MU.editor.style.fontSize = size;
};

MU.setBackgroundColor = function(color) {
    MU.editor.style.backgroundColor = color;
};

MU.setHeight = function(size) {
    MU.editor.style.height = size;
};

MU.undo = function() {
    document.execCommand('undo', false, null);
};

MU.redo = function() {
    document.execCommand('redo', false, null);
};

//MARK:- Formatting
// Note:
// 1. Formats (B, I, U, DEL, SUB, SUP) are toggled off and on
// 2. Formats can be nested, but not inside themselves; e.g., B cannot be within B

MU.toggleBold = function() {
    _toggleFormat('b');
    _callback('input');
};

MU.toggleItalic = function() {
    _toggleFormat('i');
    _callback('input');
};

MU.toggleUnderline = function() {
    _toggleFormat('u');
    _callback('input');
};

MU.toggleStrike = function() {
    _toggleFormat('del');
    _callback('input');
};

MU.toggleCode = function() {
    _toggleFormat('code');
    _callback('input');
};

MU.toggleSubscript = function() {
    _toggleFormat('sub');
    _callback('input');
};

MU.toggleSuperscript = function() {
    _toggleFormat('sup');
    _callback('input');
};

var _toggleFormat = function(type) {
    // Turn the format tag off and on for selection
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, [type.toUpperCase()]);
    if (existingElement) {
        _unsetTag(existingElement, sel);
    } else {
        _setTag(type, sel);
    }
    _callback('input');
}

//MARK:- Raw and formatted text
// Showing raw is meant to be "temporary" in the sense that we just replace the innertHTML
// with HTML that displays &, <, and >. It might look like you could edit it, but you
// really can't.

MU.showRaw = function() {
    // Just replace the innerHTML without the callback.
    // Remove all ranges to avoid potential problems.
    // The expectation is the the editor prevents editing in this state.
    let sel = document.getSelection();
    if (sel) { sel.removeAllRanges() };
    MU.editor.innerHTML = MU.editor.innerHTML.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;');
};

MU.showFormatted = function(html) {
    // Just replace the innerHTML with html and notify of the input
    // Remove all ranges to avoid potential problems.
    let sel = document.getSelection();
    if (sel) { sel.removeAllRanges() };
    MU.editor.innerHTML = html;
    _callback('input');
};

//MARK:- Styling
// 1. Styles (P, H1-H6) are applied to blocks
// 2. Unlike formats, styles are never nested (so toggling makes no sense)
// 3. Every block in a LogEntry should have some style

MU.replaceStyle = function(oldStyle, newStyle) {
    // Find/verify the oldStyle for the selection and replace it with newStyle
    // Replaces original usage of execCommand(formatBlock)
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, [oldStyle.toUpperCase()]);
    if (existingElement) {
        var range = sel.getRangeAt(0).cloneRange();
        var newElement = _replaceTag(newStyle.toUpperCase(), existingElement);
        range.setStart(newElement.firstChild, range.startOffset);
        range.setEnd(newElement.firstChild, range.endOffset);
        sel.removeAllRanges();
        sel.addRange(range);
        _callback('input');
    };
};

//MARK:- Nestables, including lists and block quotes

MU.toggleListItem = function(newListType) {
    // Turn the list tag off and on for selection, doing the right thing
    // for different cases of selections.
    // The newListType passed-in is the kind of List we want the List Item to
    // appear in if we are turning it on or changing it. But, it might be in
    // a list of the wrong type, in which case we need to create a new list
    // and make the selection appear in it.
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    // Capture the range settings for the selection
    var range = sel.getRangeAt(0).cloneRange();
    var oldStartContainer = range.startContainer;
    var oldStartOffset = range.startOffset;
    var oldEndContainer = range.endContainer;
    var oldEndOffset = range.endOffset;
    var selectionState = _getSelectionState();
    var styleType = selectionState['style'];
    var listType = selectionState['list'];
    var isInListItem = selectionState['li'];
    // We will capture the newSelNode for restoring the selection along the way
    var newSelNode = null;
    if (listType) {
        // TOP-LEVEL CASE: We selected something in a list
        var listElement = _findFirstParentElementInTagNames(selNode, [listType]);
        var listItemElementCount = _childrenWithTagNameCount(listElement, 'LI');
        if (isInListItem) {
            // CASE: We selected a list item inside of a list
            var listItemElement = _findFirstParentElementInTagNames(selNode, ['LI']);
            if (listType === newListType) {
                // We want to toggle it off and remove the list altogether if it's empty afterward
                // NOTE: _unsetTag resets the selection properly itself. So, we don't
                // set newSelNode in this case
                _unsetTag(listItemElement, sel);
                if (listItemElementCount === 1) {
                    // There was only one list item, and we just removed it
                    // So, unset the list
                    _unsetTag(listElement, sel);
                }
            } else {
                // If this is the only item in the list, then change the list type rather than
                // change the one element.
                if (listItemElementCount === 1) {
                    newSelNode = _replaceTag(newListType, listElement);
                } else {
                    // We want to replace the existing list item with a newListType list that contains it
                    var newListElement = document.createElement(newListType);
                    newListElement.innerHTML = listItemElement.outerHTML;
                    listItemElement.replaceWith(newListElement);
                    newSelNode = newListElement.firstChild;
                }
            }
        } else if (styleType) {
            // CASE: We selected a styled element in a list, but not in an LI
            var styledElement = _findFirstParentElementInTagNames(selNode, [styleType]);
            if (listType === newListType) {
                // We want the entire styled element to be a list item in the existing list
                newSelNode = _replaceNodeWithListItem(styledElement);
            } else {
                // We want to make the entire styled element the first item in a new newListType list
                newSelNode = _replaceNodeWithList(newListType, styledElement);
            }
        } else if (listType === newListType) {
            // CASE: We selected something in a newListType list that is not an LI and not styled.
            // Replace selNode with a new LI that contains it
            newSelNode = _replaceNodeWithListItem(selNode);
        } else {
            // CASE: We selected something in a not-newListType list that is not an LI and not styled.
            // Replace selNode with a newListType list that contains one LI containing selNode
            newSelNode = _replaceNodeWithList(newListType, selNode);
        }
    } else {
        // TOP-LEVEL CASE: We selected something outside of any list
        // By definition, we want to put it in a newListType list
        var styledElement = _findFirstParentElementInTagNames(selNode, [styleType]);
        if (styledElement) {
            newSelNode = _replaceNodeWithList(newListType, styledElement);
        } else {
            newSelNode = _replaceNodeWithList(newListType, selNode);
        }
    };
    // If we captured the newSelNode, then reset the selection based on it
    if (newSelNode) {
        var startContainer, endContainer;
        startContainer = _firstChildMatchingContainer(newSelNode.parentNode, oldStartContainer);
        if (oldEndContainer ===  oldStartContainer) {
            endContainer = startContainer;
        } else {
            endContainer = _firstChildMatchingContainer(newSelNode.parentNode, oldEndContainer);
        }
        range.setStart(startContainer, oldStartOffset);
        range.setEnd(endContainer, oldEndOffset);
        sel.removeAllRanges();
        sel.addRange(range);
    }
    _callback('input');
}

var _replaceNodeWithList = function(newListType, selNode) {
    // Create a newListType list, place selNode's contents in it, and replace selNode with the new list
    // Return the newListItemElement, which we can use to reset selection from selNode
    var newListElement = document.createElement(newListType);
    var newListItemElement = document.createElement('LI');
    if (selNode.nodeType == Node.TEXT_NODE) {
        newListItemElement.innerHTML = selNode.textContent;
    } else {
        newListItemElement.innerHTML = selNode.outerHTML;
    }
    newListElement.appendChild(newListItemElement);
    selNode.replaceWith(newListElement);
    return newListItemElement;
}

var _replaceNodeWithListItem = function(selNode) {
    // Create a newListItem containing selNode's contents, and replace selNode it
    // Return the newListItemElement, which we can use to reset selection from selNode
    var newListItemElement = document.createElement('LI');
    if (selNode.nodeType == Node.TEXT_NODE) {
        newListItemElement.innerHTML = selNode.textContent;
    } else {
        newListItemElement.innerHTML = selNode.outerHTML;
    }
    selNode.replaceWith(newListItemElement);
    return newListItemElement;
}

MU.replaceList = function(oldList, newList) {
    // Find/verify the oldList for the selection and replace it with newList
    // Replaces original usage of execCommand(insert<type>List)
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, [oldList.toUpperCase()]);
    if (existingElement) {
        MU.backupRange();
        var range = sel.getRangeAt(0).cloneRange();
        var newElement = _replaceTag(newList.toUpperCase(), existingElement);
        range.setStart(newElement, range.startOffset);
        range.setEnd(newElement, range.endOffset);
        sel.removeAllRanges();
        sel.addRange(range);
        _callback('input');
    };
};

MU.increaseQuoteLevel = function() {
    // Add a new BLOCKQUOTE
    // This is a lot more like setting a style than a format, since it applies to the
    // selected element, not to the range of the selection.
    // However, it's important to note that while BLOCKQUOTEs can contain styled
    // elements, styled elements cannot contain BLOCKQUOTEs.
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    var selectionState = _getSelectionState();
    // Capture the range settings for the selection
    var range = sel.getRangeAt(0).cloneRange();
    var oldStartContainer = range.startContainer;
    var oldStartOffset = range.startOffset;
    var oldEndContainer = range.endContainer;
    var oldEndOffset = range.endOffset;
    // We should be inside of style, but if we are inside of a BLOCKQUOTE
    // then we want to increase the quote level from the style, not from the
    // BLOCKQUOTE level. See if we can find a style tag before encountering the
    // BLOCKQUOTE. For example:
    // <BLOCKQUOTE>
    //      <P>This is a paragraph</P>
    //      <P>This is a <b>par|agraph</b> with a word bolded</P>
    // </BLOCKQUOTE>
    // If we select inside of the bolded paragraph at the "|" and add a
    // <BLOCKQUOTE>, we want to end up with:
    // <BLOCKQUOTE>
    //      <P>This is a paragraph</P>
    //      <BLOCKQUOTE>
    //          <P>This is a <b>par|agraph</b> with a word bolded</P>
    //      </BLOCKQUOTE>
    // </BLOCKQUOTE>
    // So...
    // If selection is in a style, use that node as the parent to put in a
    // BLOCKQUOTE. If not, then look for a BLOCKQUOTE and use that node
    // as the parent to put in another BLOCKQUOTE.
    // We should always be selecting inside of some styled element in a LogEntry,
    // but we don't know for sure.
    var selStyle = selectionState['style'];
    var selNodeParent;
    if (selStyle) {
        selNodeParent = _findFirstParentElementInTagNames(selNode, [selStyle]);
    } else {
        var existingBlockQuote = _findFirstParentElementInTagNames(selNode, ['BLOCKQUOTE']);
        if (existingBlockQuote) {
            selNodeParent = existingBlockQuote;
        } else {
            selNodeParent = selNode.parentNode;
        }
    }
    // Now create a new BLOCKQUOTE parent based, put the selNodeParent's outerHTML
    // into it, and replace the selNodeParent with the BLOCKQUOTE
    var newParent = document.createElement('blockquote');
    newParent.innerHTML = selNodeParent.outerHTML;
    selNodeParent.replaceWith(newParent);
    // Restore the selection by locating the start and endContainers in the newParent
    MU.backupRange();
    var startContainer, endContainer;
    startContainer = _firstChildMatchingContainer(newParent, oldStartContainer);
    if (oldEndContainer ===  oldStartContainer) {
        endContainer = startContainer;
    } else {
        endContainer = _firstChildMatchingContainer(newParent, oldEndContainer);
    }
    range.setStart(startContainer, oldStartOffset);
    range.setEnd(endContainer, oldEndOffset);
    sel.removeAllRanges();
    sel.addRange(range);
    _callback('input');
}

MU.decreaseQuoteLevel = function() {
    // Remove an existing BLOCKQUOTE if it exists
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, ['BLOCKQUOTE']);
    if (existingElement) {
        _unsetTag(existingElement, sel);
        _callback('input');
    }
}

//MARK:- Insert operations

/// All insert operations that involve user interaction outside of JavaScript
/// need to be preceded by prepareInsert so that range can be restored prior
/// to the insert* operation
MU.prepareInsert = function() {
    MU.backupRange();
};

/// Insert the image at url with alt text, signaling updateHeight when done loading.
/// We leave the selection where it was (right in front of the image) rather
/// than surrounding the selection. The operation will cause a selectionChange
/// event. On the Swift side, we can do whatever is appropriate when we find
/// the SelectionState points to an image, which it will when the selection changes.
MU.insertImage = function(url, alt) {
    MU.restoreRange();
    var sel = document.getSelection();
    var el = document.createElement('img');
    el.setAttribute('src', url);
    if (alt) { el.setAttribute('alt', alt) };
    el.onload = MU.updateHeight;
    var range = sel.getRangeAt(0).cloneRange();
    range.insertNode(el);
    _callback('input');
};

/// Modify the attributes of the image at selection.
/// If url is null, then remove the image.
/// Scale is a percentage like '80' where null means 100%
MU.modifyImage = function(src, alt, scale) {
    MU.restoreRange();
    var el = _getImageAtSelection()
    if (el) {
        if (src) {
            el.setAttribute('src', src);
            if (alt) {
                el.setAttribute('alt', alt);
            } else {
                el.removeAttribute('alt');
            }
            if (scale) {
                el.setAttribute('width', el.naturalWidth * scale / 100);
                el.setAttribute('height', el.naturalHeight * scale / 100);
            } else {
                el.removeAttribute('width');
                el.removeAttribute('height');
            }
            MU.restoreRange()
        } else {
            el.parentNode.removeChild(el);
        }
        _callback('input');
    }
}

/// Insert a link to url. The selection has to be across a range.
/// When done, re-select the range.
MU.insertLink = function(url) {
    MU.restoreRange();
    var sel = document.getSelection();
    if (sel.toString().length !== 0) {
        if (sel.rangeCount) {
            var el = document.createElement('a');
            el.setAttribute('href', url);
            var range = sel.getRangeAt(0).cloneRange();
            range.surroundContents(el);
            sel.removeAllRanges();
            sel.addRange(range);
        }
    }
    _callback('input');
};

//MARK:- Range operations

MU.initializeRange = function() {
    var selection = document.getSelection();
    selection.removeAllRanges();
    var range = document.createRange();
    range.setStart(MU.editor.firstChild, 0);
    range.setEnd(MU.editor.firstChild, 0);
    selection.addRange(range);
    MU.backupRange();
}

MU.backupRange = function() {
    var selection = document.getSelection();
    if (selection.rangeCount > 0) {
        var range = selection.getRangeAt(0).cloneRange();
        MU.currentSelection = {
            'startContainer': range.startContainer,
            'startOffset': range.startOffset,
            'endContainer': range.endContainer,
            'endOffset': range.endOffset
        };
    }
};

MU.restoreRange = function() {
    var selection = document.getSelection();
    selection.removeAllRanges();
    var range = document.createRange();
    range.setStart(MU.currentSelection.startContainer, MU.currentSelection.startOffset);
    range.setEnd(MU.currentSelection.endContainer, MU.currentSelection.endOffset);
    selection.addRange(range);
};

MU.addRangeToSelection = function(selection, range) {
    if (selection) {
        selection.removeAllRanges();
        selection.addRange(range);
    }
};

// Programatically select a DOM element
MU.selectElementContents = function(el) {
    var range = document.createRange();
    range.selectNodeContents(el);
    var sel = window.getSelection();
    // this.createSelectionFromRange sel, range
    MU.addRangeToSelection(sel, range);
};

//MARK:- Focus and blur

MU.focus = function() {
    var range = document.createRange();
    range.selectNodeContents(MU.editor);
    range.collapse(false);
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    MU.editor.focus();
};

MU.focusAtPoint = function(x, y) {
    var range = document.caretRangeFromPoint(x, y) || document.createRange();
    var selection = window.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
    MU.editor.focus();
};

MU.blurFocus = function() {
    MU.editor.blur();
};

//MARK:- Selection

MU.cleanUpHTML = function() {
    // Due to the presence of "-webkit-text-size-adjust: 100%;" in normalize.css,
    // WebKit was inserting styling for elements many places, but particularly
    // on deletion as it tried to maintain the proper appearance. However, even
    // with that removed, we still end up with spans that try to enforce the
    // previous "style" (for example, H1) font size. We also end up with styles
    // imposed on format elements. All of these need to be removed, since we
    // don't support arbitrary font size changes.
    // Spans need to be removed and replaced with their innerHTML.
    _cleanUpSpans();
    _cleanUpAttributes('style');
};

var _cleanUpSpans = function() {
    // Standard webkit editing may leave messy and useless SPANs all over the place.
    // This method just cleans them all up and notifies Swift that the content
    // has changed. Start with the selection focusNode's parent, so as to make
    // sure to get all its siblings. If there is no focusNode, fix the entire
    // editor.
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    var startNode = (selNode) ? selNode.parentNode : MU.editor;
    if (startNode) {
        var spansRemoved = _cleanUpSpansWithin(startNode);
        if (spansRemoved > 0) {
            _callback('input');
        }
    };
}

var _cleanUpSpansWithin = function(node) {
    // Do a depth-first traversal from node, removing spans
    // starting at the leaf nodes
    // Return the number of spans removed
    var spansRemoved = 0;
    var children = node.children;
    if (children.length > 0) {
        for (let i=0; i < children.length; i++) {
            spansRemoved += _cleanUpSpansWithin(children[i]);
        };
    };
    if (node.tagName === 'SPAN') {
        spansRemoved++;
        var template = document.createElement('template');
        template.innerHTML = node.innerHTML;
        var newElement = template.content;
        node.replaceWith(newElement);
    };
    return spansRemoved;
}

var _cleanUpAttributes = function(attribute) {
    // Do a depth-first traversal from selection, removing attributes
    // from the focusNode and its siblings. If there is no focusNode,
    // fix the entire editor.
    // If any attributes were removed, then notify Swift of a content change
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    var startNode = (selNode) ? selNode.parentNode : MU.editor;
    if (startNode) {
        var attributesRemoved = _cleanUpAttributesWithin(attribute, startNode);
        if (attributesRemoved > 0) {
            _callback('input');
        }
    };
};

var _cleanUpAttributesWithin = function(attribute, node) {
    // Do a depth-first traversal from node, removing attributes
    // starting at the leaf nodes
    // Return the number of attributes removed
    var attributesRemoved = 0;
    var children = node.children;
    if (children.length > 0) {
        for (let i=0; i < children.length; i++) {
            attributesRemoved += _cleanUpAttributesWithin(attribute, children[i]);
        };
    };
    if (node.hasAttribute(attribute)) {
        attributesRemoved++;
        node.removeAttribute(attribute);
    };
    return attributesRemoved;
};

/**
 * We received a double or triple click event.
 * When switching LogEntryViews, the double and triple click does not highlight
 * immediately. So, this method highlights and sets the selection properly if needed.
 * We can get double and triple clicks events when the selection is already set
 * properly, in which case we do nothing.
 */
var _multiClickSelect = function(nClicks) {
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (selNode) {
        if (nClicks === 3) {
            _tripleClickSelect(sel);
        } else if (nClicks === 2) {
            // For posterity, I tried just (re)dispatching a new click event,
            // but it does not do anything for the selection.
            _doubleClickSelect(sel, selNode);
        }
    };
};

var _doubleClickSelect = function(sel, selNode) {
    // Select the word in the selNode
    var range = sel.getRangeAt(0).cloneRange();
    var startOffset = range.startOffset;
    var endOffset = range.endOffset;
    let selNodeText = selNode.textContent;
    while ((startOffset > 0) && !_isWhiteSpace(selNodeText[startOffset - 1])) {
        startOffset -= 1;
    }
    while ((endOffset < selNodeText.length) && !_isWhiteSpace(selNodeText[endOffset]))  {
        endOffset += 1;
    }
    var wordRange = document.createRange();
    wordRange.setStart(range.startContainer, startOffset);
    wordRange.setEnd(range.endContainer, endOffset);
    sel.removeAllRanges();
    sel.addRange(wordRange);
};

var _tripleClickSelect = function(sel) {
    // Find the node that should be selected in full, and then select it
    var nodeToSelect = _firstSelectionNodeMatching(['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'LI', 'BLOCKQUOTE', 'OL', 'UL']);
    if (nodeToSelect) {
        var elementRange = document.createRange();
        if (nodeToSelect.firstChild.nodeType === Node.TEXT_NODE) {
            elementRange.setStart(nodeToSelect.firstChild, 0);
        } else {
            elementRange.setStart(nodeToSelect, 0);
        }
        if (nodeToSelect.lastChild.nodeType === Node.TEXT_NODE) {
            elementRange.setEnd(nodeToSelect.lastChild, nodeToSelect.lastChild.textContent.length);
        } else {
            elementRange.setEnd(nodeToSelect, nodeToSelect.childNodes.length - 1);
        }
        sel.removeAllRanges();
        sel.addRange(elementRange);
    }
};

var _isWhiteSpace = function(s) {
    return /\s/g.test(s);
};

/**
 * Populate a dictionary of properties about the current selection
 * and return it in a JSON form
 */
MU.getSelectionState = function() {
    var state = _getSelectionState();
    return JSON.stringify(state);
};

/**
 * Populate a dictionary of properties about the current selection
 * and return it
 */
var _getSelectionState = function() {
    var state = {};
    if (!document.getSelection()) {
        return state;
    }
    var linkAttributes = _getLinkAttributesAtSelection();
    state['href'] = linkAttributes['href'];
    state['link'] = linkAttributes['link'];
    var imageAttributes = _getImageAttributesAtSelection();
    state['src'] = imageAttributes['src'];
    state['alt'] = imageAttributes['alt'];
    state['scale'] = imageAttributes['scale'];
    state['frame'] = imageAttributes['frame'];
    state['style'] = _getSelectionStyle();
    state['selection'] = _getSelectionText();
    var formatTags = _getFormatTags();
    state['bold'] = formatTags.includes('B');
    state['italic'] = formatTags.includes('I');
    state['underline'] = formatTags.includes('U');
    state['strike'] = formatTags.includes('DEL');
    state['sub'] = formatTags.includes('SUB');
    state['sup'] = formatTags.includes('SUP');
    state['code'] = formatTags.includes('CODE');
    state['list'] = _firstSelectionTagMatching(['UL', 'OL']);
    if (state['list']) {
        // If we are in a list, then we might or might not be in a list item
        state['li'] = _firstSelectionTagMatching(['LI']).length > 0;
    } else {
        // But if we're not in a list, we deny we are in a list item
        state['li'] = false;
    }
    state['quote'] = _firstSelectionTagMatching(['BLOCKQUOTE']).length > 0;
    // DEBUGGING
    //var focusNode = document.getSelection().focusNode;
    //if (focusNode) {
    //    state['focusNodeType'] = focusNode.nodeType;
    //}
    //var focusOffset = document.getSelection().focusOffset;
    //if (focusOffset) {
    //    state['focusOffset'] = focusOffset;
    //}
    return state
};

var _getSelectionStyle = function() {
    return _firstSelectionTagMatching(['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6']);
}

var _getFormatTags = function() {
    return _selectionTagsMatching(['B', 'I', 'U', 'DEL', 'SUB', 'SUP', 'CODE']);
}

var _getSelectionText = function() {
    var sel = window.getSelection();
    if (sel) {
        return sel.toString();
    }
    return '';
};

/**
 * If there is a range selection, return it as a string.
 * @returns {string}
 */
MU.getRangeSelection = function() {
    var sel = document.getSelection();
    if (sel && sel.type == 'Range') {
        return sel.toString();
    }
    return null;
};

/**
 * For testing purposes, set selection based on elementIds and offsets
 * Like selection, the startOffset and endOffset are number of characters
 * when startElement is #test; else, child number
 * Return true if both elements are found; else, false
 */
MU.setRange = function(startElementId, startOffset, endElementId, endOffset) {
    var startElement = document.getElementById(startElementId);
    var endElement = document.getElementById(endElementId);
    if (!startElement || !endElement) { return false };
    var startContainer = _firstTextNodeChild(startElement);
    var endContainer = _firstTextNodeChild(endElement);
    if (!startContainer || !endContainer) { return false };
    var range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    return true;
}

//MARK:- Links

/**
 * If the current selection's parent is an A tag, get the href and text.
 * @returns dictionary with href and link as keys; empty if not a link
 */
var _getLinkAttributesAtSelection = function() {
    var link = {};
    var sel = document.getSelection();
    if (sel) {
        var element = sel.anchorNode.parentElement;
        if ('A' === element.nodeName) {
            link['href'] = element.getAttribute('href');
            link['link'] = element.text;
        }
    }
    return link;
};

//MARK:- Images

/**
 * If the current selection's anchorNode is an IMG tag, get the src and alt.
 * @returns dictionary with src and alt as keys; empty if not an image
 */

var _getImageAttributesAtSelection = function() {
    var attributes = {};
    var element = _getImageAtSelection();
    if (element) {
        attributes['src'] = element.getAttribute('src');
        attributes['alt'] = element.getAttribute('alt');
        attributes['scale'] = element.getAttribute('width');    //  A string like "100%" with height=auto
        var rect = element.getBoundingClientRect();
        let rectDict = {
            'x' : rect.left,
            'y' : rect.top,
            'width' : rect.width,
            'height' : rect.height
        }
        attributes['frame'] = rectDict
    }
    return attributes;
};


var _getImageAtSelection = function() {
    var sel = document.getSelection();
    if (sel) {
        var node = sel.anchorNode;
        if ((node.nodeType === Node.TEXT_NODE) && (sel.isCollapsed)) {
            if (sel.anchorOffset === node.textContent.length) {
                // We have selected the end of a text element, which might be next to an IMG
                if (node.nextSibling.nodeType === Node.ELEMENT_NODE) {
                    var element = node.nextSibling;
                    if (element.nodeName === 'IMG') {
                        return element;
                    };
                };
            };
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            // We selected some element (like <P>) and its first child might be an IMG
            var firstChild = node.firstChild;
            if (firstChild.nodeName === 'IMG') {
                return firstChild;
            };
        };
    };
    return null;
}

/**
 * Recursively search element ancestors to find a element nodeName e.g. A
 */
var _findNodeByNameInContainer = function(element, nodeName, rootElementId) {
    if (element.nodeName == nodeName) {
        return element;
    } else {
        if (element.id === rootElementId) {
            return null;
        }
        _findNodeByNameInContainer(element.parentElement, nodeName, rootElementId);
    }
};

//MARK:- Common private functions

var _setTag = function(type, sel) {
    // Put the tag around the current selection, even if range.collapsed
    var el = document.createElement(type);
    var range = sel.getRangeAt(0).cloneRange();
    if (range.collapsed) {
        // When we have the case of a collapsed selection, AFAICT there is no way to
        // set the selection to be inside of an empty element. As a workaround, I create
        // a zero-width space character inside of it. This causes move-by-character to stay
        // on the same location, which is a bit of a drag. See ancient WebKit discussion at:
        // https://bugs.webkit.org/show_bug.cgi?id=15256. This would lead you to think it
        // was fixed after 5 agonizing years, but it would appear not to me.
        var emptyTextNode = document.createTextNode('\u200B');
        el.appendChild(emptyTextNode);
        range.insertNode(el);
        range.setStart(el, 1);  // If set to zero, the caret doesn't show
        range.setEnd(el, 1);
    } else {
        // Why not just range.surroundContents(el)?
        // Because for selections that span elements, it doesn't work.
        // Consider:
        //      <p><b>Hel|lo</b> wo|rld<p>
        // Where | shows the selection starting in the bold element and ending in text.
        // The extractContents-appendChild-insertNode for italic operation produces:
        //      <p><b>Hel<i>lo</b> wo</i>rld<p>
        el.appendChild(range.extractContents());
        range.insertNode(el);
    }
    // Check if the insertion left an empty element preceding or following
    // the inserted el. Unfortunately, when starting/ending the selection at
    // the beginning/end of an element in the multinode selection - for example:
    //      <p><b>|Hello</b> wo|rld<p>
    // We end up with:
    //      <p><b></b><i><b>Hello</b> wo</i>rld<p>
    // IOW, we end up with a blank sibling to the new <i> element. It doesn't
    // hurt anything, but it's annoying as hell. So the following code checks
    // for it and removes it.
    var prevSib = el.previousSibling;
    if (prevSib && (prevSib.nodeType != Node.TEXT_NODE)) {
        var innerHTML = prevSib.innerHTML;
        if (!innerHTML || (innerHTML.length == 0)) {
            prevSib.parentNode.removeChild(prevSib);
        }
    }
    var nextSib = el.nextSibling;
    if (nextSib && (nextSib.nodeType != Node.TEXT_NODE)) {
        var innerHTML = nextSib.innerHTML;
        if (!innerHTML || (innerHTML.length == 0)) {
            nextSib.parentNode.removeChild(nextSib);
        }
    }
    sel.removeAllRanges();
    sel.addRange(range);
};

var _unsetTag = function(oldElement, oldSelection) {
    // Remove the tag from the oldElement. The oldSelection startContainer might or might not be
    // the oldElement passed-in. In all cases, though, oldSelection starts at some offset into text.
    // The element passed-in has the tag we are removing, so replacing outerHTML with inner removes
    // the outermost in place. A simple reassignment still leaves references the element type
    // unchanged (see https://developer.mozilla.org/en-US/docs/Web/API/Element/outerHTML#notes).
    // So, we need to do a proper replace.
    //
    // First, hold onto the old range so we can put it back in place when done
    var oldRange = oldSelection.getRangeAt(0).cloneRange();
    // Note: I thought cloneRange() does copy by value.
    // Per https://developer.mozilla.org/en-us/docs/Web/API/Range/cloneRange...
    //   The returned clone is copied by value, not reference, so a change in either Range
    //   does not affect the other.
    // But this doesn't seem to be true in practice. In practice, oldRange properties get
    // changed after we do replaceWith below. We need to hold onto the values explicitly
    // so we can assign them properly to the new range after unsetting the tag.
    var oldStartContainer = oldRange.startContainer;
    var oldStartOffset = oldRange.startOffset;
    var oldEndContainer = oldRange.endContainer;
    var oldEndOffset = oldRange.endOffset;
    // Get a newElement from the innerHTML of the oldElement, but hold onto the parentNode
    var oldParentNode = oldElement.parentNode;
    var template = document.createElement('template');
    template.innerHTML = oldElement.innerHTML;
    var newElement = template.content;
    oldElement.replaceWith(newElement);
    // Now that oldElement has been replaced, we need to reset the selection.
    // We need to do everything from the oldParentNode, which remains unchanged.
    // Did we just eliminate the startContainer for the selection? Consider
    // element is a bolded word and selection (| = caret) is collapsed in it:
    //      "hello <b>wo|rld</b>"
    // becomes:
    //      "hello wo|rld"
    // But, if the selection is nested and we remove bold, it might start like:
    //      "hello <i><b>wo|rld</b></i>"
    // and become:
    //      "hello <i>wo|rld</i>"
    // And a more complicated case could be:
    //      "<i>hello <b>wo|rld</b></i>
    // In all these cases, the existing range.startContainer is the same -
    // a text node - and the startOffset is 2. However, the newElement we
    // is either another text node (the 1st case), an element node (the 2nd),
    // or a text node (the 3rd) embedded in an element node.
    // Note from https://developer.mozilla.org/en-US/docs/Web/API/Range/startOffset:
    //      If the startContainer is a Node of type Text, Comment, or CDATASection, then
    //      the offset is the number of characters from the start of the startContainer to
    //      the boundary point of the Range. For other Node types, the startOffset is the
    //      number of child nodes between the start of the startContainer and the boundary
    //      point of the Range.
    // So, we need to make sure the startOffset and endOffset make sense for the newElement
    // if it replaces the startContainer or endContainer.
    var range, startContainer, startOffset, endContainer, endOffset;
    var newStartContainer = _firstChildMatchingContainer(oldParentNode, oldStartContainer);
    if (newStartContainer) {
        startContainer = newStartContainer;
        startOffset = oldStartOffset;
    } else {
        startContainer = newElement;
        startOffset = 0;
    }
    var newEndContainer = _firstChildMatchingContainer(oldParentNode, oldEndContainer);
    if (newEndContainer) {
        endContainer = newEndContainer;
        endOffset = oldEndOffset;
    } else {
        endContainer = newElement;
        endOffset = 0;
    };
    // With the new range properties sorted out, create the new range and reset the selection
    range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    var selection = document.getSelection();
    selection.removeAllRanges();
    selection.addRange(range);
}

var _replaceTag = function(tagName, element) {
    MU.backupRange();
    var newElement = document.createElement(tagName);
    newElement.innerHTML = element.innerHTML;
    element.replaceWith(newElement);
    MU.restoreRange();
    return newElement;
};

var _childrenWithTagNameCount = function(element, tagName) {
    var count = 0;
    var children = element.children;
    for (let i=0; i < children.length; i++) {
        if (children[i].tagName === tagName) { count++ };
    }
    return count;
}

var _firstChildMatchingContainer = function(element, container) {
    // Sure, might be obvious to you, but just for the record...
    // The children property returns a collection of an element's child
    // elements, as an HTMLCollection object. The difference between
    // children and childNodes, is that childNodes contain all nodes,
    // including text nodes and comment nodes, while children only contain
    // element nodes.
    // For our purposes here, container is always a #text node.
    var childNodes = element.childNodes;
    for (let i = 0; i < childNodes.length; i++) {
        var node = childNodes[i];
        if (node.nodeType === container.nodeType) {
            if (node.textContent === container.textContent) {
                return node;
            }
        } else {
            var child = _firstChildMatchingContainer(node, container);
            if (child) {
                return child;
            }
        }
    }
    return null;
}

var _firstTextNodeChild = function(element) {
    let childNodes = element.childNodes;
    for (let i = 0; i < childNodes.length; i++) {
        var node = childNodes[i];
        if (node.nodeType === Node.TEXT_NODE) {
            return node;
        };
    };
    return null;
}

/**
 * Recursively search parentElements to find the first one included in matchNames
 * without ever encountering one in excludeNames
 */
var _findFirstParentElementInTagNames = function(node, matchNames, excludeNames) {
    // ExcludeNames may be null, in which case will just match; else return null
    // if any element in excludeNames is encountered
    var parentElement = node.parentElement;
    if (!parentElement) {
        return null;
    } else {
        var parentTagName = parentElement.tagName;
        if (excludeNames && excludeNames.includes(parentTagName)) {
            return null;
        } else if (matchNames.includes(parentTagName)) {
            return parentElement;
        } else {
            return _findFirstParentElementInTagNames(parentElement, matchNames, excludeNames);
        }
    }
};

//MARK:- Unused?

MU.getLineHeight = function() {
    return MU.editor.style.lineHeight;
};

MU.setLineHeight = function(height) {
    MU.editor.style.lineHeight = height;
};

MU.getText = function() {
    return MU.editor.innerText;
};

MU.setBaseTextColor = function(color) {
    MU.editor.style.color  = color;
};

MU.setOrderedList = function() {
    document.execCommand('insertOrderedList', false, null);
};

MU.setUnorderedList = function() {
    document.execCommand('insertUnorderedList', false, null);
};

MU.setBlockquote = function() {
    document.execCommand('formatBlock', false, '<blockquote>');
};

MU.setTextColor = function(color) {
    MU.restoreRange();
    document.execCommand('styleWithCSS', null, true);
    document.execCommand('foreColor', false, color);
    document.execCommand('styleWithCSS', null, false);
};

MU.setTextBackgroundColor = function(color) {
    MU.restoreRange();
    document.execCommand('styleWithCSS', null, true);
    document.execCommand('hiliteColor', false, color);
    document.execCommand('styleWithCSS', null, false);
};

MU.setIndent = function() {
    document.execCommand('indent', false, null);
};

MU.setOutdent = function() {
    document.execCommand('outdent', false, null);
};

MU.setJustifyLeft = function() {
    document.execCommand('justifyLeft', false, null);
};

MU.setJustifyCenter = function() {
    document.execCommand('justifyCenter', false, null);
};

MU.setJustifyRight = function() {
    document.execCommand('justifyRight', false, null);
};

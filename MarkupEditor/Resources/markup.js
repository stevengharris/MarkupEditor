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

/*
 * The Undoer class below was adopted with minor changes from https://github.com/samthor/undoer
 * under the Apache 2.0 license found at https://github.com/samthor/undoer/blob/dad5b30c2667579667b883e246cad77711daaff7/LICENSE.
 */
class Undoer {
    
    /**
     * @template T
     * @param {function(T)} callback to call when undo/redo occurs
     * @param {T=} zero the zero state for undoing everything
     */
    constructor(undoCallback, redoCallback, zero=null) {
        this._duringUpdate = false;
        this._stack = [zero];
        
        // Using an input element rather than contentEditable div because parent is already a
        // contentEditable div
        this._ctrl = document.createElement('input');
        this._ctrl.setAttribute('aria-hidden', 'true');
        this._ctrl.setAttribute('id', 'hiddenInput');
        this._ctrl.style.opacity = 0;
        this._ctrl.style.position = 'fixed';
        this._ctrl.style.top = '-1000px';
        this._ctrl.style.pointerEvents = 'none';
        this._ctrl.tabIndex = -1;
        
        this._ctrl.textContent = '0';
        this._ctrl.style.visibility = 'hidden';  // hide element while not used
        
        this._ctrl.addEventListener('focus', (ev) => {
            // Safari needs us to wait, can't blur immediately.
            window.setTimeout(() => void this._ctrl.blur(), 1);
        });
        this._ctrl.addEventListener('input', (ev) => {
            // There are two types of input events.
            // 1. If _duringUpdate, we just pushed data onto _stack and ev.data is the index
            //      of what we just spliced into _stack.
            // 2. If !_duringUpdate, then we are undoing or redoing. In this case, ev.data
            //      is null, and we use _depth to find out what _ctrl is holding. That
            //      value is the index into _stack for either undoing or redoing.
            ev.stopImmediatePropagation();  // We don't want this event to be seen by the parent
            //_consoleLog("input event: " + ev.inputType);
            //_consoleLog("  this._depth: " + this._depth);
            //_consoleLog("  this.data: " + JSON.stringify(this.data));
            //_consoleLog("  ev.data: " + ev.data);
            //_consoleLog("  initial this._ctrl.textContent: " + this._ctrl.textContent);
            if (!this._duringUpdate) {
                if (ev.inputType === 'historyUndo') {
                    undoCallback(this._stack[this._depth]);
                    this._ctrl.textContent = this._depth - 1;
                } else if (ev.inputType === 'historyRedo') {
                    redoCallback(this._stack[this._depth + 1]);
                    this._ctrl.textContent = this._depth + 1;
                };
            } else {
                this._ctrl.textContent = ev.data;
            }
            //_consoleLog("  final this._ctrl.textContent: " + this._ctrl.textContent);
            // clear selection, otherwise user copy gesture will copy value
            // nb. this _probably_ won't work inside Shadow DOM
            // nb. this is mitigated by the fact that we set visibility: 'hidden'
            const s = window.getSelection();
            if (s.containsNode(this._ctrl, true)) {
                s.removeAllRanges();
            }
        });
    }
    
    /**
     * @return {number} the current stack value
     */
    get _depth() {
        return +(this._ctrl.textContent) || 0;
    }
    
    /**
     * @return {T} the current data
     * @export
     */
    get data() {
        return this._stack[this._depth];
    }
    
    /**
     * Pushes a new undoable event. Adds to the browser's native undo/redo stack.
     *
     * @param {T} data the data for this undo event
     * @param {!Node=} parent to add to, uses document.body by default
     * @export
     */
    push(data, parent) {
        // nb. We can't remove this later: the only case we could is if the user undoes everything
        // and then does some _other_ action (which we can't detect).
        if (!this._ctrl.parentNode) {
            // nb. we check parentNode as this would remove contentEditable's history
            (parent || document.body).appendChild(this._ctrl);
        }
        
        // Avoid letting the MarkupEditor know about the focus-blur dance going on with this._ctrl
        // and the previousFocus (the MU.editor). When MU.editor gets the focus event, it will always
        // reset so other focus events are not muted.
        muteFocusBlur();
        
        const nextID = this._depth + 1;
        this._stack.splice(nextID, this._stack.length - nextID, data);

        const previousFocus = document.activeElement;
        MU.backupRange();   // Otherwise, when we refocus, it won't be set right
        try {
            this._duringUpdate = true;
            this._ctrl.style.visibility = null;
            this._ctrl.focus({preventScroll: true});
            document.execCommand('selectAll');
            document.execCommand('insertText', false, nextID);
        } finally {
            this._duringUpdate = false;
            this._ctrl.style.visibility = 'hidden';
        }
        previousFocus && previousFocus.focus({preventScroll: true});
    }
};

/**
 * Create the undoer and the callbacks
 * The data is created at undoer.push time and consists of an
 * operation name key followed by a Range and some operation-specific
 * data. For example, a pasteText operation includes the Range
 * that existed when the original paste took place.
 */

const _doOperation = function(undoerData) {
    // Invoked to redo the operation identified in undoerData. So, for example,
    // when operation is 'indent', we redo an indent by executing increaseQuoteLevel.
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (undoerData.operation) {
        case 'pasteText':
            _doPasteText(range, data);
            break;
        case 'format':
            MU.restoreRange();
            _toggleFormat(data, false);
            MU.backupRange();
            break;
        case 'style':
            MU.restoreRange();
            MU.replaceStyle(data.oldStyle, data.newStyle, false);
            MU.backupRange();
            break;
        case 'list':
            MU.restoreRange();
            MU.toggleListItem(data.newListType, false);
            MU.backupRange();
            break;
        case 'indent':
            MU.restoreRange();
            MU.increaseQuoteLevel(false);
            MU.backupRange();
            break;
        case 'insertLink':
            _doInsertLink(undoerData);
            break;
        case 'deleteLink':
            _doDeleteLink(undoerData);
            break;
        case 'insertImage':
            _doInsertImage(undoerData);
            break;
        case 'modifyImage':
            _doModifyImage(undoerData);
            break;
        case 'insertTable':
            _doInsertTable(undoerData);
            break;
        case 'deleteTable':
            _doDeleteTable(undoerData);
            break;
        default:
            _consoleLog("Error: Unknown doOperation " + undoerData.operation);
    };
};

const _undoOperation = function(undoerData) {
    // Invoked to undo the operation identified in undoerData. So, for example,
    // when operation is 'indent', we undo an indent by executing decreaseQuoteLevel.
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (operation) {
        case 'pasteText':
            _undoPasteText(range, data);
            break;
        case 'format':
            MU.restoreRange();
            _toggleFormat(data, false);
            MU.backupRange();
            break;
        case 'style':
            MU.restoreRange();
            MU.replaceStyle(data.newStyle, data.oldStyle, false);
            MU.backupRange();
            break;
        case 'list':
            MU.restoreRange();
            MU.toggleListItem(data.oldListType, false);
            MU.backupRange();
            break;
        case 'indent':
            MU.restoreRange();
            MU.decreaseQuoteLevel(false);
            MU.backupRange();
            break;
        case 'insertLink':
            _doDeleteLink(undoerData);
            break;
        case 'deleteLink':
            _doInsertLink(undoerData);
            break;
        case 'insertImage':
            _doModifyImage(undoerData);
            break;
        case 'modifyImage':
            _doInsertImage(undoerData);
            break;
        case 'insertTable':
            _doDeleteTable(undoerData);
            break;
        case 'deleteTable':
            _doInsertTable(undoerData);
            break;
        default:
            _consoleLog("Error: Unknown undoOperation " + undoerData.operation);
    };
};

/**
 * Without any api-level access to undo/redo, we are forced to use the execCommand to cause the
 * event to be triggered from the toolbar. Note that the _undoOperation gets called when it has
 * been placed in the stack with undoer.push (for example, for formatting or pasting)
 */
MU.undo = function() {
    document.execCommand('undo', false, null);
};

MU.redo = function() {
    document.execCommand('redo', false, null);
};

/**
 * Return the populated undoerData held on the Undoer._stack
 * If range is not passed-in, then populate range from document.getSelection()
 */
const _undoerData = function(operation, data, range=null) {
    var undoerRange;
    if (range) {
        undoerRange = range;
    } else {
        const sel = document.getSelection();
        undoerRange = (sel && (sel.rangeCount > 0)) ? sel.getRangeAt(0).cloneRange() : null;
    }
    const undoData = {
        operation: operation,
        range: undoerRange,
        data: data
    }
    return undoData;
};

const undoer = new Undoer(_undoOperation, _doOperation, null);

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
    var sel = document.getSelection();
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
    var sel = document.getSelection();
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
    var sel = document.getSelection();
    if (sel) {
        var focusNode = sel.focusNode
        if (focusNode) {
            var selElement = _findFirstParentElementInTagNames(focusNode, matchNames, excludeNames);
            if (selElement) {
                return selElement;
            }
        }
    }
    return null;
};

/// Return the all tags in tagNames that the selection is inside of
var _selectionTagsMatching = function(tagNames) {
    var sel = document.getSelection();
    var tags = [];
    if (sel) {
        var focusNode = sel.focusNode;
        while (focusNode) {
            var selElement = _findFirstParentElementInTagNames(focusNode, tagNames);
            if (selElement) {
                tags.push(selElement.tagName);
            }
            focusNode = focusNode.parentNode;
        }
    }
    return tags;
};

//MARK:- Event listeners

/**
 * The selectionChange callback is expensive on the Swift side, because it
 * tells us we need to getSelectionState to update the toolbar. This is okay
 * when we're clicking-around a document, but we need to mute the callback
 * in two situations:
 *
 * 1. We don't want to hear about the selection changing as the mouse moves
 *    during a drag-select. We track when the mouse is down. If mouse movement
 *    occurs while down, we mute. Then, when the mouse comes back up, we
 *    unmute. The net effect is to get one selectionChange event when the mouse
 *    comes back up after a drag-select, and avoid any selectionChange events while
 *    the mouse is down.
 *
 * 2. We purposely set the selection at many points; for example, after an insert
 *    operation of some kind. From here: https://developer.mozilla.org/en-US/docs/Web/API/Selection,
 *    it's clear that the selectionChanged occurs multiple times as we do things like
 *    Range.setStart(), Range.setEnd(), and Selection.setRange(). So, whenever we're
 *    setting the selection, we try to encapsulate it so that we can mute the
 *    selectionChange callback until it matters.
 *
 */
var mouseDown = false;
var _muteChanges = false;
var muteChanges = function() { _setMuteChanges(true) };
var unmuteChanges = function() { _setMuteChanges(false) };
var _setMuteChanges = function(bool) { _muteChanges = bool };

MU.editor.addEventListener('mousedown', function() {
    mouseDown = true;
    unmuteChanges();
});

MU.editor.addEventListener('mousemove', function() {
    if (mouseDown) {
        muteChanges();
    } else {
        unmuteChanges();
    };
});

MU.editor.addEventListener('mouseup', function() {
    // TODO:- I don't think this is needed so have commented it out.
    //if (moving && mouseDown) { _callback('selectionChange') };
    mouseDown = false;
    unmuteChanges();
});

document.addEventListener('selectionchange', function() {
    if (!_muteChanges) {
        _callback('selectionChange');
    //} else {
    //    _consoleLog("selection muted");
    }
});

var _selectionString = function() {
    var sel = document.getSelection();
    var range = sel.getRangeAt(0).cloneRange();
    var sc = range.startContainer;
    var so = range.startOffset;
    var ec = range.endContainer;
    var eo = range.endOffset;
    return 'start: "' + sc.textContent + '" at ' + so + ', end: "' + ec.textContent + '" at ' + eo
}

MU.editor.addEventListener('input', function() {
    //_consoleLog("input>backupRange");
    MU.backupRange();
    _callback('input');
});

var _muteFocusBlur = false;
var muteFocusBlur = function() { _setMuteFocusBlur(true) };
var unmuteFocusBlur = function() { _setMuteFocusBlur(false) };
var _setMuteFocusBlur = function(bool) { _muteFocusBlur = bool };

MU.editor.addEventListener('focus', function(e) {
    // A blur/focus cycle occurs when the undoer is used, but we don't want that to
    // be noticable by the MarkupEditor in Swift.
    //_consoleLog("focus>restoreRange");
    if (!_muteFocusBlur) {
        MU.restoreRange();
        _callback('focus');
    //} else {
    //    _consoleLog(" ignored");
    }
    // Always unmute after focus happens, since it should only happen once for
    // the undoer.push operation
    unmuteFocusBlur();    // Always unmuteChanges when focus happens
    e.preventDefault();
    MU.editor.focus({preventScroll:true})
});

MU.editor.addEventListener('blur', function() {
    // A blur/focus cycle occurs when the undoer is used, but we don't want that to
    // be noticable by the MarkupEditor in Swift. The blur during the undoer.push
    // operation will always be followed by a focus, where _muteFocusBlur will be
    // reset.
    if (!_muteFocusBlur) {
        //_consoleLog("blur>backupRange");
        MU.backupRange();
        _callback('blur');
    //} else {
    //    _consoleLog(" ignored")
    }
});

MU.editor.addEventListener('click', function(event) {
    // Notify on single-click (e.g., for following links)
    // Handle the case of multiple clicks being received without
    // doing selection
    let nclicks = event.detail;
    if (nclicks === 1) {
        _callback('click');
    } else {
        //_multiClickSelect(nclicks);
    }
});

MU.editor.addEventListener('keyup', function(event) {
    const key = event.key;
    if ((key === 'Backspace') || (key === 'Delete')) {
        _cleanUpSpans();
        _cleanUpAttributes('style');
    } else if (key === 'Enter') {
        _replaceDivIfNeeded();
    //} else if ((key === 'ArrowLeft') || (key === 'ArrowRight') || (key === 'ArrowDown') || (key === 'ArrowUp')) {
    //    _consoleLog("Arrow key")
    };
});

//MARK:- Paste

MU.editor.addEventListener('paste', function(e) {
    e.preventDefault();
    var pastedText = undefined;
    if (e.clipboardData && e.clipboardData.getData) {
        pastedText = e.clipboardData.getData('text/plain');
    }
    const undoerData = _undoerData('pasteText', pastedText);
    undoer.push(undoerData, MU.editor);
    _doOperation(undoerData);
});

const _doPasteText = function(range, data) {
    // Paste the undoerData.data text after the range.endOffset or range.endContainer
    // TODO: Handle non-collapsed ranges
    let originalText = range.endContainer.textContent;
    let newText = originalText.substring(0, range.endOffset) + data + originalText.substr(range.endOffset);
    range.endContainer.textContent = newText;
    let newRange = document.createRange();
    newRange.setStart(range.endContainer, range.endOffset + data.length);
    newRange.setEnd(range.endContainer, range.endOffset + data.length);
    let selection = document.getSelection();
    selection.removeAllRanges();
    selection.addRange(newRange);
    _callback('input');
}

const _undoPasteText = function(range, data) {
    // The pasted text data was placed after the range.endOffset in endContainer
    // Make sure it's still there and if so, remove it, leaving the selection
    // TODO: Handle non-collapsed ranges
    let textContent = range.endContainer.textContent;
    let existingText = textContent.slice(range.endOffset, range.endOffset + data.length);
    if (existingText === data) {
        let startText = textContent.slice(0, range.endOffset);
        let endText = textContent.slice(range.endOffset + data.length);
        range.endContainer.textContent = startText + endText;
        let newRange = document.createRange();
        newRange.setStart(range.endContainer, range.endOffset);
        newRange.setEnd(range.endContainer, range.endOffset);
        let selection = document.getSelection();
        selection.removeAllRanges();
        selection.addRange(newRange);
        _callback('input');
    } else {
        _consoleLog('undo pasteText mismatch: ' + existingText);
    }
}

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
};

var _consoleLog = function(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    var message = JSON.stringify(messageDict);
    _callback(message);
};

MU.emptyDocument = function() {
    while (MU.editor.firstChild) {
        MU.editor.removeChild(MU.editor.firstChild);
    };
    var p = document.createElement('p');
    p.appendChild(document.createElement('br'));
    MU.editor.appendChild(p);
    var sel = document.getSelection();
    var range = document.createRange();
    muteChanges();
    range.setStart(p, 1);
    range.setEnd(p, 1);
    sel.removeAllRanges();
    unmuteChanges();
    sel.addRange(range);
    //_consoleLog("emptyDocument>backupRange");
    MU.backupRange();
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
    _initializeRange()
};

/**
 * Gets the contents of the editor element
 * @return {String} The HTML for the editor element
 */
MU.getHTML = function() {
    return MU.editor.innerHTML;
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

//MARK:- Formatting
// Note:
// 1. Formats (B, I, U, DEL, SUB, SUP) are toggled off and on
// 2. Formats can be nested, but not inside themselves; e.g., B cannot be within B

MU.toggleBold = function() {
    _toggleFormat('b');
};

MU.toggleItalic = function() {
    _toggleFormat('i');
};

MU.toggleUnderline = function() {
    _toggleFormat('u');
};

MU.toggleStrike = function() {
    _toggleFormat('del');
};

MU.toggleCode = function() {
    _toggleFormat('code');
};

MU.toggleSubscript = function() {
    _toggleFormat('sub');
};

MU.toggleSuperscript = function() {
    _toggleFormat('sup');
};

const _toggleFormat = function(type, undoable=true) {
    // Turn the format tag off and on for selection
    // Called directly on undo/redo so that nothing new is pushed onto the undo stack
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, [type.toUpperCase()]);
    if (existingElement) {
        _unsetTag(existingElement, sel);
    } else {
        _setTag(type, sel);
    }
    if (undoable) {
        // Both _setTag and _unsetTag reset the selection when they're done;
        // however, the selection should be left in a way that undoing is accomplished
        // by just re-executing the _toggleFormat. So, for example, _toggleFormat while
        // selected between characters in a word will toggleFormat for the word, but leave
        // the selection at the same place in that word. Also, toggleFormat when a word
        // has a range selected will leave the same range selected.
        MU.backupRange()
        const undoerData = _undoerData('format', type);
        undoer.push(undoerData, MU.editor);
        MU.restoreRange()
    }
    _callback('input');
}

//MARK:- Raw and formatted text

//var _configureTurndownService = function() {
//    var gfm = turndownPluginGfm.gfm;
//    var turndownService = new TurndownService();
//    turndownService.use(gfm);
//    turndownService.addRule('strikethrough', {
//      filter: ['del', 's', 'strike'],
//      replacement: function (content) {
//        return '~~' + content + '~~'
//      }
//    })
//    return turndownService;
//};
//
//const _turndownService = _configureTurndownService();
//
//var _configureShowdownService = function() {
//    var converter = new showdown.Converter();
//    converter.setOption('noHeaderId', true);
//    converter.setOption('strikethrough', true);
//    converter.setOption('parseImgDimensions', true);
//    return converter;
//}
//
//const _showdownService = _configureShowdownService();

//MU.getMarkdown = function() {
//    return _turndownService.turndown(MU.editor.innerHTML);
//};
//
//MU.getRoundTrip = function() {
//    return _showdownService(MU.getMarkdown());
//};

MU.getPrettyHTML = function() {
    //return _prettify(MU.editor.innerHTML);
    return MU.editor.innerHTML.replace(/<p/g, '\n<p').replace(/<h/g, '\n<h').replace(/<div/g, '\n<div').replace(/<table/g, '\n<table').trim();
};

var _prettify = function(html) {
    // From https://stackoverflow.com/a/60338028/8968411
    var tab = '\t';
    var result = '';
    var indent= '';

    html.split(/>\s*</).forEach(function(element) {
        if (element.match( /^\/\w/ )) {
            indent = indent.substring(tab.length);
        }

        result += indent + '<' + element + '>\n\n';

        if (element.match( /^<?\w[^>]*[^\/]$/ ) && !element.startsWith("input")  ) {
            indent += tab;
        }
    });

    return result.substring(1, result.length-3);
}

//MARK:- Styling
// 1. Styles (P, H1-H6) are applied to blocks
// 2. Unlike formats, styles are never nested (so toggling makes no sense)
// 3. Every block in a LogEntry should have some style

MU.replaceStyle = function(oldStyle, newStyle, undoable=true) {
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
        if (undoable) {
            MU.backupRange();
            const undoerData = _undoerData('style', { oldStyle: oldStyle, newStyle: newStyle });
            undoer.push(undoerData, MU.editor);
            MU.restoreRange()
        }
        _callback('input');
    };
};

//MARK:- Nestables, including lists and block quotes

MU.toggleListItem = function(newListType, undoable=true) {
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
    var oldListType = selectionState['list'];
    var isInListItem = selectionState['li'];
    // We will capture the newSelNode for restoring the selection along the way
    var newSelNode = null;
    if (oldListType) {
        // TOP-LEVEL CASE: We selected something in a list
        var listElement = _findFirstParentElementInTagNames(selNode, [oldListType]);
        var listItemElementCount = _childrenWithTagNameCount(listElement, 'LI');
        if (isInListItem) {
            // CASE: We selected a list item inside of a list
            var listItemElement = _findFirstParentElementInTagNames(selNode, ['LI']);
            if (oldListType === newListType) {
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
                if (listItemElementCount === 1) {
                    // If this is the only item in the list, then change the list type rather than
                    // change the one element.
                    if (newListType) {
                        newSelNode = _replaceTag(newListType, listElement);
                    } else {
                        // We are unsetting the list for a single-item list, so just remove both so
                        // the list is removed.
                        _unsetTag(listItemElement, sel);
                        _unsetTag(listElement, sel);
                    }
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
            if (oldListType === newListType) {
                // We want the entire styled element to be a list item in the existing list
                newSelNode = _replaceNodeWithListItem(styledElement);
            } else {
                // We want to make the entire styled element the first item in a new newListType list
                newSelNode = _replaceNodeWithList(newListType, styledElement);
            }
        } else if (oldListType === newListType) {
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
    if (undoable) {
        MU.backupRange();
        const undoerData = _undoerData('list', { newListType: newListType, oldListType: oldListType });
        undoer.push(undoerData, MU.editor);
        MU.restoreRange();
    }
    _callback('input');
};

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
};

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
};

MU.increaseQuoteLevel = function(undoable=true) {
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
    if (undoable) {
        MU.backupRange();
        const undoerData = _undoerData('indent', null);
        undoer.push(undoerData, MU.editor);
        MU.restoreRange();
    }
    _callback('input');
}

MU.decreaseQuoteLevel = function(undoable=true) {
    // Remove an existing BLOCKQUOTE if it exists
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    var existingElement = _findFirstParentElementInTagNames(selNode, ['BLOCKQUOTE']);
    if (existingElement) {
        _unsetTag(existingElement, sel);
        if (undoable) {
            MU.backupRange();
            const undoerData = _undoerData('indent', null);
            undoer.push(undoerData, MU.editor);
            MU.restoreRange();
        }
        _callback('input');
    }
}

//MARK:- Range operations

/**
 * Make sure selection is set to something reasonable when starting
 * or setting HTML.
 * Something reasonable here means the front of the first text node,
 * and creating that element in an empty document if it doesn't exist.
 * We make the contentEditable editor have focus when done. From a
 * the iOS perspective, this doesn't mean we becomeFirstResponder.
 * This should be done at the application level when the MarkupDelegate
 * signals contentDidLoad, because with more than one MarkupWKWebView,
 * the application has to decide when to becomeFirstResponder.
 */
var _initializeRange = function() {
    var firstTextNode = _getFirstChildOfTypeWithin(MU.editor, Node.TEXT_NODE);
    var selection = document.getSelection();
    selection.removeAllRanges();
    var range = document.createRange();
    if (firstTextNode) {
        muteChanges();
        range.setStart(firstTextNode, 0);
        range.setEnd(firstTextNode, 0);
        unmuteChanges();
        selection.addRange(range);
        MU.backupRange();
    } else {
        MU.emptyDocument()
    }
    MU.editor.focus();
}

const _rangeProxy = function() {
    // A range obtained from selection.getRangeAt(0).cloneRange() can end up being changed
    // as focus changes, etc. So, to avoid the problem, return an object with properties
    // for the startContainer, startOffset, endContainer, and endOffset.
    const selection = document.getSelection();
    if ((selection) && (selection.rangeCount > 0)) {
        var range = selection.getRangeAt(0).cloneRange();
        return _rangeCopy(range);
    } else {
        return null;
    };
};

const _rangeCopy = function(range) {
    return {
        'startContainer': range.startContainer,
        'startOffset': range.startOffset,
        'endContainer': range.endContainer,
        'endOffset': range.endOffset
    };
}

const _restoreRange = function(rangeProxy) {
    if (rangeProxy && rangeProxy.length === 0) {
        _consoleLog("Attempt to restore invalid range");
        new Error("Attempt to restore invalid range");
        return;
    }
    var selection = document.getSelection();
    selection.removeAllRanges();
    var range = document.createRange();
    range.setStart(rangeProxy.startContainer, rangeProxy.startOffset);
    range.setEnd(rangeProxy.endContainer, rangeProxy.endOffset);
    selection.addRange(range);
}

MU.backupRange = function() {
    MU.currentSelection = _rangeProxy();
};

MU.restoreRange = function() {
    _restoreRange(MU.currentSelection);
};

const _rangeString = function(range) {
    const startContainer = range.startContainer;
    const endContainer = range.endContainer;
    var startContainerType, startContainerContent, endContainerType, endContainerContent;
    if (startContainer.nodeType === Node.TEXT_NODE) {
        startContainerType = "<TextElement>"
        startContainerContent = startContainer.textContent;
    } else {
        startContainerType = "<" + startContainer.tagName + ">";
        startContainerContent = startContainer.innerHTML;
    }
    if (endContainer.nodeType === Node.TEXT_NODE) {
        endContainerType = "<TextElement>"
        endContainerContent = endContainer.textContent;
    } else {
        endContainerType = "<" + endContainer.tagName + ">";
        endContainerContent = endContainer.innerHTML;
    }
    return "range:\n" + "  startContainer: " + startContainerType + ", content: " + startContainerContent + "\n" + "  startOffset: " + range.startOffset + "\n" + "  endContainer: " + endContainerType + ", content: " + endContainerContent + "\n" + "  endOffset: " + range.endOffset
}

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
    var sel = document.getSelection();
    // this.createSelectionFromRange sel, range
    MU.addRangeToSelection(sel, range);
};

//MARK:- Focus and blur

//MU.focus = function() {
//    var range = document.createRange();
//    range.selectNodeContents(MU.editor);
//    range.collapse(false);
//    var selection = document.getSelection();
//    selection.removeAllRanges();
//    selection.addRange(range);
//    MU.editor.focus();
//};
//
//MU.focusAtPoint = function(x, y) {
//    var range = document.caretRangeFromPoint(x, y) || document.createRange();
//    var selection = document.getSelection();
//    selection.removeAllRanges();
//    selection.addRange(range);
//    MU.editor.focus();
//};
//
//MU.blurFocus = function() {
//    MU.editor.blur();
//};

//MARK:- Clean up of weird things to avoid ugly HTML

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
 * If selection is in a DIV and the previousSibling is an ElementNode, then
 * replace the DIV with a tag of the same type as previousSibling. We use this
 * to prevent DIVs from being inserted when Enter is pressed.
 */
var _replaceDivIfNeeded = function() {
    var sel = document.getSelection();
    var selNode = (sel) ? sel.focusNode : null;
    if ((selNode.nodeType === Node.ELEMENT_NODE) && (selNode.tagName === 'DIV')) {
        var prevSib = selNode.previousSibling;
        if (prevSib.nodeType === Node.ELEMENT_NODE) {
            var range = sel.getRangeAt(0).cloneRange();
            var newElement = document.createElement(prevSib.tagName);
            newElement.appendChild(document.createElement('br'));
            selNode.replaceWith(newElement);
            range.setStart(newElement, 0);
            range.setEnd(newElement, 0);
            sel.removeAllRanges();
            sel.addRange(range);
            _callback('input');
        };
    };
};
                                
//MARK:- Explicit handling of multi-click

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
                                
//MARK:- Selection

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
    // Selected text
    state['selection'] = _getSelectionText();
    // Link
    var linkAttributes = _getLinkAttributesAtSelection();
    state['href'] = linkAttributes['href'];
    state['link'] = linkAttributes['link'];
    // Image
    var imageAttributes = _getImageAttributesAtSelection();
    state['src'] = imageAttributes['src'];
    state['alt'] = imageAttributes['alt'];
    state['scale'] = imageAttributes['scale'];
    state['frame'] = imageAttributes['frame'];
    // Table
    var tableAttributes = _getTableAttributesAtSelection();
    state['table'] = tableAttributes['table'];
    state['thead'] = tableAttributes['thead'];
    state['tbody'] = tableAttributes['tbody'];
    state['header'] = tableAttributes['header'];
    state['colspan'] = tableAttributes['colspan'];
    state['rows'] = tableAttributes['rows'];
    state['cols'] = tableAttributes['cols'];
    state['row'] = tableAttributes['row'];
    state['col'] = tableAttributes['col'];
    // Style
    state['style'] = _getSelectionStyle();
    state['list'] = _firstSelectionTagMatching(['UL', 'OL']);
    if (state['list']) {
        // If we are in a list, then we might or might not be in a list item
        state['li'] = _firstSelectionTagMatching(['LI']).length > 0;
    } else {
        // But if we're not in a list, we deny we are in a list item
        state['li'] = false;
    }
    state['quote'] = _firstSelectionTagMatching(['BLOCKQUOTE']).length > 0;
    // Format
    var formatTags = _getFormatTags();
    state['bold'] = formatTags.includes('B');
    state['italic'] = formatTags.includes('I');
    state['underline'] = formatTags.includes('U');
    state['strike'] = formatTags.includes('DEL');
    state['sub'] = formatTags.includes('SUB');
    state['sup'] = formatTags.includes('SUP');
    state['code'] = formatTags.includes('CODE');
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
};

var _getFormatTags = function() {
    return _selectionTagsMatching(['B', 'I', 'U', 'DEL', 'SUB', 'SUP', 'CODE']);
};
                                
var _getTableTags = function() {
    return _selectionTagsMatching(['TABLE', 'THEAD', 'TBODY', 'TD', 'TR', 'TH'])
};

var _getSelectionText = function() {
    var sel = document.getSelection();
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
 * Insert a link to url. The selection has to be across a range.
 * When done, re-select the range and back it up.
 */
MU.insertLink = function(url, undoable=true) {
    MU.restoreRange();
    var sel = document.getSelection();
    if (!sel || (sel.rangeCount === 0)) { return };
    var range;
    if (sel.isCollapsed) {
        range = _wordRangeAtCaret()
    } else {
        range = sel.getRangeAt(0).cloneRange();
    }
    var el = document.createElement('a');
    el.setAttribute('href', url);
    el.appendChild(range.extractContents());
    range.deleteContents();
    range.insertNode(el);
    range.setStart(el.firstChild, 0);
    range.setEnd(el.firstChild, el.firstChild.textContent.length);
    sel.removeAllRanges();
    sel.addRange(range);
    // Note because the selection is changing while the view is not focused,
    // we need to backupRange() so we can get it back when we come back
    // into focus later.
    MU.backupRange();
    if (undoable) {
        const undoerData = _undoerData('insertLink', url);
        undoer.push(undoerData, MU.editor);
        MU.restoreRange();
    }
    _callback('input');
    return el;
};

/**
 * Remove the link at the selection
 */
MU.deleteLink = function(undoable=true) {
    // When we call this method, sel is the text inside of an anchorNode
    MU.restoreRange();
    var sel = document.getSelection();
    if (sel) {
        var element = sel.anchorNode.parentElement;
        if ('A' === element.nodeName) {
            // Before we _unsetTag, we know what element is and can determine what to select
            // after it is gone. We want to select all of the text that was linked-to
            // as if the user had selected the entire link. After selecting it, then set that
            // as the backed-up range before unsetting the tag. So, if we started with a caret
            // selection inside of a link and removed the link, we will end up with the entire
            // linked-to text selected when done. Now the undo operation knows the text selection
            // and when undo happens, the link can be properly restored.
            var linkRange = document.createRange();
            const linkText = element.firstChild;
            linkRange.setStart(linkText, 0);
            linkRange.setEnd(linkText, linkText.length);
            sel.removeAllRanges();
            sel.addRange(linkRange);
            _unsetTag(element, sel);
            MU.backupRange();
            if (undoable) {
                const undoerData = _undoerData('deleteLink', element.href);
                undoer.push(undoerData, MU.editor);
                MU.restoreRange();
            }
            _callback('input');
        }
    }
}

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

/**
 * Do the insertLink operation following a deleteLink operation
 * Used to undo the deleteLink operation and to do the insertLink operation.
 */
const _doInsertLink = function(undoerData) {
    // Reset the selection based on the range after the link was removed,
    // then insert the link at that range. After the link is re-inserted,
    // the insertLink operation leaves the selection properly set,
    // but we have to update the undoerData.range to reflect it.
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(undoerData.range);
    MU.backupRange();
    MU.insertLink(undoerData.data, false);
    var newSel = document.getSelection();
    undoerData.range = newSel.getRangeAt(0).cloneRange();
}

/**
 * Do the deleteLink operation following an insertLink operation
 * Used to undo the insertLink operation and to do the deleteLink operation.
 */
const _doDeleteLink = function(undoerData) {
    // Reset the selection based on the range after insert was done,
    // then remove the link at that range. When the link is re-removed,
    // the deleteLink operation leaves the selection properly set,
    // but we have to update the undoerData.range to reflect it.
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(undoerData.range);
    MU.backupRange();
    MU.deleteLink(false);
    var newSel = document.getSelection();
    undoerData.range = newSel.getRangeAt(0).cloneRange();
}

//MARK:- Images

/**
 * Insert the image at src with alt text, signaling updateHeight when done loading.
 * All insert operations that involve user interaction outside of JavaScript
 * need to be preceded by backupRange so that range can be restored prior
 * to the insert* operation.
 * We leave the selection after the inserted image.
 * The operation will cause a selectionChange event.
 * Return the image element that is created, so we can use it for undoing.
 */
MU.insertImage = function(src, alt, scale=100, undoable=true) {
    MU.restoreRange();
    var sel = document.getSelection();
    var range = sel.getRangeAt(0).cloneRange();
    var img = document.createElement('img');
    img.setAttribute('src', src);
    if (alt) { img.setAttribute('alt', alt) };
    if (scale !== 100) {
        img.setAttribute('width', scale);
        img.setAttribute('height', scale);
    }
    img.setAttribute('tabindex', -1);    // Allows us to select the image
    img.onload = MU.updateHeight;
    var range = sel.getRangeAt(0).cloneRange();
    range.insertNode(img);
    // After inserting the image, we want to leave the selection at the beginning
    // of the nextTextElement after it for inline images. If there is no such thing,
    // then find the next best thing.
    var nearestTextNode = _getFirstChildOfTypeNear(img, Node.TEXT_NODE);
    var newRange = document.createRange();
    if (nearestTextNode) {
        newRange.setStart(nearestTextNode, 0);
        newRange.setEnd(nearestTextNode, 0)
    } else {
        var nextSibling = img.nextSibling;
        if (nextSibling && (nextSibling.nodeName === 'BR')) {
            var newTextNode = document.createTextNode('');
            nextSibling.replaceWith(newTextNode);
            newRange.setStart(newTextNode, 0);
            newRange.setEnd(newTextNode, 0)
        } else {
            newRange.setStart(img, 0);
            newRange.setEnd(img, 0)
        };
    }
    sel.removeAllRanges();
    sel.addRange(newRange);
    MU.backupRange();
    // Track image insertion on the undo stack if necessary and hold onto the new image element's range
    // Note that the range tracked on the undo stack is not the same as the selection, which has been
    // set to make continued typing easy after inserting the image.
    if (undoable) {
        var imgRange = document.createRange();
        imgRange.selectNode(el);
        const undoerData = _undoerData('insertImage', {src: src, alt: alt, scale: scale}, imgRange);
        undoer.push(undoerData, MU.editor);
        MU.restoreRange();
    }
    _callback('input');
    return img;
};

/**
 * Modify the attributes of the image at selection.
 * If src is null, then remove the image.
 * Scale is a percentage like '80' where null means 100%.
 * Scale is always expressed relative to full scale.
 * Only removing an image is undoable.
 */
MU.modifyImage = function(src, alt, scale, undoable=true) {
    MU.restoreRange();
    var img = _getElementAtSelection('IMG');
    if (img) {
        if (src) {
            img.setAttribute('src', src);
            if (alt) {
                img.setAttribute('alt', alt);
            } else {
                img.removeAttribute('alt');
            }
            if (scale) {
                let width = _percentInt(scale, img.naturalWidth);
                let height = _percentInt(scale, img.naturalHeight);
                img.setAttribute('width', width);
                img.setAttribute('height', height);
            } else {
                img.removeAttribute('width');
                img.removeAttribute('height');
            }
            MU.restoreRange()
        } else {
            // Before removing the img, record the existing src, alt, and scale
            const deletedSrc = img.getAttribute('src');
            const deletedAlt = img.getAttribute('alt');
            const deletedScale = img.getAttribute('width');
            _deleteAndResetSelection(img);
            if (undoable) {
                const undoerData = _undoerData('modifyImage', {src: deletedSrc, alt: deletedAlt, scale: deletedScale});
                undoer.push(undoerData, MU.editor);
                MU.restoreRange();
            }
        };
        _callback('input');
    };
};

/**
 * If the current selection's anchorNode is an IMG tag, get the src and alt.
 * @returns {Dictionary} with src and alt as keys; empty if not an image
 */
var _getImageAttributesAtSelection = function() {
    var attributes = {};
    var img = _getElementAtSelection('IMG');
    if (img) {
        attributes['src'] = img.getAttribute('src');
        attributes['alt'] = img.getAttribute('alt');
        var scale = _imgScale(img);
        if (scale) {
            attributes['scale'] = scale;
        };
        var rect = img.getBoundingClientRect();
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

/**
 * Do the insertImage operation following a modifyImage operation
 * Used to undo the modifyImage/remove operation and to do the insertImage operation.
 */
const _doInsertImage = function(undoerData) {
    // Reset the selection based on the range after the image was removed,
    // then insert the image at that range. After the image is re-inserted,
    // the insertImage operation leaves the selection properly set to keep
    // typing, but we need to update the undoerData.range with the range
    // for the newly (re)created image element.
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(undoerData.range);
    MU.backupRange();
    const el = MU.insertImage(undoerData.data.src, undoerData.data.alt, undoerData.data.scale, false);
    const range = document.createRange();
    range.selectNode(el);
    undoerData.range = range;
}

/**
 * Do the modifyImage operation following an insertImage operation
 * Used to undo the insertImage operation and to do the modifyImage/remove operation.
 */
const _doModifyImage = function(undoerData) {
    // The undoerData has the range to select to remove the image;
    // iow, the image exists when modifyImage is called.
    // Once the image is removed, the selection is set properly, and
    // we don't want to update the undoerData.
    // Remove image is done with modifyImage but with src=null.
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(undoerData.range);
    MU.backupRange();
    MU.modifyImage(null, null, null, false);
}

//MARK:- Tables

/**
 * Insert an empty table with the specified number of rows and cols.
 * All insert operations that involve user interaction outside of JavaScript
 * need to be preceded by backupRange so that range can be restored prior
 * to the insert* operation.
 * We leave the selection in the first cell of the first row.
 * The operation will cause a selectionChange event.
 */
MU.insertTable = function(rows, cols, undoable=true) {
    MU.restoreRange();
    var sel = document.getSelection();
    var range = sel.getRangeAt(0).cloneRange();
    var table = document.createElement('table');
    var tbody = document.createElement('tbody');
    var firstRow;
    for (let row = 0; row < rows; row++) {
        var tr = document.createElement('tr');
        if (row === 0) { firstRow = tr };
        for (let col = 0; col < cols; col++) {
            var td = document.createElement('td');
            tr.appendChild(td);
        };
        tbody.appendChild(tr);
    };
    table.appendChild(tbody);
    var range = sel.getRangeAt(0).cloneRange();
    range.insertNode(table);
    if (firstRow) {
        var newRange = document.createRange();
        newRange.setStart(firstRow, 0);
        newRange.setEnd(firstRow, 0)
        sel.removeAllRanges();
        sel.addRange(newRange);
    };
    MU.backupRange();
    // Track table insertion on the undo stack if necessary and hold onto the new table element's range
    // Note that the range tracked on the undo stack is not the same as the selection, which has been
    // set to make continued typing easy after inserting the table.
    if (undoable) {
        var tableRange = document.createRange();
        tableRange.selectNode(table);
        const undoerData = _undoerData('insertTable', {rows: rows, cols: cols}, tableRange);
        undoer.push(undoerData, MU.editor);
        MU.restoreRange();
    }
    _callback('input');
    return table;
};

/**
 * Delete the entire table at the selection
 */
MU.deleteTable = function(undoable=true) {
    const elements = _getTableElementsAtSelection();
    var table = elements['table'];
    if (table) {
        const outerHTML = table.outerHTML;
        _deleteAndResetSelection(table);
        if (undoable) {
            const undoerData = _undoerData('deleteTable', outerHTML);
            undoer.push(undoerData, MU.editor);
            MU.restoreRange();
        };
        _callback('input');
    };
};

/*
 * If the selection is inside a TABLE, populate attributes with the information
 * about the table and what is selected in it.
 * Note that the table likely has empty #text elements in it depending on how the
 * HTML is formatted, so we use 'children' to get only ELEMENT_NODEs.
 * The values in elements are JavaScript objects of various kinds; however, the
 * values in attributes have to be consumable on the Swift side. So, for example,
 * the elements['thead'] is the HTML Table Heade Element, whereas attributes['thead']
 * is either true or false indicating whether the selection is in the header.
 * Similarly, elements['header'] and ['colspan'] are true or false so
 * can be stored in attributes directly.
 */
var _getTableAttributesAtSelection = function() {
    var attributes = {};
    var elements = _getTableElementsAtSelection();
    attributes['table'] = elements['table'] != null;
    if (!attributes['table']) { return attributes };
    attributes['thead'] = elements['thead'] != null;
    attributes['tbody'] = elements['tbody'] != null;
    attributes['header'] = elements['header'];
    attributes['colspan'] = elements['colspan'];
    attributes['cols'] = elements['cols'];
    attributes['rows'] = elements['rows'];
    attributes['row'] = elements['row'];
    attributes['col'] = elements['col'];
    return attributes;
};

/**
 * Return all the table elements at the selection.
 * The selection has to be in a TD or TH element. Then, we
 * walk up the parent chain to TABLE, populating elements
 * as we go. We compute the row and col of the selection, too.
 * If anything is unexpected along the way, we return an empty
 * dictionary.
 */
var _getTableElementsAtSelection = function() {
    var elements = {};
    var cell = _firstSelectionNodeMatching(['TD', 'TH']);
    if (cell) {
        var _cell = cell;
        // Track the cell the selection is in
        if (cell.nodeName === 'TD') {
            elements['td'] = cell;
        } else {
            elements['th'] = cell;
        }
        // Find the column the selection is in, since we know it immediately
        var colCount = 0;
        while (_cell.previousSibling) {
            _cell = _cell.previousSibling;
            if (_cell.nodeType === cell.nodeType) { colCount++; };
        };
        elements['col'] = colCount;
        // Track the row the selection is in
        var row = cell.parentNode;
        if (row.nodeName === 'TR') {
            elements['tr'] = row;
        } else {
            return {};
        }
        // Track whether we are in the header or body
        var section = row.parentNode;
        if (section.nodeName === 'TBODY') {
            elements['tbody'] = section;
            // If the selection is in the body, then we can find the row
            var _row = row;
            var rowCount = 0;
            while (_row.previousSibling) {
                _row = _row.previousSibling;
                if (_row.nodeType === row.nodeType) { rowCount++; };
            };
            elements['row'] = rowCount;
        } else if (section.nodeName === 'THEAD') {
            elements['thead'] = section;
        } else {
            return {};
        };
        // Track the selected table
        var table = section.parentNode;
        if (table.nodeName === 'TABLE') {
            elements['table'] = table;
        } else {
            return {};
        }
        // Track the size of the table and whether the header spans columns
        const [rows, cols, header, colspan] = _getRowsCols(table);
        elements['rows'] = rows;
        elements['cols'] = cols;
        elements['header'] = header
        elements['colspan'] = colspan;
    };
    return elements;
};

/**
 * Since we might select an element in the header or the body of table, we need a single
 * way to get the size of the table body in terms rows and cols regardless of what was
 * selected. The header always has one row that is not counted in terms of the table size.
 * When we have a TBODY, it always defines rowCount and colCount. If we have a THEAD and
 * no TBODY, then THEAD defines colcount either using the value in colspan if it exists, or
 * by the number of TH children of THEAD. In both of those cases (no TBODY), rowCount
 * is zero. The colspan value is returned so we know if the header spans columns.
 * Externally, we only need to know if a header exists. Internally in JavaScript, we can
 * always _getSection for the table to find out.
 */
var _getRowsCols = function(table) {
    var rowCount = 0;
    var colCount = 0;
    var headerExists = false;
    var colspan = null;
    var children = table.children;
    for (let i=0; i<children.length; i++) {
        var section = children[i];
        var rows = section.children;
        if (rows.length > 0) {
            var row = rows[0];
            var cols = row.children;
            if (section.nodeName === 'TBODY') {
                rowCount = rows.length;
                colCount = cols.length;
            } else if (section.nodeName === 'THEAD') {
                headerExists = true;
                if (cols.length > 0) {
                    colspan = _numberAttribute(cols[0], 'colspan');
                };
                if (colspan && (colCount === 0)) {
                    colCount = colspan;
                } else if (colCount === 0) {
                    colCount = cols.length;
                };
            };
        };
    };
    let colSpanExists = colspan != null;
    return [ rowCount, colCount, headerExists, colSpanExists ];
}

/**
 * Return the named section of the table (e.g., name === 'THEAD' or 'TBODY')
 */
var _getSection = function(table, name) {
    var children = table.children;
    for (let i=0; i<children.length; i++) {
        var section = children[i];
        if (section.nodeName === name) {
            return section;
        };
    };
    return null;
};

/**
 * Add a row before or after the current selection, whether it's in the header or body.
 * For rows, AFTER = below; otherwise above.
 */
MU.addRow = function(direction) {
    MU.backupRange();
    var tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    var table = tableElements['table'];
    var tr = tableElements['tr'];
    var tbody = tableElements['tbody'];
    var thead = tableElements['thead'];
    var rows = tableElements['rows'];
    var cols = tableElements['cols'];
    // Create an empty row with the right number of elements
    var newRow = document.createElement('tr');
    for (let i=0; i<cols; i++) {
        var td = document.createElement('td');
        newRow.appendChild(td);
    };
    // For reference, form of insertBefore is...
    //  let insertedNode = parentNode.insertBefore(newNode, referenceNode)
    if (thead) {
        if (direction === 'AFTER') {
            // We are in the header
            // A row after the header is the first row of the body
            if (rows > 0) {
                // There is at least one row in the body, so put the new one first
                var body = _getSection(table, 'TBODY');
                if (body) {
                    var firstRow = body.children[0];
                    body.insertBefore(newRow, firstRow);
                }
            } else {
                // The body doesn't exist because rows === 0
                // Create it and put the new row in it
                var body = document.createElement('tbody');
                body.appendChild(tr);
                table.appendChild(body)
            }
        }
    } else if (tbody) {
        if (direction === 'AFTER') {
            // We are in the body, so tr is the selected row
            // If tr.nextSibling is null, newRow will be inserted
            // after tr.
            tbody.insertBefore(newRow, tr.nextSibling);
        } else {
            tbody.insertBefore(newRow, tr)
        }
    } else {
        _consoleLog("Could not add row");
    }
    MU.restoreRange();
    _callback('input');
};

/**
 * Add a col before or after the current selection, whether it's in the header or body.
 */
MU.addCol = function(direction) {
    MU.backupRange();
    var tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    var table = tableElements['table'];
    var col = tableElements['col'];
    var cols = tableElements['cols'];
    var tbody = tableElements['tbody'];
    var thead = tableElements['thead'];
    var colspan = tableElements['colspan'];
    var tr, td, th;
    if (tbody || (thead && !colspan)) {
        // We have selected the body of the table or the header.
        // In the case of selecting the header, it is a non-colspan header,
        // so col is meaningful (otherwise it is always 1 in a colspan header).
        // Loop over all rows in the body, adding a new td in each one
        var body = _getSection(table, 'TBODY');
        if (body) {
            var rows = body.children;       // Only tr elements
            for (let j=0; j<rows.length; j++) {
                tr = rows[j];
                td = tr.children[col];  // Only td elements
                // Then insert a new td before or after
                var newTd = document.createElement('td');
                // For reference, form of insertBefore is...
                //  let insertedNode = parentNode.insertBefore(newNode, referenceNode)
                if (direction === 'AFTER') {
                    tr.insertBefore(newTd, td.nextSibling);
                } else {
                    tr.insertBefore(newTd, td);
                }
            }
        };
        var header = _getSection(table, 'THEAD');
        if (header) {
            // If the header exists for this table, we need to expand it, too.
            tr = header.children[0];    // Only tr elements
            th = tr.children[0];
            if (colspan) {
                th.setAttribute('colspan', cols+1)
            } else {
                th = tr.children[col];           // Only th elements
                // Then insert a new td before or after
                var newTh = document.createElement('th');
                // For reference, form of insertBefore is...
                //  let insertedNode = parentNode.insertBefore(newNode, referenceNode)
                if (direction === 'AFTER') {
                    th.insertBefore(newTh, th.nextSibling);
                } else {
                    th.insertBefore(newTh, th);
                }
            }
        }
    }
    MU.restoreRange();
    _callback('input');
}

MU.addHeader = function(colspan) {
    MU.backupRange();
    var tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tbody has to be selected
    var table = tableElements['table'];
    var cols = tableElements['cols'];
    var tbody = tableElements['tbody'];
    if (tbody) {
        var header = document.createElement('thead');
        var tr = document.createElement('tr');
        if (colspan) {
            header.setAttribute('colspan', cols);
            var th = document.createElement('th');
            tr.appendChild(th);
            header.appendChild(tr);
        } else {
            for (let i=0; i<cols; i++) {
                var th = document.createElement('th');
                tr.appendChild(th);
            }
            header.appendChild(tr);
        };
        table.insertBefore(header, tbody);
    }
    MU.restoreRange();
    _callback('input');
}

MU.deleteRow = function() {
    MU.backupRange();
    var tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    // tr might be the row in the header or a row in the body
    var table = tableElements['table'];
    var thead = tableElements['thead'];
    var tbody = tableElements['tbody'];
    var tr = tableElements['tr'];
    var newTr;
    if (thead) {
        // We are going to delete the header,
        // So we will identify the first body cell
        // for selection after deleting
        var body = _getSection(table, 'TBODY');
        if (body) {
            newTr = body.firstChild;
        }
    } else if (tbody) {
        // We are going to delete a body row,
        // So we will choose the nextSib if there is one,
        // or prevSib if not, or even the header if we have to
        // for selection after deleting
        if (tr.nextSibling) {
            newTr = tr.nextSibling;
        } else if (tr.previousSibling) {
            newTr = tr.previousSibling;
        } else if (_getSection(table, 'THEAD')) {
            var header = _getSection(table, 'THEAD');
            newTr = header.firstChild;
        }
    }
    var sel = document.getSelection();
    if (newTr) {
        // There is a row left, so we will do the remove and select the first element of the newTr
        tr.parentNode.removeChild(tr);
        _selectCol(newTr, 0)
    } else {
        // We just removed everything in the table, so let's just get rid of it.
        _deleteAndResetSelection(table);
    }
    _callback('input');
}

MU.deleteCol = function() {
    MU.backupRange();
    var tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    // tr might be the row in the header or a row in the body
    var table = tableElements['table'];
    var thead = tableElements['thead'];
    var tbody = tableElements['tbody'];
    var newTr = tableElements['tr'];
    var cols = tableElements['cols'];
    var col = tableElements['col'];
    var colspan = tableElements['colspan'];
    var newCol;
    if ((tbody || (thead && !colspan)) && cols > 1) {
        // newCol identifies the column to select in newTr after deleting
        if (col === cols - 1) {
            newCol = col - 1;   // In the last col, so decrement 1
        } else {
            newCol = col;       // Leave in the same column (i.e., the one after the col being deleted)
        }
    } else if ((cols > 1) && thead && colspan) {
        // We really can't do anything when delete column is selected when in header w/colspan
        // since we have no idea what column to delete unless there is only one
        return;
    } else if (cols === 1) {
        // We are deleting the last column of the table
        _deleteAndResetSelection(table);
        _callback('input');
        return;
    }
    // newCol should be non-null if we got here; iow, we will be deleting a column and leaving
    // the remaining table in place with a cell selected.
    // Now delete the column elements from each row and the header
    var tr, td, th;
    var body = _getSection(table, 'TBODY');
    if (body) {
        var rows = body.children;
        for (let j=0; j<rows.length; j++) {
            tr = rows[j];
            td = tr.children[col];
            tr.removeChild(td);
        }
    }
    var header = _getSection(table, 'THEAD');
    if (header) {
        tr = header.children[0];
        th = tr.children[0];
        if (colspan) {
            th.setAttribute('colspan', cols-1);
        } else {
            tr.removeChild(th);
        }
    }
    // Then, since newTr still exists, select the newCol child in it
    _selectCol(newTr, newCol);
    _callback('input');
}

/**
 * Given a row, tr, select at the beginning of the first text element in col, or
 * the entire first element if not a text element
 */
const _selectCol = function(tr, col) {
    var cell = tr.children[col];
    if (cell) { // The cell is either a th or td
        var sel = document.getSelection();
        var range = document.createRange();
        const cellNode = cell.firstChild;
        if (cellNode) {
            if (cellNode.nodeType === Node.TEXT_NODE) {
                range.setStart(cellNode, 0);
                range.setEnd(cellNode, 0);
            } else {
                range.selectNode(cellNode);
            };
            sel.removeAllRanges();
            sel.addRange(range);
            MU.backupRange();
        };
    };
};

/**
 * Do the insertTable operation following a deleteTable operation
 * Used to undo the deleteTable operation and to do the insertTable operation.
 */
const _doInsertTable = function(undoerData) {
    // Reset the selection based on the range after the table was removed,
    // then insert the table at that range. The original table's outerHTML
    // is held in the undoerData.data.outerHTML along with the row and col of
    // the selection. After the table is re-inserted,
    // the insertTable operation leaves the selection properly set to keep
    // typing, but we need to update the undoerData.range with the range
    // for the newly (re)created table element.
    var template = document.createElement('template');
    template.innerHTML = undoerData.data;
    var table = template.content;
    var newRange = undoerData.range.cloneRange();
    newRange.insertNode(table);
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(newRange);
    MU.backupRange();
    undoerData.range = newRange;
}

/**
 * Do the deleteTable operation following an insertTable operation
 * Used to undo the insertTable operation and to do the deleteTable operation.
 */
const _doDeleteTable = function(undoerData) {
    // The undoerData has the range to select to remove the table;
    // iow, the table exists when deleteTable is called.
    // Once the table is removed, the selection is set properly, and
    // we don't want to update the undoerData.
    var sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(undoerData.range);
    MU.backupRange();
    MU.deleteTable(false);
}


//MARK:- Common private functions

/**
 * Return the first node of nodeType within node, doing a depthwise traversal
 */
var _getFirstChildOfTypeWithin = function(node, nodeType) {
    if (node.nodeType === nodeType) {
        return node
    };
    var childNodes = node.childNodes;
    for (let i=0; i<childNodes.length; i++) {
        return _getFirstChildOfTypeWithin(childNodes[i], nodeType);
    };
    return null;
}

/**
 * Return the first node of nodeType within element's next siblings
 */
var _getFirstChildOfTypeAfter = function(element, nodeType) {
    var nextSib = element.nextSibling;
    while (nextSib) {
        var firstChildOfType = _getFirstChildOfTypeWithin(nextSib, nodeType);
        if (firstChildOfType) {
            nextSib = null;
        } else {
            nextSib = nextSib.nextSibling;
        };
    };
    return firstChildOfType;
};

/**
 * Return the first node of nodeType within element's previous siblings
 */
var _getFirstChildOfTypeBefore = function(element, nodeType) {
    var prevSib = element.previousSibling;
    while (prevSib) {
        var firstChildOfType = _getFirstChildOfTypeWithin(prevSib, nodeType);
        if (firstChildOfType) {
            prevSib = null;
        } else {
            prevSib = prevSib.prevSibling;
        };
    };
    return firstChildOfType;
};

/**
 * Return the firstChild of nodeType after element, or if there isn't one,
 * return the firstChild of nodeType before element, or if there isn't one,
 * return null.
 */
var _getFirstChildOfTypeNear = function(element, nodeType) {
    var nearestChildOfType = _getFirstChildOfTypeAfter(element, nodeType);
    return (nearestChildOfType) ? nearestChildOfType : _getFirstChildOfTypeBefore(element, nodeType);
}

/*
 * Return a number that is what is actually specified in the attribute.
 * Since all attributes are strings, using them in raw form can cause weird
 * JavaScript autoconversion issues, especially when adding things to them
 */
var _numberAttribute = function(element, attribute) {
    var number = Number(element.getAttribute(attribute));
    return isNaN(number) ? null : number
};

/**
 * Return the nearest text node to element.
 * Used for deleting element and leaving selection in a reasonable state.
 * If the nearest sibling is a BR, we will replace it with a text node
 * and return that text node.
 */
const _elementAfterDeleting = function(element) {
    var nearestTextNode = _getFirstChildOfTypeNear(element, Node.TEXT_NODE);
    if (nearestTextNode) {
        return nearestTextNode
    } else {
        var sibling = (element.nextSibling) ? element.nextSibling : element.previousSibling;
        if (sibling && (nextSibling.nodeName === 'BR')) {
            var newTextNode = document.createTextNode('');
            sibling.replaceWith(newTextNode);
            return newTextNode;
        } else if (sibling) {
            return sibling;
        } else {
            var firstTextNode = _getFirstChildOfTypeWithin(MU.editor, Node.TEXT_NODE);
            if (firstTextNode) {
                return firstTextNode;
            } else {
                // Things are really messed up if this happens!
                return MU.editor;
            };
        };
    };
};

/**
 * Delete the element and reset the selection to the nearest text node to what
 * we deleted. The selection should be left in a state that will allow the
 * element to be inserted again at the same spot.
 */
const _deleteAndResetSelection = function(element) {
    var nextEl = _elementAfterDeleting(element);
    element.parentNode.removeChild(element);
    var sel = document.getSelection();
    sel.removeAllRanges();
    var newRange = document.createRange();
    newRange.setStart(nextEl, 0);
    newRange.setEnd(nextEl, 0)
    sel.addRange(newRange);
    MU.backupRange();
}

/**
 * Get the element with nodeName at the selection point if one exists
 */
const _getElementAtSelection = function(nodeName) {
    var sel = document.getSelection();
    if (sel) {  // Removed check on && isCollapsed
        var node = sel.anchorNode;
        var anchorOffset = sel.anchorOffset;
        if ((node.nodeType === Node.TEXT_NODE) && (sel.isCollapsed)) {
            if (anchorOffset === node.textContent.length) {
                // We have selected the end of a text element, which might be next
                // to an element we're looking for
                var nextSibling = node.nextSibling;
                if (nextSibling && nextSibling.nodeType === Node.ELEMENT_NODE) {
                    return (nextSibling.nodeName === nodeName) ? nextSibling : null;
                };
            };
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            // We selected some element (like <P>) and the child at anchorOffset might be an element we're looking for
            var child = node.childNodes[anchorOffset];
            return (child && child.nodeName === nodeName) ? child : null;
        };
    };
    return null;
}

/**
 * Put the tag around the current selection, or the word if range.collapsed
 * If not in a word or in a non-collapsed range, create and empty element of
 * type tag and select it so that new input begins in that element immediately.
 */
var _setTag = function(type, sel) {
    const range = sel.getRangeAt(0).cloneRange();
    var el = document.createElement(type);
    const wordRange = _wordRangeAtCaret();
    const startNewTag = range.collapsed && !wordRange;
    const tagWord = range.collapsed && wordRange;
    var newRange = document.createRange();
    // In all cases, el is the new element with tagName type and range will have
    // been modified to have the new element appropriately inserted. The
    // newRange is set appropriately depending on the case.
    if (startNewTag) {
        // If we are in a word and collapsed, then we treat separately.
        // When we have the case of a collapsed selection, AFAICT there is no way to
        // set the selection to be inside of an empty element. As a workaround, I create
        // a zero-width space character inside of it. This causes move-by-character to stay
        // on the same location, which is a bit of a drag. See ancient WebKit discussion at:
        // https://bugs.webkit.org/show_bug.cgi?id=15256. This would lead you to think it
        // was fixed after 5 agonizing years, but it would appear not to me.
        // We select the empty text character so that as soon as we type, it gets replaced.
        // If we create the empty node (e.g., <b></b> but don't start typing to replace
        // the empty text character, then we can "see" it show up when we select even tho
        // it doesn't have any visibility on the screen.
        // TODO - The cursor doesn't show up, dammit.
        var emptyTextNode = document.createTextNode('\u200B');
        el.appendChild(emptyTextNode);
        range.insertNode(el);
        newRange.selectNode(emptyTextNode);
    } else if (tagWord) {
        const inWordOffset = range.startOffset - wordRange.startOffset;
        const wordNode = document.createTextNode(wordRange.toString());
        el.appendChild(wordNode);
        wordRange.deleteContents();
        wordRange.insertNode(el);
        newRange.setStart(wordNode, inWordOffset);
        newRange.setEnd(wordNode, inWordOffset);
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
        newRange.selectNode(el);
    }
    sel.removeAllRanges();
    sel.addRange(newRange);
    MU.backupRange();
    // Note: Now that tagging with selection collapsed inside a word means
    // the word is tagged, and selecting at the beginning of a word just
    // does the non-spacing char, the following is not needed.
    //
    // Check if the insertion left an empty element preceding or following
    // the inserted el. Unfortunately, when starting/ending the selection at
    // the beginning/end of an element in the multinode selection - for example:
    //      <p><b>|Hello</b> wo|rld<p>
    // We end up with:
    //      <p><b></b><i><b>Hello</b> wo</i>rld<p>
    // IOW, we end up with a blank sibling to the new <i> element. It doesn't
    // hurt anything, but it's annoying as hell. So the following code checks
    // for it and removes it.
    //var prevSib = el.previousSibling;
    //if (prevSib && (prevSib.nodeType != Node.TEXT_NODE)) {
    //    var innerHTML = prevSib.innerHTML;
    //    if (!innerHTML || (innerHTML.length == 0)) {
    //        prevSib.parentNode.removeChild(prevSib);
    //    }
    //}
    //var nextSib = el.nextSibling;
    //if (nextSib && (nextSib.nodeType != Node.TEXT_NODE)) {
    //    var innerHTML = nextSib.innerHTML;
    //    if (!innerHTML || (innerHTML.length == 0)) {
    //        nextSib.parentNode.removeChild(nextSib);
    //    }
    //}
};

const _wordRangeAtCaret = function() {
    const sel = document.getSelection();
    if ((!sel) || (sel.rangeCount === 0) || (!sel.isCollapsed)) { return null };
    const range = sel.getRangeAt(0).cloneRange();
    if (range.startContainer.nodeType !== Node.TEXT_NODE) { return null };
    // Select the word in the selNode
    var startOffset = range.startOffset;
    var endOffset = range.endOffset;
    let selNodeText = range.startContainer.textContent;
    while ((startOffset > 0) && !_isWhiteSpace(selNodeText[startOffset - 1])) {
        startOffset -= 1;
    }
    while ((endOffset < selNodeText.length) && !_isWhiteSpace(selNodeText[endOffset]))  {
        endOffset += 1;
    }
    // If both startOffset and endOffset have moved from the originals in range,
    // then the selection/caret is inside of a word, not on the ends of one
    if ((startOffset < range.startOffset) && (endOffset > range.endOffset)) {
        var wordRange = document.createRange();
        wordRange.setStart(range.startContainer, startOffset);
        wordRange.setEnd(range.endContainer, endOffset);
        return wordRange;
    } else {
        return null;
    }
};

/**
 * Remove the tag from the oldElement. The oldRange startContainer might or might not be
 * the oldElement passed-in. In all cases, though, oldRange starts at some offset into text.
 * The element passed-in has the tag we are removing, so replacing outerHTML with inner removes
 * the outermost in place. A simple reassignment still leaves references the element type
 * unchanged (see https://developer.mozilla.org/en-US/docs/Web/API/Element/outerHTML#notes).
 * So, we need to do a proper replace.
 */
var _unsetTag = function(oldElement, sel) {
    const oldRange = sel.getRangeAt(0).cloneRange();
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
    sel.removeAllRanges();
    sel.addRange(range);
}

/**
 * Given an element with a tag, replace its tag with the new tagName
 */
var _replaceTag = function(tagName, element) {
    MU.backupRange();
    var newElement = document.createElement(tagName);
    newElement.innerHTML = element.innerHTML;
    element.replaceWith(newElement);
    MU.restoreRange();
    return newElement;
};

/**
 * Return the count of the element's children that have the tagName
 */
var _childrenWithTagNameCount = function(element, tagName) {
    var count = 0;
    var children = element.children;
    for (let i=0; i < children.length; i++) {
        if (children[i].tagName === tagName) { count++ };
    }
    return count;
}

/**
 * Find the first child of element whose textContent matches the container passed-in
 */
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

/**
 * Return the first child within element that is a textNode using depth-first traversal
 */
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
 * without ever encountering one in excludeNames.
 * If node is a TEXT_NODE, then start with its parent; else, just start with node
 * to find a match.
 */
var _findFirstParentElementInTagNames = function(node, matchNames, excludeNames) {
    // ExcludeNames may be null, in which case will just match; else return null
    // if any element in excludeNames is encountered
    if (!node) { return null };
    var element;
    if (node.nodeType === Node.TEXT_NODE) {
        element = node.parentElement;
    } else {
        element = node;
    };
    var tagName = element.tagName;
    if (excludeNames && excludeNames.includes(tagName)) {
        return null;
    } else if (matchNames.includes(tagName)) {
        return element;
    } else {
        return _findFirstParentElementInTagNames(element.parentElement, matchNames, excludeNames);
    };
};

var _oldFindFirstParentElementInTagNames = function(node, matchNames, excludeNames) {
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
        };
    };
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

/**
 * This is so pathetic, I cannot believe I am doing it.
 * But, wherever the / shows up in JavaScript, XCode messes
 * up all subsequent formatting and it becomes pretty unbearable
 * to deal with the indentation it forces on you.
 * So, I'm putting the only methods where I divide at the bottom of the file.
 */

var _imgScale = function(element) {
    var width = _numberAttribute(element, 'width')
    if (width) {
        return 100 * width / element.naturalWidth;
    } else {
        return null;
    }
}

var _percentInt = function(percent, int) {
    return int * percent / 100;
}


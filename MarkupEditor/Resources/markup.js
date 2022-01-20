/**
 * Copyright © 2021 Steven Harris. All rights reserved.
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

const MU = {};

/**
 * The editor element contains the HTML being edited
 */
MU.editor = document.getElementById('editor');

/********************************************************************************
 * Undo/Redo
 */

/*
 * The Undoer class below was adopted from https://github.com/samthor/undoer
 * under the Apache 2.0 license found
 * at https://github.com/samthor/undoer/blob/dad5b30c2667579667b883e246cad77711daaff7/LICENSE.
 */
class Undoer {
    
    /**
     * @template T
     * @param {function(T)} callback to call when undo occurs
     * @param {function(T)} callback to call when redo occurs
     * @param {T=} zero the zero state for undoing everything
     */
    constructor(undoCallback, redoCallback, zero=null) {
        this._duringUpdate = false;
        this._stack = [zero];
        
        /**
         * Set the textContent and revert focus to MU.editor
         * @param {String}  content     The index into this._stack for the data
         */
        this._setUndoIndex = function(content) {
            //_consoleLog("undoIndex: " + content);
            this._ctrl.textContent = content;
            // Reset focus on MU.editor directly rather than use this._ctrl.blur()
            // Because the input can happen quickly after the push causes this._ctrl to get focus,
            // we need to do change the undoIndex in textContent after a timeout, similarly
            // to how the focus followed by immediate blur needs a timeout.
            //
            // Experimentation shows that a delay of 10 prevents the caret from disappearing,
            // particularly for _toggleFormat. Not sure how reproducible it is or if there is
            // a determinate way to do it, as this just seems like a hack.
            window.setTimeout(function() {
                muteFocusBlur();    // Will be unmuted after MU.editor receives focus
                MU.editor.focus({preventScroll:true});
            }, 10)
        };
        
        // Using an input element rather than contentEditable div because parent is already a
        // contentEditable div
        this._ctrl = document.createElement('div');
        this._ctrl.setAttribute('contenteditable', 'true');
        this._ctrl.setAttribute('aria-hidden', 'true');
        this._ctrl.setAttribute('id', 'hiddenInput');
        this._ctrl.style.caretColor = 'blue';   // To match MU.editor as focus changes
        this._ctrl.style.opacity = 0;
        this._ctrl.style.position = 'fixed';
        this._ctrl.style.top = '-1000px';
        this._ctrl.style.pointerEvents = 'none';
        this._ctrl.tabIndex = -1;
        
        this._ctrl.textContent = '0';
        this._ctrl.style.visibility = 'hidden';  // hide element while not used
        
        this._ctrl.addEventListener('input', (ev) => {
            //_consoleLog("input: hiddenInput");
            // There are two types of input events.
            // 1. If _duringUpdate, we just pushed data onto _stack and ev.data is the index
            //      of what we just spliced into _stack.
            // 2. If !_duringUpdate, then we are undoing or redoing. In this case, ev.data
            //      is null, and we use _depth to find out what _ctrl is holding. That
            //      value is the index into _stack for either undoing or redoing.
            ev.stopImmediatePropagation();  // We don't want this event to be seen by the parent
            //_consoleLog('input event: ' + ev.inputType);
            //_consoleLog('  this._depth: ' + this._depth);
            //_consoleLog('  this.data.operation: ' + this.data.operation);
            //if (this.data.range) {
            //    _consoleLog('  this.data.range:' + _rangeString(this.data.range));
            //} else {
            //    _consoleLog('  this.data.range: null');
            //}
            //_consoleLog('  this.data.data: ' + JSON.stringify(this.data.data));
            //_consoleLog('  ev.data: ' + ev.data);
            //_consoleLog('  initial this._ctrl.textContent: ' + this._ctrl.textContent);
            if (!this._duringUpdate) {
                if (ev.inputType === 'historyUndo') {
                    undoCallback(this._stack[this._depth]);
                    this._setUndoIndex(this._depth - 1);
                } else if (ev.inputType === 'historyRedo') {
                    redoCallback(this._stack[this._depth + 1]);
                    this._setUndoIndex(this._depth + 1);
                };
            } else {
                this._setUndoIndex(ev.data);
            };
        });
    };
    
    /**
     * @return {number} the current stack value
     */
    get _depth() {
        return +(this._ctrl.textContent) || 0;
    }
    
    /**
     * @return {T} the current data
     */
    get data() {
        return this._stack[this._depth];
    }
    
    /**
     * @return {Boolean}    Whether we are pushing something onto the _undoStack
     */
    get pushingUndo() {
        return this._duringUpdate;
    }
    
    /**
     * Pushes a new undoable event. Adds to the browser's native undo/redo stack.
     *
     * @param {T} data the data for this undo event
     * @param {!Node=} parent to add to, uses document.body by default
     */
    push(data, parent) {
        // nb. We can't remove this later: the only case we could is if the user undoes everything
        // and then does some _other_ action (which we can't detect).
        if (!this._ctrl.parentNode) {
            // nb. we check parentNode as this would remove contentEditable's history
            (parent || document.body).appendChild(this._ctrl);
        };
        
        const nextID = this._depth + 1;
        this._stack.splice(nextID, this._stack.length - nextID, data);

        const previousFocus = document.activeElement;
        try {
            _backupSelection();   // Otherwise, when we refocus, it won't be set right
            this._duringUpdate = true;
            this._ctrl.style.visibility = null;
            // Avoid letting the MarkupEditor know about the focus-blur dance going on with this._ctrl
            // and the previousFocus (the MU.editor). When MU.editor gets the focus event, it will always
            // reset so other focus events are not muted.
            muteFocusBlur();
            this._ctrl.focus({preventScroll: true});
            document.execCommand('selectAll');
            document.execCommand('insertText', false, nextID);
        } finally {
            this._duringUpdate = false;
            this._ctrl.style.visibility = 'hidden';
        }
        //if (previousFocus) {
        //    // And we need to mute again when regaining focus.
        //    muteFocusBlur();
        //    // The focus event in MU.editor does _restoreSelection
        //    previousFocus.focus({preventScroll: true});
        //};
    };
    
    testUndo() {
        _undoOperation(this._stack[this._depth]);
        this._setUndoIndex(this._depth - 1);
    };
    
    testRedo() {
        _redoOperation(this._stack[this._depth]);
        this._setUndoIndex(this._depth - 1);
    };
};

/**
 * Return the populated undoerData object held on the Undoer._stack.
 * If range is not passed-in, then populate range from document.getSelection().
 *
 * @param {String}      operation   The name of the operation that was performed (e.g., 'paste').
 * @param {Object}      data        The object with data specific to operation for undo/redo.
 * @param {HTML Range}  range       A range that can be used during the undo/redo if current selection is inadequate.
 * @return {Object}                 The object populated with operation, data, and range.
 */
const _undoerData = function(operation, data, range=null) {
    let undoerRange;
    if (range) {
        undoerRange = range;
    } else {
        const sel = document.getSelection();
        undoerRange = (sel && (sel.rangeCount > 0)) ? sel.getRangeAt(0).cloneRange() : null;
    }
    return {
        operation: operation,
        range: undoerRange,
        data: data
    };
};

/**
 * Undo the operation identified in undoerData. So, for example,
 * when operation is 'indent', we undo an indent by executing decreaseQuoteLevel.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _undoOperation = function(undoerData) {
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (operation) {
        case 'pasteText':
            _undoPasteText(range, data);
            break;
        case 'format':
            _restoreSelection();
            _toggleFormat(data, false);
            _backupSelection();
            break;
        case 'style':
            _restoreSelection();
            MU.replaceStyle(data.newStyle, data.oldStyle, false);
            _backupSelection();
            break;
        case 'list':
            _restoreSelection();
            MU.toggleListItem(data.oldListType, false);
            _backupSelection();
            break;
        case 'indent':
            _restoreSelection();
            MU.decreaseQuoteLevel(false);
            _backupSelection();
            break;
        case 'insertLink':
            _redoDeleteLink(undoerData);
            break;
        case 'deleteLink':
            _redoInsertLink(undoerData);
            break;
        case 'insertImage':
            _redoModifyImage(undoerData);
            break;
        case 'modifyImage':
            _redoInsertImage(undoerData);
            break;
        case 'insertTable':
            _redoDeleteTable(undoerData);
            break;
        case 'deleteTable':
            _redoInsertTable(undoerData);
            break;
        case 'restoreTable':
            _restoreTable(undoerData);
            break;
        default:
            _consoleLog('Error: Unknown undoOperation ' + undoerData.operation);
    };
};

/**
 * Redo the operation identified in undoerData. So, for example,
 * when operation is 'indent', we redo an indent by executing increaseQuoteLevel.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoOperation = function(undoerData) {
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (undoerData.operation) {
        case 'pasteText':
            _redoPasteText(range, data);
            break;
        case 'format':
            _restoreSelection();
            _toggleFormat(data, false);
            _backupSelection();
            break;
        case 'style':
            _restoreSelection();
            MU.replaceStyle(data.oldStyle, data.newStyle, false);
            _backupSelection();
            break;
        case 'list':
            _restoreSelection();
            MU.toggleListItem(data.newListType, false);
            _backupSelection();
            break;
        case 'indent':
            _restoreSelection();
            MU.increaseQuoteLevel(false);
            _backupSelection();
            break;
        case 'insertLink':
            _redoInsertLink(undoerData);
            break;
        case 'deleteLink':
            _redoDeleteLink(undoerData);
            break;
        case 'insertImage':
            _redoInsertImage(undoerData);
            break;
        case 'modifyImage':
            _redoModifyImage(undoerData);
            break;
        case 'insertTable':
            _redoInsertTable(undoerData);
            break;
        case 'deleteTable':
            _redoDeleteTable(undoerData);
            break;
        case 'restoreTable':
            _restoreTable(undoerData);
            break;
        default:
            _consoleLog('Error: Unknown redoOperation ' + undoerData.operation);
    };
};

/**
 * The undoer is the singleton that handles undo/redo.
 * The _undoOperation/_redoOperation are the functions we
 * call to perform undo and redo, passing the undoerData
 * which includes the operation name, data specific to the
 * operation, as well as a range that might be needed to
 * perform the operation.
 */
const undoer = new Undoer(_undoOperation, _redoOperation, null);

/**
 * Without any api-level access to undo/redo, we are forced to use the execCommand to cause the
 * event to be triggered from Swift. Note that the _undoOperation gets called when it has
 * been placed in the stack with undoer.push (for example, for formatting or pasting).
 */
MU.undo = function() {
    document.execCommand('undo', false, null);
};

/**
 * Without any api-level access to undo/redo, we are forced to use the execCommand to cause the
 * event to be triggered from Swift. Note that the _redoOperation gets called when it has
 * been placed in the stack with undoer.push (for example, for formatting or pasting).
 */
MU.redo = function() {
    document.execCommand('redo', false, null);
};

/**
 * Restore the selection to the range held in undoerData.
 * Note that caller has to call _backupSelection independently if needed.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _restoreUndoerRange = function(undoerData) {
    const range = undoerData.range;
    if (range) {
        const sel = document.getSelection();
        sel.removeAllRanges();
        sel.addRange(range);
    };
};

/**
 * Backup the current selection into the undoerData.range.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _backupUndoerRange = function(undoerData) {
    const sel = document.getSelection();
    if (sel && (sel.rangeCount > 0)) {
        undoerData.range = sel.getRangeAt(0).cloneRange();
    };
};

/**
 * The 'ready' callback lets Swift know the editor and this js is properly loaded
 */
window.onload = function() {
    _callback('ready');
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

/********************************************************************************
 * Event Listeners
 */

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
let _mouseDown = false;
let _muteChanges = false;
const muteChanges = function() { _setMuteChanges(true) };
const unmuteChanges = function() { _setMuteChanges(false) };
const _setMuteChanges = function(bool) { _muteChanges = bool };

/**
 * Track when mouse is down, unmute to broadcase selectionChange unless mousemove happens.
 */
MU.editor.addEventListener('mousedown', function() {
    _mouseDown = true;
    _muteChanges = false;
});

/**
 * Mute selectionChange when mousedown has happened and the mouse is moving.
 */
MU.editor.addEventListener('mousemove', function() {
    if (_mouseDown) { _muteChanges = true };
});

/**
 * Unmute selectionChange on mouseup.
 */
MU.editor.addEventListener('mouseup', function() {
    _mouseDown = false;
    _muteChanges = false;
});

/**
 * Let Swift know the selection has changed so it can getSelectionState.
 * The eventListener has to be done at the document level, not MU.editor.
 */
document.addEventListener('selectionchange', function() {
    if (!_muteChanges) {
        //_consoleLog('selectionchange')
        _callback('selectionChange');
    //} else {
    //    _consoleLog(' (muted selectionchange)')
    };
});

MU.editor.addEventListener('input', function() {
    _backupSelection();
    _callback('input');
});

/**
 * A blur/focus cycle occurs when the undoer is used, but we don't want that to
 * be noticable by the MarkupEditor in Swift. We use mute/unmute to track the
 * whether the focus and blur callbacks should be made, as determined in the Undoer.
 * We also don't want selectionchange events to trigger callbacks during the cycle.
 */
let _muteFocusBlur = false;
const muteFocusBlur = function() {
    _muteFocusBlur = true;
    muteChanges();
};
const unmuteFocusBlur = function() {
    unmuteChanges();
    _muteFocusBlur = false;
};

/**
 * Restore the range captured on blur and then let Swift know focus happened.
 */
MU.editor.addEventListener('focus', function(ev) {
    _restoreSelection();
    if (!_muteFocusBlur) {
        //_consoleLog("focused: " + ev.target.id)
        _callback('focus');
    //} else {
    //    _consoleLog(" (muted focused: " + ev.target.id + ")")
    };
    // Always unmute after focus happens, since it should only happen once for
    // the undoer.push operation
    unmuteFocusBlur();
});

//MU.editor.addEventListener('focusout', function(ev) {
//    _consoleLog("focusout: " + ev.target.id);
//});
//
//MU.editor.addEventListener('focusin', function(ev) {
//    _consoleLog("focusin: " + ev.target.id);
//});

/**
 * Capture the current selection using backupSelection and then let Swift know blur happened.
 * The blur during the undoer.push operation will always be followed by a focus, where
 * _muteFocusBlur will be reset.
 */
MU.editor.addEventListener('blur', function(ev) {
    // A blur/focus cycle occurs when the undoer is used, but we don't want that to
    // be noticable by the MarkupEditor in Swift.
    //if (!_muteFocusBlur) {
    //    _consoleLog("blurred: " + ev.target.id);
    //} else {
    //    _consoleLog(" (muted blurred: " + ev.target.id +")");
    //}
    //if (ev.relatedTarget) {
    //    _consoleLog(" will focus: " + ev.relatedTarget.id);
    //} else {
    //    _consoleLog(" will focus: null");
    //}
    if (!undoer || (undoer && !undoer.pushingUndo)) {
        _backupSelection()
    };
    if (!_muteFocusBlur) {
        _callback('blur');
    }
});

/**
 * Notify Swift on single-click (e.g., for following links)
 * Handle the case of multiple clicks being received without
 * doing selection.
 * TODO - Maybe remove the _multiClickSelect call
 */
MU.editor.addEventListener('click', function(ev) {
    let nclicks = ev.detail;
    if (nclicks === 1) {
        _callback('click');
    } else {
        //_multiClickSelect(nclicks);
    }
});

/**
 * Track keystrokes combined with modifiers using the keyModifier (e.g., 'Shift') as key
 * and the key-pressed as the value.
 * On keydown of any key that is pressed at the same time as a keyModifier, populate the
 * _hotKeyDown. On keyup of any keyModifier, clear it.
 * Note that the keydown event is triggered for every keystroke unless somehow intercepted
 * at a lower level, but if a modifierKey is pressed, the keyup does not occur except when
 * the modifierKey comes up. For example pressing Shift and then ] triggers keydown both for
 * Shift and ], but keyup is never triggered when the ] key is let go as long as Shift is
 * still being held. So, Shift+[ triggers keydown for both, but when you let go of [ and
 * press ], the only event that is triggered is keydown on ]. The keyup on [ never happens.
 * Keyup is triggered when the Shift key is let go. And because we only want to track a single
 * key combined with one or more of the modifiers, this is the reason to key _hotKeyDown by the
 * keyModifier, not by the ev.key itself. We end up with _hotKeyDown['Shift'] = ']' for Shift+].
 * If we hold Shift and Meta and then press ], we end up with _hotKeyDown['Shift'] = ']'
 * AND _hotKeyDown['Meta'] = ']'. This approach precludes key combos other than the modifier
 * keys (i.e., no Control+P+Q).
 */
var _hotKeyDown = {};
const keyModifiers = ['Shift', 'Meta', 'Alt', 'Control'];
const _trackHotKeyDown = function(ev) {
    const key = ev.key;
    if (keyModifiers.includes(key)) { return };     // If pressing one of the modifiers, nothing to do
    _hotKeyDown['Shift'] = (ev.shiftKey) ? key : null;
    _hotKeyDown['Meta'] = (ev.metaKey) ? key : null;
    _hotKeyDown['Alt'] = (ev.altKey) ? key : null;
    _hotKeyDown['Control'] = (ev.ctrlKey) ? key : null;
    //if (_hotKeyDown['Shift']) { _consoleLog("Setting Shift to " + _hotKeyDown['Shift']) }
    //if (_hotKeyDown['Meta']) { _consoleLog("Setting Meta to " + _hotKeyDown['Meta']) }
    //if (_hotKeyDown['Alt']) { _consoleLog("Setting Alt to " + _hotKeyDown['Alt']) }
    //if (_hotKeyDown['Control']) { _consoleLog("Setting Control to " + _hotKeyDown['Control']) }
};
const _trackModifierKeyUp = function(ev) {
    const key = ev.key;
    if (!keyModifiers.includes(key)) { return };    // If not releasing a modifier, nothing to do
    //if ((key === 'Shift') && _hotKeyDown['Shift']) { _consoleLog("Clearing Shift, was " + _hotKeyDown['Shift']) }
    //if ((key === 'Meta') && _hotKeyDown['Meta']) { _consoleLog("Clearing Meta, was " + _hotKeyDown['Meta']) }
    //if ((key === 'Alt') && _hotKeyDown['Alt']) { _consoleLog("Clearing Alt, was " + _hotKeyDown['Alt']) }
    //if ((key === 'Control') && _hotKeyDown['Control']) { _consoleLog("Clearing Control, was " + _hotKeyDown['Control']) }
    _hotKeyDown[key] = null;
};
MU.editor.addEventListener('keydown', _trackHotKeyDown);
MU.editor.addEventListener('keyup', _trackModifierKeyUp);

/**
 * Return true if the key is down together with the modifier
 */
const _keyModified = function(modifier, key) {
    return _hotKeyDown[modifier] === key;
};

/**
 * Monitor certain keydown events for special handling.
 * This event is fired after, and in addition to, the one that tracks _hotKeyDown,
 * so we can examine the state of _hotKeyDown to determine what to do depending
 * on the context.
 */
MU.editor.addEventListener('keydown', function(ev) {
    const key = ev.key;
    const sel = document.getSelection()
    const selNode = (sel) ? sel.focusNode : null;
    if (!selNode) { return };
    if (key === 'Enter') {
        const inList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
        if ((inList && _doListEnter()) || (!inList && _doEnter())) {
            ev.preventDefault();
        };
    } else {
        const specialParent = _findFirstParentElementInNodeNames(selNode, _monitorEnterTags);
        if (specialParent) {
            const nodeName = specialParent.nodeName;
            const inList = (nodeName === 'UL') || (nodeName === 'OL')
            const inTable = nodeName === 'TABLE';
            const inBlockQuote = nodeName === 'BLOCKQUOTE';
            let preventDefault;
            if (key === 'Tab') {
                preventDefault =
                    (inList && _doListIndent()) ||
                    (inBlockQuote && MU.increaseQuoteLevel()) ||
                    (inTable && _doNextCell());
            } else if (_keyModified('Meta', ']')) {
                preventDefault =
                    (inList && _doListIndent()) ||
                    (inBlockQuote && MU.increaseQuoteLevel()) ||
                    (inTable && MU.increaseQuoteLevel());
            } else if (_keyModified('Meta', '=')) {
                //} else if (_keyModified('Shift', 'Tab')) {
                // TODO: Shift Tab is never triggered. Instead it moves focus somewhere
                //      For now, this is just a hack to use Meta+= as an alternative to exercise code
                preventDefault =
                    (inList && _doListOutdent()) ||
                    (inBlockQuote && MU.decreaseQuoteLevel()) ||
                    (inTable && _doPrevCell());
            } else if (_keyModified('Meta', '[')) {
                preventDefault =
                    (inList && _doListOutdent()) ||
                    (inBlockQuote && MU.decreaseQuoteLevel()) ||
                    (inTable && MU.decreaseQuoteLevel());
            };
            if (preventDefault) {
                ev.preventDefault();
            };
        } else if (
            ((key === 'Tab') || _keyModified('Shift', 'Tab')) ||        // Do nothing for tab by default
            (_keyModified('Meta', ']') && MU.increaseQuoteLevel()) ||
            (_keyModified('Meta', '[') && MU.decreaseQuoteLevel())) {
            ev.preventDefault();
        };
    };
});

/**
 * Handle the Enter key to avoid <div> being inserted instead of <p>
 *
 * @returns {HTML Paragraph Element}   The newly created P to preventDefault handling; else, null.
 */
const _doEnter = function() {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.focusNode : null;
    if (!selNode) { return null };
    // If sel is not collapsed, delete the entire selection and reset before continuing
    if (!sel.isCollapsed) {
        sel.deleteFromDocument();
        sel = document.getSelection();
        selNode = (sel) ? sel.focusNode : null;
        if (!selNode) { return null };
    };
    const existingRange = sel.getRangeAt(0).cloneRange();
    if ((selNode.nodeType === Node.TEXT_NODE) && (!selNode.nextSibling) && (existingRange.endOffset === selNode.textContent.length)) {
        // We are at the end of the last text node in some element, so we want to
        // create a new <P> to keep typing
        const parent = selNode.parentNode;
        const p = document.createElement('p');
        p.appendChild(document.createElement('br'));
        parent.parentNode.insertBefore(p, parent.nextSibling);
        const range = document.createRange();
        // And leave selection in the newElement
        range.setStart(p, 0);
        range.setEnd(p, 0);
        sel.removeAllRanges();
        sel.addRange(range);
        _callback('input');
        return p;   // To preventDefault() on Enter
    };
    return null;    // Let the MarkupWKWebView do its normal thing
}


/**
 * Monitor certain keyup events that follow actions that mess up simple HTML formatting.
 * Clean up formatting if needed.
 * We do the clean up after Enter because the default behavior (like breaking paragraphs)
 * is generally correct and the selection is predictably left in a br or div.
 */
MU.editor.addEventListener('keyup', function(ev) {
    const key = ev.key;
    if ((key === 'Backspace') || (key === 'Delete')) {
        _cleanUpSpans();
        _cleanUpAttributes('style');
    };
});

/**
 * Do a custom paste operation to avoid polluting the document with arbitrary HTML
 */
MU.editor.addEventListener('paste', function(ev) {
   ev.preventDefault();
   let pastedText = undefined;
   if (ev.clipboardData && ev.clipboardData.getData) {
       pastedText = ev.clipboardData.getData('text/plain');
   };
   const undoerData = _undoerData('pasteText', pastedText);
   undoer.push(undoerData);
   _redoOperation(undoerData);
});

/********************************************************************************
 * Paste
 */

/**
 * Do or redo the paste operation.
 *
 * @param   {HTML Range}    range       The range to pasting into.
 * @param   {String}        data        The text to paste.
 */
const _redoPasteText = function(range, data) {
    // Paste the undoerData.data text after the range.endOffset or range.endContainer
    // TODO: Handle non-collapsed ranges
    const originalText = range.endContainer.textContent;
    const newText = originalText.substring(0, range.endOffset) + data + originalText.substr(range.endOffset);
    range.endContainer.textContent = newText;
    const newRange = document.createRange();
    newRange.setStart(range.endContainer, range.endOffset + data.length);
    newRange.setEnd(range.endContainer, range.endOffset + data.length);
    const selection = document.getSelection();
    selection.removeAllRanges();
    selection.addRange(newRange);
    _callback('input');
};

/**
 * Undo the paste operation after it was done via _redoPasteText.
 *
 * @param   {HTML Range}    range       The range to pasting into.
 * @param   {String}        data        The text to paste.
 *
 */
const _undoPasteText = function(range, data) {
    // The pasted text data was placed after the range.endOffset in endContainer
    // Make sure it's still there and if so, remove it, leaving the selection
    // TODO: Handle non-collapsed ranges
    const textContent = range.endContainer.textContent;
    const existingText = textContent.slice(range.endOffset, range.endOffset + data.length);
    if (existingText === data) {
        const startText = textContent.slice(0, range.endOffset);
        const endText = textContent.slice(range.endOffset + data.length);
        range.endContainer.textContent = startText + endText;
        const newRange = document.createRange();
        newRange.setStart(range.endContainer, range.endOffset);
        newRange.setEnd(range.endContainer, range.endOffset);
        const selection = document.getSelection();
        selection.removeAllRanges();
        selection.addRange(newRange);
        _callback('input');
    } else {
        _consoleLog('undo pasteText mismatch: ' + existingText);
    };
};

/********************************************************************************
 * Getting and setting document contents
 */

/**
 * Clean out the MU.editor and replace it with an empty paragraph
 */
MU.emptyDocument = function() {
    while (MU.editor.firstChild) {
        MU.editor.removeChild(MU.editor.firstChild);
    };
    const p = document.createElement('p');
    p.appendChild(document.createElement('br'));
    MU.editor.appendChild(p);
    const sel = document.getSelection();
    const range = document.createRange();
    range.setStart(p, 1);
    range.setEnd(p, 1);
    sel.removeAllRanges();
    sel.addRange(range);
    _backupSelection();
}

/**
 * Set the contents of the editor element
 *
 * @param {String} contents The HTML for the editor element
 */
MU.setHTML = function(contents) {
    const tempWrapper = document.createElement('div');
    tempWrapper.innerHTML = contents;
    const images = tempWrapper.querySelectorAll('img');
    for (let i=0; i<images.length; i++) {
        images[i].onload = function() {
            // _consoleLog("Loaded " + images[i].src);
            _callback('updateHeight')
        };
        //images[i].onerror = function() {
        //    _consoleLog("Error loading " + images[i].src);
        //};
    }
    MU.editor.innerHTML = tempWrapper.innerHTML;
    _initializeRange()
};

/**
 * Get the contents of the editor element
 *
 * @return {string} The HTML for the editor element
 */
MU.getHTML = function() {
    return MU.editor.innerHTML;
};

/**
 * Set the base element for the document to the urlString.
 * URLs within the html will be interpreted relative to this urlString.
 * For example, and <img src="foo.png"> will be loaded from the location
 * identified by urlString.
 *
 * @param {String} urlString The full string for base (e.g., 'file:///<path>')
 */
MU.setBase = function(urlString) {
    const existingBase = document.getElementsByTagName('base')
    if (existingBase.length > 0) {
        _consoleLog("Existing base href was " + existingBase[0].href);
        _consoleLog("Resetting base.href to " + urlString);
        existingBase[0].href = urlString;
    } else {
        _consoleLog("Setting base.href to " + urlString);
        const base = document.createElement('base');
        base.href = urlString;
        document.getElementsByTagName('head')[0].appendChild(base);
    }
    _consoleLog(" Done.");
};

/**
 * Make sure selection is set to something reasonable when starting
 * or setting HTML.
 * Something reasonable here means the front of the first text node
 * or absent that, the firstChild in MU.editor. As a backup,
 * we will create an empty document if neither of those exist.
 * We make the contentEditable editor have focus when done. From a
 * the iOS perspective, this doesn't mean we becomeFirstResponder.
 * This should be done at the application level when the MarkupDelegate
 * signals contentDidLoad, because with more than one MarkupWKWebView,
 * the application has to decide when to becomeFirstResponder.
 */
const _initializeRange = function() {
    const firstChild = _firstEditorElement();
    const selection = document.getSelection();
    selection.removeAllRanges();
    const range = document.createRange();
    if (firstChild) {
        range.setStart(firstChild, 0);
        range.setEnd(firstChild, 0);
        selection.addRange(range);
        _backupSelection();
    } else {
        MU.emptyDocument()
    }
    MU.editor.focus({preventScroll:true});
    _callback('updateHeight');
}

const _firstEditorElement = function() {
    const firstTextNode = _getFirstChildOfTypeWithin(MU.editor, Node.TEXT_NODE);
    return firstTextNode ? firstTextNode : MU.editor.firstChild;
};

/********************************************************************************
 * Formatting
 * 1. Formats (B, I, U, DEL, CODE, SUB, SUP) are toggled off and on
 * 2. Formats can be nested, but not inside themselves; e.g., B cannot be within B
 */

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

/**
 * Turn the format tag off and on for selection.
 * Called directly on undo/redo so that nothing new is pushed onto the undo stack
 */
const _toggleFormat = function(type, undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    const existingElement = _findFirstParentElementInNodeNames(selNode, [type.toUpperCase()]);
    if (existingElement) {
        _unsetTag(existingElement, sel);
    } else {
        _setTag(type, sel);
    }
    _backupSelection();
    if (undoable) {
        // Both _setTag and _unsetTag reset the selection when they're done;
        // however, the selection should be left in a way that undoing is accomplished
        // by just re-executing the _toggleFormat. So, for example, _toggleFormat while
        // selected between characters in a word will toggleFormat for the word, but leave
        // the selection at the same place in that word. Also, toggleFormat when a word
        // has a range selected will leave the same range selected.
        const undoerData = _undoerData('format', type);
        undoer.push(undoerData);
    }
    _callback('input');
}

/********************************************************************************
 * Raw and formatted text
 */

//const _prettify = function(html) {
//    // A hack to prettify MU.editor.innerHTML.
//    // From https://stackoverflow.com/a/60338028/8968411.
//    const tab = '\t';
//    const result = '';
//    const indent= '';
//    html.split(/>\s*</).forEach(function(element) {
//        if (element.match( /^\/\w/ )) {
//            indent = indent.substring(tab.length);
//        }
//        result += indent + '<' + element + '>\n\n';
//        if (element.match( /^<?\w[^>]*[^\/]$/ ) && !element.startsWith('input')  ) {
//            indent += tab;
//        }
//    });
//    return result.substring(1, result.length-3);
//}

/**
 * Return a marginally prettier version of the raw editor contents.
 *
 * @return {String}     A string showing the raw HTML with tags, etc.
 */
MU.getPrettyHTML = function() {
    return MU.editor.innerHTML.replace(/<p/g, '\n<p').replace(/<h/g, '\n<h').replace(/<div/g, '\n<div').replace(/<table/g, '\n<table').trim();
};

/********************************************************************************
 * Styling
 * 1. Styles (P, H1-H6) are applied to blocks
 * 2. Unlike formats, styles are never nested (so toggling makes no sense)
 * 3. Every block should have some style
 */

/**
 * Find/verify the oldStyle for the selection and replace it with newStyle.
 * Replacement for execCommand(formatBlock).
 *
 * @param {String}  oldStyle    One of the styles P or H1-H6 that exists at selection.
 * @param {String}  newStyle    One of the styles P or H1-H6 to replace oldStyle with.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.replaceStyle = function(oldStyle, newStyle, undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode) { return };
    let existingElement = null;
    if (oldStyle) {
        // There can only be an existing element if oldStyle is non-null
        existingElement = _findFirstParentElementInNodeNames(selNode, [oldStyle.toUpperCase()]);
    };
    if (existingElement) {
        _replaceTag(existingElement, (newStyle) ? newStyle.toUpperCase() : newStyle);
        if (undoable) {
            const undoerData = _undoerData('style', {oldStyle: oldStyle, newStyle: newStyle});
            undoer.push(undoerData);
        }
        _callback('input');
    } else if (selNode.nodeType === Node.TEXT_NODE) {
        // We occasionally (e.g., in lists) select unstyled text nodes.
        // In these cases, we need to select the entire text node, set the style,
        // and then reset the selection afterward. We can only do this when the
        // selNode is not within a style already, since styles cannot be nested.
        const rangeProxy = _rangeProxy()
        let range = document.createRange();
        range.setStart(selNode, 0);
        range.setEnd(selNode, selNode.textContent.length);
        sel.removeAllRanges();
        sel.addRange(range);
        _setTag(newStyle, sel);
        range = document.createRange();
        range.setStart(range.startContainer, rangeProxy.startOffset);
        range.setEnd(range.endContainer, rangeProxy.endOffset);
        sel.removeAllRanges();
        sel.addRange(range);
        if (undoable) {
            // Pass the oldStyle as null since on undo we want to remove the style completely.
            const undoerData = _undoerData('style', {oldStyle: null, newStyle: newStyle});
            undoer.push(undoerData);
        }
        _callback('input');
    }
};

/********************************************************************************
 * Nestables, including lists and block quotes
 */

/**
 * Turn the list tag off and on for selection, doing the right thing
 * for different cases of selections.
 * If the selection is in a list type that is different than newListTyle,
 * we need to create a new list and make the selection appear in it.
 *
 * @param {String}  newListType     The kind of list we want the list item to be in if we are turning it on or changing it.
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.toggleListItem = function(newListType, undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    // Capture the range settings for the selection
    const range = sel.getRangeAt(0).cloneRange();
    const oldStartContainer = range.startContainer;
    const oldStartOffset = range.startOffset;
    const oldEndContainer = range.endContainer;
    const oldEndOffset = range.endOffset;
    const selectionState = _getSelectionState();
    const styleType = selectionState['style'];
    const oldListType = selectionState['list'];
    const isInListItem = selectionState['li'];
    // We will capture the newSelNode for restoring the selection along the way
    let newSelNode = null;
    if (oldListType) {
        // TOP-LEVEL CASE: We selected something in a list
        const listElement = _findFirstParentElementInNodeNames(selNode, [oldListType]);
        const listItemElementCount = _childrenWithNodeNameCount(listElement, 'LI');
        if (isInListItem) {
            // CASE: We selected a list item inside of a list
            const listItemElement = _findFirstParentElementInNodeNames(selNode, ['LI']);
            if (oldListType === newListType) {
                // We need to determine if we are in a node whose enclosing LI should be toggled
                // off or on. This is made more complicated by the fact that selNode is not necessarily
                // inside of any style tag (like <p>).
                // Consider this case with the selection in 'Bar'. Here styleType will be null,
                // and oldListType will be 'UL'. 'Bar' is a TEXT_NODE whose parentNode is <OL>, and
                // we want to put it in an <LI>.
                //  <ul>
                //      <li>
                //          <h5>Foo</h5>
                //          <ol>
                //              Bar
                //              <li>Baz</li>
                //          </ol>
                //      </li>
                //      <li><h5>Fiz</h5></li>
                //  </ul>
                // And then this one. Here styleType is 'P'. 'Bar' is a text node whose parentNode
                // is <P>, and we want to put it in an <LI>
                //  <ul>
                //      <li>
                //          <h5>Foo</h5>
                //          <ol>
                //              <p>Bar</p>
                //              <li>Baz</li>
                //          </ol>
                //      </li>
                //      <li><h5>Fiz</h5></li>
                //  </ul>
                // To make both of these cases work, find the parentNode that is in listStyleTags(). If
                // there is one, then that parentNode is what we want to put in a newListItem. If there
                // isn't one, then we just want to put selNode into it.
                // But, now consider the same cases when selecting 'Baz'. The difference between 'Bar'
                // and 'Baz' is that 'Bar' isn't in a <LI> inside of the <OL> or <UL>, the listElement.
                // We need a way to determine if selNode is "naked" inside of a list (we know it is in
                // a list). If it is naked, then the rule above works -- we always want do put it in a
                // new <LI>. If it's not naked, we might still want to toggle it on, but only if it
                // has a previousElementSibling, because it is by definition without a visible bullet
                // or number.
                const containingBlock = _findFirstParentElementInNodeNames(selNode, _listStyleTags)
                const liChild = (containingBlock) ? containingBlock : selNode
                //_consoleLog("liChild.outerHTML: " + liChild.outerHTML);
                const naked = _isNakedListSelection(liChild, ['LI'], ['OL', 'UL']);
                const previousSib = liChild.previousElementSibling;
                if (previousSib || (naked && (listItemElementCount > 0))) {
                    //_consoleLog("Toggle on")
                    //_consoleLog(" previousSib: " + previousSib + ", naked: " + naked + ", listItemElementCount: " + listItemElementCount);
                    //_consoleLog(" Setting tag for " + liChild);
                    // We want to make the selNode into a new list item in the existing list.
                    // But, we also want it to include all of its siblings.
                    const newListItem = document.createElement('li');
                    let nextSib = liChild.nextSibling;  // Get nextSib before we put it in the LI and it doesn't have any sibs any more
                    //_consoleLog(" Appending " + liChild.textContent);
                    newListItem.appendChild(liChild);
                    let nextNextSib;
                    while (nextSib && (nextSib.nodeName !== 'LI')) {
                        nextNextSib = nextSib.nextSibling;
                        //_consoleLog(" Appending " + nextSib.textContent);
                        newListItem.appendChild(nextSib);
                        nextSib = nextNextSib;
                    }
                    if (naked) {
                        listElement.insertBefore(newListItem, nextSib);
                    } else {
                        listElement.insertBefore(newListItem, listItemElement.nextSibling);
                    }
                    //TODO: The caret goes missing afterwards.
                    newSelNode = newListItem;
                } else {
                    //_consoleLog("Toggle off")
                    if (listItemElementCount === 0) {
                        //_consoleLog(" Unsetting tag for " + listElement.outerHTML);
                        _unsetTag(listElement, sel);
                    } else {
                        //_consoleLog(" Unsetting tag for " + listItemElement.outerHTML);
                        // We want to toggle it off and remove the list altogether if it's empty afterward
                        // NOTE: _unsetTag resets the selection properly itself. So, we don't
                        // set newSelNode in this case
                        _unsetTag(listItemElement, sel);
                        if (listItemElementCount === 1) {
                            // There was only one list item, and we just removed it
                            // So, unset the list. This seems like the right thing to do,
                            // because it can be confusing visually to still have some kind
                            // of list present without any list items in it. We don't have
                            // to do this, but it just seems less confusing to an end user.
                            _unsetTag(listElement, sel);
                        }
                    }
                }
            } else {
                if (listItemElementCount === 1) {
                    // If this is the only item in the list, then change the list type rather than
                    // change the one element.
                    if (newListType) {
                        const newList = _replaceTag(listElement, newListType);
                        newSelNode = newList.firstChild;
                    } else {
                        // We are unsetting the list for a single-item list, so just remove both so
                        // the list is removed.
                        _unsetTag(listItemElement, sel);
                        _unsetTag(listElement, sel);
                    }
                } else {
                    // We want to replace the existing list item with a newListType list that contains it
                    newSelNode = _splitList(listItemElement, newListType);
                }
            }
            if (newSelNode) {
                _collapseList(newSelNode)
            };
        } else if (styleType) {
            // CASE: We selected a styled element in a list, but not in an LI
            const styledElement = _findFirstParentElementInNodeNames(selNode, [styleType]);
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
        const styledElement = _findFirstParentElementInNodeNames(selNode, [styleType]);
        if (styledElement) {
            newSelNode = _replaceNodeWithList(newListType, styledElement);
        } else {
            newSelNode = _replaceNodeWithList(newListType, selNode);
        }
    };
    // If we captured the newSelNode, then reset the selection based on it
    if (newSelNode) {
        let startContainer, endContainer;
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
        _backupSelection();
        const undoerData = _undoerData('list', {newListType: newListType, oldListType: oldListType});
        undoer.push(undoerData);
        _restoreSelection();
    }
    _callback('input');
};

/**
 * Return true if we don't encounter LI before we hit OL or UL starting at node.
 * This happens when we have paragraphs or any other element inside of a list but
 * not separately in an LI. For example, we have multiple paragraphs inside of a
 * single LI.
 */
const _isNakedListSelection = function(node) {
    return !(_findFirstParentElementInNodeNames(node, ['LI'], ['OL', 'UL']));
};

/**
 * We are inside of a list and hit Enter.
 *
 * @return  {HTML BR Element}   The BR in the newly created LI to preventDefault handling; else, null.
 */
const _doListEnter = function() {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.focusNode : null;
    if (!selNode) { return null };
    // If sel is not collapsed, delete the entire selection and reset before continuing
    if (!sel.isCollapsed) {
        sel.deleteFromDocument();
        sel = document.getSelection();
        selNode = (sel) ? sel.focusNode : null;
        if (!selNode) { return null };
    }
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!existingList || !existingListItem) { return null };
    const existingRange = sel.getRangeAt(0).cloneRange();
    const beginningListNode = (existingRange.startOffset === 0) && (!selNode.previousSibling)
    const endingListNode = (selNode.nodeType === Node.TEXT_NODE) && !(selNode.nextSibling) && (existingRange.endOffset === selNode.textContent.length)
    const newListItem = document.createElement('li');
    const blockContainer = _findFirstParentElementInNodeNames(selNode, _listStyleTags);
    let newElement;
    if (blockContainer) {
        newElement = document.createElement(blockContainer.nodeName);
    } else {
        newElement = document.createElement('p');
    }
    if (beginningListNode) {
        // We are at the beginning of a list node, so insert the newListItem
        newElement.appendChild(document.createElement('br'));
        newListItem.appendChild(newElement);
        existingList.insertBefore(newListItem, existingListItem);
        _callback('input');
        // Leave selection alone
        return existingListItem;  // To preventDefault() on Enter
    } else if (endingListNode) {
        // We are at the end of a textNode in a list item (e.g., a <p> or just naked text)
        // First, move all of the siblings of selNode's parentNode to reside in the new list,
        // leaving selNode itself alone.
        newElement.appendChild(document.createElement('br'));
        newListItem.appendChild(newElement);
        let sib = selNode.parentNode.nextElementSibling;
        let nextSib;
        while (sib && (sib.nodeName !== 'LI')) {
            nextSib = sib.nextElementSibling;
            newListItem.appendChild(sib);
            sib = nextSib;
        }
        // Then, insert the newListItem with its new children into the list before the next list element.
        existingList.insertBefore(newListItem, existingListItem.nextElementSibling);
        const range = document.createRange();
        // And leave selection in the newElement
        range.setStart(newElement, 0);
        range.setEnd(newElement, 0);
        sel.removeAllRanges();
        sel.addRange(range);
        _callback('input');
        return newElement;  // To preventDefault() on Enter
    } else {
        // We are somewhere in a list item
        let sib, nextSib;
        if (selNode.nodeType === Node.TEXT_NODE) {
            let trailingContent = selNode.splitText(existingRange.startOffset);
            const formatTags = _getFormatTags();
            let innerElement = trailingContent;
            let outerElement = selNode;
            for (let i=0; i<formatTags.length; i++) {
                newElement = document.createElement(formatTags[i]);
                newElement.appendChild(innerElement);
                innerElement = newElement;
            };
            if (formatTags.length > 0) {
                outerElement = _findFirstParentElementInNodeNames(selNode, [formatTags[formatTags.length - 1]]);
            };
            if (blockContainer) {
                // Make the newElement in the same style as its container.
                newElement = document.createElement(blockContainer.nodeName);
                newElement.appendChild(innerElement);
            } else if (!newElement) {
                // Make the newElement just an unstyled text node like it started.
                newElement = document.createTextNode(trailingContent);
            }
            newListItem.appendChild(newElement);
            // With trailingContent in newElement which is in newListItem,
            // append all of selNode's siblings to newElement
            sib = outerElement.nextSibling;
            while (sib) {
                nextSib = sib.nextSibling;
                newElement.appendChild(sib);
                sib = nextSib;
            }
            // And then make all of selNode's parentNode's siblings follow it in
            // the same newListItem. For example, we might have nested lists
            // below the text node we are splitting.
            if (blockContainer) {
                sib = blockContainer.nextSibling;
                while (sib) {
                    nextSib = sib.nextSibling;
                    newListItem.appendChild(sib);
                    sib = nextSib;
                }
            }
            // Then, insert the newListItem with its new children into the list before the next list element.
            existingList.insertBefore(newListItem, existingListItem.nextElementSibling);
            const range = document.createRange();
            // And leave selection in the newElement
            range.setStart(newElement, 0);
            range.setEnd(newElement, 0);
            sel.removeAllRanges();
            sel.addRange(range);
            _callback('input');
            return newElement;  // To preventDefault() on Enter
        };
    };
    return null;    // To let standard event handling happen
};

/**
 * We are inside of a list and want to indent the selected item in it.
 *
 * @return  {HTML Node}   The existing node put in new list of the same type to preventDefault handling; else, null.
 */
const _doListIndent = function() {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.focusNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!existingList || !existingListItem) { return null };
    _backupSelection();
    if (_indentListItem(existingListItem, existingList)) {
        _restoreSelection();
        _callback('input');
        return selNode;  // To preventDefault() on Enter
    };
    return null;
};

/**
 * Given an existingListItem in an existingList, indent the existingListItem,
 * leaving everything else (including existingListItem's sublists) at the same level.
 *
 * @return  {HTML Node}   The existingListItem if it could be indented; else, null.
 */
const _indentListItem = function(existingListItem, existingList) {
    const previousListItem = existingListItem.previousElementSibling;
    if (!previousListItem || (previousListItem.nodeName !== 'LI')) { return null };
    // The only valid child of UL or OL is LI; however,
    // LI can have UL or OL children to form sublists. So, indenting
    // means taking an existing LI putting it in a new UL or OL, and then
    // appending the new UL or OL as a child of the existing LI's
    // previousSibling. If previousElementSibling doesn't exist or is not
    // an LI, then the indent is not allowed. Thus, indenting the 2nd list
    // item in:
    //  <UL>
    //      <LI>List item 1</LI>
    //      <LI>List item 2</LI>
    //  </UL>
    // becomes:
    //  <UL>
    //      <LI>List item 1
    //          <UL>
    //              <LI>List item 2</LI>
    //          </UL>
    //      </LI>
    //  </UL>
    //
    // Check whether to put the newListItem in its own newList, or whether to append it to
    // the existingList at the level above in the list.
    // Consider:
    //  <UL>
    //      <LI>List item 1
    //          <UL>
    //              <LI>Sublist item 1</LI>
    //          </UL>
    //      </LI>
    //      <LI>List item 2</LI>
    //  </UL>
    // When indenting List item 2, we want:
    //  <UL>
    //      <LI>List item 1
    //          <UL>
    //              <LI>Sublist item 1</LI>
    //              <LI>List item 2</LI>
    //          </UL>
    //      </LI>
    //  </UL>
    // We don't want:
    //  <UL>
    //      <LI>List item 1
    //          <UL>
    //              <LI>Sublist item 1</LI>
    //          </UL>
    //          <UL>
    //              <LI>List item 2</LI>
    //          </UL>
    //      </LI>
    //  </UL>
    const prevListItemLastChild = previousListItem.lastElementChild;
    if (prevListItemLastChild && (prevListItemLastChild.nodeName === existingList.nodeName)) {
        // The previous list's last element is a list of the same type, so existingListItem should just be appended to it
        prevListItemLastChild.appendChild(existingListItem);
        
    } else {
        // We just need to create a newList to contain existingListItem, and then put that list
        // as a child of previousListItem.
        const newList = document.createElement(existingList.nodeName);
        newList.appendChild(existingListItem);
        previousListItem.appendChild(newList);
    };
    // But existingListItem's list children now have to be outdented so they stay at the original level in the list
    let existingChild = existingListItem.firstElementChild;
    while (existingChild && (existingChild.nodeName === existingList.nodeName)) {
        let existingSubListItem = existingChild.firstElementChild;
        while (existingSubListItem) {
            _outdentListItem(existingSubListItem, existingChild);
            existingSubListItem = existingChild.firstElementChild;
        };
        existingChild = existingListItem.firstElementChild;
    };
    return existingListItem;
};
    
/**
 * We are inside of a list and want to outdent the selected item in it.
 * We can only outdent if the list we are in is contained in another list.
 *
 * @return  {HTML Node}   The existing node put in the containing list of the same type; else, null.
 */
const _doListOutdent = function() {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.focusNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!(existingList && existingListItem)) { return null };
    _backupSelection();
    if (_outdentListItem(existingListItem, existingList)) {
        _restoreSelection()
        _callback('input');
        return selNode;  // To preventDefault() on Enter
    };
    return null;
};

/**
 * Given an existingListItem in an existingList, outdent the existingListItem,
 * leaving everything else (including existingListItem's sublists) at the same level.
 *
 * @return  {HTML Node}   The existingListItem if it could be outdented; else, null.
 */
const _outdentListItem = function(existingListItem, existingList) {
    // First, determine if we can outdent within an outerList, or if existingListItem
    // should just not be in a list at all
    const outerList = (existingList) ? _findFirstParentElementInNodeNames(existingList.parentNode, ['UL', 'OL']) : null;
    if (!outerList) {
        // We can't outdent in a list any further, so split the list here and then put
        // the existingListItem contents outside of the list, and return immediately;
        return _splitList(existingListItem)
    };
    // Following the comments in _indentListItem, we want to outdent
    // Sublist item 2 in:
    //  <UL>
    //     <LI>List item 1
    //         <UL>
    //             <LI>Sublist item 1</LI>
    //             <LI>Sublist item 2</LI>
    //             <LI>Sublist item 3</LI>
    //         </UL>
    //     </LI>
    //     <LI>List item 2</LI>
    //  </UL>
    // which should produce:
    //  <UL>
    //     <LI>List item 1
    //         <UL>
    //             <LI>Sublist item 1</LI>
    //         </UL>
    //     </LI>
    //     <LI>Sublist item 2
    //         <UL>
    //             <LI>Sublist item 3</LI>
    //         </UL>
    //     </LI>
    //     <LI>List item 2</LI>
    //  </UL>
    // To do this, find the existingListItem and the existingList it is inside of.
    // The existingList's parentNode's nextSibling is what we want to put the
    // existingListItem before. However, before we do that, move all of existingListItem's
    // nextSiblings to be its children, thereby "moving down" any nodes below it in the
    // existingList. When done, if existingList is empty, remove it.
    const nextListItem = existingList.parentNode.nextElementSibling;
    let sib = existingListItem.nextElementSibling;
    if (sib) {
        const newList = document.createElement(existingList.nodeName);
        while (sib) {
            newList.appendChild(sib);
            sib = existingListItem.nextElementSibling;
        }
        existingListItem.appendChild(newList);
    };
    outerList.insertBefore(existingListItem, nextListItem);
    if (existingList.children.length === 0) {
        existingList.parentNode.removeChild(existingList);
    };
    return existingListItem;
}

/**
 * Given a listItemElement that we want to be in a newListType,
 * split the list it resides in so that the listItemElement is in
 * its own list of newListType, and the one it was in has been split
 * around it. So, for example, if newListType is UL and listItemElement
 * is in an OL, then we end up with two or three lists depending on
 * whether the element was in the middle or at the ends of the original.
 * Note that the listItemElement might contain an Element or a text node,
 * and it might have children, such an a sublist of UL or OL.
 * If newListType is null or not specified, then place the contents
 * of the listItemElement between the split list, but not in a UL
 * or OL at all. In this case, we need to leave any "bare text" in
 * a <P>.
 *
 * @param   {HTML List Item Element}    listItemElement     The LI currently in a UL or OL.
 * @param   {String | null}             newListType         OL or UL to indicate what listItemElement should be in, or null.
 * @return  {HTML List Item Element}                        The listItemElement now residing in a new list of newListType, or null.
 */
const _splitList = function(listItemElement, newListType) {
    const oldList = listItemElement.parentNode;
    const oldListType = oldList.nodeName;
    const oldListItems = oldList.children;
    const preList = document.createElement(oldListType);
    const postList = document.createElement(oldListType);
    // Populate the preList and postList that will surround the new list
    // containing listItemElement or children of listItemElement
    let listToPopulate = preList;
    while (oldListItems.length > 1) {
        let index = (listToPopulate === preList) ? 0 : 1;
        let child = oldListItems[index];
        if (child === listItemElement) {
            listToPopulate = postList;  // Flip the listToPopulate and skip the listItemElement
            index = 1;
        } else {
            listToPopulate.appendChild(child);
        };
    };
    // Insert the preList and postList before and after the oldList (which now
    // contains only the listItemElement
    if (preList.children.length > 0) {
        oldList.parentNode.insertBefore(preList, oldList)
    };
    if (postList.children.length > 0) {
        oldList.parentNode.insertBefore(postList, oldList.nextSibling);
    };
    if (newListType) {
        // We want listItemElement to be in a list of newListType
        const newList = document.createElement(newListType);
        newList.appendChild(listItemElement);
        oldList.replaceWith(newList);
        return listItemElement;
    } else {
        // We want the contents of listItemElement to be embedded between
        // at the right place in the document, which varies depending on
        // whether there was a postList to mark the location.
        let insertionPoint;
        if (postList.children.length > 0) {
            insertionPoint = postList;
        } else {
            insertionPoint = oldList.nextSibling ?? MU.editor;
        };
        let child;
        const firstChild = listItemElement.firstChild;
        while (child = listItemElement.firstChild) {
            if (child.nodeType === Node.TEXT_NODE) {
                if (child.textContent.trim().length > 0) {
                    // We want any bare text node children to be embedded in <p>
                    const p = document.createElement('p');
                    p.appendChild(child);
                    insertionPoint.parentNode.insertBefore(p, insertionPoint);
                } else {
                    insertionPoint.parentNode.insertBefore(child, insertionPoint);
                };
            } else {
                // The child could be something like <p> or <h5>, or even a <ul> or <ol>
                insertionPoint.parentNode.insertBefore(child, insertionPoint);
            };
        };
        // But in any case, the oldList is depopulated by the time we are done, so remove it
        oldList.parentNode.removeChild(oldList);
        return (firstChild) ? firstChild : listItemElement; // firstChild should always exist
    };
};

/**
 * Given a listItemElement in a UL or OL list, examine its parent's siblings and collapse
 * as many as possible into a single list when they are of the same type. For example, if
 * listItemElement is in a UL list surrounded by two other ULs, then listItemElement's parent
 * will become be a single UL with the elements of all three ULs combined, and the
 * other ULs will be removed. Intervening white space and non-list elements are preserved.
 *
 * @param   {HTML List Item Element}    listItemElement     The LI currently in a UL or OL.
 */
const _collapseList = function(listItemElement) {
    const list = listItemElement.parentNode;
    const listType = list.nodeName;
    const firstChild = list.firstChild;
    // Use previousElementSibling to find the list, but use childNodes
    // to include intervening non-LI nodes as part of the collapsing process,
    // taking from prevList and putting before the (unchanging) firstChild of list.
    let prevList = list.previousElementSibling;
    while (prevList && (prevList.nodeName === listType)) {
        while (prevList.childNodes.length > 0) {
            list.insertBefore(prevList.childNodes[0], firstChild);
        };
        // Now the earlier content has been collapsed into list,
        // so remove it and move on to the previousElementSibling.
        prevList.parentNode.removeChild(prevList);
        prevList = prevList.previousElementSibling;
    };
    // Use nextElementSibling to find the list, but use childNodes
    // to include intervening non-LI nodes as part of the collapsing process,
    // taking from nextList and putting at the (changing) end of list.
    let nextList = list.nextElementSibling;
    while (nextList && (nextList.nodeName === listType)) {
        while (nextList.childNodes.length > 0) {
            let lastChild = list.lastChild;
            list.insertBefore(nextList.childNodes[0], lastChild.nextSibling);
        };
        // Now the following content has been collapsed into list,
        // so remove it and move on to the nextElementSibling.
        nextList.parentNode.removeChild(nextList);
        nextList = nextList.nextElementSibling;
    };
};

/**
 * Put the contents of selNode in a list of type newListType.
 *
 * @param {String}      newListType     The type of list to put selNode's contents in.
 * @param {HTML Node}   selNode         The node at the selection.
 * @return {HTML ListElement}           The new list element.
 */
const _replaceNodeWithList = function(newListType, selNode) {
    const newListElement = document.createElement(newListType);
    const newListItemElement = document.createElement('LI');
    if (selNode.nodeType == Node.TEXT_NODE) {
        newListItemElement.innerHTML = selNode.textContent;
    } else {
        newListItemElement.innerHTML = selNode.outerHTML;
    }
    newListElement.appendChild(newListItemElement);
    selNode.replaceWith(newListElement);
    return newListItemElement;
};

/**
 * Put the contents of selNode in a list item, and replace selNode with the new list item.
 *
 * @param {HTML Node}   selNode     The node at the selection.
 * @return {HTML ListItemElement}   The new list item element.
 */
const _replaceNodeWithListItem = function(selNode) {
    const newListItemElement = document.createElement('LI');
    if (selNode.nodeType == Node.TEXT_NODE) {
        newListItemElement.innerHTML = selNode.textContent;
    } else {
        newListItemElement.innerHTML = selNode.outerHTML;
    }
    selNode.replaceWith(newListItemElement);
    return newListItemElement;
};

/**
 * Add a new BLOCKQUOTE
 * This is a lot more like setting a style than a format, since it applies to the
 * selected element, not to the range of the selection.
 * However, it's important to note that while BLOCKQUOTEs can contain styled
 * elements, styled elements cannot contain BLOCKQUOTEs.
 *
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.increaseQuoteLevel = function(undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return null };
    const selectionState = _getSelectionState();
    // Capture the range settings for the selection
    const range = sel.getRangeAt(0).cloneRange();
    const oldStartContainer = range.startContainer;
    const oldStartOffset = range.startOffset;
    const oldEndContainer = range.endContainer;
    const oldEndOffset = range.endOffset;
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
    // We should always be selecting inside of some styled element,
    // but we don't know for sure.
    const selStyle = selectionState['style'];
    let selNodeParent;
    if (selStyle) {
        selNodeParent = _findFirstParentElementInNodeNames(selNode, [selStyle]);
    } else {
        const existingBlockQuote = _findFirstParentElementInNodeNames(selNode, ['BLOCKQUOTE']);
        if (existingBlockQuote) {
            selNodeParent = existingBlockQuote;
        } else {
            selNodeParent = selNode.parentNode;
        }
    }
    // Now create a new BLOCKQUOTE parent based, put the selNodeParent's outerHTML
    // into it, and replace the selNodeParent with the BLOCKQUOTE
    const newParent = document.createElement('blockquote');
    newParent.innerHTML = selNodeParent.outerHTML;
    selNodeParent.replaceWith(newParent);
    // Restore the selection by locating the start and endContainers in the newParent
    _backupSelection();
    let startContainer, endContainer;
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
        _backupSelection();
        const undoerData = _undoerData('indent', null);
        undoer.push(undoerData);
        _restoreSelection();
    }
    _callback('input');
    return selNode;
}

/**
 * Remove an existing BLOCKQUOTE if it exists
 *
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.decreaseQuoteLevel = function(undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return null };
    const existingElement = _findFirstParentElementInNodeNames(selNode, ['BLOCKQUOTE']);
    if (existingElement) {
        _unsetTag(existingElement, sel);
        if (undoable) {
            _backupSelection();
            const undoerData = _undoerData('indent', null);
            undoer.push(undoerData);
            _restoreSelection();
        }
        _callback('input');
        return selNode;
    };
    return null;
}

/********************************************************************************
 * Range operations
 */

const _reselect = function(sel, range) {
    sel.removeAllRanges();
    sel.addRange(range);
    _backupSelection();
}

/**
 * Return an object containing the startContainer, startOffset, endContainer, and endOffset at selection
 * A HTML Range obtained from selection.getRangeAt(0).cloneRange() can end up being changed
 * as focus changes, etc. So, to avoid the problem, return a range-like object with properties
 * for the startContainer, startOffset, endContainer, and endOffset.
 *
 * @return {Object | null}     Return the object or null if selection is non-existent
 */
const _rangeProxy = function() {
    const selection = document.getSelection();
    if (selection && (selection.rangeCount > 0)) {
        const range = selection.getRangeAt(0).cloneRange();
        return {
            'startContainer': range.startContainer,
            'startOffset': range.startOffset,
            'endContainer': range.endContainer,
            'endOffset': range.endOffset
        };
    } else {
        return null;
    };
};

/**
 * Restore the selection to the range held in rangeProxy
 *
 * @param {Object}  rangeProxy      The HTML Range-like object that was populated using _rangeProxy()
 */
const _restoreRange = function(rangeProxy) {
    if (rangeProxy && (rangeProxy.startContainer)) {
        const selection = document.getSelection();
        const range = document.createRange();
        range.setStart(rangeProxy.startContainer, rangeProxy.startOffset);
        range.setEnd(rangeProxy.endContainer, rangeProxy.endOffset);
        selection.removeAllRanges();
        selection.addRange(range);
    } else {
        _consoleLog('Attempt to restore null range');
        new Error('Attempt to restore null range');
    };
};

/**
 * Backup the range of the current selection into MU.currentSelection
 */
const _backupSelection = function() {
    const rangeProxy = _rangeProxy();
    MU.currentSelection = rangeProxy;
    if (!rangeProxy) {
        _consoleLog('Backed up null range');
        new Error('Backed up null range');
    };
};

/**
 * Restore the selection to the range held in MU.currentSelection
 */
const _restoreSelection = function() {
    _restoreRange(MU.currentSelection);
};

/**
 * Return a reasonably informative string describing the range, for debugging purposes
 *
 * @param {Object | HTML Range}     range   Something holding onto the startContainer, startOffset, endContainer, and endOffset
 */
const _rangeString = function(range) {
    const startContainer = range.startContainer;
    const endContainer = range.endContainer;
    let startContainerType, startContainerContent, endContainerType, endContainerContent;
    if (startContainer.nodeType === Node.TEXT_NODE) {
        startContainerType = '<TextElement>'
        startContainerContent = startContainer.textContent;
    } else {
        startContainerType = '<' + startContainer.nodeName + '>';
        startContainerContent = startContainer.innerHTML;
    };
    if (endContainer.nodeType === Node.TEXT_NODE) {
        endContainerType = '<TextElement>'
        endContainerContent = endContainer.textContent;
    } else {
        endContainerType = '<' + endContainer.nodeName + '>';
        endContainerContent = endContainer.innerHTML;
    };
    return '\n   startContainer: ' + startContainerType + ', content: ' + startContainerContent + '\n   startOffset: ' + range.startOffset + '\n   endContainer: ' + endContainerType + ', content: ' + endContainerContent + '\n   endOffset: ' + range.endOffset;
};

/********************************************************************************
 * Clean up to avoid ugly HTML
 */

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
    _cleanUpSpans();
    _cleanUpAttributes('style');
};

/**
 * Standard webkit editing may leave messy and useless SPANs all over the place.
 * This method just cleans them all up and notifies Swift that the content
 * has changed. Start with the selection focusNode's parent, so as to make
 * sure to get all its siblings. If there is no focusNode, fix the entire
 * editor.
 */
const _cleanUpSpans = function() {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    const startNode = (selNode) ? selNode.parentNode : MU.editor;
    if (startNode) {
        const spansRemoved = _cleanUpSpansWithin(startNode);
        if (spansRemoved > 0) {
            _callback('input');
        };
    };
};

/**
 * Do a depth-first traversal from node, removing spans starting at the leaf nodes.
 *
 * @return {Int}    The number of spans removed
 */
const _cleanUpSpansWithin = function(node) {
    let spansRemoved = 0;
    const children = node.children;
    if (children.length > 0) {
        for (let i=0; i<children.length; i++) {
            spansRemoved += _cleanUpSpansWithin(children[i]);
        };
    };
    if (node.nodeName === 'SPAN') {
        spansRemoved++;
        const template = document.createElement('template');
        template.innerHTML = node.innerHTML;
        const newElement = template.content;
        node.replaceWith(newElement);
    };
    return spansRemoved;
};

/**
 * Do a depth-first traversal from selection, removing attributes
 * from the focusNode and its siblings. If there is no focusNode,
 * fix the entire editor.
 * If any attributes were removed, then notify Swift of a content change
 */
const _cleanUpAttributes = function(attribute) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    const startNode = (selNode) ? selNode.parentNode : MU.editor;
    if (startNode) {
        const attributesRemoved = _cleanUpAttributesWithin(attribute, startNode);
        if (attributesRemoved > 0) {
            _callback('input');
        };
    };
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
    if (node.hasAttribute(attribute)) {
        attributesRemoved++;
        node.removeAttribute(attribute);
    };
    return attributesRemoved;
};
                                
/********************************************************************************
 * Explicit handling of multi-click
 * TODO: Remove?
 */

/**
 * We received a double or triple click event.
 * When switching between multiple MarkupWKWebViews, the double and triple click does
 * not highlight immediately. So, this method highlights and sets the selection properly
 * if needed. We can get double and triple clicks events when the selection is already
 * set properly, in which case we do nothing.
 *
 * @param {Int}     nClicks     The number of clicks in the 'click' event that got us here
 */
const _multiClickSelect = function(nClicks) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
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

/**
 * Select the word in the selNode
 *
 * @param {HTML Selection}  sel         The current selection
 * @param {HTML Node}       selNode     The node at the selection
 */
const _doubleClickSelect = function(sel, selNode) {
    const range = sel.getRangeAt(0).cloneRange();
    let startOffset = range.startOffset;
    let endOffset = range.endOffset;
    const selNodeText = selNode.textContent;
    while ((startOffset > 0) && !_isWhiteSpace(selNodeText[startOffset - 1])) {
        startOffset -= 1;
    }
    while ((endOffset < selNodeText.length) && !_isWhiteSpace(selNodeText[endOffset]))  {
        endOffset += 1;
    }
    const wordRange = document.createRange();
    wordRange.setStart(range.startContainer, startOffset);
    wordRange.setEnd(range.endContainer, endOffset);
    sel.removeAllRanges();
    sel.addRange(wordRange);
};

/**
 * Find the node that should be selected in full, and then select it
 *
 * @param {HTML Selection}  sel         The current selection
 */
const _tripleClickSelect = function(sel) {
    const nodeToSelect = _firstSelectionNodeMatching(_styleTags);
    if (nodeToSelect) {
        const elementRange = document.createRange();
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

/**
 * Return a boolean indicating if s is a white space
 *
 * @param   {String}      s     The string that might be white space
 * @return {Boolean}            Whether it's white space
 */
const _isWhiteSpace = function(s) {
    return /\s/g.test(s);
};

/********************************************************************************
 * Selection
 */

/**
 * Define various arrays of tags used to represent concepts on the Swift side.
 *
 * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
 */
const _listStyleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE'];

const _styleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'LI', 'BLOCKQUOTE', 'OL', 'UL'];

const _formatTags = ['B', 'I', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];

const _tableTags = ['TABLE', 'THEAD', 'TBODY', 'TD', 'TR', 'TH'];

const _paragraphStyleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'];

const _monitorEnterTags = ['UL', 'OL', 'TABLE', 'BLOCKQUOTE'];

/**
 * Populate a dictionary of properties about the current selection
 * and return it in a JSON form. This is the primary means that the
 * Swift side finds out what the selection is in the document, so we
 * can tell if the selection is in a bolded word or a list or a table, etc.
 *
 * @return {String}      The stringified dictionary of selectionState.
 */
MU.getSelectionState = function() {
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
    if (!document.getSelection()) {
        return state;
    }
    // Selected text
    state['selection'] = _getSelectionText();
    // Link
    const linkAttributes = _getLinkAttributesAtSelection();
    state['href'] = linkAttributes['href'];
    state['link'] = linkAttributes['link'];
    // Image
    const imageAttributes = _getImageAttributesAtSelection();
    state['src'] = imageAttributes['src'];
    state['alt'] = imageAttributes['alt'];
    state['scale'] = imageAttributes['scale'];
    state['frame'] = imageAttributes['frame'];
    // Table
    const tableAttributes = _getTableAttributesAtSelection();
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
    state['style'] = _getParagraphStyle();
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
    const formatTags = _getFormatTags();
    state['bold'] = formatTags.includes('B');
    state['italic'] = formatTags.includes('I');
    state['underline'] = formatTags.includes('U');
    state['strike'] = formatTags.includes('DEL');
    state['sub'] = formatTags.includes('SUB');
    state['sup'] = formatTags.includes('SUP');
    state['code'] = formatTags.includes('CODE');
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
 * Return the paragraph style at the selection.
 *
 * @return {String}         Tag name that represents the selected paragraph style on the Swift side.
 */
const _getParagraphStyle = function() {
    return _firstSelectionTagMatching(_paragraphStyleTags);
};

/**
 * Return an array of format tags at the selection. For example, the selection could
 * be in the word "Hello" in <B><I><U>Hello</U></I></B>, returning ['U', 'I', 'B'],
 * from innermost to outermost tag.
 *
 * @return {[String]}       Tag names that represent the selection formatting on the Swift side.
 */
const _getFormatTags = function() {
    return _selectionTagsMatching(_formatTags);
};

/**
 * Return an array of table tags at the selection. For example, if the selection is in
 * a TD element or a TR in the TBODY, we will get ['TABLE', 'TBODY', 'TR', 'TD'].
 *
 * @return {[String]}       Tag names that represent the selection table elements.
 */
const _getTableTags = function() {
    return _selectionTagsMatching(_tableTags);
};

/**
 * Return the currently selected text.
 *
 * @return {String}         The selected text, which may be empty
 */
const _getSelectionText = function() {
    const sel = document.getSelection();
    if (sel) {
        return sel.toString();
    }
    return '';
};

/**
 * For testing purposes, set selection based on elementIds and offsets
 * Like range, the startOffset and endOffset are number of characters
 * when startElement is #text; else, child number.
 *
 * @param   {String}  startElementId      The id of the element to use as startContainer for the range.
 * @param   {Int}     startOffset         The offset into the startContainer for the range.
 * @param   {String}  endElementId        The id of the element to use as endContainer for the range.
 * @param   {Int}     endOffset           The offset into the endContainer for the range.
 * @return  {Boolean}                     True if both elements are found; else, false.
 */
MU.setRange = function(startElementId, startOffset, endElementId, endOffset) {
    const startElement = document.getElementById(startElementId);
    const endElement = document.getElementById(endElementId);
    if (!startElement || !endElement) { return false };
    const startContainer = _firstTextNodeChild(startElement);
    const endContainer = _firstTextNodeChild(endElement);
    if (!startContainer || !endContainer) { return false };
    const range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    const sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    return true;
};

/**
 * For testing purposes, invoke undo by direct input to undoer.
 * Using MU.undo() from a test does not work properly.
 */
MU.testUndo = function() {
    undoer.testUndo();
}

/**
 * For testing purposes, invoke redo by direct input to undoer.
 * Using MU.redo() from a test does not work properly.
 */
MU.testRedo = function() {
    undoer.testRedo();
}

/********************************************************************************
 * Links
 */

/**
 * Insert a link to url. The selection has to be across a range.
 * When done, re-select the range and back it up.
 *
 * @param {String}  url             The url/href to use for the link
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.insertLink = function(url, undoable=true) {
    _restoreSelection();
    const sel = document.getSelection();
    if (!sel || (sel.rangeCount === 0)) { return };
    let range;
    if (sel.isCollapsed) {
        range = _wordRangeAtCaret()
    } else {
        range = sel.getRangeAt(0).cloneRange();
    }
    const el = document.createElement('a');
    el.setAttribute('href', url);
    el.appendChild(range.extractContents());
    range.deleteContents();
    range.insertNode(el);
    range.setStart(el.firstChild, 0);
    range.setEnd(el.firstChild, el.firstChild.textContent.length);
    sel.removeAllRanges();
    sel.addRange(range);
    // Note because the selection is changing while the view is not focused,
    // we need to backupSelection() so we can get it back when we come back
    // into focus later.
    _backupSelection();
    if (undoable) {
        const undoerData = _undoerData('insertLink', url);
        undoer.push(undoerData);
        _restoreSelection();
    }
    _callback('input');
};

/**
 * Remove the link at the selection.
 *
 * @param {Boolean} undoable        True if we should push undoerData onto the undo stack.
 */
MU.deleteLink = function(undoable=true) {
    // When we call this method, sel is the text inside of an anchorNode
    _restoreSelection();
    const sel = document.getSelection();
    if (sel) {
        const element = sel.anchorNode.parentElement;
        if ('A' === element.nodeName) {
            // Before we _unsetTag, we know what element is and can determine what to select
            // after it is gone. We want to select all of the text that was linked-to
            // as if the user had selected the entire link. After selecting it, then set that
            // as the backed-up range before unsetting the tag. So, if we started with a caret
            // selection inside of a link and removed the link, we will end up with the entire
            // linked-to text selected when done. Now the undo operation knows the text selection
            // and when undo happens, the link can be properly restored.
            const linkRange = document.createRange();
            const linkText = element.firstChild;
            linkRange.setStart(linkText, 0);
            linkRange.setEnd(linkText, linkText.length);
            sel.removeAllRanges();
            sel.addRange(linkRange);
            _unsetTag(element, sel);
            _backupSelection();
            if (undoable) {
                const undoerData = _undoerData('deleteLink', element.href);
                undoer.push(undoerData);
                _restoreSelection();
            }
            _callback('input');
        }
    }
}

/**
 * If the current selection's parent is an A tag, get the href and text.
 *
 * @return {String : String}        Dictionary with 'href' and 'link' as keys; empty if not a link
 */
const _getLinkAttributesAtSelection = function() {
    const link = {};
    const sel = document.getSelection();
    if (sel) {
        const element = sel.anchorNode.parentElement;
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
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoInsertLink = function(undoerData) {
    // Reset the selection based on the range after the link was removed,
    // then insert the link at that range. After the link is re-inserted,
    // the insertLink operation leaves the selection properly set,
    // but we have to update the undoerData.range to reflect it.
    _restoreUndoerRange(undoerData);
    _backupSelection();
    MU.insertLink(undoerData.data, false);
    _backupUndoerRange(undoerData);
}

/**
 * Do the deleteLink operation following an insertLink operation
 * Used to undo the insertLink operation and to do the deleteLink operation.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoDeleteLink = function(undoerData) {
    // Reset the selection based on the range after insert was done,
    // then remove the link at that range. When the link is re-removed,
    // the deleteLink operation leaves the selection properly set,
    // but we have to update the undoerData.range to reflect it.
    _restoreUndoerRange(undoerData);
    _backupSelection();
    MU.deleteLink(false);
    _backupUndoerRange(undoerData);
}

/********************************************************************************
 * Images
 */

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
 * @param {Int}                 scale       The scale as a percentage of original's naturalWidth/Height.
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 * @return {HTML Image Element}             The image element that was created, used for undo/redo.
 */
MU.insertImage = function(src, alt, scale=100, undoable=true) {
    _restoreSelection();
    const sel = document.getSelection();
    const range = sel.getRangeAt(0).cloneRange();
    const img = document.createElement('img');
    img.setAttribute('src', src);
    if (alt) { img.setAttribute('alt', alt) };
    if (scale !== 100) {
        img.setAttribute('width', scale);
        img.setAttribute('height', scale);
    }
    img.setAttribute('tabindex', -1);                       // Allows us to select the image
    img.onload = function() { _callback('updateHeight') };  // Let Swift know the height changed after loading
    range.insertNode(img);
    // After inserting the image, we want to leave the selection at the beginning
    // of the nextTextElement after it for inline images. If there is no such thing,
    // then find the next best thing.
    const nearestTextNode = _getFirstChildOfTypeAfter(img, Node.TEXT_NODE);
    const newRange = document.createRange();
    if (nearestTextNode) {
        newRange.setStart(nearestTextNode, 0);
        newRange.setEnd(nearestTextNode, 0);
    } else {
        const nextSibling = img.nextSibling;
        if (nextSibling && (nextSibling.nodeName === 'BR')) {
            const newTextNode = document.createTextNode('');
            nextSibling.replaceWith(newTextNode);
            newRange.setStart(newTextNode, 0);
            newRange.setEnd(newTextNode, 0);
        } else {
            newRange.setStart(img, 0);
            newRange.setEnd(img, 0);
        };
    };
    sel.removeAllRanges();
    sel.addRange(newRange);
    _backupSelection();
    // Track image insertion on the undo stack if necessary and hold onto the new image element's range
    // Note that the range tracked on the undo stack is not the same as the selection, which has been
    // set to make continued typing easy after inserting the image.
    if (undoable) {
        const imgRange = document.createRange();
        imgRange.selectNode(img);
        const undoerData = _undoerData('insertImage', {src: src, alt: alt, scale: scale}, imgRange);
        undoer.push(undoerData);
        _restoreSelection();
    };
    _callback('input');
    return img;
};

/**
 * Modify the attributes of the image at selection.
 * If src is null, then remove the image.
 * Scale is a percentage like '80' where null means 100%.
 * Scale is always expressed relative to full scale.
 * Only removing an image is undoable.
 *
 * @param {String}              src         The url of the image.
 * @param {String}              alt         The alt text describing the image.
 * @param {Int}                 scale       The scale as a percentage of original's naturalWidth/Height.
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 */
MU.modifyImage = function(src, alt, scale, undoable=true) {
    _restoreSelection();
    const img = _getElementAtSelection('IMG');
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
            _restoreSelection()
        } else {
            // Before removing the img, record the existing src, alt, and scale
            const deletedSrc = img.getAttribute('src');
            const deletedAlt = img.getAttribute('alt');
            const deletedScale = img.getAttribute('width');
            _deleteAndResetSelection(img, 'BEFORE');
            if (undoable) {
                const undoerData = _undoerData('modifyImage', {src: deletedSrc, alt: deletedAlt, scale: deletedScale});
                undoer.push(undoerData);
                _restoreSelection();
            }
        };
        _callback('input');
    };
};

/**
 * If the current selection's anchorNode is an IMG tag, get the src and alt.
 * We include the boundingRect in attributes in case we want to do something with it on the Swift side.
 *
 * @return {String : String}        Dictionary with 'src', 'alt', etc as keys; empty if not an image.
 */
const _getImageAttributesAtSelection = function() {
    const attributes = {};
    const img = _getElementAtSelection('IMG');
    if (img) {
        attributes['src'] = img.getAttribute('src');
        attributes['alt'] = img.getAttribute('alt');
        const scale = _imgScale(img);
        if (scale) {
            attributes['scale'] = scale;
        };
        const rect = img.getBoundingClientRect();
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
 * Do the insertImage operation following a modifyImage operation
 * Used to undo the modifyImage/remove operation and to do the insertImage operation.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoInsertImage = function(undoerData) {
    // Reset the selection based on the range after the image was removed,
    // then insert the image at that range. After the image is re-inserted,
    // the insertImage operation leaves the selection properly set to keep
    // typing, but we need to update the undoerData.range with the range
    // for the newly (re)created image element.
    _restoreUndoerRange(undoerData);
    _backupSelection();
    const el = MU.insertImage(undoerData.data.src, undoerData.data.alt, undoerData.data.scale, false);
    const range = document.createRange();
    range.selectNode(el);
    undoerData.range = range;
}

/**
 * Do the modifyImage operation following an insertImage operation
 * Used to undo the insertImage operation and to do the modifyImage/remove operation.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoModifyImage = function(undoerData) {
    // The undoerData has the range to select to remove the image;
    // iow, the image exists when modifyImage is called.
    // Once the image is removed, the selection is set properly, and
    // we don't want to update the undoerData.
    // Remove image is done with modifyImage but with src=null.
    _restoreUndoerRange(undoerData);
    _backupSelection();
    MU.modifyImage(null, null, null, false);
}

/********************************************************************************
 * Tables
 */

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
    if ((rows < 1) || (cols < 1)) { return };
    _restoreSelection();
    const sel = document.getSelection();
    const selNode = (sel) ? sel.focusNode : null;
    const table = document.createElement('table');
    const tbody = document.createElement('tbody');
    for (let row=0; row<rows; row++) {
        let tr = document.createElement('tr');
        for (let col=0; col<cols; col++) {
            let td = document.createElement('td');
            tr.appendChild(td);
        };
        tbody.appendChild(tr);
    };
    table.appendChild(tbody);
    const targetNode = _findFirstParentElementInNodeNames(selNode, _styleTags);
    if (!targetNode) { return };
    targetNode.insertAdjacentHTML('afterend', table.outerHTML);
    // We need the new table that now exists at selection.
    // Restore the selection to leave it at the beginning of the new table
    const newTable = _getFirstChildWithNameWithin(targetNode.nextSibling, 'TABLE');
    _restoreTableSelection(newTable, 0, 0, false);
    // Track table insertion on the undo stack if necessary
    if (undoable) {
        const undoerData = _undoerData('insertTable', {row: 0, col: 0, inHeader: false, outerHTML: table.outerHTML});
        undoer.push(undoerData);
    }
    _callback('input');
    return newTable;
};

/**
 * Delete the entire table at the selection.
 *
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteTable = function(undoable=true) {
    const elements = _getTableElementsAtSelection();
    const table = elements['table'];
    if (table) {
        const outerHTML = table.outerHTML;
        const row = elements['row'];
        const col = elements['col'];
        const inHeader = elements['thead'] != null     // Are we in the header?
        _deleteAndResetSelection(table, 'BEFORE');
        if (undoable) {
            const undoerData = _undoerData('deleteTable', {row: row, col: col, inHeader: inHeader, outerHTML: outerHTML});
            undoer.push(undoerData);
            _restoreSelection();
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
 * the elements['thead'] is the HTML Table Header Element, whereas attributes['thead']
 * is either true or false indicating whether the selection is in the header.
 * Similarly, elements['header'] and ['colspan'] are true or false so
 * can be stored in attributes directly.
 *
 * @return {String : T}     Dictionary with keys of various types consumable in Swift
 */
const _getTableAttributesAtSelection = function() {
    const attributes = {};
    const elements = _getTableElementsAtSelection();
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
 *
 * @return {String : T}     Dictionary with keys of types consumable here in JavaScript
 */
const _getTableElementsAtSelection = function() {
    const elements = {};
    const cell = _firstSelectionNodeMatching(['TD', 'TH']);
    if (cell) {
        let _cell = cell;
        // Track the cell the selection is in
        if (cell.nodeName === 'TD') {
            elements['td'] = cell;
        } else {
            elements['th'] = cell;
        }
        // Find the column the selection is in, since we know it immediately
        let colCount = 0;
        while (_cell.previousElementSibling) {
            _cell = _cell.previousElementSibling;
            if (_cell.nodeType === cell.nodeType) { colCount++; };
        };
        elements['col'] = colCount;
        // Track the row the selection is in
        const row = cell.parentNode;
        if (row.nodeName === 'TR') {
            elements['tr'] = row;
        } else {
            return {};
        }
        // Track whether we are in the header or body
        const section = row.parentNode;
        if (section.nodeName === 'TBODY') {
            elements['tbody'] = section;
            // If the selection is in the body, then we can find the row
            let _row = row;
            let rowCount = 0;
            while (_row.previousElementSibling) {
                _row = _row.previousElementSibling;
                if (_row.nodeType === row.nodeType) { rowCount++; };
            };
            elements['row'] = rowCount;
        } else if (section.nodeName === 'THEAD') {
            elements['thead'] = section;
        } else {
            return {};
        };
        // Track the selected table
        const table = section.parentNode;
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
 *
 * @param {HTML Table Element}  table   The table being examined
 * @return {[T]}                        Array with number of rows and cols and whether a header with or without colSpan exists
 */
const _getRowsCols = function(table) {
    let rowCount = 0;
    let colCount = 0;
    let headerExists = false;
    let colspan = null;
    const children = table.children;
    for (let i=0; i<children.length; i++) {
        let section = children[i];
        let rows = section.children;
        if (rows.length > 0) {
            let row = rows[0];
            let cols = row.children;
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
    const colSpanExists = colspan != null;
    return [ rowCount, colCount, headerExists, colSpanExists ];
}

/**
 * Return the section of the table identified by node name
 *
 * @param {HTML Table Element}  table   The table being examined.
 * @param {String}              name    The desired section, either 'THEAD' or 'TBODY'.
 * @return {HTML Table Header | HTML Table Body | null}
 */
const _getSection = function(table, name) {
    const children = table.children;
    for (let i=0; i<children.length; i++) {
        let section = children[i];
        if (section.nodeName === name) {
            return section;
        };
    };
    return null;
};

/**
 * Add a row before or after the current selection, whether it's in the header or body.
 * For rows, AFTER = below; otherwise above.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new row goes relative to the selection.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addRow = function(direction, undoable=true) {
    _backupSelection();
    let addedRow = false;
    const tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    const table = tableElements['table'];
    const tr = tableElements['tr'];
    const tbody = tableElements['tbody'];
    const thead = tableElements['thead'];
    const rows = tableElements['rows'];
    const cols = tableElements['cols'];
    const row = tableElements['row'];
    const col = tableElements['col'];
    const outerHTML = table.outerHTML;    // The table contents before we insert a row
    // Create an empty row with the right number of elements
    const newRow = document.createElement('tr');
    for (let i=0; i<cols; i++) {
        let td = document.createElement('td');
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
                let body = _getSection(table, 'TBODY');
                if (body) {
                    let firstRow = body.children[0];
                    body.insertBefore(newRow, firstRow);
                    addedRow = true;
                }
            } else {
                // The body doesn't exist because rows === 0
                // Create it and put the new row in it
                let body = document.createElement('tbody');
                body.appendChild(newRow);
                table.appendChild(body)
                addedRow = true;
            }
        }
    } else if (tbody) {
        if (direction === 'AFTER') {
            // We are in the body, so tr is the selected row
            // If tr.nextElementSibling is null, newRow will be inserted
            // after tr.
            tbody.insertBefore(newRow, tr.nextElementSibling);
        } else {
            tbody.insertBefore(newRow, tr)
        }
        addedRow = true;
    } else {
        _consoleLog('Could not add row');
    }
    _restoreSelection();
    // Track row addition on the undo stack if necessary.
    if (undoable && addedRow) {
        const undoerData = _undoerData('restoreTable', {row: row, col: col, inHeader: (thead != null), outerHTML: outerHTML});
        undoer.push(undoerData);
        _restoreSelection();
    }
    _callback('input');
};

/**
 * Add a column before or after the current selection, whether it's in the header or body.
 *
 * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new column goes relative to the selection.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addCol = function(direction, undoable=true) {
    _backupSelection();
    const tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    const table = tableElements['table'];
    const row = tableElements['row'];
    const col = tableElements['col'];
    const cols = tableElements['cols'];
    const tbody = tableElements['tbody'];
    const thead = tableElements['thead'];
    const colspan = tableElements['colspan'];
    const outerHTML = table.outerHTML;  // Table contents before we add a column
    if (tbody || (thead && !colspan)) {
        // We have selected the body of the table or the header.
        // In the case of selecting the header, it is a non-colspan header,
        // so col is meaningful (otherwise it is always 1 in a colspan header).
        // Loop over all rows in the body, adding a new td in each one
        const body = _getSection(table, 'TBODY');
        if (body) {
            const rows = body.children;       // Only tr elements
            for (let j=0; j<rows.length; j++) {
                let tr = rows[j];
                let td = tr.children[col];  // Only td elements
                // Then insert a new td before or after
                let newTd = document.createElement('td');
                // For reference, form of insertBefore is...
                //  let insertedNode = parentNode.insertBefore(newNode, referenceNode)
                if (direction === 'AFTER') {
                    tr.insertBefore(newTd, td.nextElementSibling);
                } else {
                    tr.insertBefore(newTd, td);
                };
            };
        };
        const header = _getSection(table, 'THEAD');
        if (header) {
            // If the header exists for this table, we need to expand it, too.
            let tr = header.children[0];    // Only tr elements
            let th = tr.children[0];
            if (colspan) {
                th.setAttribute('colspan', cols+1)
            } else {
                th = tr.children[col];           // Only th elements
                // Then insert a new td before or after
                let newTh = document.createElement('th');
                // For reference, form of insertBefore is...
                //  let insertedNode = parentNode.insertBefore(newNode, referenceNode)
                if (direction === 'AFTER') {
                    th.insertBefore(newTh, th.nextElementSibling);
                } else {
                    th.insertBefore(newTh, th);
                };
            };
        };
    };
    _restoreSelection();
    // Track col addition on the undo stack if necessary.
    if (undoable) {
        // Use restoreTable to handle addCol undo/redo
        const undoerData = _undoerData('restoreTable', {row: row, col: col, inHeader: (thead != null), outerHTML: outerHTML});
        undoer.push(undoerData);
        _restoreSelection();
    };
    _callback('input');
};

/**
 * Add a header to the table at the selection.
 *
 * @param {Boolean} colspan     Whether the header should span all columns of the table or not.
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.addHeader = function(colspan=true, undoable=true) {
    _backupSelection();
    const tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tbody has to be selected
    const table = tableElements['table'];
    const row = tableElements['row'];
    const col = tableElements['col'];
    const cols = tableElements['cols'];
    const tbody = tableElements['tbody'];
    const outerHTML = table.outerHTML;
    if (tbody) {
        const header = document.createElement('thead');
        const tr = document.createElement('tr');
        if (colspan) {
            let th = document.createElement('th');
            th.setAttribute('colspan', cols);
            tr.appendChild(th);
            header.appendChild(tr);
        } else {
            for (let i=0; i<cols; i++) {
                let th = document.createElement('th');
                tr.appendChild(th);
            }
            header.appendChild(tr);
        };
        table.insertBefore(header, tbody);
    };
    _restoreSelection();
    if (undoable) {
        // Use restoreTable to handle addHeader undo/redo
        const undoerData = _undoerData('restoreTable', {row: row, col: col, inHeader: false, outerHTML: outerHTML});
        undoer.push(undoerData);
        _restoreSelection();
    };
    _callback('input');
};

/**
 * Delete the row at the selection point in the table.
 *
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteRow = function(undoable=true) {
    _backupSelection();
    const tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    // tr might be the row in the header or a row in the body
    const table = tableElements['table'];
    const thead = tableElements['thead'];
    const tbody = tableElements['tbody'];
    const tr = tableElements['tr'];
    const outerHTML = table.outerHTML;
    const row = tableElements['row'];
    const col = tableElements['col'];
    let newTr;
    if (thead) {
        // We are going to delete the header,
        // So we will identify the first body cell
        // for selection after deleting
        const body = _getSection(table, 'TBODY');
        if (body) {
            newTr = body.firstElementChild;
        }
    } else if (tbody) {
        // We are going to delete a body row,
        // So we will choose the nextSib if there is one,
        // or prevSib if not, or even the header if we have to
        // for selection after deleting
        if (tr.nextElementSibling) {
            newTr = tr.nextElementSibling;
        } else if (tr.previousElementSibling) {
            newTr = tr.previousElementSibling;
        } else if (_getSection(table, 'THEAD')) {
            const header = _getSection(table, 'THEAD');
            newTr = header.firstElementChild;
        }
    }
    if (newTr) {
        // There is a row left, so we will do the remove and select the first element of the newTr
        tr.parentNode.removeChild(tr);
        _selectCol(newTr, 0)
        if (undoable) {
            const undoerData = _undoerData('restoreTable', {outerHTML: outerHTML, row: row, col: col, inHeader: (thead != null)});
            undoer.push(undoerData);
            _restoreSelection();
        };
    } else {
        // We just removed everything in the table, so let's just get rid of it.
        _deleteAndResetSelection(table, 'BEFORE');
        if (undoable) {
            const undoerData = _undoerData('deleteTable', {row: row, col: col, inHeader: (thead != null), outerHTML: outerHTML});
            undoer.push(undoerData);
            _restoreSelection();
        };
    }
    _callback('input');
};

/**
 * Delete the column at the selection point in the table.
 *
 * @param {Boolean} undoable    True if we should push undoerData onto the undo stack.
 */
MU.deleteCol = function(undoable=true) {
    _backupSelection();
    const tableElements = _getTableElementsAtSelection();
    if (tableElements.length === 0) { return };
    // There will always be a table and tr and either tbody or thead
    // tr might be the row in the header or a row in the body
    const table = tableElements['table'];
    const thead = tableElements['thead'];
    const tbody = tableElements['tbody'];
    const newTr = tableElements['tr'];
    const cols = tableElements['cols'];
    const col = tableElements['col'];
    const colspan = tableElements['colspan'];
    const outerHTML = table.outerHTML;
    const row = tableElements['row'];
    let newCol;
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
        _deleteAndResetSelection(table, 'BEFORE');
        if (undoable) {
            const undoerData = _undoerData('deleteTable', {row: row, col: col, inHeader: (thead != null), outerHTML: outerHTML});
            undoer.push(undoerData);
            _restoreSelection();
        };
        _callback('input');
        return;
    }
    // newCol should be non-null if we got here; iow, we will be deleting a column and leaving
    // the remaining table in place with a cell selected.
    // Now delete the column elements from each row and the header
    let tr, td, th;
    const body = _getSection(table, 'TBODY');
    if (body) {
        const rows = body.children;
        for (let j=0; j<rows.length; j++) {
            tr = rows[j];
            td = tr.children[col];
            tr.removeChild(td);
        }
    };
    const header = _getSection(table, 'THEAD');
    if (header) {
        tr = header.children[0];
        th = tr.children[0];
        if (colspan) {
            th.setAttribute('colspan', cols-1);
        } else {
            tr.removeChild(th);
        };
    };
    // Then, since newTr still exists, select the newCol child in it
    _selectCol(newTr, newCol)
    if (undoable) {
        const undoerData = _undoerData('restoreTable', {row: row, col: col, inHeader: (thead != null), outerHTML: outerHTML});
        undoer.push(undoerData);
        _restoreSelection();
    };
    _callback('input');
};

/**
 * Given a row, tr, select at the beginning of the first text element in col, or
 * the entire first element if not a text element.
 *
 * @param {HTML Row Element}    tr      The row that holds the TD or TH cell in column col to be selected.
 * @param {Int}                 col     The column to be selected
 * @returns {HTML Node | null}          The selected node at row/col or header in table
 */
const _selectCol = function(tr, col) {
    const cell = tr.children[col];
    let selectedNode = null;
    if (cell) { // The cell is either a th or td
        const sel = document.getSelection();
        const range = document.createRange();
        const cellNode = cell.firstChild;
        if (cellNode) {
            selectedNode = cellNode;
            if (cellNode.nodeType === Node.TEXT_NODE) {
                range.setStart(cellNode, 0);
                range.setEnd(cellNode, 0);
            } else {
                range.selectNode(cellNode);
            };
        } else {
            const br = document.createElement('br');
            cell.appendChild(br);
            range.selectNode(br);
            selectedNode = br;
        };
        sel.removeAllRanges();
        sel.addRange(range);
        _backupSelection();
    };
    return selectedNode;
};

/**
 * Given the table, row, col, and whether we want to select row/col in the header,
 * reset the selection to the row/col in the table.
 * Used after doInsertTable to restore the selection to the same row/col it
 * started it, but will be at the beginning of the first child in it.
 *
 * @param {HTML Table Element}  table   The table to put the selection in.
 * @param {Int}                 row     The row number to select the TD cell in.
 * @param {Int}                 col     The column number to select the TD or TH cell in.
 * @returns {HTML Node | null}          The selected node at row/col or header in table
 */
const _restoreTableSelection = function(table, row, col, inHeader) {
    let tr;
    if (inHeader) {
        const header = _getSection(table, 'THEAD');
        tr = header.children[0];
    } else {
        const body = _getSection(table, 'TBODY');
        tr = body.children[row];
    }
    return _selectCol(tr, col)
};

/**
 * Do the insertTable operation following a deleteTable operation.
 * Used to undo the deleteTable operation and to do the insertTable operation.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoInsertTable = function(undoerData) {
    // Reset the selection based on the range after the table was removed,
    // then insert the table at that range. The original table's outerHTML
    // is held in the undoerData.data.outerHTML along with the row and col of
    // the selection. After the table is re-inserted, we need to update the
    // undoerData.range with the range for the newly (re)created table element.
    // We leave the selection at the same row/col that was selected when the
    // table was deleted, but we don't try to put it at the same offset as before.
    const endContainer = undoerData.range.endContainer;
    let targetNode = endContainer;
    if (endContainer.nodeType === Node.TEXT_NODE) {
        targetNode = endContainer.parentNode;
    };
    targetNode.insertAdjacentHTML('afterend', undoerData.data.outerHTML);
    _callback('input');
    // We need the new table that now exists at selection.
    // Restore the selection to leave it at the beginning of the proper row/col
    // it was at when originally deleted. Then reset the undoerData range to hold
    // onto the new range.
    const table = _getFirstChildWithNameWithin(targetNode.nextSibling, 'TABLE');
    if (table) {
        _restoreTableSelection(table, undoerData.data.row, undoerData.data.col, undoerData.data.inHeader)
        _backupUndoerRange(undoerData);
    };
};

/**
 * Do the deleteTable operation following an insertTable operation.
 * Used to undo the insertTable operation and to do the deleteTable operation.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoDeleteTable = function(undoerData) {
    // The undoerData has the range to select to remove the table;
    // iow, the table exists when deleteTable is called. Leave the
    // undoerData.range set to the selection after deleting the table.
    _restoreUndoerRange(undoerData);
    _backupSelection();
    MU.deleteTable(false);
    _backupUndoerRange(undoerData);
};

/**
 * Restore the previous table by deleting the existing table and
 * inserting the one held in undoerData. This is a lazy way to
 * handle undo/redo for addRow, deleteRow, addCol, and deleteCol.
 * In each of these cases, undoerData holds the row and column
 * that were selected before the operation we are undoing or redoing,
 * along with the outerHTML that existed before the operation.
 * Before we leave here, we need to reset the undoerData.outerHTML
 * to hold the table contents that existed when we arrive (i.e., after
 * the operation we are undoing or redoing, but before we do the undo
 * or redo). Because the selection might have changed in the operation
 * (e.g., we might end up in col 0 of a colspan header after deleting
 * the last row of the body), we also have to reset row, col, and inHeader.
 * Why not reset the undoerData.range? Because the range is what we need
 * to delete the *table*, not to delete a row or col or add a row or col,
 * and that does not change.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _restoreTable = function(undoerData) {
    _restoreUndoerRange(undoerData);
    const tableElements = _getTableElementsAtSelection();
    const table = tableElements['table'];
    const outerHTML = table.outerHTML;
    const row = tableElements['row'];
    const col = tableElements['col'];
    const inHeader = tableElements['thead'] != null
    _redoDeleteTable(undoerData);
    _redoInsertTable(undoerData);
    undoerData.data.outerHTML = outerHTML;
    undoerData.data.row = row;
    undoerData.data.col = col;
    undoerData.data.inHeader = inHeader;
};

/**
 * Move from current row/col forward to the next one in the table.
 * Special handling for the last final cell of the table to insert a
 * new row and the move into it.
 * @returns {HTML Node | null}          The cell we navigated to
 */
const _doNextCell = function() {
    const tableElements = _getTableElementsAtSelection();
    const table = tableElements['table'];
    const row = tableElements['row'];
    const col = tableElements['col'];
    const rows = tableElements['rows'];
    const cols = tableElements['cols'];
    const inHeader = tableElements['thead'] != null
    const colspan = tableElements['colspan']
    let nextElement = null;
    if (inHeader) {
        if (!colspan && (col < cols-1)) {
            nextElement = _restoreTableSelection(table, row, col+1, true);
        } else if (rows > 0) {
            nextElement = _restoreTableSelection(table, 0, 0, false);
        } else {
            MU.addRow('AFTER');
            const newTableElements = _getTableElementsAtSelection();
            const newTable = newTableElements['table'];
            nextElement = _restoreTableSelection(newTable, 0, 0, false);
        };
    } else if (col < cols-1) {
        nextElement = _restoreTableSelection(table, row, col+1, false);
    } else if (row < rows-1) {
        nextElement = _restoreTableSelection(table, row+1, 0, false);
    } else if ((row === rows-1) && (col === cols-1)) {
        MU.addRow('AFTER');
        const newTableElements = _getTableElementsAtSelection();
        const newTable = newTableElements['table'];
        const newRows = newTableElements['rows'];   // should be original rows+1
        nextElement = _restoreTableSelection(newTable, newRows-1, 0, false);
    };
    return nextElement;
}

/**
 * Move from the current row/col back to the previous one in the table.
 * @returns {HTML Node | null}          The cell we navigated to
 */
const _doPrevCell = function() {
    const tableElements = _getTableElementsAtSelection();
    const table = tableElements['table'];
    const row = tableElements['row'];
    const col = tableElements['col'];
    const cols = tableElements['cols'];
    const header = _getSection(table, 'THEAD');
    const inHeader = tableElements['thead'] != null
    const colspan = tableElements['colspan']
    let nextElement = null;
    if (inHeader) {
        if (!colspan && (col > 0)) {
            nextElement = _restoreTableSelection(table, row, col-1, true);
        };
    } else if (col > 0) {
        nextElement = _restoreTableSelection(table, row, col-1, false);
    } else if ((col === 0) && (row > 0)) {
        nextElement = _restoreTableSelection(table, row-1, cols-1, false);
    } else if (header && (col === 0) && (row === 0)) {
        if (!colspan) {
            nextElement = _restoreTableSelection(table, 0, cols-1, true);
        } else {
            nextElement = _restoreTableSelection(table, 0, 0, true);
        };
    };
    return nextElement
}

/********************************************************************************
 * Common private functions
 */

/**
 * Callback into Swift to show a string in the XCode console, like console.log()
 */
const _consoleLog = function(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    _callback(JSON.stringify(messageDict));
};

/**
 * Return the first tag contained in matchNames that the selection is inside of, without encountering one in excludeNames.
 *
 * @return {String}         The nodeName that was found, or an empty string if not found.
 */
const _firstSelectionTagMatching = function(matchNames, excludeNames) {
    const matchingNode = _firstSelectionNodeMatching(matchNames, excludeNames);
    if (matchingNode) {
        return matchingNode.nodeName;
    } else {
        return '';
    }
};

/**
 * Return the first node that the selection is inside of whose nodeName matches matchNames, without encountering one in excludeNames.
 *
 * @return {HTML Element}   The element that was found, or null if not found.
 */
const _firstSelectionNodeMatching = function(matchNames, excludeNames) {
    const sel = document.getSelection();
    if (sel) {
        const focusNode = sel.focusNode
        if (focusNode) {
            const selElement = _findFirstParentElementInNodeNames(focusNode, matchNames, excludeNames);
            if (selElement) {
                return selElement;
            }
        }
    }
    return null;
};

/**
 * Return all of the tags in nodeNames that the selection is inside of.
 *
 * @param   {[String]}  nodeNames   Array of nodeNames to search upward for, starting at selection.
 * @return  {[String]}              Array of nodeNames found.
 */
const _selectionTagsMatching = function(nodeNames) {
    const sel = document.getSelection();
    const tags = [];
    if (sel && sel.focusNode) {
        let selElement = _findFirstParentElementInNodeNames(sel.focusNode, nodeNames);
        while (selElement) {
            tags.push(selElement.nodeName);
            selElement = _findFirstParentElementInNodeNames(selElement.parentNode, nodeNames);
        }
    }
    return tags;
};

/**
 * Return the first node with nodeName within node, doing a depthwise traversal.
 * Will only examine element nodes, not text nodes, so nodeName should not be #text
 *
 * @param   {HTML Node}     node        The node to look inside of for a child with nodeName.
 * @param   {String}        nodeName    The name of the node we are looking for.
 * @return  {HTML Element | null}       The element we found, or null.
 */
const _getFirstChildWithNameWithin = function(node, nodeName) {
    if (node.nodeName === nodeName) {
        return node;
    };
    const children = node.children;
    for (let i=0; i<children.length; i++) {
        return _getFirstChildWithNameWithin(children[i], nodeName);
    };
    return null;
};

/**
 * Return the first node of nodeType within node, doing a depthwise traversal.
 *
 * @param   {HTML Node}     node        The node to look inside of for a child of type nodeType.
 * @param   {String}        nodeType    The type of node we are looking for.
 * @return  {HTML Node | null}          The node we found, or null.
 */
const _getFirstChildOfTypeWithin = function(node, nodeType) {
    if (node.nodeType === nodeType) {
        return node;
    };
    const childNodes = node.childNodes;
    for (let i=0; i<childNodes.length; i++) {
        return _getFirstChildOfTypeWithin(childNodes[i], nodeType);
    };
    return null;
};

/**
 * Return the first node of nodeType within element's next siblings.
 *
 * @param   {HTML Element}  element     The element to start looking at for nextSiblings.
 * @param   {String}        nodeType    The type of node we are looking for.
 * @return  {HTML Node | null}          The node we found, or null.
 */
const _getFirstChildOfTypeAfter = function(element, nodeType) {
    let nextSib = element.nextSibling;
    let firstChildOfType;
    while (nextSib) {
        firstChildOfType = _getFirstChildOfTypeWithin(nextSib, nodeType);
        if (firstChildOfType) {
            nextSib = null;
        } else {
            nextSib = nextSib.nextSibling;
        };
    };
    return firstChildOfType;
};

/**
 * Return the first node of nodeType within element's previous siblings.
 *
 * @param   {HTML Element}  element     The element to start looking at for previousSiblings.
 * @param   {String}        nodeType    The type of node we are looking for.
 * @return  {HTML Node | null}          The node we found, or null.
 */
const _getFirstChildOfTypeBefore = function(element, nodeType) {
    let prevSib = element.previousElementSibling;
    let firstChildOfType;
    while (prevSib) {
        firstChildOfType = _getFirstChildOfTypeWithin(prevSib, nodeType);
        if (firstChildOfType) {
            prevSib = null;
        } else {
            prevSib = prevSib.prevElementSibling;
        };
    };
    return firstChildOfType;
};

/**
 * Return the index of node in its parentNode by counting previousSiblings.
 *
 * @param   {HTML Node}     node        The node to find the index of in its parent.
 * @return  {Int}                       The index of node in its parent's childNodes.
 */
const _childNodeIndex = function(node) {
    let index = 0;
    let prevSib = node.previousSibling;
    while (prevSib) {
        index++;
        prevSib = prevSib.previousSibling;
    }
    return index;
}

/*
 * Return a number that is what is actually specified in the attribute.
 * Since all attributes are strings, using them in raw form can cause weird
 * JavaScript autoconversion issues, especially when adding things to them.
 *
 * @param   {HTML Element}  element     HTML element.
 * @param   {String}        attribute   The name of the attribute.
 * @return  {Number | null}             The value of the attribute if it is actually a number; else null.
 */
const _numberAttribute = function(element, attribute) {
    const number = Number(element.getAttribute(attribute));
    return isNaN(number) ? null : number
};

/**
 * Return the nearest text node to element.
 * Used for deleting element and leaving selection in a reasonable state.
 * If the nearest sibling is a BR, we will replace it with a text node
 * and return that text node.
 *
 * @param   {HTML Element}      element     HTML element.
 * @param   {String}            direction   Either 'BEFORE' or 'AFTER' to identify which way to look for a text node
 * @return  {HTML Text Node | MU.editor}    The text node in the direction, or as fallback, the editor element
 */
const _elementAfterDeleting = function(element, direction) {
    let nearestTextNode;
    if (direction === 'BEFORE') {
        nearestTextNode = _getFirstChildOfTypeBefore(element, Node.TEXT_NODE);
    } else {
        nearestTextNode = _getFirstChildOfTypeAfter(element, Node.TEXT_NODE);
    };
    if (nearestTextNode) {
        return nearestTextNode
    } else {
        const sibling = element.nextSibling ?? element.previousSibling;
        if (sibling && (sibling.nodeName === 'BR')) {
            const newTextNode = document.createTextNode('');
            sibling.replaceWith(newTextNode);
            return newTextNode;
        } else if (sibling) {
            return sibling;
        } else {
            const firstTextNode = _getFirstChildOfTypeWithin(MU.editor, Node.TEXT_NODE);
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
 *
 * @param   {HTML Element}      element     HTML element.
 * @param   {String}            direction   Either 'BEFORE' or 'AFTER' to identify where to put the selection
 */
const _deleteAndResetSelection = function(element, direction) {
    const nextEl = _elementAfterDeleting(element, direction);
    element.parentNode.removeChild(element);
    const sel = document.getSelection();
    sel.removeAllRanges();
    const newRange = document.createRange();
    if (direction === 'BEFORE') {
        newRange.setStart(nextEl, nextEl.textContent.length);
        newRange.setEnd(nextEl, nextEl.textContent.length);
    } else {
        newRange.setStart(nextEl, 0);
        newRange.setEnd(nextEl, 0);
    }
    sel.addRange(newRange);
    _backupSelection();
}

/**
 * Get the element with nodeName at the selection point if one exists.
 *
 * @param   {String}        nodeName    The name of the node we are looking for.
 * @return  {HTML Node | null}          The node we found or null if not found.
 */
const _getElementAtSelection = function(nodeName) {
    const sel = document.getSelection();
    if (sel) {  // Removed check on && isCollapsed
        const node = sel.anchorNode;
        const anchorOffset = sel.anchorOffset;
        if ((node.nodeType === Node.TEXT_NODE) && (sel.isCollapsed)) {
            if (anchorOffset === node.textContent.length) {
                // We have selected the end of a text element, which might be next
                // to an element we're looking for
                const nextSibling = node.nextSibling;
                if (nextSibling && nextSibling.nodeType === Node.ELEMENT_NODE) {
                    return (nextSibling.nodeName === nodeName) ? nextSibling : null;
                };
            };
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            // We selected some element (like <P>) and the child at anchorOffset might be an element we're looking for
            const child = node.childNodes[anchorOffset];
            return (child && child.nodeName === nodeName) ? child : null;
        };
    };
    return null;
};

/**
 * Put the tag around the current selection, or the word if range.collapsed
 * If not in a word or in a non-collapsed range, create an empty element of
 * type tag and select it so that new input begins in that element immediately.
 *
 * @param   {String}            type    The tag name to set; e.g., 'B'.
 * @param   {HTML Selection}    sel     The current selection.
 */
const _setTag = function(type, sel) {
    const range = sel.getRangeAt(0).cloneRange();
    const el = document.createElement(type);
    const wordRange = _wordRangeAtCaret();
    const startNewTag = range.collapsed && !wordRange;
    const tagWord = range.collapsed && wordRange;
    const newRange = document.createRange();
    // In all cases, el is the new element with nodeName type and range will have
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
        const emptyTextNode = document.createTextNode('\u200B');
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
    _backupSelection();
    // Check if the insertion left an empty element preceding or following
    // the inserted el. Unfortunately, when starting/ending the selection at
    // the beginning/end of an element in the multinode selection - for example:
    //      <p><b>|Hello</b> wo|rld<p>
    // We end up with:
    //      <p><b></b><i><b>Hello</b> wo</i>rld<p>
    // IOW, we end up with a blank sibling to the new <i> element. It doesn't
    // hurt anything, but it's annoying as hell. So the following code checks
    // for it and removes it.
    const prevSib = el.previousSibling;
    if (prevSib && (prevSib.nodeType != Node.TEXT_NODE)) {
        const innerHTML = prevSib.innerHTML;
        if (!innerHTML || (innerHTML.length == 0)) {
            prevSib.parentNode.removeChild(prevSib);
        };
    };
    const nextSib = el.nextSibling;
    if (nextSib && (nextSib.nodeType != Node.TEXT_NODE)) {
        const innerHTML = nextSib.innerHTML;
        if (!innerHTML || (innerHTML.length == 0)) {
            nextSib.parentNode.removeChild(nextSib);
        };
    };
};

/**
 * When selection is collapsed and in or next to a word, return the range
 * surrounding the word.
 *
 * @return  {HTML Range | null}    The range that surrounds the word the selection is in; else, null.
 */
const _wordRangeAtCaret = function() {
    const sel = document.getSelection();
    if ((!sel) || (sel.rangeCount === 0) || (!sel.isCollapsed)) { return null };
    const range = sel.getRangeAt(0).cloneRange();
    if (range.startContainer.nodeType !== Node.TEXT_NODE) { return null };
    // Select the word in the selNode
    let startOffset = range.startOffset;
    let endOffset = range.endOffset;
    const selNodeText = range.startContainer.textContent;
    while ((startOffset > 0) && !_isWhiteSpace(selNodeText[startOffset - 1])) {
        startOffset -= 1;
    }
    while ((endOffset < selNodeText.length) && !_isWhiteSpace(selNodeText[endOffset]))  {
        endOffset += 1;
    }
    // If both startOffset and endOffset have moved from the originals in range,
    // then the selection/caret is inside of a word, not on the ends of one
    if ((startOffset < range.startOffset) && (endOffset > range.endOffset)) {
        const wordRange = document.createRange();
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
 *
 * @param   {HTML Element}      oldElement      The element we are removing the tag from.
 * @param   {HTML Selection}    sel             The current selection.
 */
const _unsetTag = function(oldElement, sel) {
    const oldRange = sel.getRangeAt(0).cloneRange();
    // Note: I thought cloneRange() does copy by value.
    // Per https://developer.mozilla.org/en-us/docs/Web/API/Range/cloneRange...
    //   The returned clone is copied by value, not reference, so a change in either Range
    //   does not affect the other.
    // But this doesn't seem to be true in practice. In practice, oldRange properties get
    // changed after we do replaceWith below. We need to hold onto the values explicitly
    // so we can assign them properly to the new range after unsetting the tag.
    const oldStartContainer = oldRange.startContainer;
    const oldStartOffset = oldRange.startOffset;
    const oldEndContainer = oldRange.endContainer;
    const oldEndOffset = oldRange.endOffset;
    // Hold onto the parentNode
    const oldParentNode = oldElement.parentNode;
    //
    // TODO: Deal with turning off a tag at at the end of a word; for example,
    // type, CTRL-B turns bold on, type, then CTRL-B turns it off, but what was
    // bolded stays bolded.
    //
    // Get a newElement from the innerHTML of the oldElement
    // Start by tracking the index of oldElement in oldParentNode's childNodes,
    // so we know what element to select when we are done. The original oldElement
    // will be replaced with template.content derived from oldElement's innerHTML.
    const childNodeIndex = _childNodeIndex(oldElement);
    const template = document.createElement('template');
    template.innerHTML = oldElement.innerHTML;
    const newElement = template.content;
    oldElement.replaceWith(newElement);
    const elementToSelect = oldParentNode.childNodes[childNodeIndex];
    const offsetToSelect = oldStartOffset;
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
    let range, startContainer, startOffset, endContainer, endOffset;
    const newStartContainer = _firstChildMatchingContainer(oldParentNode, oldStartContainer);
    if (newStartContainer) {
        startContainer = newStartContainer;
        startOffset = oldStartOffset;
    } else {
        //_consoleLog("selecting start");
        // Make the best choice for startContainer when we have removed everything from a list.
        startContainer = elementToSelect;
        startOffset = offsetToSelect;
    }
    const newEndContainer = _firstChildMatchingContainer(oldParentNode, oldEndContainer);
    if (newEndContainer) {
        endContainer = newEndContainer;
        endOffset = oldEndOffset;
    } else {
        //_consoleLog("selecting end");
        // Make the best choice for endContainer when we have removed everything from a list.
        endContainer = elementToSelect;
        endOffset = offsetToSelect;
    };
    // With the new range properties sorted out, create the new range and reset the selection
    range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    sel.removeAllRanges();
    sel.addRange(range);
};

/**
 * Given an element with a tag, replace its tag with the new nodeName.
 *
 * @param   {HTML Element}  element     The element for which we are replacing the tag.
 * @param   {String}        nodeName    The type of element we want; e.g., 'B'.
 *
 */
const _replaceTag = function(oldElement, nodeName) {
    const sel = document.getSelection();
    const oldParentNode = oldElement.parentNode;
    const oldRange = sel.getRangeAt(0).cloneRange();
    const oldStartContainer = oldRange.startContainer;
    const oldStartOffset = oldRange.startOffset;
    const oldEndContainer = oldRange.endContainer;
    const oldEndOffset = oldRange.endOffset;
    let newElement;
    if (nodeName) {
        newElement = document.createElement(nodeName);
        newElement.innerHTML = oldElement.innerHTML;
    } else {
        newElement = document.createTextNode(oldElement.innerHTML)
    }
    oldElement.replaceWith(newElement);
    let startContainer, startOffset, endContainer, endOffset;
    const newStartContainer = _firstChildMatchingContainer(oldParentNode, oldStartContainer);
    if (newStartContainer) {
        startContainer = newStartContainer;
        startOffset = oldStartOffset;
    } else {
        startContainer = newElement;
        startOffset = 0;
    }
    const newEndContainer = _firstChildMatchingContainer(oldParentNode, oldEndContainer);
    if (newEndContainer) {
        endContainer = newEndContainer;
        endOffset = oldEndOffset;
    } else {
        endContainer = newElement;
        endOffset = 0;
    };
    // With the new range properties sorted out, create the new range and reset the selection
    const range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    sel.removeAllRanges();
    sel.addRange(range);
    return newElement;
};

/**
 * Return the count of the element's children that have the nodeName.
 *
 * @param   {HTML Element}  element     The element for which we are replacing the tag.
 * @param   {String}        nodeName     The type of element we want; e.g., 'B'.
 */
const _childrenWithNodeNameCount = function(element, nodeName) {
    let count = 0;
    const children = element.children;
    for (let i=0; i<children.length; i++) {
        if (children[i].nodeName === nodeName) { count++ };
    }
    return count;
}

/**
 * Find the first child of element whose textContent matches the container passed-in.
 *
 * @param   {HTML Element}      element     The element for which we are replacing the tag.
 * @param   {HTML Text Node}    container   The text node we are trying to match.
 * @return  {HTML Text Node | null}         The text node whose textContent matches container's; else null.
 */
const _firstChildMatchingContainer = function(element, container) {
    // For our purposes here, container is always a #text node.
    const childNodes = element.childNodes;    // Include text nodes and comment nodes
    for (let i=0; i<childNodes.length; i++) {
        let node = childNodes[i];
        if (node.nodeType === container.nodeType) {
            if (node.textContent === container.textContent) {
                return node;
            }
        } else {
            let child = _firstChildMatchingContainer(node, container);
            if (child) {
                return child;
            }
        }
    }
    return null;
}

/**
 * Return the first child within element that is a textNode using depth-first traversal.
 *
 * @param   {HTML Element}      element     The element in which we are looking for a text node.
 */
const _firstTextNodeChild = function(element) {
    const childNodes = element.childNodes;
    for (let i=0; i<childNodes.length; i++) {
        let node = childNodes[i];
        if (node.nodeType === Node.TEXT_NODE) {
            return node;
        };
    };
    return null;
};

/**
 * Recursively search parent elements to find the first one included in matchNames
 * without ever encountering one in excludeNames. Note that excludeNames may be null,
 * in which case will just match. Return null if any element in excludeNames is
 * encountered. If node is a TEXT_NODE, then start with its parent; else, just start
 * with node to find a match.
 *
 * @param   {HTML Node}     node            The node to look upward from to find a parent.
 * @param   {[String]}      matchNames      Array of tags/nodeNames that we are searching for.
 * @param   {[String]}      excludeNames    Array or tags/nodeNames that will abort the search.
 */
const _findFirstParentElementInNodeNames = function(node, matchNames, excludeNames) {
    if (!node) { return null };
    let element;
    if (node.nodeType === Node.TEXT_NODE) {
        element = node.parentElement;
    } else {
        element = node;
    };
    const nodeName = element.nodeName;
    if (excludeNames && excludeNames.includes(nodeName)) {
        return null;
    } else if (matchNames.includes(nodeName)) {
        return element;
    } else {
        return _findFirstParentElementInNodeNames(element.parentElement, matchNames, excludeNames);
    };
};

/********************************************************************************
 * Unused?
 * TODO - Remove
 */

MU.setFontSize = function(size) {
    MU.editor.style.fontSize = size;
};

MU.setBackgroundColor = function(color) {
    MU.editor.style.backgroundColor = color;
};

MU.setHeight = function(size) {
    MU.editor.style.height = size;
};

MU.customAction = function(action) {
    let messageDict = {
        'messageType' : 'action',
        'action' : action
    }
    _callback(JSON.stringify(messageDict));
};

/// Returns the cursor position relative to its current position onscreen.
/// Can be negative if it is above what is visible
MU.getRelativeCaretYPosition = function() {
    let y = 0;
    const sel = document.getSelection();
    if (sel.rangeCount) {
        const range = sel.getRangeAt(0);
        const needsWorkAround = (range.startOffset == 0);
        /* Removing fixes bug when node name other than 'div' */
        // && range.startContainer.nodeName.toLowerCase() == 'div');
        if (needsWorkAround) {
            y = range.startContainer.offsetTop - window.pageYOffset;
        } else {
            if (range.getClientRects) {
                const rects = range.getClientRects();
                if (rects.length > 0) {
                    y = rects[0].top;
                };
            };
        };
    };
    return y;
};

/// Looks specifically for a Range selection and not a Caret selection
MU.rangeSelectionExists = function() {
    //!! coerces a null to bool
    const sel = document.getSelection();
    if (sel && sel.type == 'Range') {
        return true;
    }
    return false;
};

/// Return the first tag the selection is inside of
MU.selectionTag = function() {
    const sel = document.getSelection();
    if (sel) {
        if (sel.type === 'None') {
            return '';
        } else {    // sel.type will be Caret or Range
            const focusNode = sel.focusNode;
            if (focusNode) {
                const selElement = focusNode.parentElement;
                if (selElement) {
                    return selElement.nodeName;
                }
            }
        }
    }
    return '';
};

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
    _restoreSelection();
    document.execCommand('styleWithCSS', null, true);
    document.execCommand('foreColor', false, color);
    document.execCommand('styleWithCSS', null, false);
};

MU.setTextBackgroundColor = function(color) {
    _restoreSelection();
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

/********************************************************************************
 * This is so pathetic, I cannot believe I am doing it.
 * But, wherever the / shows up in JavaScript, XCode messes
 * up all subsequent formatting and it becomes pretty unbearable
 * to deal with the indentation it forces on you.
 * So, I'm putting the only methods where I divide at the bottom of the
 * file and using these methods rather than inlining above.
 */

/**
 * Return the scale as a percentage based on naturalWidth.
 * The implicit assumption here is that width and height are scaled the same.
 *
 * @param   {HTML Image Element}    The image we are finding the scale for.
 * @return  {Number | null}         The scale as a percentage, e.g., 80.
 */
const _imgScale = function(element) {
    const width = _numberAttribute(element, 'width')
    if (width) {
        return 100 * width / element.naturalWidth;
    } else {
        return null;
    }
}

/**
 * Return percent of int; e.g., 80 percent of 10 is 8.
 *
 * @param   {Number}    percent     The percentage to calculate.
 * @param   {Int}       int         The number to find percentage of.
 * @return  {Number}                The result.
 */
const _percentInt = function(percent, int) {
    return int * percent / 100;
}


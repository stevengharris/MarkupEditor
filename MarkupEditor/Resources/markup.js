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
//MARK: Bootstrapping

const MU = {};

/**
 * The editor element contains the HTML being edited
 */
MU.editor = document.getElementById('editor');

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

/**
 * The 'ready' callback lets Swift know the editor and this js is properly loaded.
 *
 * Note for history, replaced window.onload with this eventListener.
 */
window.addEventListener('load', function () {
    undoer.enable();
    _callback('ready');
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
 */
class MUError {
    static BackupNullRange = new MUError('BackupNullRange', 'Attempt to back up a null range.', null, false);
    static RestoreNullRange = new MUError('RestoreNullRange', 'Attempt to restore a null range.', null, false);
    static CantUndoListEnter = new MUError('CantUndoListEnter', 'Child node could not be found in childNodeIndices.');
    static CantInsertHtml = new MUError('CantInsertHtml', 'Top-level element could not be found from selection point.');
    static CantInsertInList = new MUError('CantInsertInList', 'Selection prior to insertList is not collapsed inside of a TEXT_NODE.');
    static CantFindElement = new MUError('CantFindElement', 'The element id could not be found.', null, false);
    static CantFindContainer = new MUError('CantFindContainer', 'The startContainer or endContainer for a range could not be found.', null, false);
    static InvalidFillEmpty = new MUError('InvalidFillEmpty', 'The node was not an ELEMENT_NODE or was not empty.');
    static InvalidJoinNodes = new MUError('InvalidJoinNodes', 'The nodes to join did not conform to expectations.');
    static InvalidSplitTextNode = new MUError('InvalidSplitTextNode', 'Node passed to _splitTextNode must be a TEXT_NODE.');
    static InvalidSplitTextRoot = new MUError('InvalidSplitTextRoot', 'Root name passed to _splitTextNode was not a parent of textNode.');
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
            _focusOn(MU.editor).then(_callback('undoSet'));
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
     * Enable the undoer by making it part of the document body.
     */
    enable() {
        document.body.appendChild(this._ctrl);
    }
    
    /**
     * Pushes a new undoable event. Adds to the browser's native undo/redo stack.
     *
     * Note: Caller needs to handle backing up selection before call and restoring
     * it afterward.
     *
     * @param {T} data the data for this undo event
     * @param {!Node=} parent to add to, uses document.body by default
     */
    push(data) {
        // Get the nextID, splice it along with the data into this._stack, and then update the
        // contents of this._ctrl so that it pushes the change to nextID onto the undo stack.
        const nextID = this._depth + 1;
        this._stack.splice(nextID, this._stack.length - nextID, data);
        this._duringUpdate = true;
        this._ctrl.style.visibility = null;
        // Avoid letting the MarkupEditor know about the focus-blur dance going on with this._ctrl
        // When MU.editor gets the focus event, it will always reset so other focus events are not muted.
        muteFocusBlur();
        _focusOn(this._ctrl).then( () => {
            document.execCommand('selectAll');
            document.execCommand('insertText', false, nextID);
            this._duringUpdate = false;
            this._ctrl.style.visibility = 'hidden';
        });
    };
    
    testUndo() {
        _undoOperation(this._stack[this._depth]);
    };
    
    testRedo() {
        _redoOperation(this._stack[this._depth]);
        this._setUndoIndex(this._depth - 1);
    };

};

/********************************************************************************
 * Undo/Redo
 */
//MARK: Undo/Redo

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
 * when operation is 'indent', we undo an indent by executing MU.outdent.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _undoOperation = function(undoerData) {
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (operation) {
        case 'pasteHTML':
            _undoPasteHTML(undoerData);
            break;
        case 'format':
            _undoToggleFormat(undoerData);
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
            MU.outdent(false);
            _backupSelection();
            break;
        case 'outdent':
            _restoreSelection();
            MU.indent(false);
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
        case 'listEnter':
            _undoListEnter(undoerData);
            break;
        case 'enter':
            _undoEnter(undoerData);
            break;
        default:
            _consoleLog('Error: Unknown undoOperation ' + undoerData.operation);
    };
};

/**
 * Redo the operation identified in undoerData. So, for example,
 * when operation is 'indent', we redo an indent by executing MU.indent.
 *
 * @param {Object}  undoerData  The undoerData instance created at push time.
 */
const _redoOperation = function(undoerData) {
    const operation = undoerData.operation;
    const range = undoerData.range;
    const data = undoerData.data;
    switch (undoerData.operation) {
        case 'pasteHTML':
            _redoPasteHTML(undoerData);
            break;
        case 'format':
            _redoToggleFormat(undoerData);
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
            MU.indent(false);
            _backupSelection();
            break;
        case 'outdent':
            _restoreSelection();
            MU.outdent(false);
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
        case 'listEnter':
            _doListEnter(false, undoerData);
            break;
        case 'enter':
            _doEnter(false);
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
 * Return a promise that delays focusing on a target.
 *
 * The delay seems to be required by WebKit because focus doesn't happen
 * properly when blur is followed too closely by focus.
 *
 * Experimentation shows that a delay of 20 prevents the caret from disappearing,
 * particularly for _toggleFormat. Not sure how reproducible it is or if there is
 * a determinate way to do it, as this just seems like a hack.
 */
const _focusOn = function(target, delay=20) {
    return new Promise((resolve, reject) => {
        window.setTimeout(function() {
            target.focus({ preventScroll:true });
            resolve();
        }, delay);
    });
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

/********************************************************************************
 * Event Listeners
 */
//MARK: Event Listeners

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
 *
 * Be aware that while the the keydown event is always received for Shift, Meta, Alt, and Control,
 * the accompanying printable character hotkey keydown event is not received at all when it is
 * mapped (and enabled) on the Swift side to a UIKeyCommand in a menu.
 */
let _hotKeyDown = {};
const keyModifiers = ['Shift', 'Meta', 'Alt', 'Control'];
const _trackHotKeyDown = function(ev) {
    const key = ev.key;
    if (keyModifiers.includes(key)) { return };     // If not pressing one of the modifiers, nothing to do
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
 *
 * Whenever we do special handling of keystrokes, we also have to deal with
 * undo.
 *
 * Note that when hotkeys are identified as part of menus and *are not disabled*,
 * the keydown is never received here. For example, when Meta+] is a hotkey for
 * indenting, then we receive keydown for Meta, but not for ] while Meta is down.
 * Similarly, if Meta+[ is a hotkey for outdenting, but it is disabled because
 * we are at the leftmost margin, then it *is* received here. Thus, the logic here
 * only executes when the corresponding hot-keys are not defined or are disabled.
 * Also note that Tab is still received and handled here, never on the Swift side.
 */
MU.editor.addEventListener('keydown', function(ev) {
    const key = ev.key;
    switch (key) {
        case 'Enter':
            // Seems super easy to get repeat Enter events, which I am declaring to
            // be non-useful to avoid expensive processing in lists, etc.
            if (ev.repeat) {
                ev.preventDefault();
                return;
            }
            const sel = document.getSelection()
            const selNode = (sel) ? sel.anchorNode : null;
            if (!selNode) { return };
            const inList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
            if ((inList && _doListEnter()) || (!inList && _doEnter())) {
                ev.preventDefault();
            };
            break;
        case 'Tab':
            ev.preventDefault();
            if (_keyModified('Shift', 'Tab')) {
                _doPrevCell();
            } else {
                _doNextCell();
            };
            break;
    };
});

/**
 * Handle the Enter key to avoid <div> being inserted instead of <p>
 *
 * @returns {HTML Paragraph Element || null}    The newly created P to preventDefault handling; else, null.
 */
const _doEnter = function(undoable=true) {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingRange = sel.getRangeAt(0).cloneRange();
    const selectionIsText = selNode.nodeType === Node.TEXT_NODE;
    const selectionAtEnd = existingRange.endOffset === selNode.textContent.length;
    const nextSiblingIsEmpty = (!selNode.nextSibling) || _isEmpty(selNode.nextSibling);
    if (selectionIsText && selectionAtEnd && nextSiblingIsEmpty) {
        // We are at the end of the last text node in some element, so we want to
        // create a new <P> to keep typing. Note this means we get <p> when hitting return
        // at the end of, say, <H3>. I believe this is the "expected" behavior.
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
        if (undoable) {
            _backupSelection();
            const undoerData = _undoerData('enter');
            undoer.push(undoerData);
            _restoreSelection();
        }
        _callback('input');
        return p;   // To preventDefault() on Enter
    };
    return null;    // Let the MarkupWKWebView do its normal thing
}

/**
 * Undo Enter that was handled by _doEnter.
 *
 * By definition, _doEnter only preventsDefault when we are not in a list,
 * the selection is collapsed, and we are at the end of a styled element.
 * The behavior then always inserts a new paragraph. So, we restore the
 * selection from the undoerData, find the paragraph and delete it, restoring
 * the selection to the text element before it.
 */
const _undoEnter = function(undoerData) {
    _restoreUndoerRange(undoerData);
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingP = _findFirstParentElementInNodeNames(selNode, ['P'])
    if (!existingP) { return null };
    _deleteAndResetSelection(existingP, 'BEFORE');
};

/**
 * Monitor certain keyup events that follow actions that mess up simple HTML formatting.
 * Clean up formatting if needed.
 */
MU.editor.addEventListener('keyup', function(ev) {
    const key = ev.key;
    if ((key === 'Backspace') || (key === 'Delete')) {
        _cleanUpSpans();
        _cleanUpAttributes('style');
    };
});

/**
 * Prevent all default paste events. Paste is invoked from the Swift side.
 */
MU.editor.addEventListener('paste', function(ev) {
    ev.preventDefault();
});

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
    const fragment = _patchPasteHTML(html);     // Remove all the cruft first
    const minimalHTML = _minimalHTML(fragment);
    _pasteHTML(minimalHTML);
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
            elements = div.getElementsByTagName('A');
            element = (elements.length > 0) ? elements[0] : null;
        };
    };
};

/**
 * Do a custom paste operation of html.
 */
MU.pasteHTML = function(html) {
    _pasteHTML(html);
}

const _pasteHTML = function(html, oldUndoerData, undoable=true) {
    const redoing = !undoable && (oldUndoerData !== null);
    let sel = document.getSelection();
    let anchorNode = (sel) ? sel.anchorNode : null;
    if (!anchorNode) {
        MUError.NoSelection.callback();
        return null;
    };
    let focusNode = sel.focusNode;
    let selRange = sel.getRangeAt(0).cloneRange();
    // If sel is not collapsed, delete the entire selection and reset before continuing.
    // Track the deletedFragment.
    let deletedFragment;
    if (!sel.isCollapsed) {
        deletedFragment = selRange.extractContents();
        if (redoing) {
            oldUndoerData.data.deletedFragment = deletedFragment;
        };
        sel = document.getSelection();
        anchorNode = sel.anchorNode;
        focusNode = sel.focusNode;
        selRange = sel.getRangeAt(0).cloneRange();
        // At this point, sel is collapsed and the document contents are the same as if we had
        // hit Backspace (but not paste yet) on the original non-collapsed selection.
        //
        // DEBUGGING TIP:
        // By executing an 'input' callback and returning true at this point, we can debug the
        // result ensure it is the same as hitting Backspace.
        //_callback('input');
        //return true;
    };
    const newElement = _patchPasteHTML(html)
    const anchorIsElement = anchorNode.nodeType === Node.ELEMENT_NODE;
    const firstChildIsElement = newElement.firstChild && (newElement.firstChild.nodeType === Node.ELEMENT_NODE);
    const anchorIsEmpty = _isEmpty(anchorNode);
    let pasteRange = selRange.cloneRange();
    let newSelRange, rootName, replacedEmpty;
    if (anchorIsElement && firstChildIsElement && anchorIsEmpty) {
        // We are in an empty paragraph, typically, like <p><br></p>. Replace it with the newElement
        // manually by replacing the anchor with the firstChild, followed by all of its siblings.
        // Unfortunately, we have no way to know if we did this on undo unless we track it in
        // undoerData, which we do by placing the anchorNode.nodeName in replacedEmpty.
        replacedEmpty = anchorNode.nodeName;
        let offset = 0;
        let lastChild = newElement.firstChild;
        let nextSib = lastChild.nextSibling;
        const beforeTarget = anchorNode.nextElementSibling;
        anchorNode.replaceWith(lastChild);
        // Now we need put the rest of the newElement fragment in as siblings,
        // tracking lastChild as we go thru them.
        while (nextSib) {
            lastChild = nextSib;
            beforeTarget.parentNode.insertBefore(nextSib, beforeTarget);
            nextSib = newElement.firstChild;
        };
        newSelRange = document.createRange();
        if (lastChild && (lastChild.nodeType === Node.TEXT_NODE)) {
            offset = lastChild.textContent.length;
        } else if (lastChild && (lastChild.nodeType === Node.ELEMENT_NODE)) {
            offset = lastChild.childNodes.length;
        };
        newSelRange.setStart(lastChild, offset);
        newSelRange.setEnd(lastChild, offset);
        pasteRange.setEnd(lastChild, offset);
        rootName = null;
    } else {
        const insertResults = _insertHTML(newElement);
        if (insertResults) {
            pasteRange = insertResults.insertedRange;
            rootName = insertResults.rootName;
        } else {
            return null;        // Something went wrong in insertHTML, so let default happen.
        }
        replacedEmpty = null;
        newSelRange = document.getSelection().getRangeAt(0);
    };
    // As we patch up the results of pasting later, the offsets in the undoerData.range get
    // set to zero, even tho the startContainer and endContainer remain valid. We hold onto
    // them separately in undoerData so we can restore them later.
    const startOffset = pasteRange.startOffset;
    const endOffset = pasteRange.endOffset;
    if (redoing) {
        oldUndoerData.range = pasteRange;
        oldUndoerData.data.rootName = rootName;
        oldUndoerData.data.replacedEmpty = replacedEmpty;
        //_consoleLog(_rangeString(pasteRange, "redo"));
    }
    sel.removeAllRanges();
    sel.addRange(newSelRange);
    _backupSelection();
    if (undoable) {
        // html - What was pasted, probably contains spans, styles and other cruft
        // deletedFragment - What (if anything) we deleted before pasting
        // rootName - The name of the node we splitText up to, or null if we didn't splitText
        // replacedEmpty - The name of the empty node we replaced, or null if we didn't
        // pasteRange - (saved as undoerData.range) Range that contains what we pasted
        //_consoleLog(_rangeString(pasteRange, "do"));
        const undoerData = _undoerData('pasteHTML', {html: html, deletedFragment: deletedFragment, rootName: rootName, replacedEmpty: replacedEmpty}, pasteRange);
        undoer.push(undoerData);
    }
    _callback('input');
    return true;
};

/**
 * Patch html by removing all of the spans, etc, so that a template created from it
 * is "clean" by MarkupEditor standards.
 */
const _patchPasteHTML = function(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    const element = template.content;
    _cleanUpSpansWithin(element);
    _cleanUpAttributesWithin('style', element);
    _cleanUpAttributesWithin('class', element);
    _cleanUpMetas(element);
    _cleanUpBRs(element);
    _cleanUpPREs(element);
    _cleanUpAliases(element);
    return element;
};

/**
 * Insert the fragment at the current selection point.
 *
 * Return a range containing the fragment that was inserted and whether the selection
 * was split into multiple elements using _splitTextNode. If so, then on undo, we
 * can tell whether we should unsplit them.
 */
const _insertHTML = function(fragment) {
    //_consoleLog("* _insertHTML")
    let sel = document.getSelection();
    let anchorNode = (sel) ? sel.anchorNode : null;
    if (!anchorNode) {
        MUError.NoSelection.callback();
        return null;
    };
    let selRange = sel.getRangeAt(0);
    let direction = null;
    // Remove any empty leading or trailing children and identify the direction to
    // reset selection afterward. If we deleted a leading fragment because it was
    // empty, this indicates we want the selection at the beginning of trailingText
    // after we splitTextNode (direction='BEFORE'); else, we will put it at the end
    // of the anchorNode (direction='AFTER'). If direction is not null, then we will
    // force flow thru splitTextNode.
    let firstFragEl = (fragment.firstChild && (fragment.firstChild.nodeType === Node.ELEMENT_NODE)) ? fragment.firstChild : null;
    if (firstFragEl && _isEmpty(firstFragEl)) {
        fragment.removeChild(firstFragEl);
        firstFragEl = (fragment.firstChild && (fragment.firstChild.nodeType === Node.ELEMENT_NODE)) ? fragment.firstChild : null;
        direction = 'AFTER';
    }
    let lastFragEl = (fragment.lastChild && (fragment.lastChild.nodeType === Node.ELEMENT_NODE)) ? fragment.lastChild : null;
    if (lastFragEl && _isEmpty(lastFragEl)) {
        fragment.removeChild(lastFragEl);
        direction = direction || 'BEFORE';  // Only reset if we didn't already set
    }
    // We will need to define a new range for selection and track the insertedRange
    let newSelRange = document.createRange();       // Collapsed at the end of the fragment
    const insertedRange = document.createRange();   // Spanning the fragment
    // Handle specially if fragment is "simple" (i.e., has noChildElements or noTopLevelChildren).
    // TODO: Could just use noTopLevelChildren
    // However, not sure if this is really right in cases with things like lists included, which
    // don't work properly now anyway.
    const noChildElements = fragment.childElementCount === 0;
    let noTopLevelChildren = true;
    if (!noChildElements) {
        const fragChildren = fragment.children;
        for (let i=0; i < fragChildren.length; i++) {
            if (_topLevelTags.includes(fragChildren[i].nodeName)) {
                noTopLevelChildren = false;
                break;
            };
        };
    };
    if ((direction === null) && (noChildElements || noTopLevelChildren)) {
        //_consoleLog("Simple")
        const firstFragChild = fragment.firstChild;
        const lastFragChild = fragment.lastChild;
        const shouldJoin = _isTextNode(anchorNode) && !_isTextNode(firstFragChild) && (anchorNode.parentNode.nodeName === firstFragChild.nodeName)
        if (shouldJoin) {
            //_consoleLog(" Joining")
            // Fragment is merged in with anchorNode
            const originalAnchorLength = anchorNode.textContent.length;
            _joinNodes(anchorNode.parentNode, firstFragChild, anchorNode.parentNode.nodeName);
            insertedRange.setStart(anchorNode, originalAnchorLength);
            insertedRange.setEnd(anchorNode, anchorNode.textContent.length);
            newSelRange.setStart(anchorNode, anchorNode.textContent.length);
            newSelRange.setEnd(anchorNode, anchorNode.textContent.length);
        } else {
            //_consoleLog(" Inserting")
            // Fragment becomes anchorNode's nextSibling, selection set to end
            selRange.insertNode(fragment);
            _stripZeroWidthChars(anchorNode.parentNode);
            insertedRange.setStart(firstFragChild, 0);
            if (_isTextNode(lastFragChild)) {
                newSelRange.setStart(lastFragChild, lastFragChild.textContent.length);
                newSelRange.setEnd(lastFragChild, lastFragChild.textContent.length);
                insertedRange.setEnd(lastFragChild, lastFragChild.textContent.length);
            } else {
                newSelRange.setStart(lastFragChild, lastFragChild.childNodes.length);
                newSelRange.setEnd(lastFragChild, lastFragChild.childNodes.length);
                insertedRange.setEnd(lastFragChild, lastFragChild.childNodes.length);
            };
        };
        sel.removeAllRanges();
        sel.addRange(newSelRange);
        //_consoleLog("* Done _insertHTML (simple)")
        return {insertedRange: insertedRange, rootName: null};
    };
    // Selection is within a text node that needs to be split and then merged with the fragment.
    // See _splitTextNode comments, but it recreates the node heirarchy at the selection up
    // to and including the topLevelNode, leaving the selection set in the direction specified.
    // Like splitText, _splitTextNode returns the trailingText and leaves anchorNode containing
    // the textNode before the selection.
    const topLevelNode = _findFirstParentElementInNodeNames(anchorNode, _topLevelTags);
    if (!topLevelNode) {
        MUError.CantInsertHtml.callback();
        return null;
    };
    //_consoleLog(" Complex")
    const rootName = topLevelNode.nodeName;
    let trailingText = _splitTextNode(anchorNode, selRange.startOffset, rootName, direction);
    // Regardless of what we do now to insert the fragment, the trailingText and anchorNode define
    // the span of the fragment which will sit between those points. However, if the trailingText
    // is empty, then we won't be able to set selection properly into it. In that case,
    // we will adjust it later after we insert the fragment.
    insertedRange.setStart(anchorNode, anchorNode.textContent.length);
    insertedRange.setEnd(trailingText, 0);
    // Now the selection has been split and left at the beginning of trailingText, which is
    // where we generally want to paste the fragment contents.
    // FIRST, insert all of the firstElFrag's childNodes at the end of anchorNode
    // if the nodeNames match. So, for example, if the firstElFrag is
    // <h5 id="h5">ted <i id="i">item</i> 1.</h5>, the "ted <i id="i">item</i> 1."
    // gets put at the end of the anchorNode.
    const anchorNodeParent = anchorNode.parentNode;
    const anchorNodeParentName = anchorNodeParent.nodeName;
    if (firstFragEl && (firstFragEl.nodeName === anchorNodeParentName)) {
        let firstElChild = firstFragEl.firstChild;
        while (firstElChild) {
            anchorNodeParent.appendChild(firstElChild);
            firstElChild = firstFragEl.firstChild;
        };
        fragment.removeChild(firstFragEl);
    };
    // SECOND, all the siblings of firstFragEl need to be added as siblings of anchorNode.parentNode.
    // The siblings start with what is now fragment.firstChild. If the nodeTypes didn't match, then
    // this will be the same as firstFragEl.
    // TODO: Determine if this works properly in a list
    let nextFragSib = fragment.firstChild;
    const existingTopLevelItem = _findFirstParentElementInNodeNames(trailingText, _topLevelTags);
    while (nextFragSib) {
        if (_topLevelTags.includes(nextFragSib.nodeName)) {
            existingTopLevelItem.parentNode.insertBefore(nextFragSib, existingTopLevelItem)
        } else {
            trailingText.parentNode.insertBefore(nextFragSib, trailingText);
        }
        nextFragSib = fragment.firstChild;
    };
    // If trailingText is empty, then we need to insert a <BR> in it so that the selection
    // works properly (similar to how Enter produces a <p><br></p>).
    if (trailingText.length === 0) {
        const trailingTextParent = trailingText.parentNode;
        const modRange = _fillEmpty(trailingTextParent);
        if (modRange) {
            newSelRange = modRange;
        } else {
            newSelRange = document.getSelection().getRangeAt(0);
        };
        insertedRange.setStart(anchorNode, anchorNode.textContent.length);
        insertedRange.setEnd(trailingTextParent, 0);
    } else if (anchorNode.length === 0) {
        const modRange = _fillEmpty(anchorNodeParent);
        if (modRange) {
            newSelRange = modRange;
        } else {
            newSelRange = document.getSelection().getRangeAt(0);
        };
        insertedRange.setStart(anchorNodeParent, 0);
        insertedRange.setEnd(trailingText, 0);
    } else {
        newSelRange.setStart(trailingText, 0);
        newSelRange.setEnd(trailingText, 0);
    };
    sel.removeAllRanges();
    sel.addRange(newSelRange);
    //_consoleLog("* Done _insertHTML")
    return {insertedRange: insertedRange, rootName: rootName}
};

/**
 * Split the textNode at offset, but also split its parents up to and
 * including the parent with name rootName.
 *
 * For example...
 *      <p>Hello <b>bo|ld</b> world</p>
 * when split at the | would result in...
 *      <p>Hello <b>bo</b></p><p><b>ld</b> world</p>
 *
 * Direction identifies whether selection is reset at just BEFORE the
 * offset or AFTER the offset, and is always reset.
 *
 * The behavior here is very much like pressing Enter. There are several
 * cases (Enter and Paste) where I wish I could get the default Enter behavior
 * and then take action afterward. There is no way to create a trusted
 * Enter event from JavaScript, so this is the rough equivalent.
 *
 * Like splitText, return the trailingText (result of textNode.splitText(offset)),
 * and leave textNode as the leadingText after the split. Note, however, unlike
 * splitText, trailingText might be embedded in a new element, not just be
 * a text node in the existing element. The leadingText remains where it was in
 * terms of the document structure, altho it might be empty depending on offset.
 */
const _splitTextNode = function(textNode, offset, rootName=null, direction='AFTER') {
    if (textNode.nodeType !== Node.TEXT_NODE) {
        const error = MUError.InvalidSplitTextNode;
        error.setInfo('Node name was ' + textNode.nodeName);
        error.callback();
        return textNode;    // Seems least problematic
    }
    const rootNode = _findFirstParentElementInNodeNames(textNode, [rootName]);
    if (rootName && !rootNode) {
        const error = MUError.InvalidSplitTextRoot;
        error.setInfo('The rootName was ' + rootName);
        error.callback();
        return textNode;    // Seems least problematic
    }
    // Note that trailingText or leadingText can be empty text nodes when
    // offset is 0 or textNode.textContent.length
    const trailingText = textNode.splitText(offset);
    const leadingText = textNode;   // Use leadingText name for clarity
    if (rootNode) {
        // We want to recreate the node hierarchy up to and including rootNode.
        // Moving up from trailingText, put all the intermediate parents into
        // a newContainer, resulting in a newContainer with nodeName = rootName.
        // To move siblings afterward, track the nextSib of trailingText before
        // putting trailingText in the newContainer. For example,
        // for <p>Hello <b>bo|ld</b> world</p>, nextSib has to be <b> so
        // that we move the " world" after it. In a nested case, like
        // <p>Hello <i><b>bo|ld</b></i> world</p>, it needs to be <i>. OTOH,
        // for <p>Hel|lo <b>bold</b> world<p>, nextSib needs to be "Hel",
        // and sibs include <b>bold</b>, and " world".
        let existingContainer = trailingText.parentNode;
        let existingContainerName = existingContainer.nodeName;
        let newContainer = document.createElement(existingContainerName);
        let nextSib = trailingText.nextSibling;
        newContainer.appendChild(trailingText);
        let nestedContainer = newContainer;
        while (existingContainerName !== rootName) {
            nextSib = existingContainer.nextSibling;
            existingContainer = existingContainer.parentNode;
            existingContainerName = existingContainer.nodeName;
            newContainer = document.createElement(existingContainerName);
            newContainer.appendChild(nestedContainer);
            nestedContainer = newContainer;
        };
        // Put the newContainer in the right place.
        rootNode.parentNode.insertBefore(newContainer, rootNode.nextSibling);
        // And then append all of the nextSiblings
        let nextNextSib;
        while (nextSib) {
            nextNextSib = nextSib.nextSibling;
            newContainer.appendChild(nextSib);
            nextSib = nextNextSib;
        };
    };
    const range = document.createRange();
    let rangeContainer, rangeOffset;
    if (direction === 'AFTER') {
        rangeContainer = trailingText;
        rangeOffset = 0;
    } else {
        rangeContainer = leadingText;
        rangeOffset = leadingText.textContent.length;
    }
    range.setStart(rangeContainer, rangeOffset);
    range.setEnd(rangeContainer, rangeOffset);
    const sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    return trailingText;
};

/**
 * Join the parents of leadingNode and trailingNode at their parentNode with name rootName.
 *
 * For example, in <p>Hello <b>bo|ld</b> world</p> when splitTextNode at |, we end up with
 * <p>Hello <b>bo</b></p><p><b>ld</b> world</p>, with the selection anchorNode at
 * <p>Hello <b>bo|</b></p> and the selection focusNode at <p><b>|ld</b> world</p>.
 * If we _joinNodes(anchorNode, focusNode, 'P'), then we end back up with
 * <p>Hello <b>bo|ld</b> world</p>.
 *
 * This is like the _splitTextNode equivalent of normalize() for _splitText.
 *
 * As we move contents from the trailingRoot into the leadingRoot, the selection will remain
 * valid unless we combine text nodes my modifying textContent. In that case, we need to reset
 * the selection. If we just move nodes around using appendChild or insertBefore, the selection
 * remains valid; if it was in the trailingRoot before, when done it will be in the leadingRoot.
 */
const _joinNodes = function(leadingNode, trailingNode, rootName) {
    //_consoleLog("* _joinNodes(" + _textString(leadingNode) + ", " + _textString(trailingNode) + ", " + rootName);
    const leadingRoot = _findFirstParentElementInNodeNames(leadingNode, [rootName]);
    const trailingRoot = _findFirstParentElementInNodeNames(trailingNode, [rootName]);
    // We need to be able to locate leadingRoot and trailingRoot above the leadingNode and trailingNode.
    if (!(leadingRoot && trailingRoot)) {
        const error = MUError.InvalidJoinNodes;
        error.setInfo('Could not join at ' + rootName + ' (leadingRoot: ' + leadingRoot + ', trailingRoot: ' + trailingRoot + ').');
        error.callback();
        return;
    };
    //_consoleLog("  leadingRoot: " + _textString(leadingRoot) + ", trailingRoot: " + _textString(trailingRoot));
    // The lastChild within leadingRoot has to be the same nodeName as the firstChild of trailingRoot.
    // If they are not the same nodeName, then they were not created using splitTextNode or are otherwise
    // violating the assumptions used when joining them. For example, starting with <p><b>bo|ld</b></p>
    // which is then splitTextNode at 'P' into <p><b>bo</b></p><p><b>ld</b></p>, leadingNode will be
    // <b>bo</b> and trailingNode will be <b>ld</b>, and the lastLeadingChild and firstTrailingChild will
    // both be the same 'B' nodeName. However, when starting with <p><i><b>bo|ld</b><i></p> which is then
    // splitTextNode at 'P' into <p><i><b>bo</b></i></p><p><i><b>ld</b></i></p>, leadingNode and trailingNode
    // will be the same as before, but lastLeadingChild will be <i><b>bo</b></i> and firstTrailingChild will
    // be <i><b>ld</b></i>. This is an important distinction because we want to fold the contents of
    // firstTrailingChild into the lastLeadingChild.
    // There is also a case where the leadingRoot is empty, like <p></p>. This happens because we might
    // have deleted a range, leaving an empty paragraph. In this case, we still want to join the nodes, but
    // the lastLeadingChild is null.
    const lastLeadingChild = leadingRoot.lastChild;
    const lastLeadingChildNodeName = (lastLeadingChild) ? lastLeadingChild.nodeName : null;
    const firstTrailingChild = trailingRoot.firstChild;
    const firstTrailingChildNodeName = (firstTrailingChild) ? firstTrailingChild.nodeName : null;
    if (lastLeadingChild && firstTrailingChild && (lastLeadingChildNodeName !== firstTrailingChildNodeName)) {
        const error = MUError.InvalidJoinNodes;
        error.setInfo('Could not join at ' + rootName + ' (lastLeadingChild: ' + lastLeadingChild + ', firstTrailingChild: ' + firstTrailingChild + ').');
        error.callback();
        return;
    }
    // Start by treating firstTrailingChild specially.
    const sel = document.getSelection();
    const range = sel.getRangeAt(0);
    const originalStartContainer = range.startContainer;
    const originalStartOffset = range.startOffset;
    const originalEndContainer = range.endContainer;
    const originalEndOffset = range.endOffset;
    let newStartContainer = originalStartContainer;
    let newStartOffset = originalStartOffset;
    let newEndContainer = originalEndContainer;
    let newEndOffset = originalEndOffset;
    // The next two consts tell us whether the lastLeadingChild needs to replace the startContainer.
    // or endContainer. Exactly how we do it depends on what we encounter.
    const startWithFirstChild = (originalStartContainer === firstTrailingChild) || ((originalStartContainer === trailingRoot) && (originalStartOffset === 0));
    const endWithFirstChild = (originalEndContainer === firstTrailingChild) || ((originalEndContainer === trailingRoot) && (originalEndOffset === 0));
    if (firstTrailingChild.nodeType === Node.TEXT_NODE) {
        // We just have to append text from the firstTrailingChild to the lastLeadingChild
        if (startWithFirstChild) {
            if (lastLeadingChild) {
                newStartContainer = lastLeadingChild;
                newStartOffset = lastLeadingChild.textContent.length + originalStartOffset;
            } else {
                newStartContainer = leadingRoot;
                newStartOffset = 0;
            };
        }
        if (endWithFirstChild) {
            if (lastLeadingChild) {
                newEndContainer = lastLeadingChild;
                newEndOffset = lastLeadingChild.textContent.length + originalEndOffset;
            } else {
                newEndContainer = leadingRoot;
                newEndOffset = originalEndOffset;
            };
        }
        if (lastLeadingChild) {
            lastLeadingChild.textContent = lastLeadingChild.textContent + firstTrailingChild.textContent;
            // Remove the firstTrailingChild so that it's no longer in trailingRoot
            trailingRoot.removeChild(firstTrailingChild);
        } else {
            leadingRoot.appendChild(firstTrailingChild);
        }
    } else if (firstTrailingChild.nodeType === Node.ELEMENT_NODE) {
        // We have some kind of nested elements (like <i><b>Hello</b> world</i> that we need to walk down to find
        // the embedded text element we are going to join to the corresponding lastLeadingChild's nested
        // element. The nesting needs to match (as it will for splitTextNode), or our assumptions have been
        // violated.
        let lastLeadingGrandchild = lastLeadingChild.firstChild;
        let firstTrailingGrandchild = firstTrailingChild.firstChild;
        while (firstTrailingGrandchild) {
            if (lastLeadingGrandchild.nodeName !== firstTrailingGrandchild.nodeName) {
                const error = MU.InvalidJoinNodes;
                error.setInfo('Could not join at ' + rootName + ' (lastLeadingGrandchild: ' + lastLeadingGrandchild + ', firstTrailingGrandchild: ' + firstTrailingGrandchild + ').');
                error.callback();
                return;
            };
            //TODO: This almost certainly doesn't work on triple nested format elements
            if (firstTrailingGrandchild.nodeType === Node.TEXT_NODE) {
                if (startWithFirstChild) {
                    newStartContainer = lastLeadingGrandchild;
                    newStartOffset = lastLeadingGrandchild.textContent.length;
                };
                if (endWithFirstChild) {
                    newEndContainer = lastLeadingGrandchild;
                    newEndOffset = lastLeadingGrandchild.textContent.length;
                };
                lastLeadingGrandchild.textContent = lastLeadingGrandchild.textContent + firstTrailingGrandchild.textContent;
                let trailingSib = firstTrailingGrandchild.parentNode.nextSibling;
                const insertTarget = lastLeadingGrandchild.parentNode.nextSibling;
                while (trailingSib) {
                    lastLeadingGrandchild.parentNode.parentNode.insertBefore(trailingSib, insertTarget);
                    trailingSib = trailingSib.nextSibling;
                }
                firstTrailingGrandchild = null;
            } else {
                lastLeadingGrandchild = lastLeadingGrandchild.firstChild;
                firstTrailingGrandchild = firstTrailingGrandchild.firstChild;
            };
        };
        // Remove the firstTrailingChild so that it's no longer in trailingRoot
        trailingRoot.removeChild(firstTrailingChild);
    };
    // Now we can just appendChild all the childNodes of trailingRoot to leadingRoot.
    // If we joined text together, the original firstTrailingChild was removed.
    // It's theoretically possible that firstTrailingChild was a <br>. If so, we will
    // append here, not previously.
    let trailingChild = trailingRoot.firstChild;
    while (trailingChild) {
        leadingRoot.appendChild(trailingChild);
        trailingChild = trailingRoot.firstChild;
    }
    // Remove the now-empty trailingRoot and patch up the selection
    trailingRoot.parentNode.removeChild(trailingRoot);
    const newSel = document.getSelection();
    const newRange = document.createRange();
    newRange.setStart(newStartContainer, newStartOffset);
    newRange.setEnd(newEndContainer, newEndOffset);
    newSel.removeAllRanges();
    newSel.addRange(newRange);
    //_consoleLog("* Done _joinNodes")
}

/**
 * Fill an empty element with a br and patch up the selection if needed.
 *
 * Return a range that selects the empty element. Selection won't be affected
 * unless the changes to element necessitate it.
 *
 * In cases where element is empty, we cannot select inside of it. For example,
 * <p></p> is valid html, but we cannot set the selection inside of it. Instead,
 * when we want to select inside of it, we have to populate it with a <BR> and
 * then select.
 */
const _fillEmpty = function(element) {
    if (!_isElementNode(element)) {
        MUError.InvalidFillEmpty.callback();
        return null;
    };
    if (!_isEmpty(element) || (element.childNodes.length > 1)) { return null };
    const sel = document.getSelection();
    let resetStart = false;
    let resetEnd = false;
    let startContainer, startOffset, endContainer, endOffset;
    if (sel && (sel.rangeCount > 0)) {
        const range = sel.getRangeAt(0);
        startContainer = range.startContainer;
        startOffset = range.startOffset;
        endContainer = range.endContainer;
        endOffset = range.endOffset;
        resetStart = (element === startContainer) || (element.firstChild === startContainer);
        resetEnd = (element === endContainer) || (element.firstChild === endContainer);
    };
    const br = document.createElement('br');
    if (element.childNodes.length === 1) {
        element.childNodes[0].replaceWith(br);
    } else {
        element.appendChild(br);
    };
    const newRange = document.createRange();
    if (resetStart || resetEnd) {
        if (elementIsStart) {
            newRange.setStart(element, 0);
        } else {
            newRange.setStart(startContainer, startOffset);
        }
        if (elementIsEnd) {
            newRange.setEnd(element, 0);
        } else {
            newRange.setEnd(endContainer, endOffset);
        }
        sel.removeAllRanges();
        sel.addRange(newRange);
    } else {
        newRange.setStart(element, 0);
        newRange.setEnd(element, 0);
    }
    return newRange;
};

const _undoPasteHTML = function(undoerData) {
    // The undoerData contains:
    //  html - What was pasted, probably contains spans, styles and other cruft
    //  deletedFragment - What (if anything) we deleted before pasting
    //  rootName - The name of the node we splitText up to, or null if we didn't splitText
    //  replacedEmpty - The name of the empty node we replaced, or null if we didn't
    //  pasteRange - (saved as undoerData.range) Range that contains what we pasted
    //_consoleLog("* _undoPasteHTML")
    const pasteRange = undoerData.range;
    const rootName = undoerData.data.rootName;
    const replacedEmpty = undoerData.data.replacedEmpty;
    const deletedFragment = undoerData.data.deletedFragment;
    //_consoleLog(_rangeString(pasteRange, "undo"));
    _deleteRange(pasteRange, rootName);
    const sel = document.getSelection();
    let newRange = sel.getRangeAt(0);
    if (replacedEmpty) {
        const newEmptyElement = document.createElement(replacedEmpty);
        const br = document.createElement('br');
        newEmptyElement.appendChild(br);
        const topLevelNode = _findFirstParentElementInNodeNames(newRange.startContainer, _topLevelTags);
        if (topLevelNode) {
            topLevelNode.parentNode.insertBefore(newEmptyElement, topLevelNode.nextSibling);
            newRange.setStart(newEmptyElement, 0);
            newRange.setEnd(newEmptyElement, 0);
            undoerData.range = newRange;
        };
    };
    // At this point, what was pasted-in is gone, and the document looks like if it had
    // never been pasted-in, except for the deletedFragment if there was one.
    if (deletedFragment) {
        // We previously had deleted some selected text when pasting.
        // Re-insert the deletedFragment. This will reset the selection
        // and return a range that surrounds the now-inserted deletedFragment,
        // which is what we want to select when done.
        const insertResults = _insertHTML(deletedFragment);
        if (insertResults) {
            newRange = insertResults.insertedRange;
        };
    };
    sel.removeAllRanges();
    sel.addRange(newRange);
    _backupSelection();
    _callback('input');
};

const _redoPasteHTML = function(undoerData) {
    _restoreUndoerRange(undoerData);
    _pasteHTML(undoerData.data.html, undoerData, false);
};

const _rangeFor = function(node, direction='START') {
    const range = document.createRange();
    let startOffset, endOffset;
    if (direction === 'START') {
        startOffset = 0;
        endOffset = 0;
    } else if (direction === 'END'){
        if (node.nodeType === Node.TEXT_NODE) {
            startOffset = node.textContent.length;
        } else {
            startOffset = node.childNodes.length;
        };
        endOffset = startOffset;
    } else {    // Range across node
        startOffset = 0;
        if (node.nodeType === Node.TEXT_NODE) {
            endOffset = node.textContent.length;
        } else {
            endOffset = node.childNodes.length;
        };
    }
    range.setStart(node, startOffset);
    range.setEnd(node, endOffset);
    return range;
}

/**
 * Delete the range and reset selection if needed.
 *
 * If the selection anchorNode is empty after deleting range, then
 * delete the anchorNode and reset the selection to the nearest sibling,
 * preferring the end of the previousSibling if it exists.
 *
 * If rootName is not null, then it identifies the nodeName that was split
 * up-to when range was inserted. For example, in <p>Hello <b>bo|ld</b> world</p>
 * when split at |, we ended up with <p>Hello <b>bo</b></p><p><b>ld</b> world</p>,
 * and the range would span from the end of <b>bo</b> to the beginning of <b>ld</b>.
 * Then we pasted in some fragment, which we are now deleting. After we delete range,
 * we end up with <p>Hello <b>bo</b></p><p><b>ld</b> world</p> when what we want is
 * <p>Hello <b>bo|ld</b> world</p>. If rootName is specified as 'P', then this
 * tells us we need to combine the P that <b>bo</b> is in with the P that <b>ld</b>
 * is in. This is kind of like the _splitTextNode equivalent of normalize()
 * for _splitText.
 *
 * In all cases, it's important to patch up the range that is passed-in so that it is
 * still valid and represents the selection after deleting the range.
 */
const _deleteRange = function(range, rootName) {
    //_consoleLog("* _deleteRange");
    let leadingNode = range.startContainer;
    let trailingNode = range.endContainer;
    range.deleteContents();
    const sel = document.getSelection();
    const anchorNode = sel.anchorNode;
    let newRange;
    if (anchorNode && _isEmpty(anchorNode)) {
        const prevSib = anchorNode.previousSibling;
        const nextSib = anchorNode.nextSibling;
        const parentNode = anchorNode.parentNode;
        parentNode.removeChild(anchorNode);
        if (prevSib) {
            newRange = _rangeFor(prevSib, 'END');
        } else if (nextSib) {
            newRange = _rangeFor(nextSib, 'START');
        } else {
            newRange = _rangeFor(parentNode, 'START');
        };
    } else {
        newRange = document.createRange();
        newRange.setStart(leadingNode, leadingNode.textContent.length);
        newRange.setEnd(trailingNode, 0);
    };
    range.setStart(newRange.startContainer, newRange.startOffset);
    range.setEnd(newRange.endContainer, newRange.endOffset);
    sel.removeAllRanges();
    sel.addRange(newRange);
    leadingNode = newRange.startContainer;  // because it might have changed
    trailingNode = newRange.endContainer;   // because it might have changed
    if (rootName && (leadingNode !== trailingNode)) {
        _joinNodes(leadingNode, trailingNode, rootName);
        newRange = document.getSelection().getRangeAt(0);
        range.setStart(newRange.startContainer, newRange.startOffset);
        range.setEnd(newRange.endContainer, newRange.endOffset);
        //_consoleLog(_rangeString(range, "after _joinNodes"));
    };
    //_consoleLog("* Done _deleteRange");
};

/********************************************************************************
 * Getting and setting document contents
 */
//MARK: Getting and Setting Document Contents

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
    if (firstChild) {
        const selection = document.getSelection();
        selection.removeAllRanges();
        const range = document.createRange();
        range.setStart(firstChild, 0);
        range.setEnd(firstChild, 0);
        selection.addRange(range);
        _backupSelection();
    } else {
        MU.emptyDocument()
    }
    _focusOn(MU.editor).then(_callback('updateHeight'));
}

const _firstEditorElement = function() {
    const firstTextNode = _getFirstChildOfTypeWithin(MU.editor, Node.TEXT_NODE);
    return firstTextNode ? firstTextNode : MU.editor.firstChild;
};

/**
 * Return a marginally prettier version of the raw editor contents.
 *
 * @return {String}     A string showing the raw HTML with tags, etc.
 */
MU.getPrettyHTML = function() {
    return MU.editor.innerHTML.replace(/<p/g, '\n<p').replace(/<h/g, '\n<h').replace(/<div/g, '\n<div').replace(/<table/g, '\n<table').trim();
};

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
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return };
    const range = sel.getRangeAt(0);
    let tagRange; // startIndices, startOffset, endIndices, endOffset;
    const existingElement = _findFirstParentElementInNodeNames(selNode, [type]);
    const newSelRange = sel.getRangeAt(0);
    const commonAncestor = newSelRange.commonAncestorContainer;
    const ancestor = _findFirstParentElementInNodeNames(commonAncestor, _styleTags);
    const startIndices = _childNodeIndicesByParent(newSelRange.startContainer, ancestor);
    const startOffset = newSelRange.startOffset;
    const endIndices = _childNodeIndicesByParent(newSelRange.endContainer, ancestor);
    const endOffset = newSelRange.endOffset;
    if (existingElement) {
        let newRange;
        const nextNode = existingElement.nextSibling;
        const endOfNode = sel.isCollapsed && (selNode.nodeType === Node.TEXT_NODE) && !(selNode.nextSibling) && (range.endOffset === selNode.textContent.length);
        const emptyNextNode = nextNode && (nextNode.nodeType === Node.TEXT_NODE) && (nextNode.textContent.length === 0);
        const placeholderChar = '\u200B';  // A zero width char (where '\u00A0' would be space)
        if (endOfNode && emptyNextNode && range.collapsed) {
            // We are at the end of a formatted piece of text, with nothing ahead of us.
            // We want to allow continued typing in unformatted text.
            // Append a zero width char and select after it. If we continue to type, text will be unformatted.
            // The downside is that navigation with arrow keys knows there is a character there, but the user
            // cannot see it (as is the case on inserting an empty formatting element like <b></b>. An
            // alternative is to insert a space, which works okay, but would probably be unexpected by a user.
            newRange = document.createRange();
            const emptyTextNode = document.createTextNode(placeholderChar);
            nextNode.parentNode.insertBefore(emptyTextNode, nextNode);
            newRange.setStart(emptyTextNode, 1);
            newRange.setEnd(emptyTextNode, 1);
            sel.removeAllRanges();
            sel.addRange(newRange);
            undoable = false;       // Doesn't make sense to undo this operation
        } else if (!endOfNode) {
            tagRange = _unsetTag(existingElement, sel);
        } else {
            // The existingNode can contain only the placeholderChar, and if so, we need to unset it.
            // This also ensures that undo works properly.
            const textNode = existingElement.firstChild;
            const cleanText = existingElement.textContent.replace(placeholderChar, '');
            if (cleanText.length === 0) {
                textNode.textContent = '';
                newRange = document.createRange();
                newRange.setStart(textNode, 0);
                newRange.setEnd(textNode, 0);
                sel.removeAllRanges();
                sel.addRange(newRange);
                tagRange = _unsetTag(existingElement, sel);
            } else {
                tagRange = _unsetTag(existingElement, sel);
            };
        };
    } else {
        tagRange = _setTag(type, sel);
    };
    _backupSelection();
    if (undoable) {
        // Both _setTag and _unsetTag reset the selection when they're done;
        // however, the selection should be left in a way that undoing is accomplished
        // by just re-executing the _toggleFormat. So, for example, _toggleFormat while
        // selected between characters in a word will toggleFormat for the word, but leave
        // the selection at the same place in that word. Also, toggleFormat when a word
        // has a range selected will leave the same range selected.
        const undoerData = _undoerData('format', {type: type, tagRange: tagRange, ancestor: ancestor, startIndices: startIndices, startOffset: startOffset, endIndices: endIndices, endOffset: endOffset});
        undoer.push(undoerData);
    }
    _callback('input');
    return tagRange;
}

/**
 * Undo of the toggleFormat operation.
 *
 * The tagRange tells us what we need to select before using toggleFormat
 * to undo an earlier toggleFormat operation.
 *
 * The difficult part is restoring the selection across undo/redo/undo.
 * At "do" time, we set the indices and offsets that were present before we
 * perform the operation. So, for example, if we have selected a point in the
 * middle of a word, then the tagRange encompasses the word, while the indices
 * and offsets tell us how to set the selection *before* the operation is
 * performed. For undo and redo, then we select the tag range and when done,
 * we use the indices and offsets to set the selection. This leaves the
 * selection in the place it started before ever "did" the operation. Consider:
 *
 *  <p>Hello <b>bold and <i>ita|lic</i> world</b></p>
 *
 * Now "do" untag of ita|lic. We end up with:
 *
 *  <p>Hello <b>bold and ita|lic world</b></p>
 *
 * The tagRange was returned from the _unsetTag method. It captures
 * the range to be used later in the undo of untag. When performing the untag,
 * we set the undoerData with a tagRange of "italic" *after* the untag.
 * In contract, indices and offsets measured are from <p> to locate <i>ita|lic</i>
 * in the original *before* the untag. When undoing the untag, we are starting from:
 *
 *  <p>Hello <b>bold and ita|lic world</b></p>
 *
 * We set the selection using tagRange and invoke _toggleFormat without pushing
 * anything onto the undo stack. The _toggleFormat uses the fully selected "|italic|",
 * not the collapsed "ita|lic". Unfortunately, this means that the "before" state when
 * entering _toggleFormat does *not* represent what we want to select when we undo
 * later. We have to capture that before we set the tagRange selection. When we are done
 * toggling for undo here, then  we can use the indices and offsets we captured here
 * to set the selection to "ita|lic" inside of the new <b> that was restored. But
 * now that we have done undo untag, the tagRange and indices are wrong for redo.
 * The tagRange needed to be set to what was returned from the _toggleFormat on undo,
 * and the indices and offsets needed to be reset to the values based on when we
 * called _undoToggleFormat.
 */
const _undoToggleFormat = function(undoerData) {
    _restoreUndoerRange(undoerData)
    const sel = document.getSelection();
    if (!sel || !sel.rangeCount) { return };
    // We are going to toggle this type of element at the selection
    const type = undoerData.data.type;
    // We are about to set the selection to the tagRange, so before we do that, let's
    // capture the ancestor, indices, and offset to update undoerData with.
    const newSelRange = sel.getRangeAt(0);
    const commonAncestor = newSelRange.commonAncestorContainer;
    const ancestor = _findFirstParentElementInNodeNames(commonAncestor, _styleTags);
    let startIndices = _childNodeIndicesByParent(newSelRange.startContainer, ancestor);
    let startOffset = newSelRange.startOffset;
    let endIndices = _childNodeIndicesByParent(newSelRange.endContainer, ancestor);
    let endOffset = newSelRange.endOffset;
    // Start by setting the selection to the tagRange, which encompasses
    // the area to _toggleFormat on.
    const tagRange = undoerData.data.tagRange;
    sel.removeAllRanges();
    sel.addRange(tagRange);
    // Now tag the format across the tagRange and update undoerData
    const newTagRange = _toggleFormat(type, false);
    undoerData.data.tagRange = newTagRange;
    // The entire range is selected at this point, and we need to reselect
    // based on the startIndices and endIndices. The problem is that we either added
    // a new container or eliminated one.
    const newSel = document.getSelection();
    const toggledNode = _findFirstParentElementInNodeNames(sel.anchorNode, [type]);
    if (!toggledNode) {
        // We toggled off. The last entry in startIndices and endIndices leads to the
        // container we just toggled off. Update the undoerData so that redo will work
        // properly.
        undoerData.data.startIndices = startIndices;
        undoerData.data.startOffset = startOffset;
        undoerData.data.endIndices = endIndices;
        undoerData.data.endOffset = endOffset;
        startIndices.pop();
        endIndices.pop();
    } else {
        // We toggled on. Use the undoerData.
        startIndices = undoerData.data.startIndices;
        startOffset = undoerData.data.startOffset;
        endIndices = undoerData.data.endIndices;
        endOffset = undoerData.data.endOffset;
    }
    // Now we can locate the new selection and we are set for another undo or redo
    const startContainer = _childNodeIn(ancestor, startIndices);
    const endContainer = _childNodeIn(ancestor, endIndices);
    const range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    undoerData.range = range;
    sel.removeAllRanges();
    sel.addRange(range);
};

const _redoToggleFormat = function(undoerData) {
    _restoreUndoerRange(undoerData)
    const sel = document.getSelection();
    if (!sel || !sel.rangeCount) { return };
    // We are going to toggle this type of element at the selection
    const type = undoerData.data.type;
    const ancestor = undoerData.data.ancestor;
    let startIndices = undoerData.data.startIndices;
    const startOffset = undoerData.data.startOffset;
    let endIndices = undoerData.data.endIndices;
    const endOffset = undoerData.data.endOffset;
    const originalStartContainer = _childNodeIn(ancestor, startIndices);
    const originalEndContainer = _childNodeIn(ancestor, endIndices);
    // Start by setting the selection to the tagRange, which encompasses
    // the area to _toggleFormat on.
    const tagRange = undoerData.data.tagRange;
    sel.removeAllRanges();
    sel.addRange(tagRange);
    // Now tag the format across the tagRange and update undoerData
    const newTagRange = _toggleFormat(type, false);
    undoerData.data.tagRange = newTagRange;
    // The entire range is selected at this point, and we need to reselect
    // based on the startIndices and endIndices. The problem is that we either added
    // a new container or eliminated one.
    const newSel = document.getSelection();
    const toggledNode = _findFirstParentElementInNodeNames(sel.anchorNode, [type]);
    let startContainer, endContainer;
    if (!toggledNode) {
        // We toggled off. Use the original containers.
        startContainer = originalStartContainer;
        endContainer = originalEndContainer;
    } else {
        // We toggled on. Use the adjusted undoerData with a new container on the end.
        startIndices = [...undoerData.data.startIndices];
        startIndices.push(0);
        endIndices = [...undoerData.data.endIndices];
        endIndices.push(0);
        startContainer = _childNodeIn(ancestor, startIndices);
        endContainer = _childNodeIn(ancestor, endIndices);
    }
    // Now we can locate the new selection and we are set for another undo or redo
    const range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    undoerData.range = range;
    sel.removeAllRanges();
    sel.addRange(range);
}

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
    if (!newStyle) {
        MUError.NoNewTag.callback();
        return;
    };
    if (_selectionSpansParagraphs()) {
        _replaceAllStyles(newStyle, undoable);
        return;
    };
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    if (!sel || !selNode) { return };
    let existingElement = null;
    if (oldStyle) {
        // There can only be an existing element if oldStyle is non-null
        existingElement = _findFirstParentElementInNodeNames(selNode, [oldStyle.toUpperCase()]);
    };
    if (existingElement) {
        _replaceTag(existingElement, newStyle);
        _backupSelection();
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

/**
 * Make all styled elements within a selection that spans paragraphs into newStyle.
 */
const _replaceAllStyles = function(newStyle, undoable=true) {
    const selectedParagraphElements = _selectedParagraphElements();
    for (let i = 0; i < selectedParagraphElements.length; i++) {
        _replaceTag(selectedParagraphElements[i], newStyle.toUpperCase());
    };
    return;
}

/********************************************************************************
 * Nestables, including lists and block quotes
 */
//MARK: Nestables, Including Lists and BlockQuotes

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
    const selNode = (sel) ? sel.anchorNode : null;
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

const _rangeCopy = function() {
    const sel = document.getSelection();
    if (!sel || (!sel.rangeCount > 0)) { return null };
    const selRange = sel.getRangeAt(0)
    const rangeCopy = document.createRange();
    rangeCopy.setStart(selRange.startContainer, selRange.startOffset);
    rangeCopy.setEnd(selRange.endContainer, selRange.endOffset);
    return rangeCopy;
}

/**
 * We are inside of a list and hit Enter.
 *
 * The default behavior is to put in a div, but we want Enter to produce new list elements
 * that match the existing selection. We also have to handle the case of the selection not
 * being collapsed, by capturing the selection as a fragment, removing it, and then reinserting
 * it on undo.
 *
 * When we repeat _doListEnter for redo, we set undoable to false, because we don't want to
 * push anyother item onto the undo stack. However, we still need to patch up some things in
 * the undoerData if it exists from the previous _doListEnter. For example, we need to replace
 * the deletedFragment here once we delete it again, and we need to patch up the range.
 *
 * @return  {HTML BR Element}   The BR in the newly created LI to preventDefault handling; else, null.
 */
const _doListEnter = function(undoable=true, oldUndoerData) {
    //_consoleLog("\n* _doListEnter(" + undoable + ")");
    const redoing = !undoable && (oldUndoerData !== null);
    //_consoleLog(" redoing: " + redoing);
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode) {
        MUError.NoSelection.callback();
        return null;
    };
    // If sel is not collapsed, delete the entire selection and reset before continuing.
    // Track the deletedFragment and whether it came from a selection that spanned list items
    let deletedFragment, selWithinListItem;
    if (!sel.isCollapsed) {
        const selRange = sel.getRangeAt(0).cloneRange();
        if (redoing) {
            if (selRange.startContainer.nodeType === Node.TEXT_NODE) {
                selRange.startContainer.parentNode.normalize();
            } else {
                selRange.startContainer.normalize();
            };
            if (selRange.endContainer.nodeType === Node.TEXT_NODE) {
                selRange.endContainer.parentNode.normalize();
            } else {
                selRange.endContainer.normalize();
            };
            sel.removeAllRanges();
            sel.addRange(selRange);
        }
        const selStartListItem = _findFirstParentElementInNodeNames(selRange.startContainer, ['LI']);
        const selEndListItem = _findFirstParentElementInNodeNames(selRange.endContainer, ['LI']);
        selWithinListItem = selStartListItem && selEndListItem && (selStartListItem === selEndListItem);
        deletedFragment = selRange.extractContents();
        if (redoing) {
            oldUndoerData.data.deletedFragment = deletedFragment;
        }
        // The selection at this point is in the element that precedes what was previously selected,
        // and what was deleted is captured as deletedFragment. Unfortunately, when the selection extends
        // beyond the list item that the selection starts in, this does not result in the equivalent of
        // pressing Delete on the selection, which is what we want. So, we need to patch things up a bit.
        if (!selWithinListItem) {
            _patchMultiListItemEnter(deletedFragment);
        }
        // Even now selection might not be collapsed if, for example, the selection was everything within a
        // formatting node (like <b>).
        if (!document.getSelection().isCollapsed) {
            _patchEmptyFormatNodeEnter();
        }
        sel = document.getSelection();
        selNode = (sel) ? sel.anchorNode : null;
        // At this point, sel is collapsed and the document contents are the same as if we had
        // hit Backspace (but not Enter yet) on the original non-collapsed selection.
        //
        // DEBUGGING TIP:
        // By executing an 'input' callback and returning true at this point, we can debug the
        // result of various _patch* calls and ensure the result is the same as hitting Backspace.
        //_callback('input');
        //return true;
    }
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!existingList || !existingListItem) {
        MUError.NotInList.callback();
        return null;
    };
    let undoerRange = sel.getRangeAt(0).cloneRange();
    const startOffset = undoerRange.startOffset;
    const endOffset = undoerRange.endOffset;
    const outerHTML = existingList.outerHTML;
    // Record the child node indices we can traverse from existingList to find selNode
    // The childNodeIndices also reflect the state *after* a non-collapsed selection has
    // been extracted into deletedFragment and the dom has been patched-up properly.
    const childNodeIndices = _childNodeIndicesByName(selNode, existingList.nodeName);
    const textNode = selNode.nodeType === Node.TEXT_NODE
    const beginningListNode = (startOffset === 0) && (!selNode.previousSibling)
    const endOfTextNode = textNode && (endOffset === selNode.textContent.length);
    const emptyNode = textNode && (selNode.textContent.length === 0);
    const nextSib = selNode.nextSibling;
    const nextParentSib = selNode.parentNode.nextSibling;
    const nextParentSibIsList = (nextParentSib !== null) && ((nextParentSib.nodeName === 'LI') || (nextParentSib.nodeName === 'OL') || (nextParentSib.nodeName === 'UL'));
    const nextParentSibIsEmpty = (nextParentSib !== null) && ((nextParentSib.nodeType === Node.TEXT_NODE) && (nextParentSib.textContent.trim().length === 0));
    // If there is no nextParentSib or if it is empty after trim(), then we are at the end of a list element
    const endOfListElement = endOfTextNode && !nextSib && (nextParentSibIsList || nextParentSibIsEmpty)
    const endingListNode = (emptyNode && !nextSib) || (!emptyNode && endOfTextNode && !nextSib && !nextParentSib) || endOfListElement;
    const emptyListItem = beginningListNode && _isEmpty(existingListItem);
    const newListItem = document.createElement('li');
    const blockContainer = _findFirstParentElementInNodeNames(selNode, _listStyleTags);
    let newElement;
    if (blockContainer) {
        newElement = document.createElement(blockContainer.nodeName);
    } else {
        newElement = document.createElement('p');
    }
    if (emptyListItem) {
        _doListOutdent(undoable);
        // We return here because we want _doListOutdent to handle all the undoing logic
        return true;
    } else if (beginningListNode) {
        if (redoing) {
            oldUndoerData.range = undoerRange;
        };
        _newListItemBefore(newElement, newListItem, existingListItem, existingList);
    } else if (endingListNode) {
        if (redoing) {
            oldUndoerData.range = undoerRange;
        };
        _newListItemAfter(newElement, newListItem, existingListItem, existingList);
    } else if (selNode.nodeType === Node.TEXT_NODE) {
        //_consoleLog("- Splitting selNode")
        // We are somewhere in a list item
        let sib, nextSib, innerElement, outerElement;
        // innerElement is always the next sibling of outerElement
        innerElement = selNode.splitText(startOffset);
        outerElement = selNode;
        let innerTextContent = _patchWhiteSpace(innerElement.textContent);
        let outerTextContent = _patchWhiteSpace(outerElement.textContent);
        if (innerTextContent.length === 0) { innerTextContent = '\u200B' }
        if (outerTextContent.length === 0) { outerTextContent = '\u200B' }
        innerElement.textContent = innerTextContent;
        outerElement.textContent = outerTextContent;
        // After patching whitespace, the undoerRange itself has to be patched
        const selRange = document.createRange();
        selRange.setStart(outerElement, outerElement.textContent.length);
        selRange.setEnd(outerElement, outerElement.textContent.length);
        sel.removeAllRanges();
        sel.addRange(selRange);
        undoerRange = selRange;
        if (redoing) {
            const redoRange = document.createRange();
            redoRange.setStart(outerElement, outerElement.textContent.length);
            redoRange.setEnd(outerElement, outerElement.textContent.length);
            oldUndoerData.range = redoRange;
        }
        // If we split a textNode that is inside of format tags, then we need to patch up
        // innerElement and outerElement
        const formatTags = _getFormatTags();
        for (let i=0; i<formatTags.length; i++) {
            newElement = document.createElement(formatTags[i]);
            newElement.appendChild(innerElement);
            innerElement = newElement;
        };
        if (formatTags.length > 0) {
            const outermostFormatTag = formatTags[formatTags.length - 1];
            outerElement = _findFirstParentElementInNodeNames(outerElement, [outermostFormatTag]);
        };
        if (blockContainer) {
            // Make the newElement in the same style as its container.
            newElement = document.createElement(blockContainer.nodeName);
            newElement.appendChild(innerElement);
        } else if (!newElement) {
            // The newElement already exists if we were in formatTags
            // Otherwise, make the newElement just an unstyled text node like it started.
            newElement = document.createTextNode(trailingContent);
        }
        newListItem.appendChild(newElement);
        // With trailingContent in newElement which is in newListItem,
        // append all of selNode's siblings to newElement
        sib = outerElement.nextSibling;
        while (sib) {
            newElement.appendChild(sib);
            sib = outerElement.nextSibling;
        }
        // And then make all of selNode's parentNode's siblings follow it in
        // the same newListItem. For example, we might have nested lists
        // below the text node we are splitting.
        if (blockContainer) {
            sib = blockContainer.nextSibling;
            while (sib) {
                newListItem.appendChild(sib);
                sib = blockContainer.nextSibling;
            }
        };
        // Then, insert the newListItem with its new children into the list before the next list element.
        existingList.insertBefore(newListItem, existingListItem.nextElementSibling);
        const range = document.createRange();
        // And leave selection in the newElement
        range.setStart(newElement, 0);
        range.setEnd(newElement, 0);
        sel.removeAllRanges();
        sel.addRange(range);
    };
    _backupSelection();
    if (undoable) {
        const undoerData = _undoerData(
                                'listEnter',
                                {
                                    outerHTML: outerHTML,
                                    childNodeIndices: childNodeIndices,
                                    deletedFragment: deletedFragment,
                                    selWithinListItem: selWithinListItem
                                },
                                undoerRange
                            );
        undoer.push(undoerData);
        _restoreSelection();
    }
    _callback('input');
    //_consoleLog("* Done _doListEnter")
    return newElement;      // To preventDefault() on Enter
};

const _patchWhiteSpace = function(str, end='BOTH') {
    let patchedStr;
    switch (end) {
        case 'LEADING':
            patchedStr = str.replace(/^\s+/g, '\xA0');
            break;
        case 'TRAILING':
            patchedStr = str.replace(/\s+$/g, '\xA0');
            break;
        case 'BOTH':
            patchedStr = str.replace(/^\s+/g, '\xA0');
            patchedStr = patchedStr.replace(/\s+$/g, '\xA0');
            break;
    };
    return patchedStr;
};

const _stripZeroWidthChars = function(element) {
    const childNodes = element.childNodes;
    for (let i=0; i<childNodes.length; i++) {
        const childNode = childNodes[i];
        if (childNode.nodeType === Node.TEXT_NODE) {
            childNode.textContent = childNode.textContent.replace(/\u200B/g, '');
        };
    };
}

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
    if (element.nodeType === Node.TEXT_NODE) {
        empty = element.textContent.trim().length === 0;
    } else {
        empty = true;
        const childNodes = element.childNodes;
        for (let i=0; i<childNodes.length; i++) {
            empty = _isEmpty(childNodes[i]);
            if (!empty) { break };
        };
    }
    return empty;
};

/**
 * The deletedFragment spanned list items. Leave the document looking like
 * it would if we had pressed Backspace. This means the items at the focusNode
 * get moved to be in the same list item as the anchorNode. By default, the
 * contentEditable after extractContents leaves the focusNode in a non-list-element
 * below the anchorNode list element.
 */
const _patchMultiListItemEnter = function(deletedFragment) {
    // The selection at this point is in the element that precedes what was previously selected,
    // and what was deleted is captured as deletedFragment. Unfortunately, when the selection extends
    // beyond the list item that the selection starts in, this does not result in the equivalent of
    // pressing Delete on the selection, which is what we want. So, we need to patch things up a bit.
    //_consoleLog("* _patchMultiListItemEnter");
    //_consoleLog(_fragmentString(deletedFragment, "deletedFragment: "))
    let sel = document.getSelection();
    let newSelRange = sel.getRangeAt(0);
    const newEndContainer = newSelRange.endContainer;
    const newEndOffset = newSelRange.endOffset;
    let listItem = _findFirstParentElementInNodeNames(newSelRange.startContainer, ['LI']);
    const endListItem = _findFirstParentElementInNodeNames(newSelRange.endContainer, ['LI']);
    let newListItem;
    while (listItem && _isEmpty(listItem) && (listItem !== endListItem)) {
        newListItem = listItem.nextElementSibling ?? endListItem;
        //_consoleLog("Removing " + listItem.outerHTML);
        listItem.parentNode.removeChild(listItem);
        listItem = newListItem;
    }
    if (newListItem) {
        newSelRange = document.createRange();
        const firstChild = newListItem.firstChild;
        const newStartContainer = firstChild ?? newListItem;
        newSelRange.setStart(newStartContainer, 0);
        newSelRange.setEnd(newEndContainer, newEndOffset);
    };
    //_consoleLog(_rangeString(newSelRange, "after newSelRange"))
    //_consoleLog("after newSelRange.startContainer.parentNode.outerHTML: " +  newSelRange.startContainer.parentNode.outerHTML)
    // We want to move the newSelRange endContainer to be a child of the startContainer's parentNode
    // so that it becomes part of the same list item the startContainer is in.
    const startContainer = newSelRange.startContainer;
    let startContainerParent = startContainer.parentNode;
    const styleParent = _findFirstParentElementInNodeNames(startContainer, _styleTags);
    if (styleParent) { startContainerParent = styleParent };
    const formatElement = _outermostFormatElement(startContainer);
    if (formatElement) { startContainerParent = formatElement.parentNode };
    let mergedChild = newSelRange.endContainer;
    const mergedChildParent = mergedChild.parentNode;
    while (mergedChild && (mergedChild !== startContainer)) {
        let nextSib = mergedChild.nextSibling;
        startContainerParent.insertBefore(mergedChild, startContainer.nextSibling);
        mergedChild = nextSib;
    }
    startContainerParent.normalize();
    // If after merging the mergedChild, its parentNode is empty, then remove the mergedChild parentNode
    if (mergedChildParent.childNodes.length === 0) {
        //_consoleLog(" removing " + mergedChildParent.outerHTML)
        mergedChildParent.parentNode.removeChild(mergedChildParent);
    }
    // After we do that, if the existingList item where the selection ends is empty, then we need to remove it
    // so that we don't end up with an empty list node.
    const existingListItem = _findFirstParentElementInNodeNames(newSelRange.endContainer, ['LI']);
    //_consoleLog("existingListItem.outerHTML: " + existingListItem.outerHTML)
    if (existingListItem.childNodes.length === 0) {
        newSelRange.endContainer.parentNode.removeChild(newSelRange.endContainer);
    }
    const patchRange = document.createRange();
    patchRange.setStart(newSelRange.startContainer, newSelRange.startOffset);
    patchRange.setEnd(newSelRange.startContainer, newSelRange.startOffset)
    sel.removeAllRanges();
    sel.addRange(patchRange);
    //_consoleLog(_rangeString(patchRange, "patchRange"))
    //_consoleLog(_rangeString(document.getSelection().getRangeAt(0), "from getSelection()"))
    //_consoleLog("* Done _patchMultiListItemEnter")
};

/**
 * The deletedFragment contains the entire contents within a format node (like <b>).
 * We want the Enter to split the format node. To make that happen, insert a non-printing
 * pair of characters inside of the format node, and position selection between them.
 * Now when splitText happens, we end up with two text nodes and both are formatted
 * like the original we extracted the deletedFragment from.
 */
const _patchEmptyFormatNodeEnter = function() {
    //_consoleLog("* _patchEmptyFormatNodeEnter")
    const sel = document.getSelection();
    const anchorNode = sel.anchorNode;  // Selection start
    const focusNode = sel.focusNode;    // Selection end
    const anchorIsEmpty = anchorNode.textContent.length === 0;
    const focusIsEmpty = focusNode.textContent.length === 0;
    const anchorIsInTag = _tagsMatching(anchorNode, _formatTags).length > 0
    const focusIsInTag = _tagsMatching(focusNode, _formatTags).length > 0
    if (!anchorIsEmpty && !focusIsEmpty) {
        MUError.PatchFormatNodeNotEmpty.callback();
        return;
    };
    const anchorParentIsSibling = anchorNode.parentNode.nextSibling !== focusNode.parentNode
    const focusParentIsSibling = anchorNode.nextSibling !== focusNode.parentNode;
    if (!anchorParentIsSibling && !focusParentIsSibling) {
        MUError.PatchFormatNodeNotSiblings.callback();
        return;
    }
    const npcPair = document.createTextNode('\u200B\u200B');
    const range = document.createRange();
    // The node that is an empty tag (likely) has an empty text node in it which we
    // want to replace with the non-printing character pair so we can split them.
    if (anchorIsInTag) {
        if (anchorNode.parentNode.childNodes.length === 1) {
            anchorNode.parentNode.childNodes[0].replaceWith(npcPair)
        } else {
            anchorNode.parentNode.appendChild(npcPair);
        }
        range.setStart(npcPair, 1);
        range.setEnd(npcPair, 1);
    } else if (focusIsInTag) {
        if (focusNode.parentNode.childNodes.length === 1) {
            focusNode.parentNode.childNodes[0].replaceWith(npcPair)
        } else {
            focusNode.parentNode.appendChild(npcPair);
        }
        range.setStart(npcPair, 1);
        range.setEnd(npcPair, 1);
    } else {
        _consoleLog("Error - neither anchor nor focus is in a format tag");
        return;
    };
    sel.removeAllRanges();
    sel.addRange(range);
    //_consoleLog("* Done _patchEmptyFormatNodeEnter")
};

/**
 * We are at the beginning of a list node, so insert the newListItem
 */
const _newListItemBefore = function(newElement, newListItem, existingListItem, existingList) {
    //_consoleLog("- _newListItemBefore");
    newElement.appendChild(document.createElement('br'));
    newListItem.appendChild(newElement);
    existingList.insertBefore(newListItem, existingListItem);
    // Leave selection alone
};

/**
 * Insert a new list item after the selection.
 * We are at the end of a textNode in a list item (e.g., a <p> or just naked text)
 * First, move all of the siblings of selNode's parentNode to reside in the new list,
 * leaving selNode itself alone.
 */
const _newListItemAfter = function(newElement, newListItem, existingListItem, existingList) {
    //_consoleLog("- _newListItemAfter")
    const sel = document.getSelection();
    const selNode = sel.anchorNode;
    newElement.appendChild(document.createElement('br'));
    newListItem.appendChild(newElement);
    let sib = selNode.parentNode.nextElementSibling;
    let nextElementSib;
    while (sib && (sib.nodeName !== 'LI')) {
        nextElementSib = sib.nextElementSibling;
        newListItem.appendChild(sib);
        sib = nextElementSib;
    }
    // Then, insert the newListItem with its new children into the list before the next list element.
    existingList.insertBefore(newListItem, existingListItem.nextElementSibling);
    const range = document.createRange();
    // And leave selection in the newElement
    range.setStart(newElement, 0);
    range.setEnd(newElement, 0);
    sel.removeAllRanges();
    sel.addRange(range);
};

/**
 * Undo the _doListEnter operation. Redo is just to _doListEnter again.
 *
 * We were in a list when we hit Enter, and we end up be in the same list afterward.
 * The contents of the list changed, and the selection changed. The undoer.outerHTML
 * contains the list outerHTML before Enter was pressed. To undo, we first
 * restore the selection from undoer, so we are at the proper position in the list
 * we started with, before hitting Enter. Then we delete the entire list and replace
 * it with the outerHTML we captured in undoer. Now how to restore selection properly?
 * Unlike TABLE, where we hold onto the row and col to reselect, in list we will
 * identify the element to reselect based on indices into the list that were recorded
 * at undo time.
 *
 * Because we use insertAdjacentHTML to put the outerHTML in place, we have replaced
 * the existing list with a new one that looks the same as the one that existed when
 * Enter was pressed, but is actually a different element. Thus, we need to patch up
 * the range held in the undoerData when we are done. Remember, the undoerData used
 * here reflects the state *before* _doListEnter, which is the same state as we are
 * leaving when we are done undoing in this method.
 */
const _undoListEnter = function(undoerData) {
    //_consoleLog("\n* _undoListEnter");
    const oldRange = undoerData.range;
    const oldStartContainer = oldRange.startContainer;
    const oldStartOffset = oldRange.startOffset;
    const oldEndContainer = oldRange.endContainer;
    const oldEndOffset = oldRange.endOffset;
    _restoreUndoerRange(undoerData);
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!existingList || !existingListItem) { return null };
    _deleteAndResetSelection(existingList, 'BEFORE');
    sel = document.getSelection();
    selNode = (sel) ? sel.anchorNode : null;
    if (!selNode) { return null };
    const targetNode = selNode.parentNode;
    const parentNode = targetNode.parentNode;
    targetNode.insertAdjacentHTML('afterend', undoerData.data.outerHTML);
    // We need the new list that now exists at selection.
    let newList;
    if (sel.isCollapsed) {
        // Normal insertion at a collapsed selection
        newList = _getFirstChildWithNameWithin(targetNode.nextSibling, existingList.nodeName);
    } else {
        // Replacement insertion at a non-collapsed selection
        // The only reason this happens is that we ended up with nothing to select when we
        // deleted the list which we are about to undo the deletion of. At that point, we
        // set selection to span across a single non-printing character in a paragraph.
        // See the code in _deleteAndResetSelection when _elementAfterDeleting returns null.
        // To leave just the list again, we need to remove the targetNode.
        parentNode.removeChild(targetNode);
        newList = _getFirstChildWithNameWithin(parentNode, existingList.nodeName);
    };
    // Find the selected element based on the indices into the list recorded at undo time
    const selectedElement = _childNodeIn(newList, undoerData.data.childNodeIndices);
    if (!selectedElement) {
        MUError.CantUndoListEnter.callback();
        return;
    }
    // And then restore the range
    let range = document.createRange();
    range.setStart(selectedElement, oldStartOffset);
    range.setEnd(selectedElement, oldEndOffset);
    sel.removeAllRanges();
    sel.addRange(range);
    // There is a special case where sel is at the beginning of a list element, but the
    // initial textNode has blanks in front. In that case the oldStartOffset etc are zero,
    // but if we check the range selection immediately after setting it, it shows offset
    // to get to the first non-blank character.
    // At this point, the document and selection look like the did before hitting Enter,
    // unless there was a non-collapsed selection when Enter was hit. If so, this selection
    // is held in deletedFragment, and it may span list items. In any case, we need to put it
    // back at the current selection and restore the range.
    const deletedFragment = undoerData.data.deletedFragment;
    if (deletedFragment) {
        // After insertNode, the deletedFragment's childNodes will be in the range so we can select them.
        // Note that these childNodes were extracted from the selection as the deletedFragment.
        _insertInList(deletedFragment);
        _backupUndoerRange(undoerData);
    };
    _backupSelection();
    _callback('input');
    //_consoleLog("* Done _undoListEnter")
};

/**
 * Insert fragment into the current selection point somewhere inside of a list.
 *
 * When we reach this point, we have undone the Enter that preceded and now need
 * to re-insert the non-collapsed selection that we extracted and placed in fragment.
 */
const _insertInList = function(fragment) {
    //_consoleLog("* _insertInList(" + _fragmentString(fragment) + ")")
    const sel = document.getSelection();
    const range = sel.getRangeAt(0).cloneRange();
    const anchorNode = (sel) ? sel.anchorNode : null;   // Selection is collapsed
    if (!sel.isCollapsed || !anchorNode || (anchorNode.nodeType != Node.TEXT_NODE)) {
        MUError.CantInsertInList.callback();
        return;
    };
    // Handle specially if fragment contains no elements (i.e., just text nodes).
    const simpleFragment = fragment.childElementCount === 0;
    const singleListItemFragment = (fragment.childElementCount === 1) && (fragment.firstElementChild.nodeName !== 'LI');
    if (simpleFragment || singleListItemFragment) {
        //_consoleLog("* _insertInList (simple)")
        const firstFragChild = fragment.firstChild;
        const lastFragChild = fragment.lastChild;
        range.insertNode(fragment); // fragment becomes anchorNode's nextSibling
        _stripZeroWidthChars(anchorNode.parentNode);
        // Setting the selection is a challenge because (at least in a list) when we have
        // trailing blank characters, we can set to encompass them, but the document.getSelection()
        // afterward will not include the blank character. Perhaps this has to do with the nature of
        // lists, but in any case, this forces us to use the locations surrounding the inserted
        // fragment to set the selection and using normalize to combine text nodes.
        const textRange = document.createRange();
        const prevSib = firstFragChild.previousSibling;
        const nextSib = lastFragChild.nextSibling;
        if (prevSib) {
            if (prevSib.nodeType === Node.TEXT_NODE) {
                textRange.setStart(prevSib, prevSib.textContent.length);
            } else {
                textRange.setStart(prevSib, prevSib.childNodes.length);
            };
        } else {
            textRange.setStart(firstFragChild, firstFragChild.textContent.length);
        };
        if (nextSib) {
            textRange.setEnd(nextSib, 0);
        } else {
            textRange.setEnd(lastFragChild, lastFragChild.textContent.length);
        }
        anchorNode.parentNode.normalize();
        sel.removeAllRanges();
        sel.addRange(textRange);
        //_consoleLog("* Done _insertInList (simple)")
        return;
    }
    const existingList = _findFirstParentElementInNodeNames(anchorNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(anchorNode, ['LI'])
    const firstFragEl = fragment.firstElementChild;
    const lastFragEl = fragment.lastElementChild;
    if (range.startOffset === 0) {
        //_consoleLog("At the beginning of a text node")
        // Selection is at the beginning of a text node that we need
        // to insert the fragment into.
        let fragEl = fragment.firstElementChild;
        if (_isEmpty(lastFragEl)) {     // It should be an empty placeholder
            fragment.removeChild(lastFragEl);
        }
        while (fragEl) {
            existingList.insertBefore(fragEl, existingListItem);
            fragEl = fragment.firstElementChild;
        }
        const newRange = document.createRange();
        newRange.setStart(firstFragEl, 0);
        newRange.setEnd(existingListItem, 0);
        sel.removeAllRanges();
        sel.addRange(newRange);
    } else {
        //_consoleLog("In the middle of a text node")
        // Selection starts within a text node that needs to be split
        // and then merged with the fragment. After splitText,
        // anchorNode contains the textNode before the selection.
        let trailingText = anchorNode.splitText(range.startOffset);
        // We have a case where the selection is at the end of a textNode, so trailingText
        // ends up with zero length. This means we have to set the target for insertBefore
        // not to trailingText but to its parentNode's nextSibling.
        if (trailingText.length === 0) {
            trailingText = trailingText.parentNode.nextSibling;
        }
        // FIRST, insert all of the firstElFrag's childNodes before
        // the trailingText. So, for example, if the firstElFrag is
        // <h5 id="h5">ted <i id="i">item</i> 1.</h5>, the "ted <i id="i">item</i> 1."
        // gets put just after anchorNode (i.e., before trailingText).
        const anchorNodeParent = anchorNode.parentNode;
        const anchorNodeParentName = anchorNodeParent.nodeName;
        let firstElChild = firstFragEl.firstChild;
        while (firstElChild) {
            if ((firstElChild.nodeType === Node.ELEMENT_NODE) && (firstElChild.nodeName === anchorNodeParent.nodeName)) {
                let nextChild = firstElChild.firstChild;
                while (nextChild) {
                    anchorNode.parentNode.appendChild(nextChild)
                    nextChild = firstElChild.firstChild;
                }
                firstElChild.parentNode.removeChild(firstElChild);
            } else {
                trailingText.parentNode.insertBefore(firstElChild, trailingText)
            }
            firstElChild = firstFragEl.firstChild;
        }
        firstFragEl.parentNode.removeChild(firstFragEl);
        // SECOND, all the siblings of firstFragEl need to be added as siblings of anchorNode.parentNode.
        // The siblings start with what is now fragment.firstChild.
        let nextFragSib = fragment.firstChild;
        let nextSib = trailingText.parentNode.nextSibling;
        const nextListItem = existingListItem.nextSibling;
        while (nextFragSib) {
            if (nextFragSib.nodeName === 'LI') {
                // This is the case when selection spans list items within a single list type
                existingListItem.parentNode.insertBefore(nextFragSib, nextListItem)
            } else if ((nextFragSib.nodeName === 'OL') || (nextFragSib.nodeName === 'UL')) {
                // The selection crosses into another list. So, we were inserting list
                // items, and now this list item contains another list. Rather than
                // inserting it before the nextListItem, a sublist needs to be inside
                // of the current list item.
                // Handle styling in list item or no styling
                const styleElement = _findFirstParentElementInNodeNames(anchorNode, _styleTags)
                let insertBeforeNode;
                if (styleElement) {
                    insertBeforeNode = styleElement.nextSibling;
                } else {
                    insertBeforeNode = anchorNode.nextSibling
                }
                existingListItem.insertBefore(nextFragSib, insertBeforeNode);
            } else {
                _consoleLog("Error: unexpected nextFragSib")
            }
            nextFragSib = fragment.firstChild;
        };
        // THIRD, put the trailingText itself at the end of the lastFragEl along
        // with all of its parentNode's nextSiblings.
        let lastChildEl = lastFragEl.lastChild;
        let appendTrailingTarget;
        if (lastChildEl.nodeType === Node.TEXT_NODE) {
            appendTrailingTarget = lastChildEl.parentNode;
        } else if (lastChildEl.nodeType === Node.ELEMENT_NODE) {
            const lastChildChild = lastChildEl.lastChild;
            if (lastChildChild.nodeType === Node.TEXT_NODE) {
                appendTrailingTarget = lastChildChild.parentNode;
            } else {
                appendTrailingTarget = lastChildChild;
            }
        }
        // TODO: Maybe have to deal with siblings
        appendTrailingTarget.appendChild(trailingText);
        // FINALLY, if we ended up with two lists of the same type as siblings, then merge them
        const currentList = _findFirstParentElementInNodeNames(lastChildEl, ['OL', 'UL']);
        const nextList = currentList.nextSibling;
        if (nextList && (currentList.nodeName === nextList.nodeName)) {
            let nextListChild = nextList.firstChild;
            while (nextListChild) {
                currentList.appendChild(nextListChild);
                nextListChild = nextList.firstChild;
            }
            nextList.parentNode.removeChild(nextList);
        };
        const newRange = document.createRange();
        newRange.setStart(anchorNode, anchorNode.textContent.length);
        newRange.setEnd(trailingText, 0);
        sel.removeAllRanges();
        sel.addRange(newRange);
    };
    //_consoleLog("* Done _insertInList")
};

/**
 * We are inside of a list and want to indent the selected item in it.
 */
const _doListIndent = function(undoable=true) {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!existingList || !existingListItem) { return null };
    _backupSelection();
    if (_indentListItem(existingListItem, existingList)) {
        _restoreSelection();
        if (undoable) {
            _backupSelection();
            const undoerData = _undoerData('indent');
            undoer.push(undoerData);
            _restoreSelection();
        }
        _callback('input');
    };
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
 */
const _doListOutdent = function(undoable=true) {
    let sel = document.getSelection();
    let selNode = (sel) ? sel.anchorNode : null;
    if (!selNode || !sel.isCollapsed) { return null };
    const existingList = _findFirstParentElementInNodeNames(selNode, ['UL', 'OL'])
    const existingListItem = _findFirstParentElementInNodeNames(selNode, ['LI'])
    if (!(existingList && existingListItem)) { return null };
    _backupSelection();
    const outdentedItem = _outdentListItem(existingListItem, existingList);
    _restoreSelection()
    // When outdenting to get out of a list, we will always end up in a
    // style tag of some kind. The operation will not be undoable.
    // User can undo by pressing the delete key to get back in the list.
    if (outdentedItem && (!_styleTags.includes(outdentedItem.nodeName))) {
        if (undoable) {
            _backupSelection();
            const undoerData = _undoerData('outdent');
            undoer.push(undoerData);
        };
    };
    _callback('input');
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
            insertionPoint = oldList.nextSibling ?? MU.editor.lastChild;
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
 * Do a context-sensitive indent.
 *
 * If in a list, indent the item to a more nested level in the list if appropriate.
 * If in a blockquote, add another blockquote to indent further.
 * Else, put into a blockquote to indent.
 *
 */
MU.indent = function(undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    const specialParent = _findFirstParentElementInNodeNames(selNode, _monitorIndentTags);
    if (specialParent) {
        const nodeName = specialParent.nodeName;
        const inList = (nodeName === 'UL') || (nodeName === 'OL');
        const inBlockQuote = nodeName === 'BLOCKQUOTE';
        if (inList) {
            _doListIndent(undoable);
        } else if (inBlockQuote) {
            _increaseQuoteLevel(undoable);
        };
    } else {
        _increaseQuoteLevel(undoable);
    };
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
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    const specialParent = _findFirstParentElementInNodeNames(selNode, _monitorIndentTags);
    if (specialParent) {
        const nodeName = specialParent.nodeName;
        const inList = (nodeName === 'UL') || (nodeName === 'OL');
        const inBlockQuote = nodeName === 'BLOCKQUOTE';
        if (inList) {
            _doListOutdent(undoable);
        } else if (inBlockQuote) {
            _decreaseQuoteLevel(undoable);
        };
    };
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
const _increaseQuoteLevel = function(undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
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
            // Handle nested format tags
            const outermostFormatElement = _outermostFormatElement(selNode);
            if (outermostFormatElement) {
                selNodeParent = outermostFormatElement;
            } else {
                selNodeParent = selNode.parentNode;
            }
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
        const undoerData = _undoerData('indent');
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
const _decreaseQuoteLevel = function(undoable=true) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    if (!sel || !selNode || !sel.rangeCount) { return null };
    const existingElement = _findFirstParentElementInNodeNames(selNode, ['BLOCKQUOTE']);
    if (existingElement) {
        _unsetTag(existingElement, sel);
        if (undoable) {
            _backupSelection();
            const undoerData = _undoerData('outdent');
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
//MARK: Range Operations

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
        MUError.RestoreNullRange.callback();
    };
};

/**
 * Backup the range of the current selection into MU.currentSelection
 */
const _backupSelection = function() {
    const rangeProxy = _rangeProxy();
    MU.currentSelection = rangeProxy;
    if (!rangeProxy) {
        const error = MUError.BackupNullRange;
        error.setInfo('activeElement.id: ' + document.activeElement.id + ', getSelection().rangeCount: ' + document.getSelection().rangeCount);
        error.callback();
    };
};

/**
 * Restore the selection to the range held in MU.currentSelection
 */
const _restoreSelection = function() {
    _restoreRange(MU.currentSelection);
};

const _textString = function(node, title="") {
    if (!node) return title + "null"
    if (node.nodeType === Node.TEXT_NODE) {
        return title + "[" + node.nodeName + "] \"" + node.textContent + "\""
    } else {
        return title + "[" + node.nodeName + "] " + node.outerHTML;
    }
}

const _fragmentString = function(fragment, title="") {
    if (!fragment) return title + "null"
    let div = document.createElement('div');
    div.appendChild(fragment.cloneNode(true));
    return title + div.innerHTML;
};

/**
 * Return a reasonably informative string describing the range, for debugging purposes
 *
 * @param {Object | HTML Range}     range   Something holding onto the startContainer, startOffset, endContainer, and endOffset
 */
const _rangeString = function(range, title="") {
    if (!range) return title + "\n   null"
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
    return title + '\n   startContainer: ' + startContainerType + ', content: \"' + startContainerContent + '\"\n   startOffset: ' + range.startOffset + '\n   endContainer: ' + endContainerType + ', content: \"' + endContainerContent + '\"\n   endOffset: ' + range.endOffset;
};

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
    _cleanUpSpans();
    _cleanUpAttributes('style');
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
 * Put any direct childNodes of node that are BRs into paragraphs.
 */
const _cleanUpBRs = function(node) {
    const childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        const child = childNodes[i];
        const childName = child.nodeName;
        if (childName === 'BR') {
            const p = document.createElement('p');
            node.insertBefore(p, child);
            p.appendChild(child);
        };
    };
};

/*
 * Replace PREs with Ps. They should only occur at the top level.
 */
const _cleanUpPREs = function(node) {
    let childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        const child = childNodes[i];
        const childName = child.nodeName;
        if (childName === 'PRE') {
            const p = document.createElement('p');
            const template = document.createElement('template');
            template.innerHTML = child.innerHTML;
            const newElement = template.content;
            p.appendChild(newElement);
            child.replaceWith(p);
        };
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
 * Standard webkit editing may leave messy and useless SPANs all over the place.
 * This method just cleans them all up and notifies Swift that the content
 * has changed. Start with the selection anchorNode's parent, so as to make
 * sure to get all its siblings. If there is no anchorNode, fix the entire
 * editor.
 */
const _cleanUpSpans = function() {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
    const startNode = (selNode) ? selNode.parentNode : MU.editor;
    if (startNode) {
        const styleParent = _findFirstParentElementInNodeNames(startNode, _styleTags)
        if (styleParent) {
            const spansRemoved = _cleanUpSpansWithin(styleParent);
            if (spansRemoved > 0) {
                _callback('input');
            };
        };
    };
};

/**
 * Do a depth-first traversal from node, removing spans starting at the leaf nodes.
 *
 * @return {Int}    The number of spans removed
 */
const _cleanUpSpansWithin = function(node, spansRemoved) {
    spansRemoved = spansRemoved ?? 0;
    // Spans are not elements, so have no children; however, nested
    // spans do show up as childNodes of a span.
    const childNodes = node.childNodes;
    for (let i=0; i<childNodes.length; i++) {
        const child = childNodes[i];
        spansRemoved = _cleanUpSpansWithin(child, spansRemoved);
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
 * from the anchorNode and its siblings. If there is no anchorNode,
 * fix the entire editor.
 * If any attributes were removed, then notify Swift of a content change
 */
const _cleanUpAttributes = function(attribute) {
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
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
    if ((node.nodeType === Node.ELEMENT_NODE) && (node.hasAttribute(attribute))) {
        attributesRemoved++;
        node.removeAttribute(attribute);
    };
    return attributesRemoved;
};
                                
/********************************************************************************
 * Explicit handling of multi-click
 * TODO: Remove?
 */
//MARK: Explicit Handling of Multi-click

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
    const selNode = (sel) ? sel.anchorNode : null;
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

/********************************************************************************
 * Selection
 */
//MARK: Selection

/**
 * Define various arrays of tags used to represent concepts on the Swift side.
 *
 * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
 */
const _paragraphStyleTags = ['P', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6'];      // All paragraph styles

const _formatTags = ['B', 'I', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];           // All possible (nestable) formats

const _listStyleTags = _paragraphStyleTags.concat(['BLOCKQUOTE']);          // Possible containing blocks in a list

const _minimalStyleTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE'];       // Convert to 'P' for MU.pasteText

const _styleTags = _paragraphStyleTags.concat(['LI', 'BLOCKQUOTE', 'OL', 'UL']);    // Identify insert-before point in table/list

const _tableTags = ['TABLE', 'THEAD', 'TBODY', 'TD', 'TR', 'TH'];           // All tags associated with tables

const _monitorEnterTags = ['UL', 'OL', 'TABLE', 'BLOCKQUOTE'];              // Tags we monitor for Enter

const _monitorIndentTags = ['UL', 'OL', 'BLOCKQUOTE'];                      // Tags we monitor for Tab or Ctrl+]

const _topLevelTags = _paragraphStyleTags.concat(['OL', 'UL', 'TABLE']);    // Allowed top-level tags within editor

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
 * Return the outermost element at the selection that corresponds to a format tag.
 * For example, the selection could be in the word "Hello" in <B><I><U>Hello</U></I></B>,
 * and the outermostFormatElement would be the HTMLBoldElement in <B><I><U>Hello</U></I></B>.
 *
 * @return {HTMLElement || null}    The ancestor HTML Element that is outermost from the selection or null if none.
 */
const _outermostFormatElement = function(selNode) {
    const formatTags = _tagsMatching(selNode, _formatTags);
    if (formatTags.length > 0) {
        return _findFirstParentElementInNodeNames(selNode, [formatTags[formatTags.length - 1]]);
    } else {
        return null;
    };
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
    const startElement = document.getElementById(startElementId);
    const endElement = document.getElementById(endElementId);
    if (!startElement || !endElement) {
        let error = MUError.CantFindElement;
        error.setInfo('Could not identify startElement(' + startElement + ') or endElement(' + endElement + ')');
        error.callback();
        return false;
    };
    let startContainer, endContainer;
    if (startChildNodeIndex) {
        const startChild = startElement.childNodes[startChildNodeIndex];
        if (startChild.nodeType === Node.TEXT_NODE) {
            startContainer = startChild;
        } else {
            startContainer = _firstTextNodeChild(startChild);
        };
    } else {
        startContainer = _firstTextNodeChild(startElement);
        if (!startContainer) {
            startContainer = startElement;
        }
    };
    if (endChildNodeIndex) {
        const endChild = endElement.childNodes[endChildNodeIndex];
        if (endChild.nodeType === Node.TEXT_NODE) {
            endContainer = endChild;
        } else {
            endContainer = _firstTextNodeChild(endChild);
        };
    } else {
        endContainer = _firstTextNodeChild(endElement);
        if (!endContainer) {
            endContainer = endElement;
        }
    };
    if (!startContainer || !endContainer) {
        let error = MUError.CantFindContainer;
        error.setInfo('Could not identify startContainer(' + startContainer + ') or endContainer(' + endContainer + ')');
        error.callback();
        return false;
    };
    const range = document.createRange();
    range.setStart(startContainer, startOffset);
    range.setEnd(endContainer, endOffset);
    const sel = document.getSelection();
    sel.removeAllRanges();
    sel.addRange(range);
    //_consoleLog(_rangeString(range, "setRange to: "));
    _backupSelection();
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

/**
 * For testing purposes, invoke _doListEnter programmatically.
 *
 * After the _doListEnter, subsequent ops for undo and redo need to
 * be done using MU.testUndo
 */
MU.testListEnter = function() {
    _doListEnter()
}

/**
 * For testing purposes, undo _doListEnter by invoking standard undo.
 */
MU.testUndoListEnter = function() {
    undoer.testUndo()
}

/**
 * For testing purposes, execute _patchPasteHTML and return the resulting
 * html as a string. Testing in this way lets us do simple pasteHTML tests with
 * clean HTML and test the _patchPasteHTML functionality separately. The
 * purpose of _patchPasteHTML is to return "clean" HTML from arbitrary HTML
 * (typically) obtained from the paste buffer on the Swift side.
 */
MU.testPasteHTMLPreprocessing = function(html) {
    const fragment = _patchPasteHTML(html);
    return _fragmentString(fragment);
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
    return _minimalHTML(fragment);
};

/********************************************************************************
 * Links
 */
//MARK: Links

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
    if (sel && sel.anchorNode && sel.anchorNode.parentElement) {
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
    if (sel && sel.anchorNode && sel.anchorNode.parentElement) {
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
 * @param {Int}                 scale       The scale as a percentage of original's naturalWidth/Height.
 * @param {Boolean}             undoable    True if we should push undoerData onto the undo stack.
 * @return {HTML Image Element}             The image element that was created, used for undo/redo.
 */
MU.insertImage = function(src, alt, scale=100, undoable=true) {
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
    if ((rows < 1) || (cols < 1)) { return };
    _restoreSelection();
    const sel = document.getSelection();
    const selNode = (sel) ? sel.anchorNode : null;
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
//MARK: Common Private Functions

/**
 * Return true if the selection spans _paragraphStyleTags.
 *
 * It's possible (due to pasting) that we end up with a selection in a text
 * node that is not inside of a paragraph style tag. Since we are only going to
 * apply multiple operations at the paragraph style level, we will return
 * false here in that case.
 */
const _selectionSpansParagraphs = function() {
    const sel = document.getSelection();
    if (!sel || sel.isCollapsed || (sel.anchorNode === sel.focusNode)) { return false };
    const anchorStyleParent = _findFirstParentElementInNodeNames(sel.anchorNode, _paragraphStyleTags);
    const focusStyleParent = _findFirstParentElementInNodeNames(sel.focusNode, _paragraphStyleTags);
    return (!anchorStyleParent || !focusStyleParent || (anchorStyleParent !== focusStyleParent));
};

/**
 * Return an array of paragraph-styled Elements that the selection spans, including ones it
 * only partially encompasses.
 *
 * If the selection doesn't span paragraphs, return an empty array. We do this even though
 * the selection is within a paragraph. This is because the function is used for operations
 * that span paragraphs.
 */
const _selectedParagraphElements = function() {
    let elements = [];
    if (!_selectionSpansParagraphs()) { return elements };
    const sel = document.getSelection();
    if (!sel || (sel.rangeCount === 0)) { return elements };
    const range = sel.getRangeAt(0);
    const startContainer = range.startContainer;
    const startOffset = range.startOffset;
    const startParagraph = _findFirstParentElementInNodeNames(startContainer, _paragraphStyleTags);
    const endContainer = range.endContainer;
    const endOffset = range.endOffset;
    const endParagraph = _findFirstParentElementInNodeNames(endContainer, _paragraphStyleTags);
    const selAtParagraphStart = (startOffset === 0) && (!startContainer.previousSibling);
    let selAtParagraphEnd;
    if (_isTextNode(endContainer)) {
        selAtParagraphEnd = (endOffset === endContainer.textContent.length) && (!endContainer.nextSibling);
    } else {
        selAtParagraphEnd = (endOffset === endContainer.children.length) && (!endContainer.nextSibling);
    };
    const fragment = range.extractContents();
    elements = _allChildElementsWithNodeNames(fragment, _paragraphStyleTags)
    range.insertNode(fragment);
    // When the fragment splits a node at the beginning or end, we need to join
    // them back together or we end up with new paragraphs and the changes to
    // the beginning and ending paragraphs will not be applied to the surrounding
    // ones that were split-off.
    const leadingParagraph = _findFirstParentElementInNodeNames(sel.anchorNode, _paragraphStyleTags);
    const leadingNodeName = leadingParagraph && leadingParagraph.nodeName;
    const fragLeadingParagraph = leadingParagraph && leadingParagraph.nextElementSibling;
    if (!selAtParagraphStart && leadingParagraph && fragLeadingParagraph && (leadingNodeName === fragLeadingParagraph.nodeName)) {
        _joinNodes(leadingParagraph, fragLeadingParagraph, leadingNodeName);
        elements[0] = leadingParagraph;
    };
    const trailingParagraph = _findFirstParentElementInNodeNames(sel.focusNode, _paragraphStyleTags);
    const trailingNodeName = trailingParagraph && trailingParagraph.nodeName;
    const fragTrailingParagraph = trailingParagraph && trailingParagraph.previousElementSibling;
    if (!selAtParagraphEnd && trailingParagraph && fragTrailingParagraph && (trailingNodeName === fragTrailingParagraph.nodeName)) {
        _joinNodes(fragTrailingParagraph, trailingParagraph, trailingNodeName);
    }
    return elements;
}

/**
 * Return all elements within element that have nodeName.
 */
const _allChildElementsWithNodeNames = function(element, nodeNames, existingElements=[]) {
    if (nodeNames.includes(element.nodeName)) { existingElements.push(element) };
    const children = element.children;
    for (let i = 0; i < children.length; i++) {
        let child = children[i];
        if (_isElementNode(child)) {
           existingElements = _allChildElementsWithNodeNames(child, nodeNames, existingElements);
        };
    };
    return existingElements;
}

/**
 * Return whether node is a textNode or not
 */
const _isTextNode = function(node) {
    return node.nodeType === Node.TEXT_NODE;
};

/***
 * Return whether node is an ELEMENT_NODE or not
 */
const _isElementNode = function (node) {
    return node.nodeType === Node.ELEMENT_NODE;
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
        const anchorNode = sel.anchorNode
        if (anchorNode) {
            const selElement = _findFirstParentElementInNodeNames(anchorNode, matchNames, excludeNames);
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
    if (sel && sel.anchorNode) {
        return _tagsMatching(sel.anchorNode, nodeNames);
    } else {
        return [];
    };
};

const _tagsMatching = function(selNode, nodeNames) {
    const tags = [];
    let selElement = _findFirstParentElementInNodeNames(selNode, nodeNames);
    while (selElement) {
        tags.push(selElement.nodeName);
        selElement = _findFirstParentElementInNodeNames(selElement.parentNode, nodeNames);
    };
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
 * Return the first node of nodeType within element's nextSiblings.
 *
 * Note that when looking for text nodes, a sibling is sometimes an empty text node.
 * The whole point of identifying the child is to set the selection, so we skip
 * these because we cannot select in an empty text node. Such nodes are "normal" to
 * be found between styled sections and are not useful in any case.
 *
 * @param   {HTML Element}  element     The element to start looking at for nextSiblings.
 * @param   {String}        nodeType    The type of node we are looking for.
 * @return  {HTML Node | null}          The node we found, or null.
 */
const _getFirstChildOfTypeAfter = function(element, nodeType) {
    const nextSibs = [];
    let nextSib = element.nextSibling;
    while (nextSib) {
        nextSibs.push(nextSib);
        nextSib = nextSib.nextSibling;
    }
    let firstChildOfType;
    for (let i = 0; i < nextSibs.length; i++) {
        firstChildOfType = nextSibs[i];
        if (firstChildOfType.nodeType === nodeType) {
            if ((nodeType !== Node.TEXT_NODE) || (!_isEmpty(firstChildOfType))) {
                break;
            };
        };
        if (firstChildOfType.nodeType === Node.ELEMENT_NODE) {
            firstChildOfType = _getFirstChildOfTypeWithin(firstChildOfType, nodeType);
            if (firstChildOfType) { break };
        };
    };
    return firstChildOfType;
};

/**
 * Return the first node of nodeType within element's previousSiblings.
 *
 * Note that when looking for text nodes, a sibling is sometimes an empty text node.
 * The whole point of identifying the child is to set the selection, so we skip
 * these because we cannot select in an empty text node. Such nodes are "normal" to
 * be found between styled sections and are not useful in any case.
 *
 * @param   {HTML Element}  element     The element to start looking at for previousSiblings.
 * @param   {String}        nodeType    The type of node we are looking for.
 * @return  {HTML Node | null}          The node we found, or null.
 */
const _getFirstChildOfTypeBefore = function(element, nodeType) {
    const prevSibs = [];
    let prevSib = element.previousSibling;
    while (prevSib) {
        prevSibs.push(prevSib);
        prevSib = prevSib.previousSibling;
    }
    let firstChildOfType;
    for (let i = 0; i < prevSibs.length; i++) {
        firstChildOfType = prevSibs[i];
        if (firstChildOfType.nodeType === nodeType) {
            if ((nodeType !== Node.TEXT_NODE) || (!_isEmpty(firstChildOfType))) {
                break;
            };
        };
        if (firstChildOfType.nodeType === Node.ELEMENT_NODE) {
            firstChildOfType = _getFirstChildOfTypeWithin(firstChildOfType, nodeType);
            if (firstChildOfType) { break };
        };
    };
    return firstChildOfType;
};

/**
 * Return the childNode in element by following indices into childNodes at each level.
 *
 * @param   {HTML Element}      element     The element to traverse using childNodes at each level
 * @param   {Array of Int}      indices     The indices into element's childNodes to walk down toward the target childNode
 * @return  {HTML Node}                     The node we found by following indices down childNodes at each level
 */
const _childNodeIn = function(element, indices) {
    let childNode = element
    for (let i=0; i<indices.length; i++) {
        childNode = childNode.childNodes[indices[i]];
    };
    return childNode;
};

/**
 * Return an array of indices into the childNodes at each level below the parentNode
 * that has a nodeName of nodeName, so as to locate a particular childNode within
 * that parentNode.
 *
 * We start at node and go upward to find a parentNode with nodeName === nodeName,
 * recording the index into childNodes at each level by counting previousSiblings.
 *
 * For example, say node is the textElement "With two items." in this unordered list:
 *    <ul>
 *        <li>
 *            <h5>Here is a bulleted list with an item in <i>H5</i> paragraph style.</h5>
 *            <ol>
 *                <li>Here is a numbered sublist.</li>
 *                <li>With two items.</li>
 *            </ol>
 *        </li>
 *        <li><h5>The bulleted list has two items and a sublist that is numbered.</h5></li>
 *    </ul>
 *
 * Then, _childNodeIndices(node, 'OL') returns [1,0] because node is inside of the 2nd
 * childNode of the OL and the 1st childNode of the LI in that OL. Similarly,
 * _childNodeIndices(node, 'UL') returns [0,1,1,0] because node is inside of the 1st
 * childNode of the UL, whose 2nd childNode is OL, whose 1st childNode is LI, whose 2nd
 * childNode is node ("With two items.").
 *
 * @param   {HTML Node}     node        The node to move upward from until we find a parent with nodeName
 * @param   {String}        nodeName    The type of nodeName we are looking for in the ancestors of node
 * @return  {Array of Int}              The indices into the parent's childNodes (and their childNodes) to walk down to find node
 */
const _childNodeIndicesByName = function(node, nodeName) {
    let _node = node;
    let indices = [];
    while (_node && (_node.nodeName !== nodeName)) {
        indices.unshift(_childNodeIndex(_node)); // Put at beginning of indices
        _node = _node.parentNode;
    }
    // If we never find parentNode, return an empty array
    return (_node) ? indices : [];
};

/**
 * Return an array of indices into the childNodes at each level below the parentNode
 * so as to locate a particular childNode within that parentNode.
 *
 * See comments under _childNodeIndicesByName for discussion.
 *
 */
const _childNodeIndicesByParent = function(node, parentNode) {
    let _node = node;
    let indices = [];
    while (_node && (_node !== parentNode)) {
        indices.unshift(_childNodeIndex(_node)); // Put at beginning of indices
        _node = _node.parentNode;
    }
    // If we never find parentNode, return an empty array
    return (_node) ? indices : [];
}

/**
 * Return the index in node.parentNode.childNodes where we will find node.
 *
 * @param   {HTML Node}     node        The node to find the index of in its parent.
 * @return  {Int}                       The index of node in its parent's childNodes.
 */
const _childNodeIndex = function(node) {
    let _node = node;
    let childCount = 0;
    while (_node.previousSibling) {
        childCount++;
        _node = _node.previousSibling;
    };
    return childCount;
};

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
 *
 * Used for deleting element and leaving selection in a reasonable state.
 * If the nearest sibling is a BR, we will replace it with a text node
 * and return that text node.
 *
 * Note that there is a case where determining the node that should be selected
 * after deleting an element which is the only element in MU.editor (i.e., in test
 * cases, but also possible in actual usage) always returns null.
 *
 * @param   {HTML Element}      element     HTML element.
 * @param   {String}            direction   Either 'BEFORE' or 'AFTER' to identify which way to look for a text node
 * @return  {HTML Text Node | null}         The text node in the direction or null if not able to determine it
 */
const _elementAfterDeleting = function(element, direction) {
    //_consoleLog("\n* elementAfterDeleting")
    let nearestTextNode;
    if (direction === 'BEFORE') {
        nearestTextNode = _getFirstChildOfTypeBefore(element, Node.TEXT_NODE);
    } else {
        nearestTextNode = _getFirstChildOfTypeAfter(element, Node.TEXT_NODE);
    };
    if (nearestTextNode) {
        return nearestTextNode
    } else {
        // Regardless of direction, find the nearest sibling if there is one
        const sibling = element.nextSibling ?? element.previousSibling;
        if (sibling && (sibling.nodeName === 'BR')) {
            const newTextNode = document.createTextNode('');
            sibling.replaceWith(newTextNode);
            return newTextNode;
        } else if (sibling) {
            return sibling;
        } else {
            // Nothing will be left to select after deleting element
            return null;
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
    //_consoleLog("\n* _deleteAndResetSelection")
    let nextEl = _elementAfterDeleting(element, direction);
    element.parentNode.removeChild(element);
    const newRange = document.createRange();
    if (!nextEl) {
        MU.emptyDocument()
        nextEl = _firstEditorElement().firstChild;
        const emptyTextNode = document.createTextNode('\u200B');
        nextEl.replaceWith(emptyTextNode);
        newRange.setStart(emptyTextNode, 0);
        newRange.setEnd(emptyTextNode, 1);
    } else {
        if (direction === 'BEFORE') {
            newRange.setStart(nextEl, nextEl.textContent.length);
            newRange.setEnd(nextEl, nextEl.textContent.length);
        } else {
            newRange.setStart(nextEl, 0);
            newRange.setEnd(nextEl, 0);
        }
    }
    const sel = document.getSelection();
    sel.removeAllRanges();
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
    if (sel && sel.anchorNode) {  // Removed check on && isCollapsed
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
    const range = sel.getRangeAt(0);
    const el = document.createElement(type);
    const wordRange = _wordRangeAtCaret();
    const startNewTag = range.collapsed && !wordRange;
    const tagWord = range.collapsed && wordRange;
    const newRange = document.createRange();
    let tagRange;
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
        // If we select the empty text character so that as soon as we type, it gets replaced,
        // everything works fine and it "goes away". Unfortunately, the cursor doesn't show
        // up when the range covers the non-printing character (just like it doesn't show up
        // when any range is selected). To avoid losing the cursor, we select the position
        // after the zero-width space character. The zero-width character is a character, tho.
        // For example, if we create the empty node (e.g., <b></b> but never start typing to
        // to add more text, then we can "see" it show up when navigating with arrow keys, as
        // the cursor stays in the same place twice.
        const emptyTextNode = document.createTextNode('\u200B');
        el.appendChild(emptyTextNode);
        range.insertNode(el);
        newRange.setStart(el.firstChild, 1);    // Can't use emptyTextNode
        newRange.setEnd(el.firstChild, 1);      // Can't use emptyTextNode
        tagRange = newRange;
    } else if (tagWord) {
        const inWordOffset = range.startOffset - wordRange.startOffset;
        const wordNode = document.createTextNode(wordRange.toString());
        el.appendChild(wordNode);
        wordRange.deleteContents();
        wordRange.insertNode(el);
        newRange.setStart(wordNode, inWordOffset);
        newRange.setEnd(wordNode, inWordOffset);
        tagRange = wordRange;
    } else {
        // Why not just range.surroundContents(el)?
        // Because for selections that span elements, it doesn't work.
        // Consider:
        //      <p><b>Hel|lo</b> wo|rld<p>
        // Where | shows the selection starting in the bold element and ending in text.
        // The extractContents-appendChild-insertNode for italic operation produces:
        //      <p><b>Hel</b><i><b>lo</b> wo</i>rld<p>
        el.appendChild(range.extractContents());
        range.insertNode(el);
        newRange.selectNode(el);
        // Extracting the contents of range leaves empty text node placeholders
        // where things used to be, and these mess up any references by indices.
        _removeEmptyTextNodes(range);
        newRange.selectNode(el);
        tagRange = newRange;
        // By extractingContents, we may have left range's startContainer and/or
        // endContainer empty. If so, we need to remove them to avoid messing up
        // future navigation by indices from parents in undo.
        const startContainer = range.startContainer;
        const endContainer = range.endContainer;
        if (_isEmpty(startContainer)) {
            startContainer.parentNode.removeChild(startContainer);
        };
        if ((startContainer !== endContainer) && _isEmpty(endContainer)) {
            endContainer.parentNode.removeChild(endContainer);
        };
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
    return tagRange;
};

/**
 * Remove all the empty text nodes found in range.
 *
 * This is needed because range.extractContents leaves empty textNode
 * placeholders that serve no purpose and mess up later childNode
 * index-based access.
 */
const _removeEmptyTextNodes = function(range) {
    const startContainer = range.startContainer;
    const endContainer = range.endContainer;
    let child = startContainer.firstChild;
    while (child) {
        let nextChild = child.nextSibling;
        if (_isEmpty(child)) {
            startContainer.removeChild(child);
        }
        child = nextChild;
    };
    child = endContainer.firstChild;
    while (child) {
        let nextChild = child.nextSibling;
        if (_isEmpty(child)) {
            endContainer.removeChild(child);
        };
        child = nextChild;
    };
}

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
 * Remove the tag from the oldElement.
 *
 * The oldRange startContainer might or might not be the oldElement passed-in. In all cases,
 * though, oldRange starts at some offset into text. The element passed-in has the tag we are
 * removing, so we move its childNodes to follow oldElement and then remove oldElement. This
 * also allows us to set the selection properly since the startContainer and endContainer
 * will still exist even though they have moved.
 *
 * When undoing, we need the range that surrounds the content that was changed. For example,
 * consider <p><b><i>Hello</i> wo|rld</b></p>. When we untag, we get <p><i>Hello</i> wo|rld</p>,
 * with selection still in "world". However, when we undo just by toggling the format at the
 * selection, we end up with <p><i>Hello</i> <b>wo|rld</b></p> because the selection is
 * collapsed in "world", and we only format the word it's within. For this reason, we return
 * the tagRange here that the sender can save in undoerData.
 *
 * @param   {HTML Element}      oldElement      The element we are removing the tag from.
 * @param   {HTML Selection}    sel             The current selection.
 * @return  {HTML Range}        tagRange        Range used to setTag on undo
 */
const _unsetTag = function(oldElement, sel) {
    const oldRange = sel.getRangeAt(0);
    const oldStartContainer = oldRange.startContainer;
    const oldStartOffset = oldRange.startOffset;
    const oldEndContainer = oldRange.endContainer;
    const oldEndOffset = oldRange.endOffset;
    // Hold onto the parentNode and the nextSibling so we know where to
    // insert the oldElement's childNodes.
    const oldParentNode = oldElement.parentNode;
    const oldNextSibling = oldElement.nextSibling;
    // Establish the tagRange as we move childNodes.
    const tagRange = document.createRange();
    let child = oldElement.firstChild;
    let setStart = true;
    while (child) {
        oldParentNode.insertBefore(child, oldNextSibling);
        if (setStart) {
            tagRange.setStart(child, 0);
            setStart = false;
        };
        if (oldElement.firstChild) {
            child = oldElement.firstChild;
        } else {
            if (_isTextNode(child)) {
                tagRange.setEnd(child, child.textContent.length);
            } else {
                tagRange.setEnd(child, child.childNodes.length);
            }
            child = null;
        };
    };
    oldParentNode.removeChild(oldElement);  // Because oldElement is now empty
    // Note the obvious: oldParentNode has a different set of childNodes when done, so
    // any external usage of indices into it will be wrong. We can fix this by
    // normalizing oldParentNode, but this messes with selection. Furthermore, the
    // selection on undo or redo is set to the tagRange before _unsetTag is called,
    // so it is not meaningful in those cases other than to ensure the proper range
    // is untagged.
    const range = document.createRange();
    range.setStart(oldStartContainer, oldStartOffset);
    range.setEnd(oldEndContainer, oldEndOffset);
    sel.removeAllRanges();
    sel.addRange(range);
    return tagRange;
};

/**
 * Given an element with a tag, replace its tag with the new nodeName.
 *
 * If the current selection is within the oldElement, then patch it up to sit in
 * the right place in the newElement. It's important not to change selection if
 * this is not the case, because we iterate over _replaceTag when doing selection
 * across multiple paragraphs.
 *
 * @param   {HTML Element}  element     The element for which we are replacing the tag.
 * @param   {String}        nodeName    The type of element we want; e.g., 'B'.
 *
 */
const _replaceTag = function(oldElement, nodeName) {
    if (!nodeName) {
        MUError.NoNewTag.callback();
        return;
    };
    const sel = document.getSelection();
    const oldRange = sel.getRangeAt(0).cloneRange();
    const startContainer = oldRange.startContainer;
    const startOffset = oldRange.startOffset;
    const endContainer = oldRange.endContainer;
    const endOffset = oldRange.endOffset;
    // Create and update newRange if we can find either startContainer or
    // endContainer within oldElement. If we can, then we can reset the
    // selection by locating the proper element inside of newElement using
    // the indices we obtained from oldElement.
    const newRange = oldRange.cloneRange();
    const startIndices = _childNodeIndicesByParent(startContainer, oldElement);
    const endIndices = _childNodeIndicesByParent(endContainer, oldElement);
    const patchStart = startIndices.length > 0;
    const patchEnd = endIndices.length > 0;
    const newElement = document.createElement(nodeName);
    newElement.innerHTML = oldElement.innerHTML;
    oldElement.replaceWith(newElement);
    if (patchStart) {
        newRange.setStart(_childNodeIn(newElement, startIndices), startOffset);
    };
    if (patchEnd) {
        newRange.setEnd(_childNodeIn(newElement, endIndices), endOffset);
    }
    if (patchStart || patchEnd) {
        sel.removeAllRanges();
        sel.addRange(newRange);
    };
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
        } else if (node.nodeType === Node.ELEMENT_NODE) {
            return _firstTextNodeChild(node);
        }
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
        element = node.parentNode;
    } else {
        element = node;
    };
    const nodeName = element.nodeName;
    if (excludeNames && excludeNames.includes(nodeName)) {
        return null;
    } else if (matchNames.includes(nodeName)) {
        return element;
    } else {
        return _findFirstParentElementInNodeNames(element.parentNode, matchNames, excludeNames);
    };
};

/********************************************************************************
 * Xcode Formatting Hack
 *
 * This is so pathetic, I cannot believe I am doing it.
 * But, wherever the / shows up in JavaScript, Xcode messes
 * up all subsequent formatting and it becomes pretty unbearable
 * to deal with the indentation it forces on you.
 * So, I'm putting the only methods where I divide at the bottom of the
 * file and using these methods rather than inlining above.
 */
//MARK: Xcode Formatting Hack

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


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

/**
 * The NodeView to support divs, as installed in main.js.
 */
export class DivView {
    constructor(node) {
        this.node = node;
        const div = document.createElement('div');
        div.setAttribute('id', node.attrs.id);
        div.setAttribute('class', node.attrs.cssClass);
        // Note that the click is reported using createSelectionBetween on the EditorView.
        // Here we have access to the node id and can specialize for divs.
        // Because the contentDOM is not set for non-editable divs, the selection never gets 
        // set in them, but will be set to the first selectable node after.
        div.addEventListener('click', (ev) => {
            selectedID = node.attrs.id;
        })
        div.innerHTML = node.attrs.htmlContents;
        this.dom = div;
        if (node.attrs.editable) {
            // For editable divs, set contentDom so ProseMirror handles all the rendering and interaction
            this.contentDOM = div;
        } else {
            // For non-editable divs, we have to handle all the interaction, which only occurs for buttons.
            // Note ProseMirror does not render children inside of non-editable divs. We deal with this by 
            // supplying the entire content of the div in htmlContents, and when we need to change the div
            // (for example, adding and removing a button group), we must then update the htmlContents 
            // accordingly. This happens in addDiv and removeDiv.
            const buttons = Array.from(div.getElementsByTagName('button'));
            buttons.forEach( button => {
                button.addEventListener('click', () => {
                    // Report the button that was clicked and its location
                    _callback(
                        JSON.stringify({
                            'messageType' : 'buttonClicked',
                            'id' : button.id,
                            'rect' : this._getButtonRect(button)
                        })
                    )
                })
            })
        }
    }

    /**
     * Return the rectangle of the button in a form that can be digested on the Swift side.
     * @param {HTMLButton} button 
     * @returns {Object} The button's (origin) x, y, width, and height.
     */
    _getButtonRect(button) {
        const boundingRect = button.getBoundingClientRect();
        const buttonRect = {
            'x' : boundingRect.left,
            'y' : boundingRect.top,
            'width' : boundingRect.width,
            'height' : boundingRect.height
        };
        return buttonRect;
    };

}

/**
 * The NodeView to support resizable images and Swift callbacks, as installed in main.js.
 * 
 * The ResizableImage instance holds onto the actual HTMLImageElement and deals with the styling,
 * event listeners, and resizing work.
 * 
 * Many thanks to contributors to this thread: https://discuss.prosemirror.net/t/image-resize/1489
 * and the accompanying Glitch project https://glitch.com/edit/#!/toothsome-shoemaker
 */
export class ImageView {
    constructor(node, view, getPos) {
        this.node = node;
        this.resizableImage = new ResizableImage(node, getPos)
        this.dom = this.resizableImage.imageContainer
    }
    
    selectNode() {
        this.resizableImage.imageElement.classList.add("ProseMirror-selectednode")
        this.resizableImage.select()
        selectionChanged()
    }
  
    deselectNode() {
        this.resizableImage.imageElement.classList.remove("ProseMirror-selectednode")
        this.resizableImage.deselect()
        selectionChanged()
    }

}

/**
 * A ResizableImage tracks a specific image element, and the imageContainer it is
 * contained in. The style of the container and its handles is handled in markup.css.
 *
 * As a resizing handle is dragged, the image size is adjusted. The underlying image
 * is never actually resized or changed.
 *
 * The approach of setting spans in the HTML and styling them in CSS to show the selected
 * ResizableImage, and dealing with mouseup/down/move was inspired by
 * https://tympanus.net/codrops/2014/10/30/resizing-cropping-images-canvas/
 */
class ResizableImage {
    
    constructor(node, getPos) {
        this._getPos = getPos;              // How to find node in view.state.doc
        this._minImageSize = 20             // Large enough for visibility and for the handles to display properly
        this._boundFunctions = new Map();   // Used to track functions used by event listeners so they can be removed later
        this._imageElement = this.imageElementFrom(node);
        this._imageContainer = this.containerFor(this.imageElement);
        this._startDimensions = this.dimensionsFrom(this.imageElement);
        this._startEvent = null;
        this._startDx = -1;                 // Delta x between the two touches for pinching; -1 = not pinching
        this._startDy = -1;                 // Delta y between the two touches for pinching; -1 = not pinching
        this._touchCache = [];              // Touches that are active, max 2, min 0
        this._touchStartCache = [];         // Touches at the start of a pinch gesture, max 2, min 0
    }
    
    get imageElement() {
        return this._imageElement;
    };

    get imageContainer() {
        return this._imageContainer;
    };
    
    /**
     * The startDimensions are the width/height before resizing
     */
    get startDimensions() {
        return this._startDimensions;
    };
    
    /**
     * Reset the start dimensions for the next resizing
     */
    set startDimensions(startDimensions) {
        this._startDimensions = startDimensions;
    };
    
    /*
     * Return the width and height of the image element
     */
    get currentDimensions() {
        const width = parseInt(this._imageElement.getAttribute('width'));
        const height = parseInt(this._imageElement.getAttribute('height'));
        return {width: width, height: height};
    };

    /**
     * Dispatch a transaction to the view, using its metadata to pass the src
     * of the image that just loaded. This method executes when the load 
     * or error event is triggered for the image element. The image plugin 
     * can hold state to avoid taking actions multiple times when the same 
     * image loads.
     * @param {string} src   The src attribute for the imageElement.
     */
    imageLoaded(src) {
        const transaction = view.state.tr
            .setMeta("imageLoaded", {'src': src})
        view.dispatch(transaction);
    };

    /**
     * Update the image size for the node in a transaction so that the resizing 
     * can be undone.
     * 
     * Note that after the transaction is dispatched, the ImageView is recreated, 
     * and `imageLoaded` gets called again.
     */
    imageResized() {
        const pos = this._getPos();
        const {width, height} = this.currentDimensions
        const transaction = view.state.tr
            .setNodeAttribute(pos, 'width', width)
            .setNodeAttribute(pos, 'height', height)
        transaction.setSelection(new NodeSelection(transaction.doc.resolve(pos)))
        view.dispatch(transaction);
    };

    /**
     * Return the HTML Image Element displayed in the ImageView
     * @param {Node} node 
     * @returns HTMLImageElement
     */
    imageElementFrom(node) {
        const img = document.createElement('img');
        const src = node.attrs.src

        // If the img node does not have both width and height attr, get them from naturalWidth 
        // after loading.
        img.addEventListener('load', e => {
            if (node.attrs.width && node.attrs.height) {
                img.setAttribute('width', node.attrs.width)
                img.setAttribute('height', node.attrs.height)
            } else {
                node.attrs.width = e.target.naturalWidth
                img.setAttribute('width', e.target.naturalWidth)
                node.attrs.height = e.target.naturalHeight
                img.setAttribute('height', e.target.naturalHeight)
            }
            this.imageLoaded(src)
        })

        // Notify the Swift side of any errors
        img.addEventListener('error', function () {
            this.imageLoaded(src)
        });
        
        img.setAttribute("src", src)

        return img
    }

    /**
     * Return the HTML Content Span element that contains the imageElement.
     * 
     * Note that the resizing handles, which are themselves spans, are inserted 
     * before and after the imageElement at selection time, and removed at 
     * deselect time.
     * 
     * @param {HTMLImageElement} imageElement 
     * @returns HTML Content Span element
     */
    containerFor(imageElement) {
        const imageContainer = document.createElement('span');
        imageContainer.appendChild(imageElement);
        return imageContainer
    }

    /**
     * Save the JavaScript function resulting from fn.bind(this) in the _boundFunctions Map, 
     * indexed by key.
     * 
     * We use trackFunction to create the function used in addEventListener, and then we can 
     * removeEventListener using the function returned from untrackFunction.
     * 
     * @param {string}  key     The key used to look up the bound function later.
     * @param {*}       fn      The JavaScript function to bind to this.
     * @returns  The JavaScripr function resulting from fn.bind(this)
     */
    trackFunction(key, fn) {
        const boundFn = fn.bind(this);
        this._boundFunctions.set(key, boundFn);
        return boundFn;
    }

    /**
     * Return the bound function that was tracked by key.
     * 
     * @param {string} key The key used to look up the bound function.
     * @returns A JavaScript function, typically one that was returned from .bind(this)
     */
    untrackFunction(key) {
        const boundFn = this._boundFunctions.get(key);
        this._boundFunctions.delete(key);
        return boundFn;
    }

    /**
     * Set the attributes for the imageContainer and populate the spans that show the 
     * resizing handles. Add the mousedown event listener to initiate resizing.
     */
    select() {
        this.imageContainer.setAttribute('class', 'resize-container');
        this.imageContainer.setAttribute('tabindex', -1);
        const nwHandle = document.createElement('span');
        nwHandle.setAttribute('class', 'resize-handle resize-handle-nw');
        this.imageContainer.insertBefore(nwHandle, this.imageElement);
        const neHandle = document.createElement('span');
        neHandle.setAttribute('class', 'resize-handle resize-handle-ne');
        this.imageContainer.insertBefore(neHandle, this.imageElement);
        const swHandle = document.createElement('span');
        swHandle.setAttribute('class', 'resize-handle resize-handle-sw');
        this.imageContainer.insertBefore(swHandle, null);
        const seHandle = document.createElement('span');
        seHandle.setAttribute('class', 'resize-handle resize-handle-se');
        this.imageContainer.insertBefore(seHandle, null);
        this.imageContainer.addEventListener('mousedown', this.trackFunction('mousedown', this.startResize));
        this.addPinchGestureEvents();
    }

    /**
     * Remove the attributes for the imageContainer and the spans that show the 
     * resizing handles. Remove the mousedown event listener.
     */
    deselect() {
        this.removePinchGestureEvents();
        this.imageContainer.removeEventListener('mousedown', this.untrackFunction('mousedown'));
        const handles = this.imageContainer.querySelectorAll('span');
        handles.forEach((handle) => {this.imageContainer.removeChild(handle)});
        this.imageContainer.removeAttribute('tabindex');
        this.imageContainer.removeAttribute('class');
    }

    /**
     * Return an object containing the width and height of imageElement as integers.
     * @param {HTMLImageElement} imageElement 
     * @returns An object with Int width and height.
     */
    dimensionsFrom(imageElement) {
        const width = parseInt(imageElement.getAttribute('width'));
        const height = parseInt(imageElement.getAttribute('height'));
        return {width: width, height: height};
    };
    
    /**
     * Add touch event listeners to support pinch resizing.
     *
     * Listeners are added when the resizableImage is selected.
     */
    addPinchGestureEvents() {
        document.addEventListener('touchstart', this.trackFunction('touchstart', this.handleTouchStart));
        document.addEventListener('touchmove', this.trackFunction('touchmove', this.handleTouchMove));
        document.addEventListener('touchend', this.trackFunction('touchend', this.handleTouchEnd));
        document.addEventListener('touchcancel', this.trackFunction('touchcancel', this.handleTouchEnd));
    };
    
    /**
     * Remove event listeners supporting pinch resizing.
     *
     * Listeners are removed when the resizableImage is deselected.
     */
    removePinchGestureEvents() {
        document.removeEventListener('touchstart', this.untrackFunction('touchstart'));
        document.removeEventListener('touchmove', this.untrackFunction('touchmove'));
        document.removeEventListener('touchend', this.untrackFunction('touchend'));
        document.removeEventListener('touchcancel', this.untrackFunction('touchcancel'));
    };

    /**
     * Start resize on a mousedown event.
     * @param {Event} ev    The mousedown Event.
     */
    startResize(ev) {
        ev.preventDefault();

        //TODO: Avoid selecting text while resizing.
        // Setting webkitUserSelect to 'none' used to help when the style could be applied to 
        // the actual HTML document being edited, but it doesn't seem to work when applied to 
        // view.dom. Leaving a record here for now.
        // view.state.tr.style.webkitUserSelect = 'none';  // Prevent selection of text as mouse moves

        // Use window to receive events even when cursor goes outside of the editor
        window.addEventListener('mousemove', this.trackFunction('mousemove', this.resizing));
        window.addEventListener('mouseup', this.trackFunction('mouseup', this.endResize));
        this._startEvent = ev;
        this._startDimensions = this.dimensionsFrom(this.imageElement);
    };
    
    /**
     * End resizing on a mouseup event.
     * @param {Event} ev    The mouseup Event.
     */
    endResize(ev) {
        ev.preventDefault();

        //TODO: Restore selecting text when done resizing.
        // Setting webkitUserSelect to 'text' used to help when the style could be applied to 
        // the actual HTML document being edited, but it doesn't seem to work when applied to 
        // view.dom. Leaving a record here for now.
        //view.dom.style.webkitUserSelect = 'text';  // Restore selection of text now that we are done

        window.removeEventListener('mousemove', this.untrackFunction('mousemove'));
        window.removeEventListener('mouseup', this.untrackFunction('mouseup'));
        this._startDimensions = this.currentDimensions;
        this.imageResized();
    };
    
    /**
     * Continuously resize the imageElement as the mouse moves.
     * @param {Event} ev    The mousemove Event.
     */
    resizing(ev) {
        ev.preventDefault();
        const ev0 = this._startEvent;
        // FYI: x increases to the right, y increases down
        const x = ev.clientX;
        const y = ev.clientY;
        const x0 = ev0.clientX;
        const y0 = ev0.clientY;
        const classList = ev0.target.classList;
        let dx, dy;
        if (classList.contains('resize-handle-nw')) {
            dx = x0 - x;
            dy = y0 - y;
        } else if (classList.contains('resize-handle-ne')) {
            dx = x - x0;
            dy = y0 - y;
        } else if (classList.contains('resize-handle-sw')) {
            dx = x0 - x;
            dy = y - y0;
        } else if (classList.contains('resize-handle-se')) {
            dx = x - x0;
            dy = y - y0;
        } else {
            // If not in a handle, treat movement like resize-handle-ne (upper right)
            dx = x - x0;
            dy = y0 - y;
        }
        const scaleH = Math.abs(dy) > Math.abs(dx);
        const w0 = this._startDimensions.width;
        const h0 = this._startDimensions.height;
        const ratio = w0 / h0;
        let width, height;
        if (scaleH) {
            height = Math.max(h0 + dy, this._minImageSize);
            width = Math.floor(height * ratio);
        } else {
            width = Math.max(w0 + dx, this._minImageSize);
            height = Math.floor(width / ratio);
        };
        this._imageElement.setAttribute('width', width);
        this._imageElement.setAttribute('height', height);
    };
    
    /**
     * A touch started while the resizableImage was selected.
     * Cache the touch to support 2-finger gestures only.
     */
    handleTouchStart(ev) {
        ev.preventDefault();
        if (this._touchCache.length < 2) {
            const touch = ev.changedTouches.length > 0 ? ev.changedTouches[0] : null;
            if (touch) {
                this._touchCache.push(touch);
                this._touchStartCache.push(touch);
            };
        };
    };
    
    /**
     * A touch moved while the resizableImage was selected.
     *
     * If this is a touch we are tracking already, then replace it in the touchCache.
     *
     * If we only have one finger down, the update the startCache for it, since we are
     * moving a finger but haven't start pinching.
     *
     * Otherwise, we are pinching and need to resize.
     */
    handleTouchMove(ev) {
        ev.preventDefault();
        const touch = this.touchMatching(ev);
        if (touch) {
            // Replace the touch in the touchCache with this touch
            this.replaceTouch(touch, this._touchCache)
            if (this._touchCache.length < 2) {
                // If we are only touching a single place, then replace it in the touchStartCache as it moves
                this.replaceTouch(touch, this._touchStartCache);
            } else {
                // Otherwise, we are touching two places and are pinching
                this.startPinch();   // A no-op if we have already started
                this.pinch();
            };
        }
    };
    
    /**
     * A touch ended while the resizableImage was selected.
     *
     * Remove the touch from the caches, and end the pinch operation.
     * We might still have a touch point down when one ends, but the pinch operation
     * itself ends at that time.
     */
    handleTouchEnd(ev) {
        const touch = this.touchMatching(ev);
        if (touch) {
            const touchIndex = this.indexOfTouch(touch, this._touchCache);
            if (touchIndex !== null) {
                this._touchCache.splice(touchIndex, 1);
                this._touchStartCache.splice(touchIndex, 1);
                this.endPinch();
            };
        };
    };
    
    /**
     * Return the touch in ev.changedTouches that matches what's in the touchCache, or null if it isn't there
     */
    touchMatching(ev) {
        const changedTouches = ev.changedTouches;
        const touchCache = this._touchCache;
        for (let i = 0; i < touchCache.length; i++) {
            for (let j = 0; j < changedTouches.length; j++) {
                if (touchCache[i].identifier === changedTouches[j].identifier) {
                    return changedTouches[j];
                };
            };
        };
        return null;
    };
    
    /**
     * Return the index into touchArray of touch based on identifier, or null if not found
     *
     * Note: Due to JavaScript idiocy, must always check return value against null, because
     * indices of 1 and 0 are true and false, too. Fun!
     */
    indexOfTouch(touch, touchArray) {
        for (let i = 0; i < touchArray.length; i++) {
            if (touch.identifier === touchArray[i].identifier) {
                return i;
            };
        };
        return null;
    };
    
    /**
     * Replace the touch in touchArray if it has the same identifier, else do nothing
     */
    replaceTouch(touch, touchArray) {
        const i = this.indexOfTouch(touch, touchArray);
        if (i !== null) { touchArray[i] = touch }
    };
    
    /**
     * We received the touchmove event and need to initialize things for pinching.
     *
     * If the resizableImage._startDx is -1, then we need to initialize; otherwise,
     * a call to startPinch is a no-op.
     *
     * The initialization captures a new startDx and startDy that track the distance
     * between the two touch points when pinching starts. We also track the startDimensions,
     * because scaling is done relative to it.
     */
    startPinch() {
        if (this._startDx === -1) {
            const touchStartCache = this._touchStartCache;
            this._startDx = Math.abs(touchStartCache[0].pageX - touchStartCache[1].pageX);
            this._startDy = Math.abs(touchStartCache[0].pageY - touchStartCache[1].pageY);
            this._startDimensions = this.dimensionsFrom(this._imageElement);
        };
    };

    /**
     * Pinch the resizableImage based on the information in the touchCache and the startDx/startDy
     * we captured when pinching started. The touchCache has the two touches that are active.
     */
    pinch() {
        // Here currentDx and currentDx are the current distance between the two
        // pointers, which have to be compared to the start distances to determine
        // if we are zooming in or out
        const touchCache = this._touchCache;
        const x0 = touchCache[0].pageX
        const y0 = touchCache[0].pageY
        const x1 = touchCache[1].pageX
        const y1 = touchCache[1].pageY
        const currentDx = Math.abs(x1 - x0);
        const currentDy = Math.abs(y1 - y0);
        const dx = currentDx - this._startDx;
        const dy = currentDy - this._startDy;
        const scaleH = Math.abs(dy) > Math.abs(dx);
        const w0 = this._startDimensions.width;
        const h0 = this._startDimensions.height;
        const ratio = w0 / h0;
        let width, height;
        if (scaleH) {
            height = Math.max(h0 + dy, this._minImageSize);
            width = Math.floor(height * ratio);
        } else {
            width = Math.max(w0 + dx, this._minImageSize);
            height = Math.floor(width / ratio);
        };
        this._imageElement.setAttribute('width', width);
        this._imageElement.setAttribute('height', height);
    };
    
    /**
     * The pinch operation has ended because we stopped touching one of the two touch points.
     *
     * If we are only touching one point, then endPinch is a no-op. For example, if the
     * resizableImage is selected and you touch and release at a point, endPinch gets called
     * but does nothing. Similarly for lifting the second touch point after releasing the first.
     */
    endPinch() {
        if (this._touchCache.length === 1) {
            this._startDx = -1;
            this._startDy = -1;
            this._startDimensions = this.currentDimensions;
            this.imageResized();
        };
    };
   
    /**
     * Callback to Swift with the resizableImage data that allows us to put an image
     * in the clipboard without all the browser shenanigans.
     */
    copyToClipboard() {
        const image = this._imageElement;
        if (!image) { return };
        const messageDict = {
            'messageType' : 'copyImage',
            'src' : image.src,
            'alt' : image.alt,
            'dimensions' : this._startDimensions
        };
        _callback(JSON.stringify(messageDict));
    };
    
};

/**
 * Define various arrays of tags used to represent concepts on the Swift side and internally.
 *
 * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
 */

// Add STRONG and EM (leaving B and I) to support default ProseMirror output   
const _formatTags = ['B', 'STRONG', 'I', 'EM', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];       // All possible (nestable) formats

const _minimalStyleTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE'];           // Convert to 'P' for pasteText

const _voidTags = ['BR', 'IMG', 'AREA', 'COL', 'EMBED', 'HR', 'INPUT', 'LINK', 'META', 'PARAM'] // Tags that are self-closing

/**
 * selectedID is the id of the contentEditable DIV containing the currently selected element.
 */
export let selectedID = null;

/**
 * MUError captures internal errors and makes it easy to communicate them to the
 * Swift side.
 *
 * Usage is generally via the statics defined here, altho supplementary info can
 * be provided to the MUError instance when useful.
 *
 * Alert is set to true when the user might want to know an error occurred. Because
 * this is generally the case, it's set to true by default and certain MUErrors that
 * are more informational in nature are set to false.
 *
 * Note that there is at least one instance of the Swift side notifying its MarkupDelegate
 * of an error using this same approach, but originating on the Swift side. That happens
 * in MarkupWKWebView.copyImage if anything goes wrong, because the copying to the
 * clipboard is handled on the Swift side.
 */
//MARK: Error Reporting
class MUError {

    constructor(name, message, info, alert=true) {
        this.name = name;
        this.message = message;
        this.info = info;
        this.alert = alert;
    };
    
    static NoDiv = new MUError('NoDiv', 'A div could not be found to return HTML from.');
    
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

/**
 * Called to set attributes to the editor div, typically to ,
 * set spellcheck and autocorrect. Note that contenteditable 
 * should not be set for the editor element, even if it is 
 * included in the jsonString attributes. The same attributes
 * are used for contenteditable divs, and the attribute is 
 * relevant in that case.
 */
export function setTopLevelAttributes(jsonString) {
    const attributes = JSON.parse(jsonString);
    const editor = document.getElementById('editor');
    if (editor && attributes) {   
        for (const [key, value] of Object.entries(attributes)) {
            if (key !== 'contenteditable') editor.setAttribute(key, value);
        };
    };
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
    // I'd like to use nullish coalescing on selectedID, but rollup's tree-shaking
    // actively removes it, at least until I do something with it.
    let source = '';
    if (selectedID !== null) {
        source = selectedID;
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
    const muError = new MUError('Internal', 'Break at MUError(\'Internal\'... in Safari Web Inspector to debug.');
    muError.callback()
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
 * Paste html at the selection, replacing the selection as-needed.
 */
export function pasteHTML(html) {
    const node = _nodeFromHTML(html);
    const transaction = view.state.tr.replaceSelectionWith(node, false)
    view.dispatch(transaction);
    stateChanged();
};

/**
 * Do a custom paste operation of "text only", which we will extract from the html
 * ourselves. First we get a node that conforms to the schema, which by definition 
 * only includes elements in a form we recognize, no spans, styles, etc.
 * The trick here is that we want to use the same code to paste text as we do for
 * HTML, but we want to paste something that is the MarkupEditor-equivalent of
 * unformatted text.
 */
export function pasteText(html) {
    const node = _nodeFromHTML(html);
    const htmlFragment = _fragmentFromNode(node);
    const minimalHTML = _minimalHTML(htmlFragment); // Reduce to MarkupEditor-equivalent of "plain" text
    pasteHTML(minimalHTML);
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

/********************************************************************************
 * Getting and setting document contents
 */
//MARK: Getting and Setting Document Contents

/**
 * Clean out the document and replace it with an empty paragraph
 */
export function emptyDocument() {
    selectedID = null;
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
    if (!divNode) {
        MUError.NoDiv.callback();
        return "";
    }
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
 * Set the contents of the editor.
 * 
 * The exported placeholderText is set after setting the contents.
 *
 * @param {String} contents The HTML for the editor
 */
export function setHTML(contents, select=true) {
    const state = view.state;
    const doc = state.doc;
    const tr = state.tr;
    const node = _nodeFromHTML(contents);
    const selection = new AllSelection(doc);
    const transaction = tr
        .setSelection(selection)
        .replaceSelectionWith(node, false)
        .setSelection(TextSelection.near(tr.doc.resolve(0)))
        .scrollIntoView()
    const newState = state.apply(transaction);
    placeholderText = _placeholderText;
    view.updateState(newState);
    if (select) view.focus();
};

/**
 * Internal value of placeholder text
 */
let _placeholderText;           // Hold onto the placeholder text so we can defer setting it until setHTML.

/**
 * Externally visible value of placeholder text
 */
export let placeholderText;     // What we tell ProseMirror to display as a decoration, set after setHTML.

/**
 * Set the text to use as a placeholder when the document is empty.
 * 
 * This method does not affect an existing view being displayed. It only takes effect after the 
 * HTML contents is set via setHTML. We want to set the value held in _placeholderText early and 
 * hold onto it, but because we always start with a valid empty document before loading HTML contents, 
 * we need to defer setting the exported value until later, which displays using a ProseMirror 
 * plugin and decoration.
 * 
 * @param {string} text     The text to display as a placeholder when the document is empty.
 */
export function setPlaceholder(text) {
    _placeholderText = text;
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
   const editor = document.getElementById('editor');
   const paddingBlockStart = editor.style.getPropertyValue('padding-block-start');
   const paddingBlockEnd = editor.style.getPropertyValue('padding-block-end');
   editor.style['padding-block-start'] = '0px';
   editor.style['padding-block-end'] = '0px';
   const style = window.getComputedStyle(editor, null);
   const height = parseInt(style.getPropertyValue('height'));
   editor.style['padding-block-start'] = paddingBlockStart;
   editor.style['padding-block-end'] = paddingBlockEnd;
   return height;
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
    const editor = document.getElementById('editor');
    const padHeight = fullHeight - getHeight();
    if (padHeight > 0) {
        editor.style.setProperty('--padBottom', padHeight+'px');
    } else {
        editor.style.setProperty('--padBottom', '0');
    };
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
    const {node, pos} = _firstEditableTextNode();
    const doc = view.state.doc;
    const selection = (node) ? new TextSelection(doc.resolve(pos)) : new AllSelection(doc);
    const transaction = view.state.tr.setSelection(selection);
    view.dispatch(transaction);
};

/**
 * Return the node and position of the first editable text; i.e., 
 * a text node inside of a contentEditable div.
 */
function _firstEditableTextNode() {
    const divNodeType = view.state.schema.nodes.div;
    const fromPos = TextSelection.atStart(view.state.doc).from
    const toPos = TextSelection.atEnd(view.state.doc).to
    let nodePos = {};
    let foundNode = false;
    view.state.doc.nodesBetween(fromPos, toPos, (node, pos) => {
        if ((node.type === divNodeType) && !foundNode) {
            return node.attrs.editable;
        } else if (node.isText && !foundNode) {
            nodePos = {node: node, pos: pos};
            foundNode = true;
            return false;
        } else {
            return node.isBlock && !foundNode;
        };
    });
    return nodePos;
}

/**
 * Add a div with id to parentId.
 * 
 * Note that divs that contain a static button group are created in a single call that includes 
 * the buttonGroupJSON. However, button groups can also be added and removed dynamically.
 * In that case, a button group div is added to a parent div using this call, and the parent has to 
 * already exist so that we can find it.
 */
export function addDiv(id, parentId, cssClass, attributesJSON, buttonGroupJSON, htmlContents) {
    const divNodeType = view.state.schema.nodes.div;
    const editableAttributes = (attributesJSON && JSON.parse(attributesJSON)) ?? {};
    const editable = editableAttributes.contenteditable === true;
    const buttonGroupDiv = _buttonGroupDiv(buttonGroupJSON);
    // When adding a button group div dynamically to an existing div, it will be 
    // non-editable, the htmlContent will be null, and the div will contain only buttons
    let div;
    if (buttonGroupDiv && !htmlContents && !editable) {
        div = buttonGroupDiv;
    } else {
        div = document.createElement('div');
        div.innerHTML = htmlContents ?? '<p></p>';
        if (buttonGroupDiv) div.appendChild(buttonGroupDiv);
    }
    const divSlice = _sliceFromHTML(div.innerHTML);
    const divNode = divNodeType.create({id, parentId, cssClass, editable, htmlContents: div.innerHTML}, divSlice.content);
    const transaction = view.state.tr;
    if (parentId && (parentId !== 'editor')) {
        // This path is only executed when adding a dynamic button group
        // Find the div that is the parent of the one we are adding
        const {node, pos} = _getNode(parentId, transaction.doc)
        if (node) {
            // Insert the div inside of its parent as a new child of the existing div
            const divPos = pos + node.nodeSize - 1;
            transaction.insert(divPos, divNode)
            // Now we have to update the htmlContent markup of the parent
            const $divPos = transaction.doc.resolve(divPos);
            const parent = $divPos.node();
            const htmlContents = _htmlFromFragment(_fragmentFromNode(parent));
            transaction.setNodeAttribute(pos, "htmlContents", htmlContents);
            view.dispatch(transaction);
        }
    } else {
        // This is the "normal" path when building a doc from the MarkupDivStructure.
        // Add the div to the end of the document, replacing the empty paragraph node 
        // at that position if it exists (e.g., when the doc is empty)
        const nodeSelection = NodeSelection.atEnd(transaction.doc);
        const node = nodeSelection.$anchor.node();
        if ((node.type == view.state.schema.nodes.paragraph) && (node.childCount === 0)) {
            // Replace the last empty paragraph with divNode
            nodeSelection.replaceWith(transaction, divNode);
        } else {
            // Otherwise, append this div to the end of the document
            const divPos = transaction.doc.content.size;
            transaction.insert(divPos, divNode);
        }
        view.dispatch(transaction);
    };
};

/**
 * 
 * @param {string} buttonGroupJSON A JSON string describing the button group
 * @returns HTMLDivElement
 */
function _buttonGroupDiv(buttonGroupJSON) {
    if (buttonGroupJSON) {
        const buttonGroup = JSON.parse(buttonGroupJSON);
        if (buttonGroup) {
            const buttonGroupDiv = document.createElement('div');
            buttonGroupDiv.setAttribute('id', buttonGroup.id);
            buttonGroupDiv.setAttribute('parentId', buttonGroup.parentId);
            buttonGroupDiv.setAttribute('class', buttonGroup.cssClass);
            buttonGroupDiv.setAttribute('editable', "false");   // Hardcode
            buttonGroup.buttons.forEach( buttonAttributes => {
                let button = document.createElement('button');
                button.appendChild(document.createTextNode(buttonAttributes.label));
                button.setAttribute('label', buttonAttributes.label)
                button.setAttribute('type', 'button')
                button.setAttribute('id', buttonAttributes.id);
                button.setAttribute('class', buttonAttributes.cssClass);
                buttonGroupDiv.appendChild(button);
            })
            return buttonGroupDiv; 
        }
    }
    return null;
};

export function removeDiv(id) {
    const divNodeType = view.state.schema.nodes.div;
    const {node, pos} = _getNode(id)
    if (divNodeType === node?.type) {
        const $pos = view.state.doc.resolve(pos);
        const selection = view.state.selection;
        const nodeSelection = new NodeSelection($pos);
        const transaction = view.state.tr
            .setSelection(nodeSelection)
            .deleteSelection();
        const newSelection = TextSelection.create(transaction.doc, selection.from, selection.to);
        transaction.setSelection(newSelection);
        const isButtonGroup = (node.attrs.editable == false) && (node.attrs.parentId !== 'editor') && ($pos.parent.type == divNodeType);
        if (isButtonGroup) {
            // Now we have to update the htmlContents markup of the parent
            const parent = _getNode(node.attrs.parentId, transaction.doc);
            const htmlContents = _htmlFromFragment(_fragmentFromNode(parent.node));
            transaction.setNodeAttribute(parent.pos, "htmlContents", htmlContents);
        }
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
    const buttonSlice = _sliceFromElement(button);
    const buttonNode = buttonNodeType.create({id, parentId, cssClass, label}, buttonSlice.content);
    const transaction = view.state.tr;
    if (parentId && (parentId !== 'editor')) {
        // Find the div that is the parent of the button we are adding
        const {node, pos} = _getNode(parentId, transaction.doc)
        if (node) {   // Will always be a buttonGroup div that might be empty
            // Insert the div inside of its parent as a new child of the existing div
            const divPos = pos + node.nodeSize - 1;
            transaction.insert(divPos, buttonNode);
            // Now we have to update the htmlContent markup of the parent
            const $divPos = transaction.doc.resolve(divPos);
            const parent = $divPos.node();
            const htmlContents = _htmlFromFragment(_fragmentFromNode(parent));
            transaction.setNodeAttribute(pos, "htmlContents", htmlContents);
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
    const {node, pos} = _getNode(id);
    if (node && (node.attrs.id !== selectedID)) {
        const selection = new TextSelection(view.state.doc.resolve(pos));
        const transaction = view.state.tr.setSelection(selection).scrollIntoView();
        view.dispatch(transaction);
    };
};

/**
 * Remove all divs in the document.
 */
export function removeAllDivs() {
    const allSelection = new AllSelection(view.state.doc);
    const transaction = view.state.tr.delete(allSelection.from, allSelection.to);
    view.dispatch(transaction);
};

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
function _getNode(id, doc, from, to) {
    const source = doc ?? view.state.doc;
    const fromPos = from ?? TextSelection.atStart(source).from;
    const toPos = to ?? TextSelection.atEnd(source).to;
    let foundNode, foundPos;
    source.nodesBetween(fromPos, toPos, (node, pos) => {
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
 * to be restored by endModalInput.
 * 
 * @deprecated No longer needed.
 */
export function startModalInput() {
}

/**
 * Called typically after cancelling a modal popover on the Swift side, since
 * normally the result of using the popover is to modify the DOM and reset the
 * selection.
 * 
 * @deprecated No longer needed.
 */
export function endModalInput() {
}

/********************************************************************************
 * Clean up to avoid ugly HTML
 */
//MARK: Clean Up

/**
 * Remove all children with names in node.
 * @param {[string]} names 
 * @param {HTMLElement} node 
 */
function _cleanUpTypesWithin(names, node) {
    const ucNames = names.map((name) => name.toUpperCase());
    const childNodes = node.childNodes;
    for (let i=0; i < childNodes.length; i++) {
        const child = childNodes[i];
        if (ucNames.includes(child.nodeName)) {
            node.removeChild(child);
            i--;    // Because we just removed one
        } else if (child.childNodes.length > 0) {
            _cleanUpTypesWithin(names, child);
        };
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
 * @returns {String | null} The text that is selected.
 */
function _getSelectionText() {
    const doc = view.state.doc;
    const selection = view.state.selection;
    if (selection.empty) return null;
    const fragment =  doc.cut(selection.from, selection.to).content;
    let text = '';
    fragment.nodesBetween(0, fragment.size, (node) => {
        if (node.isText) {
            text += node.text;
            return false;
        }
        return true;
    })
    return (text.length === 0) ? null : text;
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

export function postMessage(message) {
    _callback(JSON.stringify(message))
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
 * For testing purposes, create a ProseMirror Node that conforms to the 
 * MarkupEditor schema and return the resulting html as a string. 
 * Testing in this way lets us do simple pasteHTML tests with
 * clean HTML and test the effect of schema-conformance on HTML contents
 * separately. The html passed here is (typically) obtained from the paste 
 * buffer on the Swift side.
 */
export function testPasteHTMLPreprocessing(html) {
    const node = _nodeFromHTML(html);
    const fragment = _fragmentFromNode(node);
    return _htmlFromFragment(fragment);
};

/**
 * Use the same approach as testPasteHTMLPreprocessing, but augment with 
 * _minimalHTML to get a MarkupEditor-equivalent of unformatted text.
 */
export function testPasteTextPreprocessing(html) {
    const node = _nodeFromHTML(html);
    const fragment = _fragmentFromNode(node);
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
 * Return a ProseMirror Node derived from HTML text.
 * 
 * Since the schema for the MarkupEditor accepts div and buttons, clean them from the 
 * html before deriving a Node. Cleaning up means retaining the div contents while removing
 * the divs, and removing buttons.
 * @param {string} html 
 * @returns Node
 */
function _nodeFromHTML(html) {
    const fragment = _fragmentFromHTML(html);
    const body = fragment.body ?? fragment;
    _cleanUpDivsWithin(body);
    _cleanUpTypesWithin(['button'], body);
    return _nodeFromElement(body);
};

/**
 * Return a ProseMirror Node derived from an HTMLElement.
 * @param {HTMLElement} htmlElement 
 * @returns Node
 */
function _nodeFromElement(htmlElement) {
    return DOMParser.fromSchema(view.state.schema).parse(htmlElement, { preserveWhiteSpace: true });
}

/**
 * Return an HTML DocumentFragment derived from a ProseMirror node.
 * @param {Node} node 
 * @returns DocumentFragment
 */
function _fragmentFromNode(node) {
    return DOMSerializer.fromSchema(view.state.schema).serializeFragment(node.content);
};

/**
 * Return a Node derived from the node type's toDOM method.
 * @param {Node} node
 * @returns HTMLElement
 */
function _elementFromNode(node) {
    return node.type.spec.toDOM(node)
}

/**
 * Return an HTML DocumentFragment derived from HTML text.
 * @param {string} html 
 * @returns DocumentFragment
 */
function _fragmentFromHTML(html) {
    const template = document.createElement('template');
    template.innerHTML = html;
    return template.content;
};

/**
 * Return a ProseMirror Slice derived from HTML text.
 * @param {string} html 
 * @returns Slice
 */
function _sliceFromHTML(html) {
    const div = document.createElement('div');
    div.innerHTML = html ?? "";
    return _sliceFromElement(div);
};

/**
 * Return a ProseMirror Slice derived from an HTMLElement.
 * @param {HTMLElement} htmlElement 
 * @returns Slice
 */
function _sliceFromElement(htmlElement) {
    return DOMParser.fromSchema(view.state.schema).parseSlice(htmlElement, { preserveWhiteSpace: true });
}

/**
 * Return the innerHTML string contained in a DocumentFragment.
 * @param {DocumentFragment} fragment 
 * @returns string
 */
function _htmlFromFragment(fragment) {
    const div = document.createElement('div');
    div.appendChild(fragment);
    return div.innerHTML;
};

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

/**
 * Return whether node is a format element; i.e., its nodeName is in _formatTags
 */
function _isFormatElement(node) {
    return _isElementNode(node) && _formatTags.includes(node.nodeName);
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
 * Callback into Swift to show a string in the Xcode console, like console.log()
 */
function _consoleLog(string) {
    let messageDict = {
        'messageType' : 'log',
        'log' : string
    }
    _callback(JSON.stringify(messageDict));
};

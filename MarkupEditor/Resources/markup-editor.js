/* global MU */

// Track a global indicating that the MarkupEditor base script was loaded
window.markupEditorScriptLoaded = false

/**
 * MarkupEditorElement is the Web Component for the MarkupEditor.
 * 
 * The lifecycle and resulting document structure are probably the most interesting 
 * aspects of the MarkupEditorElement, especially because the HTML page can   
 * contain multiple of them. The MarkupEditor "base" script should be loaded 
 * only once in the first (or only) MarkupEditorElement. It defines the global
 * `MU` along with the global `muRegistry` with exported methods to access it.
 * 
 * We use the `connectedCallback`, which is called for each MarkupEditorElement, 
 * to trigger appending the MarkupEditor base script only once. It's loaded into 
 * the first MarkupEditorElement, and produces the global `MU` that provides access
 * to all editor functionality regardless of where subsequent scripts are run.
 * When the base script finishes loading, we dispatch the `ready` `muCallback` 
 * event for each MarkupEditorElement instance in `document`. From that point, 
 * the MarkupEditor styling is appended to the `editor` set up for each individual 
 * MarkupEditorElement instance. Any user-supplied script and styling are also 
 * appended. Once those are appended (and even if they are not specified), the 
 * `loadedUserFiles` `muCallback` is dispatched for the `editorContainer`, and 
 * we can finally `createEditor` for the element and set its HTML contents.
 */
class MarkupEditorElement extends HTMLElement {

  /** 
   * Construct the MarkupEditorElement and set up the events to listen-to that 
   * drive loading of scripts, styles, configuration, and contents.
   */
  constructor() {
    super()   // Establish prototype chain

    // Attach shadow tree and hold onto root reference
    // https://developer.mozilla.org/en-US/docs/Web/API/Element/attachShadow
    const shadow = this.attachShadow({ mode: 'open' })

    // Create a container for the markup-editor component
    this.editorContainer = document.createElement('div')
    // Add a class to the container for the sake of clarity
    this.editorContainer.classList.add('markup-editor')
    this.editorContainer.setAttribute('id', 'editor')

    // The `muCallback` `ready` event is dispatched to *each* MarkupEditorElement 
    // in the document. Each MarkupEditorElement instance then calls 
    // `appendEditorStyle` to load `markupeditor.css`, which has to be loaded 
    // for each instance of MarkupEditorElement, since the actual `editor` 
    // element (i.e., `this.editorContainer`) is in the shadow DOM.

    // Have this MarkupEditorElement instance listen for the `ready` callback
    // that is dispatched from `loadedEditorScript`.
    this.addEventListener('muCallback', (e) => {
      switch (e.message) {
        case 'ready':
          this.appendEditorStyle()
          break
        default:
          console.log('Unexpected muCallback to MarkupEditorElement: ', e.message)
      }
    })

    // Have the `editorContainer` listen for callbacks from within the 
    // MarkupEditor base script, dispatched from `_callback`. The
    // `messageHandler` can be overridden (as it is for VSCode and 
    // Swift) so all document editing notifications can be dealt 
    // with in a custom way.
    //
    // Note that while `ready` is a notification to `this` dispatched 
    // to every MarkupEditorElement from `loadedEditorScript` within this 
    // script, other editing events are dispatched to `editorContainer` 
    // from within the MarkupEditor base script.
    // 
    // The first `muCallback` will be `loadedUserFiles`, which will 
    // cause the editor instance to be created before posting the 
    // message.
    this.editorContainer.addEventListener('muCallback', (e) => {
      if (!this.editor) this.createEditor()
      this.editor.messageHandler.postMessage(e.message)
    })

    // Append the container to the shadow DOM
    // The rest of the initialization happens in the `connectedCallback`
    shadow.appendChild(this.editorContainer)
  }

  /**
   * Fires after the MarkupEditorElement instance has been attached to the DOM.
   *  
   * If no MarkupEditorElement has yet been connected, we invoke `appendEditorScript`
   * to cause the MarkupEditor script, `markupeditor.umd.js`, to load at the end 
   * of `body`. This means the MarkupEditor script is loaded only once. When the 
   * MarkupEditorScript has loaded, it dispatches a `muCallback` event on each 
   * MarkupEditorElement in the `document`, which in turn creates a properly 
   * configured MarkupEditor instance.
   */ 
  connectedCallback() {
    this.appendEditorScript()
  }

  /**
   * Fires when the MarkupEditorElement instance is removed from the DOM.
   * 
   * In the spirit of undoing what `connectedCallback` did, we have to destroy
   * the ProseMirror EditorView held by the MarkupEditor instance in `this.editor`
   * as well as remove it from the `window.viewRegistry`. The editor does this in 
   * its `destroy` method.
   */
  disconnectedCallback() {
    this.editor.destroy();
	}

  /**
   * Dispatch a `muCallback` event on `element`.
   * @param {String} message        The message (could be stringified JSON) to be dispatch to `element`
   * @param {HTMLElement} element   The HTMLElement that should be listening for `muCallback`.
   */
  dispatchMuCallback(message, element) {
    const muCallback = new CustomEvent("muCallback")
    muCallback.message = message
    element.dispatchEvent(muCallback)
  }

  /**
   * Append the MarkupEditor script to the body only once.
   * 
   * The MarkupEditor script will dispatch a muCallback('ready') to this instance 
   * that results in `appendEditorStyle` being called next.
   */
  appendEditorScript() {
    if (window.markupEditorScriptLoaded) return  // Only load it once
    window.markupEditorScriptLoaded = true
    const muScript = this.getAttribute('muScript') ?? './markupeditor.umd.js'
    const nonce = this.getAttribute('nonce')
    const baseScript = document.createElement('script')
    if (nonce) baseScript.setAttribute('nonce', nonce)
    baseScript.setAttribute('src', muScript)
    baseScript.addEventListener('load', this.loadedEditorScript.bind(this))
    this.editorContainer.appendChild(baseScript)
  }

  /**
   * The MarkupEditor base styling, markupeditor.css loaded.
   * 
   * Dispatch the `ready` `muCallback` to each MarkupEditorElement.
   * Called once after the MarkupEditor base script has loaded.
   */
  loadedEditorScript() {
    const webComponents = document.querySelectorAll('markup-editor')
    webComponents.forEach((element) => {
      this.dispatchMuCallback('ready', element)
    })
  }

  /**
   * Append the MarkupEditor styling to the `editorContainer`, because they should be styled independently 
   * of the document they are embedded in.
   * 
   * Upon loading, invoke `loadUserFiles` with any user-specified script and styling that will follow 
   * the MarkupEditor styling. The `loadUserFiles` results in a `loadedUserFiles` `muCallback` that 
   * (finally) creates the MarkupEditor and sets its HTML.
   */
  appendEditorStyle() {
    const muStyle = this.getAttribute('mustyle') ?? './markupeditor.css'
    const link = document.createElement('link')
    link.setAttribute('href', muStyle)
    link.setAttribute('rel', 'stylesheet')
    const userStyle = this.getAttribute('userstyle')
    const userScript = this.getAttribute('userscript')
    const nonce = this.getAttribute('nonce')
    link.onload = () => { MU.loadUserFiles(userScript, userStyle, this.editorContainer, nonce) }
    this.editorContainer.appendChild(link)
  }

  /**
   * Create the MarkupEditor instance for this MarkupEditorElement.
   * 
   * Use the attributes from the <markup-editor> element to set up the 
   * configuration. Set the initial HTML based on the `innerHTML` for the 
   * <markup-editor> element, which will be overridden by `filename` contents 
   * if it it specified and if the editor is running in an environment that 
   * has access to the file system (e.g., node.js, but not a browser).
   */
  createEditor() {
    const html = (this.innerHTML.length == 0) ? null : this.innerHTML
    const filename = this.getAttribute('filename')
    const config = { 
      filename: filename, 
      html: html,
      base: this.getAttribute('base'),
      placeholder: this.getAttribute('placeholder'), 
      delegate: this.getAttribute('delegate'),
      handler: this.getAttribute('handler'),
      toolbar: this.getAttribute('toolbar'),
      behavior: this.getAttribute('behavior'),
      keymap: this.getAttribute('keymap'),
      prepend: this.getAttribute('prepend'),
      append: this.getAttribute('append'),
    }
    this.editor = new MU.MarkupEditor(this.editorContainer, config)
    
    this.editor.config.delegate?.markupReady && this.editor.config.delegate?.markupReady()

    // Prepend and/or append any augmentations
    const prependItems = MU.getAugmentation(config.prepend)?.menuItems
    if (prependItems) MU.prependToolbar(prependItems)
    const appendItems = MU.getAugmentation(config.append)?.menuItems
    if (appendItems) MU.appendToolbar(appendItems)

    // Whether this editor takes focus (and shows the keyboard on iOS) is 
    // set in BehaviorConfig, which can be overridden using a registered
    // instance whose name is passed as an attribute of this element. If 
    // not overridden, the default `true` behavior is used.
    //const focusAfterLoad = this.editor.config.behavior.focusAfterLoad

    // Set the initial HTML contents based on `filename` or the innerHTML
    //if (!config.filename) {
    //  MU.setHTML(html, focusAfterLoad, config.base, this.editor.view)
    //} else {
    //  fetch(filename)
    //    .then((response) => response.text())
    //    .then((text) => {
    //      MU.setHTML(text, focusAfterLoad, config.base, this.editor.view)
    //    })
    //    .catch((error) => {
    //      MU.setHTML(
    //        `
    //        <p>
    //            Failed to load ${filename}.
    //            Error message: ${error.message}.
    //            You may be trying to load HTML from a local file in a browser.
    //        </p>
    //        `, null, null, this.editor.view)
    //    });
    //}
  }

}

// Let the browser know about the custom element
customElements.define('markup-editor', MarkupEditorElement)

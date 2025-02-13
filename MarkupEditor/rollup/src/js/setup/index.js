import {keymap} from "prosemirror-keymap"
import {history} from "prosemirror-history"
import {baseKeymap} from "prosemirror-commands"
import {AllSelection, NodeSelection, Plugin} from "prosemirror-state"
import {dropCursor} from "prosemirror-dropcursor"
import {gapCursor} from "prosemirror-gapcursor"
import {Decoration, DecorationSet} from "prosemirror-view"
import {search } from "prosemirror-search"

import {menuBar} from "../menu/menubar"
import {buildMenuItems} from "./menu"
import {buildKeymap} from "./keymap"
import {buildInputRules} from "./inputrules"

import {placeholderText, postMessage, selectedID, stateChanged, searchIsActive} from "../markup"

export {buildMenuItems, buildKeymap, buildInputRules}

// !! This module exports helper functions for deriving a set of basic
// menu items, input rules, or key bindings from a schema. These
// values need to know about the schema for two reasons—they need
// access to specific instances of node and mark types, and they need
// to know which of the node and mark types that they know about are
// actually present in the schema.

/**
 * The MarkupEditor plugin, aka `muPlugin`, handles decorations that add CSS styling 
 * we want to see reflected in the view. The node `attrs` for styling are, as needed, 
 * also produced in the `toDOM` definition in the schema, but they do not seem 
 * to reliably affect the view when changed during editing.
 */
const muPlugin = new Plugin({
  state: {
    init(_, {doc}) {
      return DecorationSet.create(doc, [])
    },
    apply(tr, set) {
      if (tr.getMeta("bordered-table")) {
        const {border, fromPos, toPos} = tr.getMeta("bordered-table")
        return DecorationSet.create(tr.doc, [
          Decoration.node(fromPos, toPos, {class: "bordered-table-" + border})
        ])
      } else if (set) {
        // map "other" changes so our decoration "stays put" 
        // (e.g. user is typing so decoration's pos must change)
        return set.map(tr.mapping, tr.doc)
      }
    }
  },
  props: {
    decorations: (state) => { return muPlugin.getState(state) }
  }
})

const searchModePlugin  = new Plugin({
  state: {
    init(_, {doc}) {
      return DecorationSet.create(doc, [])
    },
    apply(tr, set) {
      if (tr.getMeta("search$")) {
        if (searchIsActive()) {
          // This only sets class=searching for the first node in doc, I am not sure why.
          // TODO: Fix. I have some commented-out versions of things I tried that work even less well.
          const nodeSelection = new NodeSelection(tr.doc.resolve(0));
          const decoration = Decoration.node(nodeSelection.from, nodeSelection.to, {class: 'searching'})
          //const decoration = Decoration.widget(0, selectingDOM);
          //const allSelection = new AllSelection(tr.doc);
          //const decoration = Decoration.node(allSelection.from, allSelection.to, {class: "searching"});
          return DecorationSet.create(tr.doc, [decoration])
        }
      } else if (set) {
        // map "other" changes so our decoration "stays put" 
        // (e.g. user is typing so decoration's pos must change)
        return set.map(tr.mapping, tr.doc)
      }
    }
  },
  props: {
    decorations: (state) => { return searchModePlugin.getState(state) }
  }
})

/**
 * The imagePlugin handles the interaction with the Swift side that we need for images.
 * Specifically, we want notification that an image was added at load time, but only once. 
 * The loaded event can fire multiple times, both when the initial ImageView is created 
 * as an img element is found, but also whenever the ImageView is recreated. This happens
 * whenever we resize and image and dispatch a transaction to update its state.
 * 
 * We want a notification on the Swift side for the first image load, because when we insert 
 * a new image, that new image is placed in cached storage but has not been saved for the doc.
 * This is done using postMessage to send "addedImage", identifying the src. However, we don't 
 * want to tell the Swift side we added an image every time we resize it. To deal with this 
 * problem, we set "imageLoaded" metadata in the transaction that is dispatched on at load. The 
 * first time, we update the Map held in the imagePlugin. When we resize, the image loads again 
 * as the ImageView gets recreated, but in the plugin, we can check the Map to see if we already 
 * loaded it once and avoid notifying the Swift side multiple times.
 * 
 * The Map is keyed by the src for the image. If the src is duplicated in the document, we only 
 * get one "addedImage" notification.
 */
const imagePlugin = new Plugin({
  state: {
    init() {
      return new Map()
    },
    apply(tr, srcMap) {
      if (tr.getMeta("imageLoaded")) {
        const src = tr.getMeta("imageLoaded").src
        const srcIsLoaded = srcMap.get(src) == true
        if (!srcIsLoaded) {
          srcMap.set(src, true)
          postMessage({ 'messageType': 'addedImage', 'src': src, 'divId': (selectedID ?? '') });
        }
        stateChanged()
      }
      return srcMap
    }
  },
  props: {
    attributes: (state) => { return imagePlugin.getState(state) }
  }
  
})

/**
 * A simple plugin to show placeholder text when the document is empty.
 * 
 * The placeholder text is imported from markup.js and is set there via setPlaceholder.
 * 
 * Adapted from https://discuss.prosemirror.net/t/how-to-input-like-placeholder-behavior/705/3
 * 
 * @returns {Plugin}
 */
const placeholderPlugin = new Plugin({
  props: {
    decorations(state) {
      if (!placeholderText) return;   // No need to mess around if we have no placeholder
      const doc = state.doc
      if (doc.childCount == 1 && doc.firstChild.isTextblock && doc.firstChild.content.size == 0) {
        const allSelection = new AllSelection(doc);
        // The attributes are applied to the empty paragraph and styled based on editor.css
        const decoration = Decoration.node(allSelection.from, allSelection.to, {class: 'placeholder', placeholder: placeholderText});
        return DecorationSet.create(doc, [decoration])
      }
    }
  }
})

// :: (Object) → [Plugin]
// A convenience plugin that bundles together a simple menu with basic
// key bindings, input rules, and styling for the example schema.
// Probably only useful for quickly setting up a passable
// editor—you'll need more control over your settings in most
// real-world situations.
//
//   options::- The following options are recognized:
//
//     schema:: Schema
//     The schema to generate key bindings and menu items for.
//
//     mapKeys:: ?Object
//     Can be used to [adjust](#example-setup.buildKeymap) the key bindings created.
//
//     menuBar:: ?bool
//     Set to false to disable the menu bar.
//
//     history:: ?bool
//     Set to false to disable the history plugin.
//
//     floatingMenu:: ?bool
//     Set to false to make the menu bar non-floating.
//
//     menuContent:: [[MenuItem]]
//     Can be used to override the menu content.
export function markupSetup(options) {
  let plugins = [
    buildInputRules(options.schema),
    keymap(buildKeymap(options.schema, options.mapKeys)),
    keymap(baseKeymap),
    dropCursor(),
    gapCursor(),
  ]
  if (options.menuBar !== false)
    plugins.push(menuBar({floating: options.floatingMenu !== false,
                          content: options.menuContent || buildMenuItems(options.schema).fullMenu}))
  if (options.history !== false)
    plugins.push(history())

  // Add the MarkupEditor plugin
  plugins.push(muPlugin);

  // Add the plugin that handles placeholder display for an empty document
  plugins.push(placeholderPlugin)

  // Add the plugin to handle notifying the Swift side of images loading
  plugins.push(imagePlugin)

  // Add the plugins that performs search, decorates matches, and indicates searchmode
  plugins.push(search())
  plugins.push(searchModePlugin)

  return plugins;
}

import {keymap} from "prosemirror-keymap"
import {history} from "prosemirror-history"
import {baseKeymap} from "prosemirror-commands"
import {AllSelection, Plugin} from "prosemirror-state"
import {dropCursor} from "prosemirror-dropcursor"
import {gapCursor} from "prosemirror-gapcursor"
import {Decoration, DecorationSet} from "prosemirror-view"

import {menuBar} from "../menu/menubar"
import {buildMenuItems} from "./menu"
import {buildKeymap} from "./keymap"
import {buildInputRules} from "./inputrules"

import { placeholderText } from "../markup"

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
      } else {
         // map "other" changes so our decoration "stays put" 
         // (e.g. user is typing so decoration's pos must change)
        return set.map(tr.mapping, tr.doc)
      }
    }
  },
  props: {
    decorations: (state) => { return muPlugin.getState(state) },
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

  return plugins;
}

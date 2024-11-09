import {EditorState, TextSelection} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "./schema/index.js"
import {addListNodes} from "prosemirror-schema-list"
import {markupSetup} from "./setup/index.js"
import {tableNodes} from "prosemirror-tables"

import {
  setTopLevelAttributes,
  loadUserFiles,
  searchFor,
  deactivateSearch,
  cancelSearch,
  pasteText,
  pasteHTML,
  emptyDocument,
  getHTML,
  setHTML,
  setPlaceholder,
  getHeight,
  padBottom,
  focus,
  resetSelection,
  addDiv,
  removeDiv,
  addButton,
  removeButton,
  scrollIntoView,
  removeAllDivs,
  toggleBold,
  toggleItalic,
  toggleUnderline,
  toggleCode,
  toggleStrike,
  toggleSubscript,
  toggleSuperscript,
  setStyle,
  replaceStyle,
  toggleListItem,
  indent,
  outdent,
  startModalInput,
  endModalInput,
  cleanUpHTML,
  getSelectionState,
  stateChanged,
  setRange,
  testUndo,
  testRedo,
  testBlockquoteEnter,
  testListEnter,
  testExtractContents,
  testPasteHTMLPreprocessing,
  testPasteTextPreprocessing,
  insertLink,
  deleteLink,
  insertImage,
  modifyImage,
  cutImage,
  insertTable,
  addRow,
  addCol,
  addHeader,
  deleteTableArea,
  borderTable,
} from "./markup.js"

export {
  setTopLevelAttributes,
  loadUserFiles,
  searchFor,
  deactivateSearch,
  cancelSearch,
  pasteText,
  pasteHTML,
  emptyDocument,
  getHTML,
  setHTML,
  setPlaceholder,
  getHeight,
  padBottom,
  focus,
  resetSelection,
  addDiv,
  removeDiv,
  addButton,
  removeButton,
  scrollIntoView,
  removeAllDivs,
  toggleBold,
  toggleItalic,
  toggleUnderline,
  toggleCode,
  toggleStrike,
  toggleSubscript,
  toggleSuperscript,
  setStyle,
  replaceStyle,
  toggleListItem,
  indent,
  outdent,
  startModalInput,
  endModalInput,
  cleanUpHTML,
  getSelectionState,
  stateChanged,
  setRange,
  testUndo,
  testRedo,
  testBlockquoteEnter,
  testListEnter,
  testExtractContents,
  testPasteHTMLPreprocessing,
  testPasteTextPreprocessing,
  insertLink,
  deleteLink,
  insertImage,
  modifyImage,
  cutImage,
  insertTable,
  addRow,
  addCol,
  addHeader,
  deleteTableArea,
  borderTable,
}

// Mix the nodes from prosemirror-schema-list and prosemirror-tables into the basic schema
// to create a schema with list and table support.
const mySchema = new Schema({
  nodes: 
    addListNodes(schema.spec.nodes, "paragraph block*", "block").append(
      tableNodes({
        tableGroup: 'block',
        cellContent: 'block+',
        cellAttributes: {
          background: {
            default: null,
            getFromDOM(dom) {
              return dom.style.backgroundColor || null;
            },
            setDOMAttr(value, attrs) {
              if (value)
                attrs.style = (attrs.style || '') + `background-color: ${value};`;
            },
          },
        },
      }
    ),
  ),
  marks: schema.spec.marks
})

window.view = new EditorView(document.querySelector("#editor"), {
  state: EditorState.create({
    doc: DOMParser.fromSchema(mySchema).parse(document.querySelector("#content")),
    plugins: markupSetup({schema: mySchema})
  }),
  dispatchTransaction(transaction) {
    let newState = view.state.apply(transaction)
    view.updateState(newState)
    stateChanged()    // For every transaction, let the Swift side know the state changed
  }
})

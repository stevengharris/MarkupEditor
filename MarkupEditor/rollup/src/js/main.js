import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "./schema/markup.js"
import {addListNodes} from "prosemirror-schema-list"
import {markupSetup} from "./setup/markup.js"

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
  deleteTable,
  deleteRow,
  deleteCol,
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
  deleteTable,
  deleteRow,
  deleteCol,
  borderTable,
}

// Mix the nodes from prosemirror-schema-list into the basic schema to
// create a schema with list support.
const mySchema = new Schema({
  nodes: addListNodes(schema.spec.nodes, "paragraph block*", "block"),
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
    stateChanged()
  }

})

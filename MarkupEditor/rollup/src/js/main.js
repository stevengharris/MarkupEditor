import {EditorState} from "prosemirror-state"
import {EditorView} from "prosemirror-view"
import {Schema, DOMParser} from "prosemirror-model"
import {schema} from "./schema/index.js"
import {markupSetup} from "./setup/index.js"

import {
  ImageView,
  DivView,
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
  focusOn,
  resetSelection,
  addDiv,
  removeDiv,
  addButton,
  removeButton,
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
  getSelectionState,
  selectionChanged,
  clicked,
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
  focusOn,
  resetSelection,
  addDiv,
  removeDiv,
  addButton,
  removeButton,
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
  getSelectionState,
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

const muSchema = new Schema({
  nodes: schema.spec.nodes,
  marks: schema.spec.marks
})

window.view = new EditorView(document.querySelector("#editor"), {
  state: EditorState.create({
    // For the MarkupEditor, we can just use the editor element. 
    // There is mo need to use a separate content element.
    doc: DOMParser.fromSchema(muSchema).parse(document.querySelector("#editor")),
    plugins: markupSetup({
      menuBar: false,   // TODO: We need a way to make this configurable at setup time
      schema: muSchema
    })
  }),
  nodeViews: {
    image(node, view, getPos) { return new ImageView(node, view, getPos) },
    div(node, view, getPos) { return new DivView(node, view, getPos) },
  },
  handleTextInput() {
    stateChanged();
    return false; // All the default behavior should occur
  },
  // Use createSelectionBetween to handle selection and click both.
  // Note that we handle button clicks in non-editable divs in DivView, since 
  // they can't be selected.
  createSelectionBetween() {
    selectionChanged();
    clicked();
    return null; // All the default behavior should occur
  }
})

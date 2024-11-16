import {EditorState, Plugin} from "prosemirror-state"
import {EditorView, Decoration, DecorationSet} from "prosemirror-view"
import {Schema, DOMParser, DOMSerializer} from "prosemirror-model"
import {schema} from "./schema/index.js"
import {markupSetup} from "./setup/index.js"

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

// Mix the nodes from prosemirror-schema-list into the MarkupEditor schema to create a schema with list support.
//let muNodes = addListNodes(schema.spec.nodes, 'paragraph block*', 'block');

const muSchema = new Schema({
  nodes: schema.spec.nodes,
  marks: schema.spec.marks
})

window.view = new EditorView(document.querySelector("#editor"), {
  state: EditorState.create({
    doc: DOMParser.fromSchema(muSchema).parse(document.querySelector("#content")),
    plugins: markupSetup({schema: muSchema})
  }),
  nodeViews: {
    image(node, view, getPos) { return new ImageView(node, view, getPos) },
    //table(node, view, getPos) { return new TableView(node, view, getPos) }
  },
  //handleClick() {
  //  console.log("handleClick")
  //  stateChanged();
  //},
  //handleTextInput(view, from, to, text) {
  //  console.log("handleClick: " + text)
  //  stateChanged();
  //  return false; // All the default behavior should occur
  //},
  dispatchTransaction(transaction) {
    let newState = view.state.apply(transaction)
    view.updateState(newState)
    stateChanged()    // For every transaction, let the Swift side know the state changed
  }
})

class ImageView {
  constructor(node, view, getPos) {
    this.dom = document.createElement("img")
    this.dom.src = node.attrs.src
    this.dom.alt = node.attrs.alt
    this.dom.addEventListener("click", e => {
      e.preventDefault()
      let alt = prompt("New alt text:", "")
      if (alt) view.dispatch(view.state.tr.setNodeMarkup(getPos(), null, {
        src: node.attrs.src,
        alt
      }))
    })
  }

  stopEvent() { return true }
}

class TableView {

  constructor(node, view, getPos) {
    this.node = node;
    this.dom = document.createElement("table")
    if(node.attrs.class){
      this.dom.setAttribute("class", node.attrs.class);
    }
    const fragment = DOMSerializer.fromSchema(view.state.schema).serializeFragment(node.content);
    const div = document.createElement('div');
    const tbody = document.createElement('tbody');
    tbody.appendChild(fragment);
    div.appendChild(tbody);
    this.dom.innerHTML = div.innerHTML;
    // The contentDOM sets the area that is selectable and editable in ProseMirror.
    this.contentDOM = this.dom.querySelector("tbody");
  }

  update(node, decorations) {
    return node.type === view.state.schema.nodes.table
  }

}

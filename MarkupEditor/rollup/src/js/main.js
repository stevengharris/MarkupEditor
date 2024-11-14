import {EditorState} from "prosemirror-state"
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

// Mix the nodes from prosemirror-schema-list into the basic schema to create a schema with list support.
let muNodes = addListNodes(schema.spec.nodes, 'paragraph block*', 'block');
// Get the object defining table nodes from prosemirror-tables
let tNodes = tableNodes({
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
  }
});
/* At this point, tNodes.table is:
table: {
    content: 'table_row+',
    tableRole: 'table',
    isolating: true,
    group: options.tableGroup,
    parseDOM: [{ tag: 'table' }],
    toDOM() {
      return ['table', ['tbody', 0]];
    },
  },
but we need to support the class definition to support bordering
*/
tNodes.table.attrs = {class: {default: null}};
tNodes.table.parseDOM = [{tag: 'table', getAttrs(dom) {
  return {class: dom.getAttribute('class')}
}}]
tNodes.table.toDOM = (node)=> { let tClass = node.attrs; return ['table', tClass, 0] };
// Now append the modified tNodes to muNodes and create the schema
muNodes = muNodes.append(tNodes);

const muSchema = new Schema({
  nodes: muNodes,
  marks: schema.spec.marks
})

window.view = new EditorView(document.querySelector("#editor"), {
  state: EditorState.create({
    doc: DOMParser.fromSchema(muSchema).parse(document.querySelector("#content")),
    plugins: markupSetup({schema: muSchema})
  }),
  dispatchTransaction(transaction) {
    let newState = view.state.apply(transaction)
    view.updateState(newState)
    stateChanged()    // For every transaction, let the Swift side know the state changed
  }
})

import {Schema} from "prosemirror-model"
import {tableNodes} from "prosemirror-tables"
import {addListNodes} from "prosemirror-schema-list"
import {default as OrderedMap} from "orderedmap"

const pDOM = ["p", 0], 
      blockquoteDOM = ["blockquote", 0], 
      hrDOM = ["hr"],
      preDOM = ["pre", ["code", 0]], 
      brDOM = ["br"]

let baseNodes = OrderedMap.from({
  // :: NodeSpec The top level document node.
  doc: {
    content: "block+"
  },

  // :: NodeSpec A plain paragraph textblock. Represented in the DOM
  // as a `<p>` element.
  paragraph: {
    content: "inline*",
    group: "block",
    parseDOM: [{tag: "p"}],
    toDOM() { return pDOM }
  },

  // :: NodeSpec A blockquote (`<blockquote>`) wrapping one or more blocks.
  blockquote: {
    content: "block+",
    group: "block",
    defining: true,
    parseDOM: [{tag: "blockquote"}],
    toDOM() { return blockquoteDOM }
  },

  // :: NodeSpec A horizontal rule (`<hr>`).
  horizontal_rule: {
    group: "block",
    parseDOM: [{tag: "hr"}],
    toDOM() { return hrDOM }
  },

  // :: NodeSpec A heading textblock, with a `level` attribute that
  // should hold the number 1 to 6. Parsed and serialized as `<h1>` to
  // `<h6>` elements.
  heading: {
    attrs: {level: {default: 1}},
    content: "inline*",
    group: "block",
    defining: true,
    parseDOM: [{tag: "h1", attrs: {level: 1}},
               {tag: "h2", attrs: {level: 2}},
               {tag: "h3", attrs: {level: 3}},
               {tag: "h4", attrs: {level: 4}},
               {tag: "h5", attrs: {level: 5}},
               {tag: "h6", attrs: {level: 6}}],
    toDOM(node) { return ["h" + node.attrs.level, 0] }
  },

  // :: NodeSpec A code listing. Disallows marks or non-text inline
  // nodes by default. Represented as a `<pre>` element with a
  // `<code>` element inside of it.
  code_block: {
    content: "text*",
    marks: "",
    group: "block",
    code: true,
    defining: true,
    parseDOM: [{tag: "pre", preserveWhitespace: "full"}],
    toDOM() { return preDOM }
  },

  // :: NodeSpec The text node.
  text: {
    group: "inline"
  },

  // :: NodeSpec An inline image (`<img>`) node. Supports `src`,
  // `alt`, and `href` attributes. The latter two default to the empty
  // string.
  image: {
    inline: true,
    attrs: {
      src: {},
      alt: {default: null},
      width: {default: null},
      height: {default: null},
      scale: {default: null}
    },
    group: "inline",
    parseDOM: [{
      tag: "img[src]", 
      getAttrs(dom) {
        const width = dom.getAttribute("width") && parseInt(dom.getAttribute("width"));
        const height = dom.getAttribute("height") && parseInt(dom.getAttribute("height"));
        const scale = (width && dom.naturalWidth) ? 100 * width / dom.naturalWidth : null;
        return {
          src: dom.getAttribute("src"),
          alt: dom.getAttribute("alt"),
          width: width,
          height: height,
          scale: scale
        }
      }
    }],
    toDOM(node) { let {src, alt, width, height, scale} = node.attrs; return ["img", {src, alt, width, height, scale}] }
  },

  // :: NodeSpec A hard line break, represented in the DOM as `<br>`.
  hard_break: {
    inline: true,
    group: "inline",
    selectable: false,
    parseDOM: [{tag: "br"}],
    toDOM() { return brDOM }
  },

  // A div-delineated area within the MarkupEditor which can be editable or not,
  // and typically has its own styling. It may contain a <p> title and/or another div. 
  // In the latter case, this is used to hold a group of buttons.
  //
  // Notes: 
  //
  // 1. Changes to div here may need to be reflected in DivView found in markup.js.
  //
  // 2. At some point, we may want to be able to set attributes like spellcheck
  // at an individual div level, but for now these are not needed but are left 
  // commented-out for future use.
  //
  // 3. It might be possible to exclude divs that don't conform to MarkupEditor expectations 
  // by using a rule. For now, deriving a Node from html always removes divs and buttons, so 
  // the only way for them to get into the MarkupEditor is via addDiv and addButton.
  // See https://discuss.prosemirror.net/t/how-to-filter-pasted-content-by-node-type/4866 and
  // https://prosemirror.net/docs/ref/#inputrules
  div: {
    content: "block*",
    group: "block",
    selectable: false,
    attrs: {
      id: {default: null},
      parentId: {default: 'editor'},
      cssClass: {default: null},
      editable: {default: true},
      htmlContents: {default: null},
      spellcheck: {default: false},
      autocorrect: {default: 'on'},
      autocapitalize: {default: 'off'},
      writingsuggestions: {default: false},
    },
    parseDOM: [{
      tag: "div",
      getAttrs(dom) {
        const id = dom.getAttribute("id");
        const parentId = dom.getAttribute("parentId");
        const cssClass = dom.getAttribute("class");
        const editable = dom.getAttribute("editable") == "true";
        const spellcheck = dom.getAttribute("spellcheck") == "true";
        const autocorrect = dom.getAttribute("autocorrect") == "on";
        const autocapitalize = dom.getAttribute("autocapitalize") == "on";
        const writingsuggestions = dom.getAttribute("writingsuggestions") == "true";
        return {
          id: id,
          parentId: parentId,
          cssClass: cssClass,
          editable: editable,
          spellcheck: spellcheck,
          autocorrect: autocorrect,
          autocapitalize: autocapitalize,
          writingsuggestions: writingsuggestions,
          htmlContents: dom.innerHTML ?? ""
        }
      }
    }],
    // Notes:
    // 1. We produce div HTML that includes the id and class. This is because for non-editable 
    // divs, we have to find elements by id based on the HTML because we prevent ProseMirror from 
    // handling selection and rendering, and we have to do it for ourselves in the DivView. Also
    // the attributes on div are not part of the HTML content they hold, which is what is of
    // interest in MarkupEditor usage.
    //
    // 2. For the MarkupEditor, we set the top-level attributes of the editor div at initialization, 
    // and the other divs embedded in it inherit the behavior set once at the top.
    toDOM(node) {
      let {id, cssClass} = node.attrs; 
      return ["div", { id: id, class: cssClass }, 0] 
    }
  },

  button: {
    content: "text*",
    group: "block",
    attrs: {
      id: {default: null},
      parentId: {default: null},
      cssClass: {default: null},
      label: {default: ""}
    },
    parseDOM: [{
      tag: "button",
      getAttrs(dom) {
        const id = dom.getAttribute("id");
        const parentId = dom.getAttribute("parentId");
        const cssClass = dom.getAttribute("class");
        return {
          id: id,
          parentId: parentId,
          cssClass: cssClass,
          label: dom.innerHTML ?? ""
        }
      }
    }],
    toDOM(node) { 
      let {id, cssClass} = node.attrs; 
      return ["button", { id: id, class: cssClass }, 0]
    }
  }

})

// Mix the nodes from prosemirror-schema-list into the baseNodes to create a schema with list support.
baseNodes = addListNodes(baseNodes, '(paragraph | heading) block*', 'block');

// Create table nodes that support bordering
const tNodes = tableNodes({
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
tNodes.table.attrs = {class: {default: null}};
// The class for table indicates the type of bordering so needs to be parsed and output as 
// part of the table.
tNodes.table.parseDOM = [{
  tag: 'table', 
  getAttrs(dom) {
    return {class: dom.getAttribute('class')}
  }
}];
tNodes.table.toDOM = (node) => { let tClass = node.attrs; return ['table', tClass, 0] };

// Append the modified tableNodes and export the resulting nodes
// :: Object
// [Specs](#model.NodeSpec) for the nodes defined in this schema.
export const nodes = baseNodes.append(tNodes);

const emDOM = ["em", 0], 
      strongDOM = ["strong", 0], 
      codeDOM = ["code", 0],
      strikeDOM = ["s", 0],
      uDOM = ["u", 0],
      subDOM = ["sub", 0],
      supDOM = ["sup", 0]

// :: Object [Specs](#model.MarkSpec) for the marks in the schema.
export const marks = {
  // :: MarkSpec A link. Has `href` and `title` attributes. `title`
  // defaults to the empty string. Rendered and parsed as an `<a>`
  // element.
  // TODO: Eliminate title?
  link: {
    attrs: {
      href: {},
      title: {default: null}
    },
    inclusive: false,
    parseDOM: [{tag: "a[href]", getAttrs(dom) {
      return {href: dom.getAttribute("href"), title: dom.getAttribute("title")}
    }}],
    toDOM(node) { let {href, title} = node.attrs; return ["a", {href, title}, 0] }
  },

  // :: MarkSpec An emphasis mark. Rendered as an `<em>` element.
  // Has parse rules that also match `<i>` and `font-style: italic`.
  em: {
    parseDOM: [{tag: "i"}, {tag: "em"}, {style: "font-style=italic"}],
    toDOM() { return emDOM }
  },

  s: {
    parseDOM: [{tag: "s"}, {tag: "del"}, {style: "text-decoration=line-through"}],
    toDOM() { return strikeDOM }
  },

  u: {
    parseDOM: [{tag: "u"}, {style: "text-decoration=underline"}],
    toDOM() { return uDOM }
  },

  sub: {
    parseDOM: [{tag: "sub"}, {style: "vertical-align: sub"}],
    toDOM() { return subDOM }
  },

  sup: {
    parseDOM: [{tag: "sup"}, {style: "vertical-align: super"}],
    toDOM() { return supDOM }
  },

  // :: MarkSpec A strong mark. Rendered as `<strong>`, parse rules
  // also match `<b>` and `font-weight: bold`.
  strong: {
    parseDOM: [{tag: "strong"},
               // This works around a Google Docs misbehavior where
               // pasted content will be inexplicably wrapped in `<b>`
               // tags with a font-weight normal.
               {tag: "b", getAttrs: node => node.style.fontWeight != "normal" && null},
               {style: "font-weight", getAttrs: value => /^(bold(er)?|[5-9]\d{2,})$/.test(value) && null}],
    toDOM() { return strongDOM }
  },

  // :: MarkSpec Code font mark. Represented as a `<code>` element.
  code: {
    parseDOM: [{tag: "code"}],
    toDOM() { return codeDOM }
  }
}

// :: Schema
// This schema roughly corresponds to the document schema used by
// [CommonMark](http://commonmark.org/), minus the list elements,
// which are defined in the [`prosemirror-schema-list`](#schema-list)
// module.
//
// To reuse elements from this schema, extend or read from its
// `spec.nodes` and `spec.marks` [properties](#model.Schema.spec).
export const schema = new Schema({nodes, marks})

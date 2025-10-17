(function (global, factory) {
  typeof exports === 'object' && typeof module !== 'undefined' ? factory(exports) :
  typeof define === 'function' && define.amd ? define(['exports'], factory) :
  (global = typeof globalThis !== 'undefined' ? globalThis : global || self, factory(global.MU = {}));
})(this, (function (exports) { 'use strict';

  // ::- Persistent data structure representing an ordered mapping from
  // strings to values, with some convenient update methods.
  function OrderedMap(content) {
    this.content = content;
  }

  OrderedMap.prototype = {
    constructor: OrderedMap,

    find: function(key) {
      for (var i = 0; i < this.content.length; i += 2)
        if (this.content[i] === key) return i
      return -1
    },

    // :: (string) → ?any
    // Retrieve the value stored under `key`, or return undefined when
    // no such key exists.
    get: function(key) {
      var found = this.find(key);
      return found == -1 ? undefined : this.content[found + 1]
    },

    // :: (string, any, ?string) → OrderedMap
    // Create a new map by replacing the value of `key` with a new
    // value, or adding a binding to the end of the map. If `newKey` is
    // given, the key of the binding will be replaced with that key.
    update: function(key, value, newKey) {
      var self = newKey && newKey != key ? this.remove(newKey) : this;
      var found = self.find(key), content = self.content.slice();
      if (found == -1) {
        content.push(newKey || key, value);
      } else {
        content[found + 1] = value;
        if (newKey) content[found] = newKey;
      }
      return new OrderedMap(content)
    },

    // :: (string) → OrderedMap
    // Return a map with the given key removed, if it existed.
    remove: function(key) {
      var found = this.find(key);
      if (found == -1) return this
      var content = this.content.slice();
      content.splice(found, 2);
      return new OrderedMap(content)
    },

    // :: (string, any) → OrderedMap
    // Add a new key to the start of the map.
    addToStart: function(key, value) {
      return new OrderedMap([key, value].concat(this.remove(key).content))
    },

    // :: (string, any) → OrderedMap
    // Add a new key to the end of the map.
    addToEnd: function(key, value) {
      var content = this.remove(key).content.slice();
      content.push(key, value);
      return new OrderedMap(content)
    },

    // :: (string, string, any) → OrderedMap
    // Add a key after the given key. If `place` is not found, the new
    // key is added to the end.
    addBefore: function(place, key, value) {
      var without = this.remove(key), content = without.content.slice();
      var found = without.find(place);
      content.splice(found == -1 ? content.length : found, 0, key, value);
      return new OrderedMap(content)
    },

    // :: ((key: string, value: any))
    // Call the given function for each key/value pair in the map, in
    // order.
    forEach: function(f) {
      for (var i = 0; i < this.content.length; i += 2)
        f(this.content[i], this.content[i + 1]);
    },

    // :: (union<Object, OrderedMap>) → OrderedMap
    // Create a new map by prepending the keys in this map that don't
    // appear in `map` before the keys in `map`.
    prepend: function(map) {
      map = OrderedMap.from(map);
      if (!map.size) return this
      return new OrderedMap(map.content.concat(this.subtract(map).content))
    },

    // :: (union<Object, OrderedMap>) → OrderedMap
    // Create a new map by appending the keys in this map that don't
    // appear in `map` after the keys in `map`.
    append: function(map) {
      map = OrderedMap.from(map);
      if (!map.size) return this
      return new OrderedMap(this.subtract(map).content.concat(map.content))
    },

    // :: (union<Object, OrderedMap>) → OrderedMap
    // Create a map containing all the keys in this map that don't
    // appear in `map`.
    subtract: function(map) {
      var result = this;
      map = OrderedMap.from(map);
      for (var i = 0; i < map.content.length; i += 2)
        result = result.remove(map.content[i]);
      return result
    },

    // :: () → Object
    // Turn ordered map into a plain object.
    toObject: function() {
      var result = {};
      this.forEach(function(key, value) { result[key] = value; });
      return result
    },

    // :: number
    // The amount of keys in this map.
    get size() {
      return this.content.length >> 1
    }
  };

  // :: (?union<Object, OrderedMap>) → OrderedMap
  // Return a map with the given content. If null, create an empty
  // map. If given an ordered map, return that map itself. If given an
  // object, create a map from the object's properties.
  OrderedMap.from = function(value) {
    if (value instanceof OrderedMap) return value
    var content = [];
    if (value) for (var prop in value) content.push(prop, value[prop]);
    return new OrderedMap(content)
  };

  function findDiffStart(a, b, pos) {
      for (let i = 0;; i++) {
          if (i == a.childCount || i == b.childCount)
              return a.childCount == b.childCount ? null : pos;
          let childA = a.child(i), childB = b.child(i);
          if (childA == childB) {
              pos += childA.nodeSize;
              continue;
          }
          if (!childA.sameMarkup(childB))
              return pos;
          if (childA.isText && childA.text != childB.text) {
              for (let j = 0; childA.text[j] == childB.text[j]; j++)
                  pos++;
              return pos;
          }
          if (childA.content.size || childB.content.size) {
              let inner = findDiffStart(childA.content, childB.content, pos + 1);
              if (inner != null)
                  return inner;
          }
          pos += childA.nodeSize;
      }
  }
  function findDiffEnd(a, b, posA, posB) {
      for (let iA = a.childCount, iB = b.childCount;;) {
          if (iA == 0 || iB == 0)
              return iA == iB ? null : { a: posA, b: posB };
          let childA = a.child(--iA), childB = b.child(--iB), size = childA.nodeSize;
          if (childA == childB) {
              posA -= size;
              posB -= size;
              continue;
          }
          if (!childA.sameMarkup(childB))
              return { a: posA, b: posB };
          if (childA.isText && childA.text != childB.text) {
              let same = 0, minSize = Math.min(childA.text.length, childB.text.length);
              while (same < minSize && childA.text[childA.text.length - same - 1] == childB.text[childB.text.length - same - 1]) {
                  same++;
                  posA--;
                  posB--;
              }
              return { a: posA, b: posB };
          }
          if (childA.content.size || childB.content.size) {
              let inner = findDiffEnd(childA.content, childB.content, posA - 1, posB - 1);
              if (inner)
                  return inner;
          }
          posA -= size;
          posB -= size;
      }
  }

  /**
  A fragment represents a node's collection of child nodes.

  Like nodes, fragments are persistent data structures, and you
  should not mutate them or their content. Rather, you create new
  instances whenever needed. The API tries to make this easy.
  */
  class Fragment {
      /**
      @internal
      */
      constructor(
      /**
      The child nodes in this fragment.
      */
      content, size) {
          this.content = content;
          this.size = size || 0;
          if (size == null)
              for (let i = 0; i < content.length; i++)
                  this.size += content[i].nodeSize;
      }
      /**
      Invoke a callback for all descendant nodes between the given two
      positions (relative to start of this fragment). Doesn't descend
      into a node when the callback returns `false`.
      */
      nodesBetween(from, to, f, nodeStart = 0, parent) {
          for (let i = 0, pos = 0; pos < to; i++) {
              let child = this.content[i], end = pos + child.nodeSize;
              if (end > from && f(child, nodeStart + pos, parent || null, i) !== false && child.content.size) {
                  let start = pos + 1;
                  child.nodesBetween(Math.max(0, from - start), Math.min(child.content.size, to - start), f, nodeStart + start);
              }
              pos = end;
          }
      }
      /**
      Call the given callback for every descendant node. `pos` will be
      relative to the start of the fragment. The callback may return
      `false` to prevent traversal of a given node's children.
      */
      descendants(f) {
          this.nodesBetween(0, this.size, f);
      }
      /**
      Extract the text between `from` and `to`. See the same method on
      [`Node`](https://prosemirror.net/docs/ref/#model.Node.textBetween).
      */
      textBetween(from, to, blockSeparator, leafText) {
          let text = "", first = true;
          this.nodesBetween(from, to, (node, pos) => {
              let nodeText = node.isText ? node.text.slice(Math.max(from, pos) - pos, to - pos)
                  : !node.isLeaf ? ""
                      : leafText ? (typeof leafText === "function" ? leafText(node) : leafText)
                          : node.type.spec.leafText ? node.type.spec.leafText(node)
                              : "";
              if (node.isBlock && (node.isLeaf && nodeText || node.isTextblock) && blockSeparator) {
                  if (first)
                      first = false;
                  else
                      text += blockSeparator;
              }
              text += nodeText;
          }, 0);
          return text;
      }
      /**
      Create a new fragment containing the combined content of this
      fragment and the other.
      */
      append(other) {
          if (!other.size)
              return this;
          if (!this.size)
              return other;
          let last = this.lastChild, first = other.firstChild, content = this.content.slice(), i = 0;
          if (last.isText && last.sameMarkup(first)) {
              content[content.length - 1] = last.withText(last.text + first.text);
              i = 1;
          }
          for (; i < other.content.length; i++)
              content.push(other.content[i]);
          return new Fragment(content, this.size + other.size);
      }
      /**
      Cut out the sub-fragment between the two given positions.
      */
      cut(from, to = this.size) {
          if (from == 0 && to == this.size)
              return this;
          let result = [], size = 0;
          if (to > from)
              for (let i = 0, pos = 0; pos < to; i++) {
                  let child = this.content[i], end = pos + child.nodeSize;
                  if (end > from) {
                      if (pos < from || end > to) {
                          if (child.isText)
                              child = child.cut(Math.max(0, from - pos), Math.min(child.text.length, to - pos));
                          else
                              child = child.cut(Math.max(0, from - pos - 1), Math.min(child.content.size, to - pos - 1));
                      }
                      result.push(child);
                      size += child.nodeSize;
                  }
                  pos = end;
              }
          return new Fragment(result, size);
      }
      /**
      @internal
      */
      cutByIndex(from, to) {
          if (from == to)
              return Fragment.empty;
          if (from == 0 && to == this.content.length)
              return this;
          return new Fragment(this.content.slice(from, to));
      }
      /**
      Create a new fragment in which the node at the given index is
      replaced by the given node.
      */
      replaceChild(index, node) {
          let current = this.content[index];
          if (current == node)
              return this;
          let copy = this.content.slice();
          let size = this.size + node.nodeSize - current.nodeSize;
          copy[index] = node;
          return new Fragment(copy, size);
      }
      /**
      Create a new fragment by prepending the given node to this
      fragment.
      */
      addToStart(node) {
          return new Fragment([node].concat(this.content), this.size + node.nodeSize);
      }
      /**
      Create a new fragment by appending the given node to this
      fragment.
      */
      addToEnd(node) {
          return new Fragment(this.content.concat(node), this.size + node.nodeSize);
      }
      /**
      Compare this fragment to another one.
      */
      eq(other) {
          if (this.content.length != other.content.length)
              return false;
          for (let i = 0; i < this.content.length; i++)
              if (!this.content[i].eq(other.content[i]))
                  return false;
          return true;
      }
      /**
      The first child of the fragment, or `null` if it is empty.
      */
      get firstChild() { return this.content.length ? this.content[0] : null; }
      /**
      The last child of the fragment, or `null` if it is empty.
      */
      get lastChild() { return this.content.length ? this.content[this.content.length - 1] : null; }
      /**
      The number of child nodes in this fragment.
      */
      get childCount() { return this.content.length; }
      /**
      Get the child node at the given index. Raise an error when the
      index is out of range.
      */
      child(index) {
          let found = this.content[index];
          if (!found)
              throw new RangeError("Index " + index + " out of range for " + this);
          return found;
      }
      /**
      Get the child node at the given index, if it exists.
      */
      maybeChild(index) {
          return this.content[index] || null;
      }
      /**
      Call `f` for every child node, passing the node, its offset
      into this parent node, and its index.
      */
      forEach(f) {
          for (let i = 0, p = 0; i < this.content.length; i++) {
              let child = this.content[i];
              f(child, p, i);
              p += child.nodeSize;
          }
      }
      /**
      Find the first position at which this fragment and another
      fragment differ, or `null` if they are the same.
      */
      findDiffStart(other, pos = 0) {
          return findDiffStart(this, other, pos);
      }
      /**
      Find the first position, searching from the end, at which this
      fragment and the given fragment differ, or `null` if they are
      the same. Since this position will not be the same in both
      nodes, an object with two separate positions is returned.
      */
      findDiffEnd(other, pos = this.size, otherPos = other.size) {
          return findDiffEnd(this, other, pos, otherPos);
      }
      /**
      Find the index and inner offset corresponding to a given relative
      position in this fragment. The result object will be reused
      (overwritten) the next time the function is called. @internal
      */
      findIndex(pos) {
          if (pos == 0)
              return retIndex(0, pos);
          if (pos == this.size)
              return retIndex(this.content.length, pos);
          if (pos > this.size || pos < 0)
              throw new RangeError(`Position ${pos} outside of fragment (${this})`);
          for (let i = 0, curPos = 0;; i++) {
              let cur = this.child(i), end = curPos + cur.nodeSize;
              if (end >= pos) {
                  if (end == pos)
                      return retIndex(i + 1, end);
                  return retIndex(i, curPos);
              }
              curPos = end;
          }
      }
      /**
      Return a debugging string that describes this fragment.
      */
      toString() { return "<" + this.toStringInner() + ">"; }
      /**
      @internal
      */
      toStringInner() { return this.content.join(", "); }
      /**
      Create a JSON-serializeable representation of this fragment.
      */
      toJSON() {
          return this.content.length ? this.content.map(n => n.toJSON()) : null;
      }
      /**
      Deserialize a fragment from its JSON representation.
      */
      static fromJSON(schema, value) {
          if (!value)
              return Fragment.empty;
          if (!Array.isArray(value))
              throw new RangeError("Invalid input for Fragment.fromJSON");
          return new Fragment(value.map(schema.nodeFromJSON));
      }
      /**
      Build a fragment from an array of nodes. Ensures that adjacent
      text nodes with the same marks are joined together.
      */
      static fromArray(array) {
          if (!array.length)
              return Fragment.empty;
          let joined, size = 0;
          for (let i = 0; i < array.length; i++) {
              let node = array[i];
              size += node.nodeSize;
              if (i && node.isText && array[i - 1].sameMarkup(node)) {
                  if (!joined)
                      joined = array.slice(0, i);
                  joined[joined.length - 1] = node
                      .withText(joined[joined.length - 1].text + node.text);
              }
              else if (joined) {
                  joined.push(node);
              }
          }
          return new Fragment(joined || array, size);
      }
      /**
      Create a fragment from something that can be interpreted as a
      set of nodes. For `null`, it returns the empty fragment. For a
      fragment, the fragment itself. For a node or array of nodes, a
      fragment containing those nodes.
      */
      static from(nodes) {
          if (!nodes)
              return Fragment.empty;
          if (nodes instanceof Fragment)
              return nodes;
          if (Array.isArray(nodes))
              return this.fromArray(nodes);
          if (nodes.attrs)
              return new Fragment([nodes], nodes.nodeSize);
          throw new RangeError("Can not convert " + nodes + " to a Fragment" +
              (nodes.nodesBetween ? " (looks like multiple versions of prosemirror-model were loaded)" : ""));
      }
  }
  /**
  An empty fragment. Intended to be reused whenever a node doesn't
  contain anything (rather than allocating a new empty fragment for
  each leaf node).
  */
  Fragment.empty = new Fragment([], 0);
  const found = { index: 0, offset: 0 };
  function retIndex(index, offset) {
      found.index = index;
      found.offset = offset;
      return found;
  }

  function compareDeep(a, b) {
      if (a === b)
          return true;
      if (!(a && typeof a == "object") ||
          !(b && typeof b == "object"))
          return false;
      let array = Array.isArray(a);
      if (Array.isArray(b) != array)
          return false;
      if (array) {
          if (a.length != b.length)
              return false;
          for (let i = 0; i < a.length; i++)
              if (!compareDeep(a[i], b[i]))
                  return false;
      }
      else {
          for (let p in a)
              if (!(p in b) || !compareDeep(a[p], b[p]))
                  return false;
          for (let p in b)
              if (!(p in a))
                  return false;
      }
      return true;
  }

  /**
  A mark is a piece of information that can be attached to a node,
  such as it being emphasized, in code font, or a link. It has a
  type and optionally a set of attributes that provide further
  information (such as the target of the link). Marks are created
  through a `Schema`, which controls which types exist and which
  attributes they have.
  */
  class Mark {
      /**
      @internal
      */
      constructor(
      /**
      The type of this mark.
      */
      type, 
      /**
      The attributes associated with this mark.
      */
      attrs) {
          this.type = type;
          this.attrs = attrs;
      }
      /**
      Given a set of marks, create a new set which contains this one as
      well, in the right position. If this mark is already in the set,
      the set itself is returned. If any marks that are set to be
      [exclusive](https://prosemirror.net/docs/ref/#model.MarkSpec.excludes) with this mark are present,
      those are replaced by this one.
      */
      addToSet(set) {
          let copy, placed = false;
          for (let i = 0; i < set.length; i++) {
              let other = set[i];
              if (this.eq(other))
                  return set;
              if (this.type.excludes(other.type)) {
                  if (!copy)
                      copy = set.slice(0, i);
              }
              else if (other.type.excludes(this.type)) {
                  return set;
              }
              else {
                  if (!placed && other.type.rank > this.type.rank) {
                      if (!copy)
                          copy = set.slice(0, i);
                      copy.push(this);
                      placed = true;
                  }
                  if (copy)
                      copy.push(other);
              }
          }
          if (!copy)
              copy = set.slice();
          if (!placed)
              copy.push(this);
          return copy;
      }
      /**
      Remove this mark from the given set, returning a new set. If this
      mark is not in the set, the set itself is returned.
      */
      removeFromSet(set) {
          for (let i = 0; i < set.length; i++)
              if (this.eq(set[i]))
                  return set.slice(0, i).concat(set.slice(i + 1));
          return set;
      }
      /**
      Test whether this mark is in the given set of marks.
      */
      isInSet(set) {
          for (let i = 0; i < set.length; i++)
              if (this.eq(set[i]))
                  return true;
          return false;
      }
      /**
      Test whether this mark has the same type and attributes as
      another mark.
      */
      eq(other) {
          return this == other ||
              (this.type == other.type && compareDeep(this.attrs, other.attrs));
      }
      /**
      Convert this mark to a JSON-serializeable representation.
      */
      toJSON() {
          let obj = { type: this.type.name };
          for (let _ in this.attrs) {
              obj.attrs = this.attrs;
              break;
          }
          return obj;
      }
      /**
      Deserialize a mark from JSON.
      */
      static fromJSON(schema, json) {
          if (!json)
              throw new RangeError("Invalid input for Mark.fromJSON");
          let type = schema.marks[json.type];
          if (!type)
              throw new RangeError(`There is no mark type ${json.type} in this schema`);
          let mark = type.create(json.attrs);
          type.checkAttrs(mark.attrs);
          return mark;
      }
      /**
      Test whether two sets of marks are identical.
      */
      static sameSet(a, b) {
          if (a == b)
              return true;
          if (a.length != b.length)
              return false;
          for (let i = 0; i < a.length; i++)
              if (!a[i].eq(b[i]))
                  return false;
          return true;
      }
      /**
      Create a properly sorted mark set from null, a single mark, or an
      unsorted array of marks.
      */
      static setFrom(marks) {
          if (!marks || Array.isArray(marks) && marks.length == 0)
              return Mark.none;
          if (marks instanceof Mark)
              return [marks];
          let copy = marks.slice();
          copy.sort((a, b) => a.type.rank - b.type.rank);
          return copy;
      }
  }
  /**
  The empty set of marks.
  */
  Mark.none = [];

  /**
  Error type raised by [`Node.replace`](https://prosemirror.net/docs/ref/#model.Node.replace) when
  given an invalid replacement.
  */
  class ReplaceError extends Error {
  }
  /*
  ReplaceError = function(this: any, message: string) {
    let err = Error.call(this, message)
    ;(err as any).__proto__ = ReplaceError.prototype
    return err
  } as any

  ReplaceError.prototype = Object.create(Error.prototype)
  ReplaceError.prototype.constructor = ReplaceError
  ReplaceError.prototype.name = "ReplaceError"
  */
  /**
  A slice represents a piece cut out of a larger document. It
  stores not only a fragment, but also the depth up to which nodes on
  both side are ‘open’ (cut through).
  */
  class Slice {
      /**
      Create a slice. When specifying a non-zero open depth, you must
      make sure that there are nodes of at least that depth at the
      appropriate side of the fragment—i.e. if the fragment is an
      empty paragraph node, `openStart` and `openEnd` can't be greater
      than 1.
      
      It is not necessary for the content of open nodes to conform to
      the schema's content constraints, though it should be a valid
      start/end/middle for such a node, depending on which sides are
      open.
      */
      constructor(
      /**
      The slice's content.
      */
      content, 
      /**
      The open depth at the start of the fragment.
      */
      openStart, 
      /**
      The open depth at the end.
      */
      openEnd) {
          this.content = content;
          this.openStart = openStart;
          this.openEnd = openEnd;
      }
      /**
      The size this slice would add when inserted into a document.
      */
      get size() {
          return this.content.size - this.openStart - this.openEnd;
      }
      /**
      @internal
      */
      insertAt(pos, fragment) {
          let content = insertInto(this.content, pos + this.openStart, fragment);
          return content && new Slice(content, this.openStart, this.openEnd);
      }
      /**
      @internal
      */
      removeBetween(from, to) {
          return new Slice(removeRange(this.content, from + this.openStart, to + this.openStart), this.openStart, this.openEnd);
      }
      /**
      Tests whether this slice is equal to another slice.
      */
      eq(other) {
          return this.content.eq(other.content) && this.openStart == other.openStart && this.openEnd == other.openEnd;
      }
      /**
      @internal
      */
      toString() {
          return this.content + "(" + this.openStart + "," + this.openEnd + ")";
      }
      /**
      Convert a slice to a JSON-serializable representation.
      */
      toJSON() {
          if (!this.content.size)
              return null;
          let json = { content: this.content.toJSON() };
          if (this.openStart > 0)
              json.openStart = this.openStart;
          if (this.openEnd > 0)
              json.openEnd = this.openEnd;
          return json;
      }
      /**
      Deserialize a slice from its JSON representation.
      */
      static fromJSON(schema, json) {
          if (!json)
              return Slice.empty;
          let openStart = json.openStart || 0, openEnd = json.openEnd || 0;
          if (typeof openStart != "number" || typeof openEnd != "number")
              throw new RangeError("Invalid input for Slice.fromJSON");
          return new Slice(Fragment.fromJSON(schema, json.content), openStart, openEnd);
      }
      /**
      Create a slice from a fragment by taking the maximum possible
      open value on both side of the fragment.
      */
      static maxOpen(fragment, openIsolating = true) {
          let openStart = 0, openEnd = 0;
          for (let n = fragment.firstChild; n && !n.isLeaf && (openIsolating || !n.type.spec.isolating); n = n.firstChild)
              openStart++;
          for (let n = fragment.lastChild; n && !n.isLeaf && (openIsolating || !n.type.spec.isolating); n = n.lastChild)
              openEnd++;
          return new Slice(fragment, openStart, openEnd);
      }
  }
  /**
  The empty slice.
  */
  Slice.empty = new Slice(Fragment.empty, 0, 0);
  function removeRange(content, from, to) {
      let { index, offset } = content.findIndex(from), child = content.maybeChild(index);
      let { index: indexTo, offset: offsetTo } = content.findIndex(to);
      if (offset == from || child.isText) {
          if (offsetTo != to && !content.child(indexTo).isText)
              throw new RangeError("Removing non-flat range");
          return content.cut(0, from).append(content.cut(to));
      }
      if (index != indexTo)
          throw new RangeError("Removing non-flat range");
      return content.replaceChild(index, child.copy(removeRange(child.content, from - offset - 1, to - offset - 1)));
  }
  function insertInto(content, dist, insert, parent) {
      let { index, offset } = content.findIndex(dist), child = content.maybeChild(index);
      if (offset == dist || child.isText) {
          if (parent && !parent.canReplace(index, index, insert))
              return null;
          return content.cut(0, dist).append(insert).append(content.cut(dist));
      }
      let inner = insertInto(child.content, dist - offset - 1, insert, child);
      return inner && content.replaceChild(index, child.copy(inner));
  }
  function replace($from, $to, slice) {
      if (slice.openStart > $from.depth)
          throw new ReplaceError("Inserted content deeper than insertion position");
      if ($from.depth - slice.openStart != $to.depth - slice.openEnd)
          throw new ReplaceError("Inconsistent open depths");
      return replaceOuter($from, $to, slice, 0);
  }
  function replaceOuter($from, $to, slice, depth) {
      let index = $from.index(depth), node = $from.node(depth);
      if (index == $to.index(depth) && depth < $from.depth - slice.openStart) {
          let inner = replaceOuter($from, $to, slice, depth + 1);
          return node.copy(node.content.replaceChild(index, inner));
      }
      else if (!slice.content.size) {
          return close(node, replaceTwoWay($from, $to, depth));
      }
      else if (!slice.openStart && !slice.openEnd && $from.depth == depth && $to.depth == depth) { // Simple, flat case
          let parent = $from.parent, content = parent.content;
          return close(parent, content.cut(0, $from.parentOffset).append(slice.content).append(content.cut($to.parentOffset)));
      }
      else {
          let { start, end } = prepareSliceForReplace(slice, $from);
          return close(node, replaceThreeWay($from, start, end, $to, depth));
      }
  }
  function checkJoin(main, sub) {
      if (!sub.type.compatibleContent(main.type))
          throw new ReplaceError("Cannot join " + sub.type.name + " onto " + main.type.name);
  }
  function joinable$1($before, $after, depth) {
      let node = $before.node(depth);
      checkJoin(node, $after.node(depth));
      return node;
  }
  function addNode(child, target) {
      let last = target.length - 1;
      if (last >= 0 && child.isText && child.sameMarkup(target[last]))
          target[last] = child.withText(target[last].text + child.text);
      else
          target.push(child);
  }
  function addRange($start, $end, depth, target) {
      let node = ($end || $start).node(depth);
      let startIndex = 0, endIndex = $end ? $end.index(depth) : node.childCount;
      if ($start) {
          startIndex = $start.index(depth);
          if ($start.depth > depth) {
              startIndex++;
          }
          else if ($start.textOffset) {
              addNode($start.nodeAfter, target);
              startIndex++;
          }
      }
      for (let i = startIndex; i < endIndex; i++)
          addNode(node.child(i), target);
      if ($end && $end.depth == depth && $end.textOffset)
          addNode($end.nodeBefore, target);
  }
  function close(node, content) {
      node.type.checkContent(content);
      return node.copy(content);
  }
  function replaceThreeWay($from, $start, $end, $to, depth) {
      let openStart = $from.depth > depth && joinable$1($from, $start, depth + 1);
      let openEnd = $to.depth > depth && joinable$1($end, $to, depth + 1);
      let content = [];
      addRange(null, $from, depth, content);
      if (openStart && openEnd && $start.index(depth) == $end.index(depth)) {
          checkJoin(openStart, openEnd);
          addNode(close(openStart, replaceThreeWay($from, $start, $end, $to, depth + 1)), content);
      }
      else {
          if (openStart)
              addNode(close(openStart, replaceTwoWay($from, $start, depth + 1)), content);
          addRange($start, $end, depth, content);
          if (openEnd)
              addNode(close(openEnd, replaceTwoWay($end, $to, depth + 1)), content);
      }
      addRange($to, null, depth, content);
      return new Fragment(content);
  }
  function replaceTwoWay($from, $to, depth) {
      let content = [];
      addRange(null, $from, depth, content);
      if ($from.depth > depth) {
          let type = joinable$1($from, $to, depth + 1);
          addNode(close(type, replaceTwoWay($from, $to, depth + 1)), content);
      }
      addRange($to, null, depth, content);
      return new Fragment(content);
  }
  function prepareSliceForReplace(slice, $along) {
      let extra = $along.depth - slice.openStart, parent = $along.node(extra);
      let node = parent.copy(slice.content);
      for (let i = extra - 1; i >= 0; i--)
          node = $along.node(i).copy(Fragment.from(node));
      return { start: node.resolveNoCache(slice.openStart + extra),
          end: node.resolveNoCache(node.content.size - slice.openEnd - extra) };
  }

  /**
  You can [_resolve_](https://prosemirror.net/docs/ref/#model.Node.resolve) a position to get more
  information about it. Objects of this class represent such a
  resolved position, providing various pieces of context
  information, and some helper methods.

  Throughout this interface, methods that take an optional `depth`
  parameter will interpret undefined as `this.depth` and negative
  numbers as `this.depth + value`.
  */
  class ResolvedPos {
      /**
      @internal
      */
      constructor(
      /**
      The position that was resolved.
      */
      pos, 
      /**
      @internal
      */
      path, 
      /**
      The offset this position has into its parent node.
      */
      parentOffset) {
          this.pos = pos;
          this.path = path;
          this.parentOffset = parentOffset;
          this.depth = path.length / 3 - 1;
      }
      /**
      @internal
      */
      resolveDepth(val) {
          if (val == null)
              return this.depth;
          if (val < 0)
              return this.depth + val;
          return val;
      }
      /**
      The parent node that the position points into. Note that even if
      a position points into a text node, that node is not considered
      the parent—text nodes are ‘flat’ in this model, and have no content.
      */
      get parent() { return this.node(this.depth); }
      /**
      The root node in which the position was resolved.
      */
      get doc() { return this.node(0); }
      /**
      The ancestor node at the given level. `p.node(p.depth)` is the
      same as `p.parent`.
      */
      node(depth) { return this.path[this.resolveDepth(depth) * 3]; }
      /**
      The index into the ancestor at the given level. If this points
      at the 3rd node in the 2nd paragraph on the top level, for
      example, `p.index(0)` is 1 and `p.index(1)` is 2.
      */
      index(depth) { return this.path[this.resolveDepth(depth) * 3 + 1]; }
      /**
      The index pointing after this position into the ancestor at the
      given level.
      */
      indexAfter(depth) {
          depth = this.resolveDepth(depth);
          return this.index(depth) + (depth == this.depth && !this.textOffset ? 0 : 1);
      }
      /**
      The (absolute) position at the start of the node at the given
      level.
      */
      start(depth) {
          depth = this.resolveDepth(depth);
          return depth == 0 ? 0 : this.path[depth * 3 - 1] + 1;
      }
      /**
      The (absolute) position at the end of the node at the given
      level.
      */
      end(depth) {
          depth = this.resolveDepth(depth);
          return this.start(depth) + this.node(depth).content.size;
      }
      /**
      The (absolute) position directly before the wrapping node at the
      given level, or, when `depth` is `this.depth + 1`, the original
      position.
      */
      before(depth) {
          depth = this.resolveDepth(depth);
          if (!depth)
              throw new RangeError("There is no position before the top-level node");
          return depth == this.depth + 1 ? this.pos : this.path[depth * 3 - 1];
      }
      /**
      The (absolute) position directly after the wrapping node at the
      given level, or the original position when `depth` is `this.depth + 1`.
      */
      after(depth) {
          depth = this.resolveDepth(depth);
          if (!depth)
              throw new RangeError("There is no position after the top-level node");
          return depth == this.depth + 1 ? this.pos : this.path[depth * 3 - 1] + this.path[depth * 3].nodeSize;
      }
      /**
      When this position points into a text node, this returns the
      distance between the position and the start of the text node.
      Will be zero for positions that point between nodes.
      */
      get textOffset() { return this.pos - this.path[this.path.length - 1]; }
      /**
      Get the node directly after the position, if any. If the position
      points into a text node, only the part of that node after the
      position is returned.
      */
      get nodeAfter() {
          let parent = this.parent, index = this.index(this.depth);
          if (index == parent.childCount)
              return null;
          let dOff = this.pos - this.path[this.path.length - 1], child = parent.child(index);
          return dOff ? parent.child(index).cut(dOff) : child;
      }
      /**
      Get the node directly before the position, if any. If the
      position points into a text node, only the part of that node
      before the position is returned.
      */
      get nodeBefore() {
          let index = this.index(this.depth);
          let dOff = this.pos - this.path[this.path.length - 1];
          if (dOff)
              return this.parent.child(index).cut(0, dOff);
          return index == 0 ? null : this.parent.child(index - 1);
      }
      /**
      Get the position at the given index in the parent node at the
      given depth (which defaults to `this.depth`).
      */
      posAtIndex(index, depth) {
          depth = this.resolveDepth(depth);
          let node = this.path[depth * 3], pos = depth == 0 ? 0 : this.path[depth * 3 - 1] + 1;
          for (let i = 0; i < index; i++)
              pos += node.child(i).nodeSize;
          return pos;
      }
      /**
      Get the marks at this position, factoring in the surrounding
      marks' [`inclusive`](https://prosemirror.net/docs/ref/#model.MarkSpec.inclusive) property. If the
      position is at the start of a non-empty node, the marks of the
      node after it (if any) are returned.
      */
      marks() {
          let parent = this.parent, index = this.index();
          // In an empty parent, return the empty array
          if (parent.content.size == 0)
              return Mark.none;
          // When inside a text node, just return the text node's marks
          if (this.textOffset)
              return parent.child(index).marks;
          let main = parent.maybeChild(index - 1), other = parent.maybeChild(index);
          // If the `after` flag is true of there is no node before, make
          // the node after this position the main reference.
          if (!main) {
              let tmp = main;
              main = other;
              other = tmp;
          }
          // Use all marks in the main node, except those that have
          // `inclusive` set to false and are not present in the other node.
          let marks = main.marks;
          for (var i = 0; i < marks.length; i++)
              if (marks[i].type.spec.inclusive === false && (!other || !marks[i].isInSet(other.marks)))
                  marks = marks[i--].removeFromSet(marks);
          return marks;
      }
      /**
      Get the marks after the current position, if any, except those
      that are non-inclusive and not present at position `$end`. This
      is mostly useful for getting the set of marks to preserve after a
      deletion. Will return `null` if this position is at the end of
      its parent node or its parent node isn't a textblock (in which
      case no marks should be preserved).
      */
      marksAcross($end) {
          let after = this.parent.maybeChild(this.index());
          if (!after || !after.isInline)
              return null;
          let marks = after.marks, next = $end.parent.maybeChild($end.index());
          for (var i = 0; i < marks.length; i++)
              if (marks[i].type.spec.inclusive === false && (!next || !marks[i].isInSet(next.marks)))
                  marks = marks[i--].removeFromSet(marks);
          return marks;
      }
      /**
      The depth up to which this position and the given (non-resolved)
      position share the same parent nodes.
      */
      sharedDepth(pos) {
          for (let depth = this.depth; depth > 0; depth--)
              if (this.start(depth) <= pos && this.end(depth) >= pos)
                  return depth;
          return 0;
      }
      /**
      Returns a range based on the place where this position and the
      given position diverge around block content. If both point into
      the same textblock, for example, a range around that textblock
      will be returned. If they point into different blocks, the range
      around those blocks in their shared ancestor is returned. You can
      pass in an optional predicate that will be called with a parent
      node to see if a range into that parent is acceptable.
      */
      blockRange(other = this, pred) {
          if (other.pos < this.pos)
              return other.blockRange(this);
          for (let d = this.depth - (this.parent.inlineContent || this.pos == other.pos ? 1 : 0); d >= 0; d--)
              if (other.pos <= this.end(d) && (!pred || pred(this.node(d))))
                  return new NodeRange(this, other, d);
          return null;
      }
      /**
      Query whether the given position shares the same parent node.
      */
      sameParent(other) {
          return this.pos - this.parentOffset == other.pos - other.parentOffset;
      }
      /**
      Return the greater of this and the given position.
      */
      max(other) {
          return other.pos > this.pos ? other : this;
      }
      /**
      Return the smaller of this and the given position.
      */
      min(other) {
          return other.pos < this.pos ? other : this;
      }
      /**
      @internal
      */
      toString() {
          let str = "";
          for (let i = 1; i <= this.depth; i++)
              str += (str ? "/" : "") + this.node(i).type.name + "_" + this.index(i - 1);
          return str + ":" + this.parentOffset;
      }
      /**
      @internal
      */
      static resolve(doc, pos) {
          if (!(pos >= 0 && pos <= doc.content.size))
              throw new RangeError("Position " + pos + " out of range");
          let path = [];
          let start = 0, parentOffset = pos;
          for (let node = doc;;) {
              let { index, offset } = node.content.findIndex(parentOffset);
              let rem = parentOffset - offset;
              path.push(node, index, start + offset);
              if (!rem)
                  break;
              node = node.child(index);
              if (node.isText)
                  break;
              parentOffset = rem - 1;
              start += offset + 1;
          }
          return new ResolvedPos(pos, path, parentOffset);
      }
      /**
      @internal
      */
      static resolveCached(doc, pos) {
          let cache = resolveCache.get(doc);
          if (cache) {
              for (let i = 0; i < cache.elts.length; i++) {
                  let elt = cache.elts[i];
                  if (elt.pos == pos)
                      return elt;
              }
          }
          else {
              resolveCache.set(doc, cache = new ResolveCache);
          }
          let result = cache.elts[cache.i] = ResolvedPos.resolve(doc, pos);
          cache.i = (cache.i + 1) % resolveCacheSize;
          return result;
      }
  }
  class ResolveCache {
      constructor() {
          this.elts = [];
          this.i = 0;
      }
  }
  const resolveCacheSize = 12, resolveCache = new WeakMap();
  /**
  Represents a flat range of content, i.e. one that starts and
  ends in the same node.
  */
  class NodeRange {
      /**
      Construct a node range. `$from` and `$to` should point into the
      same node until at least the given `depth`, since a node range
      denotes an adjacent set of nodes in a single parent node.
      */
      constructor(
      /**
      A resolved position along the start of the content. May have a
      `depth` greater than this object's `depth` property, since
      these are the positions that were used to compute the range,
      not re-resolved positions directly at its boundaries.
      */
      $from, 
      /**
      A position along the end of the content. See
      caveat for [`$from`](https://prosemirror.net/docs/ref/#model.NodeRange.$from).
      */
      $to, 
      /**
      The depth of the node that this range points into.
      */
      depth) {
          this.$from = $from;
          this.$to = $to;
          this.depth = depth;
      }
      /**
      The position at the start of the range.
      */
      get start() { return this.$from.before(this.depth + 1); }
      /**
      The position at the end of the range.
      */
      get end() { return this.$to.after(this.depth + 1); }
      /**
      The parent node that the range points into.
      */
      get parent() { return this.$from.node(this.depth); }
      /**
      The start index of the range in the parent node.
      */
      get startIndex() { return this.$from.index(this.depth); }
      /**
      The end index of the range in the parent node.
      */
      get endIndex() { return this.$to.indexAfter(this.depth); }
  }

  const emptyAttrs = Object.create(null);
  /**
  This class represents a node in the tree that makes up a
  ProseMirror document. So a document is an instance of `Node`, with
  children that are also instances of `Node`.

  Nodes are persistent data structures. Instead of changing them, you
  create new ones with the content you want. Old ones keep pointing
  at the old document shape. This is made cheaper by sharing
  structure between the old and new data as much as possible, which a
  tree shape like this (without back pointers) makes easy.

  **Do not** directly mutate the properties of a `Node` object. See
  [the guide](https://prosemirror.net/docs/guide/#doc) for more information.
  */
  let Node$1 = class Node {
      /**
      @internal
      */
      constructor(
      /**
      The type of node that this is.
      */
      type, 
      /**
      An object mapping attribute names to values. The kind of
      attributes allowed and required are
      [determined](https://prosemirror.net/docs/ref/#model.NodeSpec.attrs) by the node type.
      */
      attrs, 
      // A fragment holding the node's children.
      content, 
      /**
      The marks (things like whether it is emphasized or part of a
      link) applied to this node.
      */
      marks = Mark.none) {
          this.type = type;
          this.attrs = attrs;
          this.marks = marks;
          this.content = content || Fragment.empty;
      }
      /**
      The array of this node's child nodes.
      */
      get children() { return this.content.content; }
      /**
      The size of this node, as defined by the integer-based [indexing
      scheme](https://prosemirror.net/docs/guide/#doc.indexing). For text nodes, this is the
      amount of characters. For other leaf nodes, it is one. For
      non-leaf nodes, it is the size of the content plus two (the
      start and end token).
      */
      get nodeSize() { return this.isLeaf ? 1 : 2 + this.content.size; }
      /**
      The number of children that the node has.
      */
      get childCount() { return this.content.childCount; }
      /**
      Get the child node at the given index. Raises an error when the
      index is out of range.
      */
      child(index) { return this.content.child(index); }
      /**
      Get the child node at the given index, if it exists.
      */
      maybeChild(index) { return this.content.maybeChild(index); }
      /**
      Call `f` for every child node, passing the node, its offset
      into this parent node, and its index.
      */
      forEach(f) { this.content.forEach(f); }
      /**
      Invoke a callback for all descendant nodes recursively between
      the given two positions that are relative to start of this
      node's content. The callback is invoked with the node, its
      position relative to the original node (method receiver),
      its parent node, and its child index. When the callback returns
      false for a given node, that node's children will not be
      recursed over. The last parameter can be used to specify a
      starting position to count from.
      */
      nodesBetween(from, to, f, startPos = 0) {
          this.content.nodesBetween(from, to, f, startPos, this);
      }
      /**
      Call the given callback for every descendant node. Doesn't
      descend into a node when the callback returns `false`.
      */
      descendants(f) {
          this.nodesBetween(0, this.content.size, f);
      }
      /**
      Concatenates all the text nodes found in this fragment and its
      children.
      */
      get textContent() {
          return (this.isLeaf && this.type.spec.leafText)
              ? this.type.spec.leafText(this)
              : this.textBetween(0, this.content.size, "");
      }
      /**
      Get all text between positions `from` and `to`. When
      `blockSeparator` is given, it will be inserted to separate text
      from different block nodes. If `leafText` is given, it'll be
      inserted for every non-text leaf node encountered, otherwise
      [`leafText`](https://prosemirror.net/docs/ref/#model.NodeSpec.leafText) will be used.
      */
      textBetween(from, to, blockSeparator, leafText) {
          return this.content.textBetween(from, to, blockSeparator, leafText);
      }
      /**
      Returns this node's first child, or `null` if there are no
      children.
      */
      get firstChild() { return this.content.firstChild; }
      /**
      Returns this node's last child, or `null` if there are no
      children.
      */
      get lastChild() { return this.content.lastChild; }
      /**
      Test whether two nodes represent the same piece of document.
      */
      eq(other) {
          return this == other || (this.sameMarkup(other) && this.content.eq(other.content));
      }
      /**
      Compare the markup (type, attributes, and marks) of this node to
      those of another. Returns `true` if both have the same markup.
      */
      sameMarkup(other) {
          return this.hasMarkup(other.type, other.attrs, other.marks);
      }
      /**
      Check whether this node's markup correspond to the given type,
      attributes, and marks.
      */
      hasMarkup(type, attrs, marks) {
          return this.type == type &&
              compareDeep(this.attrs, attrs || type.defaultAttrs || emptyAttrs) &&
              Mark.sameSet(this.marks, marks || Mark.none);
      }
      /**
      Create a new node with the same markup as this node, containing
      the given content (or empty, if no content is given).
      */
      copy(content = null) {
          if (content == this.content)
              return this;
          return new Node(this.type, this.attrs, content, this.marks);
      }
      /**
      Create a copy of this node, with the given set of marks instead
      of the node's own marks.
      */
      mark(marks) {
          return marks == this.marks ? this : new Node(this.type, this.attrs, this.content, marks);
      }
      /**
      Create a copy of this node with only the content between the
      given positions. If `to` is not given, it defaults to the end of
      the node.
      */
      cut(from, to = this.content.size) {
          if (from == 0 && to == this.content.size)
              return this;
          return this.copy(this.content.cut(from, to));
      }
      /**
      Cut out the part of the document between the given positions, and
      return it as a `Slice` object.
      */
      slice(from, to = this.content.size, includeParents = false) {
          if (from == to)
              return Slice.empty;
          let $from = this.resolve(from), $to = this.resolve(to);
          let depth = includeParents ? 0 : $from.sharedDepth(to);
          let start = $from.start(depth), node = $from.node(depth);
          let content = node.content.cut($from.pos - start, $to.pos - start);
          return new Slice(content, $from.depth - depth, $to.depth - depth);
      }
      /**
      Replace the part of the document between the given positions with
      the given slice. The slice must 'fit', meaning its open sides
      must be able to connect to the surrounding content, and its
      content nodes must be valid children for the node they are placed
      into. If any of this is violated, an error of type
      [`ReplaceError`](https://prosemirror.net/docs/ref/#model.ReplaceError) is thrown.
      */
      replace(from, to, slice) {
          return replace(this.resolve(from), this.resolve(to), slice);
      }
      /**
      Find the node directly after the given position.
      */
      nodeAt(pos) {
          for (let node = this;;) {
              let { index, offset } = node.content.findIndex(pos);
              node = node.maybeChild(index);
              if (!node)
                  return null;
              if (offset == pos || node.isText)
                  return node;
              pos -= offset + 1;
          }
      }
      /**
      Find the (direct) child node after the given offset, if any,
      and return it along with its index and offset relative to this
      node.
      */
      childAfter(pos) {
          let { index, offset } = this.content.findIndex(pos);
          return { node: this.content.maybeChild(index), index, offset };
      }
      /**
      Find the (direct) child node before the given offset, if any,
      and return it along with its index and offset relative to this
      node.
      */
      childBefore(pos) {
          if (pos == 0)
              return { node: null, index: 0, offset: 0 };
          let { index, offset } = this.content.findIndex(pos);
          if (offset < pos)
              return { node: this.content.child(index), index, offset };
          let node = this.content.child(index - 1);
          return { node, index: index - 1, offset: offset - node.nodeSize };
      }
      /**
      Resolve the given position in the document, returning an
      [object](https://prosemirror.net/docs/ref/#model.ResolvedPos) with information about its context.
      */
      resolve(pos) { return ResolvedPos.resolveCached(this, pos); }
      /**
      @internal
      */
      resolveNoCache(pos) { return ResolvedPos.resolve(this, pos); }
      /**
      Test whether a given mark or mark type occurs in this document
      between the two given positions.
      */
      rangeHasMark(from, to, type) {
          let found = false;
          if (to > from)
              this.nodesBetween(from, to, node => {
                  if (type.isInSet(node.marks))
                      found = true;
                  return !found;
              });
          return found;
      }
      /**
      True when this is a block (non-inline node)
      */
      get isBlock() { return this.type.isBlock; }
      /**
      True when this is a textblock node, a block node with inline
      content.
      */
      get isTextblock() { return this.type.isTextblock; }
      /**
      True when this node allows inline content.
      */
      get inlineContent() { return this.type.inlineContent; }
      /**
      True when this is an inline node (a text node or a node that can
      appear among text).
      */
      get isInline() { return this.type.isInline; }
      /**
      True when this is a text node.
      */
      get isText() { return this.type.isText; }
      /**
      True when this is a leaf node.
      */
      get isLeaf() { return this.type.isLeaf; }
      /**
      True when this is an atom, i.e. when it does not have directly
      editable content. This is usually the same as `isLeaf`, but can
      be configured with the [`atom` property](https://prosemirror.net/docs/ref/#model.NodeSpec.atom)
      on a node's spec (typically used when the node is displayed as
      an uneditable [node view](https://prosemirror.net/docs/ref/#view.NodeView)).
      */
      get isAtom() { return this.type.isAtom; }
      /**
      Return a string representation of this node for debugging
      purposes.
      */
      toString() {
          if (this.type.spec.toDebugString)
              return this.type.spec.toDebugString(this);
          let name = this.type.name;
          if (this.content.size)
              name += "(" + this.content.toStringInner() + ")";
          return wrapMarks(this.marks, name);
      }
      /**
      Get the content match in this node at the given index.
      */
      contentMatchAt(index) {
          let match = this.type.contentMatch.matchFragment(this.content, 0, index);
          if (!match)
              throw new Error("Called contentMatchAt on a node with invalid content");
          return match;
      }
      /**
      Test whether replacing the range between `from` and `to` (by
      child index) with the given replacement fragment (which defaults
      to the empty fragment) would leave the node's content valid. You
      can optionally pass `start` and `end` indices into the
      replacement fragment.
      */
      canReplace(from, to, replacement = Fragment.empty, start = 0, end = replacement.childCount) {
          let one = this.contentMatchAt(from).matchFragment(replacement, start, end);
          let two = one && one.matchFragment(this.content, to);
          if (!two || !two.validEnd)
              return false;
          for (let i = start; i < end; i++)
              if (!this.type.allowsMarks(replacement.child(i).marks))
                  return false;
          return true;
      }
      /**
      Test whether replacing the range `from` to `to` (by index) with
      a node of the given type would leave the node's content valid.
      */
      canReplaceWith(from, to, type, marks) {
          if (marks && !this.type.allowsMarks(marks))
              return false;
          let start = this.contentMatchAt(from).matchType(type);
          let end = start && start.matchFragment(this.content, to);
          return end ? end.validEnd : false;
      }
      /**
      Test whether the given node's content could be appended to this
      node. If that node is empty, this will only return true if there
      is at least one node type that can appear in both nodes (to avoid
      merging completely incompatible nodes).
      */
      canAppend(other) {
          if (other.content.size)
              return this.canReplace(this.childCount, this.childCount, other.content);
          else
              return this.type.compatibleContent(other.type);
      }
      /**
      Check whether this node and its descendants conform to the
      schema, and raise an exception when they do not.
      */
      check() {
          this.type.checkContent(this.content);
          this.type.checkAttrs(this.attrs);
          let copy = Mark.none;
          for (let i = 0; i < this.marks.length; i++) {
              let mark = this.marks[i];
              mark.type.checkAttrs(mark.attrs);
              copy = mark.addToSet(copy);
          }
          if (!Mark.sameSet(copy, this.marks))
              throw new RangeError(`Invalid collection of marks for node ${this.type.name}: ${this.marks.map(m => m.type.name)}`);
          this.content.forEach(node => node.check());
      }
      /**
      Return a JSON-serializeable representation of this node.
      */
      toJSON() {
          let obj = { type: this.type.name };
          for (let _ in this.attrs) {
              obj.attrs = this.attrs;
              break;
          }
          if (this.content.size)
              obj.content = this.content.toJSON();
          if (this.marks.length)
              obj.marks = this.marks.map(n => n.toJSON());
          return obj;
      }
      /**
      Deserialize a node from its JSON representation.
      */
      static fromJSON(schema, json) {
          if (!json)
              throw new RangeError("Invalid input for Node.fromJSON");
          let marks = undefined;
          if (json.marks) {
              if (!Array.isArray(json.marks))
                  throw new RangeError("Invalid mark data for Node.fromJSON");
              marks = json.marks.map(schema.markFromJSON);
          }
          if (json.type == "text") {
              if (typeof json.text != "string")
                  throw new RangeError("Invalid text node in JSON");
              return schema.text(json.text, marks);
          }
          let content = Fragment.fromJSON(schema, json.content);
          let node = schema.nodeType(json.type).create(json.attrs, content, marks);
          node.type.checkAttrs(node.attrs);
          return node;
      }
  };
  Node$1.prototype.text = undefined;
  class TextNode extends Node$1 {
      /**
      @internal
      */
      constructor(type, attrs, content, marks) {
          super(type, attrs, null, marks);
          if (!content)
              throw new RangeError("Empty text nodes are not allowed");
          this.text = content;
      }
      toString() {
          if (this.type.spec.toDebugString)
              return this.type.spec.toDebugString(this);
          return wrapMarks(this.marks, JSON.stringify(this.text));
      }
      get textContent() { return this.text; }
      textBetween(from, to) { return this.text.slice(from, to); }
      get nodeSize() { return this.text.length; }
      mark(marks) {
          return marks == this.marks ? this : new TextNode(this.type, this.attrs, this.text, marks);
      }
      withText(text) {
          if (text == this.text)
              return this;
          return new TextNode(this.type, this.attrs, text, this.marks);
      }
      cut(from = 0, to = this.text.length) {
          if (from == 0 && to == this.text.length)
              return this;
          return this.withText(this.text.slice(from, to));
      }
      eq(other) {
          return this.sameMarkup(other) && this.text == other.text;
      }
      toJSON() {
          let base = super.toJSON();
          base.text = this.text;
          return base;
      }
  }
  function wrapMarks(marks, str) {
      for (let i = marks.length - 1; i >= 0; i--)
          str = marks[i].type.name + "(" + str + ")";
      return str;
  }

  /**
  Instances of this class represent a match state of a node type's
  [content expression](https://prosemirror.net/docs/ref/#model.NodeSpec.content), and can be used to
  find out whether further content matches here, and whether a given
  position is a valid end of the node.
  */
  class ContentMatch {
      /**
      @internal
      */
      constructor(
      /**
      True when this match state represents a valid end of the node.
      */
      validEnd) {
          this.validEnd = validEnd;
          /**
          @internal
          */
          this.next = [];
          /**
          @internal
          */
          this.wrapCache = [];
      }
      /**
      @internal
      */
      static parse(string, nodeTypes) {
          let stream = new TokenStream(string, nodeTypes);
          if (stream.next == null)
              return ContentMatch.empty;
          let expr = parseExpr(stream);
          if (stream.next)
              stream.err("Unexpected trailing text");
          let match = dfa(nfa(expr));
          checkForDeadEnds(match, stream);
          return match;
      }
      /**
      Match a node type, returning a match after that node if
      successful.
      */
      matchType(type) {
          for (let i = 0; i < this.next.length; i++)
              if (this.next[i].type == type)
                  return this.next[i].next;
          return null;
      }
      /**
      Try to match a fragment. Returns the resulting match when
      successful.
      */
      matchFragment(frag, start = 0, end = frag.childCount) {
          let cur = this;
          for (let i = start; cur && i < end; i++)
              cur = cur.matchType(frag.child(i).type);
          return cur;
      }
      /**
      @internal
      */
      get inlineContent() {
          return this.next.length != 0 && this.next[0].type.isInline;
      }
      /**
      Get the first matching node type at this match position that can
      be generated.
      */
      get defaultType() {
          for (let i = 0; i < this.next.length; i++) {
              let { type } = this.next[i];
              if (!(type.isText || type.hasRequiredAttrs()))
                  return type;
          }
          return null;
      }
      /**
      @internal
      */
      compatible(other) {
          for (let i = 0; i < this.next.length; i++)
              for (let j = 0; j < other.next.length; j++)
                  if (this.next[i].type == other.next[j].type)
                      return true;
          return false;
      }
      /**
      Try to match the given fragment, and if that fails, see if it can
      be made to match by inserting nodes in front of it. When
      successful, return a fragment of inserted nodes (which may be
      empty if nothing had to be inserted). When `toEnd` is true, only
      return a fragment if the resulting match goes to the end of the
      content expression.
      */
      fillBefore(after, toEnd = false, startIndex = 0) {
          let seen = [this];
          function search(match, types) {
              let finished = match.matchFragment(after, startIndex);
              if (finished && (!toEnd || finished.validEnd))
                  return Fragment.from(types.map(tp => tp.createAndFill()));
              for (let i = 0; i < match.next.length; i++) {
                  let { type, next } = match.next[i];
                  if (!(type.isText || type.hasRequiredAttrs()) && seen.indexOf(next) == -1) {
                      seen.push(next);
                      let found = search(next, types.concat(type));
                      if (found)
                          return found;
                  }
              }
              return null;
          }
          return search(this, []);
      }
      /**
      Find a set of wrapping node types that would allow a node of the
      given type to appear at this position. The result may be empty
      (when it fits directly) and will be null when no such wrapping
      exists.
      */
      findWrapping(target) {
          for (let i = 0; i < this.wrapCache.length; i += 2)
              if (this.wrapCache[i] == target)
                  return this.wrapCache[i + 1];
          let computed = this.computeWrapping(target);
          this.wrapCache.push(target, computed);
          return computed;
      }
      /**
      @internal
      */
      computeWrapping(target) {
          let seen = Object.create(null), active = [{ match: this, type: null, via: null }];
          while (active.length) {
              let current = active.shift(), match = current.match;
              if (match.matchType(target)) {
                  let result = [];
                  for (let obj = current; obj.type; obj = obj.via)
                      result.push(obj.type);
                  return result.reverse();
              }
              for (let i = 0; i < match.next.length; i++) {
                  let { type, next } = match.next[i];
                  if (!type.isLeaf && !type.hasRequiredAttrs() && !(type.name in seen) && (!current.type || next.validEnd)) {
                      active.push({ match: type.contentMatch, type, via: current });
                      seen[type.name] = true;
                  }
              }
          }
          return null;
      }
      /**
      The number of outgoing edges this node has in the finite
      automaton that describes the content expression.
      */
      get edgeCount() {
          return this.next.length;
      }
      /**
      Get the _n_​th outgoing edge from this node in the finite
      automaton that describes the content expression.
      */
      edge(n) {
          if (n >= this.next.length)
              throw new RangeError(`There's no ${n}th edge in this content match`);
          return this.next[n];
      }
      /**
      @internal
      */
      toString() {
          let seen = [];
          function scan(m) {
              seen.push(m);
              for (let i = 0; i < m.next.length; i++)
                  if (seen.indexOf(m.next[i].next) == -1)
                      scan(m.next[i].next);
          }
          scan(this);
          return seen.map((m, i) => {
              let out = i + (m.validEnd ? "*" : " ") + " ";
              for (let i = 0; i < m.next.length; i++)
                  out += (i ? ", " : "") + m.next[i].type.name + "->" + seen.indexOf(m.next[i].next);
              return out;
          }).join("\n");
      }
  }
  /**
  @internal
  */
  ContentMatch.empty = new ContentMatch(true);
  class TokenStream {
      constructor(string, nodeTypes) {
          this.string = string;
          this.nodeTypes = nodeTypes;
          this.inline = null;
          this.pos = 0;
          this.tokens = string.split(/\s*(?=\b|\W|$)/);
          if (this.tokens[this.tokens.length - 1] == "")
              this.tokens.pop();
          if (this.tokens[0] == "")
              this.tokens.shift();
      }
      get next() { return this.tokens[this.pos]; }
      eat(tok) { return this.next == tok && (this.pos++ || true); }
      err(str) { throw new SyntaxError(str + " (in content expression '" + this.string + "')"); }
  }
  function parseExpr(stream) {
      let exprs = [];
      do {
          exprs.push(parseExprSeq(stream));
      } while (stream.eat("|"));
      return exprs.length == 1 ? exprs[0] : { type: "choice", exprs };
  }
  function parseExprSeq(stream) {
      let exprs = [];
      do {
          exprs.push(parseExprSubscript(stream));
      } while (stream.next && stream.next != ")" && stream.next != "|");
      return exprs.length == 1 ? exprs[0] : { type: "seq", exprs };
  }
  function parseExprSubscript(stream) {
      let expr = parseExprAtom(stream);
      for (;;) {
          if (stream.eat("+"))
              expr = { type: "plus", expr };
          else if (stream.eat("*"))
              expr = { type: "star", expr };
          else if (stream.eat("?"))
              expr = { type: "opt", expr };
          else if (stream.eat("{"))
              expr = parseExprRange(stream, expr);
          else
              break;
      }
      return expr;
  }
  function parseNum(stream) {
      if (/\D/.test(stream.next))
          stream.err("Expected number, got '" + stream.next + "'");
      let result = Number(stream.next);
      stream.pos++;
      return result;
  }
  function parseExprRange(stream, expr) {
      let min = parseNum(stream), max = min;
      if (stream.eat(",")) {
          if (stream.next != "}")
              max = parseNum(stream);
          else
              max = -1;
      }
      if (!stream.eat("}"))
          stream.err("Unclosed braced range");
      return { type: "range", min, max, expr };
  }
  function resolveName(stream, name) {
      let types = stream.nodeTypes, type = types[name];
      if (type)
          return [type];
      let result = [];
      for (let typeName in types) {
          let type = types[typeName];
          if (type.isInGroup(name))
              result.push(type);
      }
      if (result.length == 0)
          stream.err("No node type or group '" + name + "' found");
      return result;
  }
  function parseExprAtom(stream) {
      if (stream.eat("(")) {
          let expr = parseExpr(stream);
          if (!stream.eat(")"))
              stream.err("Missing closing paren");
          return expr;
      }
      else if (!/\W/.test(stream.next)) {
          let exprs = resolveName(stream, stream.next).map(type => {
              if (stream.inline == null)
                  stream.inline = type.isInline;
              else if (stream.inline != type.isInline)
                  stream.err("Mixing inline and block content");
              return { type: "name", value: type };
          });
          stream.pos++;
          return exprs.length == 1 ? exprs[0] : { type: "choice", exprs };
      }
      else {
          stream.err("Unexpected token '" + stream.next + "'");
      }
  }
  // Construct an NFA from an expression as returned by the parser. The
  // NFA is represented as an array of states, which are themselves
  // arrays of edges, which are `{term, to}` objects. The first state is
  // the entry state and the last node is the success state.
  //
  // Note that unlike typical NFAs, the edge ordering in this one is
  // significant, in that it is used to contruct filler content when
  // necessary.
  function nfa(expr) {
      let nfa = [[]];
      connect(compile(expr, 0), node());
      return nfa;
      function node() { return nfa.push([]) - 1; }
      function edge(from, to, term) {
          let edge = { term, to };
          nfa[from].push(edge);
          return edge;
      }
      function connect(edges, to) {
          edges.forEach(edge => edge.to = to);
      }
      function compile(expr, from) {
          if (expr.type == "choice") {
              return expr.exprs.reduce((out, expr) => out.concat(compile(expr, from)), []);
          }
          else if (expr.type == "seq") {
              for (let i = 0;; i++) {
                  let next = compile(expr.exprs[i], from);
                  if (i == expr.exprs.length - 1)
                      return next;
                  connect(next, from = node());
              }
          }
          else if (expr.type == "star") {
              let loop = node();
              edge(from, loop);
              connect(compile(expr.expr, loop), loop);
              return [edge(loop)];
          }
          else if (expr.type == "plus") {
              let loop = node();
              connect(compile(expr.expr, from), loop);
              connect(compile(expr.expr, loop), loop);
              return [edge(loop)];
          }
          else if (expr.type == "opt") {
              return [edge(from)].concat(compile(expr.expr, from));
          }
          else if (expr.type == "range") {
              let cur = from;
              for (let i = 0; i < expr.min; i++) {
                  let next = node();
                  connect(compile(expr.expr, cur), next);
                  cur = next;
              }
              if (expr.max == -1) {
                  connect(compile(expr.expr, cur), cur);
              }
              else {
                  for (let i = expr.min; i < expr.max; i++) {
                      let next = node();
                      edge(cur, next);
                      connect(compile(expr.expr, cur), next);
                      cur = next;
                  }
              }
              return [edge(cur)];
          }
          else if (expr.type == "name") {
              return [edge(from, undefined, expr.value)];
          }
          else {
              throw new Error("Unknown expr type");
          }
      }
  }
  function cmp(a, b) { return b - a; }
  // Get the set of nodes reachable by null edges from `node`. Omit
  // nodes with only a single null-out-edge, since they may lead to
  // needless duplicated nodes.
  function nullFrom(nfa, node) {
      let result = [];
      scan(node);
      return result.sort(cmp);
      function scan(node) {
          let edges = nfa[node];
          if (edges.length == 1 && !edges[0].term)
              return scan(edges[0].to);
          result.push(node);
          for (let i = 0; i < edges.length; i++) {
              let { term, to } = edges[i];
              if (!term && result.indexOf(to) == -1)
                  scan(to);
          }
      }
  }
  // Compiles an NFA as produced by `nfa` into a DFA, modeled as a set
  // of state objects (`ContentMatch` instances) with transitions
  // between them.
  function dfa(nfa) {
      let labeled = Object.create(null);
      return explore(nullFrom(nfa, 0));
      function explore(states) {
          let out = [];
          states.forEach(node => {
              nfa[node].forEach(({ term, to }) => {
                  if (!term)
                      return;
                  let set;
                  for (let i = 0; i < out.length; i++)
                      if (out[i][0] == term)
                          set = out[i][1];
                  nullFrom(nfa, to).forEach(node => {
                      if (!set)
                          out.push([term, set = []]);
                      if (set.indexOf(node) == -1)
                          set.push(node);
                  });
              });
          });
          let state = labeled[states.join(",")] = new ContentMatch(states.indexOf(nfa.length - 1) > -1);
          for (let i = 0; i < out.length; i++) {
              let states = out[i][1].sort(cmp);
              state.next.push({ type: out[i][0], next: labeled[states.join(",")] || explore(states) });
          }
          return state;
      }
  }
  function checkForDeadEnds(match, stream) {
      for (let i = 0, work = [match]; i < work.length; i++) {
          let state = work[i], dead = !state.validEnd, nodes = [];
          for (let j = 0; j < state.next.length; j++) {
              let { type, next } = state.next[j];
              nodes.push(type.name);
              if (dead && !(type.isText || type.hasRequiredAttrs()))
                  dead = false;
              if (work.indexOf(next) == -1)
                  work.push(next);
          }
          if (dead)
              stream.err("Only non-generatable nodes (" + nodes.join(", ") + ") in a required position (see https://prosemirror.net/docs/guide/#generatable)");
      }
  }

  // For node types where all attrs have a default value (or which don't
  // have any attributes), build up a single reusable default attribute
  // object, and use it for all nodes that don't specify specific
  // attributes.
  function defaultAttrs(attrs) {
      let defaults = Object.create(null);
      for (let attrName in attrs) {
          let attr = attrs[attrName];
          if (!attr.hasDefault)
              return null;
          defaults[attrName] = attr.default;
      }
      return defaults;
  }
  function computeAttrs(attrs, value) {
      let built = Object.create(null);
      for (let name in attrs) {
          let given = value && value[name];
          if (given === undefined) {
              let attr = attrs[name];
              if (attr.hasDefault)
                  given = attr.default;
              else
                  throw new RangeError("No value supplied for attribute " + name);
          }
          built[name] = given;
      }
      return built;
  }
  function checkAttrs(attrs, values, type, name) {
      for (let name in values)
          if (!(name in attrs))
              throw new RangeError(`Unsupported attribute ${name} for ${type} of type ${name}`);
      for (let name in attrs) {
          let attr = attrs[name];
          if (attr.validate)
              attr.validate(values[name]);
      }
  }
  function initAttrs(typeName, attrs) {
      let result = Object.create(null);
      if (attrs)
          for (let name in attrs)
              result[name] = new Attribute(typeName, name, attrs[name]);
      return result;
  }
  /**
  Node types are objects allocated once per `Schema` and used to
  [tag](https://prosemirror.net/docs/ref/#model.Node.type) `Node` instances. They contain information
  about the node type, such as its name and what kind of node it
  represents.
  */
  let NodeType$1 = class NodeType {
      /**
      @internal
      */
      constructor(
      /**
      The name the node type has in this schema.
      */
      name, 
      /**
      A link back to the `Schema` the node type belongs to.
      */
      schema, 
      /**
      The spec that this type is based on
      */
      spec) {
          this.name = name;
          this.schema = schema;
          this.spec = spec;
          /**
          The set of marks allowed in this node. `null` means all marks
          are allowed.
          */
          this.markSet = null;
          this.groups = spec.group ? spec.group.split(" ") : [];
          this.attrs = initAttrs(name, spec.attrs);
          this.defaultAttrs = defaultAttrs(this.attrs);
          this.contentMatch = null;
          this.inlineContent = null;
          this.isBlock = !(spec.inline || name == "text");
          this.isText = name == "text";
      }
      /**
      True if this is an inline type.
      */
      get isInline() { return !this.isBlock; }
      /**
      True if this is a textblock type, a block that contains inline
      content.
      */
      get isTextblock() { return this.isBlock && this.inlineContent; }
      /**
      True for node types that allow no content.
      */
      get isLeaf() { return this.contentMatch == ContentMatch.empty; }
      /**
      True when this node is an atom, i.e. when it does not have
      directly editable content.
      */
      get isAtom() { return this.isLeaf || !!this.spec.atom; }
      /**
      Return true when this node type is part of the given
      [group](https://prosemirror.net/docs/ref/#model.NodeSpec.group).
      */
      isInGroup(group) {
          return this.groups.indexOf(group) > -1;
      }
      /**
      The node type's [whitespace](https://prosemirror.net/docs/ref/#model.NodeSpec.whitespace) option.
      */
      get whitespace() {
          return this.spec.whitespace || (this.spec.code ? "pre" : "normal");
      }
      /**
      Tells you whether this node type has any required attributes.
      */
      hasRequiredAttrs() {
          for (let n in this.attrs)
              if (this.attrs[n].isRequired)
                  return true;
          return false;
      }
      /**
      Indicates whether this node allows some of the same content as
      the given node type.
      */
      compatibleContent(other) {
          return this == other || this.contentMatch.compatible(other.contentMatch);
      }
      /**
      @internal
      */
      computeAttrs(attrs) {
          if (!attrs && this.defaultAttrs)
              return this.defaultAttrs;
          else
              return computeAttrs(this.attrs, attrs);
      }
      /**
      Create a `Node` of this type. The given attributes are
      checked and defaulted (you can pass `null` to use the type's
      defaults entirely, if no required attributes exist). `content`
      may be a `Fragment`, a node, an array of nodes, or
      `null`. Similarly `marks` may be `null` to default to the empty
      set of marks.
      */
      create(attrs = null, content, marks) {
          if (this.isText)
              throw new Error("NodeType.create can't construct text nodes");
          return new Node$1(this, this.computeAttrs(attrs), Fragment.from(content), Mark.setFrom(marks));
      }
      /**
      Like [`create`](https://prosemirror.net/docs/ref/#model.NodeType.create), but check the given content
      against the node type's content restrictions, and throw an error
      if it doesn't match.
      */
      createChecked(attrs = null, content, marks) {
          content = Fragment.from(content);
          this.checkContent(content);
          return new Node$1(this, this.computeAttrs(attrs), content, Mark.setFrom(marks));
      }
      /**
      Like [`create`](https://prosemirror.net/docs/ref/#model.NodeType.create), but see if it is
      necessary to add nodes to the start or end of the given fragment
      to make it fit the node. If no fitting wrapping can be found,
      return null. Note that, due to the fact that required nodes can
      always be created, this will always succeed if you pass null or
      `Fragment.empty` as content.
      */
      createAndFill(attrs = null, content, marks) {
          attrs = this.computeAttrs(attrs);
          content = Fragment.from(content);
          if (content.size) {
              let before = this.contentMatch.fillBefore(content);
              if (!before)
                  return null;
              content = before.append(content);
          }
          let matched = this.contentMatch.matchFragment(content);
          let after = matched && matched.fillBefore(Fragment.empty, true);
          if (!after)
              return null;
          return new Node$1(this, attrs, content.append(after), Mark.setFrom(marks));
      }
      /**
      Returns true if the given fragment is valid content for this node
      type.
      */
      validContent(content) {
          let result = this.contentMatch.matchFragment(content);
          if (!result || !result.validEnd)
              return false;
          for (let i = 0; i < content.childCount; i++)
              if (!this.allowsMarks(content.child(i).marks))
                  return false;
          return true;
      }
      /**
      Throws a RangeError if the given fragment is not valid content for this
      node type.
      @internal
      */
      checkContent(content) {
          if (!this.validContent(content))
              throw new RangeError(`Invalid content for node ${this.name}: ${content.toString().slice(0, 50)}`);
      }
      /**
      @internal
      */
      checkAttrs(attrs) {
          checkAttrs(this.attrs, attrs, "node", this.name);
      }
      /**
      Check whether the given mark type is allowed in this node.
      */
      allowsMarkType(markType) {
          return this.markSet == null || this.markSet.indexOf(markType) > -1;
      }
      /**
      Test whether the given set of marks are allowed in this node.
      */
      allowsMarks(marks) {
          if (this.markSet == null)
              return true;
          for (let i = 0; i < marks.length; i++)
              if (!this.allowsMarkType(marks[i].type))
                  return false;
          return true;
      }
      /**
      Removes the marks that are not allowed in this node from the given set.
      */
      allowedMarks(marks) {
          if (this.markSet == null)
              return marks;
          let copy;
          for (let i = 0; i < marks.length; i++) {
              if (!this.allowsMarkType(marks[i].type)) {
                  if (!copy)
                      copy = marks.slice(0, i);
              }
              else if (copy) {
                  copy.push(marks[i]);
              }
          }
          return !copy ? marks : copy.length ? copy : Mark.none;
      }
      /**
      @internal
      */
      static compile(nodes, schema) {
          let result = Object.create(null);
          nodes.forEach((name, spec) => result[name] = new NodeType(name, schema, spec));
          let topType = schema.spec.topNode || "doc";
          if (!result[topType])
              throw new RangeError("Schema is missing its top node type ('" + topType + "')");
          if (!result.text)
              throw new RangeError("Every schema needs a 'text' type");
          for (let _ in result.text.attrs)
              throw new RangeError("The text node type should not have attributes");
          return result;
      }
  };
  function validateType(typeName, attrName, type) {
      let types = type.split("|");
      return (value) => {
          let name = value === null ? "null" : typeof value;
          if (types.indexOf(name) < 0)
              throw new RangeError(`Expected value of type ${types} for attribute ${attrName} on type ${typeName}, got ${name}`);
      };
  }
  // Attribute descriptors
  class Attribute {
      constructor(typeName, attrName, options) {
          this.hasDefault = Object.prototype.hasOwnProperty.call(options, "default");
          this.default = options.default;
          this.validate = typeof options.validate == "string" ? validateType(typeName, attrName, options.validate) : options.validate;
      }
      get isRequired() {
          return !this.hasDefault;
      }
  }
  // Marks
  /**
  Like nodes, marks (which are associated with nodes to signify
  things like emphasis or being part of a link) are
  [tagged](https://prosemirror.net/docs/ref/#model.Mark.type) with type objects, which are
  instantiated once per `Schema`.
  */
  class MarkType {
      /**
      @internal
      */
      constructor(
      /**
      The name of the mark type.
      */
      name, 
      /**
      @internal
      */
      rank, 
      /**
      The schema that this mark type instance is part of.
      */
      schema, 
      /**
      The spec on which the type is based.
      */
      spec) {
          this.name = name;
          this.rank = rank;
          this.schema = schema;
          this.spec = spec;
          this.attrs = initAttrs(name, spec.attrs);
          this.excluded = null;
          let defaults = defaultAttrs(this.attrs);
          this.instance = defaults ? new Mark(this, defaults) : null;
      }
      /**
      Create a mark of this type. `attrs` may be `null` or an object
      containing only some of the mark's attributes. The others, if
      they have defaults, will be added.
      */
      create(attrs = null) {
          if (!attrs && this.instance)
              return this.instance;
          return new Mark(this, computeAttrs(this.attrs, attrs));
      }
      /**
      @internal
      */
      static compile(marks, schema) {
          let result = Object.create(null), rank = 0;
          marks.forEach((name, spec) => result[name] = new MarkType(name, rank++, schema, spec));
          return result;
      }
      /**
      When there is a mark of this type in the given set, a new set
      without it is returned. Otherwise, the input set is returned.
      */
      removeFromSet(set) {
          for (var i = 0; i < set.length; i++)
              if (set[i].type == this) {
                  set = set.slice(0, i).concat(set.slice(i + 1));
                  i--;
              }
          return set;
      }
      /**
      Tests whether there is a mark of this type in the given set.
      */
      isInSet(set) {
          for (let i = 0; i < set.length; i++)
              if (set[i].type == this)
                  return set[i];
      }
      /**
      @internal
      */
      checkAttrs(attrs) {
          checkAttrs(this.attrs, attrs, "mark", this.name);
      }
      /**
      Queries whether a given mark type is
      [excluded](https://prosemirror.net/docs/ref/#model.MarkSpec.excludes) by this one.
      */
      excludes(other) {
          return this.excluded.indexOf(other) > -1;
      }
  }
  /**
  A document schema. Holds [node](https://prosemirror.net/docs/ref/#model.NodeType) and [mark
  type](https://prosemirror.net/docs/ref/#model.MarkType) objects for the nodes and marks that may
  occur in conforming documents, and provides functionality for
  creating and deserializing such documents.

  When given, the type parameters provide the names of the nodes and
  marks in this schema.
  */
  class Schema {
      /**
      Construct a schema from a schema [specification](https://prosemirror.net/docs/ref/#model.SchemaSpec).
      */
      constructor(spec) {
          /**
          The [linebreak
          replacement](https://prosemirror.net/docs/ref/#model.NodeSpec.linebreakReplacement) node defined
          in this schema, if any.
          */
          this.linebreakReplacement = null;
          /**
          An object for storing whatever values modules may want to
          compute and cache per schema. (If you want to store something
          in it, try to use property names unlikely to clash.)
          */
          this.cached = Object.create(null);
          let instanceSpec = this.spec = {};
          for (let prop in spec)
              instanceSpec[prop] = spec[prop];
          instanceSpec.nodes = OrderedMap.from(spec.nodes),
              instanceSpec.marks = OrderedMap.from(spec.marks || {}),
              this.nodes = NodeType$1.compile(this.spec.nodes, this);
          this.marks = MarkType.compile(this.spec.marks, this);
          let contentExprCache = Object.create(null);
          for (let prop in this.nodes) {
              if (prop in this.marks)
                  throw new RangeError(prop + " can not be both a node and a mark");
              let type = this.nodes[prop], contentExpr = type.spec.content || "", markExpr = type.spec.marks;
              type.contentMatch = contentExprCache[contentExpr] ||
                  (contentExprCache[contentExpr] = ContentMatch.parse(contentExpr, this.nodes));
              type.inlineContent = type.contentMatch.inlineContent;
              if (type.spec.linebreakReplacement) {
                  if (this.linebreakReplacement)
                      throw new RangeError("Multiple linebreak nodes defined");
                  if (!type.isInline || !type.isLeaf)
                      throw new RangeError("Linebreak replacement nodes must be inline leaf nodes");
                  this.linebreakReplacement = type;
              }
              type.markSet = markExpr == "_" ? null :
                  markExpr ? gatherMarks(this, markExpr.split(" ")) :
                      markExpr == "" || !type.inlineContent ? [] : null;
          }
          for (let prop in this.marks) {
              let type = this.marks[prop], excl = type.spec.excludes;
              type.excluded = excl == null ? [type] : excl == "" ? [] : gatherMarks(this, excl.split(" "));
          }
          this.nodeFromJSON = json => Node$1.fromJSON(this, json);
          this.markFromJSON = json => Mark.fromJSON(this, json);
          this.topNodeType = this.nodes[this.spec.topNode || "doc"];
          this.cached.wrappings = Object.create(null);
      }
      /**
      Create a node in this schema. The `type` may be a string or a
      `NodeType` instance. Attributes will be extended with defaults,
      `content` may be a `Fragment`, `null`, a `Node`, or an array of
      nodes.
      */
      node(type, attrs = null, content, marks) {
          if (typeof type == "string")
              type = this.nodeType(type);
          else if (!(type instanceof NodeType$1))
              throw new RangeError("Invalid node type: " + type);
          else if (type.schema != this)
              throw new RangeError("Node type from different schema used (" + type.name + ")");
          return type.createChecked(attrs, content, marks);
      }
      /**
      Create a text node in the schema. Empty text nodes are not
      allowed.
      */
      text(text, marks) {
          let type = this.nodes.text;
          return new TextNode(type, type.defaultAttrs, text, Mark.setFrom(marks));
      }
      /**
      Create a mark with the given type and attributes.
      */
      mark(type, attrs) {
          if (typeof type == "string")
              type = this.marks[type];
          return type.create(attrs);
      }
      /**
      @internal
      */
      nodeType(name) {
          let found = this.nodes[name];
          if (!found)
              throw new RangeError("Unknown node type: " + name);
          return found;
      }
  }
  function gatherMarks(schema, marks) {
      let found = [];
      for (let i = 0; i < marks.length; i++) {
          let name = marks[i], mark = schema.marks[name], ok = mark;
          if (mark) {
              found.push(mark);
          }
          else {
              for (let prop in schema.marks) {
                  let mark = schema.marks[prop];
                  if (name == "_" || (mark.spec.group && mark.spec.group.split(" ").indexOf(name) > -1))
                      found.push(ok = mark);
              }
          }
          if (!ok)
              throw new SyntaxError("Unknown mark type: '" + marks[i] + "'");
      }
      return found;
  }

  function isTagRule(rule) { return rule.tag != null; }
  function isStyleRule(rule) { return rule.style != null; }
  /**
  A DOM parser represents a strategy for parsing DOM content into a
  ProseMirror document conforming to a given schema. Its behavior is
  defined by an array of [rules](https://prosemirror.net/docs/ref/#model.ParseRule).
  */
  class DOMParser {
      /**
      Create a parser that targets the given schema, using the given
      parsing rules.
      */
      constructor(
      /**
      The schema into which the parser parses.
      */
      schema, 
      /**
      The set of [parse rules](https://prosemirror.net/docs/ref/#model.ParseRule) that the parser
      uses, in order of precedence.
      */
      rules) {
          this.schema = schema;
          this.rules = rules;
          /**
          @internal
          */
          this.tags = [];
          /**
          @internal
          */
          this.styles = [];
          let matchedStyles = this.matchedStyles = [];
          rules.forEach(rule => {
              if (isTagRule(rule)) {
                  this.tags.push(rule);
              }
              else if (isStyleRule(rule)) {
                  let prop = /[^=]*/.exec(rule.style)[0];
                  if (matchedStyles.indexOf(prop) < 0)
                      matchedStyles.push(prop);
                  this.styles.push(rule);
              }
          });
          // Only normalize list elements when lists in the schema can't directly contain themselves
          this.normalizeLists = !this.tags.some(r => {
              if (!/^(ul|ol)\b/.test(r.tag) || !r.node)
                  return false;
              let node = schema.nodes[r.node];
              return node.contentMatch.matchType(node);
          });
      }
      /**
      Parse a document from the content of a DOM node.
      */
      parse(dom, options = {}) {
          let context = new ParseContext(this, options, false);
          context.addAll(dom, Mark.none, options.from, options.to);
          return context.finish();
      }
      /**
      Parses the content of the given DOM node, like
      [`parse`](https://prosemirror.net/docs/ref/#model.DOMParser.parse), and takes the same set of
      options. But unlike that method, which produces a whole node,
      this one returns a slice that is open at the sides, meaning that
      the schema constraints aren't applied to the start of nodes to
      the left of the input and the end of nodes at the end.
      */
      parseSlice(dom, options = {}) {
          let context = new ParseContext(this, options, true);
          context.addAll(dom, Mark.none, options.from, options.to);
          return Slice.maxOpen(context.finish());
      }
      /**
      @internal
      */
      matchTag(dom, context, after) {
          for (let i = after ? this.tags.indexOf(after) + 1 : 0; i < this.tags.length; i++) {
              let rule = this.tags[i];
              if (matches(dom, rule.tag) &&
                  (rule.namespace === undefined || dom.namespaceURI == rule.namespace) &&
                  (!rule.context || context.matchesContext(rule.context))) {
                  if (rule.getAttrs) {
                      let result = rule.getAttrs(dom);
                      if (result === false)
                          continue;
                      rule.attrs = result || undefined;
                  }
                  return rule;
              }
          }
      }
      /**
      @internal
      */
      matchStyle(prop, value, context, after) {
          for (let i = after ? this.styles.indexOf(after) + 1 : 0; i < this.styles.length; i++) {
              let rule = this.styles[i], style = rule.style;
              if (style.indexOf(prop) != 0 ||
                  rule.context && !context.matchesContext(rule.context) ||
                  // Test that the style string either precisely matches the prop,
                  // or has an '=' sign after the prop, followed by the given
                  // value.
                  style.length > prop.length &&
                      (style.charCodeAt(prop.length) != 61 || style.slice(prop.length + 1) != value))
                  continue;
              if (rule.getAttrs) {
                  let result = rule.getAttrs(value);
                  if (result === false)
                      continue;
                  rule.attrs = result || undefined;
              }
              return rule;
          }
      }
      /**
      @internal
      */
      static schemaRules(schema) {
          let result = [];
          function insert(rule) {
              let priority = rule.priority == null ? 50 : rule.priority, i = 0;
              for (; i < result.length; i++) {
                  let next = result[i], nextPriority = next.priority == null ? 50 : next.priority;
                  if (nextPriority < priority)
                      break;
              }
              result.splice(i, 0, rule);
          }
          for (let name in schema.marks) {
              let rules = schema.marks[name].spec.parseDOM;
              if (rules)
                  rules.forEach(rule => {
                      insert(rule = copy(rule));
                      if (!(rule.mark || rule.ignore || rule.clearMark))
                          rule.mark = name;
                  });
          }
          for (let name in schema.nodes) {
              let rules = schema.nodes[name].spec.parseDOM;
              if (rules)
                  rules.forEach(rule => {
                      insert(rule = copy(rule));
                      if (!(rule.node || rule.ignore || rule.mark))
                          rule.node = name;
                  });
          }
          return result;
      }
      /**
      Construct a DOM parser using the parsing rules listed in a
      schema's [node specs](https://prosemirror.net/docs/ref/#model.NodeSpec.parseDOM), reordered by
      [priority](https://prosemirror.net/docs/ref/#model.GenericParseRule.priority).
      */
      static fromSchema(schema) {
          return schema.cached.domParser ||
              (schema.cached.domParser = new DOMParser(schema, DOMParser.schemaRules(schema)));
      }
  }
  const blockTags = {
      address: true, article: true, aside: true, blockquote: true, canvas: true,
      dd: true, div: true, dl: true, fieldset: true, figcaption: true, figure: true,
      footer: true, form: true, h1: true, h2: true, h3: true, h4: true, h5: true,
      h6: true, header: true, hgroup: true, hr: true, li: true, noscript: true, ol: true,
      output: true, p: true, pre: true, section: true, table: true, tfoot: true, ul: true
  };
  const ignoreTags = {
      head: true, noscript: true, object: true, script: true, style: true, title: true
  };
  const listTags = { ol: true, ul: true };
  // Using a bitfield for node context options
  const OPT_PRESERVE_WS = 1, OPT_PRESERVE_WS_FULL = 2, OPT_OPEN_LEFT = 4;
  function wsOptionsFor(type, preserveWhitespace, base) {
      if (preserveWhitespace != null)
          return (preserveWhitespace ? OPT_PRESERVE_WS : 0) |
              (preserveWhitespace === "full" ? OPT_PRESERVE_WS_FULL : 0);
      return type && type.whitespace == "pre" ? OPT_PRESERVE_WS | OPT_PRESERVE_WS_FULL : base & ~OPT_OPEN_LEFT;
  }
  class NodeContext {
      constructor(type, attrs, marks, solid, match, options) {
          this.type = type;
          this.attrs = attrs;
          this.marks = marks;
          this.solid = solid;
          this.options = options;
          this.content = [];
          // Marks applied to the node's children
          this.activeMarks = Mark.none;
          this.match = match || (options & OPT_OPEN_LEFT ? null : type.contentMatch);
      }
      findWrapping(node) {
          if (!this.match) {
              if (!this.type)
                  return [];
              let fill = this.type.contentMatch.fillBefore(Fragment.from(node));
              if (fill) {
                  this.match = this.type.contentMatch.matchFragment(fill);
              }
              else {
                  let start = this.type.contentMatch, wrap;
                  if (wrap = start.findWrapping(node.type)) {
                      this.match = start;
                      return wrap;
                  }
                  else {
                      return null;
                  }
              }
          }
          return this.match.findWrapping(node.type);
      }
      finish(openEnd) {
          if (!(this.options & OPT_PRESERVE_WS)) { // Strip trailing whitespace
              let last = this.content[this.content.length - 1], m;
              if (last && last.isText && (m = /[ \t\r\n\u000c]+$/.exec(last.text))) {
                  let text = last;
                  if (last.text.length == m[0].length)
                      this.content.pop();
                  else
                      this.content[this.content.length - 1] = text.withText(text.text.slice(0, text.text.length - m[0].length));
              }
          }
          let content = Fragment.from(this.content);
          if (!openEnd && this.match)
              content = content.append(this.match.fillBefore(Fragment.empty, true));
          return this.type ? this.type.create(this.attrs, content, this.marks) : content;
      }
      inlineContext(node) {
          if (this.type)
              return this.type.inlineContent;
          if (this.content.length)
              return this.content[0].isInline;
          return node.parentNode && !blockTags.hasOwnProperty(node.parentNode.nodeName.toLowerCase());
      }
  }
  class ParseContext {
      constructor(
      // The parser we are using.
      parser, 
      // The options passed to this parse.
      options, isOpen) {
          this.parser = parser;
          this.options = options;
          this.isOpen = isOpen;
          this.open = 0;
          this.localPreserveWS = false;
          let topNode = options.topNode, topContext;
          let topOptions = wsOptionsFor(null, options.preserveWhitespace, 0) | (isOpen ? OPT_OPEN_LEFT : 0);
          if (topNode)
              topContext = new NodeContext(topNode.type, topNode.attrs, Mark.none, true, options.topMatch || topNode.type.contentMatch, topOptions);
          else if (isOpen)
              topContext = new NodeContext(null, null, Mark.none, true, null, topOptions);
          else
              topContext = new NodeContext(parser.schema.topNodeType, null, Mark.none, true, null, topOptions);
          this.nodes = [topContext];
          this.find = options.findPositions;
          this.needsBlock = false;
      }
      get top() {
          return this.nodes[this.open];
      }
      // Add a DOM node to the content. Text is inserted as text node,
      // otherwise, the node is passed to `addElement` or, if it has a
      // `style` attribute, `addElementWithStyles`.
      addDOM(dom, marks) {
          if (dom.nodeType == 3)
              this.addTextNode(dom, marks);
          else if (dom.nodeType == 1)
              this.addElement(dom, marks);
      }
      addTextNode(dom, marks) {
          let value = dom.nodeValue;
          let top = this.top, preserveWS = (top.options & OPT_PRESERVE_WS_FULL) ? "full"
              : this.localPreserveWS || (top.options & OPT_PRESERVE_WS) > 0;
          if (preserveWS === "full" ||
              top.inlineContext(dom) ||
              /[^ \t\r\n\u000c]/.test(value)) {
              if (!preserveWS) {
                  value = value.replace(/[ \t\r\n\u000c]+/g, " ");
                  // If this starts with whitespace, and there is no node before it, or
                  // a hard break, or a text node that ends with whitespace, strip the
                  // leading space.
                  if (/^[ \t\r\n\u000c]/.test(value) && this.open == this.nodes.length - 1) {
                      let nodeBefore = top.content[top.content.length - 1];
                      let domNodeBefore = dom.previousSibling;
                      if (!nodeBefore ||
                          (domNodeBefore && domNodeBefore.nodeName == 'BR') ||
                          (nodeBefore.isText && /[ \t\r\n\u000c]$/.test(nodeBefore.text)))
                          value = value.slice(1);
                  }
              }
              else if (preserveWS !== "full") {
                  value = value.replace(/\r?\n|\r/g, " ");
              }
              else {
                  value = value.replace(/\r\n?/g, "\n");
              }
              if (value)
                  this.insertNode(this.parser.schema.text(value), marks, !/\S/.test(value));
              this.findInText(dom);
          }
          else {
              this.findInside(dom);
          }
      }
      // Try to find a handler for the given tag and use that to parse. If
      // none is found, the element's content nodes are added directly.
      addElement(dom, marks, matchAfter) {
          let outerWS = this.localPreserveWS, top = this.top;
          if (dom.tagName == "PRE" || /pre/.test(dom.style && dom.style.whiteSpace))
              this.localPreserveWS = true;
          let name = dom.nodeName.toLowerCase(), ruleID;
          if (listTags.hasOwnProperty(name) && this.parser.normalizeLists)
              normalizeList(dom);
          let rule = (this.options.ruleFromNode && this.options.ruleFromNode(dom)) ||
              (ruleID = this.parser.matchTag(dom, this, matchAfter));
          out: if (rule ? rule.ignore : ignoreTags.hasOwnProperty(name)) {
              this.findInside(dom);
              this.ignoreFallback(dom, marks);
          }
          else if (!rule || rule.skip || rule.closeParent) {
              if (rule && rule.closeParent)
                  this.open = Math.max(0, this.open - 1);
              else if (rule && rule.skip.nodeType)
                  dom = rule.skip;
              let sync, oldNeedsBlock = this.needsBlock;
              if (blockTags.hasOwnProperty(name)) {
                  if (top.content.length && top.content[0].isInline && this.open) {
                      this.open--;
                      top = this.top;
                  }
                  sync = true;
                  if (!top.type)
                      this.needsBlock = true;
              }
              else if (!dom.firstChild) {
                  this.leafFallback(dom, marks);
                  break out;
              }
              let innerMarks = rule && rule.skip ? marks : this.readStyles(dom, marks);
              if (innerMarks)
                  this.addAll(dom, innerMarks);
              if (sync)
                  this.sync(top);
              this.needsBlock = oldNeedsBlock;
          }
          else {
              let innerMarks = this.readStyles(dom, marks);
              if (innerMarks)
                  this.addElementByRule(dom, rule, innerMarks, rule.consuming === false ? ruleID : undefined);
          }
          this.localPreserveWS = outerWS;
      }
      // Called for leaf DOM nodes that would otherwise be ignored
      leafFallback(dom, marks) {
          if (dom.nodeName == "BR" && this.top.type && this.top.type.inlineContent)
              this.addTextNode(dom.ownerDocument.createTextNode("\n"), marks);
      }
      // Called for ignored nodes
      ignoreFallback(dom, marks) {
          // Ignored BR nodes should at least create an inline context
          if (dom.nodeName == "BR" && (!this.top.type || !this.top.type.inlineContent))
              this.findPlace(this.parser.schema.text("-"), marks, true);
      }
      // Run any style parser associated with the node's styles. Either
      // return an updated array of marks, or null to indicate some of the
      // styles had a rule with `ignore` set.
      readStyles(dom, marks) {
          let styles = dom.style;
          // Because many properties will only show up in 'normalized' form
          // in `style.item` (i.e. text-decoration becomes
          // text-decoration-line, text-decoration-color, etc), we directly
          // query the styles mentioned in our rules instead of iterating
          // over the items.
          if (styles && styles.length)
              for (let i = 0; i < this.parser.matchedStyles.length; i++) {
                  let name = this.parser.matchedStyles[i], value = styles.getPropertyValue(name);
                  if (value)
                      for (let after = undefined;;) {
                          let rule = this.parser.matchStyle(name, value, this, after);
                          if (!rule)
                              break;
                          if (rule.ignore)
                              return null;
                          if (rule.clearMark)
                              marks = marks.filter(m => !rule.clearMark(m));
                          else
                              marks = marks.concat(this.parser.schema.marks[rule.mark].create(rule.attrs));
                          if (rule.consuming === false)
                              after = rule;
                          else
                              break;
                      }
              }
          return marks;
      }
      // Look up a handler for the given node. If none are found, return
      // false. Otherwise, apply it, use its return value to drive the way
      // the node's content is wrapped, and return true.
      addElementByRule(dom, rule, marks, continueAfter) {
          let sync, nodeType;
          if (rule.node) {
              nodeType = this.parser.schema.nodes[rule.node];
              if (!nodeType.isLeaf) {
                  let inner = this.enter(nodeType, rule.attrs || null, marks, rule.preserveWhitespace);
                  if (inner) {
                      sync = true;
                      marks = inner;
                  }
              }
              else if (!this.insertNode(nodeType.create(rule.attrs), marks, dom.nodeName == "BR")) {
                  this.leafFallback(dom, marks);
              }
          }
          else {
              let markType = this.parser.schema.marks[rule.mark];
              marks = marks.concat(markType.create(rule.attrs));
          }
          let startIn = this.top;
          if (nodeType && nodeType.isLeaf) {
              this.findInside(dom);
          }
          else if (continueAfter) {
              this.addElement(dom, marks, continueAfter);
          }
          else if (rule.getContent) {
              this.findInside(dom);
              rule.getContent(dom, this.parser.schema).forEach(node => this.insertNode(node, marks, false));
          }
          else {
              let contentDOM = dom;
              if (typeof rule.contentElement == "string")
                  contentDOM = dom.querySelector(rule.contentElement);
              else if (typeof rule.contentElement == "function")
                  contentDOM = rule.contentElement(dom);
              else if (rule.contentElement)
                  contentDOM = rule.contentElement;
              this.findAround(dom, contentDOM, true);
              this.addAll(contentDOM, marks);
              this.findAround(dom, contentDOM, false);
          }
          if (sync && this.sync(startIn))
              this.open--;
      }
      // Add all child nodes between `startIndex` and `endIndex` (or the
      // whole node, if not given). If `sync` is passed, use it to
      // synchronize after every block element.
      addAll(parent, marks, startIndex, endIndex) {
          let index = startIndex || 0;
          for (let dom = startIndex ? parent.childNodes[startIndex] : parent.firstChild, end = endIndex == null ? null : parent.childNodes[endIndex]; dom != end; dom = dom.nextSibling, ++index) {
              this.findAtPoint(parent, index);
              this.addDOM(dom, marks);
          }
          this.findAtPoint(parent, index);
      }
      // Try to find a way to fit the given node type into the current
      // context. May add intermediate wrappers and/or leave non-solid
      // nodes that we're in.
      findPlace(node, marks, cautious) {
          let route, sync;
          for (let depth = this.open, penalty = 0; depth >= 0; depth--) {
              let cx = this.nodes[depth];
              let found = cx.findWrapping(node);
              if (found && (!route || route.length > found.length + penalty)) {
                  route = found;
                  sync = cx;
                  if (!found.length)
                      break;
              }
              if (cx.solid) {
                  if (cautious)
                      break;
                  penalty += 2;
              }
          }
          if (!route)
              return null;
          this.sync(sync);
          for (let i = 0; i < route.length; i++)
              marks = this.enterInner(route[i], null, marks, false);
          return marks;
      }
      // Try to insert the given node, adjusting the context when needed.
      insertNode(node, marks, cautious) {
          if (node.isInline && this.needsBlock && !this.top.type) {
              let block = this.textblockFromContext();
              if (block)
                  marks = this.enterInner(block, null, marks);
          }
          let innerMarks = this.findPlace(node, marks, cautious);
          if (innerMarks) {
              this.closeExtra();
              let top = this.top;
              if (top.match)
                  top.match = top.match.matchType(node.type);
              let nodeMarks = Mark.none;
              for (let m of innerMarks.concat(node.marks))
                  if (top.type ? top.type.allowsMarkType(m.type) : markMayApply(m.type, node.type))
                      nodeMarks = m.addToSet(nodeMarks);
              top.content.push(node.mark(nodeMarks));
              return true;
          }
          return false;
      }
      // Try to start a node of the given type, adjusting the context when
      // necessary.
      enter(type, attrs, marks, preserveWS) {
          let innerMarks = this.findPlace(type.create(attrs), marks, false);
          if (innerMarks)
              innerMarks = this.enterInner(type, attrs, marks, true, preserveWS);
          return innerMarks;
      }
      // Open a node of the given type
      enterInner(type, attrs, marks, solid = false, preserveWS) {
          this.closeExtra();
          let top = this.top;
          top.match = top.match && top.match.matchType(type);
          let options = wsOptionsFor(type, preserveWS, top.options);
          if ((top.options & OPT_OPEN_LEFT) && top.content.length == 0)
              options |= OPT_OPEN_LEFT;
          let applyMarks = Mark.none;
          marks = marks.filter(m => {
              if (top.type ? top.type.allowsMarkType(m.type) : markMayApply(m.type, type)) {
                  applyMarks = m.addToSet(applyMarks);
                  return false;
              }
              return true;
          });
          this.nodes.push(new NodeContext(type, attrs, applyMarks, solid, null, options));
          this.open++;
          return marks;
      }
      // Make sure all nodes above this.open are finished and added to
      // their parents
      closeExtra(openEnd = false) {
          let i = this.nodes.length - 1;
          if (i > this.open) {
              for (; i > this.open; i--)
                  this.nodes[i - 1].content.push(this.nodes[i].finish(openEnd));
              this.nodes.length = this.open + 1;
          }
      }
      finish() {
          this.open = 0;
          this.closeExtra(this.isOpen);
          return this.nodes[0].finish(!!(this.isOpen || this.options.topOpen));
      }
      sync(to) {
          for (let i = this.open; i >= 0; i--) {
              if (this.nodes[i] == to) {
                  this.open = i;
                  return true;
              }
              else if (this.localPreserveWS) {
                  this.nodes[i].options |= OPT_PRESERVE_WS;
              }
          }
          return false;
      }
      get currentPos() {
          this.closeExtra();
          let pos = 0;
          for (let i = this.open; i >= 0; i--) {
              let content = this.nodes[i].content;
              for (let j = content.length - 1; j >= 0; j--)
                  pos += content[j].nodeSize;
              if (i)
                  pos++;
          }
          return pos;
      }
      findAtPoint(parent, offset) {
          if (this.find)
              for (let i = 0; i < this.find.length; i++) {
                  if (this.find[i].node == parent && this.find[i].offset == offset)
                      this.find[i].pos = this.currentPos;
              }
      }
      findInside(parent) {
          if (this.find)
              for (let i = 0; i < this.find.length; i++) {
                  if (this.find[i].pos == null && parent.nodeType == 1 && parent.contains(this.find[i].node))
                      this.find[i].pos = this.currentPos;
              }
      }
      findAround(parent, content, before) {
          if (parent != content && this.find)
              for (let i = 0; i < this.find.length; i++) {
                  if (this.find[i].pos == null && parent.nodeType == 1 && parent.contains(this.find[i].node)) {
                      let pos = content.compareDocumentPosition(this.find[i].node);
                      if (pos & (before ? 2 : 4))
                          this.find[i].pos = this.currentPos;
                  }
              }
      }
      findInText(textNode) {
          if (this.find)
              for (let i = 0; i < this.find.length; i++) {
                  if (this.find[i].node == textNode)
                      this.find[i].pos = this.currentPos - (textNode.nodeValue.length - this.find[i].offset);
              }
      }
      // Determines whether the given context string matches this context.
      matchesContext(context) {
          if (context.indexOf("|") > -1)
              return context.split(/\s*\|\s*/).some(this.matchesContext, this);
          let parts = context.split("/");
          let option = this.options.context;
          let useRoot = !this.isOpen && (!option || option.parent.type == this.nodes[0].type);
          let minDepth = -(option ? option.depth + 1 : 0) + (useRoot ? 0 : 1);
          let match = (i, depth) => {
              for (; i >= 0; i--) {
                  let part = parts[i];
                  if (part == "") {
                      if (i == parts.length - 1 || i == 0)
                          continue;
                      for (; depth >= minDepth; depth--)
                          if (match(i - 1, depth))
                              return true;
                      return false;
                  }
                  else {
                      let next = depth > 0 || (depth == 0 && useRoot) ? this.nodes[depth].type
                          : option && depth >= minDepth ? option.node(depth - minDepth).type
                              : null;
                      if (!next || (next.name != part && !next.isInGroup(part)))
                          return false;
                      depth--;
                  }
              }
              return true;
          };
          return match(parts.length - 1, this.open);
      }
      textblockFromContext() {
          let $context = this.options.context;
          if ($context)
              for (let d = $context.depth; d >= 0; d--) {
                  let deflt = $context.node(d).contentMatchAt($context.indexAfter(d)).defaultType;
                  if (deflt && deflt.isTextblock && deflt.defaultAttrs)
                      return deflt;
              }
          for (let name in this.parser.schema.nodes) {
              let type = this.parser.schema.nodes[name];
              if (type.isTextblock && type.defaultAttrs)
                  return type;
          }
      }
  }
  // Kludge to work around directly nested list nodes produced by some
  // tools and allowed by browsers to mean that the nested list is
  // actually part of the list item above it.
  function normalizeList(dom) {
      for (let child = dom.firstChild, prevItem = null; child; child = child.nextSibling) {
          let name = child.nodeType == 1 ? child.nodeName.toLowerCase() : null;
          if (name && listTags.hasOwnProperty(name) && prevItem) {
              prevItem.appendChild(child);
              child = prevItem;
          }
          else if (name == "li") {
              prevItem = child;
          }
          else if (name) {
              prevItem = null;
          }
      }
  }
  // Apply a CSS selector.
  function matches(dom, selector) {
      return (dom.matches || dom.msMatchesSelector || dom.webkitMatchesSelector || dom.mozMatchesSelector).call(dom, selector);
  }
  function copy(obj) {
      let copy = {};
      for (let prop in obj)
          copy[prop] = obj[prop];
      return copy;
  }
  // Used when finding a mark at the top level of a fragment parse.
  // Checks whether it would be reasonable to apply a given mark type to
  // a given node, by looking at the way the mark occurs in the schema.
  function markMayApply(markType, nodeType) {
      let nodes = nodeType.schema.nodes;
      for (let name in nodes) {
          let parent = nodes[name];
          if (!parent.allowsMarkType(markType))
              continue;
          let seen = [], scan = (match) => {
              seen.push(match);
              for (let i = 0; i < match.edgeCount; i++) {
                  let { type, next } = match.edge(i);
                  if (type == nodeType)
                      return true;
                  if (seen.indexOf(next) < 0 && scan(next))
                      return true;
              }
          };
          if (scan(parent.contentMatch))
              return true;
      }
  }

  /**
  A DOM serializer knows how to convert ProseMirror nodes and
  marks of various types to DOM nodes.
  */
  class DOMSerializer {
      /**
      Create a serializer. `nodes` should map node names to functions
      that take a node and return a description of the corresponding
      DOM. `marks` does the same for mark names, but also gets an
      argument that tells it whether the mark's content is block or
      inline content (for typical use, it'll always be inline). A mark
      serializer may be `null` to indicate that marks of that type
      should not be serialized.
      */
      constructor(
      /**
      The node serialization functions.
      */
      nodes, 
      /**
      The mark serialization functions.
      */
      marks) {
          this.nodes = nodes;
          this.marks = marks;
      }
      /**
      Serialize the content of this fragment to a DOM fragment. When
      not in the browser, the `document` option, containing a DOM
      document, should be passed so that the serializer can create
      nodes.
      */
      serializeFragment(fragment, options = {}, target) {
          if (!target)
              target = doc$1(options).createDocumentFragment();
          let top = target, active = [];
          fragment.forEach(node => {
              if (active.length || node.marks.length) {
                  let keep = 0, rendered = 0;
                  while (keep < active.length && rendered < node.marks.length) {
                      let next = node.marks[rendered];
                      if (!this.marks[next.type.name]) {
                          rendered++;
                          continue;
                      }
                      if (!next.eq(active[keep][0]) || next.type.spec.spanning === false)
                          break;
                      keep++;
                      rendered++;
                  }
                  while (keep < active.length)
                      top = active.pop()[1];
                  while (rendered < node.marks.length) {
                      let add = node.marks[rendered++];
                      let markDOM = this.serializeMark(add, node.isInline, options);
                      if (markDOM) {
                          active.push([add, top]);
                          top.appendChild(markDOM.dom);
                          top = markDOM.contentDOM || markDOM.dom;
                      }
                  }
              }
              top.appendChild(this.serializeNodeInner(node, options));
          });
          return target;
      }
      /**
      @internal
      */
      serializeNodeInner(node, options) {
          let { dom, contentDOM } = renderSpec(doc$1(options), this.nodes[node.type.name](node), null, node.attrs);
          if (contentDOM) {
              if (node.isLeaf)
                  throw new RangeError("Content hole not allowed in a leaf node spec");
              this.serializeFragment(node.content, options, contentDOM);
          }
          return dom;
      }
      /**
      Serialize this node to a DOM node. This can be useful when you
      need to serialize a part of a document, as opposed to the whole
      document. To serialize a whole document, use
      [`serializeFragment`](https://prosemirror.net/docs/ref/#model.DOMSerializer.serializeFragment) on
      its [content](https://prosemirror.net/docs/ref/#model.Node.content).
      */
      serializeNode(node, options = {}) {
          let dom = this.serializeNodeInner(node, options);
          for (let i = node.marks.length - 1; i >= 0; i--) {
              let wrap = this.serializeMark(node.marks[i], node.isInline, options);
              if (wrap) {
                  (wrap.contentDOM || wrap.dom).appendChild(dom);
                  dom = wrap.dom;
              }
          }
          return dom;
      }
      /**
      @internal
      */
      serializeMark(mark, inline, options = {}) {
          let toDOM = this.marks[mark.type.name];
          return toDOM && renderSpec(doc$1(options), toDOM(mark, inline), null, mark.attrs);
      }
      static renderSpec(doc, structure, xmlNS = null, blockArraysIn) {
          return renderSpec(doc, structure, xmlNS, blockArraysIn);
      }
      /**
      Build a serializer using the [`toDOM`](https://prosemirror.net/docs/ref/#model.NodeSpec.toDOM)
      properties in a schema's node and mark specs.
      */
      static fromSchema(schema) {
          return schema.cached.domSerializer ||
              (schema.cached.domSerializer = new DOMSerializer(this.nodesFromSchema(schema), this.marksFromSchema(schema)));
      }
      /**
      Gather the serializers in a schema's node specs into an object.
      This can be useful as a base to build a custom serializer from.
      */
      static nodesFromSchema(schema) {
          let result = gatherToDOM(schema.nodes);
          if (!result.text)
              result.text = node => node.text;
          return result;
      }
      /**
      Gather the serializers in a schema's mark specs into an object.
      */
      static marksFromSchema(schema) {
          return gatherToDOM(schema.marks);
      }
  }
  function gatherToDOM(obj) {
      let result = {};
      for (let name in obj) {
          let toDOM = obj[name].spec.toDOM;
          if (toDOM)
              result[name] = toDOM;
      }
      return result;
  }
  function doc$1(options) {
      return options.document || window.document;
  }
  const suspiciousAttributeCache = new WeakMap();
  function suspiciousAttributes(attrs) {
      let value = suspiciousAttributeCache.get(attrs);
      if (value === undefined)
          suspiciousAttributeCache.set(attrs, value = suspiciousAttributesInner(attrs));
      return value;
  }
  function suspiciousAttributesInner(attrs) {
      let result = null;
      function scan(value) {
          if (value && typeof value == "object") {
              if (Array.isArray(value)) {
                  if (typeof value[0] == "string") {
                      if (!result)
                          result = [];
                      result.push(value);
                  }
                  else {
                      for (let i = 0; i < value.length; i++)
                          scan(value[i]);
                  }
              }
              else {
                  for (let prop in value)
                      scan(value[prop]);
              }
          }
      }
      scan(attrs);
      return result;
  }
  function renderSpec(doc, structure, xmlNS, blockArraysIn) {
      if (typeof structure == "string")
          return { dom: doc.createTextNode(structure) };
      if (structure.nodeType != null)
          return { dom: structure };
      if (structure.dom && structure.dom.nodeType != null)
          return structure;
      let tagName = structure[0], suspicious;
      if (typeof tagName != "string")
          throw new RangeError("Invalid array passed to renderSpec");
      if (blockArraysIn && (suspicious = suspiciousAttributes(blockArraysIn)) &&
          suspicious.indexOf(structure) > -1)
          throw new RangeError("Using an array from an attribute object as a DOM spec. This may be an attempted cross site scripting attack.");
      let space = tagName.indexOf(" ");
      if (space > 0) {
          xmlNS = tagName.slice(0, space);
          tagName = tagName.slice(space + 1);
      }
      let contentDOM;
      let dom = (xmlNS ? doc.createElementNS(xmlNS, tagName) : doc.createElement(tagName));
      let attrs = structure[1], start = 1;
      if (attrs && typeof attrs == "object" && attrs.nodeType == null && !Array.isArray(attrs)) {
          start = 2;
          for (let name in attrs)
              if (attrs[name] != null) {
                  let space = name.indexOf(" ");
                  if (space > 0)
                      dom.setAttributeNS(name.slice(0, space), name.slice(space + 1), attrs[name]);
                  else if (name == "style" && dom.style)
                      dom.style.cssText = attrs[name];
                  else
                      dom.setAttribute(name, attrs[name]);
              }
      }
      for (let i = start; i < structure.length; i++) {
          let child = structure[i];
          if (child === 0) {
              if (i < structure.length - 1 || i > start)
                  throw new RangeError("Content hole must be the only child of its parent node");
              return { dom, contentDOM: dom };
          }
          else {
              let { dom: inner, contentDOM: innerContent } = renderSpec(doc, child, xmlNS, blockArraysIn);
              dom.appendChild(inner);
              if (innerContent) {
                  if (contentDOM)
                      throw new RangeError("Multiple content holes");
                  contentDOM = innerContent;
              }
          }
      }
      return { dom, contentDOM };
  }

  // Recovery values encode a range index and an offset. They are
  // represented as numbers, because tons of them will be created when
  // mapping, for example, a large number of decorations. The number's
  // lower 16 bits provide the index, the remaining bits the offset.
  //
  // Note: We intentionally don't use bit shift operators to en- and
  // decode these, since those clip to 32 bits, which we might in rare
  // cases want to overflow. A 64-bit float can represent 48-bit
  // integers precisely.
  const lower16 = 0xffff;
  const factor16 = Math.pow(2, 16);
  function makeRecover(index, offset) { return index + offset * factor16; }
  function recoverIndex(value) { return value & lower16; }
  function recoverOffset(value) { return (value - (value & lower16)) / factor16; }
  const DEL_BEFORE = 1, DEL_AFTER = 2, DEL_ACROSS = 4, DEL_SIDE = 8;
  /**
  An object representing a mapped position with extra
  information.
  */
  class MapResult {
      /**
      @internal
      */
      constructor(
      /**
      The mapped version of the position.
      */
      pos, 
      /**
      @internal
      */
      delInfo, 
      /**
      @internal
      */
      recover) {
          this.pos = pos;
          this.delInfo = delInfo;
          this.recover = recover;
      }
      /**
      Tells you whether the position was deleted, that is, whether the
      step removed the token on the side queried (via the `assoc`)
      argument from the document.
      */
      get deleted() { return (this.delInfo & DEL_SIDE) > 0; }
      /**
      Tells you whether the token before the mapped position was deleted.
      */
      get deletedBefore() { return (this.delInfo & (DEL_BEFORE | DEL_ACROSS)) > 0; }
      /**
      True when the token after the mapped position was deleted.
      */
      get deletedAfter() { return (this.delInfo & (DEL_AFTER | DEL_ACROSS)) > 0; }
      /**
      Tells whether any of the steps mapped through deletes across the
      position (including both the token before and after the
      position).
      */
      get deletedAcross() { return (this.delInfo & DEL_ACROSS) > 0; }
  }
  /**
  A map describing the deletions and insertions made by a step, which
  can be used to find the correspondence between positions in the
  pre-step version of a document and the same position in the
  post-step version.
  */
  class StepMap {
      /**
      Create a position map. The modifications to the document are
      represented as an array of numbers, in which each group of three
      represents a modified chunk as `[start, oldSize, newSize]`.
      */
      constructor(
      /**
      @internal
      */
      ranges, 
      /**
      @internal
      */
      inverted = false) {
          this.ranges = ranges;
          this.inverted = inverted;
          if (!ranges.length && StepMap.empty)
              return StepMap.empty;
      }
      /**
      @internal
      */
      recover(value) {
          let diff = 0, index = recoverIndex(value);
          if (!this.inverted)
              for (let i = 0; i < index; i++)
                  diff += this.ranges[i * 3 + 2] - this.ranges[i * 3 + 1];
          return this.ranges[index * 3] + diff + recoverOffset(value);
      }
      mapResult(pos, assoc = 1) { return this._map(pos, assoc, false); }
      map(pos, assoc = 1) { return this._map(pos, assoc, true); }
      /**
      @internal
      */
      _map(pos, assoc, simple) {
          let diff = 0, oldIndex = this.inverted ? 2 : 1, newIndex = this.inverted ? 1 : 2;
          for (let i = 0; i < this.ranges.length; i += 3) {
              let start = this.ranges[i] - (this.inverted ? diff : 0);
              if (start > pos)
                  break;
              let oldSize = this.ranges[i + oldIndex], newSize = this.ranges[i + newIndex], end = start + oldSize;
              if (pos <= end) {
                  let side = !oldSize ? assoc : pos == start ? -1 : pos == end ? 1 : assoc;
                  let result = start + diff + (side < 0 ? 0 : newSize);
                  if (simple)
                      return result;
                  let recover = pos == (assoc < 0 ? start : end) ? null : makeRecover(i / 3, pos - start);
                  let del = pos == start ? DEL_AFTER : pos == end ? DEL_BEFORE : DEL_ACROSS;
                  if (assoc < 0 ? pos != start : pos != end)
                      del |= DEL_SIDE;
                  return new MapResult(result, del, recover);
              }
              diff += newSize - oldSize;
          }
          return simple ? pos + diff : new MapResult(pos + diff, 0, null);
      }
      /**
      @internal
      */
      touches(pos, recover) {
          let diff = 0, index = recoverIndex(recover);
          let oldIndex = this.inverted ? 2 : 1, newIndex = this.inverted ? 1 : 2;
          for (let i = 0; i < this.ranges.length; i += 3) {
              let start = this.ranges[i] - (this.inverted ? diff : 0);
              if (start > pos)
                  break;
              let oldSize = this.ranges[i + oldIndex], end = start + oldSize;
              if (pos <= end && i == index * 3)
                  return true;
              diff += this.ranges[i + newIndex] - oldSize;
          }
          return false;
      }
      /**
      Calls the given function on each of the changed ranges included in
      this map.
      */
      forEach(f) {
          let oldIndex = this.inverted ? 2 : 1, newIndex = this.inverted ? 1 : 2;
          for (let i = 0, diff = 0; i < this.ranges.length; i += 3) {
              let start = this.ranges[i], oldStart = start - (this.inverted ? diff : 0), newStart = start + (this.inverted ? 0 : diff);
              let oldSize = this.ranges[i + oldIndex], newSize = this.ranges[i + newIndex];
              f(oldStart, oldStart + oldSize, newStart, newStart + newSize);
              diff += newSize - oldSize;
          }
      }
      /**
      Create an inverted version of this map. The result can be used to
      map positions in the post-step document to the pre-step document.
      */
      invert() {
          return new StepMap(this.ranges, !this.inverted);
      }
      /**
      @internal
      */
      toString() {
          return (this.inverted ? "-" : "") + JSON.stringify(this.ranges);
      }
      /**
      Create a map that moves all positions by offset `n` (which may be
      negative). This can be useful when applying steps meant for a
      sub-document to a larger document, or vice-versa.
      */
      static offset(n) {
          return n == 0 ? StepMap.empty : new StepMap(n < 0 ? [0, -n, 0] : [0, 0, n]);
      }
  }
  /**
  A StepMap that contains no changed ranges.
  */
  StepMap.empty = new StepMap([]);
  /**
  A mapping represents a pipeline of zero or more [step
  maps](https://prosemirror.net/docs/ref/#transform.StepMap). It has special provisions for losslessly
  handling mapping positions through a series of steps in which some
  steps are inverted versions of earlier steps. (This comes up when
  ‘[rebasing](https://prosemirror.net/docs/guide/#transform.rebasing)’ steps for
  collaboration or history management.)
  */
  class Mapping {
      /**
      Create a new mapping with the given position maps.
      */
      constructor(maps, 
      /**
      @internal
      */
      mirror, 
      /**
      The starting position in the `maps` array, used when `map` or
      `mapResult` is called.
      */
      from = 0, 
      /**
      The end position in the `maps` array.
      */
      to = maps ? maps.length : 0) {
          this.mirror = mirror;
          this.from = from;
          this.to = to;
          this._maps = maps || [];
          this.ownData = !(maps || mirror);
      }
      /**
      The step maps in this mapping.
      */
      get maps() { return this._maps; }
      /**
      Create a mapping that maps only through a part of this one.
      */
      slice(from = 0, to = this.maps.length) {
          return new Mapping(this._maps, this.mirror, from, to);
      }
      /**
      Add a step map to the end of this mapping. If `mirrors` is
      given, it should be the index of the step map that is the mirror
      image of this one.
      */
      appendMap(map, mirrors) {
          if (!this.ownData) {
              this._maps = this._maps.slice();
              this.mirror = this.mirror && this.mirror.slice();
              this.ownData = true;
          }
          this.to = this._maps.push(map);
          if (mirrors != null)
              this.setMirror(this._maps.length - 1, mirrors);
      }
      /**
      Add all the step maps in a given mapping to this one (preserving
      mirroring information).
      */
      appendMapping(mapping) {
          for (let i = 0, startSize = this._maps.length; i < mapping._maps.length; i++) {
              let mirr = mapping.getMirror(i);
              this.appendMap(mapping._maps[i], mirr != null && mirr < i ? startSize + mirr : undefined);
          }
      }
      /**
      Finds the offset of the step map that mirrors the map at the
      given offset, in this mapping (as per the second argument to
      `appendMap`).
      */
      getMirror(n) {
          if (this.mirror)
              for (let i = 0; i < this.mirror.length; i++)
                  if (this.mirror[i] == n)
                      return this.mirror[i + (i % 2 ? -1 : 1)];
      }
      /**
      @internal
      */
      setMirror(n, m) {
          if (!this.mirror)
              this.mirror = [];
          this.mirror.push(n, m);
      }
      /**
      Append the inverse of the given mapping to this one.
      */
      appendMappingInverted(mapping) {
          for (let i = mapping.maps.length - 1, totalSize = this._maps.length + mapping._maps.length; i >= 0; i--) {
              let mirr = mapping.getMirror(i);
              this.appendMap(mapping._maps[i].invert(), mirr != null && mirr > i ? totalSize - mirr - 1 : undefined);
          }
      }
      /**
      Create an inverted version of this mapping.
      */
      invert() {
          let inverse = new Mapping;
          inverse.appendMappingInverted(this);
          return inverse;
      }
      /**
      Map a position through this mapping.
      */
      map(pos, assoc = 1) {
          if (this.mirror)
              return this._map(pos, assoc, true);
          for (let i = this.from; i < this.to; i++)
              pos = this._maps[i].map(pos, assoc);
          return pos;
      }
      /**
      Map a position through this mapping, returning a mapping
      result.
      */
      mapResult(pos, assoc = 1) { return this._map(pos, assoc, false); }
      /**
      @internal
      */
      _map(pos, assoc, simple) {
          let delInfo = 0;
          for (let i = this.from; i < this.to; i++) {
              let map = this._maps[i], result = map.mapResult(pos, assoc);
              if (result.recover != null) {
                  let corr = this.getMirror(i);
                  if (corr != null && corr > i && corr < this.to) {
                      i = corr;
                      pos = this._maps[corr].recover(result.recover);
                      continue;
                  }
              }
              delInfo |= result.delInfo;
              pos = result.pos;
          }
          return simple ? pos : new MapResult(pos, delInfo, null);
      }
  }

  const stepsByID = Object.create(null);
  /**
  A step object represents an atomic change. It generally applies
  only to the document it was created for, since the positions
  stored in it will only make sense for that document.

  New steps are defined by creating classes that extend `Step`,
  overriding the `apply`, `invert`, `map`, `getMap` and `fromJSON`
  methods, and registering your class with a unique
  JSON-serialization identifier using
  [`Step.jsonID`](https://prosemirror.net/docs/ref/#transform.Step^jsonID).
  */
  class Step {
      /**
      Get the step map that represents the changes made by this step,
      and which can be used to transform between positions in the old
      and the new document.
      */
      getMap() { return StepMap.empty; }
      /**
      Try to merge this step with another one, to be applied directly
      after it. Returns the merged step when possible, null if the
      steps can't be merged.
      */
      merge(other) { return null; }
      /**
      Deserialize a step from its JSON representation. Will call
      through to the step class' own implementation of this method.
      */
      static fromJSON(schema, json) {
          if (!json || !json.stepType)
              throw new RangeError("Invalid input for Step.fromJSON");
          let type = stepsByID[json.stepType];
          if (!type)
              throw new RangeError(`No step type ${json.stepType} defined`);
          return type.fromJSON(schema, json);
      }
      /**
      To be able to serialize steps to JSON, each step needs a string
      ID to attach to its JSON representation. Use this method to
      register an ID for your step classes. Try to pick something
      that's unlikely to clash with steps from other modules.
      */
      static jsonID(id, stepClass) {
          if (id in stepsByID)
              throw new RangeError("Duplicate use of step JSON ID " + id);
          stepsByID[id] = stepClass;
          stepClass.prototype.jsonID = id;
          return stepClass;
      }
  }
  /**
  The result of [applying](https://prosemirror.net/docs/ref/#transform.Step.apply) a step. Contains either a
  new document or a failure value.
  */
  class StepResult {
      /**
      @internal
      */
      constructor(
      /**
      The transformed document, if successful.
      */
      doc, 
      /**
      The failure message, if unsuccessful.
      */
      failed) {
          this.doc = doc;
          this.failed = failed;
      }
      /**
      Create a successful step result.
      */
      static ok(doc) { return new StepResult(doc, null); }
      /**
      Create a failed step result.
      */
      static fail(message) { return new StepResult(null, message); }
      /**
      Call [`Node.replace`](https://prosemirror.net/docs/ref/#model.Node.replace) with the given
      arguments. Create a successful result if it succeeds, and a
      failed one if it throws a `ReplaceError`.
      */
      static fromReplace(doc, from, to, slice) {
          try {
              return StepResult.ok(doc.replace(from, to, slice));
          }
          catch (e) {
              if (e instanceof ReplaceError)
                  return StepResult.fail(e.message);
              throw e;
          }
      }
  }

  function mapFragment(fragment, f, parent) {
      let mapped = [];
      for (let i = 0; i < fragment.childCount; i++) {
          let child = fragment.child(i);
          if (child.content.size)
              child = child.copy(mapFragment(child.content, f, child));
          if (child.isInline)
              child = f(child, parent, i);
          mapped.push(child);
      }
      return Fragment.fromArray(mapped);
  }
  /**
  Add a mark to all inline content between two positions.
  */
  class AddMarkStep extends Step {
      /**
      Create a mark step.
      */
      constructor(
      /**
      The start of the marked range.
      */
      from, 
      /**
      The end of the marked range.
      */
      to, 
      /**
      The mark to add.
      */
      mark) {
          super();
          this.from = from;
          this.to = to;
          this.mark = mark;
      }
      apply(doc) {
          let oldSlice = doc.slice(this.from, this.to), $from = doc.resolve(this.from);
          let parent = $from.node($from.sharedDepth(this.to));
          let slice = new Slice(mapFragment(oldSlice.content, (node, parent) => {
              if (!node.isAtom || !parent.type.allowsMarkType(this.mark.type))
                  return node;
              return node.mark(this.mark.addToSet(node.marks));
          }, parent), oldSlice.openStart, oldSlice.openEnd);
          return StepResult.fromReplace(doc, this.from, this.to, slice);
      }
      invert() {
          return new RemoveMarkStep(this.from, this.to, this.mark);
      }
      map(mapping) {
          let from = mapping.mapResult(this.from, 1), to = mapping.mapResult(this.to, -1);
          if (from.deleted && to.deleted || from.pos >= to.pos)
              return null;
          return new AddMarkStep(from.pos, to.pos, this.mark);
      }
      merge(other) {
          if (other instanceof AddMarkStep &&
              other.mark.eq(this.mark) &&
              this.from <= other.to && this.to >= other.from)
              return new AddMarkStep(Math.min(this.from, other.from), Math.max(this.to, other.to), this.mark);
          return null;
      }
      toJSON() {
          return { stepType: "addMark", mark: this.mark.toJSON(),
              from: this.from, to: this.to };
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.from != "number" || typeof json.to != "number")
              throw new RangeError("Invalid input for AddMarkStep.fromJSON");
          return new AddMarkStep(json.from, json.to, schema.markFromJSON(json.mark));
      }
  }
  Step.jsonID("addMark", AddMarkStep);
  /**
  Remove a mark from all inline content between two positions.
  */
  class RemoveMarkStep extends Step {
      /**
      Create a mark-removing step.
      */
      constructor(
      /**
      The start of the unmarked range.
      */
      from, 
      /**
      The end of the unmarked range.
      */
      to, 
      /**
      The mark to remove.
      */
      mark) {
          super();
          this.from = from;
          this.to = to;
          this.mark = mark;
      }
      apply(doc) {
          let oldSlice = doc.slice(this.from, this.to);
          let slice = new Slice(mapFragment(oldSlice.content, node => {
              return node.mark(this.mark.removeFromSet(node.marks));
          }, doc), oldSlice.openStart, oldSlice.openEnd);
          return StepResult.fromReplace(doc, this.from, this.to, slice);
      }
      invert() {
          return new AddMarkStep(this.from, this.to, this.mark);
      }
      map(mapping) {
          let from = mapping.mapResult(this.from, 1), to = mapping.mapResult(this.to, -1);
          if (from.deleted && to.deleted || from.pos >= to.pos)
              return null;
          return new RemoveMarkStep(from.pos, to.pos, this.mark);
      }
      merge(other) {
          if (other instanceof RemoveMarkStep &&
              other.mark.eq(this.mark) &&
              this.from <= other.to && this.to >= other.from)
              return new RemoveMarkStep(Math.min(this.from, other.from), Math.max(this.to, other.to), this.mark);
          return null;
      }
      toJSON() {
          return { stepType: "removeMark", mark: this.mark.toJSON(),
              from: this.from, to: this.to };
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.from != "number" || typeof json.to != "number")
              throw new RangeError("Invalid input for RemoveMarkStep.fromJSON");
          return new RemoveMarkStep(json.from, json.to, schema.markFromJSON(json.mark));
      }
  }
  Step.jsonID("removeMark", RemoveMarkStep);
  /**
  Add a mark to a specific node.
  */
  class AddNodeMarkStep extends Step {
      /**
      Create a node mark step.
      */
      constructor(
      /**
      The position of the target node.
      */
      pos, 
      /**
      The mark to add.
      */
      mark) {
          super();
          this.pos = pos;
          this.mark = mark;
      }
      apply(doc) {
          let node = doc.nodeAt(this.pos);
          if (!node)
              return StepResult.fail("No node at mark step's position");
          let updated = node.type.create(node.attrs, null, this.mark.addToSet(node.marks));
          return StepResult.fromReplace(doc, this.pos, this.pos + 1, new Slice(Fragment.from(updated), 0, node.isLeaf ? 0 : 1));
      }
      invert(doc) {
          let node = doc.nodeAt(this.pos);
          if (node) {
              let newSet = this.mark.addToSet(node.marks);
              if (newSet.length == node.marks.length) {
                  for (let i = 0; i < node.marks.length; i++)
                      if (!node.marks[i].isInSet(newSet))
                          return new AddNodeMarkStep(this.pos, node.marks[i]);
                  return new AddNodeMarkStep(this.pos, this.mark);
              }
          }
          return new RemoveNodeMarkStep(this.pos, this.mark);
      }
      map(mapping) {
          let pos = mapping.mapResult(this.pos, 1);
          return pos.deletedAfter ? null : new AddNodeMarkStep(pos.pos, this.mark);
      }
      toJSON() {
          return { stepType: "addNodeMark", pos: this.pos, mark: this.mark.toJSON() };
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.pos != "number")
              throw new RangeError("Invalid input for AddNodeMarkStep.fromJSON");
          return new AddNodeMarkStep(json.pos, schema.markFromJSON(json.mark));
      }
  }
  Step.jsonID("addNodeMark", AddNodeMarkStep);
  /**
  Remove a mark from a specific node.
  */
  class RemoveNodeMarkStep extends Step {
      /**
      Create a mark-removing step.
      */
      constructor(
      /**
      The position of the target node.
      */
      pos, 
      /**
      The mark to remove.
      */
      mark) {
          super();
          this.pos = pos;
          this.mark = mark;
      }
      apply(doc) {
          let node = doc.nodeAt(this.pos);
          if (!node)
              return StepResult.fail("No node at mark step's position");
          let updated = node.type.create(node.attrs, null, this.mark.removeFromSet(node.marks));
          return StepResult.fromReplace(doc, this.pos, this.pos + 1, new Slice(Fragment.from(updated), 0, node.isLeaf ? 0 : 1));
      }
      invert(doc) {
          let node = doc.nodeAt(this.pos);
          if (!node || !this.mark.isInSet(node.marks))
              return this;
          return new AddNodeMarkStep(this.pos, this.mark);
      }
      map(mapping) {
          let pos = mapping.mapResult(this.pos, 1);
          return pos.deletedAfter ? null : new RemoveNodeMarkStep(pos.pos, this.mark);
      }
      toJSON() {
          return { stepType: "removeNodeMark", pos: this.pos, mark: this.mark.toJSON() };
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.pos != "number")
              throw new RangeError("Invalid input for RemoveNodeMarkStep.fromJSON");
          return new RemoveNodeMarkStep(json.pos, schema.markFromJSON(json.mark));
      }
  }
  Step.jsonID("removeNodeMark", RemoveNodeMarkStep);

  /**
  Replace a part of the document with a slice of new content.
  */
  class ReplaceStep extends Step {
      /**
      The given `slice` should fit the 'gap' between `from` and
      `to`—the depths must line up, and the surrounding nodes must be
      able to be joined with the open sides of the slice. When
      `structure` is true, the step will fail if the content between
      from and to is not just a sequence of closing and then opening
      tokens (this is to guard against rebased replace steps
      overwriting something they weren't supposed to).
      */
      constructor(
      /**
      The start position of the replaced range.
      */
      from, 
      /**
      The end position of the replaced range.
      */
      to, 
      /**
      The slice to insert.
      */
      slice, 
      /**
      @internal
      */
      structure = false) {
          super();
          this.from = from;
          this.to = to;
          this.slice = slice;
          this.structure = structure;
      }
      apply(doc) {
          if (this.structure && contentBetween(doc, this.from, this.to))
              return StepResult.fail("Structure replace would overwrite content");
          return StepResult.fromReplace(doc, this.from, this.to, this.slice);
      }
      getMap() {
          return new StepMap([this.from, this.to - this.from, this.slice.size]);
      }
      invert(doc) {
          return new ReplaceStep(this.from, this.from + this.slice.size, doc.slice(this.from, this.to));
      }
      map(mapping) {
          let from = mapping.mapResult(this.from, 1), to = mapping.mapResult(this.to, -1);
          if (from.deletedAcross && to.deletedAcross)
              return null;
          return new ReplaceStep(from.pos, Math.max(from.pos, to.pos), this.slice, this.structure);
      }
      merge(other) {
          if (!(other instanceof ReplaceStep) || other.structure || this.structure)
              return null;
          if (this.from + this.slice.size == other.from && !this.slice.openEnd && !other.slice.openStart) {
              let slice = this.slice.size + other.slice.size == 0 ? Slice.empty
                  : new Slice(this.slice.content.append(other.slice.content), this.slice.openStart, other.slice.openEnd);
              return new ReplaceStep(this.from, this.to + (other.to - other.from), slice, this.structure);
          }
          else if (other.to == this.from && !this.slice.openStart && !other.slice.openEnd) {
              let slice = this.slice.size + other.slice.size == 0 ? Slice.empty
                  : new Slice(other.slice.content.append(this.slice.content), other.slice.openStart, this.slice.openEnd);
              return new ReplaceStep(other.from, this.to, slice, this.structure);
          }
          else {
              return null;
          }
      }
      toJSON() {
          let json = { stepType: "replace", from: this.from, to: this.to };
          if (this.slice.size)
              json.slice = this.slice.toJSON();
          if (this.structure)
              json.structure = true;
          return json;
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.from != "number" || typeof json.to != "number")
              throw new RangeError("Invalid input for ReplaceStep.fromJSON");
          return new ReplaceStep(json.from, json.to, Slice.fromJSON(schema, json.slice), !!json.structure);
      }
  }
  Step.jsonID("replace", ReplaceStep);
  /**
  Replace a part of the document with a slice of content, but
  preserve a range of the replaced content by moving it into the
  slice.
  */
  class ReplaceAroundStep extends Step {
      /**
      Create a replace-around step with the given range and gap.
      `insert` should be the point in the slice into which the content
      of the gap should be moved. `structure` has the same meaning as
      it has in the [`ReplaceStep`](https://prosemirror.net/docs/ref/#transform.ReplaceStep) class.
      */
      constructor(
      /**
      The start position of the replaced range.
      */
      from, 
      /**
      The end position of the replaced range.
      */
      to, 
      /**
      The start of preserved range.
      */
      gapFrom, 
      /**
      The end of preserved range.
      */
      gapTo, 
      /**
      The slice to insert.
      */
      slice, 
      /**
      The position in the slice where the preserved range should be
      inserted.
      */
      insert, 
      /**
      @internal
      */
      structure = false) {
          super();
          this.from = from;
          this.to = to;
          this.gapFrom = gapFrom;
          this.gapTo = gapTo;
          this.slice = slice;
          this.insert = insert;
          this.structure = structure;
      }
      apply(doc) {
          if (this.structure && (contentBetween(doc, this.from, this.gapFrom) ||
              contentBetween(doc, this.gapTo, this.to)))
              return StepResult.fail("Structure gap-replace would overwrite content");
          let gap = doc.slice(this.gapFrom, this.gapTo);
          if (gap.openStart || gap.openEnd)
              return StepResult.fail("Gap is not a flat range");
          let inserted = this.slice.insertAt(this.insert, gap.content);
          if (!inserted)
              return StepResult.fail("Content does not fit in gap");
          return StepResult.fromReplace(doc, this.from, this.to, inserted);
      }
      getMap() {
          return new StepMap([this.from, this.gapFrom - this.from, this.insert,
              this.gapTo, this.to - this.gapTo, this.slice.size - this.insert]);
      }
      invert(doc) {
          let gap = this.gapTo - this.gapFrom;
          return new ReplaceAroundStep(this.from, this.from + this.slice.size + gap, this.from + this.insert, this.from + this.insert + gap, doc.slice(this.from, this.to).removeBetween(this.gapFrom - this.from, this.gapTo - this.from), this.gapFrom - this.from, this.structure);
      }
      map(mapping) {
          let from = mapping.mapResult(this.from, 1), to = mapping.mapResult(this.to, -1);
          let gapFrom = this.from == this.gapFrom ? from.pos : mapping.map(this.gapFrom, -1);
          let gapTo = this.to == this.gapTo ? to.pos : mapping.map(this.gapTo, 1);
          if ((from.deletedAcross && to.deletedAcross) || gapFrom < from.pos || gapTo > to.pos)
              return null;
          return new ReplaceAroundStep(from.pos, to.pos, gapFrom, gapTo, this.slice, this.insert, this.structure);
      }
      toJSON() {
          let json = { stepType: "replaceAround", from: this.from, to: this.to,
              gapFrom: this.gapFrom, gapTo: this.gapTo, insert: this.insert };
          if (this.slice.size)
              json.slice = this.slice.toJSON();
          if (this.structure)
              json.structure = true;
          return json;
      }
      /**
      @internal
      */
      static fromJSON(schema, json) {
          if (typeof json.from != "number" || typeof json.to != "number" ||
              typeof json.gapFrom != "number" || typeof json.gapTo != "number" || typeof json.insert != "number")
              throw new RangeError("Invalid input for ReplaceAroundStep.fromJSON");
          return new ReplaceAroundStep(json.from, json.to, json.gapFrom, json.gapTo, Slice.fromJSON(schema, json.slice), json.insert, !!json.structure);
      }
  }
  Step.jsonID("replaceAround", ReplaceAroundStep);
  function contentBetween(doc, from, to) {
      let $from = doc.resolve(from), dist = to - from, depth = $from.depth;
      while (dist > 0 && depth > 0 && $from.indexAfter(depth) == $from.node(depth).childCount) {
          depth--;
          dist--;
      }
      if (dist > 0) {
          let next = $from.node(depth).maybeChild($from.indexAfter(depth));
          while (dist > 0) {
              if (!next || next.isLeaf)
                  return true;
              next = next.firstChild;
              dist--;
          }
      }
      return false;
  }

  function addMark(tr, from, to, mark) {
      let removed = [], added = [];
      let removing, adding;
      tr.doc.nodesBetween(from, to, (node, pos, parent) => {
          if (!node.isInline)
              return;
          let marks = node.marks;
          if (!mark.isInSet(marks) && parent.type.allowsMarkType(mark.type)) {
              let start = Math.max(pos, from), end = Math.min(pos + node.nodeSize, to);
              let newSet = mark.addToSet(marks);
              for (let i = 0; i < marks.length; i++) {
                  if (!marks[i].isInSet(newSet)) {
                      if (removing && removing.to == start && removing.mark.eq(marks[i]))
                          removing.to = end;
                      else
                          removed.push(removing = new RemoveMarkStep(start, end, marks[i]));
                  }
              }
              if (adding && adding.to == start)
                  adding.to = end;
              else
                  added.push(adding = new AddMarkStep(start, end, mark));
          }
      });
      removed.forEach(s => tr.step(s));
      added.forEach(s => tr.step(s));
  }
  function removeMark(tr, from, to, mark) {
      let matched = [], step = 0;
      tr.doc.nodesBetween(from, to, (node, pos) => {
          if (!node.isInline)
              return;
          step++;
          let toRemove = null;
          if (mark instanceof MarkType) {
              let set = node.marks, found;
              while (found = mark.isInSet(set)) {
                  (toRemove || (toRemove = [])).push(found);
                  set = found.removeFromSet(set);
              }
          }
          else if (mark) {
              if (mark.isInSet(node.marks))
                  toRemove = [mark];
          }
          else {
              toRemove = node.marks;
          }
          if (toRemove && toRemove.length) {
              let end = Math.min(pos + node.nodeSize, to);
              for (let i = 0; i < toRemove.length; i++) {
                  let style = toRemove[i], found;
                  for (let j = 0; j < matched.length; j++) {
                      let m = matched[j];
                      if (m.step == step - 1 && style.eq(matched[j].style))
                          found = m;
                  }
                  if (found) {
                      found.to = end;
                      found.step = step;
                  }
                  else {
                      matched.push({ style, from: Math.max(pos, from), to: end, step });
                  }
              }
          }
      });
      matched.forEach(m => tr.step(new RemoveMarkStep(m.from, m.to, m.style)));
  }
  function clearIncompatible(tr, pos, parentType, match = parentType.contentMatch, clearNewlines = true) {
      let node = tr.doc.nodeAt(pos);
      let replSteps = [], cur = pos + 1;
      for (let i = 0; i < node.childCount; i++) {
          let child = node.child(i), end = cur + child.nodeSize;
          let allowed = match.matchType(child.type);
          if (!allowed) {
              replSteps.push(new ReplaceStep(cur, end, Slice.empty));
          }
          else {
              match = allowed;
              for (let j = 0; j < child.marks.length; j++)
                  if (!parentType.allowsMarkType(child.marks[j].type))
                      tr.step(new RemoveMarkStep(cur, end, child.marks[j]));
              if (clearNewlines && child.isText && parentType.whitespace != "pre") {
                  let m, newline = /\r?\n|\r/g, slice;
                  while (m = newline.exec(child.text)) {
                      if (!slice)
                          slice = new Slice(Fragment.from(parentType.schema.text(" ", parentType.allowedMarks(child.marks))), 0, 0);
                      replSteps.push(new ReplaceStep(cur + m.index, cur + m.index + m[0].length, slice));
                  }
              }
          }
          cur = end;
      }
      if (!match.validEnd) {
          let fill = match.fillBefore(Fragment.empty, true);
          tr.replace(cur, cur, new Slice(fill, 0, 0));
      }
      for (let i = replSteps.length - 1; i >= 0; i--)
          tr.step(replSteps[i]);
  }

  function canCut(node, start, end) {
      return (start == 0 || node.canReplace(start, node.childCount)) &&
          (end == node.childCount || node.canReplace(0, end));
  }
  /**
  Try to find a target depth to which the content in the given range
  can be lifted. Will not go across
  [isolating](https://prosemirror.net/docs/ref/#model.NodeSpec.isolating) parent nodes.
  */
  function liftTarget(range) {
      let parent = range.parent;
      let content = parent.content.cutByIndex(range.startIndex, range.endIndex);
      for (let depth = range.depth;; --depth) {
          let node = range.$from.node(depth);
          let index = range.$from.index(depth), endIndex = range.$to.indexAfter(depth);
          if (depth < range.depth && node.canReplace(index, endIndex, content))
              return depth;
          if (depth == 0 || node.type.spec.isolating || !canCut(node, index, endIndex))
              break;
      }
      return null;
  }
  function lift(tr, range, target) {
      let { $from, $to, depth } = range;
      let gapStart = $from.before(depth + 1), gapEnd = $to.after(depth + 1);
      let start = gapStart, end = gapEnd;
      let before = Fragment.empty, openStart = 0;
      for (let d = depth, splitting = false; d > target; d--)
          if (splitting || $from.index(d) > 0) {
              splitting = true;
              before = Fragment.from($from.node(d).copy(before));
              openStart++;
          }
          else {
              start--;
          }
      let after = Fragment.empty, openEnd = 0;
      for (let d = depth, splitting = false; d > target; d--)
          if (splitting || $to.after(d + 1) < $to.end(d)) {
              splitting = true;
              after = Fragment.from($to.node(d).copy(after));
              openEnd++;
          }
          else {
              end++;
          }
      tr.step(new ReplaceAroundStep(start, end, gapStart, gapEnd, new Slice(before.append(after), openStart, openEnd), before.size - openStart, true));
  }
  /**
  Try to find a valid way to wrap the content in the given range in a
  node of the given type. May introduce extra nodes around and inside
  the wrapper node, if necessary. Returns null if no valid wrapping
  could be found. When `innerRange` is given, that range's content is
  used as the content to fit into the wrapping, instead of the
  content of `range`.
  */
  function findWrapping(range, nodeType, attrs = null, innerRange = range) {
      let around = findWrappingOutside(range, nodeType);
      let inner = around && findWrappingInside(innerRange, nodeType);
      if (!inner)
          return null;
      return around.map(withAttrs)
          .concat({ type: nodeType, attrs }).concat(inner.map(withAttrs));
  }
  function withAttrs(type) { return { type, attrs: null }; }
  function findWrappingOutside(range, type) {
      let { parent, startIndex, endIndex } = range;
      let around = parent.contentMatchAt(startIndex).findWrapping(type);
      if (!around)
          return null;
      let outer = around.length ? around[0] : type;
      return parent.canReplaceWith(startIndex, endIndex, outer) ? around : null;
  }
  function findWrappingInside(range, type) {
      let { parent, startIndex, endIndex } = range;
      let inner = parent.child(startIndex);
      let inside = type.contentMatch.findWrapping(inner.type);
      if (!inside)
          return null;
      let lastType = inside.length ? inside[inside.length - 1] : type;
      let innerMatch = lastType.contentMatch;
      for (let i = startIndex; innerMatch && i < endIndex; i++)
          innerMatch = innerMatch.matchType(parent.child(i).type);
      if (!innerMatch || !innerMatch.validEnd)
          return null;
      return inside;
  }
  function wrap(tr, range, wrappers) {
      let content = Fragment.empty;
      for (let i = wrappers.length - 1; i >= 0; i--) {
          if (content.size) {
              let match = wrappers[i].type.contentMatch.matchFragment(content);
              if (!match || !match.validEnd)
                  throw new RangeError("Wrapper type given to Transform.wrap does not form valid content of its parent wrapper");
          }
          content = Fragment.from(wrappers[i].type.create(wrappers[i].attrs, content));
      }
      let start = range.start, end = range.end;
      tr.step(new ReplaceAroundStep(start, end, start, end, new Slice(content, 0, 0), wrappers.length, true));
  }
  function setBlockType(tr, from, to, type, attrs) {
      if (!type.isTextblock)
          throw new RangeError("Type given to setBlockType should be a textblock");
      let mapFrom = tr.steps.length;
      tr.doc.nodesBetween(from, to, (node, pos) => {
          let attrsHere = typeof attrs == "function" ? attrs(node) : attrs;
          if (node.isTextblock && !node.hasMarkup(type, attrsHere) &&
              canChangeType(tr.doc, tr.mapping.slice(mapFrom).map(pos), type)) {
              let convertNewlines = null;
              if (type.schema.linebreakReplacement) {
                  let pre = type.whitespace == "pre", supportLinebreak = !!type.contentMatch.matchType(type.schema.linebreakReplacement);
                  if (pre && !supportLinebreak)
                      convertNewlines = false;
                  else if (!pre && supportLinebreak)
                      convertNewlines = true;
              }
              // Ensure all markup that isn't allowed in the new node type is cleared
              if (convertNewlines === false)
                  replaceLinebreaks(tr, node, pos, mapFrom);
              clearIncompatible(tr, tr.mapping.slice(mapFrom).map(pos, 1), type, undefined, convertNewlines === null);
              let mapping = tr.mapping.slice(mapFrom);
              let startM = mapping.map(pos, 1), endM = mapping.map(pos + node.nodeSize, 1);
              tr.step(new ReplaceAroundStep(startM, endM, startM + 1, endM - 1, new Slice(Fragment.from(type.create(attrsHere, null, node.marks)), 0, 0), 1, true));
              if (convertNewlines === true)
                  replaceNewlines(tr, node, pos, mapFrom);
              return false;
          }
      });
  }
  function replaceNewlines(tr, node, pos, mapFrom) {
      node.forEach((child, offset) => {
          if (child.isText) {
              let m, newline = /\r?\n|\r/g;
              while (m = newline.exec(child.text)) {
                  let start = tr.mapping.slice(mapFrom).map(pos + 1 + offset + m.index);
                  tr.replaceWith(start, start + 1, node.type.schema.linebreakReplacement.create());
              }
          }
      });
  }
  function replaceLinebreaks(tr, node, pos, mapFrom) {
      node.forEach((child, offset) => {
          if (child.type == child.type.schema.linebreakReplacement) {
              let start = tr.mapping.slice(mapFrom).map(pos + 1 + offset);
              tr.replaceWith(start, start + 1, node.type.schema.text("\n"));
          }
      });
  }
  function canChangeType(doc, pos, type) {
      let $pos = doc.resolve(pos), index = $pos.index();
      return $pos.parent.canReplaceWith(index, index + 1, type);
  }
  /**
  Change the type, attributes, and/or marks of the node at `pos`.
  When `type` isn't given, the existing node type is preserved,
  */
  function setNodeMarkup(tr, pos, type, attrs, marks) {
      let node = tr.doc.nodeAt(pos);
      if (!node)
          throw new RangeError("No node at given position");
      if (!type)
          type = node.type;
      let newNode = type.create(attrs, null, marks || node.marks);
      if (node.isLeaf)
          return tr.replaceWith(pos, pos + node.nodeSize, newNode);
      if (!type.validContent(node.content))
          throw new RangeError("Invalid content for node type " + type.name);
      tr.step(new ReplaceAroundStep(pos, pos + node.nodeSize, pos + 1, pos + node.nodeSize - 1, new Slice(Fragment.from(newNode), 0, 0), 1, true));
  }
  /**
  Check whether splitting at the given position is allowed.
  */
  function canSplit(doc, pos, depth = 1, typesAfter) {
      let $pos = doc.resolve(pos), base = $pos.depth - depth;
      let innerType = (typesAfter && typesAfter[typesAfter.length - 1]) || $pos.parent;
      if (base < 0 || $pos.parent.type.spec.isolating ||
          !$pos.parent.canReplace($pos.index(), $pos.parent.childCount) ||
          !innerType.type.validContent($pos.parent.content.cutByIndex($pos.index(), $pos.parent.childCount)))
          return false;
      for (let d = $pos.depth - 1, i = depth - 2; d > base; d--, i--) {
          let node = $pos.node(d), index = $pos.index(d);
          if (node.type.spec.isolating)
              return false;
          let rest = node.content.cutByIndex(index, node.childCount);
          let overrideChild = typesAfter && typesAfter[i + 1];
          if (overrideChild)
              rest = rest.replaceChild(0, overrideChild.type.create(overrideChild.attrs));
          let after = (typesAfter && typesAfter[i]) || node;
          if (!node.canReplace(index + 1, node.childCount) || !after.type.validContent(rest))
              return false;
      }
      let index = $pos.indexAfter(base);
      let baseType = typesAfter && typesAfter[0];
      return $pos.node(base).canReplaceWith(index, index, baseType ? baseType.type : $pos.node(base + 1).type);
  }
  function split(tr, pos, depth = 1, typesAfter) {
      let $pos = tr.doc.resolve(pos), before = Fragment.empty, after = Fragment.empty;
      for (let d = $pos.depth, e = $pos.depth - depth, i = depth - 1; d > e; d--, i--) {
          before = Fragment.from($pos.node(d).copy(before));
          let typeAfter = typesAfter && typesAfter[i];
          after = Fragment.from(typeAfter ? typeAfter.type.create(typeAfter.attrs, after) : $pos.node(d).copy(after));
      }
      tr.step(new ReplaceStep(pos, pos, new Slice(before.append(after), depth, depth), true));
  }
  /**
  Test whether the blocks before and after a given position can be
  joined.
  */
  function canJoin(doc, pos) {
      let $pos = doc.resolve(pos), index = $pos.index();
      return joinable($pos.nodeBefore, $pos.nodeAfter) &&
          $pos.parent.canReplace(index, index + 1);
  }
  function canAppendWithSubstitutedLinebreaks(a, b) {
      if (!b.content.size)
          a.type.compatibleContent(b.type);
      let match = a.contentMatchAt(a.childCount);
      let { linebreakReplacement } = a.type.schema;
      for (let i = 0; i < b.childCount; i++) {
          let child = b.child(i);
          let type = child.type == linebreakReplacement ? a.type.schema.nodes.text : child.type;
          match = match.matchType(type);
          if (!match)
              return false;
          if (!a.type.allowsMarks(child.marks))
              return false;
      }
      return match.validEnd;
  }
  function joinable(a, b) {
      return !!(a && b && !a.isLeaf && canAppendWithSubstitutedLinebreaks(a, b));
  }
  function join(tr, pos, depth) {
      let convertNewlines = null;
      let { linebreakReplacement } = tr.doc.type.schema;
      let $before = tr.doc.resolve(pos - depth), beforeType = $before.node().type;
      if (linebreakReplacement && beforeType.inlineContent) {
          let pre = beforeType.whitespace == "pre";
          let supportLinebreak = !!beforeType.contentMatch.matchType(linebreakReplacement);
          if (pre && !supportLinebreak)
              convertNewlines = false;
          else if (!pre && supportLinebreak)
              convertNewlines = true;
      }
      let mapFrom = tr.steps.length;
      if (convertNewlines === false) {
          let $after = tr.doc.resolve(pos + depth);
          replaceLinebreaks(tr, $after.node(), $after.before(), mapFrom);
      }
      if (beforeType.inlineContent)
          clearIncompatible(tr, pos + depth - 1, beforeType, $before.node().contentMatchAt($before.index()), convertNewlines == null);
      let mapping = tr.mapping.slice(mapFrom), start = mapping.map(pos - depth);
      tr.step(new ReplaceStep(start, mapping.map(pos + depth, -1), Slice.empty, true));
      if (convertNewlines === true) {
          let $full = tr.doc.resolve(start);
          replaceNewlines(tr, $full.node(), $full.before(), tr.steps.length);
      }
      return tr;
  }
  /**
  Try to find a point where a node of the given type can be inserted
  near `pos`, by searching up the node hierarchy when `pos` itself
  isn't a valid place but is at the start or end of a node. Return
  null if no position was found.
  */
  function insertPoint(doc, pos, nodeType) {
      let $pos = doc.resolve(pos);
      if ($pos.parent.canReplaceWith($pos.index(), $pos.index(), nodeType))
          return pos;
      if ($pos.parentOffset == 0)
          for (let d = $pos.depth - 1; d >= 0; d--) {
              let index = $pos.index(d);
              if ($pos.node(d).canReplaceWith(index, index, nodeType))
                  return $pos.before(d + 1);
              if (index > 0)
                  return null;
          }
      if ($pos.parentOffset == $pos.parent.content.size)
          for (let d = $pos.depth - 1; d >= 0; d--) {
              let index = $pos.indexAfter(d);
              if ($pos.node(d).canReplaceWith(index, index, nodeType))
                  return $pos.after(d + 1);
              if (index < $pos.node(d).childCount)
                  return null;
          }
      return null;
  }
  /**
  Finds a position at or around the given position where the given
  slice can be inserted. Will look at parent nodes' nearest boundary
  and try there, even if the original position wasn't directly at the
  start or end of that node. Returns null when no position was found.
  */
  function dropPoint(doc, pos, slice) {
      let $pos = doc.resolve(pos);
      if (!slice.content.size)
          return pos;
      let content = slice.content;
      for (let i = 0; i < slice.openStart; i++)
          content = content.firstChild.content;
      for (let pass = 1; pass <= (slice.openStart == 0 && slice.size ? 2 : 1); pass++) {
          for (let d = $pos.depth; d >= 0; d--) {
              let bias = d == $pos.depth ? 0 : $pos.pos <= ($pos.start(d + 1) + $pos.end(d + 1)) / 2 ? -1 : 1;
              let insertPos = $pos.index(d) + (bias > 0 ? 1 : 0);
              let parent = $pos.node(d), fits = false;
              if (pass == 1) {
                  fits = parent.canReplace(insertPos, insertPos, content);
              }
              else {
                  let wrapping = parent.contentMatchAt(insertPos).findWrapping(content.firstChild.type);
                  fits = wrapping && parent.canReplaceWith(insertPos, insertPos, wrapping[0]);
              }
              if (fits)
                  return bias == 0 ? $pos.pos : bias < 0 ? $pos.before(d + 1) : $pos.after(d + 1);
          }
      }
      return null;
  }

  /**
  ‘Fit’ a slice into a given position in the document, producing a
  [step](https://prosemirror.net/docs/ref/#transform.Step) that inserts it. Will return null if
  there's no meaningful way to insert the slice here, or inserting it
  would be a no-op (an empty slice over an empty range).
  */
  function replaceStep(doc, from, to = from, slice = Slice.empty) {
      if (from == to && !slice.size)
          return null;
      let $from = doc.resolve(from), $to = doc.resolve(to);
      // Optimization -- avoid work if it's obvious that it's not needed.
      if (fitsTrivially($from, $to, slice))
          return new ReplaceStep(from, to, slice);
      return new Fitter($from, $to, slice).fit();
  }
  function fitsTrivially($from, $to, slice) {
      return !slice.openStart && !slice.openEnd && $from.start() == $to.start() &&
          $from.parent.canReplace($from.index(), $to.index(), slice.content);
  }
  // Algorithm for 'placing' the elements of a slice into a gap:
  //
  // We consider the content of each node that is open to the left to be
  // independently placeable. I.e. in <p("foo"), p("bar")>, when the
  // paragraph on the left is open, "foo" can be placed (somewhere on
  // the left side of the replacement gap) independently from p("bar").
  //
  // This class tracks the state of the placement progress in the
  // following properties:
  //
  //  - `frontier` holds a stack of `{type, match}` objects that
  //    represent the open side of the replacement. It starts at
  //    `$from`, then moves forward as content is placed, and is finally
  //    reconciled with `$to`.
  //
  //  - `unplaced` is a slice that represents the content that hasn't
  //    been placed yet.
  //
  //  - `placed` is a fragment of placed content. Its open-start value
  //    is implicit in `$from`, and its open-end value in `frontier`.
  class Fitter {
      constructor($from, $to, unplaced) {
          this.$from = $from;
          this.$to = $to;
          this.unplaced = unplaced;
          this.frontier = [];
          this.placed = Fragment.empty;
          for (let i = 0; i <= $from.depth; i++) {
              let node = $from.node(i);
              this.frontier.push({
                  type: node.type,
                  match: node.contentMatchAt($from.indexAfter(i))
              });
          }
          for (let i = $from.depth; i > 0; i--)
              this.placed = Fragment.from($from.node(i).copy(this.placed));
      }
      get depth() { return this.frontier.length - 1; }
      fit() {
          // As long as there's unplaced content, try to place some of it.
          // If that fails, either increase the open score of the unplaced
          // slice, or drop nodes from it, and then try again.
          while (this.unplaced.size) {
              let fit = this.findFittable();
              if (fit)
                  this.placeNodes(fit);
              else
                  this.openMore() || this.dropNode();
          }
          // When there's inline content directly after the frontier _and_
          // directly after `this.$to`, we must generate a `ReplaceAround`
          // step that pulls that content into the node after the frontier.
          // That means the fitting must be done to the end of the textblock
          // node after `this.$to`, not `this.$to` itself.
          let moveInline = this.mustMoveInline(), placedSize = this.placed.size - this.depth - this.$from.depth;
          let $from = this.$from, $to = this.close(moveInline < 0 ? this.$to : $from.doc.resolve(moveInline));
          if (!$to)
              return null;
          // If closing to `$to` succeeded, create a step
          let content = this.placed, openStart = $from.depth, openEnd = $to.depth;
          while (openStart && openEnd && content.childCount == 1) { // Normalize by dropping open parent nodes
              content = content.firstChild.content;
              openStart--;
              openEnd--;
          }
          let slice = new Slice(content, openStart, openEnd);
          if (moveInline > -1)
              return new ReplaceAroundStep($from.pos, moveInline, this.$to.pos, this.$to.end(), slice, placedSize);
          if (slice.size || $from.pos != this.$to.pos) // Don't generate no-op steps
              return new ReplaceStep($from.pos, $to.pos, slice);
          return null;
      }
      // Find a position on the start spine of `this.unplaced` that has
      // content that can be moved somewhere on the frontier. Returns two
      // depths, one for the slice and one for the frontier.
      findFittable() {
          let startDepth = this.unplaced.openStart;
          for (let cur = this.unplaced.content, d = 0, openEnd = this.unplaced.openEnd; d < startDepth; d++) {
              let node = cur.firstChild;
              if (cur.childCount > 1)
                  openEnd = 0;
              if (node.type.spec.isolating && openEnd <= d) {
                  startDepth = d;
                  break;
              }
              cur = node.content;
          }
          // Only try wrapping nodes (pass 2) after finding a place without
          // wrapping failed.
          for (let pass = 1; pass <= 2; pass++) {
              for (let sliceDepth = pass == 1 ? startDepth : this.unplaced.openStart; sliceDepth >= 0; sliceDepth--) {
                  let fragment, parent = null;
                  if (sliceDepth) {
                      parent = contentAt(this.unplaced.content, sliceDepth - 1).firstChild;
                      fragment = parent.content;
                  }
                  else {
                      fragment = this.unplaced.content;
                  }
                  let first = fragment.firstChild;
                  for (let frontierDepth = this.depth; frontierDepth >= 0; frontierDepth--) {
                      let { type, match } = this.frontier[frontierDepth], wrap, inject = null;
                      // In pass 1, if the next node matches, or there is no next
                      // node but the parents look compatible, we've found a
                      // place.
                      if (pass == 1 && (first ? match.matchType(first.type) || (inject = match.fillBefore(Fragment.from(first), false))
                          : parent && type.compatibleContent(parent.type)))
                          return { sliceDepth, frontierDepth, parent, inject };
                      // In pass 2, look for a set of wrapping nodes that make
                      // `first` fit here.
                      else if (pass == 2 && first && (wrap = match.findWrapping(first.type)))
                          return { sliceDepth, frontierDepth, parent, wrap };
                      // Don't continue looking further up if the parent node
                      // would fit here.
                      if (parent && match.matchType(parent.type))
                          break;
                  }
              }
          }
      }
      openMore() {
          let { content, openStart, openEnd } = this.unplaced;
          let inner = contentAt(content, openStart);
          if (!inner.childCount || inner.firstChild.isLeaf)
              return false;
          this.unplaced = new Slice(content, openStart + 1, Math.max(openEnd, inner.size + openStart >= content.size - openEnd ? openStart + 1 : 0));
          return true;
      }
      dropNode() {
          let { content, openStart, openEnd } = this.unplaced;
          let inner = contentAt(content, openStart);
          if (inner.childCount <= 1 && openStart > 0) {
              let openAtEnd = content.size - openStart <= openStart + inner.size;
              this.unplaced = new Slice(dropFromFragment(content, openStart - 1, 1), openStart - 1, openAtEnd ? openStart - 1 : openEnd);
          }
          else {
              this.unplaced = new Slice(dropFromFragment(content, openStart, 1), openStart, openEnd);
          }
      }
      // Move content from the unplaced slice at `sliceDepth` to the
      // frontier node at `frontierDepth`. Close that frontier node when
      // applicable.
      placeNodes({ sliceDepth, frontierDepth, parent, inject, wrap }) {
          while (this.depth > frontierDepth)
              this.closeFrontierNode();
          if (wrap)
              for (let i = 0; i < wrap.length; i++)
                  this.openFrontierNode(wrap[i]);
          let slice = this.unplaced, fragment = parent ? parent.content : slice.content;
          let openStart = slice.openStart - sliceDepth;
          let taken = 0, add = [];
          let { match, type } = this.frontier[frontierDepth];
          if (inject) {
              for (let i = 0; i < inject.childCount; i++)
                  add.push(inject.child(i));
              match = match.matchFragment(inject);
          }
          // Computes the amount of (end) open nodes at the end of the
          // fragment. When 0, the parent is open, but no more. When
          // negative, nothing is open.
          let openEndCount = (fragment.size + sliceDepth) - (slice.content.size - slice.openEnd);
          // Scan over the fragment, fitting as many child nodes as
          // possible.
          while (taken < fragment.childCount) {
              let next = fragment.child(taken), matches = match.matchType(next.type);
              if (!matches)
                  break;
              taken++;
              if (taken > 1 || openStart == 0 || next.content.size) { // Drop empty open nodes
                  match = matches;
                  add.push(closeNodeStart(next.mark(type.allowedMarks(next.marks)), taken == 1 ? openStart : 0, taken == fragment.childCount ? openEndCount : -1));
              }
          }
          let toEnd = taken == fragment.childCount;
          if (!toEnd)
              openEndCount = -1;
          this.placed = addToFragment(this.placed, frontierDepth, Fragment.from(add));
          this.frontier[frontierDepth].match = match;
          // If the parent types match, and the entire node was moved, and
          // it's not open, close this frontier node right away.
          if (toEnd && openEndCount < 0 && parent && parent.type == this.frontier[this.depth].type && this.frontier.length > 1)
              this.closeFrontierNode();
          // Add new frontier nodes for any open nodes at the end.
          for (let i = 0, cur = fragment; i < openEndCount; i++) {
              let node = cur.lastChild;
              this.frontier.push({ type: node.type, match: node.contentMatchAt(node.childCount) });
              cur = node.content;
          }
          // Update `this.unplaced`. Drop the entire node from which we
          // placed it we got to its end, otherwise just drop the placed
          // nodes.
          this.unplaced = !toEnd ? new Slice(dropFromFragment(slice.content, sliceDepth, taken), slice.openStart, slice.openEnd)
              : sliceDepth == 0 ? Slice.empty
                  : new Slice(dropFromFragment(slice.content, sliceDepth - 1, 1), sliceDepth - 1, openEndCount < 0 ? slice.openEnd : sliceDepth - 1);
      }
      mustMoveInline() {
          if (!this.$to.parent.isTextblock)
              return -1;
          let top = this.frontier[this.depth], level;
          if (!top.type.isTextblock || !contentAfterFits(this.$to, this.$to.depth, top.type, top.match, false) ||
              (this.$to.depth == this.depth && (level = this.findCloseLevel(this.$to)) && level.depth == this.depth))
              return -1;
          let { depth } = this.$to, after = this.$to.after(depth);
          while (depth > 1 && after == this.$to.end(--depth))
              ++after;
          return after;
      }
      findCloseLevel($to) {
          scan: for (let i = Math.min(this.depth, $to.depth); i >= 0; i--) {
              let { match, type } = this.frontier[i];
              let dropInner = i < $to.depth && $to.end(i + 1) == $to.pos + ($to.depth - (i + 1));
              let fit = contentAfterFits($to, i, type, match, dropInner);
              if (!fit)
                  continue;
              for (let d = i - 1; d >= 0; d--) {
                  let { match, type } = this.frontier[d];
                  let matches = contentAfterFits($to, d, type, match, true);
                  if (!matches || matches.childCount)
                      continue scan;
              }
              return { depth: i, fit, move: dropInner ? $to.doc.resolve($to.after(i + 1)) : $to };
          }
      }
      close($to) {
          let close = this.findCloseLevel($to);
          if (!close)
              return null;
          while (this.depth > close.depth)
              this.closeFrontierNode();
          if (close.fit.childCount)
              this.placed = addToFragment(this.placed, close.depth, close.fit);
          $to = close.move;
          for (let d = close.depth + 1; d <= $to.depth; d++) {
              let node = $to.node(d), add = node.type.contentMatch.fillBefore(node.content, true, $to.index(d));
              this.openFrontierNode(node.type, node.attrs, add);
          }
          return $to;
      }
      openFrontierNode(type, attrs = null, content) {
          let top = this.frontier[this.depth];
          top.match = top.match.matchType(type);
          this.placed = addToFragment(this.placed, this.depth, Fragment.from(type.create(attrs, content)));
          this.frontier.push({ type, match: type.contentMatch });
      }
      closeFrontierNode() {
          let open = this.frontier.pop();
          let add = open.match.fillBefore(Fragment.empty, true);
          if (add.childCount)
              this.placed = addToFragment(this.placed, this.frontier.length, add);
      }
  }
  function dropFromFragment(fragment, depth, count) {
      if (depth == 0)
          return fragment.cutByIndex(count, fragment.childCount);
      return fragment.replaceChild(0, fragment.firstChild.copy(dropFromFragment(fragment.firstChild.content, depth - 1, count)));
  }
  function addToFragment(fragment, depth, content) {
      if (depth == 0)
          return fragment.append(content);
      return fragment.replaceChild(fragment.childCount - 1, fragment.lastChild.copy(addToFragment(fragment.lastChild.content, depth - 1, content)));
  }
  function contentAt(fragment, depth) {
      for (let i = 0; i < depth; i++)
          fragment = fragment.firstChild.content;
      return fragment;
  }
  function closeNodeStart(node, openStart, openEnd) {
      if (openStart <= 0)
          return node;
      let frag = node.content;
      if (openStart > 1)
          frag = frag.replaceChild(0, closeNodeStart(frag.firstChild, openStart - 1, frag.childCount == 1 ? openEnd - 1 : 0));
      if (openStart > 0) {
          frag = node.type.contentMatch.fillBefore(frag).append(frag);
          if (openEnd <= 0)
              frag = frag.append(node.type.contentMatch.matchFragment(frag).fillBefore(Fragment.empty, true));
      }
      return node.copy(frag);
  }
  function contentAfterFits($to, depth, type, match, open) {
      let node = $to.node(depth), index = open ? $to.indexAfter(depth) : $to.index(depth);
      if (index == node.childCount && !type.compatibleContent(node.type))
          return null;
      let fit = match.fillBefore(node.content, true, index);
      return fit && !invalidMarks(type, node.content, index) ? fit : null;
  }
  function invalidMarks(type, fragment, start) {
      for (let i = start; i < fragment.childCount; i++)
          if (!type.allowsMarks(fragment.child(i).marks))
              return true;
      return false;
  }
  function definesContent(type) {
      return type.spec.defining || type.spec.definingForContent;
  }
  function replaceRange(tr, from, to, slice) {
      if (!slice.size)
          return tr.deleteRange(from, to);
      let $from = tr.doc.resolve(from), $to = tr.doc.resolve(to);
      if (fitsTrivially($from, $to, slice))
          return tr.step(new ReplaceStep(from, to, slice));
      let targetDepths = coveredDepths($from, tr.doc.resolve(to));
      // Can't replace the whole document, so remove 0 if it's present
      if (targetDepths[targetDepths.length - 1] == 0)
          targetDepths.pop();
      // Negative numbers represent not expansion over the whole node at
      // that depth, but replacing from $from.before(-D) to $to.pos.
      let preferredTarget = -($from.depth + 1);
      targetDepths.unshift(preferredTarget);
      // This loop picks a preferred target depth, if one of the covering
      // depths is not outside of a defining node, and adds negative
      // depths for any depth that has $from at its start and does not
      // cross a defining node.
      for (let d = $from.depth, pos = $from.pos - 1; d > 0; d--, pos--) {
          let spec = $from.node(d).type.spec;
          if (spec.defining || spec.definingAsContext || spec.isolating)
              break;
          if (targetDepths.indexOf(d) > -1)
              preferredTarget = d;
          else if ($from.before(d) == pos)
              targetDepths.splice(1, 0, -d);
      }
      // Try to fit each possible depth of the slice into each possible
      // target depth, starting with the preferred depths.
      let preferredTargetIndex = targetDepths.indexOf(preferredTarget);
      let leftNodes = [], preferredDepth = slice.openStart;
      for (let content = slice.content, i = 0;; i++) {
          let node = content.firstChild;
          leftNodes.push(node);
          if (i == slice.openStart)
              break;
          content = node.content;
      }
      // Back up preferredDepth to cover defining textblocks directly
      // above it, possibly skipping a non-defining textblock.
      for (let d = preferredDepth - 1; d >= 0; d--) {
          let leftNode = leftNodes[d], def = definesContent(leftNode.type);
          if (def && !leftNode.sameMarkup($from.node(Math.abs(preferredTarget) - 1)))
              preferredDepth = d;
          else if (def || !leftNode.type.isTextblock)
              break;
      }
      for (let j = slice.openStart; j >= 0; j--) {
          let openDepth = (j + preferredDepth + 1) % (slice.openStart + 1);
          let insert = leftNodes[openDepth];
          if (!insert)
              continue;
          for (let i = 0; i < targetDepths.length; i++) {
              // Loop over possible expansion levels, starting with the
              // preferred one
              let targetDepth = targetDepths[(i + preferredTargetIndex) % targetDepths.length], expand = true;
              if (targetDepth < 0) {
                  expand = false;
                  targetDepth = -targetDepth;
              }
              let parent = $from.node(targetDepth - 1), index = $from.index(targetDepth - 1);
              if (parent.canReplaceWith(index, index, insert.type, insert.marks))
                  return tr.replace($from.before(targetDepth), expand ? $to.after(targetDepth) : to, new Slice(closeFragment(slice.content, 0, slice.openStart, openDepth), openDepth, slice.openEnd));
          }
      }
      let startSteps = tr.steps.length;
      for (let i = targetDepths.length - 1; i >= 0; i--) {
          tr.replace(from, to, slice);
          if (tr.steps.length > startSteps)
              break;
          let depth = targetDepths[i];
          if (depth < 0)
              continue;
          from = $from.before(depth);
          to = $to.after(depth);
      }
  }
  function closeFragment(fragment, depth, oldOpen, newOpen, parent) {
      if (depth < oldOpen) {
          let first = fragment.firstChild;
          fragment = fragment.replaceChild(0, first.copy(closeFragment(first.content, depth + 1, oldOpen, newOpen, first)));
      }
      if (depth > newOpen) {
          let match = parent.contentMatchAt(0);
          let start = match.fillBefore(fragment).append(fragment);
          fragment = start.append(match.matchFragment(start).fillBefore(Fragment.empty, true));
      }
      return fragment;
  }
  function replaceRangeWith(tr, from, to, node) {
      if (!node.isInline && from == to && tr.doc.resolve(from).parent.content.size) {
          let point = insertPoint(tr.doc, from, node.type);
          if (point != null)
              from = to = point;
      }
      tr.replaceRange(from, to, new Slice(Fragment.from(node), 0, 0));
  }
  function deleteRange(tr, from, to) {
      let $from = tr.doc.resolve(from), $to = tr.doc.resolve(to);
      let covered = coveredDepths($from, $to);
      for (let i = 0; i < covered.length; i++) {
          let depth = covered[i], last = i == covered.length - 1;
          if ((last && depth == 0) || $from.node(depth).type.contentMatch.validEnd)
              return tr.delete($from.start(depth), $to.end(depth));
          if (depth > 0 && (last || $from.node(depth - 1).canReplace($from.index(depth - 1), $to.indexAfter(depth - 1))))
              return tr.delete($from.before(depth), $to.after(depth));
      }
      for (let d = 1; d <= $from.depth && d <= $to.depth; d++) {
          if (from - $from.start(d) == $from.depth - d && to > $from.end(d) && $to.end(d) - to != $to.depth - d &&
              $from.start(d - 1) == $to.start(d - 1) && $from.node(d - 1).canReplace($from.index(d - 1), $to.index(d - 1)))
              return tr.delete($from.before(d), to);
      }
      tr.delete(from, to);
  }
  // Returns an array of all depths for which $from - $to spans the
  // whole content of the nodes at that depth.
  function coveredDepths($from, $to) {
      let result = [], minDepth = Math.min($from.depth, $to.depth);
      for (let d = minDepth; d >= 0; d--) {
          let start = $from.start(d);
          if (start < $from.pos - ($from.depth - d) ||
              $to.end(d) > $to.pos + ($to.depth - d) ||
              $from.node(d).type.spec.isolating ||
              $to.node(d).type.spec.isolating)
              break;
          if (start == $to.start(d) ||
              (d == $from.depth && d == $to.depth && $from.parent.inlineContent && $to.parent.inlineContent &&
                  d && $to.start(d - 1) == start - 1))
              result.push(d);
      }
      return result;
  }

  /**
  Update an attribute in a specific node.
  */
  class AttrStep extends Step {
      /**
      Construct an attribute step.
      */
      constructor(
      /**
      The position of the target node.
      */
      pos, 
      /**
      The attribute to set.
      */
      attr, 
      // The attribute's new value.
      value) {
          super();
          this.pos = pos;
          this.attr = attr;
          this.value = value;
      }
      apply(doc) {
          let node = doc.nodeAt(this.pos);
          if (!node)
              return StepResult.fail("No node at attribute step's position");
          let attrs = Object.create(null);
          for (let name in node.attrs)
              attrs[name] = node.attrs[name];
          attrs[this.attr] = this.value;
          let updated = node.type.create(attrs, null, node.marks);
          return StepResult.fromReplace(doc, this.pos, this.pos + 1, new Slice(Fragment.from(updated), 0, node.isLeaf ? 0 : 1));
      }
      getMap() {
          return StepMap.empty;
      }
      invert(doc) {
          return new AttrStep(this.pos, this.attr, doc.nodeAt(this.pos).attrs[this.attr]);
      }
      map(mapping) {
          let pos = mapping.mapResult(this.pos, 1);
          return pos.deletedAfter ? null : new AttrStep(pos.pos, this.attr, this.value);
      }
      toJSON() {
          return { stepType: "attr", pos: this.pos, attr: this.attr, value: this.value };
      }
      static fromJSON(schema, json) {
          if (typeof json.pos != "number" || typeof json.attr != "string")
              throw new RangeError("Invalid input for AttrStep.fromJSON");
          return new AttrStep(json.pos, json.attr, json.value);
      }
  }
  Step.jsonID("attr", AttrStep);
  /**
  Update an attribute in the doc node.
  */
  class DocAttrStep extends Step {
      /**
      Construct an attribute step.
      */
      constructor(
      /**
      The attribute to set.
      */
      attr, 
      // The attribute's new value.
      value) {
          super();
          this.attr = attr;
          this.value = value;
      }
      apply(doc) {
          let attrs = Object.create(null);
          for (let name in doc.attrs)
              attrs[name] = doc.attrs[name];
          attrs[this.attr] = this.value;
          let updated = doc.type.create(attrs, doc.content, doc.marks);
          return StepResult.ok(updated);
      }
      getMap() {
          return StepMap.empty;
      }
      invert(doc) {
          return new DocAttrStep(this.attr, doc.attrs[this.attr]);
      }
      map(mapping) {
          return this;
      }
      toJSON() {
          return { stepType: "docAttr", attr: this.attr, value: this.value };
      }
      static fromJSON(schema, json) {
          if (typeof json.attr != "string")
              throw new RangeError("Invalid input for DocAttrStep.fromJSON");
          return new DocAttrStep(json.attr, json.value);
      }
  }
  Step.jsonID("docAttr", DocAttrStep);

  /**
  @internal
  */
  let TransformError = class extends Error {
  };
  TransformError = function TransformError(message) {
      let err = Error.call(this, message);
      err.__proto__ = TransformError.prototype;
      return err;
  };
  TransformError.prototype = Object.create(Error.prototype);
  TransformError.prototype.constructor = TransformError;
  TransformError.prototype.name = "TransformError";
  /**
  Abstraction to build up and track an array of
  [steps](https://prosemirror.net/docs/ref/#transform.Step) representing a document transformation.

  Most transforming methods return the `Transform` object itself, so
  that they can be chained.
  */
  class Transform {
      /**
      Create a transform that starts with the given document.
      */
      constructor(
      /**
      The current document (the result of applying the steps in the
      transform).
      */
      doc) {
          this.doc = doc;
          /**
          The steps in this transform.
          */
          this.steps = [];
          /**
          The documents before each of the steps.
          */
          this.docs = [];
          /**
          A mapping with the maps for each of the steps in this transform.
          */
          this.mapping = new Mapping;
      }
      /**
      The starting document.
      */
      get before() { return this.docs.length ? this.docs[0] : this.doc; }
      /**
      Apply a new step in this transform, saving the result. Throws an
      error when the step fails.
      */
      step(step) {
          let result = this.maybeStep(step);
          if (result.failed)
              throw new TransformError(result.failed);
          return this;
      }
      /**
      Try to apply a step in this transformation, ignoring it if it
      fails. Returns the step result.
      */
      maybeStep(step) {
          let result = step.apply(this.doc);
          if (!result.failed)
              this.addStep(step, result.doc);
          return result;
      }
      /**
      True when the document has been changed (when there are any
      steps).
      */
      get docChanged() {
          return this.steps.length > 0;
      }
      /**
      @internal
      */
      addStep(step, doc) {
          this.docs.push(this.doc);
          this.steps.push(step);
          this.mapping.appendMap(step.getMap());
          this.doc = doc;
      }
      /**
      Replace the part of the document between `from` and `to` with the
      given `slice`.
      */
      replace(from, to = from, slice = Slice.empty) {
          let step = replaceStep(this.doc, from, to, slice);
          if (step)
              this.step(step);
          return this;
      }
      /**
      Replace the given range with the given content, which may be a
      fragment, node, or array of nodes.
      */
      replaceWith(from, to, content) {
          return this.replace(from, to, new Slice(Fragment.from(content), 0, 0));
      }
      /**
      Delete the content between the given positions.
      */
      delete(from, to) {
          return this.replace(from, to, Slice.empty);
      }
      /**
      Insert the given content at the given position.
      */
      insert(pos, content) {
          return this.replaceWith(pos, pos, content);
      }
      /**
      Replace a range of the document with a given slice, using
      `from`, `to`, and the slice's
      [`openStart`](https://prosemirror.net/docs/ref/#model.Slice.openStart) property as hints, rather
      than fixed start and end points. This method may grow the
      replaced area or close open nodes in the slice in order to get a
      fit that is more in line with WYSIWYG expectations, by dropping
      fully covered parent nodes of the replaced region when they are
      marked [non-defining as
      context](https://prosemirror.net/docs/ref/#model.NodeSpec.definingAsContext), or including an
      open parent node from the slice that _is_ marked as [defining
      its content](https://prosemirror.net/docs/ref/#model.NodeSpec.definingForContent).
      
      This is the method, for example, to handle paste. The similar
      [`replace`](https://prosemirror.net/docs/ref/#transform.Transform.replace) method is a more
      primitive tool which will _not_ move the start and end of its given
      range, and is useful in situations where you need more precise
      control over what happens.
      */
      replaceRange(from, to, slice) {
          replaceRange(this, from, to, slice);
          return this;
      }
      /**
      Replace the given range with a node, but use `from` and `to` as
      hints, rather than precise positions. When from and to are the same
      and are at the start or end of a parent node in which the given
      node doesn't fit, this method may _move_ them out towards a parent
      that does allow the given node to be placed. When the given range
      completely covers a parent node, this method may completely replace
      that parent node.
      */
      replaceRangeWith(from, to, node) {
          replaceRangeWith(this, from, to, node);
          return this;
      }
      /**
      Delete the given range, expanding it to cover fully covered
      parent nodes until a valid replace is found.
      */
      deleteRange(from, to) {
          deleteRange(this, from, to);
          return this;
      }
      /**
      Split the content in the given range off from its parent, if there
      is sibling content before or after it, and move it up the tree to
      the depth specified by `target`. You'll probably want to use
      [`liftTarget`](https://prosemirror.net/docs/ref/#transform.liftTarget) to compute `target`, to make
      sure the lift is valid.
      */
      lift(range, target) {
          lift(this, range, target);
          return this;
      }
      /**
      Join the blocks around the given position. If depth is 2, their
      last and first siblings are also joined, and so on.
      */
      join(pos, depth = 1) {
          join(this, pos, depth);
          return this;
      }
      /**
      Wrap the given [range](https://prosemirror.net/docs/ref/#model.NodeRange) in the given set of wrappers.
      The wrappers are assumed to be valid in this position, and should
      probably be computed with [`findWrapping`](https://prosemirror.net/docs/ref/#transform.findWrapping).
      */
      wrap(range, wrappers) {
          wrap(this, range, wrappers);
          return this;
      }
      /**
      Set the type of all textblocks (partly) between `from` and `to` to
      the given node type with the given attributes.
      */
      setBlockType(from, to = from, type, attrs = null) {
          setBlockType(this, from, to, type, attrs);
          return this;
      }
      /**
      Change the type, attributes, and/or marks of the node at `pos`.
      When `type` isn't given, the existing node type is preserved,
      */
      setNodeMarkup(pos, type, attrs = null, marks) {
          setNodeMarkup(this, pos, type, attrs, marks);
          return this;
      }
      /**
      Set a single attribute on a given node to a new value.
      The `pos` addresses the document content. Use `setDocAttribute`
      to set attributes on the document itself.
      */
      setNodeAttribute(pos, attr, value) {
          this.step(new AttrStep(pos, attr, value));
          return this;
      }
      /**
      Set a single attribute on the document to a new value.
      */
      setDocAttribute(attr, value) {
          this.step(new DocAttrStep(attr, value));
          return this;
      }
      /**
      Add a mark to the node at position `pos`.
      */
      addNodeMark(pos, mark) {
          this.step(new AddNodeMarkStep(pos, mark));
          return this;
      }
      /**
      Remove a mark (or all marks of the given type) from the node at
      position `pos`.
      */
      removeNodeMark(pos, mark) {
          let node = this.doc.nodeAt(pos);
          if (!node)
              throw new RangeError("No node at position " + pos);
          if (mark instanceof Mark) {
              if (mark.isInSet(node.marks))
                  this.step(new RemoveNodeMarkStep(pos, mark));
          }
          else {
              let set = node.marks, found, steps = [];
              while (found = mark.isInSet(set)) {
                  steps.push(new RemoveNodeMarkStep(pos, found));
                  set = found.removeFromSet(set);
              }
              for (let i = steps.length - 1; i >= 0; i--)
                  this.step(steps[i]);
          }
          return this;
      }
      /**
      Split the node at the given position, and optionally, if `depth` is
      greater than one, any number of nodes above that. By default, the
      parts split off will inherit the node type of the original node.
      This can be changed by passing an array of types and attributes to
      use after the split (with the outermost nodes coming first).
      */
      split(pos, depth = 1, typesAfter) {
          split(this, pos, depth, typesAfter);
          return this;
      }
      /**
      Add the given mark to the inline content between `from` and `to`.
      */
      addMark(from, to, mark) {
          addMark(this, from, to, mark);
          return this;
      }
      /**
      Remove marks from inline nodes between `from` and `to`. When
      `mark` is a single mark, remove precisely that mark. When it is
      a mark type, remove all marks of that type. When it is null,
      remove all marks of any type.
      */
      removeMark(from, to, mark) {
          removeMark(this, from, to, mark);
          return this;
      }
      /**
      Removes all marks and nodes from the content of the node at
      `pos` that don't match the given new parent node type. Accepts
      an optional starting [content match](https://prosemirror.net/docs/ref/#model.ContentMatch) as
      third argument.
      */
      clearIncompatible(pos, parentType, match) {
          clearIncompatible(this, pos, parentType, match);
          return this;
      }
  }

  const classesById = Object.create(null);
  /**
  Superclass for editor selections. Every selection type should
  extend this. Should not be instantiated directly.
  */
  class Selection {
      /**
      Initialize a selection with the head and anchor and ranges. If no
      ranges are given, constructs a single range across `$anchor` and
      `$head`.
      */
      constructor(
      /**
      The resolved anchor of the selection (the side that stays in
      place when the selection is modified).
      */
      $anchor, 
      /**
      The resolved head of the selection (the side that moves when
      the selection is modified).
      */
      $head, ranges) {
          this.$anchor = $anchor;
          this.$head = $head;
          this.ranges = ranges || [new SelectionRange($anchor.min($head), $anchor.max($head))];
      }
      /**
      The selection's anchor, as an unresolved position.
      */
      get anchor() { return this.$anchor.pos; }
      /**
      The selection's head.
      */
      get head() { return this.$head.pos; }
      /**
      The lower bound of the selection's main range.
      */
      get from() { return this.$from.pos; }
      /**
      The upper bound of the selection's main range.
      */
      get to() { return this.$to.pos; }
      /**
      The resolved lower  bound of the selection's main range.
      */
      get $from() {
          return this.ranges[0].$from;
      }
      /**
      The resolved upper bound of the selection's main range.
      */
      get $to() {
          return this.ranges[0].$to;
      }
      /**
      Indicates whether the selection contains any content.
      */
      get empty() {
          let ranges = this.ranges;
          for (let i = 0; i < ranges.length; i++)
              if (ranges[i].$from.pos != ranges[i].$to.pos)
                  return false;
          return true;
      }
      /**
      Get the content of this selection as a slice.
      */
      content() {
          return this.$from.doc.slice(this.from, this.to, true);
      }
      /**
      Replace the selection with a slice or, if no slice is given,
      delete the selection. Will append to the given transaction.
      */
      replace(tr, content = Slice.empty) {
          // Put the new selection at the position after the inserted
          // content. When that ended in an inline node, search backwards,
          // to get the position after that node. If not, search forward.
          let lastNode = content.content.lastChild, lastParent = null;
          for (let i = 0; i < content.openEnd; i++) {
              lastParent = lastNode;
              lastNode = lastNode.lastChild;
          }
          let mapFrom = tr.steps.length, ranges = this.ranges;
          for (let i = 0; i < ranges.length; i++) {
              let { $from, $to } = ranges[i], mapping = tr.mapping.slice(mapFrom);
              tr.replaceRange(mapping.map($from.pos), mapping.map($to.pos), i ? Slice.empty : content);
              if (i == 0)
                  selectionToInsertionEnd(tr, mapFrom, (lastNode ? lastNode.isInline : lastParent && lastParent.isTextblock) ? -1 : 1);
          }
      }
      /**
      Replace the selection with the given node, appending the changes
      to the given transaction.
      */
      replaceWith(tr, node) {
          let mapFrom = tr.steps.length, ranges = this.ranges;
          for (let i = 0; i < ranges.length; i++) {
              let { $from, $to } = ranges[i], mapping = tr.mapping.slice(mapFrom);
              let from = mapping.map($from.pos), to = mapping.map($to.pos);
              if (i) {
                  tr.deleteRange(from, to);
              }
              else {
                  tr.replaceRangeWith(from, to, node);
                  selectionToInsertionEnd(tr, mapFrom, node.isInline ? -1 : 1);
              }
          }
      }
      /**
      Find a valid cursor or leaf node selection starting at the given
      position and searching back if `dir` is negative, and forward if
      positive. When `textOnly` is true, only consider cursor
      selections. Will return null when no valid selection position is
      found.
      */
      static findFrom($pos, dir, textOnly = false) {
          let inner = $pos.parent.inlineContent ? new TextSelection($pos)
              : findSelectionIn($pos.node(0), $pos.parent, $pos.pos, $pos.index(), dir, textOnly);
          if (inner)
              return inner;
          for (let depth = $pos.depth - 1; depth >= 0; depth--) {
              let found = dir < 0
                  ? findSelectionIn($pos.node(0), $pos.node(depth), $pos.before(depth + 1), $pos.index(depth), dir, textOnly)
                  : findSelectionIn($pos.node(0), $pos.node(depth), $pos.after(depth + 1), $pos.index(depth) + 1, dir, textOnly);
              if (found)
                  return found;
          }
          return null;
      }
      /**
      Find a valid cursor or leaf node selection near the given
      position. Searches forward first by default, but if `bias` is
      negative, it will search backwards first.
      */
      static near($pos, bias = 1) {
          return this.findFrom($pos, bias) || this.findFrom($pos, -bias) || new AllSelection($pos.node(0));
      }
      /**
      Find the cursor or leaf node selection closest to the start of
      the given document. Will return an
      [`AllSelection`](https://prosemirror.net/docs/ref/#state.AllSelection) if no valid position
      exists.
      */
      static atStart(doc) {
          return findSelectionIn(doc, doc, 0, 0, 1) || new AllSelection(doc);
      }
      /**
      Find the cursor or leaf node selection closest to the end of the
      given document.
      */
      static atEnd(doc) {
          return findSelectionIn(doc, doc, doc.content.size, doc.childCount, -1) || new AllSelection(doc);
      }
      /**
      Deserialize the JSON representation of a selection. Must be
      implemented for custom classes (as a static class method).
      */
      static fromJSON(doc, json) {
          if (!json || !json.type)
              throw new RangeError("Invalid input for Selection.fromJSON");
          let cls = classesById[json.type];
          if (!cls)
              throw new RangeError(`No selection type ${json.type} defined`);
          return cls.fromJSON(doc, json);
      }
      /**
      To be able to deserialize selections from JSON, custom selection
      classes must register themselves with an ID string, so that they
      can be disambiguated. Try to pick something that's unlikely to
      clash with classes from other modules.
      */
      static jsonID(id, selectionClass) {
          if (id in classesById)
              throw new RangeError("Duplicate use of selection JSON ID " + id);
          classesById[id] = selectionClass;
          selectionClass.prototype.jsonID = id;
          return selectionClass;
      }
      /**
      Get a [bookmark](https://prosemirror.net/docs/ref/#state.SelectionBookmark) for this selection,
      which is a value that can be mapped without having access to a
      current document, and later resolved to a real selection for a
      given document again. (This is used mostly by the history to
      track and restore old selections.) The default implementation of
      this method just converts the selection to a text selection and
      returns the bookmark for that.
      */
      getBookmark() {
          return TextSelection.between(this.$anchor, this.$head).getBookmark();
      }
  }
  Selection.prototype.visible = true;
  /**
  Represents a selected range in a document.
  */
  class SelectionRange {
      /**
      Create a range.
      */
      constructor(
      /**
      The lower bound of the range.
      */
      $from, 
      /**
      The upper bound of the range.
      */
      $to) {
          this.$from = $from;
          this.$to = $to;
      }
  }
  let warnedAboutTextSelection = false;
  function checkTextSelection($pos) {
      if (!warnedAboutTextSelection && !$pos.parent.inlineContent) {
          warnedAboutTextSelection = true;
          console["warn"]("TextSelection endpoint not pointing into a node with inline content (" + $pos.parent.type.name + ")");
      }
  }
  /**
  A text selection represents a classical editor selection, with a
  head (the moving side) and anchor (immobile side), both of which
  point into textblock nodes. It can be empty (a regular cursor
  position).
  */
  class TextSelection extends Selection {
      /**
      Construct a text selection between the given points.
      */
      constructor($anchor, $head = $anchor) {
          checkTextSelection($anchor);
          checkTextSelection($head);
          super($anchor, $head);
      }
      /**
      Returns a resolved position if this is a cursor selection (an
      empty text selection), and null otherwise.
      */
      get $cursor() { return this.$anchor.pos == this.$head.pos ? this.$head : null; }
      map(doc, mapping) {
          let $head = doc.resolve(mapping.map(this.head));
          if (!$head.parent.inlineContent)
              return Selection.near($head);
          let $anchor = doc.resolve(mapping.map(this.anchor));
          return new TextSelection($anchor.parent.inlineContent ? $anchor : $head, $head);
      }
      replace(tr, content = Slice.empty) {
          super.replace(tr, content);
          if (content == Slice.empty) {
              let marks = this.$from.marksAcross(this.$to);
              if (marks)
                  tr.ensureMarks(marks);
          }
      }
      eq(other) {
          return other instanceof TextSelection && other.anchor == this.anchor && other.head == this.head;
      }
      getBookmark() {
          return new TextBookmark(this.anchor, this.head);
      }
      toJSON() {
          return { type: "text", anchor: this.anchor, head: this.head };
      }
      /**
      @internal
      */
      static fromJSON(doc, json) {
          if (typeof json.anchor != "number" || typeof json.head != "number")
              throw new RangeError("Invalid input for TextSelection.fromJSON");
          return new TextSelection(doc.resolve(json.anchor), doc.resolve(json.head));
      }
      /**
      Create a text selection from non-resolved positions.
      */
      static create(doc, anchor, head = anchor) {
          let $anchor = doc.resolve(anchor);
          return new this($anchor, head == anchor ? $anchor : doc.resolve(head));
      }
      /**
      Return a text selection that spans the given positions or, if
      they aren't text positions, find a text selection near them.
      `bias` determines whether the method searches forward (default)
      or backwards (negative number) first. Will fall back to calling
      [`Selection.near`](https://prosemirror.net/docs/ref/#state.Selection^near) when the document
      doesn't contain a valid text position.
      */
      static between($anchor, $head, bias) {
          let dPos = $anchor.pos - $head.pos;
          if (!bias || dPos)
              bias = dPos >= 0 ? 1 : -1;
          if (!$head.parent.inlineContent) {
              let found = Selection.findFrom($head, bias, true) || Selection.findFrom($head, -bias, true);
              if (found)
                  $head = found.$head;
              else
                  return Selection.near($head, bias);
          }
          if (!$anchor.parent.inlineContent) {
              if (dPos == 0) {
                  $anchor = $head;
              }
              else {
                  $anchor = (Selection.findFrom($anchor, -bias, true) || Selection.findFrom($anchor, bias, true)).$anchor;
                  if (($anchor.pos < $head.pos) != (dPos < 0))
                      $anchor = $head;
              }
          }
          return new TextSelection($anchor, $head);
      }
  }
  Selection.jsonID("text", TextSelection);
  class TextBookmark {
      constructor(anchor, head) {
          this.anchor = anchor;
          this.head = head;
      }
      map(mapping) {
          return new TextBookmark(mapping.map(this.anchor), mapping.map(this.head));
      }
      resolve(doc) {
          return TextSelection.between(doc.resolve(this.anchor), doc.resolve(this.head));
      }
  }
  /**
  A node selection is a selection that points at a single node. All
  nodes marked [selectable](https://prosemirror.net/docs/ref/#model.NodeSpec.selectable) can be the
  target of a node selection. In such a selection, `from` and `to`
  point directly before and after the selected node, `anchor` equals
  `from`, and `head` equals `to`..
  */
  class NodeSelection extends Selection {
      /**
      Create a node selection. Does not verify the validity of its
      argument.
      */
      constructor($pos) {
          let node = $pos.nodeAfter;
          let $end = $pos.node(0).resolve($pos.pos + node.nodeSize);
          super($pos, $end);
          this.node = node;
      }
      map(doc, mapping) {
          let { deleted, pos } = mapping.mapResult(this.anchor);
          let $pos = doc.resolve(pos);
          if (deleted)
              return Selection.near($pos);
          return new NodeSelection($pos);
      }
      content() {
          return new Slice(Fragment.from(this.node), 0, 0);
      }
      eq(other) {
          return other instanceof NodeSelection && other.anchor == this.anchor;
      }
      toJSON() {
          return { type: "node", anchor: this.anchor };
      }
      getBookmark() { return new NodeBookmark(this.anchor); }
      /**
      @internal
      */
      static fromJSON(doc, json) {
          if (typeof json.anchor != "number")
              throw new RangeError("Invalid input for NodeSelection.fromJSON");
          return new NodeSelection(doc.resolve(json.anchor));
      }
      /**
      Create a node selection from non-resolved positions.
      */
      static create(doc, from) {
          return new NodeSelection(doc.resolve(from));
      }
      /**
      Determines whether the given node may be selected as a node
      selection.
      */
      static isSelectable(node) {
          return !node.isText && node.type.spec.selectable !== false;
      }
  }
  NodeSelection.prototype.visible = false;
  Selection.jsonID("node", NodeSelection);
  class NodeBookmark {
      constructor(anchor) {
          this.anchor = anchor;
      }
      map(mapping) {
          let { deleted, pos } = mapping.mapResult(this.anchor);
          return deleted ? new TextBookmark(pos, pos) : new NodeBookmark(pos);
      }
      resolve(doc) {
          let $pos = doc.resolve(this.anchor), node = $pos.nodeAfter;
          if (node && NodeSelection.isSelectable(node))
              return new NodeSelection($pos);
          return Selection.near($pos);
      }
  }
  /**
  A selection type that represents selecting the whole document
  (which can not necessarily be expressed with a text selection, when
  there are for example leaf block nodes at the start or end of the
  document).
  */
  class AllSelection extends Selection {
      /**
      Create an all-selection over the given document.
      */
      constructor(doc) {
          super(doc.resolve(0), doc.resolve(doc.content.size));
      }
      replace(tr, content = Slice.empty) {
          if (content == Slice.empty) {
              tr.delete(0, tr.doc.content.size);
              let sel = Selection.atStart(tr.doc);
              if (!sel.eq(tr.selection))
                  tr.setSelection(sel);
          }
          else {
              super.replace(tr, content);
          }
      }
      toJSON() { return { type: "all" }; }
      /**
      @internal
      */
      static fromJSON(doc) { return new AllSelection(doc); }
      map(doc) { return new AllSelection(doc); }
      eq(other) { return other instanceof AllSelection; }
      getBookmark() { return AllBookmark; }
  }
  Selection.jsonID("all", AllSelection);
  const AllBookmark = {
      map() { return this; },
      resolve(doc) { return new AllSelection(doc); }
  };
  // FIXME we'll need some awareness of text direction when scanning for selections
  // Try to find a selection inside the given node. `pos` points at the
  // position where the search starts. When `text` is true, only return
  // text selections.
  function findSelectionIn(doc, node, pos, index, dir, text = false) {
      if (node.inlineContent)
          return TextSelection.create(doc, pos);
      for (let i = index - (dir > 0 ? 0 : 1); dir > 0 ? i < node.childCount : i >= 0; i += dir) {
          let child = node.child(i);
          if (!child.isAtom) {
              let inner = findSelectionIn(doc, child, pos + dir, dir < 0 ? child.childCount : 0, dir, text);
              if (inner)
                  return inner;
          }
          else if (!text && NodeSelection.isSelectable(child)) {
              return NodeSelection.create(doc, pos - (dir < 0 ? child.nodeSize : 0));
          }
          pos += child.nodeSize * dir;
      }
      return null;
  }
  function selectionToInsertionEnd(tr, startLen, bias) {
      let last = tr.steps.length - 1;
      if (last < startLen)
          return;
      let step = tr.steps[last];
      if (!(step instanceof ReplaceStep || step instanceof ReplaceAroundStep))
          return;
      let map = tr.mapping.maps[last], end;
      map.forEach((_from, _to, _newFrom, newTo) => { if (end == null)
          end = newTo; });
      tr.setSelection(Selection.near(tr.doc.resolve(end), bias));
  }

  const UPDATED_SEL = 1, UPDATED_MARKS = 2, UPDATED_SCROLL = 4;
  /**
  An editor state transaction, which can be applied to a state to
  create an updated state. Use
  [`EditorState.tr`](https://prosemirror.net/docs/ref/#state.EditorState.tr) to create an instance.

  Transactions track changes to the document (they are a subclass of
  [`Transform`](https://prosemirror.net/docs/ref/#transform.Transform)), but also other state changes,
  like selection updates and adjustments of the set of [stored
  marks](https://prosemirror.net/docs/ref/#state.EditorState.storedMarks). In addition, you can store
  metadata properties in a transaction, which are extra pieces of
  information that client code or plugins can use to describe what a
  transaction represents, so that they can update their [own
  state](https://prosemirror.net/docs/ref/#state.StateField) accordingly.

  The [editor view](https://prosemirror.net/docs/ref/#view.EditorView) uses a few metadata
  properties: it will attach a property `"pointer"` with the value
  `true` to selection transactions directly caused by mouse or touch
  input, a `"composition"` property holding an ID identifying the
  composition that caused it to transactions caused by composed DOM
  input, and a `"uiEvent"` property of that may be `"paste"`,
  `"cut"`, or `"drop"`.
  */
  class Transaction extends Transform {
      /**
      @internal
      */
      constructor(state) {
          super(state.doc);
          // The step count for which the current selection is valid.
          this.curSelectionFor = 0;
          // Bitfield to track which aspects of the state were updated by
          // this transaction.
          this.updated = 0;
          // Object used to store metadata properties for the transaction.
          this.meta = Object.create(null);
          this.time = Date.now();
          this.curSelection = state.selection;
          this.storedMarks = state.storedMarks;
      }
      /**
      The transaction's current selection. This defaults to the editor
      selection [mapped](https://prosemirror.net/docs/ref/#state.Selection.map) through the steps in the
      transaction, but can be overwritten with
      [`setSelection`](https://prosemirror.net/docs/ref/#state.Transaction.setSelection).
      */
      get selection() {
          if (this.curSelectionFor < this.steps.length) {
              this.curSelection = this.curSelection.map(this.doc, this.mapping.slice(this.curSelectionFor));
              this.curSelectionFor = this.steps.length;
          }
          return this.curSelection;
      }
      /**
      Update the transaction's current selection. Will determine the
      selection that the editor gets when the transaction is applied.
      */
      setSelection(selection) {
          if (selection.$from.doc != this.doc)
              throw new RangeError("Selection passed to setSelection must point at the current document");
          this.curSelection = selection;
          this.curSelectionFor = this.steps.length;
          this.updated = (this.updated | UPDATED_SEL) & ~UPDATED_MARKS;
          this.storedMarks = null;
          return this;
      }
      /**
      Whether the selection was explicitly updated by this transaction.
      */
      get selectionSet() {
          return (this.updated & UPDATED_SEL) > 0;
      }
      /**
      Set the current stored marks.
      */
      setStoredMarks(marks) {
          this.storedMarks = marks;
          this.updated |= UPDATED_MARKS;
          return this;
      }
      /**
      Make sure the current stored marks or, if that is null, the marks
      at the selection, match the given set of marks. Does nothing if
      this is already the case.
      */
      ensureMarks(marks) {
          if (!Mark.sameSet(this.storedMarks || this.selection.$from.marks(), marks))
              this.setStoredMarks(marks);
          return this;
      }
      /**
      Add a mark to the set of stored marks.
      */
      addStoredMark(mark) {
          return this.ensureMarks(mark.addToSet(this.storedMarks || this.selection.$head.marks()));
      }
      /**
      Remove a mark or mark type from the set of stored marks.
      */
      removeStoredMark(mark) {
          return this.ensureMarks(mark.removeFromSet(this.storedMarks || this.selection.$head.marks()));
      }
      /**
      Whether the stored marks were explicitly set for this transaction.
      */
      get storedMarksSet() {
          return (this.updated & UPDATED_MARKS) > 0;
      }
      /**
      @internal
      */
      addStep(step, doc) {
          super.addStep(step, doc);
          this.updated = this.updated & ~UPDATED_MARKS;
          this.storedMarks = null;
      }
      /**
      Update the timestamp for the transaction.
      */
      setTime(time) {
          this.time = time;
          return this;
      }
      /**
      Replace the current selection with the given slice.
      */
      replaceSelection(slice) {
          this.selection.replace(this, slice);
          return this;
      }
      /**
      Replace the selection with the given node. When `inheritMarks` is
      true and the content is inline, it inherits the marks from the
      place where it is inserted.
      */
      replaceSelectionWith(node, inheritMarks = true) {
          let selection = this.selection;
          if (inheritMarks)
              node = node.mark(this.storedMarks || (selection.empty ? selection.$from.marks() : (selection.$from.marksAcross(selection.$to) || Mark.none)));
          selection.replaceWith(this, node);
          return this;
      }
      /**
      Delete the selection.
      */
      deleteSelection() {
          this.selection.replace(this);
          return this;
      }
      /**
      Replace the given range, or the selection if no range is given,
      with a text node containing the given string.
      */
      insertText(text, from, to) {
          let schema = this.doc.type.schema;
          if (from == null) {
              if (!text)
                  return this.deleteSelection();
              return this.replaceSelectionWith(schema.text(text), true);
          }
          else {
              if (to == null)
                  to = from;
              to = to == null ? from : to;
              if (!text)
                  return this.deleteRange(from, to);
              let marks = this.storedMarks;
              if (!marks) {
                  let $from = this.doc.resolve(from);
                  marks = to == from ? $from.marks() : $from.marksAcross(this.doc.resolve(to));
              }
              this.replaceRangeWith(from, to, schema.text(text, marks));
              if (!this.selection.empty)
                  this.setSelection(Selection.near(this.selection.$to));
              return this;
          }
      }
      /**
      Store a metadata property in this transaction, keyed either by
      name or by plugin.
      */
      setMeta(key, value) {
          this.meta[typeof key == "string" ? key : key.key] = value;
          return this;
      }
      /**
      Retrieve a metadata property for a given name or plugin.
      */
      getMeta(key) {
          return this.meta[typeof key == "string" ? key : key.key];
      }
      /**
      Returns true if this transaction doesn't contain any metadata,
      and can thus safely be extended.
      */
      get isGeneric() {
          for (let _ in this.meta)
              return false;
          return true;
      }
      /**
      Indicate that the editor should scroll the selection into view
      when updated to the state produced by this transaction.
      */
      scrollIntoView() {
          this.updated |= UPDATED_SCROLL;
          return this;
      }
      /**
      True when this transaction has had `scrollIntoView` called on it.
      */
      get scrolledIntoView() {
          return (this.updated & UPDATED_SCROLL) > 0;
      }
  }

  function bind(f, self) {
      return !self || !f ? f : f.bind(self);
  }
  class FieldDesc {
      constructor(name, desc, self) {
          this.name = name;
          this.init = bind(desc.init, self);
          this.apply = bind(desc.apply, self);
      }
  }
  const baseFields = [
      new FieldDesc("doc", {
          init(config) { return config.doc || config.schema.topNodeType.createAndFill(); },
          apply(tr) { return tr.doc; }
      }),
      new FieldDesc("selection", {
          init(config, instance) { return config.selection || Selection.atStart(instance.doc); },
          apply(tr) { return tr.selection; }
      }),
      new FieldDesc("storedMarks", {
          init(config) { return config.storedMarks || null; },
          apply(tr, _marks, _old, state) { return state.selection.$cursor ? tr.storedMarks : null; }
      }),
      new FieldDesc("scrollToSelection", {
          init() { return 0; },
          apply(tr, prev) { return tr.scrolledIntoView ? prev + 1 : prev; }
      })
  ];
  // Object wrapping the part of a state object that stays the same
  // across transactions. Stored in the state's `config` property.
  class Configuration {
      constructor(schema, plugins) {
          this.schema = schema;
          this.plugins = [];
          this.pluginsByKey = Object.create(null);
          this.fields = baseFields.slice();
          if (plugins)
              plugins.forEach(plugin => {
                  if (this.pluginsByKey[plugin.key])
                      throw new RangeError("Adding different instances of a keyed plugin (" + plugin.key + ")");
                  this.plugins.push(plugin);
                  this.pluginsByKey[plugin.key] = plugin;
                  if (plugin.spec.state)
                      this.fields.push(new FieldDesc(plugin.key, plugin.spec.state, plugin));
              });
      }
  }
  /**
  The state of a ProseMirror editor is represented by an object of
  this type. A state is a persistent data structure—it isn't
  updated, but rather a new state value is computed from an old one
  using the [`apply`](https://prosemirror.net/docs/ref/#state.EditorState.apply) method.

  A state holds a number of built-in fields, and plugins can
  [define](https://prosemirror.net/docs/ref/#state.PluginSpec.state) additional fields.
  */
  class EditorState {
      /**
      @internal
      */
      constructor(
      /**
      @internal
      */
      config) {
          this.config = config;
      }
      /**
      The schema of the state's document.
      */
      get schema() {
          return this.config.schema;
      }
      /**
      The plugins that are active in this state.
      */
      get plugins() {
          return this.config.plugins;
      }
      /**
      Apply the given transaction to produce a new state.
      */
      apply(tr) {
          return this.applyTransaction(tr).state;
      }
      /**
      @internal
      */
      filterTransaction(tr, ignore = -1) {
          for (let i = 0; i < this.config.plugins.length; i++)
              if (i != ignore) {
                  let plugin = this.config.plugins[i];
                  if (plugin.spec.filterTransaction && !plugin.spec.filterTransaction.call(plugin, tr, this))
                      return false;
              }
          return true;
      }
      /**
      Verbose variant of [`apply`](https://prosemirror.net/docs/ref/#state.EditorState.apply) that
      returns the precise transactions that were applied (which might
      be influenced by the [transaction
      hooks](https://prosemirror.net/docs/ref/#state.PluginSpec.filterTransaction) of
      plugins) along with the new state.
      */
      applyTransaction(rootTr) {
          if (!this.filterTransaction(rootTr))
              return { state: this, transactions: [] };
          let trs = [rootTr], newState = this.applyInner(rootTr), seen = null;
          // This loop repeatedly gives plugins a chance to respond to
          // transactions as new transactions are added, making sure to only
          // pass the transactions the plugin did not see before.
          for (;;) {
              let haveNew = false;
              for (let i = 0; i < this.config.plugins.length; i++) {
                  let plugin = this.config.plugins[i];
                  if (plugin.spec.appendTransaction) {
                      let n = seen ? seen[i].n : 0, oldState = seen ? seen[i].state : this;
                      let tr = n < trs.length &&
                          plugin.spec.appendTransaction.call(plugin, n ? trs.slice(n) : trs, oldState, newState);
                      if (tr && newState.filterTransaction(tr, i)) {
                          tr.setMeta("appendedTransaction", rootTr);
                          if (!seen) {
                              seen = [];
                              for (let j = 0; j < this.config.plugins.length; j++)
                                  seen.push(j < i ? { state: newState, n: trs.length } : { state: this, n: 0 });
                          }
                          trs.push(tr);
                          newState = newState.applyInner(tr);
                          haveNew = true;
                      }
                      if (seen)
                          seen[i] = { state: newState, n: trs.length };
                  }
              }
              if (!haveNew)
                  return { state: newState, transactions: trs };
          }
      }
      /**
      @internal
      */
      applyInner(tr) {
          if (!tr.before.eq(this.doc))
              throw new RangeError("Applying a mismatched transaction");
          let newInstance = new EditorState(this.config), fields = this.config.fields;
          for (let i = 0; i < fields.length; i++) {
              let field = fields[i];
              newInstance[field.name] = field.apply(tr, this[field.name], this, newInstance);
          }
          return newInstance;
      }
      /**
      Start a [transaction](https://prosemirror.net/docs/ref/#state.Transaction) from this state.
      */
      get tr() { return new Transaction(this); }
      /**
      Create a new state.
      */
      static create(config) {
          let $config = new Configuration(config.doc ? config.doc.type.schema : config.schema, config.plugins);
          let instance = new EditorState($config);
          for (let i = 0; i < $config.fields.length; i++)
              instance[$config.fields[i].name] = $config.fields[i].init(config, instance);
          return instance;
      }
      /**
      Create a new state based on this one, but with an adjusted set
      of active plugins. State fields that exist in both sets of
      plugins are kept unchanged. Those that no longer exist are
      dropped, and those that are new are initialized using their
      [`init`](https://prosemirror.net/docs/ref/#state.StateField.init) method, passing in the new
      configuration object..
      */
      reconfigure(config) {
          let $config = new Configuration(this.schema, config.plugins);
          let fields = $config.fields, instance = new EditorState($config);
          for (let i = 0; i < fields.length; i++) {
              let name = fields[i].name;
              instance[name] = this.hasOwnProperty(name) ? this[name] : fields[i].init(config, instance);
          }
          return instance;
      }
      /**
      Serialize this state to JSON. If you want to serialize the state
      of plugins, pass an object mapping property names to use in the
      resulting JSON object to plugin objects. The argument may also be
      a string or number, in which case it is ignored, to support the
      way `JSON.stringify` calls `toString` methods.
      */
      toJSON(pluginFields) {
          let result = { doc: this.doc.toJSON(), selection: this.selection.toJSON() };
          if (this.storedMarks)
              result.storedMarks = this.storedMarks.map(m => m.toJSON());
          if (pluginFields && typeof pluginFields == 'object')
              for (let prop in pluginFields) {
                  if (prop == "doc" || prop == "selection")
                      throw new RangeError("The JSON fields `doc` and `selection` are reserved");
                  let plugin = pluginFields[prop], state = plugin.spec.state;
                  if (state && state.toJSON)
                      result[prop] = state.toJSON.call(plugin, this[plugin.key]);
              }
          return result;
      }
      /**
      Deserialize a JSON representation of a state. `config` should
      have at least a `schema` field, and should contain array of
      plugins to initialize the state with. `pluginFields` can be used
      to deserialize the state of plugins, by associating plugin
      instances with the property names they use in the JSON object.
      */
      static fromJSON(config, json, pluginFields) {
          if (!json)
              throw new RangeError("Invalid input for EditorState.fromJSON");
          if (!config.schema)
              throw new RangeError("Required config field 'schema' missing");
          let $config = new Configuration(config.schema, config.plugins);
          let instance = new EditorState($config);
          $config.fields.forEach(field => {
              if (field.name == "doc") {
                  instance.doc = Node$1.fromJSON(config.schema, json.doc);
              }
              else if (field.name == "selection") {
                  instance.selection = Selection.fromJSON(instance.doc, json.selection);
              }
              else if (field.name == "storedMarks") {
                  if (json.storedMarks)
                      instance.storedMarks = json.storedMarks.map(config.schema.markFromJSON);
              }
              else {
                  if (pluginFields)
                      for (let prop in pluginFields) {
                          let plugin = pluginFields[prop], state = plugin.spec.state;
                          if (plugin.key == field.name && state && state.fromJSON &&
                              Object.prototype.hasOwnProperty.call(json, prop)) {
                              instance[field.name] = state.fromJSON.call(plugin, config, json[prop], instance);
                              return;
                          }
                      }
                  instance[field.name] = field.init(config, instance);
              }
          });
          return instance;
      }
  }

  function bindProps(obj, self, target) {
      for (let prop in obj) {
          let val = obj[prop];
          if (val instanceof Function)
              val = val.bind(self);
          else if (prop == "handleDOMEvents")
              val = bindProps(val, self, {});
          target[prop] = val;
      }
      return target;
  }
  /**
  Plugins bundle functionality that can be added to an editor.
  They are part of the [editor state](https://prosemirror.net/docs/ref/#state.EditorState) and
  may influence that state and the view that contains it.
  */
  class Plugin {
      /**
      Create a plugin.
      */
      constructor(
      /**
      The plugin's [spec object](https://prosemirror.net/docs/ref/#state.PluginSpec).
      */
      spec) {
          this.spec = spec;
          /**
          The [props](https://prosemirror.net/docs/ref/#view.EditorProps) exported by this plugin.
          */
          this.props = {};
          if (spec.props)
              bindProps(spec.props, this, this.props);
          this.key = spec.key ? spec.key.key : createKey("plugin");
      }
      /**
      Extract the plugin's state field from an editor state.
      */
      getState(state) { return state[this.key]; }
  }
  const keys = Object.create(null);
  function createKey(name) {
      if (name in keys)
          return name + "$" + ++keys[name];
      keys[name] = 0;
      return name + "$";
  }
  /**
  A key is used to [tag](https://prosemirror.net/docs/ref/#state.PluginSpec.key) plugins in a way
  that makes it possible to find them, given an editor state.
  Assigning a key does mean only one plugin of that type can be
  active in a state.
  */
  class PluginKey {
      /**
      Create a plugin key.
      */
      constructor(name = "key") { this.key = createKey(name); }
      /**
      Get the active plugin with this key, if any, from an editor
      state.
      */
      get(state) { return state.config.pluginsByKey[this.key]; }
      /**
      Get the plugin's state from an editor state.
      */
      getState(state) { return state[this.key]; }
  }

  const domIndex = function (node) {
      for (var index = 0;; index++) {
          node = node.previousSibling;
          if (!node)
              return index;
      }
  };
  const parentNode = function (node) {
      let parent = node.assignedSlot || node.parentNode;
      return parent && parent.nodeType == 11 ? parent.host : parent;
  };
  let reusedRange = null;
  // Note that this will always return the same range, because DOM range
  // objects are every expensive, and keep slowing down subsequent DOM
  // updates, for some reason.
  const textRange = function (node, from, to) {
      let range = reusedRange || (reusedRange = document.createRange());
      range.setEnd(node, to == null ? node.nodeValue.length : to);
      range.setStart(node, from || 0);
      return range;
  };
  const clearReusedRange = function () {
      reusedRange = null;
  };
  // Scans forward and backward through DOM positions equivalent to the
  // given one to see if the two are in the same place (i.e. after a
  // text node vs at the end of that text node)
  const isEquivalentPosition = function (node, off, targetNode, targetOff) {
      return targetNode && (scanFor(node, off, targetNode, targetOff, -1) ||
          scanFor(node, off, targetNode, targetOff, 1));
  };
  const atomElements = /^(img|br|input|textarea|hr)$/i;
  function scanFor(node, off, targetNode, targetOff, dir) {
      var _a;
      for (;;) {
          if (node == targetNode && off == targetOff)
              return true;
          if (off == (dir < 0 ? 0 : nodeSize(node))) {
              let parent = node.parentNode;
              if (!parent || parent.nodeType != 1 || hasBlockDesc(node) || atomElements.test(node.nodeName) ||
                  node.contentEditable == "false")
                  return false;
              off = domIndex(node) + (dir < 0 ? 0 : 1);
              node = parent;
          }
          else if (node.nodeType == 1) {
              let child = node.childNodes[off + (dir < 0 ? -1 : 0)];
              if (child.nodeType == 1 && child.contentEditable == "false") {
                  if ((_a = child.pmViewDesc) === null || _a === void 0 ? void 0 : _a.ignoreForSelection)
                      off += dir;
                  else
                      return false;
              }
              else {
                  node = child;
                  off = dir < 0 ? nodeSize(node) : 0;
              }
          }
          else {
              return false;
          }
      }
  }
  function nodeSize(node) {
      return node.nodeType == 3 ? node.nodeValue.length : node.childNodes.length;
  }
  function textNodeBefore$1(node, offset) {
      for (;;) {
          if (node.nodeType == 3 && offset)
              return node;
          if (node.nodeType == 1 && offset > 0) {
              if (node.contentEditable == "false")
                  return null;
              node = node.childNodes[offset - 1];
              offset = nodeSize(node);
          }
          else if (node.parentNode && !hasBlockDesc(node)) {
              offset = domIndex(node);
              node = node.parentNode;
          }
          else {
              return null;
          }
      }
  }
  function textNodeAfter$1(node, offset) {
      for (;;) {
          if (node.nodeType == 3 && offset < node.nodeValue.length)
              return node;
          if (node.nodeType == 1 && offset < node.childNodes.length) {
              if (node.contentEditable == "false")
                  return null;
              node = node.childNodes[offset];
              offset = 0;
          }
          else if (node.parentNode && !hasBlockDesc(node)) {
              offset = domIndex(node) + 1;
              node = node.parentNode;
          }
          else {
              return null;
          }
      }
  }
  function isOnEdge(node, offset, parent) {
      for (let atStart = offset == 0, atEnd = offset == nodeSize(node); atStart || atEnd;) {
          if (node == parent)
              return true;
          let index = domIndex(node);
          node = node.parentNode;
          if (!node)
              return false;
          atStart = atStart && index == 0;
          atEnd = atEnd && index == nodeSize(node);
      }
  }
  function hasBlockDesc(dom) {
      let desc;
      for (let cur = dom; cur; cur = cur.parentNode)
          if (desc = cur.pmViewDesc)
              break;
      return desc && desc.node && desc.node.isBlock && (desc.dom == dom || desc.contentDOM == dom);
  }
  // Work around Chrome issue https://bugs.chromium.org/p/chromium/issues/detail?id=447523
  // (isCollapsed inappropriately returns true in shadow dom)
  const selectionCollapsed = function (domSel) {
      return domSel.focusNode && isEquivalentPosition(domSel.focusNode, domSel.focusOffset, domSel.anchorNode, domSel.anchorOffset);
  };
  function keyEvent(keyCode, key) {
      let event = document.createEvent("Event");
      event.initEvent("keydown", true, true);
      event.keyCode = keyCode;
      event.key = event.code = key;
      return event;
  }
  function deepActiveElement(doc) {
      let elt = doc.activeElement;
      while (elt && elt.shadowRoot)
          elt = elt.shadowRoot.activeElement;
      return elt;
  }
  function caretFromPoint(doc, x, y) {
      if (doc.caretPositionFromPoint) {
          try { // Firefox throws for this call in hard-to-predict circumstances (#994)
              let pos = doc.caretPositionFromPoint(x, y);
              // Clip the offset, because Chrome will return a text offset
              // into <input> nodes, which can't be treated as a regular DOM
              // offset
              if (pos)
                  return { node: pos.offsetNode, offset: Math.min(nodeSize(pos.offsetNode), pos.offset) };
          }
          catch (_) { }
      }
      if (doc.caretRangeFromPoint) {
          let range = doc.caretRangeFromPoint(x, y);
          if (range)
              return { node: range.startContainer, offset: Math.min(nodeSize(range.startContainer), range.startOffset) };
      }
  }

  const nav = typeof navigator != "undefined" ? navigator : null;
  const doc = typeof document != "undefined" ? document : null;
  const agent = (nav && nav.userAgent) || "";
  const ie_edge = /Edge\/(\d+)/.exec(agent);
  const ie_upto10 = /MSIE \d/.exec(agent);
  const ie_11up = /Trident\/(?:[7-9]|\d{2,})\..*rv:(\d+)/.exec(agent);
  const ie$1 = !!(ie_upto10 || ie_11up || ie_edge);
  const ie_version = ie_upto10 ? document.documentMode : ie_11up ? +ie_11up[1] : ie_edge ? +ie_edge[1] : 0;
  const gecko = !ie$1 && /gecko\/(\d+)/i.test(agent);
  gecko && +(/Firefox\/(\d+)/.exec(agent) || [0, 0])[1];
  const _chrome = !ie$1 && /Chrome\/(\d+)/.exec(agent);
  const chrome = !!_chrome;
  const chrome_version = _chrome ? +_chrome[1] : 0;
  const safari = !ie$1 && !!nav && /Apple Computer/.test(nav.vendor);
  // Is true for both iOS and iPadOS for convenience
  const ios = safari && (/Mobile\/\w+/.test(agent) || !!nav && nav.maxTouchPoints > 2);
  const mac$3 = ios || (nav ? /Mac/.test(nav.platform) : false);
  const windows$1 = nav ? /Win/.test(nav.platform) : false;
  const android = /Android \d/.test(agent);
  const webkit = !!doc && "webkitFontSmoothing" in doc.documentElement.style;
  const webkit_version = webkit ? +(/\bAppleWebKit\/(\d+)/.exec(navigator.userAgent) || [0, 0])[1] : 0;

  function windowRect(doc) {
      let vp = doc.defaultView && doc.defaultView.visualViewport;
      if (vp)
          return {
              left: 0, right: vp.width,
              top: 0, bottom: vp.height
          };
      return { left: 0, right: doc.documentElement.clientWidth,
          top: 0, bottom: doc.documentElement.clientHeight };
  }
  function getSide(value, side) {
      return typeof value == "number" ? value : value[side];
  }
  function clientRect(node) {
      let rect = node.getBoundingClientRect();
      // Adjust for elements with style "transform: scale()"
      let scaleX = (rect.width / node.offsetWidth) || 1;
      let scaleY = (rect.height / node.offsetHeight) || 1;
      // Make sure scrollbar width isn't included in the rectangle
      return { left: rect.left, right: rect.left + node.clientWidth * scaleX,
          top: rect.top, bottom: rect.top + node.clientHeight * scaleY };
  }
  function scrollRectIntoView(view, rect, startDOM) {
      let scrollThreshold = view.someProp("scrollThreshold") || 0, scrollMargin = view.someProp("scrollMargin") || 5;
      let doc = view.dom.ownerDocument;
      for (let parent = startDOM || view.dom;;) {
          if (!parent)
              break;
          if (parent.nodeType != 1) {
              parent = parentNode(parent);
              continue;
          }
          let elt = parent;
          let atTop = elt == doc.body;
          let bounding = atTop ? windowRect(doc) : clientRect(elt);
          let moveX = 0, moveY = 0;
          if (rect.top < bounding.top + getSide(scrollThreshold, "top"))
              moveY = -(bounding.top - rect.top + getSide(scrollMargin, "top"));
          else if (rect.bottom > bounding.bottom - getSide(scrollThreshold, "bottom"))
              moveY = rect.bottom - rect.top > bounding.bottom - bounding.top
                  ? rect.top + getSide(scrollMargin, "top") - bounding.top
                  : rect.bottom - bounding.bottom + getSide(scrollMargin, "bottom");
          if (rect.left < bounding.left + getSide(scrollThreshold, "left"))
              moveX = -(bounding.left - rect.left + getSide(scrollMargin, "left"));
          else if (rect.right > bounding.right - getSide(scrollThreshold, "right"))
              moveX = rect.right - bounding.right + getSide(scrollMargin, "right");
          if (moveX || moveY) {
              if (atTop) {
                  doc.defaultView.scrollBy(moveX, moveY);
              }
              else {
                  let startX = elt.scrollLeft, startY = elt.scrollTop;
                  if (moveY)
                      elt.scrollTop += moveY;
                  if (moveX)
                      elt.scrollLeft += moveX;
                  let dX = elt.scrollLeft - startX, dY = elt.scrollTop - startY;
                  rect = { left: rect.left - dX, top: rect.top - dY, right: rect.right - dX, bottom: rect.bottom - dY };
              }
          }
          let pos = atTop ? "fixed" : getComputedStyle(parent).position;
          if (/^(fixed|sticky)$/.test(pos))
              break;
          parent = pos == "absolute" ? parent.offsetParent : parentNode(parent);
      }
  }
  // Store the scroll position of the editor's parent nodes, along with
  // the top position of an element near the top of the editor, which
  // will be used to make sure the visible viewport remains stable even
  // when the size of the content above changes.
  function storeScrollPos(view) {
      let rect = view.dom.getBoundingClientRect(), startY = Math.max(0, rect.top);
      let refDOM, refTop;
      for (let x = (rect.left + rect.right) / 2, y = startY + 1; y < Math.min(innerHeight, rect.bottom); y += 5) {
          let dom = view.root.elementFromPoint(x, y);
          if (!dom || dom == view.dom || !view.dom.contains(dom))
              continue;
          let localRect = dom.getBoundingClientRect();
          if (localRect.top >= startY - 20) {
              refDOM = dom;
              refTop = localRect.top;
              break;
          }
      }
      return { refDOM: refDOM, refTop: refTop, stack: scrollStack(view.dom) };
  }
  function scrollStack(dom) {
      let stack = [], doc = dom.ownerDocument;
      for (let cur = dom; cur; cur = parentNode(cur)) {
          stack.push({ dom: cur, top: cur.scrollTop, left: cur.scrollLeft });
          if (dom == doc)
              break;
      }
      return stack;
  }
  // Reset the scroll position of the editor's parent nodes to that what
  // it was before, when storeScrollPos was called.
  function resetScrollPos({ refDOM, refTop, stack }) {
      let newRefTop = refDOM ? refDOM.getBoundingClientRect().top : 0;
      restoreScrollStack(stack, newRefTop == 0 ? 0 : newRefTop - refTop);
  }
  function restoreScrollStack(stack, dTop) {
      for (let i = 0; i < stack.length; i++) {
          let { dom, top, left } = stack[i];
          if (dom.scrollTop != top + dTop)
              dom.scrollTop = top + dTop;
          if (dom.scrollLeft != left)
              dom.scrollLeft = left;
      }
  }
  let preventScrollSupported = null;
  // Feature-detects support for .focus({preventScroll: true}), and uses
  // a fallback kludge when not supported.
  function focusPreventScroll(dom) {
      if (dom.setActive)
          return dom.setActive(); // in IE
      if (preventScrollSupported)
          return dom.focus(preventScrollSupported);
      let stored = scrollStack(dom);
      dom.focus(preventScrollSupported == null ? {
          get preventScroll() {
              preventScrollSupported = { preventScroll: true };
              return true;
          }
      } : undefined);
      if (!preventScrollSupported) {
          preventScrollSupported = false;
          restoreScrollStack(stored, 0);
      }
  }
  function findOffsetInNode(node, coords) {
      let closest, dxClosest = 2e8, coordsClosest, offset = 0;
      let rowBot = coords.top, rowTop = coords.top;
      let firstBelow, coordsBelow;
      for (let child = node.firstChild, childIndex = 0; child; child = child.nextSibling, childIndex++) {
          let rects;
          if (child.nodeType == 1)
              rects = child.getClientRects();
          else if (child.nodeType == 3)
              rects = textRange(child).getClientRects();
          else
              continue;
          for (let i = 0; i < rects.length; i++) {
              let rect = rects[i];
              if (rect.top <= rowBot && rect.bottom >= rowTop) {
                  rowBot = Math.max(rect.bottom, rowBot);
                  rowTop = Math.min(rect.top, rowTop);
                  let dx = rect.left > coords.left ? rect.left - coords.left
                      : rect.right < coords.left ? coords.left - rect.right : 0;
                  if (dx < dxClosest) {
                      closest = child;
                      dxClosest = dx;
                      coordsClosest = dx && closest.nodeType == 3 ? {
                          left: rect.right < coords.left ? rect.right : rect.left,
                          top: coords.top
                      } : coords;
                      if (child.nodeType == 1 && dx)
                          offset = childIndex + (coords.left >= (rect.left + rect.right) / 2 ? 1 : 0);
                      continue;
                  }
              }
              else if (rect.top > coords.top && !firstBelow && rect.left <= coords.left && rect.right >= coords.left) {
                  firstBelow = child;
                  coordsBelow = { left: Math.max(rect.left, Math.min(rect.right, coords.left)), top: rect.top };
              }
              if (!closest && (coords.left >= rect.right && coords.top >= rect.top ||
                  coords.left >= rect.left && coords.top >= rect.bottom))
                  offset = childIndex + 1;
          }
      }
      if (!closest && firstBelow) {
          closest = firstBelow;
          coordsClosest = coordsBelow;
          dxClosest = 0;
      }
      if (closest && closest.nodeType == 3)
          return findOffsetInText(closest, coordsClosest);
      if (!closest || (dxClosest && closest.nodeType == 1))
          return { node, offset };
      return findOffsetInNode(closest, coordsClosest);
  }
  function findOffsetInText(node, coords) {
      let len = node.nodeValue.length;
      let range = document.createRange();
      for (let i = 0; i < len; i++) {
          range.setEnd(node, i + 1);
          range.setStart(node, i);
          let rect = singleRect(range, 1);
          if (rect.top == rect.bottom)
              continue;
          if (inRect(coords, rect))
              return { node, offset: i + (coords.left >= (rect.left + rect.right) / 2 ? 1 : 0) };
      }
      return { node, offset: 0 };
  }
  function inRect(coords, rect) {
      return coords.left >= rect.left - 1 && coords.left <= rect.right + 1 &&
          coords.top >= rect.top - 1 && coords.top <= rect.bottom + 1;
  }
  function targetKludge(dom, coords) {
      let parent = dom.parentNode;
      if (parent && /^li$/i.test(parent.nodeName) && coords.left < dom.getBoundingClientRect().left)
          return parent;
      return dom;
  }
  function posFromElement(view, elt, coords) {
      let { node, offset } = findOffsetInNode(elt, coords), bias = -1;
      if (node.nodeType == 1 && !node.firstChild) {
          let rect = node.getBoundingClientRect();
          bias = rect.left != rect.right && coords.left > (rect.left + rect.right) / 2 ? 1 : -1;
      }
      return view.docView.posFromDOM(node, offset, bias);
  }
  function posFromCaret(view, node, offset, coords) {
      // Browser (in caretPosition/RangeFromPoint) will agressively
      // normalize towards nearby inline nodes. Since we are interested in
      // positions between block nodes too, we first walk up the hierarchy
      // of nodes to see if there are block nodes that the coordinates
      // fall outside of. If so, we take the position before/after that
      // block. If not, we call `posFromDOM` on the raw node/offset.
      let outsideBlock = -1;
      for (let cur = node, sawBlock = false;;) {
          if (cur == view.dom)
              break;
          let desc = view.docView.nearestDesc(cur, true), rect;
          if (!desc)
              return null;
          if (desc.dom.nodeType == 1 && (desc.node.isBlock && desc.parent || !desc.contentDOM) &&
              // Ignore elements with zero-size bounding rectangles
              ((rect = desc.dom.getBoundingClientRect()).width || rect.height)) {
              if (desc.node.isBlock && desc.parent && !/^T(R|BODY|HEAD|FOOT)$/.test(desc.dom.nodeName)) {
                  // Only apply the horizontal test to the innermost block. Vertical for any parent.
                  if (!sawBlock && rect.left > coords.left || rect.top > coords.top)
                      outsideBlock = desc.posBefore;
                  else if (!sawBlock && rect.right < coords.left || rect.bottom < coords.top)
                      outsideBlock = desc.posAfter;
                  sawBlock = true;
              }
              if (!desc.contentDOM && outsideBlock < 0 && !desc.node.isText) {
                  // If we are inside a leaf, return the side of the leaf closer to the coords
                  let before = desc.node.isBlock ? coords.top < (rect.top + rect.bottom) / 2
                      : coords.left < (rect.left + rect.right) / 2;
                  return before ? desc.posBefore : desc.posAfter;
              }
          }
          cur = desc.dom.parentNode;
      }
      return outsideBlock > -1 ? outsideBlock : view.docView.posFromDOM(node, offset, -1);
  }
  function elementFromPoint(element, coords, box) {
      let len = element.childNodes.length;
      if (len && box.top < box.bottom) {
          for (let startI = Math.max(0, Math.min(len - 1, Math.floor(len * (coords.top - box.top) / (box.bottom - box.top)) - 2)), i = startI;;) {
              let child = element.childNodes[i];
              if (child.nodeType == 1) {
                  let rects = child.getClientRects();
                  for (let j = 0; j < rects.length; j++) {
                      let rect = rects[j];
                      if (inRect(coords, rect))
                          return elementFromPoint(child, coords, rect);
                  }
              }
              if ((i = (i + 1) % len) == startI)
                  break;
          }
      }
      return element;
  }
  // Given an x,y position on the editor, get the position in the document.
  function posAtCoords(view, coords) {
      let doc = view.dom.ownerDocument, node, offset = 0;
      let caret = caretFromPoint(doc, coords.left, coords.top);
      if (caret)
          ({ node, offset } = caret);
      let elt = (view.root.elementFromPoint ? view.root : doc)
          .elementFromPoint(coords.left, coords.top);
      let pos;
      if (!elt || !view.dom.contains(elt.nodeType != 1 ? elt.parentNode : elt)) {
          let box = view.dom.getBoundingClientRect();
          if (!inRect(coords, box))
              return null;
          elt = elementFromPoint(view.dom, coords, box);
          if (!elt)
              return null;
      }
      // Safari's caretRangeFromPoint returns nonsense when on a draggable element
      if (safari) {
          for (let p = elt; node && p; p = parentNode(p))
              if (p.draggable)
                  node = undefined;
      }
      elt = targetKludge(elt, coords);
      if (node) {
          if (gecko && node.nodeType == 1) {
              // Firefox will sometimes return offsets into <input> nodes, which
              // have no actual children, from caretPositionFromPoint (#953)
              offset = Math.min(offset, node.childNodes.length);
              // It'll also move the returned position before image nodes,
              // even if those are behind it.
              if (offset < node.childNodes.length) {
                  let next = node.childNodes[offset], box;
                  if (next.nodeName == "IMG" && (box = next.getBoundingClientRect()).right <= coords.left &&
                      box.bottom > coords.top)
                      offset++;
              }
          }
          let prev;
          // When clicking above the right side of an uneditable node, Chrome will report a cursor position after that node.
          if (webkit && offset && node.nodeType == 1 && (prev = node.childNodes[offset - 1]).nodeType == 1 &&
              prev.contentEditable == "false" && prev.getBoundingClientRect().top >= coords.top)
              offset--;
          // Suspiciously specific kludge to work around caret*FromPoint
          // never returning a position at the end of the document
          if (node == view.dom && offset == node.childNodes.length - 1 && node.lastChild.nodeType == 1 &&
              coords.top > node.lastChild.getBoundingClientRect().bottom)
              pos = view.state.doc.content.size;
          // Ignore positions directly after a BR, since caret*FromPoint
          // 'round up' positions that would be more accurately placed
          // before the BR node.
          else if (offset == 0 || node.nodeType != 1 || node.childNodes[offset - 1].nodeName != "BR")
              pos = posFromCaret(view, node, offset, coords);
      }
      if (pos == null)
          pos = posFromElement(view, elt, coords);
      let desc = view.docView.nearestDesc(elt, true);
      return { pos, inside: desc ? desc.posAtStart - desc.border : -1 };
  }
  function nonZero(rect) {
      return rect.top < rect.bottom || rect.left < rect.right;
  }
  function singleRect(target, bias) {
      let rects = target.getClientRects();
      if (rects.length) {
          let first = rects[bias < 0 ? 0 : rects.length - 1];
          if (nonZero(first))
              return first;
      }
      return Array.prototype.find.call(rects, nonZero) || target.getBoundingClientRect();
  }
  const BIDI = /[\u0590-\u05f4\u0600-\u06ff\u0700-\u08ac]/;
  // Given a position in the document model, get a bounding box of the
  // character at that position, relative to the window.
  function coordsAtPos(view, pos, side) {
      let { node, offset, atom } = view.docView.domFromPos(pos, side < 0 ? -1 : 1);
      let supportEmptyRange = webkit || gecko;
      if (node.nodeType == 3) {
          // These browsers support querying empty text ranges. Prefer that in
          // bidi context or when at the end of a node.
          if (supportEmptyRange && (BIDI.test(node.nodeValue) || (side < 0 ? !offset : offset == node.nodeValue.length))) {
              let rect = singleRect(textRange(node, offset, offset), side);
              // Firefox returns bad results (the position before the space)
              // when querying a position directly after line-broken
              // whitespace. Detect this situation and and kludge around it
              if (gecko && offset && /\s/.test(node.nodeValue[offset - 1]) && offset < node.nodeValue.length) {
                  let rectBefore = singleRect(textRange(node, offset - 1, offset - 1), -1);
                  if (rectBefore.top == rect.top) {
                      let rectAfter = singleRect(textRange(node, offset, offset + 1), -1);
                      if (rectAfter.top != rect.top)
                          return flattenV(rectAfter, rectAfter.left < rectBefore.left);
                  }
              }
              return rect;
          }
          else {
              let from = offset, to = offset, takeSide = side < 0 ? 1 : -1;
              if (side < 0 && !offset) {
                  to++;
                  takeSide = -1;
              }
              else if (side >= 0 && offset == node.nodeValue.length) {
                  from--;
                  takeSide = 1;
              }
              else if (side < 0) {
                  from--;
              }
              else {
                  to++;
              }
              return flattenV(singleRect(textRange(node, from, to), takeSide), takeSide < 0);
          }
      }
      let $dom = view.state.doc.resolve(pos - (atom || 0));
      // Return a horizontal line in block context
      if (!$dom.parent.inlineContent) {
          if (atom == null && offset && (side < 0 || offset == nodeSize(node))) {
              let before = node.childNodes[offset - 1];
              if (before.nodeType == 1)
                  return flattenH(before.getBoundingClientRect(), false);
          }
          if (atom == null && offset < nodeSize(node)) {
              let after = node.childNodes[offset];
              if (after.nodeType == 1)
                  return flattenH(after.getBoundingClientRect(), true);
          }
          return flattenH(node.getBoundingClientRect(), side >= 0);
      }
      // Inline, not in text node (this is not Bidi-safe)
      if (atom == null && offset && (side < 0 || offset == nodeSize(node))) {
          let before = node.childNodes[offset - 1];
          let target = before.nodeType == 3 ? textRange(before, nodeSize(before) - (supportEmptyRange ? 0 : 1))
              // BR nodes tend to only return the rectangle before them.
              // Only use them if they are the last element in their parent
              : before.nodeType == 1 && (before.nodeName != "BR" || !before.nextSibling) ? before : null;
          if (target)
              return flattenV(singleRect(target, 1), false);
      }
      if (atom == null && offset < nodeSize(node)) {
          let after = node.childNodes[offset];
          while (after.pmViewDesc && after.pmViewDesc.ignoreForCoords)
              after = after.nextSibling;
          let target = !after ? null : after.nodeType == 3 ? textRange(after, 0, (supportEmptyRange ? 0 : 1))
              : after.nodeType == 1 ? after : null;
          if (target)
              return flattenV(singleRect(target, -1), true);
      }
      // All else failed, just try to get a rectangle for the target node
      return flattenV(singleRect(node.nodeType == 3 ? textRange(node) : node, -side), side >= 0);
  }
  function flattenV(rect, left) {
      if (rect.width == 0)
          return rect;
      let x = left ? rect.left : rect.right;
      return { top: rect.top, bottom: rect.bottom, left: x, right: x };
  }
  function flattenH(rect, top) {
      if (rect.height == 0)
          return rect;
      let y = top ? rect.top : rect.bottom;
      return { top: y, bottom: y, left: rect.left, right: rect.right };
  }
  function withFlushedState(view, state, f) {
      let viewState = view.state, active = view.root.activeElement;
      if (viewState != state)
          view.updateState(state);
      if (active != view.dom)
          view.focus();
      try {
          return f();
      }
      finally {
          if (viewState != state)
              view.updateState(viewState);
          if (active != view.dom && active)
              active.focus();
      }
  }
  // Whether vertical position motion in a given direction
  // from a position would leave a text block.
  function endOfTextblockVertical(view, state, dir) {
      let sel = state.selection;
      let $pos = dir == "up" ? sel.$from : sel.$to;
      return withFlushedState(view, state, () => {
          let { node: dom } = view.docView.domFromPos($pos.pos, dir == "up" ? -1 : 1);
          for (;;) {
              let nearest = view.docView.nearestDesc(dom, true);
              if (!nearest)
                  break;
              if (nearest.node.isBlock) {
                  dom = nearest.contentDOM || nearest.dom;
                  break;
              }
              dom = nearest.dom.parentNode;
          }
          let coords = coordsAtPos(view, $pos.pos, 1);
          for (let child = dom.firstChild; child; child = child.nextSibling) {
              let boxes;
              if (child.nodeType == 1)
                  boxes = child.getClientRects();
              else if (child.nodeType == 3)
                  boxes = textRange(child, 0, child.nodeValue.length).getClientRects();
              else
                  continue;
              for (let i = 0; i < boxes.length; i++) {
                  let box = boxes[i];
                  if (box.bottom > box.top + 1 &&
                      (dir == "up" ? coords.top - box.top > (box.bottom - coords.top) * 2
                          : box.bottom - coords.bottom > (coords.bottom - box.top) * 2))
                      return false;
              }
          }
          return true;
      });
  }
  const maybeRTL = /[\u0590-\u08ac]/;
  function endOfTextblockHorizontal(view, state, dir) {
      let { $head } = state.selection;
      if (!$head.parent.isTextblock)
          return false;
      let offset = $head.parentOffset, atStart = !offset, atEnd = offset == $head.parent.content.size;
      let sel = view.domSelection();
      if (!sel)
          return $head.pos == $head.start() || $head.pos == $head.end();
      // If the textblock is all LTR, or the browser doesn't support
      // Selection.modify (Edge), fall back to a primitive approach
      if (!maybeRTL.test($head.parent.textContent) || !sel.modify)
          return dir == "left" || dir == "backward" ? atStart : atEnd;
      return withFlushedState(view, state, () => {
          // This is a huge hack, but appears to be the best we can
          // currently do: use `Selection.modify` to move the selection by
          // one character, and see if that moves the cursor out of the
          // textblock (or doesn't move it at all, when at the start/end of
          // the document).
          let { focusNode: oldNode, focusOffset: oldOff, anchorNode, anchorOffset } = view.domSelectionRange();
          let oldBidiLevel = sel.caretBidiLevel // Only for Firefox
          ;
          sel.modify("move", dir, "character");
          let parentDOM = $head.depth ? view.docView.domAfterPos($head.before()) : view.dom;
          let { focusNode: newNode, focusOffset: newOff } = view.domSelectionRange();
          let result = newNode && !parentDOM.contains(newNode.nodeType == 1 ? newNode : newNode.parentNode) ||
              (oldNode == newNode && oldOff == newOff);
          // Restore the previous selection
          try {
              sel.collapse(anchorNode, anchorOffset);
              if (oldNode && (oldNode != anchorNode || oldOff != anchorOffset) && sel.extend)
                  sel.extend(oldNode, oldOff);
          }
          catch (_) { }
          if (oldBidiLevel != null)
              sel.caretBidiLevel = oldBidiLevel;
          return result;
      });
  }
  let cachedState = null;
  let cachedDir = null;
  let cachedResult = false;
  function endOfTextblock(view, state, dir) {
      if (cachedState == state && cachedDir == dir)
          return cachedResult;
      cachedState = state;
      cachedDir = dir;
      return cachedResult = dir == "up" || dir == "down"
          ? endOfTextblockVertical(view, state, dir)
          : endOfTextblockHorizontal(view, state, dir);
  }

  // View descriptions are data structures that describe the DOM that is
  // used to represent the editor's content. They are used for:
  //
  // - Incremental redrawing when the document changes
  //
  // - Figuring out what part of the document a given DOM position
  //   corresponds to
  //
  // - Wiring in custom implementations of the editing interface for a
  //   given node
  //
  // They form a doubly-linked mutable tree, starting at `view.docView`.
  const NOT_DIRTY = 0, CHILD_DIRTY = 1, CONTENT_DIRTY = 2, NODE_DIRTY = 3;
  // Superclass for the various kinds of descriptions. Defines their
  // basic structure and shared methods.
  class ViewDesc {
      constructor(parent, children, dom, 
      // This is the node that holds the child views. It may be null for
      // descs that don't have children.
      contentDOM) {
          this.parent = parent;
          this.children = children;
          this.dom = dom;
          this.contentDOM = contentDOM;
          this.dirty = NOT_DIRTY;
          // An expando property on the DOM node provides a link back to its
          // description.
          dom.pmViewDesc = this;
      }
      // Used to check whether a given description corresponds to a
      // widget/mark/node.
      matchesWidget(widget) { return false; }
      matchesMark(mark) { return false; }
      matchesNode(node, outerDeco, innerDeco) { return false; }
      matchesHack(nodeName) { return false; }
      // When parsing in-editor content (in domchange.js), we allow
      // descriptions to determine the parse rules that should be used to
      // parse them.
      parseRule() { return null; }
      // Used by the editor's event handler to ignore events that come
      // from certain descs.
      stopEvent(event) { return false; }
      // The size of the content represented by this desc.
      get size() {
          let size = 0;
          for (let i = 0; i < this.children.length; i++)
              size += this.children[i].size;
          return size;
      }
      // For block nodes, this represents the space taken up by their
      // start/end tokens.
      get border() { return 0; }
      destroy() {
          this.parent = undefined;
          if (this.dom.pmViewDesc == this)
              this.dom.pmViewDesc = undefined;
          for (let i = 0; i < this.children.length; i++)
              this.children[i].destroy();
      }
      posBeforeChild(child) {
          for (let i = 0, pos = this.posAtStart;; i++) {
              let cur = this.children[i];
              if (cur == child)
                  return pos;
              pos += cur.size;
          }
      }
      get posBefore() {
          return this.parent.posBeforeChild(this);
      }
      get posAtStart() {
          return this.parent ? this.parent.posBeforeChild(this) + this.border : 0;
      }
      get posAfter() {
          return this.posBefore + this.size;
      }
      get posAtEnd() {
          return this.posAtStart + this.size - 2 * this.border;
      }
      localPosFromDOM(dom, offset, bias) {
          // If the DOM position is in the content, use the child desc after
          // it to figure out a position.
          if (this.contentDOM && this.contentDOM.contains(dom.nodeType == 1 ? dom : dom.parentNode)) {
              if (bias < 0) {
                  let domBefore, desc;
                  if (dom == this.contentDOM) {
                      domBefore = dom.childNodes[offset - 1];
                  }
                  else {
                      while (dom.parentNode != this.contentDOM)
                          dom = dom.parentNode;
                      domBefore = dom.previousSibling;
                  }
                  while (domBefore && !((desc = domBefore.pmViewDesc) && desc.parent == this))
                      domBefore = domBefore.previousSibling;
                  return domBefore ? this.posBeforeChild(desc) + desc.size : this.posAtStart;
              }
              else {
                  let domAfter, desc;
                  if (dom == this.contentDOM) {
                      domAfter = dom.childNodes[offset];
                  }
                  else {
                      while (dom.parentNode != this.contentDOM)
                          dom = dom.parentNode;
                      domAfter = dom.nextSibling;
                  }
                  while (domAfter && !((desc = domAfter.pmViewDesc) && desc.parent == this))
                      domAfter = domAfter.nextSibling;
                  return domAfter ? this.posBeforeChild(desc) : this.posAtEnd;
              }
          }
          // Otherwise, use various heuristics, falling back on the bias
          // parameter, to determine whether to return the position at the
          // start or at the end of this view desc.
          let atEnd;
          if (dom == this.dom && this.contentDOM) {
              atEnd = offset > domIndex(this.contentDOM);
          }
          else if (this.contentDOM && this.contentDOM != this.dom && this.dom.contains(this.contentDOM)) {
              atEnd = dom.compareDocumentPosition(this.contentDOM) & 2;
          }
          else if (this.dom.firstChild) {
              if (offset == 0)
                  for (let search = dom;; search = search.parentNode) {
                      if (search == this.dom) {
                          atEnd = false;
                          break;
                      }
                      if (search.previousSibling)
                          break;
                  }
              if (atEnd == null && offset == dom.childNodes.length)
                  for (let search = dom;; search = search.parentNode) {
                      if (search == this.dom) {
                          atEnd = true;
                          break;
                      }
                      if (search.nextSibling)
                          break;
                  }
          }
          return (atEnd == null ? bias > 0 : atEnd) ? this.posAtEnd : this.posAtStart;
      }
      nearestDesc(dom, onlyNodes = false) {
          for (let first = true, cur = dom; cur; cur = cur.parentNode) {
              let desc = this.getDesc(cur), nodeDOM;
              if (desc && (!onlyNodes || desc.node)) {
                  // If dom is outside of this desc's nodeDOM, don't count it.
                  if (first && (nodeDOM = desc.nodeDOM) &&
                      !(nodeDOM.nodeType == 1 ? nodeDOM.contains(dom.nodeType == 1 ? dom : dom.parentNode) : nodeDOM == dom))
                      first = false;
                  else
                      return desc;
              }
          }
      }
      getDesc(dom) {
          let desc = dom.pmViewDesc;
          for (let cur = desc; cur; cur = cur.parent)
              if (cur == this)
                  return desc;
      }
      posFromDOM(dom, offset, bias) {
          for (let scan = dom; scan; scan = scan.parentNode) {
              let desc = this.getDesc(scan);
              if (desc)
                  return desc.localPosFromDOM(dom, offset, bias);
          }
          return -1;
      }
      // Find the desc for the node after the given pos, if any. (When a
      // parent node overrode rendering, there might not be one.)
      descAt(pos) {
          for (let i = 0, offset = 0; i < this.children.length; i++) {
              let child = this.children[i], end = offset + child.size;
              if (offset == pos && end != offset) {
                  while (!child.border && child.children.length) {
                      for (let i = 0; i < child.children.length; i++) {
                          let inner = child.children[i];
                          if (inner.size) {
                              child = inner;
                              break;
                          }
                      }
                  }
                  return child;
              }
              if (pos < end)
                  return child.descAt(pos - offset - child.border);
              offset = end;
          }
      }
      domFromPos(pos, side) {
          if (!this.contentDOM)
              return { node: this.dom, offset: 0, atom: pos + 1 };
          // First find the position in the child array
          let i = 0, offset = 0;
          for (let curPos = 0; i < this.children.length; i++) {
              let child = this.children[i], end = curPos + child.size;
              if (end > pos || child instanceof TrailingHackViewDesc) {
                  offset = pos - curPos;
                  break;
              }
              curPos = end;
          }
          // If this points into the middle of a child, call through
          if (offset)
              return this.children[i].domFromPos(offset - this.children[i].border, side);
          // Go back if there were any zero-length widgets with side >= 0 before this point
          for (let prev; i && !(prev = this.children[i - 1]).size && prev instanceof WidgetViewDesc && prev.side >= 0; i--) { }
          // Scan towards the first useable node
          if (side <= 0) {
              let prev, enter = true;
              for (;; i--, enter = false) {
                  prev = i ? this.children[i - 1] : null;
                  if (!prev || prev.dom.parentNode == this.contentDOM)
                      break;
              }
              if (prev && side && enter && !prev.border && !prev.domAtom)
                  return prev.domFromPos(prev.size, side);
              return { node: this.contentDOM, offset: prev ? domIndex(prev.dom) + 1 : 0 };
          }
          else {
              let next, enter = true;
              for (;; i++, enter = false) {
                  next = i < this.children.length ? this.children[i] : null;
                  if (!next || next.dom.parentNode == this.contentDOM)
                      break;
              }
              if (next && enter && !next.border && !next.domAtom)
                  return next.domFromPos(0, side);
              return { node: this.contentDOM, offset: next ? domIndex(next.dom) : this.contentDOM.childNodes.length };
          }
      }
      // Used to find a DOM range in a single parent for a given changed
      // range.
      parseRange(from, to, base = 0) {
          if (this.children.length == 0)
              return { node: this.contentDOM, from, to, fromOffset: 0, toOffset: this.contentDOM.childNodes.length };
          let fromOffset = -1, toOffset = -1;
          for (let offset = base, i = 0;; i++) {
              let child = this.children[i], end = offset + child.size;
              if (fromOffset == -1 && from <= end) {
                  let childBase = offset + child.border;
                  // FIXME maybe descend mark views to parse a narrower range?
                  if (from >= childBase && to <= end - child.border && child.node &&
                      child.contentDOM && this.contentDOM.contains(child.contentDOM))
                      return child.parseRange(from, to, childBase);
                  from = offset;
                  for (let j = i; j > 0; j--) {
                      let prev = this.children[j - 1];
                      if (prev.size && prev.dom.parentNode == this.contentDOM && !prev.emptyChildAt(1)) {
                          fromOffset = domIndex(prev.dom) + 1;
                          break;
                      }
                      from -= prev.size;
                  }
                  if (fromOffset == -1)
                      fromOffset = 0;
              }
              if (fromOffset > -1 && (end > to || i == this.children.length - 1)) {
                  to = end;
                  for (let j = i + 1; j < this.children.length; j++) {
                      let next = this.children[j];
                      if (next.size && next.dom.parentNode == this.contentDOM && !next.emptyChildAt(-1)) {
                          toOffset = domIndex(next.dom);
                          break;
                      }
                      to += next.size;
                  }
                  if (toOffset == -1)
                      toOffset = this.contentDOM.childNodes.length;
                  break;
              }
              offset = end;
          }
          return { node: this.contentDOM, from, to, fromOffset, toOffset };
      }
      emptyChildAt(side) {
          if (this.border || !this.contentDOM || !this.children.length)
              return false;
          let child = this.children[side < 0 ? 0 : this.children.length - 1];
          return child.size == 0 || child.emptyChildAt(side);
      }
      domAfterPos(pos) {
          let { node, offset } = this.domFromPos(pos, 0);
          if (node.nodeType != 1 || offset == node.childNodes.length)
              throw new RangeError("No node after pos " + pos);
          return node.childNodes[offset];
      }
      // View descs are responsible for setting any selection that falls
      // entirely inside of them, so that custom implementations can do
      // custom things with the selection. Note that this falls apart when
      // a selection starts in such a node and ends in another, in which
      // case we just use whatever domFromPos produces as a best effort.
      setSelection(anchor, head, view, force = false) {
          // If the selection falls entirely in a child, give it to that child
          let from = Math.min(anchor, head), to = Math.max(anchor, head);
          for (let i = 0, offset = 0; i < this.children.length; i++) {
              let child = this.children[i], end = offset + child.size;
              if (from > offset && to < end)
                  return child.setSelection(anchor - offset - child.border, head - offset - child.border, view, force);
              offset = end;
          }
          let anchorDOM = this.domFromPos(anchor, anchor ? -1 : 1);
          let headDOM = head == anchor ? anchorDOM : this.domFromPos(head, head ? -1 : 1);
          let domSel = view.root.getSelection();
          let selRange = view.domSelectionRange();
          let brKludge = false;
          // On Firefox, using Selection.collapse to put the cursor after a
          // BR node for some reason doesn't always work (#1073). On Safari,
          // the cursor sometimes inexplicable visually lags behind its
          // reported position in such situations (#1092).
          if ((gecko || safari) && anchor == head) {
              let { node, offset } = anchorDOM;
              if (node.nodeType == 3) {
                  brKludge = !!(offset && node.nodeValue[offset - 1] == "\n");
                  // Issue #1128
                  if (brKludge && offset == node.nodeValue.length) {
                      for (let scan = node, after; scan; scan = scan.parentNode) {
                          if (after = scan.nextSibling) {
                              if (after.nodeName == "BR")
                                  anchorDOM = headDOM = { node: after.parentNode, offset: domIndex(after) + 1 };
                              break;
                          }
                          let desc = scan.pmViewDesc;
                          if (desc && desc.node && desc.node.isBlock)
                              break;
                      }
                  }
              }
              else {
                  let prev = node.childNodes[offset - 1];
                  brKludge = prev && (prev.nodeName == "BR" || prev.contentEditable == "false");
              }
          }
          // Firefox can act strangely when the selection is in front of an
          // uneditable node. See #1163 and https://bugzilla.mozilla.org/show_bug.cgi?id=1709536
          if (gecko && selRange.focusNode && selRange.focusNode != headDOM.node && selRange.focusNode.nodeType == 1) {
              let after = selRange.focusNode.childNodes[selRange.focusOffset];
              if (after && after.contentEditable == "false")
                  force = true;
          }
          if (!(force || brKludge && safari) &&
              isEquivalentPosition(anchorDOM.node, anchorDOM.offset, selRange.anchorNode, selRange.anchorOffset) &&
              isEquivalentPosition(headDOM.node, headDOM.offset, selRange.focusNode, selRange.focusOffset))
              return;
          // Selection.extend can be used to create an 'inverted' selection
          // (one where the focus is before the anchor), but not all
          // browsers support it yet.
          let domSelExtended = false;
          if ((domSel.extend || anchor == head) && !(brKludge && gecko)) {
              domSel.collapse(anchorDOM.node, anchorDOM.offset);
              try {
                  if (anchor != head)
                      domSel.extend(headDOM.node, headDOM.offset);
                  domSelExtended = true;
              }
              catch (_) {
                  // In some cases with Chrome the selection is empty after calling
                  // collapse, even when it should be valid. This appears to be a bug, but
                  // it is difficult to isolate. If this happens fallback to the old path
                  // without using extend.
                  // Similarly, this could crash on Safari if the editor is hidden, and
                  // there was no selection.
              }
          }
          if (!domSelExtended) {
              if (anchor > head) {
                  let tmp = anchorDOM;
                  anchorDOM = headDOM;
                  headDOM = tmp;
              }
              let range = document.createRange();
              range.setEnd(headDOM.node, headDOM.offset);
              range.setStart(anchorDOM.node, anchorDOM.offset);
              domSel.removeAllRanges();
              domSel.addRange(range);
          }
      }
      ignoreMutation(mutation) {
          return !this.contentDOM && mutation.type != "selection";
      }
      get contentLost() {
          return this.contentDOM && this.contentDOM != this.dom && !this.dom.contains(this.contentDOM);
      }
      // Remove a subtree of the element tree that has been touched
      // by a DOM change, so that the next update will redraw it.
      markDirty(from, to) {
          for (let offset = 0, i = 0; i < this.children.length; i++) {
              let child = this.children[i], end = offset + child.size;
              if (offset == end ? from <= end && to >= offset : from < end && to > offset) {
                  let startInside = offset + child.border, endInside = end - child.border;
                  if (from >= startInside && to <= endInside) {
                      this.dirty = from == offset || to == end ? CONTENT_DIRTY : CHILD_DIRTY;
                      if (from == startInside && to == endInside &&
                          (child.contentLost || child.dom.parentNode != this.contentDOM))
                          child.dirty = NODE_DIRTY;
                      else
                          child.markDirty(from - startInside, to - startInside);
                      return;
                  }
                  else {
                      child.dirty = child.dom == child.contentDOM && child.dom.parentNode == this.contentDOM && !child.children.length
                          ? CONTENT_DIRTY : NODE_DIRTY;
                  }
              }
              offset = end;
          }
          this.dirty = CONTENT_DIRTY;
      }
      markParentsDirty() {
          let level = 1;
          for (let node = this.parent; node; node = node.parent, level++) {
              let dirty = level == 1 ? CONTENT_DIRTY : CHILD_DIRTY;
              if (node.dirty < dirty)
                  node.dirty = dirty;
          }
      }
      get domAtom() { return false; }
      get ignoreForCoords() { return false; }
      get ignoreForSelection() { return false; }
      isText(text) { return false; }
  }
  // A widget desc represents a widget decoration, which is a DOM node
  // drawn between the document nodes.
  class WidgetViewDesc extends ViewDesc {
      constructor(parent, widget, view, pos) {
          let self, dom = widget.type.toDOM;
          if (typeof dom == "function")
              dom = dom(view, () => {
                  if (!self)
                      return pos;
                  if (self.parent)
                      return self.parent.posBeforeChild(self);
              });
          if (!widget.type.spec.raw) {
              if (dom.nodeType != 1) {
                  let wrap = document.createElement("span");
                  wrap.appendChild(dom);
                  dom = wrap;
              }
              dom.contentEditable = "false";
              dom.classList.add("ProseMirror-widget");
          }
          super(parent, [], dom, null);
          this.widget = widget;
          this.widget = widget;
          self = this;
      }
      matchesWidget(widget) {
          return this.dirty == NOT_DIRTY && widget.type.eq(this.widget.type);
      }
      parseRule() { return { ignore: true }; }
      stopEvent(event) {
          let stop = this.widget.spec.stopEvent;
          return stop ? stop(event) : false;
      }
      ignoreMutation(mutation) {
          return mutation.type != "selection" || this.widget.spec.ignoreSelection;
      }
      destroy() {
          this.widget.type.destroy(this.dom);
          super.destroy();
      }
      get domAtom() { return true; }
      get ignoreForSelection() { return !!this.widget.type.spec.relaxedSide; }
      get side() { return this.widget.type.side; }
  }
  class CompositionViewDesc extends ViewDesc {
      constructor(parent, dom, textDOM, text) {
          super(parent, [], dom, null);
          this.textDOM = textDOM;
          this.text = text;
      }
      get size() { return this.text.length; }
      localPosFromDOM(dom, offset) {
          if (dom != this.textDOM)
              return this.posAtStart + (offset ? this.size : 0);
          return this.posAtStart + offset;
      }
      domFromPos(pos) {
          return { node: this.textDOM, offset: pos };
      }
      ignoreMutation(mut) {
          return mut.type === 'characterData' && mut.target.nodeValue == mut.oldValue;
      }
  }
  // A mark desc represents a mark. May have multiple children,
  // depending on how the mark is split. Note that marks are drawn using
  // a fixed nesting order, for simplicity and predictability, so in
  // some cases they will be split more often than would appear
  // necessary.
  class MarkViewDesc extends ViewDesc {
      constructor(parent, mark, dom, contentDOM, spec) {
          super(parent, [], dom, contentDOM);
          this.mark = mark;
          this.spec = spec;
      }
      static create(parent, mark, inline, view) {
          let custom = view.nodeViews[mark.type.name];
          let spec = custom && custom(mark, view, inline);
          if (!spec || !spec.dom)
              spec = DOMSerializer.renderSpec(document, mark.type.spec.toDOM(mark, inline), null, mark.attrs);
          return new MarkViewDesc(parent, mark, spec.dom, spec.contentDOM || spec.dom, spec);
      }
      parseRule() {
          if ((this.dirty & NODE_DIRTY) || this.mark.type.spec.reparseInView)
              return null;
          return { mark: this.mark.type.name, attrs: this.mark.attrs, contentElement: this.contentDOM };
      }
      matchesMark(mark) { return this.dirty != NODE_DIRTY && this.mark.eq(mark); }
      markDirty(from, to) {
          super.markDirty(from, to);
          // Move dirty info to nearest node view
          if (this.dirty != NOT_DIRTY) {
              let parent = this.parent;
              while (!parent.node)
                  parent = parent.parent;
              if (parent.dirty < this.dirty)
                  parent.dirty = this.dirty;
              this.dirty = NOT_DIRTY;
          }
      }
      slice(from, to, view) {
          let copy = MarkViewDesc.create(this.parent, this.mark, true, view);
          let nodes = this.children, size = this.size;
          if (to < size)
              nodes = replaceNodes(nodes, to, size, view);
          if (from > 0)
              nodes = replaceNodes(nodes, 0, from, view);
          for (let i = 0; i < nodes.length; i++)
              nodes[i].parent = copy;
          copy.children = nodes;
          return copy;
      }
      ignoreMutation(mutation) {
          return this.spec.ignoreMutation ? this.spec.ignoreMutation(mutation) : super.ignoreMutation(mutation);
      }
      destroy() {
          if (this.spec.destroy)
              this.spec.destroy();
          super.destroy();
      }
  }
  // Node view descs are the main, most common type of view desc, and
  // correspond to an actual node in the document. Unlike mark descs,
  // they populate their child array themselves.
  class NodeViewDesc extends ViewDesc {
      constructor(parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM, view, pos) {
          super(parent, [], dom, contentDOM);
          this.node = node;
          this.outerDeco = outerDeco;
          this.innerDeco = innerDeco;
          this.nodeDOM = nodeDOM;
      }
      // By default, a node is rendered using the `toDOM` method from the
      // node type spec. But client code can use the `nodeViews` spec to
      // supply a custom node view, which can influence various aspects of
      // the way the node works.
      //
      // (Using subclassing for this was intentionally decided against,
      // since it'd require exposing a whole slew of finicky
      // implementation details to the user code that they probably will
      // never need.)
      static create(parent, node, outerDeco, innerDeco, view, pos) {
          let custom = view.nodeViews[node.type.name], descObj;
          let spec = custom && custom(node, view, () => {
              // (This is a function that allows the custom view to find its
              // own position)
              if (!descObj)
                  return pos;
              if (descObj.parent)
                  return descObj.parent.posBeforeChild(descObj);
          }, outerDeco, innerDeco);
          let dom = spec && spec.dom, contentDOM = spec && spec.contentDOM;
          if (node.isText) {
              if (!dom)
                  dom = document.createTextNode(node.text);
              else if (dom.nodeType != 3)
                  throw new RangeError("Text must be rendered as a DOM text node");
          }
          else if (!dom) {
              let spec = DOMSerializer.renderSpec(document, node.type.spec.toDOM(node), null, node.attrs);
              ({ dom, contentDOM } = spec);
          }
          if (!contentDOM && !node.isText && dom.nodeName != "BR") { // Chrome gets confused by <br contenteditable=false>
              if (!dom.hasAttribute("contenteditable"))
                  dom.contentEditable = "false";
              if (node.type.spec.draggable)
                  dom.draggable = true;
          }
          let nodeDOM = dom;
          dom = applyOuterDeco(dom, outerDeco, node);
          if (spec)
              return descObj = new CustomNodeViewDesc(parent, node, outerDeco, innerDeco, dom, contentDOM || null, nodeDOM, spec, view, pos + 1);
          else if (node.isText)
              return new TextViewDesc(parent, node, outerDeco, innerDeco, dom, nodeDOM, view);
          else
              return new NodeViewDesc(parent, node, outerDeco, innerDeco, dom, contentDOM || null, nodeDOM, view, pos + 1);
      }
      parseRule() {
          // Experimental kludge to allow opt-in re-parsing of nodes
          if (this.node.type.spec.reparseInView)
              return null;
          // FIXME the assumption that this can always return the current
          // attrs means that if the user somehow manages to change the
          // attrs in the dom, that won't be picked up. Not entirely sure
          // whether this is a problem
          let rule = { node: this.node.type.name, attrs: this.node.attrs };
          if (this.node.type.whitespace == "pre")
              rule.preserveWhitespace = "full";
          if (!this.contentDOM) {
              rule.getContent = () => this.node.content;
          }
          else if (!this.contentLost) {
              rule.contentElement = this.contentDOM;
          }
          else {
              // Chrome likes to randomly recreate parent nodes when
              // backspacing things. When that happens, this tries to find the
              // new parent.
              for (let i = this.children.length - 1; i >= 0; i--) {
                  let child = this.children[i];
                  if (this.dom.contains(child.dom.parentNode)) {
                      rule.contentElement = child.dom.parentNode;
                      break;
                  }
              }
              if (!rule.contentElement)
                  rule.getContent = () => Fragment.empty;
          }
          return rule;
      }
      matchesNode(node, outerDeco, innerDeco) {
          return this.dirty == NOT_DIRTY && node.eq(this.node) &&
              sameOuterDeco(outerDeco, this.outerDeco) && innerDeco.eq(this.innerDeco);
      }
      get size() { return this.node.nodeSize; }
      get border() { return this.node.isLeaf ? 0 : 1; }
      // Syncs `this.children` to match `this.node.content` and the local
      // decorations, possibly introducing nesting for marks. Then, in a
      // separate step, syncs the DOM inside `this.contentDOM` to
      // `this.children`.
      updateChildren(view, pos) {
          let inline = this.node.inlineContent, off = pos;
          let composition = view.composing ? this.localCompositionInfo(view, pos) : null;
          let localComposition = composition && composition.pos > -1 ? composition : null;
          let compositionInChild = composition && composition.pos < 0;
          let updater = new ViewTreeUpdater(this, localComposition && localComposition.node, view);
          iterDeco(this.node, this.innerDeco, (widget, i, insideNode) => {
              if (widget.spec.marks)
                  updater.syncToMarks(widget.spec.marks, inline, view);
              else if (widget.type.side >= 0 && !insideNode)
                  updater.syncToMarks(i == this.node.childCount ? Mark.none : this.node.child(i).marks, inline, view);
              // If the next node is a desc matching this widget, reuse it,
              // otherwise insert the widget as a new view desc.
              updater.placeWidget(widget, view, off);
          }, (child, outerDeco, innerDeco, i) => {
              // Make sure the wrapping mark descs match the node's marks.
              updater.syncToMarks(child.marks, inline, view);
              // Try several strategies for drawing this node
              let compIndex;
              if (updater.findNodeMatch(child, outerDeco, innerDeco, i)) ;
              else if (compositionInChild && view.state.selection.from > off &&
                  view.state.selection.to < off + child.nodeSize &&
                  (compIndex = updater.findIndexWithChild(composition.node)) > -1 &&
                  updater.updateNodeAt(child, outerDeco, innerDeco, compIndex, view)) ;
              else if (updater.updateNextNode(child, outerDeco, innerDeco, view, i, off)) ;
              else {
                  // Add it as a new view
                  updater.addNode(child, outerDeco, innerDeco, view, off);
              }
              off += child.nodeSize;
          });
          // Drop all remaining descs after the current position.
          updater.syncToMarks([], inline, view);
          if (this.node.isTextblock)
              updater.addTextblockHacks();
          updater.destroyRest();
          // Sync the DOM if anything changed
          if (updater.changed || this.dirty == CONTENT_DIRTY) {
              // May have to protect focused DOM from being changed if a composition is active
              if (localComposition)
                  this.protectLocalComposition(view, localComposition);
              renderDescs(this.contentDOM, this.children, view);
              if (ios)
                  iosHacks(this.dom);
          }
      }
      localCompositionInfo(view, pos) {
          // Only do something if both the selection and a focused text node
          // are inside of this node
          let { from, to } = view.state.selection;
          if (!(view.state.selection instanceof TextSelection) || from < pos || to > pos + this.node.content.size)
              return null;
          let textNode = view.input.compositionNode;
          if (!textNode || !this.dom.contains(textNode.parentNode))
              return null;
          if (this.node.inlineContent) {
              // Find the text in the focused node in the node, stop if it's not
              // there (may have been modified through other means, in which
              // case it should overwritten)
              let text = textNode.nodeValue;
              let textPos = findTextInFragment(this.node.content, text, from - pos, to - pos);
              return textPos < 0 ? null : { node: textNode, pos: textPos, text };
          }
          else {
              return { node: textNode, pos: -1, text: "" };
          }
      }
      protectLocalComposition(view, { node, pos, text }) {
          // The node is already part of a local view desc, leave it there
          if (this.getDesc(node))
              return;
          // Create a composition view for the orphaned nodes
          let topNode = node;
          for (;; topNode = topNode.parentNode) {
              if (topNode.parentNode == this.contentDOM)
                  break;
              while (topNode.previousSibling)
                  topNode.parentNode.removeChild(topNode.previousSibling);
              while (topNode.nextSibling)
                  topNode.parentNode.removeChild(topNode.nextSibling);
              if (topNode.pmViewDesc)
                  topNode.pmViewDesc = undefined;
          }
          let desc = new CompositionViewDesc(this, topNode, node, text);
          view.input.compositionNodes.push(desc);
          // Patch up this.children to contain the composition view
          this.children = replaceNodes(this.children, pos, pos + text.length, view, desc);
      }
      // If this desc must be updated to match the given node decoration,
      // do so and return true.
      update(node, outerDeco, innerDeco, view) {
          if (this.dirty == NODE_DIRTY ||
              !node.sameMarkup(this.node))
              return false;
          this.updateInner(node, outerDeco, innerDeco, view);
          return true;
      }
      updateInner(node, outerDeco, innerDeco, view) {
          this.updateOuterDeco(outerDeco);
          this.node = node;
          this.innerDeco = innerDeco;
          if (this.contentDOM)
              this.updateChildren(view, this.posAtStart);
          this.dirty = NOT_DIRTY;
      }
      updateOuterDeco(outerDeco) {
          if (sameOuterDeco(outerDeco, this.outerDeco))
              return;
          let needsWrap = this.nodeDOM.nodeType != 1;
          let oldDOM = this.dom;
          this.dom = patchOuterDeco(this.dom, this.nodeDOM, computeOuterDeco(this.outerDeco, this.node, needsWrap), computeOuterDeco(outerDeco, this.node, needsWrap));
          if (this.dom != oldDOM) {
              oldDOM.pmViewDesc = undefined;
              this.dom.pmViewDesc = this;
          }
          this.outerDeco = outerDeco;
      }
      // Mark this node as being the selected node.
      selectNode() {
          if (this.nodeDOM.nodeType == 1) {
              this.nodeDOM.classList.add("ProseMirror-selectednode");
              if (this.contentDOM || !this.node.type.spec.draggable)
                  this.nodeDOM.draggable = true;
          }
      }
      // Remove selected node marking from this node.
      deselectNode() {
          if (this.nodeDOM.nodeType == 1) {
              this.nodeDOM.classList.remove("ProseMirror-selectednode");
              if (this.contentDOM || !this.node.type.spec.draggable)
                  this.nodeDOM.removeAttribute("draggable");
          }
      }
      get domAtom() { return this.node.isAtom; }
  }
  // Create a view desc for the top-level document node, to be exported
  // and used by the view class.
  function docViewDesc(doc, outerDeco, innerDeco, dom, view) {
      applyOuterDeco(dom, outerDeco, doc);
      let docView = new NodeViewDesc(undefined, doc, outerDeco, innerDeco, dom, dom, dom, view, 0);
      if (docView.contentDOM)
          docView.updateChildren(view, 0);
      return docView;
  }
  class TextViewDesc extends NodeViewDesc {
      constructor(parent, node, outerDeco, innerDeco, dom, nodeDOM, view) {
          super(parent, node, outerDeco, innerDeco, dom, null, nodeDOM, view, 0);
      }
      parseRule() {
          let skip = this.nodeDOM.parentNode;
          while (skip && skip != this.dom && !skip.pmIsDeco)
              skip = skip.parentNode;
          return { skip: (skip || true) };
      }
      update(node, outerDeco, innerDeco, view) {
          if (this.dirty == NODE_DIRTY || (this.dirty != NOT_DIRTY && !this.inParent()) ||
              !node.sameMarkup(this.node))
              return false;
          this.updateOuterDeco(outerDeco);
          if ((this.dirty != NOT_DIRTY || node.text != this.node.text) && node.text != this.nodeDOM.nodeValue) {
              this.nodeDOM.nodeValue = node.text;
              if (view.trackWrites == this.nodeDOM)
                  view.trackWrites = null;
          }
          this.node = node;
          this.dirty = NOT_DIRTY;
          return true;
      }
      inParent() {
          let parentDOM = this.parent.contentDOM;
          for (let n = this.nodeDOM; n; n = n.parentNode)
              if (n == parentDOM)
                  return true;
          return false;
      }
      domFromPos(pos) {
          return { node: this.nodeDOM, offset: pos };
      }
      localPosFromDOM(dom, offset, bias) {
          if (dom == this.nodeDOM)
              return this.posAtStart + Math.min(offset, this.node.text.length);
          return super.localPosFromDOM(dom, offset, bias);
      }
      ignoreMutation(mutation) {
          return mutation.type != "characterData" && mutation.type != "selection";
      }
      slice(from, to, view) {
          let node = this.node.cut(from, to), dom = document.createTextNode(node.text);
          return new TextViewDesc(this.parent, node, this.outerDeco, this.innerDeco, dom, dom, view);
      }
      markDirty(from, to) {
          super.markDirty(from, to);
          if (this.dom != this.nodeDOM && (from == 0 || to == this.nodeDOM.nodeValue.length))
              this.dirty = NODE_DIRTY;
      }
      get domAtom() { return false; }
      isText(text) { return this.node.text == text; }
  }
  // A dummy desc used to tag trailing BR or IMG nodes created to work
  // around contentEditable terribleness.
  class TrailingHackViewDesc extends ViewDesc {
      parseRule() { return { ignore: true }; }
      matchesHack(nodeName) { return this.dirty == NOT_DIRTY && this.dom.nodeName == nodeName; }
      get domAtom() { return true; }
      get ignoreForCoords() { return this.dom.nodeName == "IMG"; }
  }
  // A separate subclass is used for customized node views, so that the
  // extra checks only have to be made for nodes that are actually
  // customized.
  class CustomNodeViewDesc extends NodeViewDesc {
      constructor(parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM, spec, view, pos) {
          super(parent, node, outerDeco, innerDeco, dom, contentDOM, nodeDOM, view, pos);
          this.spec = spec;
      }
      // A custom `update` method gets to decide whether the update goes
      // through. If it does, and there's a `contentDOM` node, our logic
      // updates the children.
      update(node, outerDeco, innerDeco, view) {
          if (this.dirty == NODE_DIRTY)
              return false;
          if (this.spec.update && (this.node.type == node.type || this.spec.multiType)) {
              let result = this.spec.update(node, outerDeco, innerDeco);
              if (result)
                  this.updateInner(node, outerDeco, innerDeco, view);
              return result;
          }
          else if (!this.contentDOM && !node.isLeaf) {
              return false;
          }
          else {
              return super.update(node, outerDeco, innerDeco, view);
          }
      }
      selectNode() {
          this.spec.selectNode ? this.spec.selectNode() : super.selectNode();
      }
      deselectNode() {
          this.spec.deselectNode ? this.spec.deselectNode() : super.deselectNode();
      }
      setSelection(anchor, head, view, force) {
          this.spec.setSelection ? this.spec.setSelection(anchor, head, view.root)
              : super.setSelection(anchor, head, view, force);
      }
      destroy() {
          if (this.spec.destroy)
              this.spec.destroy();
          super.destroy();
      }
      stopEvent(event) {
          return this.spec.stopEvent ? this.spec.stopEvent(event) : false;
      }
      ignoreMutation(mutation) {
          return this.spec.ignoreMutation ? this.spec.ignoreMutation(mutation) : super.ignoreMutation(mutation);
      }
  }
  // Sync the content of the given DOM node with the nodes associated
  // with the given array of view descs, recursing into mark descs
  // because this should sync the subtree for a whole node at a time.
  function renderDescs(parentDOM, descs, view) {
      let dom = parentDOM.firstChild, written = false;
      for (let i = 0; i < descs.length; i++) {
          let desc = descs[i], childDOM = desc.dom;
          if (childDOM.parentNode == parentDOM) {
              while (childDOM != dom) {
                  dom = rm(dom);
                  written = true;
              }
              dom = dom.nextSibling;
          }
          else {
              written = true;
              parentDOM.insertBefore(childDOM, dom);
          }
          if (desc instanceof MarkViewDesc) {
              let pos = dom ? dom.previousSibling : parentDOM.lastChild;
              renderDescs(desc.contentDOM, desc.children, view);
              dom = pos ? pos.nextSibling : parentDOM.firstChild;
          }
      }
      while (dom) {
          dom = rm(dom);
          written = true;
      }
      if (written && view.trackWrites == parentDOM)
          view.trackWrites = null;
  }
  const OuterDecoLevel = function (nodeName) {
      if (nodeName)
          this.nodeName = nodeName;
  };
  OuterDecoLevel.prototype = Object.create(null);
  const noDeco = [new OuterDecoLevel];
  function computeOuterDeco(outerDeco, node, needsWrap) {
      if (outerDeco.length == 0)
          return noDeco;
      let top = needsWrap ? noDeco[0] : new OuterDecoLevel, result = [top];
      for (let i = 0; i < outerDeco.length; i++) {
          let attrs = outerDeco[i].type.attrs;
          if (!attrs)
              continue;
          if (attrs.nodeName)
              result.push(top = new OuterDecoLevel(attrs.nodeName));
          for (let name in attrs) {
              let val = attrs[name];
              if (val == null)
                  continue;
              if (needsWrap && result.length == 1)
                  result.push(top = new OuterDecoLevel(node.isInline ? "span" : "div"));
              if (name == "class")
                  top.class = (top.class ? top.class + " " : "") + val;
              else if (name == "style")
                  top.style = (top.style ? top.style + ";" : "") + val;
              else if (name != "nodeName")
                  top[name] = val;
          }
      }
      return result;
  }
  function patchOuterDeco(outerDOM, nodeDOM, prevComputed, curComputed) {
      // Shortcut for trivial case
      if (prevComputed == noDeco && curComputed == noDeco)
          return nodeDOM;
      let curDOM = nodeDOM;
      for (let i = 0; i < curComputed.length; i++) {
          let deco = curComputed[i], prev = prevComputed[i];
          if (i) {
              let parent;
              if (prev && prev.nodeName == deco.nodeName && curDOM != outerDOM &&
                  (parent = curDOM.parentNode) && parent.nodeName.toLowerCase() == deco.nodeName) {
                  curDOM = parent;
              }
              else {
                  parent = document.createElement(deco.nodeName);
                  parent.pmIsDeco = true;
                  parent.appendChild(curDOM);
                  prev = noDeco[0];
                  curDOM = parent;
              }
          }
          patchAttributes(curDOM, prev || noDeco[0], deco);
      }
      return curDOM;
  }
  function patchAttributes(dom, prev, cur) {
      for (let name in prev)
          if (name != "class" && name != "style" && name != "nodeName" && !(name in cur))
              dom.removeAttribute(name);
      for (let name in cur)
          if (name != "class" && name != "style" && name != "nodeName" && cur[name] != prev[name])
              dom.setAttribute(name, cur[name]);
      if (prev.class != cur.class) {
          let prevList = prev.class ? prev.class.split(" ").filter(Boolean) : [];
          let curList = cur.class ? cur.class.split(" ").filter(Boolean) : [];
          for (let i = 0; i < prevList.length; i++)
              if (curList.indexOf(prevList[i]) == -1)
                  dom.classList.remove(prevList[i]);
          for (let i = 0; i < curList.length; i++)
              if (prevList.indexOf(curList[i]) == -1)
                  dom.classList.add(curList[i]);
          if (dom.classList.length == 0)
              dom.removeAttribute("class");
      }
      if (prev.style != cur.style) {
          if (prev.style) {
              let prop = /\s*([\w\-\xa1-\uffff]+)\s*:(?:"(?:\\.|[^"])*"|'(?:\\.|[^'])*'|\(.*?\)|[^;])*/g, m;
              while (m = prop.exec(prev.style))
                  dom.style.removeProperty(m[1]);
          }
          if (cur.style)
              dom.style.cssText += cur.style;
      }
  }
  function applyOuterDeco(dom, deco, node) {
      return patchOuterDeco(dom, dom, noDeco, computeOuterDeco(deco, node, dom.nodeType != 1));
  }
  function sameOuterDeco(a, b) {
      if (a.length != b.length)
          return false;
      for (let i = 0; i < a.length; i++)
          if (!a[i].type.eq(b[i].type))
              return false;
      return true;
  }
  // Remove a DOM node and return its next sibling.
  function rm(dom) {
      let next = dom.nextSibling;
      dom.parentNode.removeChild(dom);
      return next;
  }
  // Helper class for incrementally updating a tree of mark descs and
  // the widget and node descs inside of them.
  class ViewTreeUpdater {
      constructor(top, lock, view) {
          this.lock = lock;
          this.view = view;
          // Index into `this.top`'s child array, represents the current
          // update position.
          this.index = 0;
          // When entering a mark, the current top and index are pushed
          // onto this.
          this.stack = [];
          // Tracks whether anything was changed
          this.changed = false;
          this.top = top;
          this.preMatch = preMatch(top.node.content, top);
      }
      // Destroy and remove the children between the given indices in
      // `this.top`.
      destroyBetween(start, end) {
          if (start == end)
              return;
          for (let i = start; i < end; i++)
              this.top.children[i].destroy();
          this.top.children.splice(start, end - start);
          this.changed = true;
      }
      // Destroy all remaining children in `this.top`.
      destroyRest() {
          this.destroyBetween(this.index, this.top.children.length);
      }
      // Sync the current stack of mark descs with the given array of
      // marks, reusing existing mark descs when possible.
      syncToMarks(marks, inline, view) {
          let keep = 0, depth = this.stack.length >> 1;
          let maxKeep = Math.min(depth, marks.length);
          while (keep < maxKeep &&
              (keep == depth - 1 ? this.top : this.stack[(keep + 1) << 1])
                  .matchesMark(marks[keep]) && marks[keep].type.spec.spanning !== false)
              keep++;
          while (keep < depth) {
              this.destroyRest();
              this.top.dirty = NOT_DIRTY;
              this.index = this.stack.pop();
              this.top = this.stack.pop();
              depth--;
          }
          while (depth < marks.length) {
              this.stack.push(this.top, this.index + 1);
              let found = -1;
              for (let i = this.index; i < Math.min(this.index + 3, this.top.children.length); i++) {
                  let next = this.top.children[i];
                  if (next.matchesMark(marks[depth]) && !this.isLocked(next.dom)) {
                      found = i;
                      break;
                  }
              }
              if (found > -1) {
                  if (found > this.index) {
                      this.changed = true;
                      this.destroyBetween(this.index, found);
                  }
                  this.top = this.top.children[this.index];
              }
              else {
                  let markDesc = MarkViewDesc.create(this.top, marks[depth], inline, view);
                  this.top.children.splice(this.index, 0, markDesc);
                  this.top = markDesc;
                  this.changed = true;
              }
              this.index = 0;
              depth++;
          }
      }
      // Try to find a node desc matching the given data. Skip over it and
      // return true when successful.
      findNodeMatch(node, outerDeco, innerDeco, index) {
          let found = -1, targetDesc;
          if (index >= this.preMatch.index &&
              (targetDesc = this.preMatch.matches[index - this.preMatch.index]).parent == this.top &&
              targetDesc.matchesNode(node, outerDeco, innerDeco)) {
              found = this.top.children.indexOf(targetDesc, this.index);
          }
          else {
              for (let i = this.index, e = Math.min(this.top.children.length, i + 5); i < e; i++) {
                  let child = this.top.children[i];
                  if (child.matchesNode(node, outerDeco, innerDeco) && !this.preMatch.matched.has(child)) {
                      found = i;
                      break;
                  }
              }
          }
          if (found < 0)
              return false;
          this.destroyBetween(this.index, found);
          this.index++;
          return true;
      }
      updateNodeAt(node, outerDeco, innerDeco, index, view) {
          let child = this.top.children[index];
          if (child.dirty == NODE_DIRTY && child.dom == child.contentDOM)
              child.dirty = CONTENT_DIRTY;
          if (!child.update(node, outerDeco, innerDeco, view))
              return false;
          this.destroyBetween(this.index, index);
          this.index++;
          return true;
      }
      findIndexWithChild(domNode) {
          for (;;) {
              let parent = domNode.parentNode;
              if (!parent)
                  return -1;
              if (parent == this.top.contentDOM) {
                  let desc = domNode.pmViewDesc;
                  if (desc)
                      for (let i = this.index; i < this.top.children.length; i++) {
                          if (this.top.children[i] == desc)
                              return i;
                      }
                  return -1;
              }
              domNode = parent;
          }
      }
      // Try to update the next node, if any, to the given data. Checks
      // pre-matches to avoid overwriting nodes that could still be used.
      updateNextNode(node, outerDeco, innerDeco, view, index, pos) {
          for (let i = this.index; i < this.top.children.length; i++) {
              let next = this.top.children[i];
              if (next instanceof NodeViewDesc) {
                  let preMatch = this.preMatch.matched.get(next);
                  if (preMatch != null && preMatch != index)
                      return false;
                  let nextDOM = next.dom, updated;
                  // Can't update if nextDOM is or contains this.lock, except if
                  // it's a text node whose content already matches the new text
                  // and whose decorations match the new ones.
                  let locked = this.isLocked(nextDOM) &&
                      !(node.isText && next.node && next.node.isText && next.nodeDOM.nodeValue == node.text &&
                          next.dirty != NODE_DIRTY && sameOuterDeco(outerDeco, next.outerDeco));
                  if (!locked && next.update(node, outerDeco, innerDeco, view)) {
                      this.destroyBetween(this.index, i);
                      if (next.dom != nextDOM)
                          this.changed = true;
                      this.index++;
                      return true;
                  }
                  else if (!locked && (updated = this.recreateWrapper(next, node, outerDeco, innerDeco, view, pos))) {
                      this.destroyBetween(this.index, i);
                      this.top.children[this.index] = updated;
                      if (updated.contentDOM) {
                          updated.dirty = CONTENT_DIRTY;
                          updated.updateChildren(view, pos + 1);
                          updated.dirty = NOT_DIRTY;
                      }
                      this.changed = true;
                      this.index++;
                      return true;
                  }
                  break;
              }
          }
          return false;
      }
      // When a node with content is replaced by a different node with
      // identical content, move over its children.
      recreateWrapper(next, node, outerDeco, innerDeco, view, pos) {
          if (next.dirty || node.isAtom || !next.children.length ||
              !next.node.content.eq(node.content) ||
              !sameOuterDeco(outerDeco, next.outerDeco) || !innerDeco.eq(next.innerDeco))
              return null;
          let wrapper = NodeViewDesc.create(this.top, node, outerDeco, innerDeco, view, pos);
          if (wrapper.contentDOM) {
              wrapper.children = next.children;
              next.children = [];
              for (let ch of wrapper.children)
                  ch.parent = wrapper;
          }
          next.destroy();
          return wrapper;
      }
      // Insert the node as a newly created node desc.
      addNode(node, outerDeco, innerDeco, view, pos) {
          let desc = NodeViewDesc.create(this.top, node, outerDeco, innerDeco, view, pos);
          if (desc.contentDOM)
              desc.updateChildren(view, pos + 1);
          this.top.children.splice(this.index++, 0, desc);
          this.changed = true;
      }
      placeWidget(widget, view, pos) {
          let next = this.index < this.top.children.length ? this.top.children[this.index] : null;
          if (next && next.matchesWidget(widget) &&
              (widget == next.widget || !next.widget.type.toDOM.parentNode)) {
              this.index++;
          }
          else {
              let desc = new WidgetViewDesc(this.top, widget, view, pos);
              this.top.children.splice(this.index++, 0, desc);
              this.changed = true;
          }
      }
      // Make sure a textblock looks and behaves correctly in
      // contentEditable.
      addTextblockHacks() {
          let lastChild = this.top.children[this.index - 1], parent = this.top;
          while (lastChild instanceof MarkViewDesc) {
              parent = lastChild;
              lastChild = parent.children[parent.children.length - 1];
          }
          if (!lastChild || // Empty textblock
              !(lastChild instanceof TextViewDesc) ||
              /\n$/.test(lastChild.node.text) ||
              (this.view.requiresGeckoHackNode && /\s$/.test(lastChild.node.text))) {
              // Avoid bugs in Safari's cursor drawing (#1165) and Chrome's mouse selection (#1152)
              if ((safari || chrome) && lastChild && lastChild.dom.contentEditable == "false")
                  this.addHackNode("IMG", parent);
              this.addHackNode("BR", this.top);
          }
      }
      addHackNode(nodeName, parent) {
          if (parent == this.top && this.index < parent.children.length && parent.children[this.index].matchesHack(nodeName)) {
              this.index++;
          }
          else {
              let dom = document.createElement(nodeName);
              if (nodeName == "IMG") {
                  dom.className = "ProseMirror-separator";
                  dom.alt = "";
              }
              if (nodeName == "BR")
                  dom.className = "ProseMirror-trailingBreak";
              let hack = new TrailingHackViewDesc(this.top, [], dom, null);
              if (parent != this.top)
                  parent.children.push(hack);
              else
                  parent.children.splice(this.index++, 0, hack);
              this.changed = true;
          }
      }
      isLocked(node) {
          return this.lock && (node == this.lock || node.nodeType == 1 && node.contains(this.lock.parentNode));
      }
  }
  // Iterate from the end of the fragment and array of descs to find
  // directly matching ones, in order to avoid overeagerly reusing those
  // for other nodes. Returns the fragment index of the first node that
  // is part of the sequence of matched nodes at the end of the
  // fragment.
  function preMatch(frag, parentDesc) {
      let curDesc = parentDesc, descI = curDesc.children.length;
      let fI = frag.childCount, matched = new Map, matches = [];
      outer: while (fI > 0) {
          let desc;
          for (;;) {
              if (descI) {
                  let next = curDesc.children[descI - 1];
                  if (next instanceof MarkViewDesc) {
                      curDesc = next;
                      descI = next.children.length;
                  }
                  else {
                      desc = next;
                      descI--;
                      break;
                  }
              }
              else if (curDesc == parentDesc) {
                  break outer;
              }
              else {
                  // FIXME
                  descI = curDesc.parent.children.indexOf(curDesc);
                  curDesc = curDesc.parent;
              }
          }
          let node = desc.node;
          if (!node)
              continue;
          if (node != frag.child(fI - 1))
              break;
          --fI;
          matched.set(desc, fI);
          matches.push(desc);
      }
      return { index: fI, matched, matches: matches.reverse() };
  }
  function compareSide(a, b) {
      return a.type.side - b.type.side;
  }
  // This function abstracts iterating over the nodes and decorations in
  // a fragment. Calls `onNode` for each node, with its local and child
  // decorations. Splits text nodes when there is a decoration starting
  // or ending inside of them. Calls `onWidget` for each widget.
  function iterDeco(parent, deco, onWidget, onNode) {
      let locals = deco.locals(parent), offset = 0;
      // Simple, cheap variant for when there are no local decorations
      if (locals.length == 0) {
          for (let i = 0; i < parent.childCount; i++) {
              let child = parent.child(i);
              onNode(child, locals, deco.forChild(offset, child), i);
              offset += child.nodeSize;
          }
          return;
      }
      let decoIndex = 0, active = [], restNode = null;
      for (let parentIndex = 0;;) {
          let widget, widgets;
          while (decoIndex < locals.length && locals[decoIndex].to == offset) {
              let next = locals[decoIndex++];
              if (next.widget) {
                  if (!widget)
                      widget = next;
                  else
                      (widgets || (widgets = [widget])).push(next);
              }
          }
          if (widget) {
              if (widgets) {
                  widgets.sort(compareSide);
                  for (let i = 0; i < widgets.length; i++)
                      onWidget(widgets[i], parentIndex, !!restNode);
              }
              else {
                  onWidget(widget, parentIndex, !!restNode);
              }
          }
          let child, index;
          if (restNode) {
              index = -1;
              child = restNode;
              restNode = null;
          }
          else if (parentIndex < parent.childCount) {
              index = parentIndex;
              child = parent.child(parentIndex++);
          }
          else {
              break;
          }
          for (let i = 0; i < active.length; i++)
              if (active[i].to <= offset)
                  active.splice(i--, 1);
          while (decoIndex < locals.length && locals[decoIndex].from <= offset && locals[decoIndex].to > offset)
              active.push(locals[decoIndex++]);
          let end = offset + child.nodeSize;
          if (child.isText) {
              let cutAt = end;
              if (decoIndex < locals.length && locals[decoIndex].from < cutAt)
                  cutAt = locals[decoIndex].from;
              for (let i = 0; i < active.length; i++)
                  if (active[i].to < cutAt)
                      cutAt = active[i].to;
              if (cutAt < end) {
                  restNode = child.cut(cutAt - offset);
                  child = child.cut(0, cutAt - offset);
                  end = cutAt;
                  index = -1;
              }
          }
          else {
              while (decoIndex < locals.length && locals[decoIndex].to < end)
                  decoIndex++;
          }
          let outerDeco = child.isInline && !child.isLeaf ? active.filter(d => !d.inline) : active.slice();
          onNode(child, outerDeco, deco.forChild(offset, child), index);
          offset = end;
      }
  }
  // List markers in Mobile Safari will mysteriously disappear
  // sometimes. This works around that.
  function iosHacks(dom) {
      if (dom.nodeName == "UL" || dom.nodeName == "OL") {
          let oldCSS = dom.style.cssText;
          dom.style.cssText = oldCSS + "; list-style: square !important";
          window.getComputedStyle(dom).listStyle;
          dom.style.cssText = oldCSS;
      }
  }
  // Find a piece of text in an inline fragment, overlapping from-to
  function findTextInFragment(frag, text, from, to) {
      for (let i = 0, pos = 0; i < frag.childCount && pos <= to;) {
          let child = frag.child(i++), childStart = pos;
          pos += child.nodeSize;
          if (!child.isText)
              continue;
          let str = child.text;
          while (i < frag.childCount) {
              let next = frag.child(i++);
              pos += next.nodeSize;
              if (!next.isText)
                  break;
              str += next.text;
          }
          if (pos >= from) {
              if (pos >= to && str.slice(to - text.length - childStart, to - childStart) == text)
                  return to - text.length;
              let found = childStart < to ? str.lastIndexOf(text, to - childStart - 1) : -1;
              if (found >= 0 && found + text.length + childStart >= from)
                  return childStart + found;
              if (from == to && str.length >= (to + text.length) - childStart &&
                  str.slice(to - childStart, to - childStart + text.length) == text)
                  return to;
          }
      }
      return -1;
  }
  // Replace range from-to in an array of view descs with replacement
  // (may be null to just delete). This goes very much against the grain
  // of the rest of this code, which tends to create nodes with the
  // right shape in one go, rather than messing with them after
  // creation, but is necessary in the composition hack.
  function replaceNodes(nodes, from, to, view, replacement) {
      let result = [];
      for (let i = 0, off = 0; i < nodes.length; i++) {
          let child = nodes[i], start = off, end = off += child.size;
          if (start >= to || end <= from) {
              result.push(child);
          }
          else {
              if (start < from)
                  result.push(child.slice(0, from - start, view));
              if (replacement) {
                  result.push(replacement);
                  replacement = undefined;
              }
              if (end > to)
                  result.push(child.slice(to - start, child.size, view));
          }
      }
      return result;
  }

  function selectionFromDOM(view, origin = null) {
      let domSel = view.domSelectionRange(), doc = view.state.doc;
      if (!domSel.focusNode)
          return null;
      let nearestDesc = view.docView.nearestDesc(domSel.focusNode), inWidget = nearestDesc && nearestDesc.size == 0;
      let head = view.docView.posFromDOM(domSel.focusNode, domSel.focusOffset, 1);
      if (head < 0)
          return null;
      let $head = doc.resolve(head), anchor, selection;
      if (selectionCollapsed(domSel)) {
          anchor = head;
          while (nearestDesc && !nearestDesc.node)
              nearestDesc = nearestDesc.parent;
          let nearestDescNode = nearestDesc.node;
          if (nearestDesc && nearestDescNode.isAtom && NodeSelection.isSelectable(nearestDescNode) && nearestDesc.parent
              && !(nearestDescNode.isInline && isOnEdge(domSel.focusNode, domSel.focusOffset, nearestDesc.dom))) {
              let pos = nearestDesc.posBefore;
              selection = new NodeSelection(head == pos ? $head : doc.resolve(pos));
          }
      }
      else {
          if (domSel instanceof view.dom.ownerDocument.defaultView.Selection && domSel.rangeCount > 1) {
              let min = head, max = head;
              for (let i = 0; i < domSel.rangeCount; i++) {
                  let range = domSel.getRangeAt(i);
                  min = Math.min(min, view.docView.posFromDOM(range.startContainer, range.startOffset, 1));
                  max = Math.max(max, view.docView.posFromDOM(range.endContainer, range.endOffset, -1));
              }
              if (min < 0)
                  return null;
              [anchor, head] = max == view.state.selection.anchor ? [max, min] : [min, max];
              $head = doc.resolve(head);
          }
          else {
              anchor = view.docView.posFromDOM(domSel.anchorNode, domSel.anchorOffset, 1);
          }
          if (anchor < 0)
              return null;
      }
      let $anchor = doc.resolve(anchor);
      if (!selection) {
          let bias = origin == "pointer" || (view.state.selection.head < $head.pos && !inWidget) ? 1 : -1;
          selection = selectionBetween(view, $anchor, $head, bias);
      }
      return selection;
  }
  function editorOwnsSelection(view) {
      return view.editable ? view.hasFocus() :
          hasSelection(view) && document.activeElement && document.activeElement.contains(view.dom);
  }
  function selectionToDOM(view, force = false) {
      let sel = view.state.selection;
      syncNodeSelection(view, sel);
      if (!editorOwnsSelection(view))
          return;
      // The delayed drag selection causes issues with Cell Selections
      // in Safari. And the drag selection delay is to workarond issues
      // which only present in Chrome.
      if (!force && view.input.mouseDown && view.input.mouseDown.allowDefault && chrome) {
          let domSel = view.domSelectionRange(), curSel = view.domObserver.currentSelection;
          if (domSel.anchorNode && curSel.anchorNode &&
              isEquivalentPosition(domSel.anchorNode, domSel.anchorOffset, curSel.anchorNode, curSel.anchorOffset)) {
              view.input.mouseDown.delayedSelectionSync = true;
              view.domObserver.setCurSelection();
              return;
          }
      }
      view.domObserver.disconnectSelection();
      if (view.cursorWrapper) {
          selectCursorWrapper(view);
      }
      else {
          let { anchor, head } = sel, resetEditableFrom, resetEditableTo;
          if (brokenSelectBetweenUneditable && !(sel instanceof TextSelection)) {
              if (!sel.$from.parent.inlineContent)
                  resetEditableFrom = temporarilyEditableNear(view, sel.from);
              if (!sel.empty && !sel.$from.parent.inlineContent)
                  resetEditableTo = temporarilyEditableNear(view, sel.to);
          }
          view.docView.setSelection(anchor, head, view, force);
          if (brokenSelectBetweenUneditable) {
              if (resetEditableFrom)
                  resetEditable(resetEditableFrom);
              if (resetEditableTo)
                  resetEditable(resetEditableTo);
          }
          if (sel.visible) {
              view.dom.classList.remove("ProseMirror-hideselection");
          }
          else {
              view.dom.classList.add("ProseMirror-hideselection");
              if ("onselectionchange" in document)
                  removeClassOnSelectionChange(view);
          }
      }
      view.domObserver.setCurSelection();
      view.domObserver.connectSelection();
  }
  // Kludge to work around Webkit not allowing a selection to start/end
  // between non-editable block nodes. We briefly make something
  // editable, set the selection, then set it uneditable again.
  const brokenSelectBetweenUneditable = safari || chrome && chrome_version < 63;
  function temporarilyEditableNear(view, pos) {
      let { node, offset } = view.docView.domFromPos(pos, 0);
      let after = offset < node.childNodes.length ? node.childNodes[offset] : null;
      let before = offset ? node.childNodes[offset - 1] : null;
      if (safari && after && after.contentEditable == "false")
          return setEditable(after);
      if ((!after || after.contentEditable == "false") &&
          (!before || before.contentEditable == "false")) {
          if (after)
              return setEditable(after);
          else if (before)
              return setEditable(before);
      }
  }
  function setEditable(element) {
      element.contentEditable = "true";
      if (safari && element.draggable) {
          element.draggable = false;
          element.wasDraggable = true;
      }
      return element;
  }
  function resetEditable(element) {
      element.contentEditable = "false";
      if (element.wasDraggable) {
          element.draggable = true;
          element.wasDraggable = null;
      }
  }
  function removeClassOnSelectionChange(view) {
      let doc = view.dom.ownerDocument;
      doc.removeEventListener("selectionchange", view.input.hideSelectionGuard);
      let domSel = view.domSelectionRange();
      let node = domSel.anchorNode, offset = domSel.anchorOffset;
      doc.addEventListener("selectionchange", view.input.hideSelectionGuard = () => {
          if (domSel.anchorNode != node || domSel.anchorOffset != offset) {
              doc.removeEventListener("selectionchange", view.input.hideSelectionGuard);
              setTimeout(() => {
                  if (!editorOwnsSelection(view) || view.state.selection.visible)
                      view.dom.classList.remove("ProseMirror-hideselection");
              }, 20);
          }
      });
  }
  function selectCursorWrapper(view) {
      let domSel = view.domSelection();
      if (!domSel)
          return;
      let node = view.cursorWrapper.dom, img = node.nodeName == "IMG";
      if (img)
          domSel.collapse(node.parentNode, domIndex(node) + 1);
      else
          domSel.collapse(node, 0);
      // Kludge to kill 'control selection' in IE11 when selecting an
      // invisible cursor wrapper, since that would result in those weird
      // resize handles and a selection that considers the absolutely
      // positioned wrapper, rather than the root editable node, the
      // focused element.
      if (!img && !view.state.selection.visible && ie$1 && ie_version <= 11) {
          node.disabled = true;
          node.disabled = false;
      }
  }
  function syncNodeSelection(view, sel) {
      if (sel instanceof NodeSelection) {
          let desc = view.docView.descAt(sel.from);
          if (desc != view.lastSelectedViewDesc) {
              clearNodeSelection(view);
              if (desc)
                  desc.selectNode();
              view.lastSelectedViewDesc = desc;
          }
      }
      else {
          clearNodeSelection(view);
      }
  }
  // Clear all DOM statefulness of the last node selection.
  function clearNodeSelection(view) {
      if (view.lastSelectedViewDesc) {
          if (view.lastSelectedViewDesc.parent)
              view.lastSelectedViewDesc.deselectNode();
          view.lastSelectedViewDesc = undefined;
      }
  }
  function selectionBetween(view, $anchor, $head, bias) {
      return view.someProp("createSelectionBetween", f => f(view, $anchor, $head))
          || TextSelection.between($anchor, $head, bias);
  }
  function hasFocusAndSelection(view) {
      if (view.editable && !view.hasFocus())
          return false;
      return hasSelection(view);
  }
  function hasSelection(view) {
      let sel = view.domSelectionRange();
      if (!sel.anchorNode)
          return false;
      try {
          // Firefox will raise 'permission denied' errors when accessing
          // properties of `sel.anchorNode` when it's in a generated CSS
          // element.
          return view.dom.contains(sel.anchorNode.nodeType == 3 ? sel.anchorNode.parentNode : sel.anchorNode) &&
              (view.editable || view.dom.contains(sel.focusNode.nodeType == 3 ? sel.focusNode.parentNode : sel.focusNode));
      }
      catch (_) {
          return false;
      }
  }
  function anchorInRightPlace(view) {
      let anchorDOM = view.docView.domFromPos(view.state.selection.anchor, 0);
      let domSel = view.domSelectionRange();
      return isEquivalentPosition(anchorDOM.node, anchorDOM.offset, domSel.anchorNode, domSel.anchorOffset);
  }

  function moveSelectionBlock(state, dir) {
      let { $anchor, $head } = state.selection;
      let $side = dir > 0 ? $anchor.max($head) : $anchor.min($head);
      let $start = !$side.parent.inlineContent ? $side : $side.depth ? state.doc.resolve(dir > 0 ? $side.after() : $side.before()) : null;
      return $start && Selection.findFrom($start, dir);
  }
  function apply(view, sel) {
      view.dispatch(view.state.tr.setSelection(sel).scrollIntoView());
      return true;
  }
  function selectHorizontally(view, dir, mods) {
      let sel = view.state.selection;
      if (sel instanceof TextSelection) {
          if (mods.indexOf("s") > -1) {
              let { $head } = sel, node = $head.textOffset ? null : dir < 0 ? $head.nodeBefore : $head.nodeAfter;
              if (!node || node.isText || !node.isLeaf)
                  return false;
              let $newHead = view.state.doc.resolve($head.pos + node.nodeSize * (dir < 0 ? -1 : 1));
              return apply(view, new TextSelection(sel.$anchor, $newHead));
          }
          else if (!sel.empty) {
              return false;
          }
          else if (view.endOfTextblock(dir > 0 ? "forward" : "backward")) {
              let next = moveSelectionBlock(view.state, dir);
              if (next && (next instanceof NodeSelection))
                  return apply(view, next);
              return false;
          }
          else if (!(mac$3 && mods.indexOf("m") > -1)) {
              let $head = sel.$head, node = $head.textOffset ? null : dir < 0 ? $head.nodeBefore : $head.nodeAfter, desc;
              if (!node || node.isText)
                  return false;
              let nodePos = dir < 0 ? $head.pos - node.nodeSize : $head.pos;
              if (!(node.isAtom || (desc = view.docView.descAt(nodePos)) && !desc.contentDOM))
                  return false;
              if (NodeSelection.isSelectable(node)) {
                  return apply(view, new NodeSelection(dir < 0 ? view.state.doc.resolve($head.pos - node.nodeSize) : $head));
              }
              else if (webkit) {
                  // Chrome and Safari will introduce extra pointless cursor
                  // positions around inline uneditable nodes, so we have to
                  // take over and move the cursor past them (#937)
                  return apply(view, new TextSelection(view.state.doc.resolve(dir < 0 ? nodePos : nodePos + node.nodeSize)));
              }
              else {
                  return false;
              }
          }
      }
      else if (sel instanceof NodeSelection && sel.node.isInline) {
          return apply(view, new TextSelection(dir > 0 ? sel.$to : sel.$from));
      }
      else {
          let next = moveSelectionBlock(view.state, dir);
          if (next)
              return apply(view, next);
          return false;
      }
  }
  function nodeLen(node) {
      return node.nodeType == 3 ? node.nodeValue.length : node.childNodes.length;
  }
  function isIgnorable(dom, dir) {
      let desc = dom.pmViewDesc;
      return desc && desc.size == 0 && (dir < 0 || dom.nextSibling || dom.nodeName != "BR");
  }
  function skipIgnoredNodes(view, dir) {
      return dir < 0 ? skipIgnoredNodesBefore(view) : skipIgnoredNodesAfter(view);
  }
  // Make sure the cursor isn't directly after one or more ignored
  // nodes, which will confuse the browser's cursor motion logic.
  function skipIgnoredNodesBefore(view) {
      let sel = view.domSelectionRange();
      let node = sel.focusNode, offset = sel.focusOffset;
      if (!node)
          return;
      let moveNode, moveOffset, force = false;
      // Gecko will do odd things when the selection is directly in front
      // of a non-editable node, so in that case, move it into the next
      // node if possible. Issue prosemirror/prosemirror#832.
      if (gecko && node.nodeType == 1 && offset < nodeLen(node) && isIgnorable(node.childNodes[offset], -1))
          force = true;
      for (;;) {
          if (offset > 0) {
              if (node.nodeType != 1) {
                  break;
              }
              else {
                  let before = node.childNodes[offset - 1];
                  if (isIgnorable(before, -1)) {
                      moveNode = node;
                      moveOffset = --offset;
                  }
                  else if (before.nodeType == 3) {
                      node = before;
                      offset = node.nodeValue.length;
                  }
                  else
                      break;
              }
          }
          else if (isBlockNode(node)) {
              break;
          }
          else {
              let prev = node.previousSibling;
              while (prev && isIgnorable(prev, -1)) {
                  moveNode = node.parentNode;
                  moveOffset = domIndex(prev);
                  prev = prev.previousSibling;
              }
              if (!prev) {
                  node = node.parentNode;
                  if (node == view.dom)
                      break;
                  offset = 0;
              }
              else {
                  node = prev;
                  offset = nodeLen(node);
              }
          }
      }
      if (force)
          setSelFocus(view, node, offset);
      else if (moveNode)
          setSelFocus(view, moveNode, moveOffset);
  }
  // Make sure the cursor isn't directly before one or more ignored
  // nodes.
  function skipIgnoredNodesAfter(view) {
      let sel = view.domSelectionRange();
      let node = sel.focusNode, offset = sel.focusOffset;
      if (!node)
          return;
      let len = nodeLen(node);
      let moveNode, moveOffset;
      for (;;) {
          if (offset < len) {
              if (node.nodeType != 1)
                  break;
              let after = node.childNodes[offset];
              if (isIgnorable(after, 1)) {
                  moveNode = node;
                  moveOffset = ++offset;
              }
              else
                  break;
          }
          else if (isBlockNode(node)) {
              break;
          }
          else {
              let next = node.nextSibling;
              while (next && isIgnorable(next, 1)) {
                  moveNode = next.parentNode;
                  moveOffset = domIndex(next) + 1;
                  next = next.nextSibling;
              }
              if (!next) {
                  node = node.parentNode;
                  if (node == view.dom)
                      break;
                  offset = len = 0;
              }
              else {
                  node = next;
                  offset = 0;
                  len = nodeLen(node);
              }
          }
      }
      if (moveNode)
          setSelFocus(view, moveNode, moveOffset);
  }
  function isBlockNode(dom) {
      let desc = dom.pmViewDesc;
      return desc && desc.node && desc.node.isBlock;
  }
  function textNodeAfter(node, offset) {
      while (node && offset == node.childNodes.length && !hasBlockDesc(node)) {
          offset = domIndex(node) + 1;
          node = node.parentNode;
      }
      while (node && offset < node.childNodes.length) {
          let next = node.childNodes[offset];
          if (next.nodeType == 3)
              return next;
          if (next.nodeType == 1 && next.contentEditable == "false")
              break;
          node = next;
          offset = 0;
      }
  }
  function textNodeBefore(node, offset) {
      while (node && !offset && !hasBlockDesc(node)) {
          offset = domIndex(node);
          node = node.parentNode;
      }
      while (node && offset) {
          let next = node.childNodes[offset - 1];
          if (next.nodeType == 3)
              return next;
          if (next.nodeType == 1 && next.contentEditable == "false")
              break;
          node = next;
          offset = node.childNodes.length;
      }
  }
  function setSelFocus(view, node, offset) {
      if (node.nodeType != 3) {
          let before, after;
          if (after = textNodeAfter(node, offset)) {
              node = after;
              offset = 0;
          }
          else if (before = textNodeBefore(node, offset)) {
              node = before;
              offset = before.nodeValue.length;
          }
      }
      let sel = view.domSelection();
      if (!sel)
          return;
      if (selectionCollapsed(sel)) {
          let range = document.createRange();
          range.setEnd(node, offset);
          range.setStart(node, offset);
          sel.removeAllRanges();
          sel.addRange(range);
      }
      else if (sel.extend) {
          sel.extend(node, offset);
      }
      view.domObserver.setCurSelection();
      let { state } = view;
      // If no state update ends up happening, reset the selection.
      setTimeout(() => {
          if (view.state == state)
              selectionToDOM(view);
      }, 50);
  }
  function findDirection(view, pos) {
      let $pos = view.state.doc.resolve(pos);
      if (!(chrome || windows$1) && $pos.parent.inlineContent) {
          let coords = view.coordsAtPos(pos);
          if (pos > $pos.start()) {
              let before = view.coordsAtPos(pos - 1);
              let mid = (before.top + before.bottom) / 2;
              if (mid > coords.top && mid < coords.bottom && Math.abs(before.left - coords.left) > 1)
                  return before.left < coords.left ? "ltr" : "rtl";
          }
          if (pos < $pos.end()) {
              let after = view.coordsAtPos(pos + 1);
              let mid = (after.top + after.bottom) / 2;
              if (mid > coords.top && mid < coords.bottom && Math.abs(after.left - coords.left) > 1)
                  return after.left > coords.left ? "ltr" : "rtl";
          }
      }
      let computed = getComputedStyle(view.dom).direction;
      return computed == "rtl" ? "rtl" : "ltr";
  }
  // Check whether vertical selection motion would involve node
  // selections. If so, apply it (if not, the result is left to the
  // browser)
  function selectVertically(view, dir, mods) {
      let sel = view.state.selection;
      if (sel instanceof TextSelection && !sel.empty || mods.indexOf("s") > -1)
          return false;
      if (mac$3 && mods.indexOf("m") > -1)
          return false;
      let { $from, $to } = sel;
      if (!$from.parent.inlineContent || view.endOfTextblock(dir < 0 ? "up" : "down")) {
          let next = moveSelectionBlock(view.state, dir);
          if (next && (next instanceof NodeSelection))
              return apply(view, next);
      }
      if (!$from.parent.inlineContent) {
          let side = dir < 0 ? $from : $to;
          let beyond = sel instanceof AllSelection ? Selection.near(side, dir) : Selection.findFrom(side, dir);
          return beyond ? apply(view, beyond) : false;
      }
      return false;
  }
  function stopNativeHorizontalDelete(view, dir) {
      if (!(view.state.selection instanceof TextSelection))
          return true;
      let { $head, $anchor, empty } = view.state.selection;
      if (!$head.sameParent($anchor))
          return true;
      if (!empty)
          return false;
      if (view.endOfTextblock(dir > 0 ? "forward" : "backward"))
          return true;
      let nextNode = !$head.textOffset && (dir < 0 ? $head.nodeBefore : $head.nodeAfter);
      if (nextNode && !nextNode.isText) {
          let tr = view.state.tr;
          if (dir < 0)
              tr.delete($head.pos - nextNode.nodeSize, $head.pos);
          else
              tr.delete($head.pos, $head.pos + nextNode.nodeSize);
          view.dispatch(tr);
          return true;
      }
      return false;
  }
  function switchEditable(view, node, state) {
      view.domObserver.stop();
      node.contentEditable = state;
      view.domObserver.start();
  }
  // Issue #867 / #1090 / https://bugs.chromium.org/p/chromium/issues/detail?id=903821
  // In which Safari (and at some point in the past, Chrome) does really
  // wrong things when the down arrow is pressed when the cursor is
  // directly at the start of a textblock and has an uneditable node
  // after it
  function safariDownArrowBug(view) {
      if (!safari || view.state.selection.$head.parentOffset > 0)
          return false;
      let { focusNode, focusOffset } = view.domSelectionRange();
      if (focusNode && focusNode.nodeType == 1 && focusOffset == 0 &&
          focusNode.firstChild && focusNode.firstChild.contentEditable == "false") {
          let child = focusNode.firstChild;
          switchEditable(view, child, "true");
          setTimeout(() => switchEditable(view, child, "false"), 20);
      }
      return false;
  }
  // A backdrop key mapping used to make sure we always suppress keys
  // that have a dangerous default effect, even if the commands they are
  // bound to return false, and to make sure that cursor-motion keys
  // find a cursor (as opposed to a node selection) when pressed. For
  // cursor-motion keys, the code in the handlers also takes care of
  // block selections.
  function getMods(event) {
      let result = "";
      if (event.ctrlKey)
          result += "c";
      if (event.metaKey)
          result += "m";
      if (event.altKey)
          result += "a";
      if (event.shiftKey)
          result += "s";
      return result;
  }
  function captureKeyDown(view, event) {
      let code = event.keyCode, mods = getMods(event);
      if (code == 8 || (mac$3 && code == 72 && mods == "c")) { // Backspace, Ctrl-h on Mac
          return stopNativeHorizontalDelete(view, -1) || skipIgnoredNodes(view, -1);
      }
      else if ((code == 46 && !event.shiftKey) || (mac$3 && code == 68 && mods == "c")) { // Delete, Ctrl-d on Mac
          return stopNativeHorizontalDelete(view, 1) || skipIgnoredNodes(view, 1);
      }
      else if (code == 13 || code == 27) { // Enter, Esc
          return true;
      }
      else if (code == 37 || (mac$3 && code == 66 && mods == "c")) { // Left arrow, Ctrl-b on Mac
          let dir = code == 37 ? (findDirection(view, view.state.selection.from) == "ltr" ? -1 : 1) : -1;
          return selectHorizontally(view, dir, mods) || skipIgnoredNodes(view, dir);
      }
      else if (code == 39 || (mac$3 && code == 70 && mods == "c")) { // Right arrow, Ctrl-f on Mac
          let dir = code == 39 ? (findDirection(view, view.state.selection.from) == "ltr" ? 1 : -1) : 1;
          return selectHorizontally(view, dir, mods) || skipIgnoredNodes(view, dir);
      }
      else if (code == 38 || (mac$3 && code == 80 && mods == "c")) { // Up arrow, Ctrl-p on Mac
          return selectVertically(view, -1, mods) || skipIgnoredNodes(view, -1);
      }
      else if (code == 40 || (mac$3 && code == 78 && mods == "c")) { // Down arrow, Ctrl-n on Mac
          return safariDownArrowBug(view) || selectVertically(view, 1, mods) || skipIgnoredNodes(view, 1);
      }
      else if (mods == (mac$3 ? "m" : "c") &&
          (code == 66 || code == 73 || code == 89 || code == 90)) { // Mod-[biyz]
          return true;
      }
      return false;
  }

  function serializeForClipboard(view, slice) {
      view.someProp("transformCopied", f => { slice = f(slice, view); });
      let context = [], { content, openStart, openEnd } = slice;
      while (openStart > 1 && openEnd > 1 && content.childCount == 1 && content.firstChild.childCount == 1) {
          openStart--;
          openEnd--;
          let node = content.firstChild;
          context.push(node.type.name, node.attrs != node.type.defaultAttrs ? node.attrs : null);
          content = node.content;
      }
      let serializer = view.someProp("clipboardSerializer") || DOMSerializer.fromSchema(view.state.schema);
      let doc = detachedDoc(), wrap = doc.createElement("div");
      wrap.appendChild(serializer.serializeFragment(content, { document: doc }));
      let firstChild = wrap.firstChild, needsWrap, wrappers = 0;
      while (firstChild && firstChild.nodeType == 1 && (needsWrap = wrapMap[firstChild.nodeName.toLowerCase()])) {
          for (let i = needsWrap.length - 1; i >= 0; i--) {
              let wrapper = doc.createElement(needsWrap[i]);
              while (wrap.firstChild)
                  wrapper.appendChild(wrap.firstChild);
              wrap.appendChild(wrapper);
              wrappers++;
          }
          firstChild = wrap.firstChild;
      }
      if (firstChild && firstChild.nodeType == 1)
          firstChild.setAttribute("data-pm-slice", `${openStart} ${openEnd}${wrappers ? ` -${wrappers}` : ""} ${JSON.stringify(context)}`);
      let text = view.someProp("clipboardTextSerializer", f => f(slice, view)) ||
          slice.content.textBetween(0, slice.content.size, "\n\n");
      return { dom: wrap, text, slice };
  }
  // Read a slice of content from the clipboard (or drop data).
  function parseFromClipboard(view, text, html, plainText, $context) {
      let inCode = $context.parent.type.spec.code;
      let dom, slice;
      if (!html && !text)
          return null;
      let asText = !!text && (plainText || inCode || !html);
      if (asText) {
          view.someProp("transformPastedText", f => { text = f(text, inCode || plainText, view); });
          if (inCode) {
              slice = new Slice(Fragment.from(view.state.schema.text(text.replace(/\r\n?/g, "\n"))), 0, 0);
              view.someProp("transformPasted", f => { slice = f(slice, view, true); });
              return slice;
          }
          let parsed = view.someProp("clipboardTextParser", f => f(text, $context, plainText, view));
          if (parsed) {
              slice = parsed;
          }
          else {
              let marks = $context.marks();
              let { schema } = view.state, serializer = DOMSerializer.fromSchema(schema);
              dom = document.createElement("div");
              text.split(/(?:\r\n?|\n)+/).forEach(block => {
                  let p = dom.appendChild(document.createElement("p"));
                  if (block)
                      p.appendChild(serializer.serializeNode(schema.text(block, marks)));
              });
          }
      }
      else {
          view.someProp("transformPastedHTML", f => { html = f(html, view); });
          dom = readHTML(html);
          if (webkit)
              restoreReplacedSpaces(dom);
      }
      let contextNode = dom && dom.querySelector("[data-pm-slice]");
      let sliceData = contextNode && /^(\d+) (\d+)(?: -(\d+))? (.*)/.exec(contextNode.getAttribute("data-pm-slice") || "");
      if (sliceData && sliceData[3])
          for (let i = +sliceData[3]; i > 0; i--) {
              let child = dom.firstChild;
              while (child && child.nodeType != 1)
                  child = child.nextSibling;
              if (!child)
                  break;
              dom = child;
          }
      if (!slice) {
          let parser = view.someProp("clipboardParser") || view.someProp("domParser") || DOMParser.fromSchema(view.state.schema);
          slice = parser.parseSlice(dom, {
              preserveWhitespace: !!(asText || sliceData),
              context: $context,
              ruleFromNode(dom) {
                  if (dom.nodeName == "BR" && !dom.nextSibling &&
                      dom.parentNode && !inlineParents.test(dom.parentNode.nodeName))
                      return { ignore: true };
                  return null;
              }
          });
      }
      if (sliceData) {
          slice = addContext(closeSlice(slice, +sliceData[1], +sliceData[2]), sliceData[4]);
      }
      else { // HTML wasn't created by ProseMirror. Make sure top-level siblings are coherent
          slice = Slice.maxOpen(normalizeSiblings(slice.content, $context), true);
          if (slice.openStart || slice.openEnd) {
              let openStart = 0, openEnd = 0;
              for (let node = slice.content.firstChild; openStart < slice.openStart && !node.type.spec.isolating; openStart++, node = node.firstChild) { }
              for (let node = slice.content.lastChild; openEnd < slice.openEnd && !node.type.spec.isolating; openEnd++, node = node.lastChild) { }
              slice = closeSlice(slice, openStart, openEnd);
          }
      }
      view.someProp("transformPasted", f => { slice = f(slice, view, asText); });
      return slice;
  }
  const inlineParents = /^(a|abbr|acronym|b|cite|code|del|em|i|ins|kbd|label|output|q|ruby|s|samp|span|strong|sub|sup|time|u|tt|var)$/i;
  // Takes a slice parsed with parseSlice, which means there hasn't been
  // any content-expression checking done on the top nodes, tries to
  // find a parent node in the current context that might fit the nodes,
  // and if successful, rebuilds the slice so that it fits into that parent.
  //
  // This addresses the problem that Transform.replace expects a
  // coherent slice, and will fail to place a set of siblings that don't
  // fit anywhere in the schema.
  function normalizeSiblings(fragment, $context) {
      if (fragment.childCount < 2)
          return fragment;
      for (let d = $context.depth; d >= 0; d--) {
          let parent = $context.node(d);
          let match = parent.contentMatchAt($context.index(d));
          let lastWrap, result = [];
          fragment.forEach(node => {
              if (!result)
                  return;
              let wrap = match.findWrapping(node.type), inLast;
              if (!wrap)
                  return result = null;
              if (inLast = result.length && lastWrap.length && addToSibling(wrap, lastWrap, node, result[result.length - 1], 0)) {
                  result[result.length - 1] = inLast;
              }
              else {
                  if (result.length)
                      result[result.length - 1] = closeRight(result[result.length - 1], lastWrap.length);
                  let wrapped = withWrappers(node, wrap);
                  result.push(wrapped);
                  match = match.matchType(wrapped.type);
                  lastWrap = wrap;
              }
          });
          if (result)
              return Fragment.from(result);
      }
      return fragment;
  }
  function withWrappers(node, wrap, from = 0) {
      for (let i = wrap.length - 1; i >= from; i--)
          node = wrap[i].create(null, Fragment.from(node));
      return node;
  }
  // Used to group adjacent nodes wrapped in similar parents by
  // normalizeSiblings into the same parent node
  function addToSibling(wrap, lastWrap, node, sibling, depth) {
      if (depth < wrap.length && depth < lastWrap.length && wrap[depth] == lastWrap[depth]) {
          let inner = addToSibling(wrap, lastWrap, node, sibling.lastChild, depth + 1);
          if (inner)
              return sibling.copy(sibling.content.replaceChild(sibling.childCount - 1, inner));
          let match = sibling.contentMatchAt(sibling.childCount);
          if (match.matchType(depth == wrap.length - 1 ? node.type : wrap[depth + 1]))
              return sibling.copy(sibling.content.append(Fragment.from(withWrappers(node, wrap, depth + 1))));
      }
  }
  function closeRight(node, depth) {
      if (depth == 0)
          return node;
      let fragment = node.content.replaceChild(node.childCount - 1, closeRight(node.lastChild, depth - 1));
      let fill = node.contentMatchAt(node.childCount).fillBefore(Fragment.empty, true);
      return node.copy(fragment.append(fill));
  }
  function closeRange(fragment, side, from, to, depth, openEnd) {
      let node = side < 0 ? fragment.firstChild : fragment.lastChild, inner = node.content;
      if (fragment.childCount > 1)
          openEnd = 0;
      if (depth < to - 1)
          inner = closeRange(inner, side, from, to, depth + 1, openEnd);
      if (depth >= from)
          inner = side < 0 ? node.contentMatchAt(0).fillBefore(inner, openEnd <= depth).append(inner)
              : inner.append(node.contentMatchAt(node.childCount).fillBefore(Fragment.empty, true));
      return fragment.replaceChild(side < 0 ? 0 : fragment.childCount - 1, node.copy(inner));
  }
  function closeSlice(slice, openStart, openEnd) {
      if (openStart < slice.openStart)
          slice = new Slice(closeRange(slice.content, -1, openStart, slice.openStart, 0, slice.openEnd), openStart, slice.openEnd);
      if (openEnd < slice.openEnd)
          slice = new Slice(closeRange(slice.content, 1, openEnd, slice.openEnd, 0, 0), slice.openStart, openEnd);
      return slice;
  }
  // Trick from jQuery -- some elements must be wrapped in other
  // elements for innerHTML to work. I.e. if you do `div.innerHTML =
  // "<td>..</td>"` the table cells are ignored.
  const wrapMap = {
      thead: ["table"],
      tbody: ["table"],
      tfoot: ["table"],
      caption: ["table"],
      colgroup: ["table"],
      col: ["table", "colgroup"],
      tr: ["table", "tbody"],
      td: ["table", "tbody", "tr"],
      th: ["table", "tbody", "tr"]
  };
  let _detachedDoc = null;
  function detachedDoc() {
      return _detachedDoc || (_detachedDoc = document.implementation.createHTMLDocument("title"));
  }
  let _policy = null;
  function maybeWrapTrusted(html) {
      let trustedTypes = window.trustedTypes;
      if (!trustedTypes)
          return html;
      // With the require-trusted-types-for CSP, Chrome will block
      // innerHTML, even on a detached document. This wraps the string in
      // a way that makes the browser allow us to use its parser again.
      if (!_policy)
          _policy = trustedTypes.defaultPolicy || trustedTypes.createPolicy("ProseMirrorClipboard", { createHTML: (s) => s });
      return _policy.createHTML(html);
  }
  function readHTML(html) {
      let metas = /^(\s*<meta [^>]*>)*/.exec(html);
      if (metas)
          html = html.slice(metas[0].length);
      let elt = detachedDoc().createElement("div");
      let firstTag = /<([a-z][^>\s]+)/i.exec(html), wrap;
      if (wrap = firstTag && wrapMap[firstTag[1].toLowerCase()])
          html = wrap.map(n => "<" + n + ">").join("") + html + wrap.map(n => "</" + n + ">").reverse().join("");
      elt.innerHTML = maybeWrapTrusted(html);
      if (wrap)
          for (let i = 0; i < wrap.length; i++)
              elt = elt.querySelector(wrap[i]) || elt;
      return elt;
  }
  // Webkit browsers do some hard-to-predict replacement of regular
  // spaces with non-breaking spaces when putting content on the
  // clipboard. This tries to convert such non-breaking spaces (which
  // will be wrapped in a plain span on Chrome, a span with class
  // Apple-converted-space on Safari) back to regular spaces.
  function restoreReplacedSpaces(dom) {
      let nodes = dom.querySelectorAll(chrome ? "span:not([class]):not([style])" : "span.Apple-converted-space");
      for (let i = 0; i < nodes.length; i++) {
          let node = nodes[i];
          if (node.childNodes.length == 1 && node.textContent == "\u00a0" && node.parentNode)
              node.parentNode.replaceChild(dom.ownerDocument.createTextNode(" "), node);
      }
  }
  function addContext(slice, context) {
      if (!slice.size)
          return slice;
      let schema = slice.content.firstChild.type.schema, array;
      try {
          array = JSON.parse(context);
      }
      catch (e) {
          return slice;
      }
      let { content, openStart, openEnd } = slice;
      for (let i = array.length - 2; i >= 0; i -= 2) {
          let type = schema.nodes[array[i]];
          if (!type || type.hasRequiredAttrs())
              break;
          content = Fragment.from(type.create(array[i + 1], content));
          openStart++;
          openEnd++;
      }
      return new Slice(content, openStart, openEnd);
  }

  // A collection of DOM events that occur within the editor, and callback functions
  // to invoke when the event fires.
  const handlers = {};
  const editHandlers = {};
  const passiveHandlers = { touchstart: true, touchmove: true };
  class InputState {
      constructor() {
          this.shiftKey = false;
          this.mouseDown = null;
          this.lastKeyCode = null;
          this.lastKeyCodeTime = 0;
          this.lastClick = { time: 0, x: 0, y: 0, type: "", button: 0 };
          this.lastSelectionOrigin = null;
          this.lastSelectionTime = 0;
          this.lastIOSEnter = 0;
          this.lastIOSEnterFallbackTimeout = -1;
          this.lastFocus = 0;
          this.lastTouch = 0;
          this.lastChromeDelete = 0;
          this.composing = false;
          this.compositionNode = null;
          this.composingTimeout = -1;
          this.compositionNodes = [];
          this.compositionEndedAt = -2e8;
          this.compositionID = 1;
          // Set to a composition ID when there are pending changes at compositionend
          this.compositionPendingChanges = 0;
          this.domChangeCount = 0;
          this.eventHandlers = Object.create(null);
          this.hideSelectionGuard = null;
      }
  }
  function initInput(view) {
      for (let event in handlers) {
          let handler = handlers[event];
          view.dom.addEventListener(event, view.input.eventHandlers[event] = (event) => {
              if (eventBelongsToView(view, event) && !runCustomHandler(view, event) &&
                  (view.editable || !(event.type in editHandlers)))
                  handler(view, event);
          }, passiveHandlers[event] ? { passive: true } : undefined);
      }
      // On Safari, for reasons beyond my understanding, adding an input
      // event handler makes an issue where the composition vanishes when
      // you press enter go away.
      if (safari)
          view.dom.addEventListener("input", () => null);
      ensureListeners(view);
  }
  function setSelectionOrigin(view, origin) {
      view.input.lastSelectionOrigin = origin;
      view.input.lastSelectionTime = Date.now();
  }
  function destroyInput(view) {
      view.domObserver.stop();
      for (let type in view.input.eventHandlers)
          view.dom.removeEventListener(type, view.input.eventHandlers[type]);
      clearTimeout(view.input.composingTimeout);
      clearTimeout(view.input.lastIOSEnterFallbackTimeout);
  }
  function ensureListeners(view) {
      view.someProp("handleDOMEvents", currentHandlers => {
          for (let type in currentHandlers)
              if (!view.input.eventHandlers[type])
                  view.dom.addEventListener(type, view.input.eventHandlers[type] = event => runCustomHandler(view, event));
      });
  }
  function runCustomHandler(view, event) {
      return view.someProp("handleDOMEvents", handlers => {
          let handler = handlers[event.type];
          return handler ? handler(view, event) || event.defaultPrevented : false;
      });
  }
  function eventBelongsToView(view, event) {
      if (!event.bubbles)
          return true;
      if (event.defaultPrevented)
          return false;
      for (let node = event.target; node != view.dom; node = node.parentNode)
          if (!node || node.nodeType == 11 ||
              (node.pmViewDesc && node.pmViewDesc.stopEvent(event)))
              return false;
      return true;
  }
  function dispatchEvent(view, event) {
      if (!runCustomHandler(view, event) && handlers[event.type] &&
          (view.editable || !(event.type in editHandlers)))
          handlers[event.type](view, event);
  }
  editHandlers.keydown = (view, _event) => {
      let event = _event;
      view.input.shiftKey = event.keyCode == 16 || event.shiftKey;
      if (inOrNearComposition(view, event))
          return;
      view.input.lastKeyCode = event.keyCode;
      view.input.lastKeyCodeTime = Date.now();
      // Suppress enter key events on Chrome Android, because those tend
      // to be part of a confused sequence of composition events fired,
      // and handling them eagerly tends to corrupt the input.
      if (android && chrome && event.keyCode == 13)
          return;
      if (event.keyCode != 229)
          view.domObserver.forceFlush();
      // On iOS, if we preventDefault enter key presses, the virtual
      // keyboard gets confused. So the hack here is to set a flag that
      // makes the DOM change code recognize that what just happens should
      // be replaced by whatever the Enter key handlers do.
      if (ios && event.keyCode == 13 && !event.ctrlKey && !event.altKey && !event.metaKey) {
          let now = Date.now();
          view.input.lastIOSEnter = now;
          view.input.lastIOSEnterFallbackTimeout = setTimeout(() => {
              if (view.input.lastIOSEnter == now) {
                  view.someProp("handleKeyDown", f => f(view, keyEvent(13, "Enter")));
                  view.input.lastIOSEnter = 0;
              }
          }, 200);
      }
      else if (view.someProp("handleKeyDown", f => f(view, event)) || captureKeyDown(view, event)) {
          event.preventDefault();
      }
      else {
          setSelectionOrigin(view, "key");
      }
  };
  editHandlers.keyup = (view, event) => {
      if (event.keyCode == 16)
          view.input.shiftKey = false;
  };
  editHandlers.keypress = (view, _event) => {
      let event = _event;
      if (inOrNearComposition(view, event) || !event.charCode ||
          event.ctrlKey && !event.altKey || mac$3 && event.metaKey)
          return;
      if (view.someProp("handleKeyPress", f => f(view, event))) {
          event.preventDefault();
          return;
      }
      let sel = view.state.selection;
      if (!(sel instanceof TextSelection) || !sel.$from.sameParent(sel.$to)) {
          let text = String.fromCharCode(event.charCode);
          let deflt = () => view.state.tr.insertText(text).scrollIntoView();
          if (!/[\r\n]/.test(text) && !view.someProp("handleTextInput", f => f(view, sel.$from.pos, sel.$to.pos, text, deflt)))
              view.dispatch(deflt());
          event.preventDefault();
      }
  };
  function eventCoords(event) { return { left: event.clientX, top: event.clientY }; }
  function isNear(event, click) {
      let dx = click.x - event.clientX, dy = click.y - event.clientY;
      return dx * dx + dy * dy < 100;
  }
  function runHandlerOnContext(view, propName, pos, inside, event) {
      if (inside == -1)
          return false;
      let $pos = view.state.doc.resolve(inside);
      for (let i = $pos.depth + 1; i > 0; i--) {
          if (view.someProp(propName, f => i > $pos.depth ? f(view, pos, $pos.nodeAfter, $pos.before(i), event, true)
              : f(view, pos, $pos.node(i), $pos.before(i), event, false)))
              return true;
      }
      return false;
  }
  function updateSelection(view, selection, origin) {
      if (!view.focused)
          view.focus();
      if (view.state.selection.eq(selection))
          return;
      let tr = view.state.tr.setSelection(selection);
      tr.setMeta("pointer", true);
      view.dispatch(tr);
  }
  function selectClickedLeaf(view, inside) {
      if (inside == -1)
          return false;
      let $pos = view.state.doc.resolve(inside), node = $pos.nodeAfter;
      if (node && node.isAtom && NodeSelection.isSelectable(node)) {
          updateSelection(view, new NodeSelection($pos));
          return true;
      }
      return false;
  }
  function selectClickedNode(view, inside) {
      if (inside == -1)
          return false;
      let sel = view.state.selection, selectedNode, selectAt;
      if (sel instanceof NodeSelection)
          selectedNode = sel.node;
      let $pos = view.state.doc.resolve(inside);
      for (let i = $pos.depth + 1; i > 0; i--) {
          let node = i > $pos.depth ? $pos.nodeAfter : $pos.node(i);
          if (NodeSelection.isSelectable(node)) {
              if (selectedNode && sel.$from.depth > 0 &&
                  i >= sel.$from.depth && $pos.before(sel.$from.depth + 1) == sel.$from.pos)
                  selectAt = $pos.before(sel.$from.depth);
              else
                  selectAt = $pos.before(i);
              break;
          }
      }
      if (selectAt != null) {
          updateSelection(view, NodeSelection.create(view.state.doc, selectAt));
          return true;
      }
      else {
          return false;
      }
  }
  function handleSingleClick(view, pos, inside, event, selectNode) {
      return runHandlerOnContext(view, "handleClickOn", pos, inside, event) ||
          view.someProp("handleClick", f => f(view, pos, event)) ||
          (selectNode ? selectClickedNode(view, inside) : selectClickedLeaf(view, inside));
  }
  function handleDoubleClick(view, pos, inside, event) {
      return runHandlerOnContext(view, "handleDoubleClickOn", pos, inside, event) ||
          view.someProp("handleDoubleClick", f => f(view, pos, event));
  }
  function handleTripleClick(view, pos, inside, event) {
      return runHandlerOnContext(view, "handleTripleClickOn", pos, inside, event) ||
          view.someProp("handleTripleClick", f => f(view, pos, event)) ||
          defaultTripleClick(view, inside, event);
  }
  function defaultTripleClick(view, inside, event) {
      if (event.button != 0)
          return false;
      let doc = view.state.doc;
      if (inside == -1) {
          if (doc.inlineContent) {
              updateSelection(view, TextSelection.create(doc, 0, doc.content.size));
              return true;
          }
          return false;
      }
      let $pos = doc.resolve(inside);
      for (let i = $pos.depth + 1; i > 0; i--) {
          let node = i > $pos.depth ? $pos.nodeAfter : $pos.node(i);
          let nodePos = $pos.before(i);
          if (node.inlineContent)
              updateSelection(view, TextSelection.create(doc, nodePos + 1, nodePos + 1 + node.content.size));
          else if (NodeSelection.isSelectable(node))
              updateSelection(view, NodeSelection.create(doc, nodePos));
          else
              continue;
          return true;
      }
  }
  function forceDOMFlush(view) {
      return endComposition(view);
  }
  const selectNodeModifier = mac$3 ? "metaKey" : "ctrlKey";
  handlers.mousedown = (view, _event) => {
      let event = _event;
      view.input.shiftKey = event.shiftKey;
      let flushed = forceDOMFlush(view);
      let now = Date.now(), type = "singleClick";
      if (now - view.input.lastClick.time < 500 && isNear(event, view.input.lastClick) && !event[selectNodeModifier] &&
          view.input.lastClick.button == event.button) {
          if (view.input.lastClick.type == "singleClick")
              type = "doubleClick";
          else if (view.input.lastClick.type == "doubleClick")
              type = "tripleClick";
      }
      view.input.lastClick = { time: now, x: event.clientX, y: event.clientY, type, button: event.button };
      let pos = view.posAtCoords(eventCoords(event));
      if (!pos)
          return;
      if (type == "singleClick") {
          if (view.input.mouseDown)
              view.input.mouseDown.done();
          view.input.mouseDown = new MouseDown(view, pos, event, !!flushed);
      }
      else if ((type == "doubleClick" ? handleDoubleClick : handleTripleClick)(view, pos.pos, pos.inside, event)) {
          event.preventDefault();
      }
      else {
          setSelectionOrigin(view, "pointer");
      }
  };
  class MouseDown {
      constructor(view, pos, event, flushed) {
          this.view = view;
          this.pos = pos;
          this.event = event;
          this.flushed = flushed;
          this.delayedSelectionSync = false;
          this.mightDrag = null;
          this.startDoc = view.state.doc;
          this.selectNode = !!event[selectNodeModifier];
          this.allowDefault = event.shiftKey;
          let targetNode, targetPos;
          if (pos.inside > -1) {
              targetNode = view.state.doc.nodeAt(pos.inside);
              targetPos = pos.inside;
          }
          else {
              let $pos = view.state.doc.resolve(pos.pos);
              targetNode = $pos.parent;
              targetPos = $pos.depth ? $pos.before() : 0;
          }
          const target = flushed ? null : event.target;
          const targetDesc = target ? view.docView.nearestDesc(target, true) : null;
          this.target = targetDesc && targetDesc.nodeDOM.nodeType == 1 ? targetDesc.nodeDOM : null;
          let { selection } = view.state;
          if (event.button == 0 &&
              targetNode.type.spec.draggable && targetNode.type.spec.selectable !== false ||
              selection instanceof NodeSelection && selection.from <= targetPos && selection.to > targetPos)
              this.mightDrag = {
                  node: targetNode,
                  pos: targetPos,
                  addAttr: !!(this.target && !this.target.draggable),
                  setUneditable: !!(this.target && gecko && !this.target.hasAttribute("contentEditable"))
              };
          if (this.target && this.mightDrag && (this.mightDrag.addAttr || this.mightDrag.setUneditable)) {
              this.view.domObserver.stop();
              if (this.mightDrag.addAttr)
                  this.target.draggable = true;
              if (this.mightDrag.setUneditable)
                  setTimeout(() => {
                      if (this.view.input.mouseDown == this)
                          this.target.setAttribute("contentEditable", "false");
                  }, 20);
              this.view.domObserver.start();
          }
          view.root.addEventListener("mouseup", this.up = this.up.bind(this));
          view.root.addEventListener("mousemove", this.move = this.move.bind(this));
          setSelectionOrigin(view, "pointer");
      }
      done() {
          this.view.root.removeEventListener("mouseup", this.up);
          this.view.root.removeEventListener("mousemove", this.move);
          if (this.mightDrag && this.target) {
              this.view.domObserver.stop();
              if (this.mightDrag.addAttr)
                  this.target.removeAttribute("draggable");
              if (this.mightDrag.setUneditable)
                  this.target.removeAttribute("contentEditable");
              this.view.domObserver.start();
          }
          if (this.delayedSelectionSync)
              setTimeout(() => selectionToDOM(this.view));
          this.view.input.mouseDown = null;
      }
      up(event) {
          this.done();
          if (!this.view.dom.contains(event.target))
              return;
          let pos = this.pos;
          if (this.view.state.doc != this.startDoc)
              pos = this.view.posAtCoords(eventCoords(event));
          this.updateAllowDefault(event);
          if (this.allowDefault || !pos) {
              setSelectionOrigin(this.view, "pointer");
          }
          else if (handleSingleClick(this.view, pos.pos, pos.inside, event, this.selectNode)) {
              event.preventDefault();
          }
          else if (event.button == 0 &&
              (this.flushed ||
                  // Safari ignores clicks on draggable elements
                  (safari && this.mightDrag && !this.mightDrag.node.isAtom) ||
                  // Chrome will sometimes treat a node selection as a
                  // cursor, but still report that the node is selected
                  // when asked through getSelection. You'll then get a
                  // situation where clicking at the point where that
                  // (hidden) cursor is doesn't change the selection, and
                  // thus doesn't get a reaction from ProseMirror. This
                  // works around that.
                  (chrome && !this.view.state.selection.visible &&
                      Math.min(Math.abs(pos.pos - this.view.state.selection.from), Math.abs(pos.pos - this.view.state.selection.to)) <= 2))) {
              updateSelection(this.view, Selection.near(this.view.state.doc.resolve(pos.pos)));
              event.preventDefault();
          }
          else {
              setSelectionOrigin(this.view, "pointer");
          }
      }
      move(event) {
          this.updateAllowDefault(event);
          setSelectionOrigin(this.view, "pointer");
          if (event.buttons == 0)
              this.done();
      }
      updateAllowDefault(event) {
          if (!this.allowDefault && (Math.abs(this.event.x - event.clientX) > 4 ||
              Math.abs(this.event.y - event.clientY) > 4))
              this.allowDefault = true;
      }
  }
  handlers.touchstart = view => {
      view.input.lastTouch = Date.now();
      forceDOMFlush(view);
      setSelectionOrigin(view, "pointer");
  };
  handlers.touchmove = view => {
      view.input.lastTouch = Date.now();
      setSelectionOrigin(view, "pointer");
  };
  handlers.contextmenu = view => forceDOMFlush(view);
  function inOrNearComposition(view, event) {
      if (view.composing)
          return true;
      // See https://www.stum.de/2016/06/24/handling-ime-events-in-javascript/.
      // On Japanese input method editors (IMEs), the Enter key is used to confirm character
      // selection. On Safari, when Enter is pressed, compositionend and keydown events are
      // emitted. The keydown event triggers newline insertion, which we don't want.
      // This method returns true if the keydown event should be ignored.
      // We only ignore it once, as pressing Enter a second time *should* insert a newline.
      // Furthermore, the keydown event timestamp must be close to the compositionEndedAt timestamp.
      // This guards against the case where compositionend is triggered without the keyboard
      // (e.g. character confirmation may be done with the mouse), and keydown is triggered
      // afterwards- we wouldn't want to ignore the keydown event in this case.
      if (safari && Math.abs(event.timeStamp - view.input.compositionEndedAt) < 500) {
          view.input.compositionEndedAt = -2e8;
          return true;
      }
      return false;
  }
  // Drop active composition after 5 seconds of inactivity on Android
  const timeoutComposition = android ? 5000 : -1;
  editHandlers.compositionstart = editHandlers.compositionupdate = view => {
      if (!view.composing) {
          view.domObserver.flush();
          let { state } = view, $pos = state.selection.$to;
          if (state.selection instanceof TextSelection &&
              (state.storedMarks ||
                  (!$pos.textOffset && $pos.parentOffset && $pos.nodeBefore.marks.some(m => m.type.spec.inclusive === false)))) {
              // Need to wrap the cursor in mark nodes different from the ones in the DOM context
              view.markCursor = view.state.storedMarks || $pos.marks();
              endComposition(view, true);
              view.markCursor = null;
          }
          else {
              endComposition(view, !state.selection.empty);
              // In firefox, if the cursor is after but outside a marked node,
              // the inserted text won't inherit the marks. So this moves it
              // inside if necessary.
              if (gecko && state.selection.empty && $pos.parentOffset && !$pos.textOffset && $pos.nodeBefore.marks.length) {
                  let sel = view.domSelectionRange();
                  for (let node = sel.focusNode, offset = sel.focusOffset; node && node.nodeType == 1 && offset != 0;) {
                      let before = offset < 0 ? node.lastChild : node.childNodes[offset - 1];
                      if (!before)
                          break;
                      if (before.nodeType == 3) {
                          let sel = view.domSelection();
                          if (sel)
                              sel.collapse(before, before.nodeValue.length);
                          break;
                      }
                      else {
                          node = before;
                          offset = -1;
                      }
                  }
              }
          }
          view.input.composing = true;
      }
      scheduleComposeEnd(view, timeoutComposition);
  };
  editHandlers.compositionend = (view, event) => {
      if (view.composing) {
          view.input.composing = false;
          view.input.compositionEndedAt = event.timeStamp;
          view.input.compositionPendingChanges = view.domObserver.pendingRecords().length ? view.input.compositionID : 0;
          view.input.compositionNode = null;
          if (view.input.compositionPendingChanges)
              Promise.resolve().then(() => view.domObserver.flush());
          view.input.compositionID++;
          scheduleComposeEnd(view, 20);
      }
  };
  function scheduleComposeEnd(view, delay) {
      clearTimeout(view.input.composingTimeout);
      if (delay > -1)
          view.input.composingTimeout = setTimeout(() => endComposition(view), delay);
  }
  function clearComposition(view) {
      if (view.composing) {
          view.input.composing = false;
          view.input.compositionEndedAt = timestampFromCustomEvent();
      }
      while (view.input.compositionNodes.length > 0)
          view.input.compositionNodes.pop().markParentsDirty();
  }
  function findCompositionNode(view) {
      let sel = view.domSelectionRange();
      if (!sel.focusNode)
          return null;
      let textBefore = textNodeBefore$1(sel.focusNode, sel.focusOffset);
      let textAfter = textNodeAfter$1(sel.focusNode, sel.focusOffset);
      if (textBefore && textAfter && textBefore != textAfter) {
          let descAfter = textAfter.pmViewDesc, lastChanged = view.domObserver.lastChangedTextNode;
          if (textBefore == lastChanged || textAfter == lastChanged)
              return lastChanged;
          if (!descAfter || !descAfter.isText(textAfter.nodeValue)) {
              return textAfter;
          }
          else if (view.input.compositionNode == textAfter) {
              let descBefore = textBefore.pmViewDesc;
              if (!(!descBefore || !descBefore.isText(textBefore.nodeValue)))
                  return textAfter;
          }
      }
      return textBefore || textAfter;
  }
  function timestampFromCustomEvent() {
      let event = document.createEvent("Event");
      event.initEvent("event", true, true);
      return event.timeStamp;
  }
  /**
  @internal
  */
  function endComposition(view, restarting = false) {
      if (android && view.domObserver.flushingSoon >= 0)
          return;
      view.domObserver.forceFlush();
      clearComposition(view);
      if (restarting || view.docView && view.docView.dirty) {
          let sel = selectionFromDOM(view), cur = view.state.selection;
          if (sel && !sel.eq(cur))
              view.dispatch(view.state.tr.setSelection(sel));
          else if ((view.markCursor || restarting) && !cur.$from.node(cur.$from.sharedDepth(cur.to)).inlineContent)
              view.dispatch(view.state.tr.deleteSelection());
          else
              view.updateState(view.state);
          return true;
      }
      return false;
  }
  function captureCopy(view, dom) {
      // The extra wrapper is somehow necessary on IE/Edge to prevent the
      // content from being mangled when it is put onto the clipboard
      if (!view.dom.parentNode)
          return;
      let wrap = view.dom.parentNode.appendChild(document.createElement("div"));
      wrap.appendChild(dom);
      wrap.style.cssText = "position: fixed; left: -10000px; top: 10px";
      let sel = getSelection(), range = document.createRange();
      range.selectNodeContents(dom);
      // Done because IE will fire a selectionchange moving the selection
      // to its start when removeAllRanges is called and the editor still
      // has focus (which will mess up the editor's selection state).
      view.dom.blur();
      sel.removeAllRanges();
      sel.addRange(range);
      setTimeout(() => {
          if (wrap.parentNode)
              wrap.parentNode.removeChild(wrap);
          view.focus();
      }, 50);
  }
  // This is very crude, but unfortunately both these browsers _pretend_
  // that they have a clipboard API—all the objects and methods are
  // there, they just don't work, and they are hard to test.
  const brokenClipboardAPI = (ie$1 && ie_version < 15) ||
      (ios && webkit_version < 604);
  handlers.copy = editHandlers.cut = (view, _event) => {
      let event = _event;
      let sel = view.state.selection, cut = event.type == "cut";
      if (sel.empty)
          return;
      // IE and Edge's clipboard interface is completely broken
      let data = brokenClipboardAPI ? null : event.clipboardData;
      let slice = sel.content(), { dom, text } = serializeForClipboard(view, slice);
      if (data) {
          event.preventDefault();
          data.clearData();
          data.setData("text/html", dom.innerHTML);
          data.setData("text/plain", text);
      }
      else {
          captureCopy(view, dom);
      }
      if (cut)
          view.dispatch(view.state.tr.deleteSelection().scrollIntoView().setMeta("uiEvent", "cut"));
  };
  function sliceSingleNode(slice) {
      return slice.openStart == 0 && slice.openEnd == 0 && slice.content.childCount == 1 ? slice.content.firstChild : null;
  }
  function capturePaste(view, event) {
      if (!view.dom.parentNode)
          return;
      let plainText = view.input.shiftKey || view.state.selection.$from.parent.type.spec.code;
      let target = view.dom.parentNode.appendChild(document.createElement(plainText ? "textarea" : "div"));
      if (!plainText)
          target.contentEditable = "true";
      target.style.cssText = "position: fixed; left: -10000px; top: 10px";
      target.focus();
      let plain = view.input.shiftKey && view.input.lastKeyCode != 45;
      setTimeout(() => {
          view.focus();
          if (target.parentNode)
              target.parentNode.removeChild(target);
          if (plainText)
              doPaste(view, target.value, null, plain, event);
          else
              doPaste(view, target.textContent, target.innerHTML, plain, event);
      }, 50);
  }
  function doPaste(view, text, html, preferPlain, event) {
      let slice = parseFromClipboard(view, text, html, preferPlain, view.state.selection.$from);
      if (view.someProp("handlePaste", f => f(view, event, slice || Slice.empty)))
          return true;
      if (!slice)
          return false;
      let singleNode = sliceSingleNode(slice);
      let tr = singleNode
          ? view.state.tr.replaceSelectionWith(singleNode, preferPlain)
          : view.state.tr.replaceSelection(slice);
      view.dispatch(tr.scrollIntoView().setMeta("paste", true).setMeta("uiEvent", "paste"));
      return true;
  }
  function getText(clipboardData) {
      let text = clipboardData.getData("text/plain") || clipboardData.getData("Text");
      if (text)
          return text;
      let uris = clipboardData.getData("text/uri-list");
      return uris ? uris.replace(/\r?\n/g, " ") : "";
  }
  editHandlers.paste = (view, _event) => {
      let event = _event;
      // Handling paste from JavaScript during composition is very poorly
      // handled by browsers, so as a dodgy but preferable kludge, we just
      // let the browser do its native thing there, except on Android,
      // where the editor is almost always composing.
      if (view.composing && !android)
          return;
      let data = brokenClipboardAPI ? null : event.clipboardData;
      let plain = view.input.shiftKey && view.input.lastKeyCode != 45;
      if (data && doPaste(view, getText(data), data.getData("text/html"), plain, event))
          event.preventDefault();
      else
          capturePaste(view, event);
  };
  class Dragging {
      constructor(slice, move, node) {
          this.slice = slice;
          this.move = move;
          this.node = node;
      }
  }
  const dragCopyModifier = mac$3 ? "altKey" : "ctrlKey";
  function dragMoves(view, event) {
      let moves = view.someProp("dragCopies", test => !test(event));
      return moves != null ? moves : !event[dragCopyModifier];
  }
  handlers.dragstart = (view, _event) => {
      let event = _event;
      let mouseDown = view.input.mouseDown;
      if (mouseDown)
          mouseDown.done();
      if (!event.dataTransfer)
          return;
      let sel = view.state.selection;
      let pos = sel.empty ? null : view.posAtCoords(eventCoords(event));
      let node;
      if (pos && pos.pos >= sel.from && pos.pos <= (sel instanceof NodeSelection ? sel.to - 1 : sel.to)) ;
      else if (mouseDown && mouseDown.mightDrag) {
          node = NodeSelection.create(view.state.doc, mouseDown.mightDrag.pos);
      }
      else if (event.target && event.target.nodeType == 1) {
          let desc = view.docView.nearestDesc(event.target, true);
          if (desc && desc.node.type.spec.draggable && desc != view.docView)
              node = NodeSelection.create(view.state.doc, desc.posBefore);
      }
      let draggedSlice = (node || view.state.selection).content();
      let { dom, text, slice } = serializeForClipboard(view, draggedSlice);
      // Pre-120 Chrome versions clear files when calling `clearData` (#1472)
      if (!event.dataTransfer.files.length || !chrome || chrome_version > 120)
          event.dataTransfer.clearData();
      event.dataTransfer.setData(brokenClipboardAPI ? "Text" : "text/html", dom.innerHTML);
      // See https://github.com/ProseMirror/prosemirror/issues/1156
      event.dataTransfer.effectAllowed = "copyMove";
      if (!brokenClipboardAPI)
          event.dataTransfer.setData("text/plain", text);
      view.dragging = new Dragging(slice, dragMoves(view, event), node);
  };
  handlers.dragend = view => {
      let dragging = view.dragging;
      window.setTimeout(() => {
          if (view.dragging == dragging)
              view.dragging = null;
      }, 50);
  };
  editHandlers.dragover = editHandlers.dragenter = (_, e) => e.preventDefault();
  editHandlers.drop = (view, _event) => {
      let event = _event;
      let dragging = view.dragging;
      view.dragging = null;
      if (!event.dataTransfer)
          return;
      let eventPos = view.posAtCoords(eventCoords(event));
      if (!eventPos)
          return;
      let $mouse = view.state.doc.resolve(eventPos.pos);
      let slice = dragging && dragging.slice;
      if (slice) {
          view.someProp("transformPasted", f => { slice = f(slice, view, false); });
      }
      else {
          slice = parseFromClipboard(view, getText(event.dataTransfer), brokenClipboardAPI ? null : event.dataTransfer.getData("text/html"), false, $mouse);
      }
      let move = !!(dragging && dragMoves(view, event));
      if (view.someProp("handleDrop", f => f(view, event, slice || Slice.empty, move))) {
          event.preventDefault();
          return;
      }
      if (!slice)
          return;
      event.preventDefault();
      let insertPos = slice ? dropPoint(view.state.doc, $mouse.pos, slice) : $mouse.pos;
      if (insertPos == null)
          insertPos = $mouse.pos;
      let tr = view.state.tr;
      if (move) {
          let { node } = dragging;
          if (node)
              node.replace(tr);
          else
              tr.deleteSelection();
      }
      let pos = tr.mapping.map(insertPos);
      let isNode = slice.openStart == 0 && slice.openEnd == 0 && slice.content.childCount == 1;
      let beforeInsert = tr.doc;
      if (isNode)
          tr.replaceRangeWith(pos, pos, slice.content.firstChild);
      else
          tr.replaceRange(pos, pos, slice);
      if (tr.doc.eq(beforeInsert))
          return;
      let $pos = tr.doc.resolve(pos);
      if (isNode && NodeSelection.isSelectable(slice.content.firstChild) &&
          $pos.nodeAfter && $pos.nodeAfter.sameMarkup(slice.content.firstChild)) {
          tr.setSelection(new NodeSelection($pos));
      }
      else {
          let end = tr.mapping.map(insertPos);
          tr.mapping.maps[tr.mapping.maps.length - 1].forEach((_from, _to, _newFrom, newTo) => end = newTo);
          tr.setSelection(selectionBetween(view, $pos, tr.doc.resolve(end)));
      }
      view.focus();
      view.dispatch(tr.setMeta("uiEvent", "drop"));
  };
  handlers.focus = view => {
      view.input.lastFocus = Date.now();
      if (!view.focused) {
          view.domObserver.stop();
          view.dom.classList.add("ProseMirror-focused");
          view.domObserver.start();
          view.focused = true;
          setTimeout(() => {
              if (view.docView && view.hasFocus() && !view.domObserver.currentSelection.eq(view.domSelectionRange()))
                  selectionToDOM(view);
          }, 20);
      }
  };
  handlers.blur = (view, _event) => {
      let event = _event;
      if (view.focused) {
          view.domObserver.stop();
          view.dom.classList.remove("ProseMirror-focused");
          view.domObserver.start();
          if (event.relatedTarget && view.dom.contains(event.relatedTarget))
              view.domObserver.currentSelection.clear();
          view.focused = false;
      }
  };
  handlers.beforeinput = (view, _event) => {
      let event = _event;
      // We should probably do more with beforeinput events, but support
      // is so spotty that I'm still waiting to see where they are going.
      // Very specific hack to deal with backspace sometimes failing on
      // Chrome Android when after an uneditable node.
      if (chrome && android && event.inputType == "deleteContentBackward") {
          view.domObserver.flushSoon();
          let { domChangeCount } = view.input;
          setTimeout(() => {
              if (view.input.domChangeCount != domChangeCount)
                  return; // Event already had some effect
              // This bug tends to close the virtual keyboard, so we refocus
              view.dom.blur();
              view.focus();
              if (view.someProp("handleKeyDown", f => f(view, keyEvent(8, "Backspace"))))
                  return;
              let { $cursor } = view.state.selection;
              // Crude approximation of backspace behavior when no command handled it
              if ($cursor && $cursor.pos > 0)
                  view.dispatch(view.state.tr.delete($cursor.pos - 1, $cursor.pos).scrollIntoView());
          }, 50);
      }
  };
  // Make sure all handlers get registered
  for (let prop in editHandlers)
      handlers[prop] = editHandlers[prop];

  function compareObjs(a, b) {
      if (a == b)
          return true;
      for (let p in a)
          if (a[p] !== b[p])
              return false;
      for (let p in b)
          if (!(p in a))
              return false;
      return true;
  }
  class WidgetType {
      constructor(toDOM, spec) {
          this.toDOM = toDOM;
          this.spec = spec || noSpec;
          this.side = this.spec.side || 0;
      }
      map(mapping, span, offset, oldOffset) {
          let { pos, deleted } = mapping.mapResult(span.from + oldOffset, this.side < 0 ? -1 : 1);
          return deleted ? null : new Decoration(pos - offset, pos - offset, this);
      }
      valid() { return true; }
      eq(other) {
          return this == other ||
              (other instanceof WidgetType &&
                  (this.spec.key && this.spec.key == other.spec.key ||
                      this.toDOM == other.toDOM && compareObjs(this.spec, other.spec)));
      }
      destroy(node) {
          if (this.spec.destroy)
              this.spec.destroy(node);
      }
  }
  class InlineType {
      constructor(attrs, spec) {
          this.attrs = attrs;
          this.spec = spec || noSpec;
      }
      map(mapping, span, offset, oldOffset) {
          let from = mapping.map(span.from + oldOffset, this.spec.inclusiveStart ? -1 : 1) - offset;
          let to = mapping.map(span.to + oldOffset, this.spec.inclusiveEnd ? 1 : -1) - offset;
          return from >= to ? null : new Decoration(from, to, this);
      }
      valid(_, span) { return span.from < span.to; }
      eq(other) {
          return this == other ||
              (other instanceof InlineType && compareObjs(this.attrs, other.attrs) &&
                  compareObjs(this.spec, other.spec));
      }
      static is(span) { return span.type instanceof InlineType; }
      destroy() { }
  }
  class NodeType {
      constructor(attrs, spec) {
          this.attrs = attrs;
          this.spec = spec || noSpec;
      }
      map(mapping, span, offset, oldOffset) {
          let from = mapping.mapResult(span.from + oldOffset, 1);
          if (from.deleted)
              return null;
          let to = mapping.mapResult(span.to + oldOffset, -1);
          if (to.deleted || to.pos <= from.pos)
              return null;
          return new Decoration(from.pos - offset, to.pos - offset, this);
      }
      valid(node, span) {
          let { index, offset } = node.content.findIndex(span.from), child;
          return offset == span.from && !(child = node.child(index)).isText && offset + child.nodeSize == span.to;
      }
      eq(other) {
          return this == other ||
              (other instanceof NodeType && compareObjs(this.attrs, other.attrs) &&
                  compareObjs(this.spec, other.spec));
      }
      destroy() { }
  }
  /**
  Decoration objects can be provided to the view through the
  [`decorations` prop](https://prosemirror.net/docs/ref/#view.EditorProps.decorations). They come in
  several variants—see the static members of this class for details.
  */
  class Decoration {
      /**
      @internal
      */
      constructor(
      /**
      The start position of the decoration.
      */
      from, 
      /**
      The end position. Will be the same as `from` for [widget
      decorations](https://prosemirror.net/docs/ref/#view.Decoration^widget).
      */
      to, 
      /**
      @internal
      */
      type) {
          this.from = from;
          this.to = to;
          this.type = type;
      }
      /**
      @internal
      */
      copy(from, to) {
          return new Decoration(from, to, this.type);
      }
      /**
      @internal
      */
      eq(other, offset = 0) {
          return this.type.eq(other.type) && this.from + offset == other.from && this.to + offset == other.to;
      }
      /**
      @internal
      */
      map(mapping, offset, oldOffset) {
          return this.type.map(mapping, this, offset, oldOffset);
      }
      /**
      Creates a widget decoration, which is a DOM node that's shown in
      the document at the given position. It is recommended that you
      delay rendering the widget by passing a function that will be
      called when the widget is actually drawn in a view, but you can
      also directly pass a DOM node. `getPos` can be used to find the
      widget's current document position.
      */
      static widget(pos, toDOM, spec) {
          return new Decoration(pos, pos, new WidgetType(toDOM, spec));
      }
      /**
      Creates an inline decoration, which adds the given attributes to
      each inline node between `from` and `to`.
      */
      static inline(from, to, attrs, spec) {
          return new Decoration(from, to, new InlineType(attrs, spec));
      }
      /**
      Creates a node decoration. `from` and `to` should point precisely
      before and after a node in the document. That node, and only that
      node, will receive the given attributes.
      */
      static node(from, to, attrs, spec) {
          return new Decoration(from, to, new NodeType(attrs, spec));
      }
      /**
      The spec provided when creating this decoration. Can be useful
      if you've stored extra information in that object.
      */
      get spec() { return this.type.spec; }
      /**
      @internal
      */
      get inline() { return this.type instanceof InlineType; }
      /**
      @internal
      */
      get widget() { return this.type instanceof WidgetType; }
  }
  const none = [], noSpec = {};
  /**
  A collection of [decorations](https://prosemirror.net/docs/ref/#view.Decoration), organized in such
  a way that the drawing algorithm can efficiently use and compare
  them. This is a persistent data structure—it is not modified,
  updates create a new value.
  */
  class DecorationSet {
      /**
      @internal
      */
      constructor(local, children) {
          this.local = local.length ? local : none;
          this.children = children.length ? children : none;
      }
      /**
      Create a set of decorations, using the structure of the given
      document. This will consume (modify) the `decorations` array, so
      you must make a copy if you want need to preserve that.
      */
      static create(doc, decorations) {
          return decorations.length ? buildTree(decorations, doc, 0, noSpec) : empty;
      }
      /**
      Find all decorations in this set which touch the given range
      (including decorations that start or end directly at the
      boundaries) and match the given predicate on their spec. When
      `start` and `end` are omitted, all decorations in the set are
      considered. When `predicate` isn't given, all decorations are
      assumed to match.
      */
      find(start, end, predicate) {
          let result = [];
          this.findInner(start == null ? 0 : start, end == null ? 1e9 : end, result, 0, predicate);
          return result;
      }
      findInner(start, end, result, offset, predicate) {
          for (let i = 0; i < this.local.length; i++) {
              let span = this.local[i];
              if (span.from <= end && span.to >= start && (!predicate || predicate(span.spec)))
                  result.push(span.copy(span.from + offset, span.to + offset));
          }
          for (let i = 0; i < this.children.length; i += 3) {
              if (this.children[i] < end && this.children[i + 1] > start) {
                  let childOff = this.children[i] + 1;
                  this.children[i + 2].findInner(start - childOff, end - childOff, result, offset + childOff, predicate);
              }
          }
      }
      /**
      Map the set of decorations in response to a change in the
      document.
      */
      map(mapping, doc, options) {
          if (this == empty || mapping.maps.length == 0)
              return this;
          return this.mapInner(mapping, doc, 0, 0, options || noSpec);
      }
      /**
      @internal
      */
      mapInner(mapping, node, offset, oldOffset, options) {
          let newLocal;
          for (let i = 0; i < this.local.length; i++) {
              let mapped = this.local[i].map(mapping, offset, oldOffset);
              if (mapped && mapped.type.valid(node, mapped))
                  (newLocal || (newLocal = [])).push(mapped);
              else if (options.onRemove)
                  options.onRemove(this.local[i].spec);
          }
          if (this.children.length)
              return mapChildren(this.children, newLocal || [], mapping, node, offset, oldOffset, options);
          else
              return newLocal ? new DecorationSet(newLocal.sort(byPos), none) : empty;
      }
      /**
      Add the given array of decorations to the ones in the set,
      producing a new set. Consumes the `decorations` array. Needs
      access to the current document to create the appropriate tree
      structure.
      */
      add(doc, decorations) {
          if (!decorations.length)
              return this;
          if (this == empty)
              return DecorationSet.create(doc, decorations);
          return this.addInner(doc, decorations, 0);
      }
      addInner(doc, decorations, offset) {
          let children, childIndex = 0;
          doc.forEach((childNode, childOffset) => {
              let baseOffset = childOffset + offset, found;
              if (!(found = takeSpansForNode(decorations, childNode, baseOffset)))
                  return;
              if (!children)
                  children = this.children.slice();
              while (childIndex < children.length && children[childIndex] < childOffset)
                  childIndex += 3;
              if (children[childIndex] == childOffset)
                  children[childIndex + 2] = children[childIndex + 2].addInner(childNode, found, baseOffset + 1);
              else
                  children.splice(childIndex, 0, childOffset, childOffset + childNode.nodeSize, buildTree(found, childNode, baseOffset + 1, noSpec));
              childIndex += 3;
          });
          let local = moveSpans(childIndex ? withoutNulls(decorations) : decorations, -offset);
          for (let i = 0; i < local.length; i++)
              if (!local[i].type.valid(doc, local[i]))
                  local.splice(i--, 1);
          return new DecorationSet(local.length ? this.local.concat(local).sort(byPos) : this.local, children || this.children);
      }
      /**
      Create a new set that contains the decorations in this set, minus
      the ones in the given array.
      */
      remove(decorations) {
          if (decorations.length == 0 || this == empty)
              return this;
          return this.removeInner(decorations, 0);
      }
      removeInner(decorations, offset) {
          let children = this.children, local = this.local;
          for (let i = 0; i < children.length; i += 3) {
              let found;
              let from = children[i] + offset, to = children[i + 1] + offset;
              for (let j = 0, span; j < decorations.length; j++)
                  if (span = decorations[j]) {
                      if (span.from > from && span.to < to) {
                          decorations[j] = null;
                          (found || (found = [])).push(span);
                      }
                  }
              if (!found)
                  continue;
              if (children == this.children)
                  children = this.children.slice();
              let removed = children[i + 2].removeInner(found, from + 1);
              if (removed != empty) {
                  children[i + 2] = removed;
              }
              else {
                  children.splice(i, 3);
                  i -= 3;
              }
          }
          if (local.length)
              for (let i = 0, span; i < decorations.length; i++)
                  if (span = decorations[i]) {
                      for (let j = 0; j < local.length; j++)
                          if (local[j].eq(span, offset)) {
                              if (local == this.local)
                                  local = this.local.slice();
                              local.splice(j--, 1);
                          }
                  }
          if (children == this.children && local == this.local)
              return this;
          return local.length || children.length ? new DecorationSet(local, children) : empty;
      }
      forChild(offset, node) {
          if (this == empty)
              return this;
          if (node.isLeaf)
              return DecorationSet.empty;
          let child, local;
          for (let i = 0; i < this.children.length; i += 3)
              if (this.children[i] >= offset) {
                  if (this.children[i] == offset)
                      child = this.children[i + 2];
                  break;
              }
          let start = offset + 1, end = start + node.content.size;
          for (let i = 0; i < this.local.length; i++) {
              let dec = this.local[i];
              if (dec.from < end && dec.to > start && (dec.type instanceof InlineType)) {
                  let from = Math.max(start, dec.from) - start, to = Math.min(end, dec.to) - start;
                  if (from < to)
                      (local || (local = [])).push(dec.copy(from, to));
              }
          }
          if (local) {
              let localSet = new DecorationSet(local.sort(byPos), none);
              return child ? new DecorationGroup([localSet, child]) : localSet;
          }
          return child || empty;
      }
      /**
      @internal
      */
      eq(other) {
          if (this == other)
              return true;
          if (!(other instanceof DecorationSet) ||
              this.local.length != other.local.length ||
              this.children.length != other.children.length)
              return false;
          for (let i = 0; i < this.local.length; i++)
              if (!this.local[i].eq(other.local[i]))
                  return false;
          for (let i = 0; i < this.children.length; i += 3)
              if (this.children[i] != other.children[i] ||
                  this.children[i + 1] != other.children[i + 1] ||
                  !this.children[i + 2].eq(other.children[i + 2]))
                  return false;
          return true;
      }
      /**
      @internal
      */
      locals(node) {
          return removeOverlap(this.localsInner(node));
      }
      /**
      @internal
      */
      localsInner(node) {
          if (this == empty)
              return none;
          if (node.inlineContent || !this.local.some(InlineType.is))
              return this.local;
          let result = [];
          for (let i = 0; i < this.local.length; i++) {
              if (!(this.local[i].type instanceof InlineType))
                  result.push(this.local[i]);
          }
          return result;
      }
      forEachSet(f) { f(this); }
  }
  /**
  The empty set of decorations.
  */
  DecorationSet.empty = new DecorationSet([], []);
  /**
  @internal
  */
  DecorationSet.removeOverlap = removeOverlap;
  const empty = DecorationSet.empty;
  // An abstraction that allows the code dealing with decorations to
  // treat multiple DecorationSet objects as if it were a single object
  // with (a subset of) the same interface.
  class DecorationGroup {
      constructor(members) {
          this.members = members;
      }
      map(mapping, doc) {
          const mappedDecos = this.members.map(member => member.map(mapping, doc, noSpec));
          return DecorationGroup.from(mappedDecos);
      }
      forChild(offset, child) {
          if (child.isLeaf)
              return DecorationSet.empty;
          let found = [];
          for (let i = 0; i < this.members.length; i++) {
              let result = this.members[i].forChild(offset, child);
              if (result == empty)
                  continue;
              if (result instanceof DecorationGroup)
                  found = found.concat(result.members);
              else
                  found.push(result);
          }
          return DecorationGroup.from(found);
      }
      eq(other) {
          if (!(other instanceof DecorationGroup) ||
              other.members.length != this.members.length)
              return false;
          for (let i = 0; i < this.members.length; i++)
              if (!this.members[i].eq(other.members[i]))
                  return false;
          return true;
      }
      locals(node) {
          let result, sorted = true;
          for (let i = 0; i < this.members.length; i++) {
              let locals = this.members[i].localsInner(node);
              if (!locals.length)
                  continue;
              if (!result) {
                  result = locals;
              }
              else {
                  if (sorted) {
                      result = result.slice();
                      sorted = false;
                  }
                  for (let j = 0; j < locals.length; j++)
                      result.push(locals[j]);
              }
          }
          return result ? removeOverlap(sorted ? result : result.sort(byPos)) : none;
      }
      // Create a group for the given array of decoration sets, or return
      // a single set when possible.
      static from(members) {
          switch (members.length) {
              case 0: return empty;
              case 1: return members[0];
              default: return new DecorationGroup(members.every(m => m instanceof DecorationSet) ? members :
                  members.reduce((r, m) => r.concat(m instanceof DecorationSet ? m : m.members), []));
          }
      }
      forEachSet(f) {
          for (let i = 0; i < this.members.length; i++)
              this.members[i].forEachSet(f);
      }
  }
  function mapChildren(oldChildren, newLocal, mapping, node, offset, oldOffset, options) {
      let children = oldChildren.slice();
      // Mark the children that are directly touched by changes, and
      // move those that are after the changes.
      for (let i = 0, baseOffset = oldOffset; i < mapping.maps.length; i++) {
          let moved = 0;
          mapping.maps[i].forEach((oldStart, oldEnd, newStart, newEnd) => {
              let dSize = (newEnd - newStart) - (oldEnd - oldStart);
              for (let i = 0; i < children.length; i += 3) {
                  let end = children[i + 1];
                  if (end < 0 || oldStart > end + baseOffset - moved)
                      continue;
                  let start = children[i] + baseOffset - moved;
                  if (oldEnd >= start) {
                      children[i + 1] = oldStart <= start ? -2 : -1;
                  }
                  else if (oldStart >= baseOffset && dSize) {
                      children[i] += dSize;
                      children[i + 1] += dSize;
                  }
              }
              moved += dSize;
          });
          baseOffset = mapping.maps[i].map(baseOffset, -1);
      }
      // Find the child nodes that still correspond to a single node,
      // recursively call mapInner on them and update their positions.
      let mustRebuild = false;
      for (let i = 0; i < children.length; i += 3)
          if (children[i + 1] < 0) { // Touched nodes
              if (children[i + 1] == -2) {
                  mustRebuild = true;
                  children[i + 1] = -1;
                  continue;
              }
              let from = mapping.map(oldChildren[i] + oldOffset), fromLocal = from - offset;
              if (fromLocal < 0 || fromLocal >= node.content.size) {
                  mustRebuild = true;
                  continue;
              }
              // Must read oldChildren because children was tagged with -1
              let to = mapping.map(oldChildren[i + 1] + oldOffset, -1), toLocal = to - offset;
              let { index, offset: childOffset } = node.content.findIndex(fromLocal);
              let childNode = node.maybeChild(index);
              if (childNode && childOffset == fromLocal && childOffset + childNode.nodeSize == toLocal) {
                  let mapped = children[i + 2]
                      .mapInner(mapping, childNode, from + 1, oldChildren[i] + oldOffset + 1, options);
                  if (mapped != empty) {
                      children[i] = fromLocal;
                      children[i + 1] = toLocal;
                      children[i + 2] = mapped;
                  }
                  else {
                      children[i + 1] = -2;
                      mustRebuild = true;
                  }
              }
              else {
                  mustRebuild = true;
              }
          }
      // Remaining children must be collected and rebuilt into the appropriate structure
      if (mustRebuild) {
          let decorations = mapAndGatherRemainingDecorations(children, oldChildren, newLocal, mapping, offset, oldOffset, options);
          let built = buildTree(decorations, node, 0, options);
          newLocal = built.local;
          for (let i = 0; i < children.length; i += 3)
              if (children[i + 1] < 0) {
                  children.splice(i, 3);
                  i -= 3;
              }
          for (let i = 0, j = 0; i < built.children.length; i += 3) {
              let from = built.children[i];
              while (j < children.length && children[j] < from)
                  j += 3;
              children.splice(j, 0, built.children[i], built.children[i + 1], built.children[i + 2]);
          }
      }
      return new DecorationSet(newLocal.sort(byPos), children);
  }
  function moveSpans(spans, offset) {
      if (!offset || !spans.length)
          return spans;
      let result = [];
      for (let i = 0; i < spans.length; i++) {
          let span = spans[i];
          result.push(new Decoration(span.from + offset, span.to + offset, span.type));
      }
      return result;
  }
  function mapAndGatherRemainingDecorations(children, oldChildren, decorations, mapping, offset, oldOffset, options) {
      // Gather all decorations from the remaining marked children
      function gather(set, oldOffset) {
          for (let i = 0; i < set.local.length; i++) {
              let mapped = set.local[i].map(mapping, offset, oldOffset);
              if (mapped)
                  decorations.push(mapped);
              else if (options.onRemove)
                  options.onRemove(set.local[i].spec);
          }
          for (let i = 0; i < set.children.length; i += 3)
              gather(set.children[i + 2], set.children[i] + oldOffset + 1);
      }
      for (let i = 0; i < children.length; i += 3)
          if (children[i + 1] == -1)
              gather(children[i + 2], oldChildren[i] + oldOffset + 1);
      return decorations;
  }
  function takeSpansForNode(spans, node, offset) {
      if (node.isLeaf)
          return null;
      let end = offset + node.nodeSize, found = null;
      for (let i = 0, span; i < spans.length; i++) {
          if ((span = spans[i]) && span.from > offset && span.to < end) {
              (found || (found = [])).push(span);
              spans[i] = null;
          }
      }
      return found;
  }
  function withoutNulls(array) {
      let result = [];
      for (let i = 0; i < array.length; i++)
          if (array[i] != null)
              result.push(array[i]);
      return result;
  }
  // Build up a tree that corresponds to a set of decorations. `offset`
  // is a base offset that should be subtracted from the `from` and `to`
  // positions in the spans (so that we don't have to allocate new spans
  // for recursive calls).
  function buildTree(spans, node, offset, options) {
      let children = [], hasNulls = false;
      node.forEach((childNode, localStart) => {
          let found = takeSpansForNode(spans, childNode, localStart + offset);
          if (found) {
              hasNulls = true;
              let subtree = buildTree(found, childNode, offset + localStart + 1, options);
              if (subtree != empty)
                  children.push(localStart, localStart + childNode.nodeSize, subtree);
          }
      });
      let locals = moveSpans(hasNulls ? withoutNulls(spans) : spans, -offset).sort(byPos);
      for (let i = 0; i < locals.length; i++)
          if (!locals[i].type.valid(node, locals[i])) {
              if (options.onRemove)
                  options.onRemove(locals[i].spec);
              locals.splice(i--, 1);
          }
      return locals.length || children.length ? new DecorationSet(locals, children) : empty;
  }
  // Used to sort decorations so that ones with a low start position
  // come first, and within a set with the same start position, those
  // with an smaller end position come first.
  function byPos(a, b) {
      return a.from - b.from || a.to - b.to;
  }
  // Scan a sorted array of decorations for partially overlapping spans,
  // and split those so that only fully overlapping spans are left (to
  // make subsequent rendering easier). Will return the input array if
  // no partially overlapping spans are found (the common case).
  function removeOverlap(spans) {
      let working = spans;
      for (let i = 0; i < working.length - 1; i++) {
          let span = working[i];
          if (span.from != span.to)
              for (let j = i + 1; j < working.length; j++) {
                  let next = working[j];
                  if (next.from == span.from) {
                      if (next.to != span.to) {
                          if (working == spans)
                              working = spans.slice();
                          // Followed by a partially overlapping larger span. Split that
                          // span.
                          working[j] = next.copy(next.from, span.to);
                          insertAhead(working, j + 1, next.copy(span.to, next.to));
                      }
                      continue;
                  }
                  else {
                      if (next.from < span.to) {
                          if (working == spans)
                              working = spans.slice();
                          // The end of this one overlaps with a subsequent span. Split
                          // this one.
                          working[i] = span.copy(span.from, next.from);
                          insertAhead(working, j, span.copy(next.from, span.to));
                      }
                      break;
                  }
              }
      }
      return working;
  }
  function insertAhead(array, i, deco) {
      while (i < array.length && byPos(deco, array[i]) > 0)
          i++;
      array.splice(i, 0, deco);
  }
  // Get the decorations associated with the current props of a view.
  function viewDecorations(view) {
      let found = [];
      view.someProp("decorations", f => {
          let result = f(view.state);
          if (result && result != empty)
              found.push(result);
      });
      if (view.cursorWrapper)
          found.push(DecorationSet.create(view.state.doc, [view.cursorWrapper.deco]));
      return DecorationGroup.from(found);
  }

  const observeOptions = {
      childList: true,
      characterData: true,
      characterDataOldValue: true,
      attributes: true,
      attributeOldValue: true,
      subtree: true
  };
  // IE11 has very broken mutation observers, so we also listen to DOMCharacterDataModified
  const useCharData = ie$1 && ie_version <= 11;
  class SelectionState {
      constructor() {
          this.anchorNode = null;
          this.anchorOffset = 0;
          this.focusNode = null;
          this.focusOffset = 0;
      }
      set(sel) {
          this.anchorNode = sel.anchorNode;
          this.anchorOffset = sel.anchorOffset;
          this.focusNode = sel.focusNode;
          this.focusOffset = sel.focusOffset;
      }
      clear() {
          this.anchorNode = this.focusNode = null;
      }
      eq(sel) {
          return sel.anchorNode == this.anchorNode && sel.anchorOffset == this.anchorOffset &&
              sel.focusNode == this.focusNode && sel.focusOffset == this.focusOffset;
      }
  }
  class DOMObserver {
      constructor(view, handleDOMChange) {
          this.view = view;
          this.handleDOMChange = handleDOMChange;
          this.queue = [];
          this.flushingSoon = -1;
          this.observer = null;
          this.currentSelection = new SelectionState;
          this.onCharData = null;
          this.suppressingSelectionUpdates = false;
          this.lastChangedTextNode = null;
          this.observer = window.MutationObserver &&
              new window.MutationObserver(mutations => {
                  for (let i = 0; i < mutations.length; i++)
                      this.queue.push(mutations[i]);
                  // IE11 will sometimes (on backspacing out a single character
                  // text node after a BR node) call the observer callback
                  // before actually updating the DOM, which will cause
                  // ProseMirror to miss the change (see #930)
                  if (ie$1 && ie_version <= 11 && mutations.some(m => m.type == "childList" && m.removedNodes.length ||
                      m.type == "characterData" && m.oldValue.length > m.target.nodeValue.length))
                      this.flushSoon();
                  else
                      this.flush();
              });
          if (useCharData) {
              this.onCharData = e => {
                  this.queue.push({ target: e.target, type: "characterData", oldValue: e.prevValue });
                  this.flushSoon();
              };
          }
          this.onSelectionChange = this.onSelectionChange.bind(this);
      }
      flushSoon() {
          if (this.flushingSoon < 0)
              this.flushingSoon = window.setTimeout(() => { this.flushingSoon = -1; this.flush(); }, 20);
      }
      forceFlush() {
          if (this.flushingSoon > -1) {
              window.clearTimeout(this.flushingSoon);
              this.flushingSoon = -1;
              this.flush();
          }
      }
      start() {
          if (this.observer) {
              this.observer.takeRecords();
              this.observer.observe(this.view.dom, observeOptions);
          }
          if (this.onCharData)
              this.view.dom.addEventListener("DOMCharacterDataModified", this.onCharData);
          this.connectSelection();
      }
      stop() {
          if (this.observer) {
              let take = this.observer.takeRecords();
              if (take.length) {
                  for (let i = 0; i < take.length; i++)
                      this.queue.push(take[i]);
                  window.setTimeout(() => this.flush(), 20);
              }
              this.observer.disconnect();
          }
          if (this.onCharData)
              this.view.dom.removeEventListener("DOMCharacterDataModified", this.onCharData);
          this.disconnectSelection();
      }
      connectSelection() {
          this.view.dom.ownerDocument.addEventListener("selectionchange", this.onSelectionChange);
      }
      disconnectSelection() {
          this.view.dom.ownerDocument.removeEventListener("selectionchange", this.onSelectionChange);
      }
      suppressSelectionUpdates() {
          this.suppressingSelectionUpdates = true;
          setTimeout(() => this.suppressingSelectionUpdates = false, 50);
      }
      onSelectionChange() {
          if (!hasFocusAndSelection(this.view))
              return;
          if (this.suppressingSelectionUpdates)
              return selectionToDOM(this.view);
          // Deletions on IE11 fire their events in the wrong order, giving
          // us a selection change event before the DOM changes are
          // reported.
          if (ie$1 && ie_version <= 11 && !this.view.state.selection.empty) {
              let sel = this.view.domSelectionRange();
              // Selection.isCollapsed isn't reliable on IE
              if (sel.focusNode && isEquivalentPosition(sel.focusNode, sel.focusOffset, sel.anchorNode, sel.anchorOffset))
                  return this.flushSoon();
          }
          this.flush();
      }
      setCurSelection() {
          this.currentSelection.set(this.view.domSelectionRange());
      }
      ignoreSelectionChange(sel) {
          if (!sel.focusNode)
              return true;
          let ancestors = new Set, container;
          for (let scan = sel.focusNode; scan; scan = parentNode(scan))
              ancestors.add(scan);
          for (let scan = sel.anchorNode; scan; scan = parentNode(scan))
              if (ancestors.has(scan)) {
                  container = scan;
                  break;
              }
          let desc = container && this.view.docView.nearestDesc(container);
          if (desc && desc.ignoreMutation({
              type: "selection",
              target: container.nodeType == 3 ? container.parentNode : container
          })) {
              this.setCurSelection();
              return true;
          }
      }
      pendingRecords() {
          if (this.observer)
              for (let mut of this.observer.takeRecords())
                  this.queue.push(mut);
          return this.queue;
      }
      flush() {
          let { view } = this;
          if (!view.docView || this.flushingSoon > -1)
              return;
          let mutations = this.pendingRecords();
          if (mutations.length)
              this.queue = [];
          let sel = view.domSelectionRange();
          let newSel = !this.suppressingSelectionUpdates && !this.currentSelection.eq(sel) && hasFocusAndSelection(view) && !this.ignoreSelectionChange(sel);
          let from = -1, to = -1, typeOver = false, added = [];
          if (view.editable) {
              for (let i = 0; i < mutations.length; i++) {
                  let result = this.registerMutation(mutations[i], added);
                  if (result) {
                      from = from < 0 ? result.from : Math.min(result.from, from);
                      to = to < 0 ? result.to : Math.max(result.to, to);
                      if (result.typeOver)
                          typeOver = true;
                  }
              }
          }
          if (gecko && added.length) {
              let brs = added.filter(n => n.nodeName == "BR");
              if (brs.length == 2) {
                  let [a, b] = brs;
                  if (a.parentNode && a.parentNode.parentNode == b.parentNode)
                      b.remove();
                  else
                      a.remove();
              }
              else {
                  let { focusNode } = this.currentSelection;
                  for (let br of brs) {
                      let parent = br.parentNode;
                      if (parent && parent.nodeName == "LI" && (!focusNode || blockParent(view, focusNode) != parent))
                          br.remove();
                  }
              }
          }
          let readSel = null;
          // If it looks like the browser has reset the selection to the
          // start of the document after focus, restore the selection from
          // the state
          if (from < 0 && newSel && view.input.lastFocus > Date.now() - 200 &&
              Math.max(view.input.lastTouch, view.input.lastClick.time) < Date.now() - 300 &&
              selectionCollapsed(sel) && (readSel = selectionFromDOM(view)) &&
              readSel.eq(Selection.near(view.state.doc.resolve(0), 1))) {
              view.input.lastFocus = 0;
              selectionToDOM(view);
              this.currentSelection.set(sel);
              view.scrollToSelection();
          }
          else if (from > -1 || newSel) {
              if (from > -1) {
                  view.docView.markDirty(from, to);
                  checkCSS(view);
              }
              this.handleDOMChange(from, to, typeOver, added);
              if (view.docView && view.docView.dirty)
                  view.updateState(view.state);
              else if (!this.currentSelection.eq(sel))
                  selectionToDOM(view);
              this.currentSelection.set(sel);
          }
      }
      registerMutation(mut, added) {
          // Ignore mutations inside nodes that were already noted as inserted
          if (added.indexOf(mut.target) > -1)
              return null;
          let desc = this.view.docView.nearestDesc(mut.target);
          if (mut.type == "attributes" &&
              (desc == this.view.docView || mut.attributeName == "contenteditable" ||
                  // Firefox sometimes fires spurious events for null/empty styles
                  (mut.attributeName == "style" && !mut.oldValue && !mut.target.getAttribute("style"))))
              return null;
          if (!desc || desc.ignoreMutation(mut))
              return null;
          if (mut.type == "childList") {
              for (let i = 0; i < mut.addedNodes.length; i++) {
                  let node = mut.addedNodes[i];
                  added.push(node);
                  if (node.nodeType == 3)
                      this.lastChangedTextNode = node;
              }
              if (desc.contentDOM && desc.contentDOM != desc.dom && !desc.contentDOM.contains(mut.target))
                  return { from: desc.posBefore, to: desc.posAfter };
              let prev = mut.previousSibling, next = mut.nextSibling;
              if (ie$1 && ie_version <= 11 && mut.addedNodes.length) {
                  // IE11 gives us incorrect next/prev siblings for some
                  // insertions, so if there are added nodes, recompute those
                  for (let i = 0; i < mut.addedNodes.length; i++) {
                      let { previousSibling, nextSibling } = mut.addedNodes[i];
                      if (!previousSibling || Array.prototype.indexOf.call(mut.addedNodes, previousSibling) < 0)
                          prev = previousSibling;
                      if (!nextSibling || Array.prototype.indexOf.call(mut.addedNodes, nextSibling) < 0)
                          next = nextSibling;
                  }
              }
              let fromOffset = prev && prev.parentNode == mut.target
                  ? domIndex(prev) + 1 : 0;
              let from = desc.localPosFromDOM(mut.target, fromOffset, -1);
              let toOffset = next && next.parentNode == mut.target
                  ? domIndex(next) : mut.target.childNodes.length;
              let to = desc.localPosFromDOM(mut.target, toOffset, 1);
              return { from, to };
          }
          else if (mut.type == "attributes") {
              return { from: desc.posAtStart - desc.border, to: desc.posAtEnd + desc.border };
          }
          else { // "characterData"
              this.lastChangedTextNode = mut.target;
              return {
                  from: desc.posAtStart,
                  to: desc.posAtEnd,
                  // An event was generated for a text change that didn't change
                  // any text. Mark the dom change to fall back to assuming the
                  // selection was typed over with an identical value if it can't
                  // find another change.
                  typeOver: mut.target.nodeValue == mut.oldValue
              };
          }
      }
  }
  let cssChecked = new WeakMap();
  let cssCheckWarned = false;
  function checkCSS(view) {
      if (cssChecked.has(view))
          return;
      cssChecked.set(view, null);
      if (['normal', 'nowrap', 'pre-line'].indexOf(getComputedStyle(view.dom).whiteSpace) !== -1) {
          view.requiresGeckoHackNode = gecko;
          if (cssCheckWarned)
              return;
          console["warn"]("ProseMirror expects the CSS white-space property to be set, preferably to 'pre-wrap'. It is recommended to load style/prosemirror.css from the prosemirror-view package.");
          cssCheckWarned = true;
      }
  }
  function rangeToSelectionRange(view, range) {
      let anchorNode = range.startContainer, anchorOffset = range.startOffset;
      let focusNode = range.endContainer, focusOffset = range.endOffset;
      let currentAnchor = view.domAtPos(view.state.selection.anchor);
      // Since such a range doesn't distinguish between anchor and head,
      // use a heuristic that flips it around if its end matches the
      // current anchor.
      if (isEquivalentPosition(currentAnchor.node, currentAnchor.offset, focusNode, focusOffset))
          [anchorNode, anchorOffset, focusNode, focusOffset] = [focusNode, focusOffset, anchorNode, anchorOffset];
      return { anchorNode, anchorOffset, focusNode, focusOffset };
  }
  // Used to work around a Safari Selection/shadow DOM bug
  // Based on https://github.com/codemirror/dev/issues/414 fix
  function safariShadowSelectionRange(view, selection) {
      if (selection.getComposedRanges) {
          let range = selection.getComposedRanges(view.root)[0];
          if (range)
              return rangeToSelectionRange(view, range);
      }
      let found;
      function read(event) {
          event.preventDefault();
          event.stopImmediatePropagation();
          found = event.getTargetRanges()[0];
      }
      // Because Safari (at least in 2018-2022) doesn't provide regular
      // access to the selection inside a shadowRoot, we have to perform a
      // ridiculous hack to get at it—using `execCommand` to trigger a
      // `beforeInput` event so that we can read the target range from the
      // event.
      view.dom.addEventListener("beforeinput", read, true);
      document.execCommand("indent");
      view.dom.removeEventListener("beforeinput", read, true);
      return found ? rangeToSelectionRange(view, found) : null;
  }
  function blockParent(view, node) {
      for (let p = node.parentNode; p && p != view.dom; p = p.parentNode) {
          let desc = view.docView.nearestDesc(p, true);
          if (desc && desc.node.isBlock)
              return p;
      }
      return null;
  }

  // Note that all referencing and parsing is done with the
  // start-of-operation selection and document, since that's the one
  // that the DOM represents. If any changes came in in the meantime,
  // the modification is mapped over those before it is applied, in
  // readDOMChange.
  function parseBetween(view, from_, to_) {
      let { node: parent, fromOffset, toOffset, from, to } = view.docView.parseRange(from_, to_);
      let domSel = view.domSelectionRange();
      let find;
      let anchor = domSel.anchorNode;
      if (anchor && view.dom.contains(anchor.nodeType == 1 ? anchor : anchor.parentNode)) {
          find = [{ node: anchor, offset: domSel.anchorOffset }];
          if (!selectionCollapsed(domSel))
              find.push({ node: domSel.focusNode, offset: domSel.focusOffset });
      }
      // Work around issue in Chrome where backspacing sometimes replaces
      // the deleted content with a random BR node (issues #799, #831)
      if (chrome && view.input.lastKeyCode === 8) {
          for (let off = toOffset; off > fromOffset; off--) {
              let node = parent.childNodes[off - 1], desc = node.pmViewDesc;
              if (node.nodeName == "BR" && !desc) {
                  toOffset = off;
                  break;
              }
              if (!desc || desc.size)
                  break;
          }
      }
      let startDoc = view.state.doc;
      let parser = view.someProp("domParser") || DOMParser.fromSchema(view.state.schema);
      let $from = startDoc.resolve(from);
      let sel = null, doc = parser.parse(parent, {
          topNode: $from.parent,
          topMatch: $from.parent.contentMatchAt($from.index()),
          topOpen: true,
          from: fromOffset,
          to: toOffset,
          preserveWhitespace: $from.parent.type.whitespace == "pre" ? "full" : true,
          findPositions: find,
          ruleFromNode,
          context: $from
      });
      if (find && find[0].pos != null) {
          let anchor = find[0].pos, head = find[1] && find[1].pos;
          if (head == null)
              head = anchor;
          sel = { anchor: anchor + from, head: head + from };
      }
      return { doc, sel, from, to };
  }
  function ruleFromNode(dom) {
      let desc = dom.pmViewDesc;
      if (desc) {
          return desc.parseRule();
      }
      else if (dom.nodeName == "BR" && dom.parentNode) {
          // Safari replaces the list item or table cell with a BR
          // directly in the list node (?!) if you delete the last
          // character in a list item or table cell (#708, #862)
          if (safari && /^(ul|ol)$/i.test(dom.parentNode.nodeName)) {
              let skip = document.createElement("div");
              skip.appendChild(document.createElement("li"));
              return { skip };
          }
          else if (dom.parentNode.lastChild == dom || safari && /^(tr|table)$/i.test(dom.parentNode.nodeName)) {
              return { ignore: true };
          }
      }
      else if (dom.nodeName == "IMG" && dom.getAttribute("mark-placeholder")) {
          return { ignore: true };
      }
      return null;
  }
  const isInline = /^(a|abbr|acronym|b|bd[io]|big|br|button|cite|code|data(list)?|del|dfn|em|i|img|ins|kbd|label|map|mark|meter|output|q|ruby|s|samp|small|span|strong|su[bp]|time|u|tt|var)$/i;
  function readDOMChange(view, from, to, typeOver, addedNodes) {
      let compositionID = view.input.compositionPendingChanges || (view.composing ? view.input.compositionID : 0);
      view.input.compositionPendingChanges = 0;
      if (from < 0) {
          let origin = view.input.lastSelectionTime > Date.now() - 50 ? view.input.lastSelectionOrigin : null;
          let newSel = selectionFromDOM(view, origin);
          if (newSel && !view.state.selection.eq(newSel)) {
              if (chrome && android &&
                  view.input.lastKeyCode === 13 && Date.now() - 100 < view.input.lastKeyCodeTime &&
                  view.someProp("handleKeyDown", f => f(view, keyEvent(13, "Enter"))))
                  return;
              let tr = view.state.tr.setSelection(newSel);
              if (origin == "pointer")
                  tr.setMeta("pointer", true);
              else if (origin == "key")
                  tr.scrollIntoView();
              if (compositionID)
                  tr.setMeta("composition", compositionID);
              view.dispatch(tr);
          }
          return;
      }
      let $before = view.state.doc.resolve(from);
      let shared = $before.sharedDepth(to);
      from = $before.before(shared + 1);
      to = view.state.doc.resolve(to).after(shared + 1);
      let sel = view.state.selection;
      let parse = parseBetween(view, from, to);
      let doc = view.state.doc, compare = doc.slice(parse.from, parse.to);
      let preferredPos, preferredSide;
      // Prefer anchoring to end when Backspace is pressed
      if (view.input.lastKeyCode === 8 && Date.now() - 100 < view.input.lastKeyCodeTime) {
          preferredPos = view.state.selection.to;
          preferredSide = "end";
      }
      else {
          preferredPos = view.state.selection.from;
          preferredSide = "start";
      }
      view.input.lastKeyCode = null;
      let change = findDiff(compare.content, parse.doc.content, parse.from, preferredPos, preferredSide);
      if (change)
          view.input.domChangeCount++;
      if ((ios && view.input.lastIOSEnter > Date.now() - 225 || android) &&
          addedNodes.some(n => n.nodeType == 1 && !isInline.test(n.nodeName)) &&
          (!change || change.endA >= change.endB) &&
          view.someProp("handleKeyDown", f => f(view, keyEvent(13, "Enter")))) {
          view.input.lastIOSEnter = 0;
          return;
      }
      if (!change) {
          if (typeOver && sel instanceof TextSelection && !sel.empty && sel.$head.sameParent(sel.$anchor) &&
              !view.composing && !(parse.sel && parse.sel.anchor != parse.sel.head)) {
              change = { start: sel.from, endA: sel.to, endB: sel.to };
          }
          else {
              if (parse.sel) {
                  let sel = resolveSelection(view, view.state.doc, parse.sel);
                  if (sel && !sel.eq(view.state.selection)) {
                      let tr = view.state.tr.setSelection(sel);
                      if (compositionID)
                          tr.setMeta("composition", compositionID);
                      view.dispatch(tr);
                  }
              }
              return;
          }
      }
      // Handle the case where overwriting a selection by typing matches
      // the start or end of the selected content, creating a change
      // that's smaller than what was actually overwritten.
      if (view.state.selection.from < view.state.selection.to &&
          change.start == change.endB &&
          view.state.selection instanceof TextSelection) {
          if (change.start > view.state.selection.from && change.start <= view.state.selection.from + 2 &&
              view.state.selection.from >= parse.from) {
              change.start = view.state.selection.from;
          }
          else if (change.endA < view.state.selection.to && change.endA >= view.state.selection.to - 2 &&
              view.state.selection.to <= parse.to) {
              change.endB += (view.state.selection.to - change.endA);
              change.endA = view.state.selection.to;
          }
      }
      // IE11 will insert a non-breaking space _ahead_ of the space after
      // the cursor space when adding a space before another space. When
      // that happened, adjust the change to cover the space instead.
      if (ie$1 && ie_version <= 11 && change.endB == change.start + 1 &&
          change.endA == change.start && change.start > parse.from &&
          parse.doc.textBetween(change.start - parse.from - 1, change.start - parse.from + 1) == " \u00a0") {
          change.start--;
          change.endA--;
          change.endB--;
      }
      let $from = parse.doc.resolveNoCache(change.start - parse.from);
      let $to = parse.doc.resolveNoCache(change.endB - parse.from);
      let $fromA = doc.resolve(change.start);
      let inlineChange = $from.sameParent($to) && $from.parent.inlineContent && $fromA.end() >= change.endA;
      // If this looks like the effect of pressing Enter (or was recorded
      // as being an iOS enter press), just dispatch an Enter key instead.
      if (((ios && view.input.lastIOSEnter > Date.now() - 225 &&
          (!inlineChange || addedNodes.some(n => n.nodeName == "DIV" || n.nodeName == "P"))) ||
          (!inlineChange && $from.pos < parse.doc.content.size &&
              (!$from.sameParent($to) || !$from.parent.inlineContent) &&
              $from.pos < $to.pos && !/\S/.test(parse.doc.textBetween($from.pos, $to.pos, "", "")))) &&
          view.someProp("handleKeyDown", f => f(view, keyEvent(13, "Enter")))) {
          view.input.lastIOSEnter = 0;
          return;
      }
      // Same for backspace
      if (view.state.selection.anchor > change.start &&
          looksLikeBackspace(doc, change.start, change.endA, $from, $to) &&
          view.someProp("handleKeyDown", f => f(view, keyEvent(8, "Backspace")))) {
          if (android && chrome)
              view.domObserver.suppressSelectionUpdates(); // #820
          return;
      }
      // Chrome will occasionally, during composition, delete the
      // entire composition and then immediately insert it again. This is
      // used to detect that situation.
      if (chrome && change.endB == change.start)
          view.input.lastChromeDelete = Date.now();
      // This tries to detect Android virtual keyboard
      // enter-and-pick-suggestion action. That sometimes (see issue
      // #1059) first fires a DOM mutation, before moving the selection to
      // the newly created block. And then, because ProseMirror cleans up
      // the DOM selection, it gives up moving the selection entirely,
      // leaving the cursor in the wrong place. When that happens, we drop
      // the new paragraph from the initial change, and fire a simulated
      // enter key afterwards.
      if (android && !inlineChange && $from.start() != $to.start() && $to.parentOffset == 0 && $from.depth == $to.depth &&
          parse.sel && parse.sel.anchor == parse.sel.head && parse.sel.head == change.endA) {
          change.endB -= 2;
          $to = parse.doc.resolveNoCache(change.endB - parse.from);
          setTimeout(() => {
              view.someProp("handleKeyDown", function (f) { return f(view, keyEvent(13, "Enter")); });
          }, 20);
      }
      let chFrom = change.start, chTo = change.endA;
      let mkTr = (base) => {
          let tr = base || view.state.tr.replace(chFrom, chTo, parse.doc.slice(change.start - parse.from, change.endB - parse.from));
          if (parse.sel) {
              let sel = resolveSelection(view, tr.doc, parse.sel);
              // Chrome will sometimes, during composition, report the
              // selection in the wrong place. If it looks like that is
              // happening, don't update the selection.
              // Edge just doesn't move the cursor forward when you start typing
              // in an empty block or between br nodes.
              if (sel && !(chrome && view.composing && sel.empty &&
                  (change.start != change.endB || view.input.lastChromeDelete < Date.now() - 100) &&
                  (sel.head == chFrom || sel.head == tr.mapping.map(chTo) - 1) ||
                  ie$1 && sel.empty && sel.head == chFrom))
                  tr.setSelection(sel);
          }
          if (compositionID)
              tr.setMeta("composition", compositionID);
          return tr.scrollIntoView();
      };
      let markChange;
      if (inlineChange) {
          if ($from.pos == $to.pos) { // Deletion
              // IE11 sometimes weirdly moves the DOM selection around after
              // backspacing out the first element in a textblock
              if (ie$1 && ie_version <= 11 && $from.parentOffset == 0) {
                  view.domObserver.suppressSelectionUpdates();
                  setTimeout(() => selectionToDOM(view), 20);
              }
              let tr = mkTr(view.state.tr.delete(chFrom, chTo));
              let marks = doc.resolve(change.start).marksAcross(doc.resolve(change.endA));
              if (marks)
                  tr.ensureMarks(marks);
              view.dispatch(tr);
          }
          else if ( // Adding or removing a mark
          change.endA == change.endB &&
              (markChange = isMarkChange($from.parent.content.cut($from.parentOffset, $to.parentOffset), $fromA.parent.content.cut($fromA.parentOffset, change.endA - $fromA.start())))) {
              let tr = mkTr(view.state.tr);
              if (markChange.type == "add")
                  tr.addMark(chFrom, chTo, markChange.mark);
              else
                  tr.removeMark(chFrom, chTo, markChange.mark);
              view.dispatch(tr);
          }
          else if ($from.parent.child($from.index()).isText && $from.index() == $to.index() - ($to.textOffset ? 0 : 1)) {
              // Both positions in the same text node -- simply insert text
              let text = $from.parent.textBetween($from.parentOffset, $to.parentOffset);
              let deflt = () => mkTr(view.state.tr.insertText(text, chFrom, chTo));
              if (!view.someProp("handleTextInput", f => f(view, chFrom, chTo, text, deflt)))
                  view.dispatch(deflt());
          }
      }
      else {
          view.dispatch(mkTr());
      }
  }
  function resolveSelection(view, doc, parsedSel) {
      if (Math.max(parsedSel.anchor, parsedSel.head) > doc.content.size)
          return null;
      return selectionBetween(view, doc.resolve(parsedSel.anchor), doc.resolve(parsedSel.head));
  }
  // Given two same-length, non-empty fragments of inline content,
  // determine whether the first could be created from the second by
  // removing or adding a single mark type.
  function isMarkChange(cur, prev) {
      let curMarks = cur.firstChild.marks, prevMarks = prev.firstChild.marks;
      let added = curMarks, removed = prevMarks, type, mark, update;
      for (let i = 0; i < prevMarks.length; i++)
          added = prevMarks[i].removeFromSet(added);
      for (let i = 0; i < curMarks.length; i++)
          removed = curMarks[i].removeFromSet(removed);
      if (added.length == 1 && removed.length == 0) {
          mark = added[0];
          type = "add";
          update = (node) => node.mark(mark.addToSet(node.marks));
      }
      else if (added.length == 0 && removed.length == 1) {
          mark = removed[0];
          type = "remove";
          update = (node) => node.mark(mark.removeFromSet(node.marks));
      }
      else {
          return null;
      }
      let updated = [];
      for (let i = 0; i < prev.childCount; i++)
          updated.push(update(prev.child(i)));
      if (Fragment.from(updated).eq(cur))
          return { mark, type };
  }
  function looksLikeBackspace(old, start, end, $newStart, $newEnd) {
      if ( // The content must have shrunk
      end - start <= $newEnd.pos - $newStart.pos ||
          // newEnd must point directly at or after the end of the block that newStart points into
          skipClosingAndOpening($newStart, true, false) < $newEnd.pos)
          return false;
      let $start = old.resolve(start);
      // Handle the case where, rather than joining blocks, the change just removed an entire block
      if (!$newStart.parent.isTextblock) {
          let after = $start.nodeAfter;
          return after != null && end == start + after.nodeSize;
      }
      // Start must be at the end of a block
      if ($start.parentOffset < $start.parent.content.size || !$start.parent.isTextblock)
          return false;
      let $next = old.resolve(skipClosingAndOpening($start, true, true));
      // The next textblock must start before end and end near it
      if (!$next.parent.isTextblock || $next.pos > end ||
          skipClosingAndOpening($next, true, false) < end)
          return false;
      // The fragments after the join point must match
      return $newStart.parent.content.cut($newStart.parentOffset).eq($next.parent.content);
  }
  function skipClosingAndOpening($pos, fromEnd, mayOpen) {
      let depth = $pos.depth, end = fromEnd ? $pos.end() : $pos.pos;
      while (depth > 0 && (fromEnd || $pos.indexAfter(depth) == $pos.node(depth).childCount)) {
          depth--;
          end++;
          fromEnd = false;
      }
      if (mayOpen) {
          let next = $pos.node(depth).maybeChild($pos.indexAfter(depth));
          while (next && !next.isLeaf) {
              next = next.firstChild;
              end++;
          }
      }
      return end;
  }
  function findDiff(a, b, pos, preferredPos, preferredSide) {
      let start = a.findDiffStart(b, pos);
      if (start == null)
          return null;
      let { a: endA, b: endB } = a.findDiffEnd(b, pos + a.size, pos + b.size);
      if (preferredSide == "end") {
          let adjust = Math.max(0, start - Math.min(endA, endB));
          preferredPos -= endA + adjust - start;
      }
      if (endA < start && a.size < b.size) {
          let move = preferredPos <= start && preferredPos >= endA ? start - preferredPos : 0;
          start -= move;
          if (start && start < b.size && isSurrogatePair(b.textBetween(start - 1, start + 1)))
              start += move ? 1 : -1;
          endB = start + (endB - endA);
          endA = start;
      }
      else if (endB < start) {
          let move = preferredPos <= start && preferredPos >= endB ? start - preferredPos : 0;
          start -= move;
          if (start && start < a.size && isSurrogatePair(a.textBetween(start - 1, start + 1)))
              start += move ? 1 : -1;
          endA = start + (endA - endB);
          endB = start;
      }
      return { start, endA, endB };
  }
  function isSurrogatePair(str) {
      if (str.length != 2)
          return false;
      let a = str.charCodeAt(0), b = str.charCodeAt(1);
      return a >= 0xDC00 && a <= 0xDFFF && b >= 0xD800 && b <= 0xDBFF;
  }
  /**
  An editor view manages the DOM structure that represents an
  editable document. Its state and behavior are determined by its
  [props](https://prosemirror.net/docs/ref/#view.DirectEditorProps).
  */
  class EditorView {
      /**
      Create a view. `place` may be a DOM node that the editor should
      be appended to, a function that will place it into the document,
      or an object whose `mount` property holds the node to use as the
      document container. If it is `null`, the editor will not be
      added to the document.
      */
      constructor(place, props) {
          this._root = null;
          /**
          @internal
          */
          this.focused = false;
          /**
          Kludge used to work around a Chrome bug @internal
          */
          this.trackWrites = null;
          this.mounted = false;
          /**
          @internal
          */
          this.markCursor = null;
          /**
          @internal
          */
          this.cursorWrapper = null;
          /**
          @internal
          */
          this.lastSelectedViewDesc = undefined;
          /**
          @internal
          */
          this.input = new InputState;
          this.prevDirectPlugins = [];
          this.pluginViews = [];
          /**
          Holds `true` when a hack node is needed in Firefox to prevent the
          [space is eaten issue](https://github.com/ProseMirror/prosemirror/issues/651)
          @internal
          */
          this.requiresGeckoHackNode = false;
          /**
          When editor content is being dragged, this object contains
          information about the dragged slice and whether it is being
          copied or moved. At any other time, it is null.
          */
          this.dragging = null;
          this._props = props;
          this.state = props.state;
          this.directPlugins = props.plugins || [];
          this.directPlugins.forEach(checkStateComponent);
          this.dispatch = this.dispatch.bind(this);
          this.dom = (place && place.mount) || document.createElement("div");
          if (place) {
              if (place.appendChild)
                  place.appendChild(this.dom);
              else if (typeof place == "function")
                  place(this.dom);
              else if (place.mount)
                  this.mounted = true;
          }
          this.editable = getEditable(this);
          updateCursorWrapper(this);
          this.nodeViews = buildNodeViews(this);
          this.docView = docViewDesc(this.state.doc, computeDocDeco(this), viewDecorations(this), this.dom, this);
          this.domObserver = new DOMObserver(this, (from, to, typeOver, added) => readDOMChange(this, from, to, typeOver, added));
          this.domObserver.start();
          initInput(this);
          this.updatePluginViews();
      }
      /**
      Holds `true` when a
      [composition](https://w3c.github.io/uievents/#events-compositionevents)
      is active.
      */
      get composing() { return this.input.composing; }
      /**
      The view's current [props](https://prosemirror.net/docs/ref/#view.EditorProps).
      */
      get props() {
          if (this._props.state != this.state) {
              let prev = this._props;
              this._props = {};
              for (let name in prev)
                  this._props[name] = prev[name];
              this._props.state = this.state;
          }
          return this._props;
      }
      /**
      Update the view's props. Will immediately cause an update to
      the DOM.
      */
      update(props) {
          if (props.handleDOMEvents != this._props.handleDOMEvents)
              ensureListeners(this);
          let prevProps = this._props;
          this._props = props;
          if (props.plugins) {
              props.plugins.forEach(checkStateComponent);
              this.directPlugins = props.plugins;
          }
          this.updateStateInner(props.state, prevProps);
      }
      /**
      Update the view by updating existing props object with the object
      given as argument. Equivalent to `view.update(Object.assign({},
      view.props, props))`.
      */
      setProps(props) {
          let updated = {};
          for (let name in this._props)
              updated[name] = this._props[name];
          updated.state = this.state;
          for (let name in props)
              updated[name] = props[name];
          this.update(updated);
      }
      /**
      Update the editor's `state` prop, without touching any of the
      other props.
      */
      updateState(state) {
          this.updateStateInner(state, this._props);
      }
      updateStateInner(state, prevProps) {
          var _a;
          let prev = this.state, redraw = false, updateSel = false;
          // When stored marks are added, stop composition, so that they can
          // be displayed.
          if (state.storedMarks && this.composing) {
              clearComposition(this);
              updateSel = true;
          }
          this.state = state;
          let pluginsChanged = prev.plugins != state.plugins || this._props.plugins != prevProps.plugins;
          if (pluginsChanged || this._props.plugins != prevProps.plugins || this._props.nodeViews != prevProps.nodeViews) {
              let nodeViews = buildNodeViews(this);
              if (changedNodeViews(nodeViews, this.nodeViews)) {
                  this.nodeViews = nodeViews;
                  redraw = true;
              }
          }
          if (pluginsChanged || prevProps.handleDOMEvents != this._props.handleDOMEvents) {
              ensureListeners(this);
          }
          this.editable = getEditable(this);
          updateCursorWrapper(this);
          let innerDeco = viewDecorations(this), outerDeco = computeDocDeco(this);
          let scroll = prev.plugins != state.plugins && !prev.doc.eq(state.doc) ? "reset"
              : state.scrollToSelection > prev.scrollToSelection ? "to selection" : "preserve";
          let updateDoc = redraw || !this.docView.matchesNode(state.doc, outerDeco, innerDeco);
          if (updateDoc || !state.selection.eq(prev.selection))
              updateSel = true;
          let oldScrollPos = scroll == "preserve" && updateSel && this.dom.style.overflowAnchor == null && storeScrollPos(this);
          if (updateSel) {
              this.domObserver.stop();
              // Work around an issue in Chrome, IE, and Edge where changing
              // the DOM around an active selection puts it into a broken
              // state where the thing the user sees differs from the
              // selection reported by the Selection object (#710, #973,
              // #1011, #1013, #1035).
              let forceSelUpdate = updateDoc && (ie$1 || chrome) && !this.composing &&
                  !prev.selection.empty && !state.selection.empty && selectionContextChanged(prev.selection, state.selection);
              if (updateDoc) {
                  // If the node that the selection points into is written to,
                  // Chrome sometimes starts misreporting the selection, so this
                  // tracks that and forces a selection reset when our update
                  // did write to the node.
                  let chromeKludge = chrome ? (this.trackWrites = this.domSelectionRange().focusNode) : null;
                  if (this.composing)
                      this.input.compositionNode = findCompositionNode(this);
                  if (redraw || !this.docView.update(state.doc, outerDeco, innerDeco, this)) {
                      this.docView.updateOuterDeco(outerDeco);
                      this.docView.destroy();
                      this.docView = docViewDesc(state.doc, outerDeco, innerDeco, this.dom, this);
                  }
                  if (chromeKludge && !this.trackWrites)
                      forceSelUpdate = true;
              }
              // Work around for an issue where an update arriving right between
              // a DOM selection change and the "selectionchange" event for it
              // can cause a spurious DOM selection update, disrupting mouse
              // drag selection.
              if (forceSelUpdate ||
                  !(this.input.mouseDown && this.domObserver.currentSelection.eq(this.domSelectionRange()) &&
                      anchorInRightPlace(this))) {
                  selectionToDOM(this, forceSelUpdate);
              }
              else {
                  syncNodeSelection(this, state.selection);
                  this.domObserver.setCurSelection();
              }
              this.domObserver.start();
          }
          this.updatePluginViews(prev);
          if (((_a = this.dragging) === null || _a === void 0 ? void 0 : _a.node) && !prev.doc.eq(state.doc))
              this.updateDraggedNode(this.dragging, prev);
          if (scroll == "reset") {
              this.dom.scrollTop = 0;
          }
          else if (scroll == "to selection") {
              this.scrollToSelection();
          }
          else if (oldScrollPos) {
              resetScrollPos(oldScrollPos);
          }
      }
      /**
      @internal
      */
      scrollToSelection() {
          let startDOM = this.domSelectionRange().focusNode;
          if (!startDOM || !this.dom.contains(startDOM.nodeType == 1 ? startDOM : startDOM.parentNode)) ;
          else if (this.someProp("handleScrollToSelection", f => f(this))) ;
          else if (this.state.selection instanceof NodeSelection) {
              let target = this.docView.domAfterPos(this.state.selection.from);
              if (target.nodeType == 1)
                  scrollRectIntoView(this, target.getBoundingClientRect(), startDOM);
          }
          else {
              scrollRectIntoView(this, this.coordsAtPos(this.state.selection.head, 1), startDOM);
          }
      }
      destroyPluginViews() {
          let view;
          while (view = this.pluginViews.pop())
              if (view.destroy)
                  view.destroy();
      }
      updatePluginViews(prevState) {
          if (!prevState || prevState.plugins != this.state.plugins || this.directPlugins != this.prevDirectPlugins) {
              this.prevDirectPlugins = this.directPlugins;
              this.destroyPluginViews();
              for (let i = 0; i < this.directPlugins.length; i++) {
                  let plugin = this.directPlugins[i];
                  if (plugin.spec.view)
                      this.pluginViews.push(plugin.spec.view(this));
              }
              for (let i = 0; i < this.state.plugins.length; i++) {
                  let plugin = this.state.plugins[i];
                  if (plugin.spec.view)
                      this.pluginViews.push(plugin.spec.view(this));
              }
          }
          else {
              for (let i = 0; i < this.pluginViews.length; i++) {
                  let pluginView = this.pluginViews[i];
                  if (pluginView.update)
                      pluginView.update(this, prevState);
              }
          }
      }
      updateDraggedNode(dragging, prev) {
          let sel = dragging.node, found = -1;
          if (this.state.doc.nodeAt(sel.from) == sel.node) {
              found = sel.from;
          }
          else {
              let movedPos = sel.from + (this.state.doc.content.size - prev.doc.content.size);
              let moved = movedPos > 0 && this.state.doc.nodeAt(movedPos);
              if (moved == sel.node)
                  found = movedPos;
          }
          this.dragging = new Dragging(dragging.slice, dragging.move, found < 0 ? undefined : NodeSelection.create(this.state.doc, found));
      }
      someProp(propName, f) {
          let prop = this._props && this._props[propName], value;
          if (prop != null && (value = f ? f(prop) : prop))
              return value;
          for (let i = 0; i < this.directPlugins.length; i++) {
              let prop = this.directPlugins[i].props[propName];
              if (prop != null && (value = f ? f(prop) : prop))
                  return value;
          }
          let plugins = this.state.plugins;
          if (plugins)
              for (let i = 0; i < plugins.length; i++) {
                  let prop = plugins[i].props[propName];
                  if (prop != null && (value = f ? f(prop) : prop))
                      return value;
              }
      }
      /**
      Query whether the view has focus.
      */
      hasFocus() {
          // Work around IE not handling focus correctly if resize handles are shown.
          // If the cursor is inside an element with resize handles, activeElement
          // will be that element instead of this.dom.
          if (ie$1) {
              // If activeElement is within this.dom, and there are no other elements
              // setting `contenteditable` to false in between, treat it as focused.
              let node = this.root.activeElement;
              if (node == this.dom)
                  return true;
              if (!node || !this.dom.contains(node))
                  return false;
              while (node && this.dom != node && this.dom.contains(node)) {
                  if (node.contentEditable == 'false')
                      return false;
                  node = node.parentElement;
              }
              return true;
          }
          return this.root.activeElement == this.dom;
      }
      /**
      Focus the editor.
      */
      focus() {
          this.domObserver.stop();
          if (this.editable)
              focusPreventScroll(this.dom);
          selectionToDOM(this);
          this.domObserver.start();
      }
      /**
      Get the document root in which the editor exists. This will
      usually be the top-level `document`, but might be a [shadow
      DOM](https://developer.mozilla.org/en-US/docs/Web/Web_Components/Shadow_DOM)
      root if the editor is inside one.
      */
      get root() {
          let cached = this._root;
          if (cached == null)
              for (let search = this.dom.parentNode; search; search = search.parentNode) {
                  if (search.nodeType == 9 || (search.nodeType == 11 && search.host)) {
                      if (!search.getSelection)
                          Object.getPrototypeOf(search).getSelection = () => search.ownerDocument.getSelection();
                      return this._root = search;
                  }
              }
          return cached || document;
      }
      /**
      When an existing editor view is moved to a new document or
      shadow tree, call this to make it recompute its root.
      */
      updateRoot() {
          this._root = null;
      }
      /**
      Given a pair of viewport coordinates, return the document
      position that corresponds to them. May return null if the given
      coordinates aren't inside of the editor. When an object is
      returned, its `pos` property is the position nearest to the
      coordinates, and its `inside` property holds the position of the
      inner node that the position falls inside of, or -1 if it is at
      the top level, not in any node.
      */
      posAtCoords(coords) {
          return posAtCoords(this, coords);
      }
      /**
      Returns the viewport rectangle at a given document position.
      `left` and `right` will be the same number, as this returns a
      flat cursor-ish rectangle. If the position is between two things
      that aren't directly adjacent, `side` determines which element
      is used. When < 0, the element before the position is used,
      otherwise the element after.
      */
      coordsAtPos(pos, side = 1) {
          return coordsAtPos(this, pos, side);
      }
      /**
      Find the DOM position that corresponds to the given document
      position. When `side` is negative, find the position as close as
      possible to the content before the position. When positive,
      prefer positions close to the content after the position. When
      zero, prefer as shallow a position as possible.
      
      Note that you should **not** mutate the editor's internal DOM,
      only inspect it (and even that is usually not necessary).
      */
      domAtPos(pos, side = 0) {
          return this.docView.domFromPos(pos, side);
      }
      /**
      Find the DOM node that represents the document node after the
      given position. May return `null` when the position doesn't point
      in front of a node or if the node is inside an opaque node view.
      
      This is intended to be able to call things like
      `getBoundingClientRect` on that DOM node. Do **not** mutate the
      editor DOM directly, or add styling this way, since that will be
      immediately overriden by the editor as it redraws the node.
      */
      nodeDOM(pos) {
          let desc = this.docView.descAt(pos);
          return desc ? desc.nodeDOM : null;
      }
      /**
      Find the document position that corresponds to a given DOM
      position. (Whenever possible, it is preferable to inspect the
      document structure directly, rather than poking around in the
      DOM, but sometimes—for example when interpreting an event
      target—you don't have a choice.)
      
      The `bias` parameter can be used to influence which side of a DOM
      node to use when the position is inside a leaf node.
      */
      posAtDOM(node, offset, bias = -1) {
          let pos = this.docView.posFromDOM(node, offset, bias);
          if (pos == null)
              throw new RangeError("DOM position not inside the editor");
          return pos;
      }
      /**
      Find out whether the selection is at the end of a textblock when
      moving in a given direction. When, for example, given `"left"`,
      it will return true if moving left from the current cursor
      position would leave that position's parent textblock. Will apply
      to the view's current state by default, but it is possible to
      pass a different state.
      */
      endOfTextblock(dir, state) {
          return endOfTextblock(this, state || this.state, dir);
      }
      /**
      Run the editor's paste logic with the given HTML string. The
      `event`, if given, will be passed to the
      [`handlePaste`](https://prosemirror.net/docs/ref/#view.EditorProps.handlePaste) hook.
      */
      pasteHTML(html, event) {
          return doPaste(this, "", html, false, event || new ClipboardEvent("paste"));
      }
      /**
      Run the editor's paste logic with the given plain-text input.
      */
      pasteText(text, event) {
          return doPaste(this, text, null, true, event || new ClipboardEvent("paste"));
      }
      /**
      Serialize the given slice as it would be if it was copied from
      this editor. Returns a DOM element that contains a
      representation of the slice as its children, a textual
      representation, and the transformed slice (which can be
      different from the given input due to hooks like
      [`transformCopied`](https://prosemirror.net/docs/ref/#view.EditorProps.transformCopied)).
      */
      serializeForClipboard(slice) {
          return serializeForClipboard(this, slice);
      }
      /**
      Removes the editor from the DOM and destroys all [node
      views](https://prosemirror.net/docs/ref/#view.NodeView).
      */
      destroy() {
          if (!this.docView)
              return;
          destroyInput(this);
          this.destroyPluginViews();
          if (this.mounted) {
              this.docView.update(this.state.doc, [], viewDecorations(this), this);
              this.dom.textContent = "";
          }
          else if (this.dom.parentNode) {
              this.dom.parentNode.removeChild(this.dom);
          }
          this.docView.destroy();
          this.docView = null;
          clearReusedRange();
      }
      /**
      This is true when the view has been
      [destroyed](https://prosemirror.net/docs/ref/#view.EditorView.destroy) (and thus should not be
      used anymore).
      */
      get isDestroyed() {
          return this.docView == null;
      }
      /**
      Used for testing.
      */
      dispatchEvent(event) {
          return dispatchEvent(this, event);
      }
      /**
      @internal
      */
      domSelectionRange() {
          let sel = this.domSelection();
          if (!sel)
              return { focusNode: null, focusOffset: 0, anchorNode: null, anchorOffset: 0 };
          return safari && this.root.nodeType === 11 &&
              deepActiveElement(this.dom.ownerDocument) == this.dom && safariShadowSelectionRange(this, sel) || sel;
      }
      /**
      @internal
      */
      domSelection() {
          return this.root.getSelection();
      }
  }
  EditorView.prototype.dispatch = function (tr) {
      let dispatchTransaction = this._props.dispatchTransaction;
      if (dispatchTransaction)
          dispatchTransaction.call(this, tr);
      else
          this.updateState(this.state.apply(tr));
  };
  function computeDocDeco(view) {
      let attrs = Object.create(null);
      attrs.class = "ProseMirror";
      attrs.contenteditable = String(view.editable);
      view.someProp("attributes", value => {
          if (typeof value == "function")
              value = value(view.state);
          if (value)
              for (let attr in value) {
                  if (attr == "class")
                      attrs.class += " " + value[attr];
                  else if (attr == "style")
                      attrs.style = (attrs.style ? attrs.style + ";" : "") + value[attr];
                  else if (!attrs[attr] && attr != "contenteditable" && attr != "nodeName")
                      attrs[attr] = String(value[attr]);
              }
      });
      if (!attrs.translate)
          attrs.translate = "no";
      return [Decoration.node(0, view.state.doc.content.size, attrs)];
  }
  function updateCursorWrapper(view) {
      if (view.markCursor) {
          let dom = document.createElement("img");
          dom.className = "ProseMirror-separator";
          dom.setAttribute("mark-placeholder", "true");
          dom.setAttribute("alt", "");
          view.cursorWrapper = { dom, deco: Decoration.widget(view.state.selection.from, dom, { raw: true, marks: view.markCursor }) };
      }
      else {
          view.cursorWrapper = null;
      }
  }
  function getEditable(view) {
      return !view.someProp("editable", value => value(view.state) === false);
  }
  function selectionContextChanged(sel1, sel2) {
      let depth = Math.min(sel1.$anchor.sharedDepth(sel1.head), sel2.$anchor.sharedDepth(sel2.head));
      return sel1.$anchor.start(depth) != sel2.$anchor.start(depth);
  }
  function buildNodeViews(view) {
      let result = Object.create(null);
      function add(obj) {
          for (let prop in obj)
              if (!Object.prototype.hasOwnProperty.call(result, prop))
                  result[prop] = obj[prop];
      }
      view.someProp("nodeViews", add);
      view.someProp("markViews", add);
      return result;
  }
  function changedNodeViews(a, b) {
      let nA = 0, nB = 0;
      for (let prop in a) {
          if (a[prop] != b[prop])
              return true;
          nA++;
      }
      for (let _ in b)
          nB++;
      return nA != nB;
  }
  function checkStateComponent(plugin) {
      if (plugin.spec.state || plugin.spec.filterTransaction || plugin.spec.appendTransaction)
          throw new RangeError("Plugins passed directly to the view must not have a state component");
  }

  var base = {
    8: "Backspace",
    9: "Tab",
    10: "Enter",
    12: "NumLock",
    13: "Enter",
    16: "Shift",
    17: "Control",
    18: "Alt",
    20: "CapsLock",
    27: "Escape",
    32: " ",
    33: "PageUp",
    34: "PageDown",
    35: "End",
    36: "Home",
    37: "ArrowLeft",
    38: "ArrowUp",
    39: "ArrowRight",
    40: "ArrowDown",
    44: "PrintScreen",
    45: "Insert",
    46: "Delete",
    59: ";",
    61: "=",
    91: "Meta",
    92: "Meta",
    106: "*",
    107: "+",
    108: ",",
    109: "-",
    110: ".",
    111: "/",
    144: "NumLock",
    145: "ScrollLock",
    160: "Shift",
    161: "Shift",
    162: "Control",
    163: "Control",
    164: "Alt",
    165: "Alt",
    173: "-",
    186: ";",
    187: "=",
    188: ",",
    189: "-",
    190: ".",
    191: "/",
    192: "`",
    219: "[",
    220: "\\",
    221: "]",
    222: "'"
  };

  var shift = {
    48: ")",
    49: "!",
    50: "@",
    51: "#",
    52: "$",
    53: "%",
    54: "^",
    55: "&",
    56: "*",
    57: "(",
    59: ":",
    61: "+",
    173: "_",
    186: ":",
    187: "+",
    188: "<",
    189: "_",
    190: ">",
    191: "?",
    192: "~",
    219: "{",
    220: "|",
    221: "}",
    222: "\""
  };

  var mac$2 = typeof navigator != "undefined" && /Mac/.test(navigator.platform);
  var ie = typeof navigator != "undefined" && /MSIE \d|Trident\/(?:[7-9]|\d{2,})\..*rv:(\d+)/.exec(navigator.userAgent);

  // Fill in the digit keys
  for (var i = 0; i < 10; i++) base[48 + i] = base[96 + i] = String(i);

  // The function keys
  for (var i = 1; i <= 24; i++) base[i + 111] = "F" + i;

  // And the alphabetic keys
  for (var i = 65; i <= 90; i++) {
    base[i] = String.fromCharCode(i + 32);
    shift[i] = String.fromCharCode(i);
  }

  // For each code that doesn't have a shift-equivalent, copy the base name
  for (var code in base) if (!shift.hasOwnProperty(code)) shift[code] = base[code];

  function keyName(event) {
    // On macOS, keys held with Shift and Cmd don't reflect the effect of Shift in `.key`.
    // On IE, shift effect is never included in `.key`.
    var ignoreKey = mac$2 && event.metaKey && event.shiftKey && !event.ctrlKey && !event.altKey ||
        ie && event.shiftKey && event.key && event.key.length == 1 ||
        event.key == "Unidentified";
    var name = (!ignoreKey && event.key) ||
      (event.shiftKey ? shift : base)[event.keyCode] ||
      event.key || "Unidentified";
    // Edge sometimes produces wrong names (Issue #3)
    if (name == "Esc") name = "Escape";
    if (name == "Del") name = "Delete";
    // https://developer.microsoft.com/en-us/microsoft-edge/platform/issues/8860571/
    if (name == "Left") name = "ArrowLeft";
    if (name == "Up") name = "ArrowUp";
    if (name == "Right") name = "ArrowRight";
    if (name == "Down") name = "ArrowDown";
    return name
  }

  const mac$1 = typeof navigator != "undefined" && /Mac|iP(hone|[oa]d)/.test(navigator.platform);
  const windows = typeof navigator != "undefined" && /Win/.test(navigator.platform);
  function normalizeKeyName(name) {
      let parts = name.split(/-(?!$)/), result = parts[parts.length - 1];
      if (result == "Space")
          result = " ";
      let alt, ctrl, shift, meta;
      for (let i = 0; i < parts.length - 1; i++) {
          let mod = parts[i];
          if (/^(cmd|meta|m)$/i.test(mod))
              meta = true;
          else if (/^a(lt)?$/i.test(mod))
              alt = true;
          else if (/^(c|ctrl|control)$/i.test(mod))
              ctrl = true;
          else if (/^s(hift)?$/i.test(mod))
              shift = true;
          else if (/^mod$/i.test(mod)) {
              if (mac$1)
                  meta = true;
              else
                  ctrl = true;
          }
          else
              throw new Error("Unrecognized modifier name: " + mod);
      }
      if (alt)
          result = "Alt-" + result;
      if (ctrl)
          result = "Ctrl-" + result;
      if (meta)
          result = "Meta-" + result;
      if (shift)
          result = "Shift-" + result;
      return result;
  }
  function normalize(map) {
      let copy = Object.create(null);
      for (let prop in map)
          copy[normalizeKeyName(prop)] = map[prop];
      return copy;
  }
  function modifiers(name, event, shift = true) {
      if (event.altKey)
          name = "Alt-" + name;
      if (event.ctrlKey)
          name = "Ctrl-" + name;
      if (event.metaKey)
          name = "Meta-" + name;
      if (shift && event.shiftKey)
          name = "Shift-" + name;
      return name;
  }
  /**
  Create a keymap plugin for the given set of bindings.

  Bindings should map key names to [command](https://prosemirror.net/docs/ref/#commands)-style
  functions, which will be called with `(EditorState, dispatch,
  EditorView)` arguments, and should return true when they've handled
  the key. Note that the view argument isn't part of the command
  protocol, but can be used as an escape hatch if a binding needs to
  directly interact with the UI.

  Key names may be strings like `"Shift-Ctrl-Enter"`—a key
  identifier prefixed with zero or more modifiers. Key identifiers
  are based on the strings that can appear in
  [`KeyEvent.key`](https:developer.mozilla.org/en-US/docs/Web/API/KeyboardEvent/key).
  Use lowercase letters to refer to letter keys (or uppercase letters
  if you want shift to be held). You may use `"Space"` as an alias
  for the `" "` name.

  Modifiers can be given in any order. `Shift-` (or `s-`), `Alt-` (or
  `a-`), `Ctrl-` (or `c-` or `Control-`) and `Cmd-` (or `m-` or
  `Meta-`) are recognized. For characters that are created by holding
  shift, the `Shift-` prefix is implied, and should not be added
  explicitly.

  You can use `Mod-` as a shorthand for `Cmd-` on Mac and `Ctrl-` on
  other platforms.

  You can add multiple keymap plugins to an editor. The order in
  which they appear determines their precedence (the ones early in
  the array get to dispatch first).
  */
  function keymap(bindings) {
      return new Plugin({ props: { handleKeyDown: keydownHandler(bindings) } });
  }
  /**
  Given a set of bindings (using the same format as
  [`keymap`](https://prosemirror.net/docs/ref/#keymap.keymap)), return a [keydown
  handler](https://prosemirror.net/docs/ref/#view.EditorProps.handleKeyDown) that handles them.
  */
  function keydownHandler(bindings) {
      let map = normalize(bindings);
      return function (view, event) {
          let name = keyName(event), baseName, direct = map[modifiers(name, event)];
          if (direct && direct(view.state, view.dispatch, view))
              return true;
          // A character key
          if (name.length == 1 && name != " ") {
              if (event.shiftKey) {
                  // In case the name was already modified by shift, try looking
                  // it up without its shift modifier
                  let noShift = map[modifiers(name, event, false)];
                  if (noShift && noShift(view.state, view.dispatch, view))
                      return true;
              }
              if ((event.altKey || event.metaKey || event.ctrlKey) &&
                  // Ctrl-Alt may be used for AltGr on Windows
                  !(windows && event.ctrlKey && event.altKey) &&
                  (baseName = base[event.keyCode]) && baseName != name) {
                  // Try falling back to the keyCode when there's a modifier
                  // active or the character produced isn't ASCII, and our table
                  // produces a different name from the the keyCode. See #668,
                  // #1060, #1529.
                  let fromCode = map[modifiers(baseName, event)];
                  if (fromCode && fromCode(view.state, view.dispatch, view))
                      return true;
              }
          }
          return false;
      };
  }

  // src/index.ts

  // src/tablemap.ts
  var readFromCache;
  var addToCache;
  if (typeof WeakMap != "undefined") {
    let cache = /* @__PURE__ */ new WeakMap();
    readFromCache = (key) => cache.get(key);
    addToCache = (key, value) => {
      cache.set(key, value);
      return value;
    };
  } else {
    const cache = [];
    const cacheSize = 10;
    let cachePos = 0;
    readFromCache = (key) => {
      for (let i = 0; i < cache.length; i += 2)
        if (cache[i] == key) return cache[i + 1];
    };
    addToCache = (key, value) => {
      if (cachePos == cacheSize) cachePos = 0;
      cache[cachePos++] = key;
      return cache[cachePos++] = value;
    };
  }
  var TableMap = class {
    constructor(width, height, map, problems) {
      this.width = width;
      this.height = height;
      this.map = map;
      this.problems = problems;
    }
    // Find the dimensions of the cell at the given position.
    findCell(pos) {
      for (let i = 0; i < this.map.length; i++) {
        const curPos = this.map[i];
        if (curPos != pos) continue;
        const left = i % this.width;
        const top = i / this.width | 0;
        let right = left + 1;
        let bottom = top + 1;
        for (let j = 1; right < this.width && this.map[i + j] == curPos; j++) {
          right++;
        }
        for (let j = 1; bottom < this.height && this.map[i + this.width * j] == curPos; j++) {
          bottom++;
        }
        return { left, top, right, bottom };
      }
      throw new RangeError(`No cell with offset ${pos} found`);
    }
    // Find the left side of the cell at the given position.
    colCount(pos) {
      for (let i = 0; i < this.map.length; i++) {
        if (this.map[i] == pos) {
          return i % this.width;
        }
      }
      throw new RangeError(`No cell with offset ${pos} found`);
    }
    // Find the next cell in the given direction, starting from the cell
    // at `pos`, if any.
    nextCell(pos, axis, dir) {
      const { left, right, top, bottom } = this.findCell(pos);
      if (axis == "horiz") {
        if (dir < 0 ? left == 0 : right == this.width) return null;
        return this.map[top * this.width + (dir < 0 ? left - 1 : right)];
      } else {
        if (dir < 0 ? top == 0 : bottom == this.height) return null;
        return this.map[left + this.width * (dir < 0 ? top - 1 : bottom)];
      }
    }
    // Get the rectangle spanning the two given cells.
    rectBetween(a, b) {
      const {
        left: leftA,
        right: rightA,
        top: topA,
        bottom: bottomA
      } = this.findCell(a);
      const {
        left: leftB,
        right: rightB,
        top: topB,
        bottom: bottomB
      } = this.findCell(b);
      return {
        left: Math.min(leftA, leftB),
        top: Math.min(topA, topB),
        right: Math.max(rightA, rightB),
        bottom: Math.max(bottomA, bottomB)
      };
    }
    // Return the position of all cells that have the top left corner in
    // the given rectangle.
    cellsInRect(rect) {
      const result = [];
      const seen = {};
      for (let row = rect.top; row < rect.bottom; row++) {
        for (let col = rect.left; col < rect.right; col++) {
          const index = row * this.width + col;
          const pos = this.map[index];
          if (seen[pos]) continue;
          seen[pos] = true;
          if (col == rect.left && col && this.map[index - 1] == pos || row == rect.top && row && this.map[index - this.width] == pos) {
            continue;
          }
          result.push(pos);
        }
      }
      return result;
    }
    // Return the position at which the cell at the given row and column
    // starts, or would start, if a cell started there.
    positionAt(row, col, table) {
      for (let i = 0, rowStart = 0; ; i++) {
        const rowEnd = rowStart + table.child(i).nodeSize;
        if (i == row) {
          let index = col + row * this.width;
          const rowEndIndex = (row + 1) * this.width;
          while (index < rowEndIndex && this.map[index] < rowStart) index++;
          return index == rowEndIndex ? rowEnd - 1 : this.map[index];
        }
        rowStart = rowEnd;
      }
    }
    // Find the table map for the given table node.
    static get(table) {
      return readFromCache(table) || addToCache(table, computeMap(table));
    }
  };
  function computeMap(table) {
    if (table.type.spec.tableRole != "table")
      throw new RangeError("Not a table node: " + table.type.name);
    const width = findWidth(table), height = table.childCount;
    const map = [];
    let mapPos = 0;
    let problems = null;
    const colWidths = [];
    for (let i = 0, e = width * height; i < e; i++) map[i] = 0;
    for (let row = 0, pos = 0; row < height; row++) {
      const rowNode = table.child(row);
      pos++;
      for (let i = 0; ; i++) {
        while (mapPos < map.length && map[mapPos] != 0) mapPos++;
        if (i == rowNode.childCount) break;
        const cellNode = rowNode.child(i);
        const { colspan, rowspan, colwidth } = cellNode.attrs;
        for (let h = 0; h < rowspan; h++) {
          if (h + row >= height) {
            (problems || (problems = [])).push({
              type: "overlong_rowspan",
              pos,
              n: rowspan - h
            });
            break;
          }
          const start = mapPos + h * width;
          for (let w = 0; w < colspan; w++) {
            if (map[start + w] == 0) map[start + w] = pos;
            else
              (problems || (problems = [])).push({
                type: "collision",
                row,
                pos,
                n: colspan - w
              });
            const colW = colwidth && colwidth[w];
            if (colW) {
              const widthIndex = (start + w) % width * 2, prev = colWidths[widthIndex];
              if (prev == null || prev != colW && colWidths[widthIndex + 1] == 1) {
                colWidths[widthIndex] = colW;
                colWidths[widthIndex + 1] = 1;
              } else if (prev == colW) {
                colWidths[widthIndex + 1]++;
              }
            }
          }
        }
        mapPos += colspan;
        pos += cellNode.nodeSize;
      }
      const expectedPos = (row + 1) * width;
      let missing = 0;
      while (mapPos < expectedPos) if (map[mapPos++] == 0) missing++;
      if (missing)
        (problems || (problems = [])).push({ type: "missing", row, n: missing });
      pos++;
    }
    if (width === 0 || height === 0)
      (problems || (problems = [])).push({ type: "zero_sized" });
    const tableMap = new TableMap(width, height, map, problems);
    let badWidths = false;
    for (let i = 0; !badWidths && i < colWidths.length; i += 2)
      if (colWidths[i] != null && colWidths[i + 1] < height) badWidths = true;
    if (badWidths) findBadColWidths(tableMap, colWidths, table);
    return tableMap;
  }
  function findWidth(table) {
    let width = -1;
    let hasRowSpan = false;
    for (let row = 0; row < table.childCount; row++) {
      const rowNode = table.child(row);
      let rowWidth = 0;
      if (hasRowSpan)
        for (let j = 0; j < row; j++) {
          const prevRow = table.child(j);
          for (let i = 0; i < prevRow.childCount; i++) {
            const cell = prevRow.child(i);
            if (j + cell.attrs.rowspan > row) rowWidth += cell.attrs.colspan;
          }
        }
      for (let i = 0; i < rowNode.childCount; i++) {
        const cell = rowNode.child(i);
        rowWidth += cell.attrs.colspan;
        if (cell.attrs.rowspan > 1) hasRowSpan = true;
      }
      if (width == -1) width = rowWidth;
      else if (width != rowWidth) width = Math.max(width, rowWidth);
    }
    return width;
  }
  function findBadColWidths(map, colWidths, table) {
    if (!map.problems) map.problems = [];
    const seen = {};
    for (let i = 0; i < map.map.length; i++) {
      const pos = map.map[i];
      if (seen[pos]) continue;
      seen[pos] = true;
      const node = table.nodeAt(pos);
      if (!node) {
        throw new RangeError(`No cell with offset ${pos} found`);
      }
      let updated = null;
      const attrs = node.attrs;
      for (let j = 0; j < attrs.colspan; j++) {
        const col = (i + j) % map.width;
        const colWidth = colWidths[col * 2];
        if (colWidth != null && (!attrs.colwidth || attrs.colwidth[j] != colWidth))
          (updated || (updated = freshColWidth(attrs)))[j] = colWidth;
      }
      if (updated)
        map.problems.unshift({
          type: "colwidth mismatch",
          pos,
          colwidth: updated
        });
    }
  }
  function freshColWidth(attrs) {
    if (attrs.colwidth) return attrs.colwidth.slice();
    const result = [];
    for (let i = 0; i < attrs.colspan; i++) result.push(0);
    return result;
  }

  // src/schema.ts
  function getCellAttrs(dom, extraAttrs) {
    if (typeof dom === "string") {
      return {};
    }
    const widthAttr = dom.getAttribute("data-colwidth");
    const widths = widthAttr && /^\d+(,\d+)*$/.test(widthAttr) ? widthAttr.split(",").map((s) => Number(s)) : null;
    const colspan = Number(dom.getAttribute("colspan") || 1);
    const result = {
      colspan,
      rowspan: Number(dom.getAttribute("rowspan") || 1),
      colwidth: widths && widths.length == colspan ? widths : null
    };
    for (const prop in extraAttrs) {
      const getter = extraAttrs[prop].getFromDOM;
      const value = getter && getter(dom);
      if (value != null) {
        result[prop] = value;
      }
    }
    return result;
  }
  function setCellAttrs(node, extraAttrs) {
    const attrs = {};
    if (node.attrs.colspan != 1) attrs.colspan = node.attrs.colspan;
    if (node.attrs.rowspan != 1) attrs.rowspan = node.attrs.rowspan;
    if (node.attrs.colwidth)
      attrs["data-colwidth"] = node.attrs.colwidth.join(",");
    for (const prop in extraAttrs) {
      const setter = extraAttrs[prop].setDOMAttr;
      if (setter) setter(node.attrs[prop], attrs);
    }
    return attrs;
  }
  function validateColwidth(value) {
    if (value === null) {
      return;
    }
    if (!Array.isArray(value)) {
      throw new TypeError("colwidth must be null or an array");
    }
    for (const item of value) {
      if (typeof item !== "number") {
        throw new TypeError("colwidth must be null or an array of numbers");
      }
    }
  }
  function tableNodes(options) {
    const extraAttrs = options.cellAttributes || {};
    const cellAttrs = {
      colspan: { default: 1, validate: "number" },
      rowspan: { default: 1, validate: "number" },
      colwidth: { default: null, validate: validateColwidth }
    };
    for (const prop in extraAttrs)
      cellAttrs[prop] = {
        default: extraAttrs[prop].default,
        validate: extraAttrs[prop].validate
      };
    return {
      table: {
        content: "table_row+",
        tableRole: "table",
        isolating: true,
        group: options.tableGroup,
        parseDOM: [{ tag: "table" }],
        toDOM() {
          return ["table", ["tbody", 0]];
        }
      },
      table_row: {
        content: "(table_cell | table_header)*",
        tableRole: "row",
        parseDOM: [{ tag: "tr" }],
        toDOM() {
          return ["tr", 0];
        }
      },
      table_cell: {
        content: options.cellContent,
        attrs: cellAttrs,
        tableRole: "cell",
        isolating: true,
        parseDOM: [
          { tag: "td", getAttrs: (dom) => getCellAttrs(dom, extraAttrs) }
        ],
        toDOM(node) {
          return ["td", setCellAttrs(node, extraAttrs), 0];
        }
      },
      table_header: {
        content: options.cellContent,
        attrs: cellAttrs,
        tableRole: "header_cell",
        isolating: true,
        parseDOM: [
          { tag: "th", getAttrs: (dom) => getCellAttrs(dom, extraAttrs) }
        ],
        toDOM(node) {
          return ["th", setCellAttrs(node, extraAttrs), 0];
        }
      }
    };
  }
  function tableNodeTypes(schema) {
    let result = schema.cached.tableNodeTypes;
    if (!result) {
      result = schema.cached.tableNodeTypes = {};
      for (const name in schema.nodes) {
        const type = schema.nodes[name], role = type.spec.tableRole;
        if (role) result[role] = type;
      }
    }
    return result;
  }

  // src/util.ts
  new PluginKey("selectingCells");
  function cellAround($pos) {
    for (let d = $pos.depth - 1; d > 0; d--)
      if ($pos.node(d).type.spec.tableRole == "row")
        return $pos.node(0).resolve($pos.before(d + 1));
    return null;
  }
  function isInTable(state) {
    const $head = state.selection.$head;
    for (let d = $head.depth; d > 0; d--)
      if ($head.node(d).type.spec.tableRole == "row") return true;
    return false;
  }
  function selectionCell(state) {
    const sel = state.selection;
    if ("$anchorCell" in sel && sel.$anchorCell) {
      return sel.$anchorCell.pos > sel.$headCell.pos ? sel.$anchorCell : sel.$headCell;
    } else if ("node" in sel && sel.node && sel.node.type.spec.tableRole == "cell") {
      return sel.$anchor;
    }
    const $cell = cellAround(sel.$head) || cellNear(sel.$head);
    if ($cell) {
      return $cell;
    }
    throw new RangeError(`No cell found around position ${sel.head}`);
  }
  function cellNear($pos) {
    for (let after = $pos.nodeAfter, pos = $pos.pos; after; after = after.firstChild, pos++) {
      const role = after.type.spec.tableRole;
      if (role == "cell" || role == "header_cell") return $pos.doc.resolve(pos);
    }
    for (let before = $pos.nodeBefore, pos = $pos.pos; before; before = before.lastChild, pos--) {
      const role = before.type.spec.tableRole;
      if (role == "cell" || role == "header_cell")
        return $pos.doc.resolve(pos - before.nodeSize);
    }
  }
  function pointsAtCell($pos) {
    return $pos.parent.type.spec.tableRole == "row" && !!$pos.nodeAfter;
  }
  function moveCellForward($pos) {
    return $pos.node(0).resolve($pos.pos + $pos.nodeAfter.nodeSize);
  }
  function inSameTable($cellA, $cellB) {
    return $cellA.depth == $cellB.depth && $cellA.pos >= $cellB.start(-1) && $cellA.pos <= $cellB.end(-1);
  }
  function nextCell($pos, axis, dir) {
    const table = $pos.node(-1);
    const map = TableMap.get(table);
    const tableStart = $pos.start(-1);
    const moved = map.nextCell($pos.pos - tableStart, axis, dir);
    return moved == null ? null : $pos.node(0).resolve(tableStart + moved);
  }
  function removeColSpan(attrs, pos, n = 1) {
    const result = { ...attrs, colspan: attrs.colspan - n };
    if (result.colwidth) {
      result.colwidth = result.colwidth.slice();
      result.colwidth.splice(pos, n);
      if (!result.colwidth.some((w) => w > 0)) result.colwidth = null;
    }
    return result;
  }
  function addColSpan(attrs, pos, n = 1) {
    const result = { ...attrs, colspan: attrs.colspan + n };
    if (result.colwidth) {
      result.colwidth = result.colwidth.slice();
      for (let i = 0; i < n; i++) result.colwidth.splice(pos, 0, 0);
    }
    return result;
  }
  function columnIsHeader(map, table, col) {
    const headerCell = tableNodeTypes(table.type.schema).header_cell;
    for (let row = 0; row < map.height; row++)
      if (table.nodeAt(map.map[col + row * map.width]).type != headerCell)
        return false;
    return true;
  }

  // src/cellselection.ts
  var CellSelection = class _CellSelection extends Selection {
    // A table selection is identified by its anchor and head cells. The
    // positions given to this constructor should point _before_ two
    // cells in the same table. They may be the same, to select a single
    // cell.
    constructor($anchorCell, $headCell = $anchorCell) {
      const table = $anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = $anchorCell.start(-1);
      const rect = map.rectBetween(
        $anchorCell.pos - tableStart,
        $headCell.pos - tableStart
      );
      const doc = $anchorCell.node(0);
      const cells = map.cellsInRect(rect).filter((p) => p != $headCell.pos - tableStart);
      cells.unshift($headCell.pos - tableStart);
      const ranges = cells.map((pos) => {
        const cell = table.nodeAt(pos);
        if (!cell) {
          throw RangeError(`No cell with offset ${pos} found`);
        }
        const from = tableStart + pos + 1;
        return new SelectionRange(
          doc.resolve(from),
          doc.resolve(from + cell.content.size)
        );
      });
      super(ranges[0].$from, ranges[0].$to, ranges);
      this.$anchorCell = $anchorCell;
      this.$headCell = $headCell;
    }
    map(doc, mapping) {
      const $anchorCell = doc.resolve(mapping.map(this.$anchorCell.pos));
      const $headCell = doc.resolve(mapping.map(this.$headCell.pos));
      if (pointsAtCell($anchorCell) && pointsAtCell($headCell) && inSameTable($anchorCell, $headCell)) {
        const tableChanged = this.$anchorCell.node(-1) != $anchorCell.node(-1);
        if (tableChanged && this.isRowSelection())
          return _CellSelection.rowSelection($anchorCell, $headCell);
        else if (tableChanged && this.isColSelection())
          return _CellSelection.colSelection($anchorCell, $headCell);
        else return new _CellSelection($anchorCell, $headCell);
      }
      return TextSelection.between($anchorCell, $headCell);
    }
    // Returns a rectangular slice of table rows containing the selected
    // cells.
    content() {
      const table = this.$anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = this.$anchorCell.start(-1);
      const rect = map.rectBetween(
        this.$anchorCell.pos - tableStart,
        this.$headCell.pos - tableStart
      );
      const seen = {};
      const rows = [];
      for (let row = rect.top; row < rect.bottom; row++) {
        const rowContent = [];
        for (let index = row * map.width + rect.left, col = rect.left; col < rect.right; col++, index++) {
          const pos = map.map[index];
          if (seen[pos]) continue;
          seen[pos] = true;
          const cellRect = map.findCell(pos);
          let cell = table.nodeAt(pos);
          if (!cell) {
            throw RangeError(`No cell with offset ${pos} found`);
          }
          const extraLeft = rect.left - cellRect.left;
          const extraRight = cellRect.right - rect.right;
          if (extraLeft > 0 || extraRight > 0) {
            let attrs = cell.attrs;
            if (extraLeft > 0) {
              attrs = removeColSpan(attrs, 0, extraLeft);
            }
            if (extraRight > 0) {
              attrs = removeColSpan(
                attrs,
                attrs.colspan - extraRight,
                extraRight
              );
            }
            if (cellRect.left < rect.left) {
              cell = cell.type.createAndFill(attrs);
              if (!cell) {
                throw RangeError(
                  `Could not create cell with attrs ${JSON.stringify(attrs)}`
                );
              }
            } else {
              cell = cell.type.create(attrs, cell.content);
            }
          }
          if (cellRect.top < rect.top || cellRect.bottom > rect.bottom) {
            const attrs = {
              ...cell.attrs,
              rowspan: Math.min(cellRect.bottom, rect.bottom) - Math.max(cellRect.top, rect.top)
            };
            if (cellRect.top < rect.top) {
              cell = cell.type.createAndFill(attrs);
            } else {
              cell = cell.type.create(attrs, cell.content);
            }
          }
          rowContent.push(cell);
        }
        rows.push(table.child(row).copy(Fragment.from(rowContent)));
      }
      const fragment = this.isColSelection() && this.isRowSelection() ? table : rows;
      return new Slice(Fragment.from(fragment), 1, 1);
    }
    replace(tr, content = Slice.empty) {
      const mapFrom = tr.steps.length, ranges = this.ranges;
      for (let i = 0; i < ranges.length; i++) {
        const { $from, $to } = ranges[i], mapping = tr.mapping.slice(mapFrom);
        tr.replace(
          mapping.map($from.pos),
          mapping.map($to.pos),
          i ? Slice.empty : content
        );
      }
      const sel = Selection.findFrom(
        tr.doc.resolve(tr.mapping.slice(mapFrom).map(this.to)),
        -1
      );
      if (sel) tr.setSelection(sel);
    }
    replaceWith(tr, node) {
      this.replace(tr, new Slice(Fragment.from(node), 0, 0));
    }
    forEachCell(f) {
      const table = this.$anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = this.$anchorCell.start(-1);
      const cells = map.cellsInRect(
        map.rectBetween(
          this.$anchorCell.pos - tableStart,
          this.$headCell.pos - tableStart
        )
      );
      for (let i = 0; i < cells.length; i++) {
        f(table.nodeAt(cells[i]), tableStart + cells[i]);
      }
    }
    // True if this selection goes all the way from the top to the
    // bottom of the table.
    isColSelection() {
      const anchorTop = this.$anchorCell.index(-1);
      const headTop = this.$headCell.index(-1);
      if (Math.min(anchorTop, headTop) > 0) return false;
      const anchorBottom = anchorTop + this.$anchorCell.nodeAfter.attrs.rowspan;
      const headBottom = headTop + this.$headCell.nodeAfter.attrs.rowspan;
      return Math.max(anchorBottom, headBottom) == this.$headCell.node(-1).childCount;
    }
    // Returns the smallest column selection that covers the given anchor
    // and head cell.
    static colSelection($anchorCell, $headCell = $anchorCell) {
      const table = $anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = $anchorCell.start(-1);
      const anchorRect = map.findCell($anchorCell.pos - tableStart);
      const headRect = map.findCell($headCell.pos - tableStart);
      const doc = $anchorCell.node(0);
      if (anchorRect.top <= headRect.top) {
        if (anchorRect.top > 0)
          $anchorCell = doc.resolve(tableStart + map.map[anchorRect.left]);
        if (headRect.bottom < map.height)
          $headCell = doc.resolve(
            tableStart + map.map[map.width * (map.height - 1) + headRect.right - 1]
          );
      } else {
        if (headRect.top > 0)
          $headCell = doc.resolve(tableStart + map.map[headRect.left]);
        if (anchorRect.bottom < map.height)
          $anchorCell = doc.resolve(
            tableStart + map.map[map.width * (map.height - 1) + anchorRect.right - 1]
          );
      }
      return new _CellSelection($anchorCell, $headCell);
    }
    // True if this selection goes all the way from the left to the
    // right of the table.
    isRowSelection() {
      const table = this.$anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = this.$anchorCell.start(-1);
      const anchorLeft = map.colCount(this.$anchorCell.pos - tableStart);
      const headLeft = map.colCount(this.$headCell.pos - tableStart);
      if (Math.min(anchorLeft, headLeft) > 0) return false;
      const anchorRight = anchorLeft + this.$anchorCell.nodeAfter.attrs.colspan;
      const headRight = headLeft + this.$headCell.nodeAfter.attrs.colspan;
      return Math.max(anchorRight, headRight) == map.width;
    }
    eq(other) {
      return other instanceof _CellSelection && other.$anchorCell.pos == this.$anchorCell.pos && other.$headCell.pos == this.$headCell.pos;
    }
    // Returns the smallest row selection that covers the given anchor
    // and head cell.
    static rowSelection($anchorCell, $headCell = $anchorCell) {
      const table = $anchorCell.node(-1);
      const map = TableMap.get(table);
      const tableStart = $anchorCell.start(-1);
      const anchorRect = map.findCell($anchorCell.pos - tableStart);
      const headRect = map.findCell($headCell.pos - tableStart);
      const doc = $anchorCell.node(0);
      if (anchorRect.left <= headRect.left) {
        if (anchorRect.left > 0)
          $anchorCell = doc.resolve(
            tableStart + map.map[anchorRect.top * map.width]
          );
        if (headRect.right < map.width)
          $headCell = doc.resolve(
            tableStart + map.map[map.width * (headRect.top + 1) - 1]
          );
      } else {
        if (headRect.left > 0)
          $headCell = doc.resolve(tableStart + map.map[headRect.top * map.width]);
        if (anchorRect.right < map.width)
          $anchorCell = doc.resolve(
            tableStart + map.map[map.width * (anchorRect.top + 1) - 1]
          );
      }
      return new _CellSelection($anchorCell, $headCell);
    }
    toJSON() {
      return {
        type: "cell",
        anchor: this.$anchorCell.pos,
        head: this.$headCell.pos
      };
    }
    static fromJSON(doc, json) {
      return new _CellSelection(doc.resolve(json.anchor), doc.resolve(json.head));
    }
    static create(doc, anchorCell, headCell = anchorCell) {
      return new _CellSelection(doc.resolve(anchorCell), doc.resolve(headCell));
    }
    getBookmark() {
      return new CellBookmark(this.$anchorCell.pos, this.$headCell.pos);
    }
  };
  CellSelection.prototype.visible = false;
  Selection.jsonID("cell", CellSelection);
  var CellBookmark = class _CellBookmark {
    constructor(anchor, head) {
      this.anchor = anchor;
      this.head = head;
    }
    map(mapping) {
      return new _CellBookmark(mapping.map(this.anchor), mapping.map(this.head));
    }
    resolve(doc) {
      const $anchorCell = doc.resolve(this.anchor), $headCell = doc.resolve(this.head);
      if ($anchorCell.parent.type.spec.tableRole == "row" && $headCell.parent.type.spec.tableRole == "row" && $anchorCell.index() < $anchorCell.parent.childCount && $headCell.index() < $headCell.parent.childCount && inSameTable($anchorCell, $headCell))
        return new CellSelection($anchorCell, $headCell);
      else return Selection.near($headCell, 1);
    }
  };
  new PluginKey("fix-tables");

  // src/commands.ts
  function selectedRect(state) {
    const sel = state.selection;
    const $pos = selectionCell(state);
    const table = $pos.node(-1);
    const tableStart = $pos.start(-1);
    const map = TableMap.get(table);
    const rect = sel instanceof CellSelection ? map.rectBetween(
      sel.$anchorCell.pos - tableStart,
      sel.$headCell.pos - tableStart
    ) : map.findCell($pos.pos - tableStart);
    return { ...rect, tableStart, map, table };
  }
  function addColumn(tr, { map, tableStart, table }, col) {
    let refColumn = col > 0 ? -1 : 0;
    if (columnIsHeader(map, table, col + refColumn)) {
      refColumn = col == 0 || col == map.width ? null : 0;
    }
    for (let row = 0; row < map.height; row++) {
      const index = row * map.width + col;
      if (col > 0 && col < map.width && map.map[index - 1] == map.map[index]) {
        const pos = map.map[index];
        const cell = table.nodeAt(pos);
        tr.setNodeMarkup(
          tr.mapping.map(tableStart + pos),
          null,
          addColSpan(cell.attrs, col - map.colCount(pos))
        );
        row += cell.attrs.rowspan - 1;
      } else {
        const type = refColumn == null ? tableNodeTypes(table.type.schema).cell : table.nodeAt(map.map[index + refColumn]).type;
        const pos = map.positionAt(row, col, table);
        tr.insert(tr.mapping.map(tableStart + pos), type.createAndFill());
      }
    }
    return tr;
  }
  function addColumnBefore(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state);
      dispatch(addColumn(state.tr, rect, rect.left));
    }
    return true;
  }
  function addColumnAfter(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state);
      dispatch(addColumn(state.tr, rect, rect.right));
    }
    return true;
  }
  function removeColumn(tr, { map, table, tableStart }, col) {
    const mapStart = tr.mapping.maps.length;
    for (let row = 0; row < map.height; ) {
      const index = row * map.width + col;
      const pos = map.map[index];
      const cell = table.nodeAt(pos);
      const attrs = cell.attrs;
      if (col > 0 && map.map[index - 1] == pos || col < map.width - 1 && map.map[index + 1] == pos) {
        tr.setNodeMarkup(
          tr.mapping.slice(mapStart).map(tableStart + pos),
          null,
          removeColSpan(attrs, col - map.colCount(pos))
        );
      } else {
        const start = tr.mapping.slice(mapStart).map(tableStart + pos);
        tr.delete(start, start + cell.nodeSize);
      }
      row += attrs.rowspan;
    }
  }
  function deleteColumn(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state);
      const tr = state.tr;
      if (rect.left == 0 && rect.right == rect.map.width) return false;
      for (let i = rect.right - 1; ; i--) {
        removeColumn(tr, rect, i);
        if (i == rect.left) break;
        const table = rect.tableStart ? tr.doc.nodeAt(rect.tableStart - 1) : tr.doc;
        if (!table) {
          throw RangeError("No table found");
        }
        rect.table = table;
        rect.map = TableMap.get(table);
      }
      dispatch(tr);
    }
    return true;
  }
  function rowIsHeader(map, table, row) {
    var _a;
    const headerCell = tableNodeTypes(table.type.schema).header_cell;
    for (let col = 0; col < map.width; col++)
      if (((_a = table.nodeAt(map.map[col + row * map.width])) == null ? void 0 : _a.type) != headerCell)
        return false;
    return true;
  }
  function addRow$1(tr, { map, tableStart, table }, row) {
    var _a;
    let rowPos = tableStart;
    for (let i = 0; i < row; i++) rowPos += table.child(i).nodeSize;
    const cells = [];
    let refRow = row > 0 ? -1 : 0;
    if (rowIsHeader(map, table, row + refRow))
      refRow = row == 0 || row == map.height ? null : 0;
    for (let col = 0, index = map.width * row; col < map.width; col++, index++) {
      if (row > 0 && row < map.height && map.map[index] == map.map[index - map.width]) {
        const pos = map.map[index];
        const attrs = table.nodeAt(pos).attrs;
        tr.setNodeMarkup(tableStart + pos, null, {
          ...attrs,
          rowspan: attrs.rowspan + 1
        });
        col += attrs.colspan - 1;
      } else {
        const type = refRow == null ? tableNodeTypes(table.type.schema).cell : (_a = table.nodeAt(map.map[index + refRow * map.width])) == null ? void 0 : _a.type;
        const node = type == null ? void 0 : type.createAndFill();
        if (node) cells.push(node);
      }
    }
    tr.insert(rowPos, tableNodeTypes(table.type.schema).row.create(null, cells));
    return tr;
  }
  function addRowBefore(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state);
      dispatch(addRow$1(state.tr, rect, rect.top));
    }
    return true;
  }
  function addRowAfter(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state);
      dispatch(addRow$1(state.tr, rect, rect.bottom));
    }
    return true;
  }
  function removeRow(tr, { map, table, tableStart }, row) {
    let rowPos = 0;
    for (let i = 0; i < row; i++) rowPos += table.child(i).nodeSize;
    const nextRow = rowPos + table.child(row).nodeSize;
    const mapFrom = tr.mapping.maps.length;
    tr.delete(rowPos + tableStart, nextRow + tableStart);
    const seen = /* @__PURE__ */ new Set();
    for (let col = 0, index = row * map.width; col < map.width; col++, index++) {
      const pos = map.map[index];
      if (seen.has(pos)) continue;
      seen.add(pos);
      if (row > 0 && pos == map.map[index - map.width]) {
        const attrs = table.nodeAt(pos).attrs;
        tr.setNodeMarkup(tr.mapping.slice(mapFrom).map(pos + tableStart), null, {
          ...attrs,
          rowspan: attrs.rowspan - 1
        });
        col += attrs.colspan - 1;
      } else if (row < map.height && pos == map.map[index + map.width]) {
        const cell = table.nodeAt(pos);
        const attrs = cell.attrs;
        const copy = cell.type.create(
          { ...attrs, rowspan: cell.attrs.rowspan - 1 },
          cell.content
        );
        const newPos = map.positionAt(row + 1, col, table);
        tr.insert(tr.mapping.slice(mapFrom).map(tableStart + newPos), copy);
        col += attrs.colspan - 1;
      }
    }
  }
  function deleteRow(state, dispatch) {
    if (!isInTable(state)) return false;
    if (dispatch) {
      const rect = selectedRect(state), tr = state.tr;
      if (rect.top == 0 && rect.bottom == rect.map.height) return false;
      for (let i = rect.bottom - 1; ; i--) {
        removeRow(tr, rect, i);
        if (i == rect.top) break;
        const table = rect.tableStart ? tr.doc.nodeAt(rect.tableStart - 1) : tr.doc;
        if (!table) {
          throw RangeError("No table found");
        }
        rect.table = table;
        rect.map = TableMap.get(rect.table);
      }
      dispatch(tr);
    }
    return true;
  }
  function isEmpty(cell) {
    const c = cell.content;
    return c.childCount == 1 && c.child(0).isTextblock && c.child(0).childCount == 0;
  }
  function cellsOverlapRectangle({ width, height, map }, rect) {
    let indexTop = rect.top * width + rect.left, indexLeft = indexTop;
    let indexBottom = (rect.bottom - 1) * width + rect.left, indexRight = indexTop + (rect.right - rect.left - 1);
    for (let i = rect.top; i < rect.bottom; i++) {
      if (rect.left > 0 && map[indexLeft] == map[indexLeft - 1] || rect.right < width && map[indexRight] == map[indexRight + 1])
        return true;
      indexLeft += width;
      indexRight += width;
    }
    for (let i = rect.left; i < rect.right; i++) {
      if (rect.top > 0 && map[indexTop] == map[indexTop - width] || rect.bottom < height && map[indexBottom] == map[indexBottom + width])
        return true;
      indexTop++;
      indexBottom++;
    }
    return false;
  }
  function mergeCells(state, dispatch) {
    const sel = state.selection;
    if (!(sel instanceof CellSelection) || sel.$anchorCell.pos == sel.$headCell.pos)
      return false;
    const rect = selectedRect(state), { map } = rect;
    if (cellsOverlapRectangle(map, rect)) return false;
    if (dispatch) {
      const tr = state.tr;
      const seen = {};
      let content = Fragment.empty;
      let mergedPos;
      let mergedCell;
      for (let row = rect.top; row < rect.bottom; row++) {
        for (let col = rect.left; col < rect.right; col++) {
          const cellPos = map.map[row * map.width + col];
          const cell = rect.table.nodeAt(cellPos);
          if (seen[cellPos] || !cell) continue;
          seen[cellPos] = true;
          if (mergedPos == null) {
            mergedPos = cellPos;
            mergedCell = cell;
          } else {
            if (!isEmpty(cell)) content = content.append(cell.content);
            const mapped = tr.mapping.map(cellPos + rect.tableStart);
            tr.delete(mapped, mapped + cell.nodeSize);
          }
        }
      }
      if (mergedPos == null || mergedCell == null) {
        return true;
      }
      tr.setNodeMarkup(mergedPos + rect.tableStart, null, {
        ...addColSpan(
          mergedCell.attrs,
          mergedCell.attrs.colspan,
          rect.right - rect.left - mergedCell.attrs.colspan
        ),
        rowspan: rect.bottom - rect.top
      });
      if (content.size) {
        const end = mergedPos + 1 + mergedCell.content.size;
        const start = isEmpty(mergedCell) ? mergedPos + 1 : end;
        tr.replaceWith(start + rect.tableStart, end + rect.tableStart, content);
      }
      tr.setSelection(
        new CellSelection(tr.doc.resolve(mergedPos + rect.tableStart))
      );
      dispatch(tr);
    }
    return true;
  }
  function deprecated_toggleHeader(type) {
    return function(state, dispatch) {
      if (!isInTable(state)) return false;
      if (dispatch) {
        const types = tableNodeTypes(state.schema);
        const rect = selectedRect(state), tr = state.tr;
        const cells = rect.map.cellsInRect(
          type == "column" ? {
            left: rect.left,
            top: 0,
            right: rect.right,
            bottom: rect.map.height
          } : type == "row" ? {
            left: 0,
            top: rect.top,
            right: rect.map.width,
            bottom: rect.bottom
          } : rect
        );
        const nodes = cells.map((pos) => rect.table.nodeAt(pos));
        for (let i = 0; i < cells.length; i++)
          if (nodes[i].type == types.header_cell)
            tr.setNodeMarkup(
              rect.tableStart + cells[i],
              types.cell,
              nodes[i].attrs
            );
        if (tr.steps.length == 0)
          for (let i = 0; i < cells.length; i++)
            tr.setNodeMarkup(
              rect.tableStart + cells[i],
              types.header_cell,
              nodes[i].attrs
            );
        dispatch(tr);
      }
      return true;
    };
  }
  function isHeaderEnabledByType(type, rect, types) {
    const cellPositions = rect.map.cellsInRect({
      left: 0,
      top: 0,
      right: type == "row" ? rect.map.width : 1,
      bottom: type == "column" ? rect.map.height : 1
    });
    for (let i = 0; i < cellPositions.length; i++) {
      const cell = rect.table.nodeAt(cellPositions[i]);
      if (cell && cell.type !== types.header_cell) {
        return false;
      }
    }
    return true;
  }
  function toggleHeader(type, options) {
    options = options || { useDeprecatedLogic: false };
    if (options.useDeprecatedLogic) return deprecated_toggleHeader(type);
    return function(state, dispatch) {
      if (!isInTable(state)) return false;
      if (dispatch) {
        const types = tableNodeTypes(state.schema);
        const rect = selectedRect(state), tr = state.tr;
        const isHeaderRowEnabled = isHeaderEnabledByType("row", rect, types);
        const isHeaderColumnEnabled = isHeaderEnabledByType(
          "column",
          rect,
          types
        );
        const isHeaderEnabled = type === "column" ? isHeaderRowEnabled : type === "row" ? isHeaderColumnEnabled : false;
        const selectionStartsAt = isHeaderEnabled ? 1 : 0;
        const cellsRect = type == "column" ? {
          left: 0,
          top: selectionStartsAt,
          right: 1,
          bottom: rect.map.height
        } : type == "row" ? {
          left: selectionStartsAt,
          top: 0,
          right: rect.map.width,
          bottom: 1
        } : rect;
        const newType = type == "column" ? isHeaderColumnEnabled ? types.cell : types.header_cell : type == "row" ? isHeaderRowEnabled ? types.cell : types.header_cell : types.cell;
        rect.map.cellsInRect(cellsRect).forEach((relativeCellPos) => {
          const cellPos = relativeCellPos + rect.tableStart;
          const cell = tr.doc.nodeAt(cellPos);
          if (cell) {
            tr.setNodeMarkup(cellPos, newType, cell.attrs);
          }
        });
        dispatch(tr);
      }
      return true;
    };
  }
  var toggleHeaderRow = toggleHeader("row", {
    useDeprecatedLogic: true
  });
  toggleHeader("column", {
    useDeprecatedLogic: true
  });
  toggleHeader("cell", {
    useDeprecatedLogic: true
  });
  function findNextCell($cell, dir) {
    if (dir < 0) {
      const before = $cell.nodeBefore;
      if (before) return $cell.pos - before.nodeSize;
      for (let row = $cell.index(-1) - 1, rowEnd = $cell.before(); row >= 0; row--) {
        const rowNode = $cell.node(-1).child(row);
        const lastChild = rowNode.lastChild;
        if (lastChild) {
          return rowEnd - 1 - lastChild.nodeSize;
        }
        rowEnd -= rowNode.nodeSize;
      }
    } else {
      if ($cell.index() < $cell.parent.childCount - 1) {
        return $cell.pos + $cell.nodeAfter.nodeSize;
      }
      const table = $cell.node(-1);
      for (let row = $cell.indexAfter(-1), rowStart = $cell.after(); row < table.childCount; row++) {
        const rowNode = table.child(row);
        if (rowNode.childCount) return rowStart + 1;
        rowStart += rowNode.nodeSize;
      }
    }
    return null;
  }
  function goToNextCell(direction) {
    return function(state, dispatch) {
      if (!isInTable(state)) return false;
      const cell = findNextCell(selectionCell(state), direction);
      if (cell == null) return false;
      if (dispatch) {
        const $cell = state.doc.resolve(cell);
        dispatch(
          state.tr.setSelection(TextSelection.between($cell, moveCellForward($cell))).scrollIntoView()
        );
      }
      return true;
    };
  }
  function deleteTable(state, dispatch) {
    const $pos = state.selection.$anchor;
    for (let d = $pos.depth; d > 0; d--) {
      const node = $pos.node(d);
      if (node.type.spec.tableRole == "table") {
        if (dispatch)
          dispatch(
            state.tr.delete($pos.before(d), $pos.after(d)).scrollIntoView()
          );
        return true;
      }
    }
    return false;
  }
  function deleteCellSelection(state, dispatch) {
    const sel = state.selection;
    if (!(sel instanceof CellSelection)) return false;
    if (dispatch) {
      const tr = state.tr;
      const baseContent = tableNodeTypes(state.schema).cell.createAndFill().content;
      sel.forEachCell((cell, pos) => {
        if (!cell.content.eq(baseContent))
          tr.replace(
            tr.mapping.map(pos + 1),
            tr.mapping.map(pos + cell.nodeSize - 1),
            new Slice(baseContent, 0, 0)
          );
      });
      if (tr.docChanged) dispatch(tr);
    }
    return true;
  }

  // src/input.ts
  keydownHandler({
    ArrowLeft: arrow$1("horiz", -1),
    ArrowRight: arrow$1("horiz", 1),
    ArrowUp: arrow$1("vert", -1),
    ArrowDown: arrow$1("vert", 1),
    "Shift-ArrowLeft": shiftArrow("horiz", -1),
    "Shift-ArrowRight": shiftArrow("horiz", 1),
    "Shift-ArrowUp": shiftArrow("vert", -1),
    "Shift-ArrowDown": shiftArrow("vert", 1),
    Backspace: deleteCellSelection,
    "Mod-Backspace": deleteCellSelection,
    Delete: deleteCellSelection,
    "Mod-Delete": deleteCellSelection
  });
  function maybeSetSelection(state, dispatch, selection) {
    if (selection.eq(state.selection)) return false;
    if (dispatch) dispatch(state.tr.setSelection(selection).scrollIntoView());
    return true;
  }
  function arrow$1(axis, dir) {
    return (state, dispatch, view) => {
      if (!view) return false;
      const sel = state.selection;
      if (sel instanceof CellSelection) {
        return maybeSetSelection(
          state,
          dispatch,
          Selection.near(sel.$headCell, dir)
        );
      }
      if (axis != "horiz" && !sel.empty) return false;
      const end = atEndOfCell(view, axis, dir);
      if (end == null) return false;
      if (axis == "horiz") {
        return maybeSetSelection(
          state,
          dispatch,
          Selection.near(state.doc.resolve(sel.head + dir), dir)
        );
      } else {
        const $cell = state.doc.resolve(end);
        const $next = nextCell($cell, axis, dir);
        let newSel;
        if ($next) newSel = Selection.near($next, 1);
        else if (dir < 0)
          newSel = Selection.near(state.doc.resolve($cell.before(-1)), -1);
        else newSel = Selection.near(state.doc.resolve($cell.after(-1)), 1);
        return maybeSetSelection(state, dispatch, newSel);
      }
    };
  }
  function shiftArrow(axis, dir) {
    return (state, dispatch, view) => {
      if (!view) return false;
      const sel = state.selection;
      let cellSel;
      if (sel instanceof CellSelection) {
        cellSel = sel;
      } else {
        const end = atEndOfCell(view, axis, dir);
        if (end == null) return false;
        cellSel = new CellSelection(state.doc.resolve(end));
      }
      const $head = nextCell(cellSel.$headCell, axis, dir);
      if (!$head) return false;
      return maybeSetSelection(
        state,
        dispatch,
        new CellSelection(cellSel.$anchorCell, $head)
      );
    };
  }
  function atEndOfCell(view, axis, dir) {
    if (!(view.state.selection instanceof TextSelection)) return null;
    const { $head } = view.state.selection;
    for (let d = $head.depth - 1; d >= 0; d--) {
      const parent = $head.node(d), index = dir < 0 ? $head.index(d) : $head.indexAfter(d);
      if (index != (dir < 0 ? 0 : parent.childCount)) return null;
      if (parent.type.spec.tableRole == "cell" || parent.type.spec.tableRole == "header_cell") {
        const cellPos = $head.before(d);
        const dirStr = axis == "vert" ? dir > 0 ? "down" : "up" : dir > 0 ? "right" : "left";
        return view.endOfTextblock(dirStr) ? cellPos : null;
      }
    }
    return null;
  }

  // src/columnresizing.ts
  new PluginKey(
    "tableColumnResizing"
  );

  const olDOM = ["ol", 0], ulDOM = ["ul", 0], liDOM = ["li", 0];
  /**
  An ordered list [node spec](https://prosemirror.net/docs/ref/#model.NodeSpec). Has a single
  attribute, `order`, which determines the number at which the list
  starts counting, and defaults to 1. Represented as an `<ol>`
  element.
  */
  const orderedList = {
      attrs: { order: { default: 1, validate: "number" } },
      parseDOM: [{ tag: "ol", getAttrs(dom) {
                  return { order: dom.hasAttribute("start") ? +dom.getAttribute("start") : 1 };
              } }],
      toDOM(node) {
          return node.attrs.order == 1 ? olDOM : ["ol", { start: node.attrs.order }, 0];
      }
  };
  /**
  A bullet list node spec, represented in the DOM as `<ul>`.
  */
  const bulletList = {
      parseDOM: [{ tag: "ul" }],
      toDOM() { return ulDOM; }
  };
  /**
  A list item (`<li>`) spec.
  */
  const listItem = {
      parseDOM: [{ tag: "li" }],
      toDOM() { return liDOM; },
      defining: true
  };
  function add$1(obj, props) {
      let copy = {};
      for (let prop in obj)
          copy[prop] = obj[prop];
      for (let prop in props)
          copy[prop] = props[prop];
      return copy;
  }
  /**
  Convenience function for adding list-related node types to a map
  specifying the nodes for a schema. Adds
  [`orderedList`](https://prosemirror.net/docs/ref/#schema-list.orderedList) as `"ordered_list"`,
  [`bulletList`](https://prosemirror.net/docs/ref/#schema-list.bulletList) as `"bullet_list"`, and
  [`listItem`](https://prosemirror.net/docs/ref/#schema-list.listItem) as `"list_item"`.

  `itemContent` determines the content expression for the list items.
  If you want the commands defined in this module to apply to your
  list structure, it should have a shape like `"paragraph block*"` or
  `"paragraph (ordered_list | bullet_list)*"`. `listGroup` can be
  given to assign a group name to the list node types, for example
  `"block"`.
  */
  function addListNodes(nodes, itemContent, listGroup) {
      return nodes.append({
          ordered_list: add$1(orderedList, { content: "list_item+", group: listGroup }),
          bullet_list: add$1(bulletList, { content: "list_item+", group: listGroup }),
          list_item: add$1(listItem, { content: itemContent })
      });
  }
  /**
  Returns a command function that wraps the selection in a list with
  the given type an attributes. If `dispatch` is null, only return a
  value to indicate whether this is possible, but don't actually
  perform the change.
  */
  function wrapInList(listType, attrs = null) {
      return function (state, dispatch) {
          let { $from, $to } = state.selection;
          let range = $from.blockRange($to);
          if (!range)
              return false;
          let tr = dispatch ? state.tr : null;
          if (!wrapRangeInList(tr, range, listType, attrs))
              return false;
          if (dispatch)
              dispatch(tr.scrollIntoView());
          return true;
      };
  }
  /**
  Try to wrap the given node range in a list of the given type.
  Return `true` when this is possible, `false` otherwise. When `tr`
  is non-null, the wrapping is added to that transaction. When it is
  `null`, the function only queries whether the wrapping is
  possible.
  */
  function wrapRangeInList(tr, range, listType, attrs = null) {
      let doJoin = false, outerRange = range, doc = range.$from.doc;
      // This is at the top of an existing list item
      if (range.depth >= 2 && range.$from.node(range.depth - 1).type.compatibleContent(listType) && range.startIndex == 0) {
          // Don't do anything if this is the top of the list
          if (range.$from.index(range.depth - 1) == 0)
              return false;
          let $insert = doc.resolve(range.start - 2);
          outerRange = new NodeRange($insert, $insert, range.depth);
          if (range.endIndex < range.parent.childCount)
              range = new NodeRange(range.$from, doc.resolve(range.$to.end(range.depth)), range.depth);
          doJoin = true;
      }
      let wrap = findWrapping(outerRange, listType, attrs, range);
      if (!wrap)
          return false;
      if (tr)
          doWrapInList(tr, range, wrap, doJoin, listType);
      return true;
  }
  function doWrapInList(tr, range, wrappers, joinBefore, listType) {
      let content = Fragment.empty;
      for (let i = wrappers.length - 1; i >= 0; i--)
          content = Fragment.from(wrappers[i].type.create(wrappers[i].attrs, content));
      tr.step(new ReplaceAroundStep(range.start - (joinBefore ? 2 : 0), range.end, range.start, range.end, new Slice(content, 0, 0), wrappers.length, true));
      let found = 0;
      for (let i = 0; i < wrappers.length; i++)
          if (wrappers[i].type == listType)
              found = i + 1;
      let splitDepth = wrappers.length - found;
      let splitPos = range.start + wrappers.length - (joinBefore ? 2 : 0), parent = range.parent;
      for (let i = range.startIndex, e = range.endIndex, first = true; i < e; i++, first = false) {
          if (!first && canSplit(tr.doc, splitPos, splitDepth)) {
              tr.split(splitPos, splitDepth);
              splitPos += 2 * splitDepth;
          }
          splitPos += parent.child(i).nodeSize;
      }
      return tr;
  }
  /**
  Build a command that splits a non-empty textblock at the top level
  of a list item by also splitting that list item.
  */
  function splitListItem(itemType, itemAttrs) {
      return function (state, dispatch) {
          let { $from, $to, node } = state.selection;
          if ((node && node.isBlock) || $from.depth < 2 || !$from.sameParent($to))
              return false;
          let grandParent = $from.node(-1);
          if (grandParent.type != itemType)
              return false;
          if ($from.parent.content.size == 0 && $from.node(-1).childCount == $from.indexAfter(-1)) {
              // In an empty block. If this is a nested list, the wrapping
              // list item should be split. Otherwise, bail out and let next
              // command handle lifting.
              if ($from.depth == 3 || $from.node(-3).type != itemType ||
                  $from.index(-2) != $from.node(-2).childCount - 1)
                  return false;
              if (dispatch) {
                  let wrap = Fragment.empty;
                  let depthBefore = $from.index(-1) ? 1 : $from.index(-2) ? 2 : 3;
                  // Build a fragment containing empty versions of the structure
                  // from the outer list item to the parent node of the cursor
                  for (let d = $from.depth - depthBefore; d >= $from.depth - 3; d--)
                      wrap = Fragment.from($from.node(d).copy(wrap));
                  let depthAfter = $from.indexAfter(-1) < $from.node(-2).childCount ? 1
                      : $from.indexAfter(-2) < $from.node(-3).childCount ? 2 : 3;
                  // Add a second list item with an empty default start node
                  wrap = wrap.append(Fragment.from(itemType.createAndFill()));
                  let start = $from.before($from.depth - (depthBefore - 1));
                  let tr = state.tr.replace(start, $from.after(-depthAfter), new Slice(wrap, 4 - depthBefore, 0));
                  let sel = -1;
                  tr.doc.nodesBetween(start, tr.doc.content.size, (node, pos) => {
                      if (sel > -1)
                          return false;
                      if (node.isTextblock && node.content.size == 0)
                          sel = pos + 1;
                  });
                  if (sel > -1)
                      tr.setSelection(Selection.near(tr.doc.resolve(sel)));
                  dispatch(tr.scrollIntoView());
              }
              return true;
          }
          let nextType = $to.pos == $from.end() ? grandParent.contentMatchAt(0).defaultType : null;
          let tr = state.tr.delete($from.pos, $to.pos);
          let types = nextType ? [null, { type: nextType }] : undefined;
          if (!canSplit(tr.doc, $from.pos, 2, types))
              return false;
          if (dispatch)
              dispatch(tr.split($from.pos, 2, types).scrollIntoView());
          return true;
      };
  }
  /**
  Create a command to lift the list item around the selection up into
  a wrapping list.
  */
  function liftListItem(itemType) {
      return function (state, dispatch) {
          let { $from, $to } = state.selection;
          let range = $from.blockRange($to, node => node.childCount > 0 && node.firstChild.type == itemType);
          if (!range)
              return false;
          if (!dispatch)
              return true;
          if ($from.node(range.depth - 1).type == itemType) // Inside a parent list
              return liftToOuterList(state, dispatch, itemType, range);
          else // Outer list node
              return liftOutOfList(state, dispatch, range);
      };
  }
  function liftToOuterList(state, dispatch, itemType, range) {
      let tr = state.tr, end = range.end, endOfList = range.$to.end(range.depth);
      if (end < endOfList) {
          // There are siblings after the lifted items, which must become
          // children of the last item
          tr.step(new ReplaceAroundStep(end - 1, endOfList, end, endOfList, new Slice(Fragment.from(itemType.create(null, range.parent.copy())), 1, 0), 1, true));
          range = new NodeRange(tr.doc.resolve(range.$from.pos), tr.doc.resolve(endOfList), range.depth);
      }
      const target = liftTarget(range);
      if (target == null)
          return false;
      tr.lift(range, target);
      let $after = tr.doc.resolve(tr.mapping.map(end, -1) - 1);
      if (canJoin(tr.doc, $after.pos) && $after.nodeBefore.type == $after.nodeAfter.type)
          tr.join($after.pos);
      dispatch(tr.scrollIntoView());
      return true;
  }
  function liftOutOfList(state, dispatch, range) {
      let tr = state.tr, list = range.parent;
      // Merge the list items into a single big item
      for (let pos = range.end, i = range.endIndex - 1, e = range.startIndex; i > e; i--) {
          pos -= list.child(i).nodeSize;
          tr.delete(pos - 1, pos + 1);
      }
      let $start = tr.doc.resolve(range.start), item = $start.nodeAfter;
      if (tr.mapping.map(range.end) != range.start + $start.nodeAfter.nodeSize)
          return false;
      let atStart = range.startIndex == 0, atEnd = range.endIndex == list.childCount;
      let parent = $start.node(-1), indexBefore = $start.index(-1);
      if (!parent.canReplace(indexBefore + (atStart ? 0 : 1), indexBefore + 1, item.content.append(atEnd ? Fragment.empty : Fragment.from(list))))
          return false;
      let start = $start.pos, end = start + item.nodeSize;
      // Strip off the surrounding list. At the sides where we're not at
      // the end of the list, the existing list is closed. At sides where
      // this is the end, it is overwritten to its end.
      tr.step(new ReplaceAroundStep(start - (atStart ? 1 : 0), end + (atEnd ? 1 : 0), start + 1, end - 1, new Slice((atStart ? Fragment.empty : Fragment.from(list.copy(Fragment.empty)))
          .append(atEnd ? Fragment.empty : Fragment.from(list.copy(Fragment.empty))), atStart ? 0 : 1, atEnd ? 0 : 1), atStart ? 0 : 1));
      dispatch(tr.scrollIntoView());
      return true;
  }

  const pDOM = ["p", 0], 
        blockquoteDOM = ["blockquote", 0], 
        hrDOM = ["hr"],
        preDOM = ["pre", ["code", 0]], 
        brDOM = ["br"];

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
    // `<h6>` elements. We include ID so that local links can reference them.
    heading: {
      attrs: {
        id: {default: null},
        level: {default: 1}
      },
      content: "inline*",
      group: "block",
      defining: true,
      parseDOM: [
        {tag: "h1", getAttrs(dom) { return {level: 1, id: dom.getAttribute("id")}}},
        {tag: "h2", getAttrs(dom) { return {level: 2, id: dom.getAttribute("id")}}},
        {tag: "h3", getAttrs(dom) { return {level: 3, id: dom.getAttribute("id")}}},
        {tag: "h4", getAttrs(dom) { return {level: 4, id: dom.getAttribute("id")}}},
        {tag: "h5", getAttrs(dom) { return {level: 5, id: dom.getAttribute("id")}}},
        {tag: "h6", getAttrs(dom) { return {level: 6, id: dom.getAttribute("id")}}}],
      toDOM(node) { 
        return ["h" + node.attrs.level, { id: node.attrs.id }, 0]
      }
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
        height: {default: null}
      },
      group: "inline",
      parseDOM: [{
        tag: "img[src]", 
        getAttrs(dom) {
          const width = dom.getAttribute("width") && parseInt(dom.getAttribute("width"));
          const height = dom.getAttribute("height") && parseInt(dom.getAttribute("height"));
          return {
            src: dom.getAttribute("src"),
            alt: dom.getAttribute("alt"),
            width: width,
            height: height
          }
        }
      }],
      toDOM(node) { 
        let {src, alt, width, height} = node.attrs; 
        let minAttrs = {};
        minAttrs.src = src;
        if (alt) minAttrs.alt = alt;
        if (width) minAttrs.width = width;
        if (height) minAttrs.height = height;
        return ["img", minAttrs] 
      }
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
    // 2. We use a style rule to require divs to include id, class, parentId. The div elements 
    // are used in the Swift MarkupEditor under these specific conditions, and requiring these 
    // attributes prevents issues when pasting (e.g., from GitHub READMEs) include divs.
    //
    // 3. It might be possible to exclude divs that don't conform to MarkupEditor expectations 
    // by using a rule. For now, deriving a Node from html always removes divs and buttons, so 
    // the only way for them to get into the MarkupEditor is via paste, addDiv, and addButton.
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
        style: "div[id, class, parentId]",
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

  });

  // Mix the nodes from prosemirror-schema-list into the baseNodes to create a schema with list support.
  baseNodes = addListNodes(baseNodes, '(paragraph | heading)+ block*', 'block');

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
  tNodes.table.toDOM = (node) => { return ['table', node.attrs, 0] };

  // Append the modified tableNodes and export the resulting nodes
  // :: Object
  // [Specs](#model.NodeSpec) for the nodes defined in this schema.
  const nodes = baseNodes.append(tNodes);

  const emDOM = ["em", 0], 
        strongDOM = ["strong", 0], 
        codeDOM = ["code", 0],
        strikeDOM = ["s", 0],
        uDOM = ["u", 0],
        subDOM = ["sub", 0],
        supDOM = ["sup", 0];

  // :: Object [Specs](#model.MarkSpec) for the marks in the schema.
  const marks = {
    // :: MarkSpec A link. Has `href` and `title` attributes. `title`
    // defaults to the empty string. Rendered and parsed as an `<a>`
    // element.
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
  };

  // :: Schema
  // This schema roughly corresponds to the document schema used by
  // [CommonMark](http://commonmark.org/), minus the list elements,
  // which are defined in the [`prosemirror-schema-list`](#schema-list)
  // module.
  //
  // To reuse elements from this schema, extend or read from its
  // `spec.nodes` and `spec.marks` [properties](#model.Schema.spec).
  const schema = new Schema({nodes, marks});

  var GOOD_LEAF_SIZE = 200;

  // :: class<T> A rope sequence is a persistent sequence data structure
  // that supports appending, prepending, and slicing without doing a
  // full copy. It is represented as a mostly-balanced tree.
  var RopeSequence = function RopeSequence () {};

  RopeSequence.prototype.append = function append (other) {
    if (!other.length) { return this }
    other = RopeSequence.from(other);

    return (!this.length && other) ||
      (other.length < GOOD_LEAF_SIZE && this.leafAppend(other)) ||
      (this.length < GOOD_LEAF_SIZE && other.leafPrepend(this)) ||
      this.appendInner(other)
  };

  // :: (union<[T], RopeSequence<T>>) → RopeSequence<T>
  // Prepend an array or other rope to this one, returning a new rope.
  RopeSequence.prototype.prepend = function prepend (other) {
    if (!other.length) { return this }
    return RopeSequence.from(other).append(this)
  };

  RopeSequence.prototype.appendInner = function appendInner (other) {
    return new Append(this, other)
  };

  // :: (?number, ?number) → RopeSequence<T>
  // Create a rope repesenting a sub-sequence of this rope.
  RopeSequence.prototype.slice = function slice (from, to) {
      if ( from === void 0 ) from = 0;
      if ( to === void 0 ) to = this.length;

    if (from >= to) { return RopeSequence.empty }
    return this.sliceInner(Math.max(0, from), Math.min(this.length, to))
  };

  // :: (number) → T
  // Retrieve the element at the given position from this rope.
  RopeSequence.prototype.get = function get (i) {
    if (i < 0 || i >= this.length) { return undefined }
    return this.getInner(i)
  };

  // :: ((element: T, index: number) → ?bool, ?number, ?number)
  // Call the given function for each element between the given
  // indices. This tends to be more efficient than looping over the
  // indices and calling `get`, because it doesn't have to descend the
  // tree for every element.
  RopeSequence.prototype.forEach = function forEach (f, from, to) {
      if ( from === void 0 ) from = 0;
      if ( to === void 0 ) to = this.length;

    if (from <= to)
      { this.forEachInner(f, from, to, 0); }
    else
      { this.forEachInvertedInner(f, from, to, 0); }
  };

  // :: ((element: T, index: number) → U, ?number, ?number) → [U]
  // Map the given functions over the elements of the rope, producing
  // a flat array.
  RopeSequence.prototype.map = function map (f, from, to) {
      if ( from === void 0 ) from = 0;
      if ( to === void 0 ) to = this.length;

    var result = [];
    this.forEach(function (elt, i) { return result.push(f(elt, i)); }, from, to);
    return result
  };

  // :: (?union<[T], RopeSequence<T>>) → RopeSequence<T>
  // Create a rope representing the given array, or return the rope
  // itself if a rope was given.
  RopeSequence.from = function from (values) {
    if (values instanceof RopeSequence) { return values }
    return values && values.length ? new Leaf(values) : RopeSequence.empty
  };

  var Leaf = /*@__PURE__*/(function (RopeSequence) {
    function Leaf(values) {
      RopeSequence.call(this);
      this.values = values;
    }

    if ( RopeSequence ) Leaf.__proto__ = RopeSequence;
    Leaf.prototype = Object.create( RopeSequence && RopeSequence.prototype );
    Leaf.prototype.constructor = Leaf;

    var prototypeAccessors = { length: { configurable: true },depth: { configurable: true } };

    Leaf.prototype.flatten = function flatten () {
      return this.values
    };

    Leaf.prototype.sliceInner = function sliceInner (from, to) {
      if (from == 0 && to == this.length) { return this }
      return new Leaf(this.values.slice(from, to))
    };

    Leaf.prototype.getInner = function getInner (i) {
      return this.values[i]
    };

    Leaf.prototype.forEachInner = function forEachInner (f, from, to, start) {
      for (var i = from; i < to; i++)
        { if (f(this.values[i], start + i) === false) { return false } }
    };

    Leaf.prototype.forEachInvertedInner = function forEachInvertedInner (f, from, to, start) {
      for (var i = from - 1; i >= to; i--)
        { if (f(this.values[i], start + i) === false) { return false } }
    };

    Leaf.prototype.leafAppend = function leafAppend (other) {
      if (this.length + other.length <= GOOD_LEAF_SIZE)
        { return new Leaf(this.values.concat(other.flatten())) }
    };

    Leaf.prototype.leafPrepend = function leafPrepend (other) {
      if (this.length + other.length <= GOOD_LEAF_SIZE)
        { return new Leaf(other.flatten().concat(this.values)) }
    };

    prototypeAccessors.length.get = function () { return this.values.length };

    prototypeAccessors.depth.get = function () { return 0 };

    Object.defineProperties( Leaf.prototype, prototypeAccessors );

    return Leaf;
  }(RopeSequence));

  // :: RopeSequence
  // The empty rope sequence.
  RopeSequence.empty = new Leaf([]);

  var Append = /*@__PURE__*/(function (RopeSequence) {
    function Append(left, right) {
      RopeSequence.call(this);
      this.left = left;
      this.right = right;
      this.length = left.length + right.length;
      this.depth = Math.max(left.depth, right.depth) + 1;
    }

    if ( RopeSequence ) Append.__proto__ = RopeSequence;
    Append.prototype = Object.create( RopeSequence && RopeSequence.prototype );
    Append.prototype.constructor = Append;

    Append.prototype.flatten = function flatten () {
      return this.left.flatten().concat(this.right.flatten())
    };

    Append.prototype.getInner = function getInner (i) {
      return i < this.left.length ? this.left.get(i) : this.right.get(i - this.left.length)
    };

    Append.prototype.forEachInner = function forEachInner (f, from, to, start) {
      var leftLen = this.left.length;
      if (from < leftLen &&
          this.left.forEachInner(f, from, Math.min(to, leftLen), start) === false)
        { return false }
      if (to > leftLen &&
          this.right.forEachInner(f, Math.max(from - leftLen, 0), Math.min(this.length, to) - leftLen, start + leftLen) === false)
        { return false }
    };

    Append.prototype.forEachInvertedInner = function forEachInvertedInner (f, from, to, start) {
      var leftLen = this.left.length;
      if (from > leftLen &&
          this.right.forEachInvertedInner(f, from - leftLen, Math.max(to, leftLen) - leftLen, start + leftLen) === false)
        { return false }
      if (to < leftLen &&
          this.left.forEachInvertedInner(f, Math.min(from, leftLen), to, start) === false)
        { return false }
    };

    Append.prototype.sliceInner = function sliceInner (from, to) {
      if (from == 0 && to == this.length) { return this }
      var leftLen = this.left.length;
      if (to <= leftLen) { return this.left.slice(from, to) }
      if (from >= leftLen) { return this.right.slice(from - leftLen, to - leftLen) }
      return this.left.slice(from, leftLen).append(this.right.slice(0, to - leftLen))
    };

    Append.prototype.leafAppend = function leafAppend (other) {
      var inner = this.right.leafAppend(other);
      if (inner) { return new Append(this.left, inner) }
    };

    Append.prototype.leafPrepend = function leafPrepend (other) {
      var inner = this.left.leafPrepend(other);
      if (inner) { return new Append(inner, this.right) }
    };

    Append.prototype.appendInner = function appendInner (other) {
      if (this.left.depth >= Math.max(this.right.depth, other.depth) + 1)
        { return new Append(this.left, new Append(this.right, other)) }
      return new Append(this, other)
    };

    return Append;
  }(RopeSequence));

  // ProseMirror's history isn't simply a way to roll back to a previous
  // state, because ProseMirror supports applying changes without adding
  // them to the history (for example during collaboration).
  //
  // To this end, each 'Branch' (one for the undo history and one for
  // the redo history) keeps an array of 'Items', which can optionally
  // hold a step (an actual undoable change), and always hold a position
  // map (which is needed to move changes below them to apply to the
  // current document).
  //
  // An item that has both a step and a selection bookmark is the start
  // of an 'event' — a group of changes that will be undone or redone at
  // once. (It stores only the bookmark, since that way we don't have to
  // provide a document until the selection is actually applied, which
  // is useful when compressing.)
  // Used to schedule history compression
  const max_empty_items = 500;
  class Branch {
      constructor(items, eventCount) {
          this.items = items;
          this.eventCount = eventCount;
      }
      // Pop the latest event off the branch's history and apply it
      // to a document transform.
      popEvent(state, preserveItems) {
          if (this.eventCount == 0)
              return null;
          let end = this.items.length;
          for (;; end--) {
              let next = this.items.get(end - 1);
              if (next.selection) {
                  --end;
                  break;
              }
          }
          let remap, mapFrom;
          if (preserveItems) {
              remap = this.remapping(end, this.items.length);
              mapFrom = remap.maps.length;
          }
          let transform = state.tr;
          let selection, remaining;
          let addAfter = [], addBefore = [];
          this.items.forEach((item, i) => {
              if (!item.step) {
                  if (!remap) {
                      remap = this.remapping(end, i + 1);
                      mapFrom = remap.maps.length;
                  }
                  mapFrom--;
                  addBefore.push(item);
                  return;
              }
              if (remap) {
                  addBefore.push(new Item(item.map));
                  let step = item.step.map(remap.slice(mapFrom)), map;
                  if (step && transform.maybeStep(step).doc) {
                      map = transform.mapping.maps[transform.mapping.maps.length - 1];
                      addAfter.push(new Item(map, undefined, undefined, addAfter.length + addBefore.length));
                  }
                  mapFrom--;
                  if (map)
                      remap.appendMap(map, mapFrom);
              }
              else {
                  transform.maybeStep(item.step);
              }
              if (item.selection) {
                  selection = remap ? item.selection.map(remap.slice(mapFrom)) : item.selection;
                  remaining = new Branch(this.items.slice(0, end).append(addBefore.reverse().concat(addAfter)), this.eventCount - 1);
                  return false;
              }
          }, this.items.length, 0);
          return { remaining: remaining, transform, selection: selection };
      }
      // Create a new branch with the given transform added.
      addTransform(transform, selection, histOptions, preserveItems) {
          let newItems = [], eventCount = this.eventCount;
          let oldItems = this.items, lastItem = !preserveItems && oldItems.length ? oldItems.get(oldItems.length - 1) : null;
          for (let i = 0; i < transform.steps.length; i++) {
              let step = transform.steps[i].invert(transform.docs[i]);
              let item = new Item(transform.mapping.maps[i], step, selection), merged;
              if (merged = lastItem && lastItem.merge(item)) {
                  item = merged;
                  if (i)
                      newItems.pop();
                  else
                      oldItems = oldItems.slice(0, oldItems.length - 1);
              }
              newItems.push(item);
              if (selection) {
                  eventCount++;
                  selection = undefined;
              }
              if (!preserveItems)
                  lastItem = item;
          }
          let overflow = eventCount - histOptions.depth;
          if (overflow > DEPTH_OVERFLOW) {
              oldItems = cutOffEvents(oldItems, overflow);
              eventCount -= overflow;
          }
          return new Branch(oldItems.append(newItems), eventCount);
      }
      remapping(from, to) {
          let maps = new Mapping;
          this.items.forEach((item, i) => {
              let mirrorPos = item.mirrorOffset != null && i - item.mirrorOffset >= from
                  ? maps.maps.length - item.mirrorOffset : undefined;
              maps.appendMap(item.map, mirrorPos);
          }, from, to);
          return maps;
      }
      addMaps(array) {
          if (this.eventCount == 0)
              return this;
          return new Branch(this.items.append(array.map(map => new Item(map))), this.eventCount);
      }
      // When the collab module receives remote changes, the history has
      // to know about those, so that it can adjust the steps that were
      // rebased on top of the remote changes, and include the position
      // maps for the remote changes in its array of items.
      rebased(rebasedTransform, rebasedCount) {
          if (!this.eventCount)
              return this;
          let rebasedItems = [], start = Math.max(0, this.items.length - rebasedCount);
          let mapping = rebasedTransform.mapping;
          let newUntil = rebasedTransform.steps.length;
          let eventCount = this.eventCount;
          this.items.forEach(item => { if (item.selection)
              eventCount--; }, start);
          let iRebased = rebasedCount;
          this.items.forEach(item => {
              let pos = mapping.getMirror(--iRebased);
              if (pos == null)
                  return;
              newUntil = Math.min(newUntil, pos);
              let map = mapping.maps[pos];
              if (item.step) {
                  let step = rebasedTransform.steps[pos].invert(rebasedTransform.docs[pos]);
                  let selection = item.selection && item.selection.map(mapping.slice(iRebased + 1, pos));
                  if (selection)
                      eventCount++;
                  rebasedItems.push(new Item(map, step, selection));
              }
              else {
                  rebasedItems.push(new Item(map));
              }
          }, start);
          let newMaps = [];
          for (let i = rebasedCount; i < newUntil; i++)
              newMaps.push(new Item(mapping.maps[i]));
          let items = this.items.slice(0, start).append(newMaps).append(rebasedItems);
          let branch = new Branch(items, eventCount);
          if (branch.emptyItemCount() > max_empty_items)
              branch = branch.compress(this.items.length - rebasedItems.length);
          return branch;
      }
      emptyItemCount() {
          let count = 0;
          this.items.forEach(item => { if (!item.step)
              count++; });
          return count;
      }
      // Compressing a branch means rewriting it to push the air (map-only
      // items) out. During collaboration, these naturally accumulate
      // because each remote change adds one. The `upto` argument is used
      // to ensure that only the items below a given level are compressed,
      // because `rebased` relies on a clean, untouched set of items in
      // order to associate old items with rebased steps.
      compress(upto = this.items.length) {
          let remap = this.remapping(0, upto), mapFrom = remap.maps.length;
          let items = [], events = 0;
          this.items.forEach((item, i) => {
              if (i >= upto) {
                  items.push(item);
                  if (item.selection)
                      events++;
              }
              else if (item.step) {
                  let step = item.step.map(remap.slice(mapFrom)), map = step && step.getMap();
                  mapFrom--;
                  if (map)
                      remap.appendMap(map, mapFrom);
                  if (step) {
                      let selection = item.selection && item.selection.map(remap.slice(mapFrom));
                      if (selection)
                          events++;
                      let newItem = new Item(map.invert(), step, selection), merged, last = items.length - 1;
                      if (merged = items.length && items[last].merge(newItem))
                          items[last] = merged;
                      else
                          items.push(newItem);
                  }
              }
              else if (item.map) {
                  mapFrom--;
              }
          }, this.items.length, 0);
          return new Branch(RopeSequence.from(items.reverse()), events);
      }
  }
  Branch.empty = new Branch(RopeSequence.empty, 0);
  function cutOffEvents(items, n) {
      let cutPoint;
      items.forEach((item, i) => {
          if (item.selection && (n-- == 0)) {
              cutPoint = i;
              return false;
          }
      });
      return items.slice(cutPoint);
  }
  class Item {
      constructor(
      // The (forward) step map for this item.
      map, 
      // The inverted step
      step, 
      // If this is non-null, this item is the start of a group, and
      // this selection is the starting selection for the group (the one
      // that was active before the first step was applied)
      selection, 
      // If this item is the inverse of a previous mapping on the stack,
      // this points at the inverse's offset
      mirrorOffset) {
          this.map = map;
          this.step = step;
          this.selection = selection;
          this.mirrorOffset = mirrorOffset;
      }
      merge(other) {
          if (this.step && other.step && !other.selection) {
              let step = other.step.merge(this.step);
              if (step)
                  return new Item(step.getMap().invert(), step, this.selection);
          }
      }
  }
  // The value of the state field that tracks undo/redo history for that
  // state. Will be stored in the plugin state when the history plugin
  // is active.
  class HistoryState {
      constructor(done, undone, prevRanges, prevTime, prevComposition) {
          this.done = done;
          this.undone = undone;
          this.prevRanges = prevRanges;
          this.prevTime = prevTime;
          this.prevComposition = prevComposition;
      }
  }
  const DEPTH_OVERFLOW = 20;
  // Record a transformation in undo history.
  function applyTransaction(history, state, tr, options) {
      let historyTr = tr.getMeta(historyKey), rebased;
      if (historyTr)
          return historyTr.historyState;
      if (tr.getMeta(closeHistoryKey))
          history = new HistoryState(history.done, history.undone, null, 0, -1);
      let appended = tr.getMeta("appendedTransaction");
      if (tr.steps.length == 0) {
          return history;
      }
      else if (appended && appended.getMeta(historyKey)) {
          if (appended.getMeta(historyKey).redo)
              return new HistoryState(history.done.addTransform(tr, undefined, options, mustPreserveItems(state)), history.undone, rangesFor(tr.mapping.maps), history.prevTime, history.prevComposition);
          else
              return new HistoryState(history.done, history.undone.addTransform(tr, undefined, options, mustPreserveItems(state)), null, history.prevTime, history.prevComposition);
      }
      else if (tr.getMeta("addToHistory") !== false && !(appended && appended.getMeta("addToHistory") === false)) {
          // Group transforms that occur in quick succession into one event.
          let composition = tr.getMeta("composition");
          let newGroup = history.prevTime == 0 ||
              (!appended && history.prevComposition != composition &&
                  (history.prevTime < (tr.time || 0) - options.newGroupDelay || !isAdjacentTo(tr, history.prevRanges)));
          let prevRanges = appended ? mapRanges(history.prevRanges, tr.mapping) : rangesFor(tr.mapping.maps);
          return new HistoryState(history.done.addTransform(tr, newGroup ? state.selection.getBookmark() : undefined, options, mustPreserveItems(state)), Branch.empty, prevRanges, tr.time, composition == null ? history.prevComposition : composition);
      }
      else if (rebased = tr.getMeta("rebased")) {
          // Used by the collab module to tell the history that some of its
          // content has been rebased.
          return new HistoryState(history.done.rebased(tr, rebased), history.undone.rebased(tr, rebased), mapRanges(history.prevRanges, tr.mapping), history.prevTime, history.prevComposition);
      }
      else {
          return new HistoryState(history.done.addMaps(tr.mapping.maps), history.undone.addMaps(tr.mapping.maps), mapRanges(history.prevRanges, tr.mapping), history.prevTime, history.prevComposition);
      }
  }
  function isAdjacentTo(transform, prevRanges) {
      if (!prevRanges)
          return false;
      if (!transform.docChanged)
          return true;
      let adjacent = false;
      transform.mapping.maps[0].forEach((start, end) => {
          for (let i = 0; i < prevRanges.length; i += 2)
              if (start <= prevRanges[i + 1] && end >= prevRanges[i])
                  adjacent = true;
      });
      return adjacent;
  }
  function rangesFor(maps) {
      let result = [];
      for (let i = maps.length - 1; i >= 0 && result.length == 0; i--)
          maps[i].forEach((_from, _to, from, to) => result.push(from, to));
      return result;
  }
  function mapRanges(ranges, mapping) {
      if (!ranges)
          return null;
      let result = [];
      for (let i = 0; i < ranges.length; i += 2) {
          let from = mapping.map(ranges[i], 1), to = mapping.map(ranges[i + 1], -1);
          if (from <= to)
              result.push(from, to);
      }
      return result;
  }
  // Apply the latest event from one branch to the document and shift the event
  // onto the other branch.
  function histTransaction(history, state, redo) {
      let preserveItems = mustPreserveItems(state);
      let histOptions = historyKey.get(state).spec.config;
      let pop = (redo ? history.undone : history.done).popEvent(state, preserveItems);
      if (!pop)
          return null;
      let selection = pop.selection.resolve(pop.transform.doc);
      let added = (redo ? history.done : history.undone).addTransform(pop.transform, state.selection.getBookmark(), histOptions, preserveItems);
      let newHist = new HistoryState(redo ? added : pop.remaining, redo ? pop.remaining : added, null, 0, -1);
      return pop.transform.setSelection(selection).setMeta(historyKey, { redo, historyState: newHist });
  }
  let cachedPreserveItems = false, cachedPreserveItemsPlugins = null;
  // Check whether any plugin in the given state has a
  // `historyPreserveItems` property in its spec, in which case we must
  // preserve steps exactly as they came in, so that they can be
  // rebased.
  function mustPreserveItems(state) {
      let plugins = state.plugins;
      if (cachedPreserveItemsPlugins != plugins) {
          cachedPreserveItems = false;
          cachedPreserveItemsPlugins = plugins;
          for (let i = 0; i < plugins.length; i++)
              if (plugins[i].spec.historyPreserveItems) {
                  cachedPreserveItems = true;
                  break;
              }
      }
      return cachedPreserveItems;
  }
  const historyKey = new PluginKey("history");
  const closeHistoryKey = new PluginKey("closeHistory");
  /**
  Returns a plugin that enables the undo history for an editor. The
  plugin will track undo and redo stacks, which can be used with the
  [`undo`](https://prosemirror.net/docs/ref/#history.undo) and [`redo`](https://prosemirror.net/docs/ref/#history.redo) commands.

  You can set an `"addToHistory"` [metadata
  property](https://prosemirror.net/docs/ref/#state.Transaction.setMeta) of `false` on a transaction
  to prevent it from being rolled back by undo.
  */
  function history(config = {}) {
      config = { depth: config.depth || 100,
          newGroupDelay: config.newGroupDelay || 500 };
      return new Plugin({
          key: historyKey,
          state: {
              init() {
                  return new HistoryState(Branch.empty, Branch.empty, null, 0, -1);
              },
              apply(tr, hist, state) {
                  return applyTransaction(hist, state, tr, config);
              }
          },
          config,
          props: {
              handleDOMEvents: {
                  beforeinput(view, e) {
                      let inputType = e.inputType;
                      let command = inputType == "historyUndo" ? undo : inputType == "historyRedo" ? redo : null;
                      if (!command)
                          return false;
                      e.preventDefault();
                      return command(view.state, view.dispatch);
                  }
              }
          }
      });
  }
  function buildCommand(redo, scroll) {
      return (state, dispatch) => {
          let hist = historyKey.getState(state);
          if (!hist || (redo ? hist.undone : hist.done).eventCount == 0)
              return false;
          if (dispatch) {
              let tr = histTransaction(hist, state, redo);
              if (tr)
                  dispatch(scroll ? tr.scrollIntoView() : tr);
          }
          return true;
      };
  }
  /**
  A command function that undoes the last change, if any.
  */
  const undo = buildCommand(false, true);
  /**
  A command function that redoes the last undone change, if any.
  */
  const redo = buildCommand(true, true);

  /**
  Delete the selection, if there is one.
  */
  const deleteSelection = (state, dispatch) => {
      if (state.selection.empty)
          return false;
      if (dispatch)
          dispatch(state.tr.deleteSelection().scrollIntoView());
      return true;
  };
  function atBlockStart(state, view) {
      let { $cursor } = state.selection;
      if (!$cursor || (view ? !view.endOfTextblock("backward", state)
          : $cursor.parentOffset > 0))
          return null;
      return $cursor;
  }
  /**
  If the selection is empty and at the start of a textblock, try to
  reduce the distance between that block and the one before it—if
  there's a block directly before it that can be joined, join them.
  If not, try to move the selected block closer to the next one in
  the document structure by lifting it out of its parent or moving it
  into a parent of the previous block. Will use the view for accurate
  (bidi-aware) start-of-textblock detection if given.
  */
  const joinBackward = (state, dispatch, view) => {
      let $cursor = atBlockStart(state, view);
      if (!$cursor)
          return false;
      let $cut = findCutBefore($cursor);
      // If there is no node before this, try to lift
      if (!$cut) {
          let range = $cursor.blockRange(), target = range && liftTarget(range);
          if (target == null)
              return false;
          if (dispatch)
              dispatch(state.tr.lift(range, target).scrollIntoView());
          return true;
      }
      let before = $cut.nodeBefore;
      // Apply the joining algorithm
      if (deleteBarrier(state, $cut, dispatch, -1))
          return true;
      // If the node below has no content and the node above is
      // selectable, delete the node below and select the one above.
      if ($cursor.parent.content.size == 0 &&
          (textblockAt(before, "end") || NodeSelection.isSelectable(before))) {
          for (let depth = $cursor.depth;; depth--) {
              let delStep = replaceStep(state.doc, $cursor.before(depth), $cursor.after(depth), Slice.empty);
              if (delStep && delStep.slice.size < delStep.to - delStep.from) {
                  if (dispatch) {
                      let tr = state.tr.step(delStep);
                      tr.setSelection(textblockAt(before, "end")
                          ? Selection.findFrom(tr.doc.resolve(tr.mapping.map($cut.pos, -1)), -1)
                          : NodeSelection.create(tr.doc, $cut.pos - before.nodeSize));
                      dispatch(tr.scrollIntoView());
                  }
                  return true;
              }
              if (depth == 1 || $cursor.node(depth - 1).childCount > 1)
                  break;
          }
      }
      // If the node before is an atom, delete it
      if (before.isAtom && $cut.depth == $cursor.depth - 1) {
          if (dispatch)
              dispatch(state.tr.delete($cut.pos - before.nodeSize, $cut.pos).scrollIntoView());
          return true;
      }
      return false;
  };
  function textblockAt(node, side, only = false) {
      for (let scan = node; scan; scan = (side == "start" ? scan.firstChild : scan.lastChild)) {
          if (scan.isTextblock)
              return true;
          if (only && scan.childCount != 1)
              return false;
      }
      return false;
  }
  /**
  When the selection is empty and at the start of a textblock, select
  the node before that textblock, if possible. This is intended to be
  bound to keys like backspace, after
  [`joinBackward`](https://prosemirror.net/docs/ref/#commands.joinBackward) or other deleting
  commands, as a fall-back behavior when the schema doesn't allow
  deletion at the selected point.
  */
  const selectNodeBackward = (state, dispatch, view) => {
      let { $head, empty } = state.selection, $cut = $head;
      if (!empty)
          return false;
      if ($head.parent.isTextblock) {
          if (view ? !view.endOfTextblock("backward", state) : $head.parentOffset > 0)
              return false;
          $cut = findCutBefore($head);
      }
      let node = $cut && $cut.nodeBefore;
      if (!node || !NodeSelection.isSelectable(node))
          return false;
      if (dispatch)
          dispatch(state.tr.setSelection(NodeSelection.create(state.doc, $cut.pos - node.nodeSize)).scrollIntoView());
      return true;
  };
  function findCutBefore($pos) {
      if (!$pos.parent.type.spec.isolating)
          for (let i = $pos.depth - 1; i >= 0; i--) {
              if ($pos.index(i) > 0)
                  return $pos.doc.resolve($pos.before(i + 1));
              if ($pos.node(i).type.spec.isolating)
                  break;
          }
      return null;
  }
  function atBlockEnd(state, view) {
      let { $cursor } = state.selection;
      if (!$cursor || (view ? !view.endOfTextblock("forward", state)
          : $cursor.parentOffset < $cursor.parent.content.size))
          return null;
      return $cursor;
  }
  /**
  If the selection is empty and the cursor is at the end of a
  textblock, try to reduce or remove the boundary between that block
  and the one after it, either by joining them or by moving the other
  block closer to this one in the tree structure. Will use the view
  for accurate start-of-textblock detection if given.
  */
  const joinForward = (state, dispatch, view) => {
      let $cursor = atBlockEnd(state, view);
      if (!$cursor)
          return false;
      let $cut = findCutAfter($cursor);
      // If there is no node after this, there's nothing to do
      if (!$cut)
          return false;
      let after = $cut.nodeAfter;
      // Try the joining algorithm
      if (deleteBarrier(state, $cut, dispatch, 1))
          return true;
      // If the node above has no content and the node below is
      // selectable, delete the node above and select the one below.
      if ($cursor.parent.content.size == 0 &&
          (textblockAt(after, "start") || NodeSelection.isSelectable(after))) {
          let delStep = replaceStep(state.doc, $cursor.before(), $cursor.after(), Slice.empty);
          if (delStep && delStep.slice.size < delStep.to - delStep.from) {
              if (dispatch) {
                  let tr = state.tr.step(delStep);
                  tr.setSelection(textblockAt(after, "start") ? Selection.findFrom(tr.doc.resolve(tr.mapping.map($cut.pos)), 1)
                      : NodeSelection.create(tr.doc, tr.mapping.map($cut.pos)));
                  dispatch(tr.scrollIntoView());
              }
              return true;
          }
      }
      // If the next node is an atom, delete it
      if (after.isAtom && $cut.depth == $cursor.depth - 1) {
          if (dispatch)
              dispatch(state.tr.delete($cut.pos, $cut.pos + after.nodeSize).scrollIntoView());
          return true;
      }
      return false;
  };
  /**
  When the selection is empty and at the end of a textblock, select
  the node coming after that textblock, if possible. This is intended
  to be bound to keys like delete, after
  [`joinForward`](https://prosemirror.net/docs/ref/#commands.joinForward) and similar deleting
  commands, to provide a fall-back behavior when the schema doesn't
  allow deletion at the selected point.
  */
  const selectNodeForward = (state, dispatch, view) => {
      let { $head, empty } = state.selection, $cut = $head;
      if (!empty)
          return false;
      if ($head.parent.isTextblock) {
          if (view ? !view.endOfTextblock("forward", state) : $head.parentOffset < $head.parent.content.size)
              return false;
          $cut = findCutAfter($head);
      }
      let node = $cut && $cut.nodeAfter;
      if (!node || !NodeSelection.isSelectable(node))
          return false;
      if (dispatch)
          dispatch(state.tr.setSelection(NodeSelection.create(state.doc, $cut.pos)).scrollIntoView());
      return true;
  };
  function findCutAfter($pos) {
      if (!$pos.parent.type.spec.isolating)
          for (let i = $pos.depth - 1; i >= 0; i--) {
              let parent = $pos.node(i);
              if ($pos.index(i) + 1 < parent.childCount)
                  return $pos.doc.resolve($pos.after(i + 1));
              if (parent.type.spec.isolating)
                  break;
          }
      return null;
  }
  /**
  If the selection is in a node whose type has a truthy
  [`code`](https://prosemirror.net/docs/ref/#model.NodeSpec.code) property in its spec, replace the
  selection with a newline character.
  */
  const newlineInCode = (state, dispatch) => {
      let { $head, $anchor } = state.selection;
      if (!$head.parent.type.spec.code || !$head.sameParent($anchor))
          return false;
      if (dispatch)
          dispatch(state.tr.insertText("\n").scrollIntoView());
      return true;
  };
  function defaultBlockAt(match) {
      for (let i = 0; i < match.edgeCount; i++) {
          let { type } = match.edge(i);
          if (type.isTextblock && !type.hasRequiredAttrs())
              return type;
      }
      return null;
  }
  /**
  When the selection is in a node with a truthy
  [`code`](https://prosemirror.net/docs/ref/#model.NodeSpec.code) property in its spec, create a
  default block after the code block, and move the cursor there.
  */
  const exitCode = (state, dispatch) => {
      let { $head, $anchor } = state.selection;
      if (!$head.parent.type.spec.code || !$head.sameParent($anchor))
          return false;
      let above = $head.node(-1), after = $head.indexAfter(-1), type = defaultBlockAt(above.contentMatchAt(after));
      if (!type || !above.canReplaceWith(after, after, type))
          return false;
      if (dispatch) {
          let pos = $head.after(), tr = state.tr.replaceWith(pos, pos, type.createAndFill());
          tr.setSelection(Selection.near(tr.doc.resolve(pos), 1));
          dispatch(tr.scrollIntoView());
      }
      return true;
  };
  /**
  If a block node is selected, create an empty paragraph before (if
  it is its parent's first child) or after it.
  */
  const createParagraphNear = (state, dispatch) => {
      let sel = state.selection, { $from, $to } = sel;
      if (sel instanceof AllSelection || $from.parent.inlineContent || $to.parent.inlineContent)
          return false;
      let type = defaultBlockAt($to.parent.contentMatchAt($to.indexAfter()));
      if (!type || !type.isTextblock)
          return false;
      if (dispatch) {
          let side = (!$from.parentOffset && $to.index() < $to.parent.childCount ? $from : $to).pos;
          let tr = state.tr.insert(side, type.createAndFill());
          tr.setSelection(TextSelection.create(tr.doc, side + 1));
          dispatch(tr.scrollIntoView());
      }
      return true;
  };
  /**
  If the cursor is in an empty textblock that can be lifted, lift the
  block.
  */
  const liftEmptyBlock = (state, dispatch) => {
      let { $cursor } = state.selection;
      if (!$cursor || $cursor.parent.content.size)
          return false;
      if ($cursor.depth > 1 && $cursor.after() != $cursor.end(-1)) {
          let before = $cursor.before();
          if (canSplit(state.doc, before)) {
              if (dispatch)
                  dispatch(state.tr.split(before).scrollIntoView());
              return true;
          }
      }
      let range = $cursor.blockRange(), target = range && liftTarget(range);
      if (target == null)
          return false;
      if (dispatch)
          dispatch(state.tr.lift(range, target).scrollIntoView());
      return true;
  };
  /**
  Create a variant of [`splitBlock`](https://prosemirror.net/docs/ref/#commands.splitBlock) that uses
  a custom function to determine the type of the newly split off block.
  */
  function splitBlockAs(splitNode) {
      return (state, dispatch) => {
          let { $from, $to } = state.selection;
          if (state.selection instanceof NodeSelection && state.selection.node.isBlock) {
              if (!$from.parentOffset || !canSplit(state.doc, $from.pos))
                  return false;
              if (dispatch)
                  dispatch(state.tr.split($from.pos).scrollIntoView());
              return true;
          }
          if (!$from.depth)
              return false;
          let types = [];
          let splitDepth, deflt, atEnd = false, atStart = false;
          for (let d = $from.depth;; d--) {
              let node = $from.node(d);
              if (node.isBlock) {
                  atEnd = $from.end(d) == $from.pos + ($from.depth - d);
                  atStart = $from.start(d) == $from.pos - ($from.depth - d);
                  deflt = defaultBlockAt($from.node(d - 1).contentMatchAt($from.indexAfter(d - 1)));
                  types.unshift((atEnd && deflt ? { type: deflt } : null));
                  splitDepth = d;
                  break;
              }
              else {
                  if (d == 1)
                      return false;
                  types.unshift(null);
              }
          }
          let tr = state.tr;
          if (state.selection instanceof TextSelection || state.selection instanceof AllSelection)
              tr.deleteSelection();
          let splitPos = tr.mapping.map($from.pos);
          let can = canSplit(tr.doc, splitPos, types.length, types);
          if (!can) {
              types[0] = deflt ? { type: deflt } : null;
              can = canSplit(tr.doc, splitPos, types.length, types);
          }
          if (!can)
              return false;
          tr.split(splitPos, types.length, types);
          if (!atEnd && atStart && $from.node(splitDepth).type != deflt) {
              let first = tr.mapping.map($from.before(splitDepth)), $first = tr.doc.resolve(first);
              if (deflt && $from.node(splitDepth - 1).canReplaceWith($first.index(), $first.index() + 1, deflt))
                  tr.setNodeMarkup(tr.mapping.map($from.before(splitDepth)), deflt);
          }
          if (dispatch)
              dispatch(tr.scrollIntoView());
          return true;
      };
  }
  /**
  Split the parent block of the selection. If the selection is a text
  selection, also delete its content.
  */
  const splitBlock = splitBlockAs();
  /**
  Select the whole document.
  */
  const selectAll = (state, dispatch) => {
      if (dispatch)
          dispatch(state.tr.setSelection(new AllSelection(state.doc)));
      return true;
  };
  function joinMaybeClear(state, $pos, dispatch) {
      let before = $pos.nodeBefore, after = $pos.nodeAfter, index = $pos.index();
      if (!before || !after || !before.type.compatibleContent(after.type))
          return false;
      if (!before.content.size && $pos.parent.canReplace(index - 1, index)) {
          if (dispatch)
              dispatch(state.tr.delete($pos.pos - before.nodeSize, $pos.pos).scrollIntoView());
          return true;
      }
      if (!$pos.parent.canReplace(index, index + 1) || !(after.isTextblock || canJoin(state.doc, $pos.pos)))
          return false;
      if (dispatch)
          dispatch(state.tr.join($pos.pos).scrollIntoView());
      return true;
  }
  function deleteBarrier(state, $cut, dispatch, dir) {
      let before = $cut.nodeBefore, after = $cut.nodeAfter, conn, match;
      let isolated = before.type.spec.isolating || after.type.spec.isolating;
      if (!isolated && joinMaybeClear(state, $cut, dispatch))
          return true;
      let canDelAfter = !isolated && $cut.parent.canReplace($cut.index(), $cut.index() + 1);
      if (canDelAfter &&
          (conn = (match = before.contentMatchAt(before.childCount)).findWrapping(after.type)) &&
          match.matchType(conn[0] || after.type).validEnd) {
          if (dispatch) {
              let end = $cut.pos + after.nodeSize, wrap = Fragment.empty;
              for (let i = conn.length - 1; i >= 0; i--)
                  wrap = Fragment.from(conn[i].create(null, wrap));
              wrap = Fragment.from(before.copy(wrap));
              let tr = state.tr.step(new ReplaceAroundStep($cut.pos - 1, end, $cut.pos, end, new Slice(wrap, 1, 0), conn.length, true));
              let $joinAt = tr.doc.resolve(end + 2 * conn.length);
              if ($joinAt.nodeAfter && $joinAt.nodeAfter.type == before.type &&
                  canJoin(tr.doc, $joinAt.pos))
                  tr.join($joinAt.pos);
              dispatch(tr.scrollIntoView());
          }
          return true;
      }
      let selAfter = after.type.spec.isolating || (dir > 0 && isolated) ? null : Selection.findFrom($cut, 1);
      let range = selAfter && selAfter.$from.blockRange(selAfter.$to), target = range && liftTarget(range);
      if (target != null && target >= $cut.depth) {
          if (dispatch)
              dispatch(state.tr.lift(range, target).scrollIntoView());
          return true;
      }
      if (canDelAfter && textblockAt(after, "start", true) && textblockAt(before, "end")) {
          let at = before, wrap = [];
          for (;;) {
              wrap.push(at);
              if (at.isTextblock)
                  break;
              at = at.lastChild;
          }
          let afterText = after, afterDepth = 1;
          for (; !afterText.isTextblock; afterText = afterText.firstChild)
              afterDepth++;
          if (at.canReplace(at.childCount, at.childCount, afterText.content)) {
              if (dispatch) {
                  let end = Fragment.empty;
                  for (let i = wrap.length - 1; i >= 0; i--)
                      end = Fragment.from(wrap[i].copy(end));
                  let tr = state.tr.step(new ReplaceAroundStep($cut.pos - wrap.length, $cut.pos + after.nodeSize, $cut.pos + afterDepth, $cut.pos + after.nodeSize - afterDepth, new Slice(end, wrap.length, 0), 0, true));
                  dispatch(tr.scrollIntoView());
              }
              return true;
          }
      }
      return false;
  }
  function selectTextblockSide(side) {
      return function (state, dispatch) {
          let sel = state.selection, $pos = side < 0 ? sel.$from : sel.$to;
          let depth = $pos.depth;
          while ($pos.node(depth).isInline) {
              if (!depth)
                  return false;
              depth--;
          }
          if (!$pos.node(depth).isTextblock)
              return false;
          if (dispatch)
              dispatch(state.tr.setSelection(TextSelection.create(state.doc, side < 0 ? $pos.start(depth) : $pos.end(depth))));
          return true;
      };
  }
  /**
  Moves the cursor to the start of current text block.
  */
  const selectTextblockStart = selectTextblockSide(-1);
  /**
  Moves the cursor to the end of current text block.
  */
  const selectTextblockEnd = selectTextblockSide(1);
  function markApplies(doc, ranges, type, enterAtoms) {
      for (let i = 0; i < ranges.length; i++) {
          let { $from, $to } = ranges[i];
          let can = $from.depth == 0 ? doc.inlineContent && doc.type.allowsMarkType(type) : false;
          doc.nodesBetween($from.pos, $to.pos, (node, pos) => {
              if (can || false)
                  return false;
              can = node.inlineContent && node.type.allowsMarkType(type);
          });
          if (can)
              return true;
      }
      return false;
  }
  /**
  Create a command function that toggles the given mark with the
  given attributes. Will return `false` when the current selection
  doesn't support that mark. This will remove the mark if any marks
  of that type exist in the selection, or add it otherwise. If the
  selection is empty, this applies to the [stored
  marks](https://prosemirror.net/docs/ref/#state.EditorState.storedMarks) instead of a range of the
  document.
  */
  function toggleMark(markType, attrs = null, options) {
      return function (state, dispatch) {
          let { empty, $cursor, ranges } = state.selection;
          if ((empty && !$cursor) || !markApplies(state.doc, ranges, markType))
              return false;
          if (dispatch) {
              if ($cursor) {
                  if (markType.isInSet(state.storedMarks || $cursor.marks()))
                      dispatch(state.tr.removeStoredMark(markType));
                  else
                      dispatch(state.tr.addStoredMark(markType.create(attrs)));
              }
              else {
                  let add, tr = state.tr;
                  {
                      add = !ranges.some(r => state.doc.rangeHasMark(r.$from.pos, r.$to.pos, markType));
                  }
                  for (let i = 0; i < ranges.length; i++) {
                      let { $from, $to } = ranges[i];
                      if (!add) {
                          tr.removeMark($from.pos, $to.pos, markType);
                      }
                      else {
                          let from = $from.pos, to = $to.pos, start = $from.nodeAfter, end = $to.nodeBefore;
                          let spaceStart = start && start.isText ? /^\s*/.exec(start.text)[0].length : 0;
                          let spaceEnd = end && end.isText ? /\s*$/.exec(end.text)[0].length : 0;
                          if (from + spaceStart < to) {
                              from += spaceStart;
                              to -= spaceEnd;
                          }
                          tr.addMark(from, to, markType.create(attrs));
                      }
                  }
                  dispatch(tr.scrollIntoView());
              }
          }
          return true;
      };
  }
  /**
  Combine a number of command functions into a single function (which
  calls them one by one until one returns true).
  */
  function chainCommands(...commands) {
      return function (state, dispatch, view) {
          for (let i = 0; i < commands.length; i++)
              if (commands[i](state, dispatch, view))
                  return true;
          return false;
      };
  }
  let backspace = chainCommands(deleteSelection, joinBackward, selectNodeBackward);
  let del = chainCommands(deleteSelection, joinForward, selectNodeForward);
  /**
  A basic keymap containing bindings not specific to any schema.
  Binds the following keys (when multiple commands are listed, they
  are chained with [`chainCommands`](https://prosemirror.net/docs/ref/#commands.chainCommands)):

  * **Enter** to `newlineInCode`, `createParagraphNear`, `liftEmptyBlock`, `splitBlock`
  * **Mod-Enter** to `exitCode`
  * **Backspace** and **Mod-Backspace** to `deleteSelection`, `joinBackward`, `selectNodeBackward`
  * **Delete** and **Mod-Delete** to `deleteSelection`, `joinForward`, `selectNodeForward`
  * **Mod-Delete** to `deleteSelection`, `joinForward`, `selectNodeForward`
  * **Mod-a** to `selectAll`
  */
  const pcBaseKeymap = {
      "Enter": chainCommands(newlineInCode, createParagraphNear, liftEmptyBlock, splitBlock),
      "Mod-Enter": exitCode,
      "Backspace": backspace,
      "Mod-Backspace": backspace,
      "Shift-Backspace": backspace,
      "Delete": del,
      "Mod-Delete": del,
      "Mod-a": selectAll
  };
  /**
  A copy of `pcBaseKeymap` that also binds **Ctrl-h** like Backspace,
  **Ctrl-d** like Delete, **Alt-Backspace** like Ctrl-Backspace, and
  **Ctrl-Alt-Backspace**, **Alt-Delete**, and **Alt-d** like
  Ctrl-Delete.
  */
  const macBaseKeymap = {
      "Ctrl-h": pcBaseKeymap["Backspace"],
      "Alt-Backspace": pcBaseKeymap["Mod-Backspace"],
      "Ctrl-d": pcBaseKeymap["Delete"],
      "Ctrl-Alt-Backspace": pcBaseKeymap["Mod-Delete"],
      "Alt-Delete": pcBaseKeymap["Mod-Delete"],
      "Alt-d": pcBaseKeymap["Mod-Delete"],
      "Ctrl-a": selectTextblockStart,
      "Ctrl-e": selectTextblockEnd
  };
  for (let key in pcBaseKeymap)
      macBaseKeymap[key] = pcBaseKeymap[key];
  const mac = typeof navigator != "undefined" ? /Mac|iP(hone|[oa]d)/.test(navigator.platform)
      // @ts-ignore
      : typeof os != "undefined" && os.platform ? os.platform() == "darwin" : false;
  /**
  Depending on the detected platform, this will hold
  [`pcBasekeymap`](https://prosemirror.net/docs/ref/#commands.pcBaseKeymap) or
  [`macBaseKeymap`](https://prosemirror.net/docs/ref/#commands.macBaseKeymap).
  */
  const baseKeymap = mac ? macBaseKeymap : pcBaseKeymap;

  /**
  Create a plugin that, when added to a ProseMirror instance,
  causes a decoration to show up at the drop position when something
  is dragged over the editor.

  Nodes may add a `disableDropCursor` property to their spec to
  control the showing of a drop cursor inside them. This may be a
  boolean or a function, which will be called with a view and a
  position, and should return a boolean.
  */
  function dropCursor(options = {}) {
      return new Plugin({
          view(editorView) { return new DropCursorView(editorView, options); }
      });
  }
  class DropCursorView {
      constructor(editorView, options) {
          var _a;
          this.editorView = editorView;
          this.cursorPos = null;
          this.element = null;
          this.timeout = -1;
          this.width = (_a = options.width) !== null && _a !== void 0 ? _a : 1;
          this.color = options.color === false ? undefined : (options.color || "black");
          this.class = options.class;
          this.handlers = ["dragover", "dragend", "drop", "dragleave"].map(name => {
              let handler = (e) => { this[name](e); };
              editorView.dom.addEventListener(name, handler);
              return { name, handler };
          });
      }
      destroy() {
          this.handlers.forEach(({ name, handler }) => this.editorView.dom.removeEventListener(name, handler));
      }
      update(editorView, prevState) {
          if (this.cursorPos != null && prevState.doc != editorView.state.doc) {
              if (this.cursorPos > editorView.state.doc.content.size)
                  this.setCursor(null);
              else
                  this.updateOverlay();
          }
      }
      setCursor(pos) {
          if (pos == this.cursorPos)
              return;
          this.cursorPos = pos;
          if (pos == null) {
              this.element.parentNode.removeChild(this.element);
              this.element = null;
          }
          else {
              this.updateOverlay();
          }
      }
      updateOverlay() {
          let $pos = this.editorView.state.doc.resolve(this.cursorPos);
          let isBlock = !$pos.parent.inlineContent, rect;
          let editorDOM = this.editorView.dom, editorRect = editorDOM.getBoundingClientRect();
          let scaleX = editorRect.width / editorDOM.offsetWidth, scaleY = editorRect.height / editorDOM.offsetHeight;
          if (isBlock) {
              let before = $pos.nodeBefore, after = $pos.nodeAfter;
              if (before || after) {
                  let node = this.editorView.nodeDOM(this.cursorPos - (before ? before.nodeSize : 0));
                  if (node) {
                      let nodeRect = node.getBoundingClientRect();
                      let top = before ? nodeRect.bottom : nodeRect.top;
                      if (before && after)
                          top = (top + this.editorView.nodeDOM(this.cursorPos).getBoundingClientRect().top) / 2;
                      let halfWidth = (this.width / 2) * scaleY;
                      rect = { left: nodeRect.left, right: nodeRect.right, top: top - halfWidth, bottom: top + halfWidth };
                  }
              }
          }
          if (!rect) {
              let coords = this.editorView.coordsAtPos(this.cursorPos);
              let halfWidth = (this.width / 2) * scaleX;
              rect = { left: coords.left - halfWidth, right: coords.left + halfWidth, top: coords.top, bottom: coords.bottom };
          }
          let parent = this.editorView.dom.offsetParent;
          if (!this.element) {
              this.element = parent.appendChild(document.createElement("div"));
              if (this.class)
                  this.element.className = this.class;
              this.element.style.cssText = "position: absolute; z-index: 50; pointer-events: none;";
              if (this.color) {
                  this.element.style.backgroundColor = this.color;
              }
          }
          this.element.classList.toggle("prosemirror-dropcursor-block", isBlock);
          this.element.classList.toggle("prosemirror-dropcursor-inline", !isBlock);
          let parentLeft, parentTop;
          if (!parent || parent == document.body && getComputedStyle(parent).position == "static") {
              parentLeft = -pageXOffset;
              parentTop = -pageYOffset;
          }
          else {
              let rect = parent.getBoundingClientRect();
              let parentScaleX = rect.width / parent.offsetWidth, parentScaleY = rect.height / parent.offsetHeight;
              parentLeft = rect.left - parent.scrollLeft * parentScaleX;
              parentTop = rect.top - parent.scrollTop * parentScaleY;
          }
          this.element.style.left = (rect.left - parentLeft) / scaleX + "px";
          this.element.style.top = (rect.top - parentTop) / scaleY + "px";
          this.element.style.width = (rect.right - rect.left) / scaleX + "px";
          this.element.style.height = (rect.bottom - rect.top) / scaleY + "px";
      }
      scheduleRemoval(timeout) {
          clearTimeout(this.timeout);
          this.timeout = setTimeout(() => this.setCursor(null), timeout);
      }
      dragover(event) {
          if (!this.editorView.editable)
              return;
          let pos = this.editorView.posAtCoords({ left: event.clientX, top: event.clientY });
          let node = pos && pos.inside >= 0 && this.editorView.state.doc.nodeAt(pos.inside);
          let disableDropCursor = node && node.type.spec.disableDropCursor;
          let disabled = typeof disableDropCursor == "function"
              ? disableDropCursor(this.editorView, pos, event)
              : disableDropCursor;
          if (pos && !disabled) {
              let target = pos.pos;
              if (this.editorView.dragging && this.editorView.dragging.slice) {
                  let point = dropPoint(this.editorView.state.doc, target, this.editorView.dragging.slice);
                  if (point != null)
                      target = point;
              }
              this.setCursor(target);
              this.scheduleRemoval(5000);
          }
      }
      dragend() {
          this.scheduleRemoval(20);
      }
      drop() {
          this.scheduleRemoval(20);
      }
      dragleave(event) {
          if (!this.editorView.dom.contains(event.relatedTarget))
              this.setCursor(null);
      }
  }

  /**
  Gap cursor selections are represented using this class. Its
  `$anchor` and `$head` properties both point at the cursor position.
  */
  class GapCursor extends Selection {
      /**
      Create a gap cursor.
      */
      constructor($pos) {
          super($pos, $pos);
      }
      map(doc, mapping) {
          let $pos = doc.resolve(mapping.map(this.head));
          return GapCursor.valid($pos) ? new GapCursor($pos) : Selection.near($pos);
      }
      content() { return Slice.empty; }
      eq(other) {
          return other instanceof GapCursor && other.head == this.head;
      }
      toJSON() {
          return { type: "gapcursor", pos: this.head };
      }
      /**
      @internal
      */
      static fromJSON(doc, json) {
          if (typeof json.pos != "number")
              throw new RangeError("Invalid input for GapCursor.fromJSON");
          return new GapCursor(doc.resolve(json.pos));
      }
      /**
      @internal
      */
      getBookmark() { return new GapBookmark(this.anchor); }
      /**
      @internal
      */
      static valid($pos) {
          let parent = $pos.parent;
          if (parent.isTextblock || !closedBefore($pos) || !closedAfter($pos))
              return false;
          let override = parent.type.spec.allowGapCursor;
          if (override != null)
              return override;
          let deflt = parent.contentMatchAt($pos.index()).defaultType;
          return deflt && deflt.isTextblock;
      }
      /**
      @internal
      */
      static findGapCursorFrom($pos, dir, mustMove = false) {
          search: for (;;) {
              if (!mustMove && GapCursor.valid($pos))
                  return $pos;
              let pos = $pos.pos, next = null;
              // Scan up from this position
              for (let d = $pos.depth;; d--) {
                  let parent = $pos.node(d);
                  if (dir > 0 ? $pos.indexAfter(d) < parent.childCount : $pos.index(d) > 0) {
                      next = parent.child(dir > 0 ? $pos.indexAfter(d) : $pos.index(d) - 1);
                      break;
                  }
                  else if (d == 0) {
                      return null;
                  }
                  pos += dir;
                  let $cur = $pos.doc.resolve(pos);
                  if (GapCursor.valid($cur))
                      return $cur;
              }
              // And then down into the next node
              for (;;) {
                  let inside = dir > 0 ? next.firstChild : next.lastChild;
                  if (!inside) {
                      if (next.isAtom && !next.isText && !NodeSelection.isSelectable(next)) {
                          $pos = $pos.doc.resolve(pos + next.nodeSize * dir);
                          mustMove = false;
                          continue search;
                      }
                      break;
                  }
                  next = inside;
                  pos += dir;
                  let $cur = $pos.doc.resolve(pos);
                  if (GapCursor.valid($cur))
                      return $cur;
              }
              return null;
          }
      }
  }
  GapCursor.prototype.visible = false;
  GapCursor.findFrom = GapCursor.findGapCursorFrom;
  Selection.jsonID("gapcursor", GapCursor);
  class GapBookmark {
      constructor(pos) {
          this.pos = pos;
      }
      map(mapping) {
          return new GapBookmark(mapping.map(this.pos));
      }
      resolve(doc) {
          let $pos = doc.resolve(this.pos);
          return GapCursor.valid($pos) ? new GapCursor($pos) : Selection.near($pos);
      }
  }
  function closedBefore($pos) {
      for (let d = $pos.depth; d >= 0; d--) {
          let index = $pos.index(d), parent = $pos.node(d);
          // At the start of this parent, look at next one
          if (index == 0) {
              if (parent.type.spec.isolating)
                  return true;
              continue;
          }
          // See if the node before (or its first ancestor) is closed
          for (let before = parent.child(index - 1);; before = before.lastChild) {
              if ((before.childCount == 0 && !before.inlineContent) || before.isAtom || before.type.spec.isolating)
                  return true;
              if (before.inlineContent)
                  return false;
          }
      }
      // Hit start of document
      return true;
  }
  function closedAfter($pos) {
      for (let d = $pos.depth; d >= 0; d--) {
          let index = $pos.indexAfter(d), parent = $pos.node(d);
          if (index == parent.childCount) {
              if (parent.type.spec.isolating)
                  return true;
              continue;
          }
          for (let after = parent.child(index);; after = after.firstChild) {
              if ((after.childCount == 0 && !after.inlineContent) || after.isAtom || after.type.spec.isolating)
                  return true;
              if (after.inlineContent)
                  return false;
          }
      }
      return true;
  }

  /**
  Create a gap cursor plugin. When enabled, this will capture clicks
  near and arrow-key-motion past places that don't have a normally
  selectable position nearby, and create a gap cursor selection for
  them. The cursor is drawn as an element with class
  `ProseMirror-gapcursor`. You can either include
  `style/gapcursor.css` from the package's directory or add your own
  styles to make it visible.
  */
  function gapCursor() {
      return new Plugin({
          props: {
              decorations: drawGapCursor,
              createSelectionBetween(_view, $anchor, $head) {
                  return $anchor.pos == $head.pos && GapCursor.valid($head) ? new GapCursor($head) : null;
              },
              handleClick,
              handleKeyDown,
              handleDOMEvents: { beforeinput: beforeinput }
          }
      });
  }
  const handleKeyDown = keydownHandler({
      "ArrowLeft": arrow("horiz", -1),
      "ArrowRight": arrow("horiz", 1),
      "ArrowUp": arrow("vert", -1),
      "ArrowDown": arrow("vert", 1)
  });
  function arrow(axis, dir) {
      const dirStr = axis == "vert" ? (dir > 0 ? "down" : "up") : (dir > 0 ? "right" : "left");
      return function (state, dispatch, view) {
          let sel = state.selection;
          let $start = dir > 0 ? sel.$to : sel.$from, mustMove = sel.empty;
          if (sel instanceof TextSelection) {
              if (!view.endOfTextblock(dirStr) || $start.depth == 0)
                  return false;
              mustMove = false;
              $start = state.doc.resolve(dir > 0 ? $start.after() : $start.before());
          }
          let $found = GapCursor.findGapCursorFrom($start, dir, mustMove);
          if (!$found)
              return false;
          if (dispatch)
              dispatch(state.tr.setSelection(new GapCursor($found)));
          return true;
      };
  }
  function handleClick(view, pos, event) {
      if (!view || !view.editable)
          return false;
      let $pos = view.state.doc.resolve(pos);
      if (!GapCursor.valid($pos))
          return false;
      let clickPos = view.posAtCoords({ left: event.clientX, top: event.clientY });
      if (clickPos && clickPos.inside > -1 && NodeSelection.isSelectable(view.state.doc.nodeAt(clickPos.inside)))
          return false;
      view.dispatch(view.state.tr.setSelection(new GapCursor($pos)));
      return true;
  }
  // This is a hack that, when a composition starts while a gap cursor
  // is active, quickly creates an inline context for the composition to
  // happen in, to avoid it being aborted by the DOM selection being
  // moved into a valid position.
  function beforeinput(view, event) {
      if (event.inputType != "insertCompositionText" || !(view.state.selection instanceof GapCursor))
          return false;
      let { $from } = view.state.selection;
      let insert = $from.parent.contentMatchAt($from.index()).findWrapping(view.state.schema.nodes.text);
      if (!insert)
          return false;
      let frag = Fragment.empty;
      for (let i = insert.length - 1; i >= 0; i--)
          frag = Fragment.from(insert[i].createAndFill(null, frag));
      let tr = view.state.tr.replace($from.pos, $from.pos, new Slice(frag, 0, 0));
      tr.setSelection(TextSelection.near(tr.doc.resolve($from.pos + 1)));
      view.dispatch(tr);
      return false;
  }
  function drawGapCursor(state) {
      if (!(state.selection instanceof GapCursor))
          return null;
      let node = document.createElement("div");
      node.className = "ProseMirror-gapcursor";
      return DecorationSet.create(state.doc, [Decoration.widget(state.selection.head, node, { key: "gapcursor" })]);
  }

  class SearchQuery {
      /**
      Create a query object.
      */
      constructor(config) {
          this.search = config.search;
          this.caseSensitive = !!config.caseSensitive;
          this.literal = !!config.literal;
          this.regexp = !!config.regexp;
          this.replace = config.replace || "";
          this.valid = !!this.search && !(this.regexp && !validRegExp(this.search));
          this.wholeWord = !!config.wholeWord;
          this.filter = config.filter || null;
          this.impl = !this.valid ? nullQuery : this.regexp ? new RegExpQuery(this) : new StringQuery(this);
      }
      /**
      Compare this query to another query.
      */
      eq(other) {
          return this.search == other.search && this.replace == other.replace &&
              this.caseSensitive == other.caseSensitive && this.regexp == other.regexp &&
              this.wholeWord == other.wholeWord;
      }
      /**
      Find the next occurrence of this query in the given range.
      */
      findNext(state, from = 0, to = state.doc.content.size) {
          for (;;) {
              if (from >= to)
                  return null;
              let result = this.impl.findNext(state, from, to);
              if (!result || this.checkResult(state, result))
                  return result;
              from = result.from + 1;
          }
      }
      /**
      Find the previous occurrence of this query in the given range.
      Note that, if `to` is given, it should be _less_ than `from`.
      */
      findPrev(state, from = state.doc.content.size, to = 0) {
          for (;;) {
              if (from <= to)
                  return null;
              let result = this.impl.findPrev(state, from, to);
              if (!result || this.checkResult(state, result))
                  return result;
              from = result.to - 1;
          }
      }
      /**
      @internal
      */
      checkResult(state, result) {
          return (!this.wholeWord || checkWordBoundary(state, result.from) && checkWordBoundary(state, result.to)) &&
              (!this.filter || this.filter(state, result));
      }
      /**
      @internal
      */
      unquote(string) {
          return this.literal ? string
              : string.replace(/\\([nrt\\])/g, (_, ch) => ch == "n" ? "\n" : ch == "r" ? "\r" : ch == "t" ? "\t" : "\\");
      }
      /**
      Get the ranges that should be replaced for this result. This can
      return multiple ranges when `this.replace` contains
      `$1`/`$&`-style placeholders, in which case the preserved
      content is skipped by the replacements.
      
      Ranges are sorted by position, and `from`/`to` positions all
      refer to positions in `state.doc`. When applying these, you'll
      want to either apply them from back to front, or map these
      positions through your transaction's current mapping.
      */
      getReplacements(state, result) {
          let $from = state.doc.resolve(result.from);
          let marks = $from.marksAcross(state.doc.resolve(result.to));
          let ranges = [];
          let frag = Fragment.empty, pos = result.from, { match } = result;
          let groups = match ? getGroupIndices(match) : [[0, result.to - result.from]];
          let replParts = parseReplacement(this.unquote(this.replace)), groupSpan;
          for (let part of replParts) {
              if (typeof part == "string") { // Replacement text
                  frag = frag.addToEnd(state.schema.text(part, marks));
              }
              else if (groupSpan = groups[part.group]) {
                  let from = result.matchStart + groupSpan[0], to = result.matchStart + groupSpan[1];
                  if (part.copy) { // Copied content
                      frag = frag.append(state.doc.slice(from, to).content);
                  }
                  else { // Skipped content
                      if (frag != Fragment.empty || from > pos) {
                          ranges.push({ from: pos, to: from, insert: new Slice(frag, 0, 0) });
                          frag = Fragment.empty;
                      }
                      pos = to;
                  }
              }
          }
          if (frag != Fragment.empty || pos < result.to)
              ranges.push({ from: pos, to: result.to, insert: new Slice(frag, 0, 0) });
          return ranges;
      }
  }
  const nullQuery = new class {
      findNext() { return null; }
      findPrev() { return null; }
  };
  class StringQuery {
      constructor(query) {
          this.query = query;
          let string = query.unquote(query.search);
          if (!query.caseSensitive)
              string = string.toLowerCase();
          this.string = string;
      }
      findNext(state, from, to) {
          return scanTextblocks(state.doc, from, to, (node, start) => {
              let off = Math.max(from, start);
              let content = textContent(node).slice(off - start, Math.min(node.content.size, to - start));
              let index = (this.query.caseSensitive ? content : content.toLowerCase()).indexOf(this.string);
              return index < 0 ? null : { from: off + index, to: off + index + this.string.length, match: null, matchStart: start };
          });
      }
      findPrev(state, from, to) {
          return scanTextblocks(state.doc, from, to, (node, start) => {
              let off = Math.max(start, to);
              let content = textContent(node).slice(off - start, Math.min(node.content.size, from - start));
              if (!this.query.caseSensitive)
                  content = content.toLowerCase();
              let index = content.lastIndexOf(this.string);
              return index < 0 ? null : { from: off + index, to: off + index + this.string.length, match: null, matchStart: start };
          });
      }
  }
  const baseFlags = "g" + (/x/.unicode == null ? "" : "u") + (/x/.hasIndices == null ? "" : "d");
  class RegExpQuery {
      constructor(query) {
          this.query = query;
          this.regexp = new RegExp(query.search, baseFlags + (query.caseSensitive ? "" : "i"));
      }
      findNext(state, from, to) {
          return scanTextblocks(state.doc, from, to, (node, start) => {
              let content = textContent(node).slice(0, Math.min(node.content.size, to - start));
              this.regexp.lastIndex = from - start;
              let match = this.regexp.exec(content);
              return match ? { from: start + match.index, to: start + match.index + match[0].length, match, matchStart: start } : null;
          });
      }
      findPrev(state, from, to) {
          return scanTextblocks(state.doc, from, to, (node, start) => {
              let content = textContent(node).slice(0, Math.min(node.content.size, from - start));
              let match;
              for (let off = 0;;) {
                  this.regexp.lastIndex = off;
                  let next = this.regexp.exec(content);
                  if (!next)
                      break;
                  match = next;
                  off = next.index + 1;
              }
              return match ? { from: start + match.index, to: start + match.index + match[0].length, match, matchStart: start } : null;
          });
      }
  }
  function getGroupIndices(match) {
      if (match.indices)
          return match.indices;
      let result = [[0, match[0].length]];
      for (let i = 1, pos = 0; i < match.length; i++) {
          let found = match[i] ? match[0].indexOf(match[i], pos) : -1;
          result.push(found < 0 ? undefined : [found, pos = found + match[i].length]);
      }
      return result;
  }
  function parseReplacement(text) {
      let result = [], highestSeen = -1;
      function add(text) {
          let last = result.length - 1;
          if (last > -1 && typeof result[last] == "string")
              result[last] += text;
          else
              result.push(text);
      }
      while (text.length) {
          let m = /\$([$&\d+])/.exec(text);
          if (!m) {
              add(text);
              return result;
          }
          if (m.index > 0)
              add(text.slice(0, m.index + (m[1] == "$" ? 1 : 0)));
          if (m[1] != "$") {
              let n = m[1] == "&" ? 0 : +m[1];
              if (highestSeen >= n) {
                  result.push({ group: n, copy: true });
              }
              else {
                  highestSeen = n || 1000;
                  result.push({ group: n, copy: false });
              }
          }
          text = text.slice(m.index + m[0].length);
      }
      return result;
  }
  function validRegExp(source) {
      try {
          new RegExp(source, baseFlags);
          return true;
      }
      catch (_a) {
          return false;
      }
  }
  const TextContentCache = new WeakMap();
  function textContent(node) {
      let cached = TextContentCache.get(node);
      if (cached)
          return cached;
      let content = "";
      for (let i = 0; i < node.childCount; i++) {
          let child = node.child(i);
          if (child.isText)
              content += child.text;
          else if (child.isLeaf)
              content += "\ufffc";
          else
              content += " " + textContent(child) + " ";
      }
      TextContentCache.set(node, content);
      return content;
  }
  function scanTextblocks(node, from, to, f, nodeStart = 0) {
      if (node.inlineContent) {
          return f(node, nodeStart);
      }
      else if (!node.isLeaf) {
          if (from > to) {
              for (let i = node.childCount - 1, pos = nodeStart + node.content.size; i >= 0 && pos > to; i--) {
                  let child = node.child(i);
                  pos -= child.nodeSize;
                  if (pos < from) {
                      let result = scanTextblocks(child, from, to, f, pos + 1);
                      if (result != null)
                          return result;
                  }
              }
          }
          else {
              for (let i = 0, pos = nodeStart; i < node.childCount && pos < to; i++) {
                  let child = node.child(i), start = pos;
                  pos += child.nodeSize;
                  if (pos > from) {
                      let result = scanTextblocks(child, from, to, f, start + 1);
                      if (result != null)
                          return result;
                  }
              }
          }
      }
      return null;
  }
  function checkWordBoundary(state, pos) {
      let $pos = state.doc.resolve(pos);
      let before = $pos.nodeBefore, after = $pos.nodeAfter;
      if (!before || !after || !before.isText || !after.isText)
          return true;
      return !/\p{L}$/u.test(before.text) || !/^\p{L}/u.test(after.text);
  }

  class SearchState {
      constructor(query, range, deco) {
          this.query = query;
          this.range = range;
          this.deco = deco;
      }
  }
  function buildMatchDeco(state, query, range) {
      if (!query.valid)
          return DecorationSet.empty;
      let deco = [];
      let sel = state.selection;
      for (let pos = range ? range.from : 0, end = range ? range.to : state.doc.content.size;;) {
          let next = query.findNext(state, pos, end);
          if (!next)
              break;
          let cls = next.from == sel.from && next.to == sel.to ? "ProseMirror-active-search-match" : "ProseMirror-search-match";
          deco.push(Decoration.inline(next.from, next.to, { class: cls }));
          pos = next.to;
      }
      return DecorationSet.create(state.doc, deco);
  }
  const searchKey = new PluginKey("search");
  /**
  Returns a plugin that stores a current search query and searched
  range, and highlights matches of the query.
  */
  function search(options = {}) {
      return new Plugin({
          key: searchKey,
          state: {
              init(_config, state) {
                  let query = options.initialQuery || new SearchQuery({ search: "" });
                  let range = options.initialRange || null;
                  return new SearchState(query, range, buildMatchDeco(state, query, range));
              },
              apply(tr, search, _oldState, state) {
                  let set = tr.getMeta(searchKey);
                  if (set)
                      return new SearchState(set.query, set.range, buildMatchDeco(state, set.query, set.range));
                  if (tr.docChanged || tr.selectionSet) {
                      let range = search.range;
                      if (range) {
                          let from = tr.mapping.map(range.from, 1);
                          let to = tr.mapping.map(range.to, -1);
                          range = from < to ? { from, to } : null;
                      }
                      search = new SearchState(search.query, range, buildMatchDeco(state, search.query, range));
                  }
                  return search;
              }
          },
          props: {
              decorations: state => searchKey.getState(state).deco
          }
      });
  }
  /**
  Access the decoration set holding the currently highlighted search
  matches in the document.
  */
  function getMatchHighlights(state) {
      let search = searchKey.getState(state);
      return search ? search.deco : DecorationSet.empty;
  }
  /**
  Add metadata to a transaction that updates the active search query
  and searched range, when dispatched.
  */
  function setSearchState(tr, query, range = null) {
      return tr.setMeta(searchKey, { query, range });
  }
  function nextMatch(search, state, wrap, curFrom, curTo) {
      let range = search.range || { from: 0, to: state.doc.content.size };
      let next = search.query.findNext(state, Math.max(curTo, range.from), range.to);
      if (!next && wrap)
          next = search.query.findNext(state, range.from, Math.min(curFrom, range.to));
      return next;
  }
  function prevMatch(search, state, wrap, curFrom, curTo) {
      let range = search.range || { from: 0, to: state.doc.content.size };
      let prev = search.query.findPrev(state, Math.min(curFrom, range.to), range.from);
      if (!prev && wrap)
          prev = search.query.findPrev(state, range.to, Math.max(curTo, range.from));
      return prev;
  }
  function findCommand(wrap, dir) {
      return (state, dispatch) => {
          let search = searchKey.getState(state);
          if (!search || !search.query.valid)
              return false;
          let { from, to } = state.selection;
          let next = dir > 0 ? nextMatch(search, state, wrap, from, to) : prevMatch(search, state, wrap, from, to);
          if (!next)
              return false;
          let selection = TextSelection.create(state.doc, next.from, next.to);
          if (dispatch)
              dispatch(state.tr.setSelection(selection).scrollIntoView());
          return true;
      };
  }
  /**
  Find the next instance of the search query after the current
  selection and move the selection to it.
  */
  const findNext = findCommand(true, 1);
  /**
  Find the previous instance of the search query and move the
  selection to it.
  */
  const findPrev = findCommand(true, -1);

  /* global view */

  /**
   * The NodeView to support divs, as installed in main.js.
   */
  class DivView {
      constructor(node) {
          const div = document.createElement('div');
          div.setAttribute('id', node.attrs.id);
          div.setAttribute('class', node.attrs.cssClass);
          // Note that the click is reported using createSelectionBetween on the EditorView.
          // Here we have access to the node id and can specialize for divs.
          // Because the contentDOM is not set for non-editable divs, the selection never gets 
          // set in them, but will be set to the first selectable node after.
          div.addEventListener('click', () => {
              selectedID = node.attrs.id;
          });
          const htmlFragment = _fragmentFromNode(node);
          if (node.attrs.editable) {
              div.innerHTML = _htmlFromFragment(htmlFragment);
              this.dom = div;
              this.contentDOM = this.dom;
          } else {
              // For non-editable divs, we have to handle all the interaction, which only occurs for buttons.
              // Note ProseMirror does not render children inside of non-editable divs. We deal with this by 
              // supplying the entire content of the div in htmlContents, and when we need to change the div
              // (for example, adding and removing a button group), we must then update the htmlContents 
              // accordingly. This happens in addDiv and removeDiv.
              div.innerHTML = _htmlFromFragment(htmlFragment);
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
                      );
                  });
              });
              this.dom = div;
          }
      }

      /**
       * Return the rectangle of the button in a form that can be digested consistently.
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

  class LinkView {
      constructor(node, view) {
          let href = node.attrs.href;
          let title = '\u2325+Click to follow\n' + href;
          const link = document.createElement('a');
          link.setAttribute('href', href);
          link.setAttribute('title', title);
          link.addEventListener('click', (ev)=> {
              if (ev.altKey) {
                  if (href.startsWith('#')) {
                      let id = href.substring(1);
                      let {pos} = nodeWithId(id, view.state);
                      if (pos) {
                          let resolvedPos = view.state.tr.doc.resolve(pos);
                          let selection = TextSelection.near(resolvedPos);
                          let transaction = view.state.tr
                              .setSelection(selection)
                              .scrollIntoView();
                          view.dispatch(transaction);
                          selectionChanged();
                      }
                  } else {
                      window.open(href);
                  }
              }
          });
          this.dom = link;
          this.contentDOM = this.dom;
      }
  }

  /**
   * The NodeView to support resizable images and callbacks, as installed in main.js.
   * 
   * The ResizableImage instance holds onto the actual HTMLImageElement and deals with the styling,
   * event listeners, and resizing work.
   * 
   * Many thanks to contributors to this thread: https://discuss.prosemirror.net/t/image-resize/1489
   * and the accompanying Glitch project https://glitch.com/edit/#!/toothsome-shoemaker
   */
  class ImageView {
      constructor(node, view, getPos) {
          this.resizableImage = new ResizableImage(node, getPos());
          this.dom = this.resizableImage.imageContainer;
      }
      
      selectNode() {
          this.resizableImage.imageElement.classList.add("ProseMirror-selectednode");
          this.resizableImage.select();
          selectionChanged();
      }
    
      deselectNode() {
          this.resizableImage.imageElement.classList.remove("ProseMirror-selectednode");
          this.resizableImage.deselect();
          selectionChanged();
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
      
      constructor(node, pos) {
          this._pos = pos;                    // How to find node in view.state.doc
          this._minImageSize = 18;             // Large enough for visibility and for the handles to display properly
          this._imageElement = this.imageElementFrom(node);
          this._imageContainer = this.containerFor(this.imageElement);
          this._startDimensions = this.dimensionsFrom(this.imageElement);
          this._startEvent = null;            // The ev that was passed to startResize
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
              .setMeta("imageLoaded", {'src': src});
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
          const {width, height} = this.currentDimensions;
          const transaction = view.state.tr
              .setNodeAttribute(this._pos, 'width', width)
              .setNodeAttribute(this._pos, 'height', height);
          // Reselect the node again, so it ends like it started - selected
          transaction.setSelection(new NodeSelection(transaction.doc.resolve(this._pos)));
          view.dispatch(transaction);
      };

      /**
       * Return the HTML Image Element displayed in the ImageView
       * @param {Node} node 
       * @returns HTMLImageElement
       */
      imageElementFrom(node) {
          const img = document.createElement('img');
          const src = node.attrs.src;

          // If the img node does not have both width and height attr, get them from naturalWidth 
          // after loading. Use => style function to reference this.
          img.addEventListener('load', e => {
              if (node.attrs.width && node.attrs.height) {
                  img.setAttribute('width', node.attrs.width);
                  img.setAttribute('height', node.attrs.height);
              } else {
                  // naturalWidth and naturalHeight will be zero if not known
                  let width = Math.max(e.target.naturalWidth, this._minImageSize);
                  node.attrs.width = width;
                  img.setAttribute('width', width);
                  let height = Math.max(e.target.naturalHeight, this._minImageSize);
                  node.attrs.height = height;
                  img.setAttribute('height', height);
              }
              this.imageLoaded(src);
          });

          // Display a broken image background and notify of any errors.
          img.addEventListener('error', () => {
              // https://fonts.google.com/icons?selected=Material+Symbols+Outlined:broken_image:FILL@0;wght@400;GRAD@0;opsz@20&icon.query=missing&icon.size=18&icon.color=%231f1f1f
              const imageSvg = '<svg xmlns="http://www.w3.org/2000/svg" height="20px" viewBox="0 -960 960 960" width="20px" fill="#1f1f1f"><path d="M216-144q-29 0-50.5-21.5T144-216v-528q0-29.7 21.5-50.85Q187-816 216-816h528q29.7 0 50.85 21.15Q816-773.7 816-744v528q0 29-21.15 50.5T744-144H216Zm48-303 144-144 144 144 144-144 48 48v-201H216v249l48 48Zm-48 231h528v-225l-48-48-144 144-144-144-144 144-48-48v177Zm0 0v-240 63-351 528Z"/></svg>';
              const image64 = btoa(imageSvg);
              const imageUrl = `url("data:image/svg+xml;base64,${image64}")`;
              img.style.background = "lightgray";  // So we can see it in light or dark mode
              img.style.backgroundImage = imageUrl;
              img.setAttribute('width', this._minImageSize);
              img.setAttribute('height', this._minImageSize);
              this.imageLoaded(src);
          });
          
          img.setAttribute("src", src);

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
       * Set the attributes for the imageContainer and populate the spans that show the 
       * resizing handles. Add the mousedown event listener to initiate resizing.
       */
      select() {
          this.imageContainer.setAttribute('class', 'resize-container');
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
          this.imageContainer.addEventListener('mousedown', this.startResize = this.startResize.bind(this));
          this.addPinchGestureEvents();
      }

      /**
       * Remove the attributes for the imageContainer and the spans that show the 
       * resizing handles. Remove the mousedown event listener.
       */
      deselect() {
          this.removePinchGestureEvents();
          this.imageContainer.removeEventListener('mousedown', this.startResize);
          const handles = this.imageContainer.querySelectorAll('span');
          handles.forEach((handle) => {this.imageContainer.removeChild(handle);});
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
          document.addEventListener('touchstart', this.handleTouchStart = this.handleTouchStart.bind(this));
          document.addEventListener('touchmove', this.handleTouchMove = this.handleTouchMove.bind(this));
          document.addEventListener('touchend', this.handleTouchEnd = this.handleTouchEnd.bind(this));
          document.addEventListener('touchcancel', this.handleTouchEnd = this.handleTouchEnd.bind(this));
      };
      
      /**
       * Remove event listeners supporting pinch resizing.
       *
       * Listeners are removed when the resizableImage is deselected.
       */
      removePinchGestureEvents() {
          document.removeEventListener('touchstart', this.handleTouchStart);
          document.removeEventListener('touchmove', this.handleTouchMove);
          document.removeEventListener('touchend', this.handleTouchEnd);
          document.removeEventListener('touchcancel', this.handleTouchEnd);
      };

      /**
       * Start resize on a mousedown event.
       * @param {Event} ev    The mousedown Event.
       */
      startResize(ev) {
          ev.preventDefault();
          // The event can trigger on imageContainer and its contents, including spans and imageElement.
          if (this._startEvent) return;   // We are already resizing
          this._startEvent = ev;          // Track the event that kicked things off

          //TODO: Avoid selecting text while resizing.
          // Setting webkitUserSelect to 'none' used to help when the style could be applied to 
          // the actual HTML document being edited, but it doesn't seem to work when applied to 
          // view.dom. Leaving a record here for now.
          // view.state.tr.style.webkitUserSelect = 'none';  // Prevent selection of text as mouse moves

          // Use document to receive events even when cursor goes outside of the imageContainer
          document.addEventListener('mousemove', this.resizing = this.resizing.bind(this));
          document.addEventListener('mouseup', this.endResize = this.endResize.bind(this));
          this._startDimensions = this.dimensionsFrom(this.imageElement);
      };
      
      /**
       * End resizing on a mouseup event.
       * @param {Event} ev    The mouseup Event.
       */
      endResize(ev) {
          ev.preventDefault();
          this._startEvent = null;

          //TODO: Restore selecting text when done resizing.
          // Setting webkitUserSelect to 'text' used to help when the style could be applied to 
          // the actual HTML document being edited, but it doesn't seem to work when applied to 
          // view.dom. Leaving a record here for now.
          //view.dom.style.webkitUserSelect = 'text';  // Restore selection of text now that we are done

          document.removeEventListener('mousemove', this.resizing);
          document.removeEventListener('mouseup', this.endResize);
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
          }        this._imageElement.setAttribute('width', width);
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
              }        }    };
      
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
              this.replaceTouch(touch, this._touchCache);
              if (this._touchCache.length < 2) {
                  // If we are only touching a single place, then replace it in the touchStartCache as it moves
                  this.replaceTouch(touch, this._touchStartCache);
              } else {
                  // Otherwise, we are touching two places and are pinching
                  this.startPinch();   // A no-op if we have already started
                  this.pinch();
              }        }
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
              }        }    };
      
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
                  }            }        }        return null;
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
              }        }        return null;
      };
      
      /**
       * Replace the touch in touchArray if it has the same identifier, else do nothing
       */
      replaceTouch(touch, touchArray) {
          const i = this.indexOfTouch(touch, touchArray);
          if (i !== null) { touchArray[i] = touch; }
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
          }    };

      /**
       * Pinch the resizableImage based on the information in the touchCache and the startDx/startDy
       * we captured when pinching started. The touchCache has the two touches that are active.
       */
      pinch() {
          // Here currentDx and currentDx are the current distance between the two
          // pointers, which have to be compared to the start distances to determine
          // if we are zooming in or out
          const touchCache = this._touchCache;
          const x0 = touchCache[0].pageX;
          const y0 = touchCache[0].pageY;
          const x1 = touchCache[1].pageX;
          const y1 = touchCache[1].pageY;
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
          }        this._imageElement.setAttribute('width', width);
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
          }    };
     
      /**
       * Callback with the resizableImage data that allows us to put an image
       * in the clipboard without all the browser shenanigans.
       */
      copyToClipboard() {
          const image = this._imageElement;
          if (!image) { return }        const messageDict = {
              'messageType' : 'copyImage',
              'src' : image.src,
              'alt' : image.alt,
              'dimensions' : this._startDimensions
          };
          _callback(JSON.stringify(messageDict));
      };
      
  }
  /**
   * Define various arrays of tags used to represent MarkupEditor-specific concepts.
   *
   * For example, "Paragraph Style" is a MarkupEditor concept that doesn't map directly to HTML or CSS.
   */

  // Add STRONG and EM (leaving B and I) to support default ProseMirror output   
  const _formatTags = ['B', 'STRONG', 'I', 'EM', 'U', 'DEL', 'SUB', 'SUP', 'CODE'];       // All possible (nestable) formats

  const _minimalStyleTags = ['H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'BLOCKQUOTE', 'PRE'];           // Convert to 'P' for pasteText

  const _voidTags = ['BR', 'IMG', 'AREA', 'COL', 'EMBED', 'HR', 'INPUT', 'LINK', 'META', 'PARAM']; // Tags that are self-closing

  /**
   * `selectedID` is the id of the contentEditable DIV containing the currently selected element.
   */
  let selectedID = null;

  /**
   * MUError captures internal errors and makes it easy to communicate them externally.
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
      static Style = new MUError('Style', 'Unable to apply style at selection.')
      
      setInfo(info) {
          this.info = info;
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
  }
  /**
   * The Searcher class lets us find text ranges that match a search string within the editor element.
   * 
   * The searcher uses the ProseMirror search plugin https://github.com/proseMirror/prosemirror-search to create 
   * and track ranges within the doc that match a given SearchQuery.
   * 
   * Note that `isActive` and intercepting Enter/Shift-Enter is only relevant in the Swift case, where the search 
   * bar is implemented in Swift.
   */
  class Searcher {
      
      constructor() {
          this._searchString = null;      // what we are searching for
          this._direction = 'forward';    // direction we are searching in
          this._caseSensitive = false;    // whether the search is case sensitive
          this._forceIndexing = true;     // true === rebuild foundRanges before use; false === use foundRanges\
          this._searchQuery = null;        // the SearchQuery we use
          this._isActive = false;         // whether we are in "search mode", intercepting Enter/Shift-Enter
          this._matchCount = null;        // the current number of matches, null when not active
          this._matchIndex = null;        // the index into matches we are at in the current search, null when not active
      };
      
      /**
       * Select and return the selection.from and selection.to in the direction that matches text.
       * 
       * In Swift, the text is passed with smartquote nonsense removed and '&quot;'
       * instead of quotes and '&apos;' instead of apostrophes, so that we can search on text
       * that includes them and pass them from Swift to JavaScript consistently.
       */
      searchFor(text, direction='forward', searchOnEnter=false) {
          let command = searchForCommand(text, direction, searchOnEnter);
          return command(view.state, view.dispatch, view);
      };

      /**
       * Return a command that will execute a search, typically assigned as a button action.
       * @param {string}                  text            The text to search for.
       * @param {'forward' | 'backward'}  direction       The direction to search in.
       * @param {boolean}                 searchOnEnter   Whether to begin intercepting Enter in the view until cancelled.
       * @returns {Command}                               A command that will execute a search for text given the state, dispatch, and view.
       */
      searchForCommand(text, direction='forward', searchOnEnter=false) {
          const commandAdapter = (state, dispatch, view) => {
              let result = {};
              if (!text || (text.length === 0)) {
                  this.cancel();
                  return result;
              }
              // On the Swift side, we replace smart quotes and apostrophes with &quot; and &apos;
              // before getting here, but when doing searches in markupeditor-base, they will come 
              // in here unchanged. So replace them with the proper " or ' now.
              text = text.replaceAll('’', "'");
              text = text.replaceAll('‘', "'");
              text = text.replaceAll('“', '"');
              text = text.replaceAll('”', '"');
              text = text.replaceAll('&quot;', '"');       // Fix the hack for quotes in the call
              text = text.replaceAll('&apos;', "'");       // Fix the hack for apostrophes in the call

              // Rebuild the query if forced or if the search string changed
              if (this._forceIndexing || (text !== this._searchString)) {
                  this._searchString = text;
                  this._isActive = searchOnEnter;
                  this._buildQuery();
                  const transaction = setSearchState(view.state.tr, this._searchQuery);
                  view.dispatch(transaction);             // Show all the matches
                  this._setMatchCount(view.state);
                  this._forceIndexing = false;
              }
              // Search for text and return the result containing from and to that was found
              //
              // TODO: Fix bug that occurs when searching for next or prev when the current selection 
              //          is unique within the doc. The `nextMatch` in prosemirror-search when failing,  
              //          should set the to value to `Math.min(curTo, range.to))` or it misses the 
              //          existing selection. Similarly on `prevMatch`. This needs to be done in a 
              //          patch of prosemirror-search. For example:
              //
              //  function nextMatch(search, state, wrap, curFrom, curTo) {
              //      let range = search.range || { from: 0, to: state.doc.content.size };
              //      let next = search.query.findNext(state, Math.max(curTo, range.from), range.to);
              //      if (!next && wrap)
              //          next = search.query.findNext(state, range.from, Math.min(curTo, range.to));
              //      return next;
              //  }

              result = this._searchInDirection(direction, view.state, view.dispatch);
              if (!result.from) {
                  this.deactivate(view);
              } else {
                  let increment = (direction == 'forward') ? 1 : -1;
                  let index = this._matchIndex + increment;
                  let total = this._matchCount;
                  let zeroIndex = index % total;
                  this._matchIndex = (zeroIndex <= 0) ? total : zeroIndex;
                  this._direction = direction;
                  if (searchOnEnter) { this._activate(view); }            }
              return result;
          };

          return commandAdapter;
      };

      _setMatchCount(state) {
          this._matchCount = getMatchHighlights(state).find().length;
          this._matchIndex = 0;
      }

      get matchCount() {
          return this._matchCount;
      }

      get matchIndex() {
          return this._matchIndex;
      }
      
      /**
       * Reset the query by forcing it to be recomputed at find time.
       */
      _resetQuery() {
          this._forceIndexing = true;
      };
      
      /**
       * Return whether search is active, and Enter should be interpreted as a search request
       */
      get isActive() {
          return this._isActive;
      };

      get caseSensitive() {
          return this._caseSensitive;
      }

      set caseSensitive(value) {
          this._caseSensitive = value;
      }
      
      /**
       * Activate search mode where Enter is being intercepted
       */
      _activate(view) {
          this._isActive = true;
          view.dom.classList.add("searching");
          _callback('activateSearch');
      }
      
      /**
       * Deactivate search mode where Enter is being intercepted
       */
      deactivate(view) {
          if (this.isActive) _callback('deactivateSearch');
          view.dom.classList.remove("searching");
          this._isActive = false;
          this._searchQuery = new SearchQuery({search: "", caseSensitive: this._caseSensitive});
          const transaction = setSearchState(view.state.tr, this._searchQuery);
          view.dispatch(transaction);
          this._matchCount = null;
          this._matchIndex = null;
      }
      
      /**
       * Stop searchForward()/searchBackward() from being executed on Enter. Force reindexing for next search.
       */
      cancel() {
          this.deactivate(view);
          this._resetQuery();
      };
      
      /**
       * Search forward (might be from Enter when isActive).
       */
      searchForward() {
          return this._searchInDirection('forward', view.state, view.dispatch);
      };
      
      /*
       * Search backward (might be from Shift+Enter when isActive).
       */
      searchBackward() {
          return this._searchInDirection('backward', view.state, view.dispatch);
      }
      
      /*
       * Search in the specified direction.
       */
      _searchInDirection(direction, state, dispatch) {
          if (this._searchString && (this._searchString.length > 0)) {
              if (direction == "forward") { findNext(state, dispatch);} else { findPrev(state, dispatch);}            _callback('searched');
              // Return the selection from and to from the view, because that is what changed
              return {from: view.state.tr.selection.from, to: view.state.tr.selection.to};
          }        return {}
      };

      /**
       * Create a new SearchQuery and highlight all the matches in the document.
       */
      _buildQuery() {
          this._searchQuery = new SearchQuery({search: this._searchString, caseSensitive: this._caseSensitive});
      }

  }
  /**
   * The searcher is the singleton that handles finding ranges that
   * contain a search string within editor.
   */
  const searcher = new Searcher();
  function searchIsActive() { return searcher.isActive }

  /** changed tracks whether the document has changed since `setHTML` */
  let changed = false;

  function isChanged() {
      return changed
  }

  /**
   * Handle pressing Enter.
   * 
   * Where Enter is bound in keymap.js, we chain `handleEnter` with `splitListItem`.
   * 
   * The logic for handling Enter is entirely MarkupEditor-specific, so is exported from here but imported in keymap.js.
   * We only need to report stateChanged when not in search mode.
   * 
   * @returns bool    Value is false if subsequent commands (like splitListItem) should execute;
   *                  else true if execution should stop here (like when search is active)
   */
  function handleEnter() {
      if (searcher.isActive) {
          searcher.searchForward();
          return true;
      }
      stateChanged();
      return false;
  }

  /**
   * Handle pressing Shift-Enter.
   * 
   * The logic for handling Shift-Enter is entirely MarkupEditor-specific, so is exported from here but imported in keymap.js.
   * We only need to report stateChanged when not in search mode.
   * 
   * @returns bool    Value is false if subsequent commands should execute;
   *                  else true if execution should stop here (like when search is active)
   */
  function handleShiftEnter() {
      if (searcher.isActive) {
          searcher.searchBackward();
          return true;
      }
      stateChanged();
      return false;
  }

  /**
   * Handle pressing Delete.
   * 
   * Notify about deleted images if one was selected, but always notify state changed and return false.
   * 
   *  * @returns bool    Value is false if subsequent commands should execute;
   *                      else true if execution should stop here.
   */
  function handleDelete() {
      const imageAttributes = _getImageAttributes();
      if (imageAttributes.src) postMessage({ 'messageType': 'deletedImage', 'src': imageAttributes.src, 'divId': (selectedID ?? '') });
      stateChanged();
      return false;
  }

  /**
   * Called to set attributes to the editor div, typically to ,
   * set spellcheck and autocorrect. Note that contenteditable 
   * should not be set for the editor element, even if it is 
   * included in the jsonString attributes. The same attributes
   * are used for contenteditable divs, and the attribute is 
   * relevant in that case.
   */
  function setTopLevelAttributes(jsonString) {
      const attributes = JSON.parse(jsonString);
      const editor = document.getElementById('editor');
      if (editor && attributes) {   
          for (const [key, value] of Object.entries(attributes)) {
              if (key !== 'contenteditable') editor.setAttribute(key, value);
          }    }}
  /**
   * Set the receiver for postMessage().
   * 
   * By default, the receiver will be window.webkit.messageHandlers.markup. 
   * However, to allow embedding of MarkupEditor in other environments, such 
   * as VSCode, allow it to be set externally.
   */
  let messageHandler = (typeof window == 'undefined') ? null : window.webkit?.messageHandlers?.markup;
  function setMessageHandler(handler) {
      messageHandler = handler;
  }
  /**
   * Called to load user script and CSS before loading html.
   *
   * The scriptFile and cssFile are loaded in sequence, with the single 'loadedUserFiles'
   * callback only happening after their load events trigger. If neither scriptFile
   * nor cssFile are specified, then the 'loadedUserFiles' callback happens anyway,
   * since this ends up driving the loading process further.
   */
  function loadUserFiles(scriptFile, cssFile) {
      if (scriptFile) {
          if (cssFile) {
              _loadUserScriptFile(scriptFile, function() { _loadUserCSSFile(cssFile); });
          } else {
              _loadUserScriptFile(scriptFile, function() { _loadedUserFiles(); });
          }
      } else if (cssFile) {
          _loadUserCSSFile(cssFile);
      } else {
          _loadedUserFiles();
      }
  }
  /**
   * Callback to the message handler.
   * In Swift, the message is handled by the WKScriptMessageHandler, 
   * but in other cases, it might have been reassigned.
   * In Swift, the WKScriptMessageHandler is the MarkupCoordinator,
   * and the userContentController(_ userContentController:didReceive:)
   * function receives message as a WKScriptMessage.
   *
   * @param {String} message     The message, which might be a JSONified string
   */
  function _callback(message) {
      messageHandler?.postMessage(message);
  }
  /**
   * Callback to signal that input came-in, passing along the DIV ID
   * that the input occurred-in if known. If DIV ID is not known, the raw 'input'
   * callback means the change happened in the 'editor' div.
   */
  function callbackInput() {
      changed = true;
      _callback('input' + (selectedID ?? ''));
  }
  /**
   * Callback to signal that user-provided CSS and/or script files have
   * been loaded.
   */
  function _loadedUserFiles() {
      _callback('loadedUserFiles');
  }
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
  }
  /**
   * Called to load user CSS before loading html if userCSSFile has been defined for this MarkupWKWebView
   */
  function _loadUserCSSFile(file) {
      let head = document.getElementsByTagName('head')[0];
      let link = document.createElement('link');
      link.rel = 'stylesheet';
      link.type = 'text/css';
      link.addEventListener('load', function() { _loadedUserFiles(); });
      link.href = file;
      head.appendChild(link);
  }
  if (typeof window != 'undefined') {
      /**
       * The 'ready' callback indicated that the editor and this js is properly loaded.
       *
       * Note for history, replaced window.onload with this eventListener.
       */
      window.addEventListener('load', function () {
          _callback('ready');
      });

      /**
       * Capture all unexpected runtime errors in this script, report for debugging.
       *
       * There is not any useful debug information for users, but as a developer,
       * you can place a break in this method to examine the call stack.
       * Please file issues for any errors captured by this function,
       * with the call stack and reproduction instructions if at all possible.
       */
      window.addEventListener('error', function () {
          const muError = new MUError('Internal', 'Break at MUError(\'Internal\'... in Safari Web Inspector to debug.');
          muError.callback();
      });

      /**
       * If the window is resized, call back so that the holder can adjust its height tracking if needed.
       */
      window.addEventListener('resize', function () {
          _callback('updateHeight');
      });
  }

  /********************************************************************************
   * Search
   */
  //MARK: Search

  /**
   * Search for `text` in `direction`.
   * 
   * When text is empty, search is canceled.
   *
   * CAUTION: When `activate` is "true", search must be cancelled once started, or Enter 
   * will be intercepted to mean searcher.searchForward()/searchBackward()
   * 
   * @param {string}              text        The string to search for in a case-insensitive manner.
   * @param {string}              direction   Search direction, either `forward ` or `backward`.
   * @param {"true" | "false"}    activate    Set to "true" to activate "search mode", where Enter/Shift-Enter = Search forward/backward.
   * @returns {Object}                        The {to: number, from: number} location of the match.
   */
  function searchFor(text, direction, activate) {
      const searchOnEnter = activate === 'true';
      let command = searchForCommand(text, direction, searchOnEnter);
      return command(view.state, view.dispatch, view);
  }
  /**
   * Return the command that will execute search for `text` in `direction when provided with the 
   * view.state, view.dispatch, and view.
   *
   * @param {string}              text        The string to search for in a case-insensitive manner
   * @param {string}              direction   Search direction, either `forward ` or `backward`.
   * @param {"true" | "false"}    activate    Set to "true" to activate "search mode", where Enter/Shift-Enter = Search forward/backward.
   * @returns {Command}                       The command that can be executed to return the location of the match.
   */
  function searchForCommand(text, direction, activate) {
      return searcher.searchForCommand(text, direction, activate);
  }

  /**
   * Set whether searches will be case sensitive or not.
   * 
   * @param {boolean} caseSensitive 
   */
  function matchCase(caseSensitive) {
      searcher.caseSensitive = caseSensitive;
  }

  /**
   * Deactivate search mode, stop intercepting Enter to search.
   */
  function deactivateSearch() {
      searcher.deactivate(view);
  }
  /**
   * Cancel searching, resetting search state.
   */
  function cancelSearch() {
      searcher.cancel();
  }

  /**
   * Return the number of matches in the current search or null if search has not yet been initiated.
   * 
   * @returns {number | null }
   */
  function matchCount() {
      return searcher.matchCount;
  }

  /**
   * Return the index of the match in the current search, starting at the first match which began 
   * at the selection point, or null if search has not yet been initiated.
   * 
   * @returns {number | null }
   */
  function matchIndex() {
      return searcher.matchIndex;
  }

  /********************************************************************************
   * Paste
   */
  //MARK: Paste

  /**
   * Paste html at the selection, replacing the selection as-needed.
   * 
   * `event` is a mocked ClipboardEvent for testing purposes, else nil.
   */
  function pasteHTML(html, event) {
      view.pasteHTML(html, event);
      stateChanged();
  }
  /**
   * Do a custom paste operation of "text only", which we will extract from the html
   * ourselves. First we get a node that conforms to the schema, which by definition 
   * only includes elements in a form we recognize, no spans, styles, etc.
   * The trick here is that we want to use the same code to paste text as we do for
   * HTML, but we want to paste something that is the MarkupEditor-equivalent of
   * unformatted text.
   * 
   * `event` is a mocked ClipboardEvent for testing purposes, else nil.
   */
  function pasteText(html, event) {
      const node = _nodeFromHTML(html);
      const htmlFragment = _fragmentFromNode(node);
      const minimalHTML = _minimalHTML(htmlFragment); // Reduce to MarkupEditor-equivalent of "plain" text
      pasteHTML(minimalHTML, event);
  }
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
  }
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
          }    });
  }
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
          }    });
  }
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
          }        elements = div.getElementsByTagName('A');
          element = (elements.length > 0) ? elements[0] : null;
      }}
  /********************************************************************************
   * Getting and setting document contents
   */
  //MARK: Getting and Setting Document Contents

  /**
   * Clean out the document and replace it with an empty paragraph
   */
  function emptyDocument() {
      selectedID = null;
      setHTML(emptyHTML());
  }
  function emptyHTML() {
      return '<p></p>'
  }

  /**
   * Set the `selectedID` to `id`, a byproduct of clicking or otherwise iteractively
   * changing the selection, triggered by `createSelectionBetween`.
   * @param {string} id 
   */
  function resetSelectedID(id) { 
      selectedID = id;
  }
  /**
   * Return an array of `src` attributes for images that are encoded as data, empty if there are none.
   * 
   * @returns {[string]}
   */
  function getDataImages() {
      let images = document.getElementsByTagName('img');
      let dataImages = [];
      for (let i = 0; i < images.length; i++) {
          let src = images[i].getAttribute('src');
          if (src && src.startsWith('data')) dataImages.push(src);
      }
      return dataImages
  }

  /**
   * We saved an image at a new location or translated it from data to a file reference, 
   * so we need to update the document to reflect it.
   * 
   * @param {string} oldSrc Some or all of the original src for the image
   * @param {string} newSrc The src that should replace the old src
   */
  function savedDataImage(oldSrc, newSrc) {
      let images = document.getElementsByTagName('img');
      for (let i = 0; i < images.length; i++) {
          let img = images[i];
          let src = img.getAttribute('src');
          if (src && src.startsWith(oldSrc)) {
              let imgPos = view.posAtDOM(img, 0);
              const transaction = view.state.tr.setNodeAttribute(imgPos, 'src', newSrc);
              view.dispatch(transaction);
          }
      }
  }

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
  function getHTML(pretty='true', clean='true', divID) {
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
      }	if (prettyHTML) {
          text = _allPrettyHTML(editor);
      } else {
          const div = document.createElement('div');
          div.appendChild(editor);
          text = div.innerHTML;
      }    return text;
  }
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
          if (i < childNodesLength - 1) { text += '\n'; }    }
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
          if (!nodeIsInlined) { text += '\n' + indent; }        text += '<' + nodeName;
          const attributes = node.attributes;
          for (let i = 0; i < attributes.length; i++) {
              const attribute = attributes[i];
              text += ' ' + attribute.name + '="' + attribute.value + '"';
          }        text += '>';
          node.childNodes.forEach(childNode => {
              text = _prettyHTML(childNode, indent + '    ', text, _isInlined(childNode));
          });
          if (nodeHasTerminator) {
              if (!terminatorIsInlined) { text += '\n' + indent; }            text += '</' + nodeName + '>';
          }        if (!nodeIsInlined && !terminatorIsInlined) {
              indent = indent.slice(0, -4);
          }    }    return text;
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
   * Set the base element for the body to `string`. 
   * 
   * Used so relative hrefs and srcs work. 
   * If `string` is undefined, then the base element is removed if it exists.
   */
  function setBase(string) {
      let base = document.getElementsByTagName('base')[0];
      if (string) {
          if (!base) {
              base = document.createElement('base');
              document.body.insertBefore(base, document.body.firstChild);
          }
          base.setAttribute('href', string);
      } else {
          if (base) {
              base.parentElement.removeChild(base);
          }
      }
  }

  /**
   * Set the contents of the editor.
   * 
   * The exported placeholderText is set after setting the contents.
   *
   * @param {string}  contents            The HTML for the editor
   * @param {boolean} selectAfterLoad     Whether we should focus after load
   */
  function setHTML(contents, focusAfterLoad=true, base) {
      // If defined, set base; else remove base if it exists. This way, when setHTML is used to,
      // say, create a new empty document, base will be reset.
      setBase(base);
      const state = view.state;
      const doc = state.doc;
      const tr = state.tr;
      const node = _nodeFromHTML(contents);
      const selection = new AllSelection(doc);
      // To avoid flashing it, only set the placeholder early if contents is empty
      if (_placeholderText && (contents == emptyHTML())) placeholderText = _placeholderText;
      let transaction = tr
          .setSelection(selection)
          .replaceSelectionWith(node, false)
          .setMeta("addToHistory", false);    // History begins here!
      const $pos = transaction.doc.resolve(0);
      transaction
          .setSelection(TextSelection.near($pos))
          .scrollIntoView();
      view.dispatch(transaction);
      // But always set placeholder in the end so it will appear when the doc is empty
      placeholderText = _placeholderText;
      if (focusAfterLoad) view.focus();
      // Reset change tracking
      changed = false;
  }
  /**
   * Internal value of placeholder text
   */
  let _placeholderText;           // Hold onto the placeholder text so we can defer setting it until setHTML.

  /**
   * Externally visible value of placeholder text
   */
  let placeholderText;     // What we tell ProseMirror to display as a decoration, set after setHTML.

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
  function setPlaceholder(text) {
      _placeholderText = text;
  }
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
  function getHeight() {
     const editor = document.getElementById('editor');
     const paddingBlockStart = editor.style.getPropertyValue('padding-block-start');
     const paddingBlockEnd = editor.style.getPropertyValue('padding-block-end');
     editor.style['padding-block-start'] = '0px';
     editor.style['padding-block-end'] = '0px';
     // TODO: Check this works on iOS or is even still needed
     const height = view.dom.getBoundingClientRect().height;
     editor.style['padding-block-start'] = paddingBlockStart;
     editor.style['padding-block-end'] = paddingBlockEnd;
     return height;
  }
  /*
   * Pad the bottom of the text in editor to fill fullHeight.
   *
   * Setting padBottom pads the editor all the way to the bottom, so that the
   * focus area occupies the entire view. This allows long-press on iOS to bring up the
   * context menu anywhere on the screen, even when text only occupies a small portion
   * of the screen.
   */
  function padBottom(fullHeight) {
      const editor = document.getElementById('editor');
      const padHeight = fullHeight - getHeight();
      if (padHeight > 0) {
          editor.style.setProperty('--padBottom', padHeight+'px');
      } else {
          editor.style.setProperty('--padBottom', '0');
      }}
  /**
   * Focus immediately, leaving range alone
   */
  function focus() {
      view.focus();
  }
  /**
   * Reset the selection to the beginning of the document
   */
  function resetSelection() {
      const {node, pos} = _firstEditableTextNode();
      const doc = view.state.doc;
      const selection = (node) ? new TextSelection(doc.resolve(pos)) : new AllSelection(doc);
      const transaction = view.state.tr.setSelection(selection);
      view.dispatch(transaction);
  }
  /**
   * Return the node and position of the first editable text; i.e., 
   * a text node inside of a contentEditable div.
   */
  function _firstEditableTextNode() {
      const divNodeType = view.state.schema.nodes.div;
      const fromPos = TextSelection.atStart(view.state.doc).from;
      const toPos = TextSelection.atEnd(view.state.doc).to;
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
          }    });
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
  function addDiv(id, parentId, cssClass, attributesJSON, buttonGroupJSON, htmlContents) {
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
          div.innerHTML = (htmlContents?.length > 0) ? htmlContents : emptyHTML();
          if (buttonGroupDiv) div.appendChild(buttonGroupDiv);
      }
      const divSlice = _sliceFromHTML(div.innerHTML);
      const startedEmpty = (div.childNodes.length == 1) && (div.firstChild.nodeName == 'P') && (div.firstChild.textContent == "");
      const divNode = divNodeType.create({id, parentId, cssClass, editable, startedEmpty}, divSlice.content);
      divNode.editable = editable;
      const transaction = view.state.tr;
      if (parentId && (parentId !== 'editor')) {
          // This path is only executed when adding a dynamic button group
          // Find the div that is the parent of the one we are adding
          const {node, pos} = _getNode(parentId, transaction.doc);
          if (node) {
              // Insert the div inside of its parent as a new child of the existing div
              const divPos = pos + node.nodeSize - 1;
              transaction.insert(divPos, divNode);
              // Now we have to update the htmlContent markup of the parent
              const $divPos = transaction.doc.resolve(divPos);
              const parent = $divPos.node();
              const htmlContents = _htmlFromFragment(_fragmentFromNode(parent));
              transaction.setNodeAttribute(pos, "htmlContents", htmlContents);
              view.dispatch(transaction);
          }
      } else {
          // This is the "normal" path when building a doc from the MarkupDivStructure.
          // If we are starting with an empty doc (i.e., <p><p>), then replace the single 
          // empty paragraph with this div. Otherwise, just append this div to the end 
          // of the doc.
          const emptyDoc = (view.state.doc.childCount == 1) && (view.state.doc.textContent == "");
          if (emptyDoc) {
              const nodeSelection = NodeSelection.atEnd(transaction.doc);
              nodeSelection.replaceWith(transaction, divNode);
          } else {
              const divPos = transaction.doc.content.size;
              transaction.insert(divPos, divNode);
          }
          view.dispatch(transaction);
      }}
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
                  button.setAttribute('label', buttonAttributes.label);
                  button.setAttribute('type', 'button');
                  button.setAttribute('id', buttonAttributes.id);
                  button.setAttribute('class', buttonAttributes.cssClass);
                  buttonGroupDiv.appendChild(button);
              });
              return buttonGroupDiv; 
          }
      }
      return null;
  }
  /**
   * Remove the div with the given id, and restore the selection to what it was before it is removed.
   * @param {string} id   The id of the div to remove
   */
  function removeDiv(id) {
      const divNodeType = view.state.schema.nodes.div;
      const {node, pos} = _getNode(id);
      if (divNodeType === node?.type) {
          const $pos = view.state.doc.resolve(pos);
          const selection = view.state.selection;
          const nodeSelection = new NodeSelection($pos);
          // Once we deleteSelection (i.e., remove te div node), then our selection has to be adjusted if it was 
          // after the div we are removing.
          const newFrom = (selection.from > nodeSelection.to) ? selection.from - node.nodeSize : selection.from;
          const newTo = (selection.to > nodeSelection.to) ? selection.to - node.nodeSize : selection.to;
          const transaction = view.state.tr
              .setSelection(nodeSelection)
              .deleteSelection();
          const newSelection = TextSelection.create(transaction.doc, newFrom, newTo);
          transaction.setSelection(newSelection);
          const isButtonGroup = (node.attrs.editable == false) && (node.attrs.parentId !== 'editor') && ($pos.parent.type == divNodeType);
          if (isButtonGroup) {
              // Now we have to update the htmlContents attribute of the parent
              const parent = _getNode(node.attrs.parentId, transaction.doc);
              const htmlContents = _htmlFromFragment(_fragmentFromNode(parent.node));
              transaction.setNodeAttribute(parent.pos, "htmlContents", htmlContents);
          }
          view.dispatch(transaction);
      }}
  /**
   * 
   * @param {string} id           The element ID of the button that will be added.
   * @param {string} parentId     The element ID of the parent DIV to place the button in.
   * @param {string} cssClass     The CSS class of the button.
   * @param {string} label        The label for the button.
   */
  function addButton(id, parentId, cssClass, label) {
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
          const {node, pos} = _getNode(parentId, transaction.doc);
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
  }
  /**
   * 
   * @param {string} id   The ID of the button to be removed.
   */
  function removeButton(id) {
      const {node, pos} = _getNode(id);
      if (view.state.schema.nodes.button === node?.type) {
          const nodeSelection = new NodeSelection(view.state.doc.resolve(pos));
          const transaction = view.state.tr
              .setSelection(nodeSelection)
              .deleteSelection();
          view.dispatch(transaction);
      }}
  /**
   * 
   * @param {string} id   The ID of the DIV to focus on.
   */
  function focusOn(id) {
      const {node, pos} = _getNode(id);
      if (node && (node.attrs.id !== selectedID)) {
          const selection = new TextSelection(view.state.doc.resolve(pos));
          const transaction = view.state.tr.setSelection(selection).scrollIntoView();
          view.dispatch(transaction);
      }}
  /**
   * Remove all divs in the document.
   */
  function removeAllDivs() {
      const allSelection = new AllSelection(view.state.doc);
      const transaction = view.state.tr.delete(allSelection.from, allSelection.to);
      view.dispatch(transaction);
  }
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
      const fromPos = TextSelection.atStart(source).from;
      const toPos = TextSelection.atEnd(source).to;
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

  /**
   * Toggle the selection to/from bold (<STRONG>)
   */
  function toggleBold() {
      _toggleFormat('B');
  }
  /**
   * Toggle the selection to/from italic (<EM>)
   */
  function toggleItalic() {
      _toggleFormat('I');
  }
  /**
   * Toggle the selection to/from underline (<U>)
   */
  function toggleUnderline() {
      _toggleFormat('U');
  }
  /**
   * Toggle the selection to/from strikethrough (<S>)
   */
  function toggleStrike() {
      _toggleFormat('DEL');
  }
  /**
   * Toggle the selection to/from code (<CODE>)
   */
  function toggleCode() {
      _toggleFormat('CODE');
  }
  /**
   * Toggle the selection to/from subscript (<SUB>)
   */
  function toggleSubscript() {
      _toggleFormat('SUB');
  }
  /**
   * Toggle the selection to/from superscript (<SUP>)
   */
  function toggleSuperscript() {
      _toggleFormat('SUP');
  }
  /**
   * Turn the format tag off and on for selection.
   * 
   * Although the HTML will contain <STRONG>, <EM>, and <S>, the types
   * passed here are <B>, <I>, and <DEL> for compatibility reasons.
   *
   * @param {string} type     The *uppercase* type to be toggled at the selection.
   */
  function _toggleFormat(type) {
      let command = toggleFormatCommand(type);
      return command(view.state, view.dispatch, view)
  }
  function toggleFormatCommand(type) {
      let commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
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
              case 'SUB':
                  toggle = toggleMark(state.schema.marks.sub);
                  break;
              case 'SUP':
                  toggle = toggleMark(state.schema.marks.sup);
                  break;
          }        if (toggle && view) {
              toggle(state, view.dispatch);
              stateChanged();
          } else {
              return toggle
          }
      };
      return commandAdapter
  }

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
  function setStyle(style) {
      let command = setStyleCommand(style);
      let result = command(view.state, view.dispatch, view);
      return result
  }
  /**
   * Return a Command that sets the paragraph style at the selection to `style` 
   * @param {String}  style    One of the styles P or H1-H6 to set the selection to.
   */
  function setStyleCommand(style) {
      let commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          const protonode = _nodeFor(style, state.schema);
          const doc = state.doc;
          const selection = state.selection;
          const tr = state.tr;
          let transaction, error;
          doc.nodesBetween(selection.from, selection.to, (node, pos) => {
              if (node.type === state.schema.nodes.div) { 
                  return true;
              } else if (node.isBlock) {
                  if (node.type.inlineContent) {
                      try {
                          transaction = tr.setNodeMarkup(pos, protonode.type, protonode.attrs);
                      } catch(e) {
                          // We might hit multiple errors across the selection, but we will only return one MUError.Style
                          error = MUError.Style;
                          if ((e instanceof RangeError) && (protonode.type == state.schema.nodes.code_block)) {
                              // This is so non-obvious when people encounter it, it needs some explanation
                              error.info = ('Code style can only be applied to unformatted text.');
                          }
                      }
                  } else {    // Keep searching if in blockquote or other than p, h1-h6
                      return true;
                  }
              }            return false;   // We only need top-level nodes within doc
          });
          if (error) {
              //error.alert = true;
              //error.callback();
              return false;
          } else if (view) {
              const newState = view.state.apply(transaction);
              view.updateState(newState);
              stateChanged();
          } else {    // When checking if active based on state, return true only if different
              return paragraphStyle(state) != style;
          }
      };
      return commandAdapter
  }

  /**
   * Find/verify the oldStyle for the selection and replace it with newStyle.
   * @deprecated Use setStyle
   * @param {String}  oldStyle    One of the styles P or H1-H6 that exists at selection.
   * @param {String}  newStyle    One of the styles P or H1-H6 to replace oldStyle with.
   */
  function replaceStyle(oldStyle, newStyle) {
      setStyle(newStyle);
  }
  /**
   * Return a ProseMirror Node that corresponds to the MarkupEditor paragraph style.
   * @param {string} paragraphStyle   One of the paragraph styles supported by the MarkupEditor.
   * @returns {Node | null}           A ProseMirror Node of the specified type or null if unknown.
   */
  function _nodeFor(paragraphStyle, schema) {
      const nodeTypes = schema.nodes;
      let node;
      switch (paragraphStyle) {
          case 'P':
              node = nodeTypes.paragraph.create();
              break;
          case 'H1':
              node = nodeTypes.heading.create({level: 1});
              break;
          case 'H2':
              node = nodeTypes.heading.create({level: 2});
              break;
          case 'H3':
              node = nodeTypes.heading.create({level: 3});
              break;
          case 'H4':
              node = nodeTypes.heading.create({level: 4});
              break;
          case 'H5':
              node = nodeTypes.heading.create({level: 5});
              break;
          case 'H6':
              node = nodeTypes.heading.create({level: 6});
              break;
          case 'PRE':
              node = nodeTypes.code_block.create();
              break;
      }    return node;
  }
  /********************************************************************************
   * Lists
   */
  //MARK: Lists

  /**
   * Turn the list tag on and off for the selection, doing the right thing
   * for different cases of selection.
   * 
   * If the selection is in a list of type `listType`, then outdent the 
   * items in the selection.
   * 
   * If the selection is in a list type that is different than `listType`,
   * then wrap it in a new list.
   * 
   * We use a single command returned by `multiWrapInList` because the command 
   * can be assigned to a single button in JavaScript.
   * 
   * @param {String}  listType     The kind of list we want the list item to be in if we are turning it on or changing it.
   */
  function toggleListItem$1(listType) {
      const targetListType = nodeTypeFor(listType, view.state.schema);
      if (targetListType !== null) {
          const command = wrapInListCommand(view.state.schema, targetListType);
          command(view.state, (transaction) => {
              const newState = view.state.apply(transaction);
              view.updateState(newState);
          });
      }}
  /**
   * Return the type of list the selection is in, else null.
   * 
   * If a list type is returned, then it will be able to be outdented. Visually, 
   * the MarkupToolbar will show filled-in (aka selected), and pressing that button 
   * will outdent the list, an operation that can be repeated until the selection 
   * no longer contains a list. Similarly, if the list returned here is null, then  
   * the selection can be set to a list.
   * 
   * @return { 'UL' | 'OL' | null }
   */
  function getListType(state) {
      const selection = state.selection;
      const ul = state.schema.nodes.bullet_list;
      const ol = state.schema.nodes.ordered_list;
      let hasUl = false;
      let hasOl = false;
      state.doc.nodesBetween(selection.from, selection.to, node => {
          if (node.isBlock) {
              hasUl = hasUl || (node.type === ul);
              hasOl = hasOl || (node.type === ol);
              return true;  // Lists can nest, so we need to recurse
          }
          return false; 
      });
      // If selection contains no lists or multiple list types, return null; else return the one list type
      const hasType = hasUl ? (hasOl ? null : ul) : (hasOl ? ol : null);
      return listTypeFor(hasType, state.schema);
  }

  function _getListType() {
      return getListType(view.state);
  }
  /**
   * Return the NodeType corresponding to `listType`, else null.
   * @param {"UL" | "OL" | String} listType The String corresponding to the NodeType
   * @returns {NodeType | null}
   */
  function nodeTypeFor(listType, schema) {
      if (listType === 'UL') {
          return schema.nodes.bullet_list;
      } else if (listType === 'OL') {
          return schema.nodes.ordered_list;
      } else {
          return null;
      }}

  /**
   * Return the String corresponding to `nodeType`, else null.
   * @param {NodeType} nodeType The NodeType corresponding to the String
   * @returns {'UL' | 'OL' | null}
   */
  function listTypeFor(nodeType, schema) {
      if (nodeType === schema.nodes.bullet_list) {
          return 'UL';
      } else if (nodeType === schema.nodes.ordered_list) {
          return 'OL';
      } else {
          return null;
      }}
  /**
   * Return a command that performs `wrapInList` or `liftListItem` depending on whether the selection 
   * is in the `targetNodeType` or not. In the former case, it does the `listLiftItem`, basically 
   * unwrapping the list. If `wrapInList` or `liftListItem` fails, it does the command across the 
   * selection. This is done by finding the common list node for the selection and then recursively 
   * replacing existing list nodes among its descendants that are not of the `targetNodeType`. So, the 
   * every descendant is made into `targetNodeType`, but not the common list node or its siblings. Note 
   * that when the selection includes a mixture of list nodes and non-list nodes (e.g., begins in a 
   * top-level <p> and ends in a list), the wrapping might be done by `wrapInList`, which doesn't follow 
   * quite the same rules in that it leaves existing sub-lists untouched. The wrapping can also just 
   * fail entirely (e.g., selection starting in a sublist and going outside of the list).
   * 
   * It seems a little silly to be passing `listTypes` and `listItemTypes` to the functions called from here, but it 
   * does avoid those methods from knowing about state or schema.
   * 
   * Adapted from code in https://discuss.prosemirror.net/t/changing-the-node-type-of-a-list/4996.
   * 
   * @param {Schema}          schema              The schema holding the list and list item node types.
   * @param {NodeType}        targetNodeType      One of state.schema.nodes.bullet_list or ordered_list to change selection to.
   * @param {Attrs | null}    attrs               Attributes of the new list items.
   * @returns {Command}                           A command to wrap the selection in a list.
   */
  function wrapInListCommand(schema, targetNodeType, attrs) {
      const listTypes = [schema.nodes.bullet_list, schema.nodes.ordered_list];
      const targetListItemType = schema.nodes.list_item;
      const listItemTypes = [targetListItemType];

      const commandAdapter = (state, dispatch) => {
          const inTargetNodeType = getListType(state) === listTypeFor(targetNodeType, state.schema);
          const command = inTargetNodeType ? liftListItem(state.schema.nodes.list_item) : wrapInList(targetNodeType, attrs);
          if (command(state)) {
              let result = command(state, dispatch);
              if (dispatch) stateChanged();
              return result;
          }

          const commonListNode = findCommonListNode(state, listTypes);
          if (!commonListNode) return false;

          if (dispatch) {
              const updatedNode = updateNode(
                  commonListNode.node,
                  targetNodeType,
                  targetListItemType,
                  listTypes,
                  listItemTypes
              );

              let tr = state.tr;

              tr = tr.replaceRangeWith(
                  commonListNode.from,
                  commonListNode.to,
                  updatedNode
              );

              tr = tr.setSelection(
                  new TextSelection(
                      tr.doc.resolve(state.selection.from),
                      tr.doc.resolve(state.selection.to)
                  )
              );

              dispatch(tr);
              stateChanged();
          }
          return true;
      };

      return commandAdapter;
  }
  /**
   * Return the common list node in the selection that is one of the `listTypes` if one exists.
   * @param {EditorState}     state       The EditorState containing the selection.
   * @param {Array<NodeType>} listTypes   The list types we're looking for.
   * @returns {node: Node, from: number, to: number}
   */
  function findCommonListNode(state, listTypes) {

      const range = state.selection.$from.blockRange(state.selection.$to);
      if (!range) return null;

      const node = range.$from.node(-2);
      if (!node || !listTypes.find((item) => item === node.type)) return null;

      const from = range.$from.posAtIndex(0, -2);
      return { node, from, to: from + node.nodeSize - 1 };
  }
  /**
   * Return a Fragment with its children replaced by ones that are of `targetListType` or `targetListItemType`.
   * @param {Fragment}        content             The ProseMirror Fragment taken from the selection.
   * @param {NodeType}        targetListType      The bullet_list or ordered_list NodeType we are changing children to.
   * @param {NodeType}        targetListItemType  The list_item NodeType we are changing children to.
   * @param {Array<NodeType>} listTypes           The list types we're looking for.
   * @param {Array<NodeType>} listItemTypes       The list item types we're looking for.
   * @returns {Fragment}  A ProseMirror Fragment with the changed nodes.
   */
  function updateContent(content, targetListType, targetListItemType, listTypes, listItemTypes) {
      let newContent = content;

      for (let i = 0; i < content.childCount; i++) {
          newContent = newContent.replaceChild(
              i,
              updateNode(
                  newContent.child(i),
                  targetListType,
                  targetListItemType,
                  listTypes,
                  listItemTypes
              )
          );
      }

      return newContent;
  }
  /**
   * Return the `target` node type if the type of `node` is one of the `options`.
   * @param {Node}            node 
   * @param {NodeType}        target 
   * @param {Array<NodeType>} options 
   * @returns {NodeType | null}
   */
  function getReplacementType(node, target, options) {
      return options.find((item) => item === node.type) ? target : null;
  }
  /**
   * Return a new Node with one of the target types.
   * @param {Node}            node                The node to change to targetListType or targetListItemType.
   * @param {NodeType}        targetListType      The list type we want to change `node` to.
   * @param {NodeType}        targetListItemType  The list item types we want to change `node` to.
   * @param {Array<NodeType>} listTypes           The list types we're looking for.
   * @param {Array<NodeType>} listItemTypes       The list item types we're looking for.
   * @returns Node
   */
  function updateNode(node, targetListType, targetListItemType, listTypes, listItemTypes) {
      const newContent = updateContent(
          node.content,
          targetListType,
          targetListItemType,
          listTypes,
          listItemTypes
      );

      const replacementType = 
          getReplacementType(node, targetListType, listTypes) ||
          getReplacementType(node, targetListItemType, listItemTypes);

      if (replacementType) {
          return replacementType.create(node.attrs, newContent, node.marks);
      } else {
          return node.copy(newContent);
      }}
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
  function indent() {
      let command = indentCommand();
      return command(view.state, view.dispatch, view)
  }
  function indentCommand() {
      let commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          let blockquote = state.schema.nodes.blockquote;
          let li = state.schema.nodes.list_item;
          let ul = state.schema.nodes.bullet_list;
          let ol = state.schema.nodes.ordered_list;
          const { $from, $to } = state.selection;
          let tr = state.tr;
          let willWrap = false;
          let nodePos = [];
          state.doc.nodesBetween($from.pos, $to.pos, (node, pos) => {
              if (node.isBlock) {
                  const $start = tr.doc.resolve(pos);
                  const $end = tr.doc.resolve(pos + node.nodeSize);
                  const range = $start.blockRange($end);
                  if ((range) && (node.type != li)) { // We will never wrap an li
                      // Later we will check if the range is valid for wrapping
                      nodePos.push({node: node, pos: pos});
                  }
                  return true
              } else {
                  return false
              }
          });

          let newState;
          let skipParents = [];
          if (nodePos.length > 0) {
              for (let { node, pos } of nodePos.sort((a, b) => b.pos - a.pos)) {
                  if (skipParents.filter((np) => {return (node === np.node)}).length > 0) continue
                  let $start = tr.doc.resolve(pos);
                  let $end = tr.doc.resolve(pos + node.nodeSize);
                  let range = $start.blockRange($end); // We know range will be defined
                  // We need to determine what we will wrap in
                  let nodeIsList = (node.type == ul) || (node.type == ol);
                  if (!nodeIsList && ($start.parent.type == li)) {
                      // We are going to try to wrap the list in a sublist, but if we 
                      // cannot, then we will try to wrap the list in a blockquote
                      let list = $start.node($start.depth - 1);
                      let willWrapInList = wrapRangeInList(null, range, list.type, list.attrs);
                      willWrap = willWrap || willWrapInList;
                      if (willWrapInList) {
                          // If we are wrapping this <li><p></p></li>, then skip all of its parents
                          skipParents.push(...parents($start, null, 1));
                      }
                      if (dispatch && willWrapInList) {
                          wrapRangeInList(tr, range, list.type, list.attrs);
                          newState = state.apply(tr);
                      }
                  } else {
                      // We are going to try tp wrap in a blockquote
                      let wrappers = findWrapping(range, blockquote, node.attrs);
                      if (wrappers) {
                          willWrap = true;
                          let parentsInSelection = [];
                          let allParents = parents($start, null, 1);
                          // If we are wrapping a list, then track parents to skip
                          if (nodeIsList) {
                              // Find the parents to skip as we try to indent ones above us
                              parentsInSelection = allParents.filter((np) => {
                                  let npNode = np.node;
                                  let npIsList = (npNode.type == ul) || (npNode.type == ol); 
                                  if (!npIsList) return false                 // We are only skipping lists
                                  if (npNode.type != node.type) return false  // We are only skipping parent lists of same type
                                  // And only lists outside of the original selection
                                  return (np.start < $from.pos) && (np.end > $to.pos)
                              });
                              skipParents.push(...parentsInSelection);
                          } else {
                              parentsInSelection = allParents.filter((np) => {
                                  let npNode = np.node;
                                  let npIsBlockquote = (npNode.type == blockquote);
                                  if (!npIsBlockquote) return false                 // We are only skipping blockquotes
                                  // And only blockquotes outside of the original selection
                                  return (np.start < $from.pos) && (np.end > $to.pos)
                              });
                          }
                          skipParents.push(...parentsInSelection);
                          if (dispatch) {
                              newState = state.apply(tr.wrap(range, wrappers));
                          }
                      }
                  }
              }
          }

          if (dispatch && willWrap && newState) view.updateState(newState);
          return willWrap

      };
      return commandAdapter
  }

  /**
   * Do a context-sensitive outdent.
   *
   * If in a list, outdent the item to a less nested level in the list if appropriate.
   * If in a blockquote, remove a blockquote to outdent further.
   * Else, do nothing.
   * 
   * Note that outdenting of a top-level list with a sublist doesn't work. TBH, I'm not sure why, 
   * but liftTarget returns null at the top-level in that case. As a result, the outdenting has 
   * to be done at least twice, the first of which splits the sublist from the top level. When this 
   * happens, we should probably just do the equivalent of toggleListType.
   *
   */
  function outdent() {
      let command = outdentCommand();
      return command(view.state, view.dispatch, view)
  }
  function outdentCommand() {
      let commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          const { $from, $to } = state.selection;
          let tr = state.tr;
          let willLift = false;
          let nodePos = [];
          state.doc.nodesBetween($from.pos, $to.pos, (node, pos) => {
              if (node.isBlock) {
                  const $start = tr.doc.resolve(pos);
                  const $end = tr.doc.resolve(pos + node.nodeSize);
                  const range = $start.blockRange($end);
                  if (range) {
                      const target = liftTarget(range);
                      if ((target !== null) && (target >= 0)) {
                          nodePos.push({node: node, pos: pos});
                      }
                  }
                  return true
              } else {
                  return false
              }
          });

          if (nodePos.length > 0) {
              let skipParents = [];
              for (let {node, pos} of nodePos.sort((a, b) => b.pos - a.pos)) {
                  // The problem we have here is that when we lift node within
                  // a blockquote and it has no siblings, the lift operation removes 
                  // the parent (see https://discuss.prosemirror.net/t/lifting-and-parent-nodes/1332).
                  // In particular, we don't want to resolve the pos of node after 
                  // its only child has been lifted, because it doesn't exist any more.
                  // In fact, we need to skip lifting of all the ancestors when this happens.
                  if (skipParents.filter((np) => {return (node === np.node)}).length > 0) continue
                  let $start = tr.doc.resolve(pos);
                  if ($start.parent.children.length == 1) {
                      // Then this node, when lifted will remove 
                      // the parent. Therefore, track the parent 
                      // and don't lift it if we encounter it later
                      // in the iteration over nodePos.
                      skipParents.push(...parents($start, null, 1));
                  }
                  let $end = tr.doc.resolve(pos + node.nodeSize);
                  let range = $start.blockRange($end);
                  if (range) { 
                      let target = liftTarget(range);
                      if ((target !== null) && (target >= 0)) {
                          willLift = true;
                          if (dispatch) tr.lift(range, target);
                      }
                  }
              }
          }

          if (dispatch && willLift) dispatch(tr);
          return willLift

      };
      return commandAdapter
  }

  function parents($pos, start, end) {
      //$pos.node($pos.depth) is the same as $pos.parent.
      let startDepth = $pos.depth;    // start at immediate parent by default
      let endDepth = end;                 // end at the top-level by default (i.e., include 'doc')
      let parents = [];
      for (let depth = startDepth; depth >= endDepth; depth--) {
          let node = $pos.node(depth);
          let start = $pos.start(depth);
          let end = $pos.end(depth);
          parents.push({node: node, start: start, end: end});
      }
      return parents
  }

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
  function startModalInput() {
  }

  /**
   * Called typically after cancelling a modal popover on the Swift side, since
   * normally the result of using the popover is to modify the DOM and reset the
   * selection.
   * 
   * @deprecated No longer needed.
   */
  function endModalInput() {
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
          }    }}
  /**
   * Do a depth-first traversal from node, removing spans starting at the leaf nodes.
   *
   * @return {Int}    The number of spans removed
   */
  function _cleanUpSpansWithin(node, spansRemoved) {
      return _cleanUpSpansDivsWithin(node, 'SPAN', spansRemoved);
  }
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
      }    if (node.nodeName === type) {
          removed++;
          if (node.childNodes.length > 0) {   // Use childNodes because we need text nodes
              const template = document.createElement('template');
              template.innerHTML = node.innerHTML;
              const newElement = template.content;
              node.replaceWith(newElement);
          } else {
              node.parentNode.removeChild(node);
          }    }    return removed;
  }
  /********************************************************************************
   * Selection
   */
  //MARK: Selection

  /**
   * Populate a dictionary of properties about the current selection
   * and return it in a JSON form. This is the primary means that the
   * find out what the selection is in the document, so we
   * can tell if the selection is in a bolded word or a list or a table, etc.
   *
   * @return {String}      The stringified dictionary of selectionState.
   */
  function getSelectionState() {
      const state = _getSelectionState();
      return JSON.stringify(state);
  }
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
      // Note: callbackInput() uses a cached value of the *editable* div ID
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
      const selrect = getSelectionRect();
      const selrectDict = {
          'x' : selrect.left,
          'y' : selrect.top,
          'width' : selrect.right - selrect.left,
          'height' : selrect.bottom - selrect.top
      };
      state['selrect'] = selrectDict;
      // Link
      const linkAttributes = getLinkAttributes();
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
      state['border'] = tableAttributes.border;
      //// Style
      state['style'] = _getParagraphStyle();
      state['list'] = _getListType();
      state['li'] = state['list'] !== null;   // We are always in a li by definition for ProseMirror, right?
      state['quote'] = isIndented();
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
      return state;
  };

  /**
   * Return the id and editable state of the selection.
   * 
   * We look at the outermost div from the selection anchor, so if the 
   * selection extends between divs (which should not happen), or we have 
   * a div embedding a div where the editable attribute is different (which 
   * should not happen), then the return might be unexpected (haha, which 
   * should not happen, of course!).
   * 
   * @returns {Object} The id and editable state that is selected.
   */
  function _getContentEditable() {
      const anchor = view.state.selection.$anchor;
      const divNode = outermostOfTypeAt(view.state.schema.nodes.div, anchor);
      if (divNode) {
          return {id: divNode.attrs.id, editable: divNode.attrs.editable ?? false};
      } else {
          return {id: 'editor', editable: true};
      }
  }

  /**
   * Return the text at the selection.
   * @returns {String | null} The text that is selected.
   */
  function _getSelectionText() {
      const doc = view.state.doc;
      const selection = view.state.selection;
      if (selection.empty) return '';
      const fragment =  doc.cut(selection.from, selection.to).content;
      let text = '';
      fragment.nodesBetween(0, fragment.size, (node) => {
          if (node.isText) {
              text += node.text;
              return false;
          }
          return true;
      });
      return (text.length === 0) ? null : text;
  }
  /**
   * Return the rectangle that encloses the selection.
   * @returns {Object} The selection rectangle's top, bottom, left, right.
   */
  function getSelectionRect() {
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
  }
  /**
   * Return the MarkTypes that exist at the selection.
   * @returns {Set<MarkType>}   The set of MarkTypes at the selection.
   */
  function _getMarkTypes() {
      const state = view.state;
      const {from, $from, to, empty} = state.selection;
      if (empty) {
          const marks = state.storedMarks || $from.marks();
          const markTypes = marks.map(mark => { return mark.type });
          return new Set(markTypes);
      } else {
          const markTypes = new Set();
          state.doc.nodesBetween(from, to, node => {
              node.marks.forEach(mark => markTypes.add(mark.type));
          });
          return markTypes;
      }
  }
  /**
   * Return the link attributes at the selection.
   * @returns {Object}   An Object whose properties are <a> attributes (like href, link) at the selection.
   */
  function getLinkAttributes() {
      const selection = view.state.selection;
      const selectedNodes = [];
      view.state.doc.nodesBetween(selection.from, selection.to, node => {
          if (node.isText) selectedNodes.push(node);
      });
      const selectedNode = (selectedNodes.length === 1) && selectedNodes[0];
      if (selectedNode) {
          const linkMarks = selectedNode.marks.filter(mark => mark.type === view.state.schema.marks.link);
          if (linkMarks.length === 1) {
              return {href: linkMarks[0].attrs.href, link: selectedNode.text};
          }    }    return {};
  }
  function _getImageAttributes() {
      return getImageAttributes(view.state)
  }

  /**
   * Return the image attributes at the selection
   * @returns {Object}   An Object whose properties are <img> attributes (like src, alt, width, height, scale) at the selection.
   */
  function getImageAttributes(state) {
      const selection = state.selection;
      const selectedNodes = [];
      state.doc.nodesBetween(selection.from, selection.to, node => {
          if (node.type === state.schema.nodes.image)  {
              selectedNodes.push(node);
              return false;
          }        return true;
      });
      const selectedNode = (selectedNodes.length === 1) && selectedNodes[0];
      return selectedNode ? selectedNode.attrs : {};
  }
  /**
   * If the selection is inside a table, populate attributes with the information
   * about the table and what is selected in it.
   * 
   * In the MarkupEditor, if there is a header, it is always colspanned across the number 
   * of columns, and normal rows are never colspanned.
   *
   * @returns {Object}   An object with properties populated.
   */
  function _getTableAttributes(state) {
      const viewState = state ?? view.state;
      const selection = viewState.selection;
      const nodeTypes = viewState.schema.nodes;
      const attributes = {};
      viewState.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
          let $pos = viewState.doc.resolve(pos);
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
                  viewState.doc.nodesBetween(attributes.from, attributes.to, (node) => {
                      switch (node.type) {
                          case nodeTypes.table_header:
                              attributes.header = true;
                              attributes.colspan = node.attrs.colspan;
                              if (attributes.colspan) {
                                  attributes.cols = Math.max(attributes.cols, attributes.colspan);
                              } else {
                                  attributes.cols = Math.max(attributes.cols, node.childCount);
                              }                            return false;
                          case nodeTypes.table_row:
                              attributes.cols = Math.max(attributes.cols, node.childCount);
                              return true;
                      }                    return true;
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
          }        return true;
      });
     return attributes;
  }

  /**
   * Return the paragraph style at the selection.
   *
   * @return {String}   {Tag name | 'Multiple'} that represents the selected paragraph style.
   */
  function _getParagraphStyle() {
      return paragraphStyle(view.state)
  }
  function paragraphStyle(state) {
      const selection = state.selection;
      const nodeTypes = new Set();
      state.doc.nodesBetween(selection.from, selection.to, node => {
          if (node.isBlock) { 
              nodeTypes.add(node.type);
          }        return false;   // We only need top-level nodes
      });
      return (nodeTypes.size <= 1) ? _paragraphStyleFor(selection.$anchor.parent) : 'Multiple';
  }

  /**
   * 
   * @param {Node} node The node we want the paragraph style for
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
          case 'code_block':
              style = "PRE";
              break;
      }    return style;
  }
  function isIndented(activeState) {
      let state = activeState ? activeState : view.state;
      return _getIndented(state); 
  }

  /**
   * Return whether the selection is indented.
   *
   * @return {Boolean}   Whether the selection is in a blockquote.
   */
  function _getIndented(state) {
      const selection = state.selection;
      let indented = false;
      state.doc.nodesBetween(selection.from, selection.to, node => {
          if (node.type == state.schema.nodes.blockquote) { 
              indented = true;
          }        return false;   // We only need top-level nodes
      });
      return indented;
  }
  /**
   * Report a selection change.
   */
  function selectionChanged() {
      _callback('selectionChanged');
  }

  /**
   * Report a click.
   */
  function clicked() {
      deactivateSearch();
      _callback('clicked');
  }

  /**
   * Report focus.
   */
  function focused() {
      _callback('focus');
  }

  /**
   * Report blur.
   */
  function blurred() {
      _callback('blur');
  }

  /**
   * Report a change in the ProseMirror document state. The 
   * change might be from typing or formatting or styling, etc.
   * and triggers both a `selectionChanged` and `input` callback.
   * 
   * @returns Bool    Return false so we can use in chainCommands directly
   */
  function stateChanged() {
      deactivateSearch();
      selectionChanged();
      callbackInput();
      return false;
  }

  /**
   * Post a message to the message handler.
   * 
   * Refer to MarkupCoordinate.swift source for message types and contents that are supported in Swift.
   * @param {string | Object} message  A JSON-serializable JavaScript object.
   */
  function postMessage(message) {
      _callback(JSON.stringify(message));
  }

  /********************************************************************************
   * Testing support
   */
  //MARK: Testing Support

  /**
   * Set the HTML `contents` and select the text identified by `sel`, removing the 
   * `sel` markers in the process.
   * 
   * Note that because we run multiple tests against a given view, and we use setTestHTML
   * to set the contents, we need to reset the view state completely each time. Otherwise, 
   * the history can be left in a state where an undo will work because the previous test
   * executed redo.
   * 
   * @param {*} contents  The HTML for the editor
   * @param {*} sel       An embedded character in contents marking selection point(s)
   */
  function setTestHTML(contents, sel) {
      // Start by resetting the view state.
      let state = EditorState.create({schema: view.state.schema, doc: view.state.doc, plugins: view.state.plugins});
      view.updateState(state);

      // Then set the HTML, which won't contain any sel markers.
      setHTML(contents, false);   // Do a normal setting of HTML
      if (!sel) return;           // Don't do any selection if we don't know what marks it

      // We need to clear the search state because we use it to find sel markers.
      searcher.cancel();

      // It's important that deleting the sel markers is not part of history, because 
      // otherwise undoing later will put them back.
      const selFrom = searcher.searchFor(sel).from;   // Find the first marker
      if (selFrom) {              // Delete the 1st sel
          const transaction = view.state.tr
              .deleteSelection()
              .setMeta("addToHistory", false);
          view.dispatch(transaction);
      } else {
          return;                 // There was no marker to find
      }

      let selTo = searcher.searchFor(sel).to;         // May be the same if only one marker
      if (selTo != selFrom) {     // Delete the 2nd sel if there is one; if not, they are the same
          const transaction = view.state.tr
              .deleteSelection()
              .setMeta("addToHistory", false);
          view.dispatch(transaction);
          selTo = selTo - sel.length;
      }

      // Set the selection based on where we found the sel markers. This should be part of 
      // history, because we need it to be set back on undo.
      const $from = view.state.doc.resolve(selFrom);
      const $to = view.state.doc.resolve(selTo);
      const transaction = view.state.tr.setSelection(new TextSelection($from, $to));
      view.dispatch(transaction);
  }
  /**
   * Get the HTML contents and mark the selection from/to using the text identified by `sel`.
   * @param {*} sel       An embedded character in contents indicating selection point(s)
   */
  function getTestHTML(sel) {
      if (!sel) return getHTML(false);   // Return the compressed/unformatted HTML if no sel
      let state = view.state;
      const selection = state.selection;
      const selFrom = selection.from;
      const selTo = selection.to;
      // Note that we never dispatch the transaction, so the view is not changed and
      // history is not affected.
      let transaction = state.tr.insertText(sel, selFrom);
      if (selFrom != selTo) transaction = transaction.insertText(sel, selTo + sel.length);
      const htmlElement = DOMSerializer.fromSchema(state.schema).serializeFragment(transaction.doc.content);
      const div = document.createElement('div');
      div.appendChild(htmlElement);
      return div.innerHTML;
  }
  function doUndo() {
      let command = undoCommand();
      let result = command(view.state, view.dispatch, view);
      return result
  }

  /**
   * Return a command to undo and do the proper callbacks.
   */
  function undoCommand() {
      let commandAdapter = (state, dispatch) => {
          let result = undo(state, dispatch);
          if (result && dispatch) {
              stateChanged();
          }
          return result
      };
      return commandAdapter
  }
  function doRedo() {
      let command = redoCommand();
      let result = command(view.state, view.dispatch, view);
      return result
  }

  /**
   * Return a command to redo and do the proper callbacks.
   */
  function redoCommand() {
      let commandAdapter = (state, dispatch) => {
          let result = redo(state, dispatch);
          if (result && dispatch) {
              stateChanged();
          }
          return result
      };
      return commandAdapter
  }
  /**
   * For testing purposes, invoke _doBlockquoteEnter programmatically.
   */
  function testBlockquoteEnter() {
  }
  /**
   * For testing purposes, invoke _doListEnter programmatically.
   */
  function testListEnter() {
      const splitCommand = splitListItem(view.state.schema.nodes.list_item);
      splitCommand(view.state, view.dispatch);
  }
  /**
   * For testing purposes, invoke extractContents() on the selected range
   * to make sure the selection is as expected.
   */
  function testExtractContents() {
  }
  /**
   * For testing purposes, create a ProseMirror Node that conforms to the 
   * MarkupEditor schema and return the resulting html as a string. 
   * Testing in this way lets us do simple pasteHTML tests with
   * clean HTML and test the effect of schema-conformance on HTML contents
   * separately. The html passed here is (typically) obtained from the paste 
   * buffer.
   */
  function testPasteHTMLPreprocessing(html) {
      const node = _nodeFromHTML(html);
      const fragment = _fragmentFromNode(node);
      return _htmlFromFragment(fragment);
  }
  /**
   * Use the same approach as testPasteHTMLPreprocessing, but augment with 
   * _minimalHTML to get a MarkupEditor-equivalent of unformatted text.
   */
  function testPasteTextPreprocessing(html) {
      const node = _nodeFromHTML(html);
      const fragment = _fragmentFromNode(node);
      const minimalHTML = _minimalHTML(fragment);
      return minimalHTML;
  }
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
  function insertLink(url) {
      let command = insertLinkCommand(url);
      let result = command(view.state, view.dispatch, view);
      return result
  }
  function insertLinkCommand(url) {
      const commandAdapter = (state, dispatch) => {
          const selection = state.selection;
          const linkMark = state.schema.marks.link.create({ href: url });
          if (selection.empty) {
              const textNode = state.schema.text(url).mark([linkMark]);
              const transaction = state.tr.replaceSelectionWith(textNode, false);
              const linkSelection = TextSelection.create(transaction.doc, selection.from, selection.from + textNode.nodeSize);
              transaction.setSelection(linkSelection);
              dispatch(transaction);
              stateChanged();
          } else {
              const toggle = toggleMark(linkMark.type, linkMark.attrs);
              if (toggle) {
                  toggle(state, dispatch);
                  stateChanged();
              }
          }
          return true;
      };
      return commandAdapter;
  }

  function insertInternalLinkCommand(hTag, index) {
      const commandAdapter = (state, dispatch) => {
          // Find the node matching hTag that is index into the nodes matching hTag
          let {node} = headerMatching(hTag, index, state);
          if (!node) return false
          // Get the unique id for this header, which is may or may not already have.
          let id = idForHeader(node, state);
          let attrs = node.attrs;
          attrs.id = id;
          // Insert the mark (id is always referenced with # at front) and set (or reset) the 
          // id in the header itself. We don't care if it's the same, but we want these changes 
          // to be made in a single transaction so we can undo them if needed.
          const selection = state.selection;
          const linkMark = state.schema.marks.link.create({ href: '#' + id });
          if (selection.empty) {
              // In case of an empty selection, insert the textContent of the header and then use 
              // that to link-to the header
              const textNode = state.schema.text(node.textContent, [linkMark]);
              let transaction = state.tr.replaceSelectionWith(textNode, false);
              dispatch(transaction);
              stateChanged();
              return true;
          } else {
              const toggle = toggleMark(linkMark.type, linkMark.attrs);
              if (toggle) {
                  toggle(state, dispatch);
                  stateChanged();
                  return true;
              } else {
                  return false;
              }
          }
      };
      return commandAdapter;
  }

  /**
   * Unlike other commands, this one returns an object identifying the id for the header with hTag. 
   * Other commands return true or false. This command also never does anything with the view or state.
   * @param {string} hTag One of the strings `H1`-`H6`
   * @param {*} index     Within existing elements with tag `hTag`, this is the index into them that is identified
   * @returns 
   */
  function idForInternalLinkCommand(hTag, index) {
      const commandAdapter = (state) => {
          let {node} = headerMatching(hTag, index, state);
          if (!node) return false;
          return {hTag: hTag, index: index, id: idForHeader(node, state), exists: node.attrs.id != null}
      };
      return commandAdapter;
  }

  /**
   * Return a unique identifier for the heading `node` by lowercasing its trimmed textContent
   * and replacing blanks with `-`, then appending a number until its unique if required.
   * If the heading `node` has an id, then just return it.
   * 
   * Since the `node.textContent` can be arbitrarily large, we limit the id to 40 characters 
   * just to avoid unwieldy IDs.
   * 
   * @param {Node}        node    A ProseMirror Node that is of heading type
   * @param {EditorState} state     
   * @returns {string}            A unique ID that is used by `node` or that can be assigned to `node`
   */
  function idForHeader(node, state) {
      if (node.attrs.id) return node.attrs.id
      let id = node.textContent.toLowerCase().substring(0, 40);
      id = id.replaceAll(' ', '-');
      let {node: idNode} = nodeWithId(id, state);
      let index = 0;
      while (idNode) {
          index++;
          id = id + index.toString();
          let {node} = nodeWithId(id, state);
          idNode = node;
      }
      return id
  }

  /**
   * Return the node and its position that has an attrs.id matching `id`
   * @param {string} id The id attr of a Node we are trying to match
   * @param {*} state 
   * @returns {object}    The `node` and its `pos` in the `state.doc`
   */
  function nodeWithId(id, state) {
      let idNode, idPos;
      state.doc.nodesBetween(0, state.doc.content.size, (node, pos) => {
          if (!idNode && (node.attrs.id == id)) {
              idNode = node;
              idPos = pos;
              return false
          }
          return !idNode  // Keep traversing unless we found a matching id
      });
      return {node: idNode, pos: idPos}
  }

  function headerMatching(hTag, index, state) {
      let header = {node: null, pos: null};
      let hLevel = parseInt(hTag.substring(1));
      let headersAtLevel = headers(state)[hLevel];
      if (!headersAtLevel) {
          return header
      } else {
          return headersAtLevel[index]
      }
  }

  // Return all the headers that exist in `state.doc` as arrays keyed by level
  function headers(state) {
      let headers = {};
      let hType = state.schema.nodes.heading;
      let pType = state.schema.nodes.paragraph;
      let cType = state.schema.nodes.code_block;
      state.doc.nodesBetween(0, state.doc.content.size, (node, pos) => {
          let nodeType = node.type;
          if (nodeType == hType) {
              let level = node.attrs.level;
              if (!headers[level]) headers[level] = [];
              headers[level].push({node: node, pos: pos});
              return false
          } else if ((nodeType == pType) || (nodeType == cType)) {
              // We don't need to keep traversing a <H1-6>, <P>, or <PRE><CODE> because 
              // they can't contain other headers
              return false
          }
          // However, the remaining block nodes like table cells and lists can contain them
          return true
      });
      return headers
  }

  /**
   * Remove the link at the selection, maintaining the same selection.
   * 
   * The selection can be at any point within the link or contain the full link, but cannot include 
   * areas outside of the link.
   */
  function deleteLink() {
      // Make sure the selection is in a single text node with a linkType Mark and 
      // that the full link is selected in the view.
      selectFullLink(view);

      // Then execute the deleteLinkCommand, which removes the link and leaves the 
      // full text of what was linked selected.
      let command = deleteLinkCommand();
      return command(view.state, view.dispatch, view)
  }
  function deleteLinkCommand() {
      const commandAdapter = (state, dispatch, view) => {
          const linkType = view.state.schema.marks.link;
          const selection = view.state.selection;
          const toggle = toggleMark(linkType);
          if (toggle) {
              return toggle(view.state, (tr) => {
                  let newState = view.state.apply(tr);   // Toggle the link off
                  const textSelection = TextSelection.create(newState.doc, selection.from, selection.to);
                  tr.setSelection(textSelection);
                  view.dispatch(tr);
                  stateChanged();
              });
          } else {
              return false;
          }
      };
      return commandAdapter;
  }

  function selectFullLink(view) {
      const linkType = view.state.schema.marks.link;
      const selection = view.state.selection;

      // Make sure the selection is in a single text node with a linkType Mark
      const nodePos = [];
      view.state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
          if (node.isText) {
              nodePos.push({node: node, pos: pos});
              return false;
          }        return true;
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
      view.dispatch(transaction);
  }

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
  function insertImage(src, alt) {
      let command = insertImageCommand(src, alt);
      return command(view.state, view.dispatch, view)
  }
  function insertImageCommand(src, alt) {
      const commandAdapter = (state, dispatch, view) => {
          const imageNode = view.state.schema.nodes.image.create({src: src, alt: alt});
          const transaction = view.state.tr.replaceSelectionWith(imageNode, true);
          view.dispatch(transaction);
          stateChanged();
          return true;
      };

      return commandAdapter
  }

  /**
   * Modify the attributes of the image at selection.
   *
   * @param {String}              src         The url of the image.
   * @param {String}              alt         The alt text describing the image.
   */
  function modifyImage(src, alt) {
      let command = modifyImageCommand(src, alt);
      return command(view.state, view.dispatch, view)
  }
  function modifyImageCommand(src, alt) {
      const commandAdapter = (state, dispatch, view) => {
          const selection = view.state.selection;
          const imageNode = selection.node;
          if (imageNode?.type !== view.state.schema.nodes.image) return false;
          let imagePos;
          view.state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
              if (node === imageNode) {
                  imagePos = pos;
                  return false;
              }
              return true;
          });
          if (imagePos) {
              const transaction = view.state.tr
                  .setNodeAttribute(imagePos, 'src', src)
                  .setNodeAttribute(imagePos, 'alt', alt);
              view.dispatch(transaction);
              return true
          } else {
              return false
          }
      };

      return commandAdapter
  }

  /**
   * Cut the selected image from the document.
   * 
   * Copy before deleting the image is done via a callback, which avoids
   * potential CORS issues. Similarly, copying of an image (e.g., Ctrl-C) is all done 
   * by the side holding the copy buffer, not via JavaScript.
   */
  function cutImage() {
      const selection = view.state.selection;
      const imageNode = selection.node;
      if (imageNode?.type === view.state.schema.nodes.image) {
          copyImage(imageNode);
          const transaction = view.state.tr.deleteSelection();
          view.dispatch(transaction);
          stateChanged();
      }}
  /**
   * Post a message with src, alt, and dimensions, so the image contents can be put into the clipboard.
   * 
   * @param {Node} node   A ProseMirror image node
   */
  function copyImage(node) {
      const messageDict = {
          'messageType' : 'copyImage',
          'src' : node.attrs.src,
          'alt' : node.attrs.alt,
          'dimensions' : {width: node.attrs.width, height: node.attrs.height}
      };
      _callback(JSON.stringify(messageDict));
  }
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
  function insertTable(rows, cols) {
      if ((rows < 1) || (cols < 1)) return;
      let command = insertTableCommand(rows, cols);
      let result = command(view.state, view.dispatch, view);
      return result;
  }
  function insertTableCommand(rows, cols) {
      const commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          const nodeTypes = state.schema.nodes;
          const table_rows = [];
          for (let j = 0; j < rows; j++) {
              const table_cells = [];
              for (let i = 0; i < cols; i++) {
                  const paragraph = state.schema.node('paragraph');
                  table_cells.push(nodeTypes.table_cell.create(null, paragraph));
              }
              table_rows.push(nodeTypes.table_row.create(null, table_cells));
          }
          const table = nodeTypes.table.create(null, table_rows);
          if (!table) return false;     // Something went wrong, like we tried to insert it at a disallowed spot
          if (dispatch) {
              // Replace the existing selection and track the transaction
              let transaction = view.state.tr.replaceSelectionWith(table, false);
              // Locate the table we just inserted in the transaction's doc.
              // Note that because pPos can be 0 or 1, we really need to check 
              // explicityly on undefined to terminate nodesBetween traversal.
              let pPos;
              let from = transaction.selection.from;
              let to = transaction.selection.to;
              transaction.doc.nodesBetween(from, to, (node, pos) => {
                  if (node === table) {
                      pPos = pos;
                  }                return (pPos == undefined);    // Keep going if pPos hasn't been defined
              });
              // After we replace the selection with the table, you would think that 
              // the transaction.selection.from and to would encompass the table, but 
              // they do not necessarily. IOW if you do transaction.doc.nodesBetween 
              // on from and to, you should find the table, right? Not always, so if 
              // we didn't emerge with pPos defined, just look for the thing across 
              // the entire doc as a backup.
              if (pPos == undefined) {
                  transaction.doc.nodesBetween(0, transaction.doc.content.size, (node, pos) => {
                      if (node === table) {
                          pPos = pos;
                      }                    return (pPos == undefined);    // Keep going if pPos hasn't been defined
                  });
              }
              // Set the selection in the first cell, apply it to the state and the view.
              // We have to special-case for empty documents to get selection in the 1st cell.
              let empty = (view.state.doc.textContent.length == 0);
              let textSelection;
              if (empty) {
                  textSelection = TextSelection.near(transaction.doc.resolve(pPos), -1);
              } else {
                  textSelection = TextSelection.near(transaction.doc.resolve(pPos));
              }
              transaction = transaction.setSelection(textSelection);
              state = state.apply(transaction);
              view.updateState(state);
              view.focus();
              stateChanged();
          }
          
          return true;
      };

      return commandAdapter;
  }

  /**
   * Add a row before or after the current selection, whether it's in the header or body.
   * For rows, AFTER = below; otherwise above.
   *
   * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new row goes relative to the selection.
   */
  function addRow(direction) {
      if (!_tableSelected()) return;
      let command = addRowCommand(direction);
      let result = command(view.state, view.dispatch);
      view.focus();
      stateChanged();
      return result;
  }
  function addRowCommand(direction) {
      const commandAdapter = (state, dispatch) => {
          if (direction === 'BEFORE') {
              return addRowBefore(state, dispatch);
          } else {
              return addRowAfter(state, dispatch);
          }    };

      return commandAdapter;
  }

  /**
   * Add a column before or after the current selection, whether it's in the header or body.
   * 
   * In MarkupEditor, the header is always colspanned fully, so we need to merge the headers if adding 
   * a column in created a new element in the header row.
   *
   * @param {String}  direction   Either 'BEFORE' or 'AFTER' to identify where the new column goes relative to the selection.
   */
  function addCol(direction) {
      if (!_tableSelected()) return;
      let command = addColCommand(direction);
      let result = command(view.state, view.dispatch, view);
      view.focus();
      stateChanged();
      return result;
  }
  function addColCommand(direction) {
      const commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          if (!isTableSelected(state)) return false;
          const startSelection = new TextSelection(state.selection.$anchor, state.selection.$head);
          let offset = 0;
          if (direction === 'BEFORE') {
              addColumnBefore(state, (tr) => { state = state.apply(tr); });
              offset = 4;  // An empty cell
          } else {
              addColumnAfter(state, (tr) => { state = state.apply(tr); });
          }        _mergeHeaders(state, (tr) => { state = state.apply(tr); });

          if (dispatch) {
              const $anchor = state.tr.doc.resolve(startSelection.from + offset);
              const $head = state.tr.doc.resolve(startSelection.to + offset);
              const selection = new TextSelection($anchor, $head);
              const transaction = state.tr.setSelection(selection);
              state = state.apply(transaction);
              view.updateState(state);
          }

          return true;
      };

      return commandAdapter;
  }

  /**
   * Add a header to the table at the selection.
   *
   * @param {boolean} colspan     Whether the header should span all columns of the table or not.
   */
  function addHeader(colspan=true) {
      let tableAttributes = _getTableAttributes();
      if (!tableAttributes.table || tableAttributes.header) return;   // We're not in a table or we are but it has a header already
      let command = addHeaderCommand(colspan);
      let result = command(view.state, view.dispatch, view);
      view.focus();
      stateChanged();
      return result;
  }
  function addHeaderCommand(colspan = true) {
      const commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          if (!isTableSelected(state)) return false;
          const nodeTypes = state.schema.nodes;
          const startSelection = new TextSelection(state.selection.$anchor, state.selection.$head);
          _selectInFirstCell(state, (tr) => { state = state.apply(tr); });
          addRowBefore(state, (tr) => { state = state.apply(tr); });
          _selectInFirstCell(state, (tr) => { state = state.apply(tr); });
          toggleHeaderRow(state, (tr) => { state = state.apply(tr); });
          if (colspan) {
              _mergeHeaders(state, (tr) => { state = state.apply(tr); });
          }
          if (dispatch) {
              // At this point, the state.selection is in the new header row we just added. By definition, 
              // the header is placed before the original selection, so we can add its size to the 
              // selection to restore the selection to where it was before.
              let tableAttributes = _getTableAttributes(state);
              let headerSize;
              state.tr.doc.nodesBetween(tableAttributes.from, tableAttributes.to, (node) => {
                  if (!headerSize && (node.type == nodeTypes.table_row)) {
                      headerSize = node.nodeSize;
                      return false;
                  }
                  return (node.type == nodeTypes.table);  // We only want to recurse over table
              });
              const $anchor = state.tr.doc.resolve(startSelection.from + headerSize);
              const $head = state.tr.doc.resolve(startSelection.to + headerSize);
              const selection = new TextSelection($anchor, $head);
              const transaction = state.tr.setSelection(selection);
              state = state.apply(transaction);
              view.updateState(state);
          }

          return true;
      };

      return commandAdapter;
  }

  /**
   * Delete the area at the table selection, either the row, col, or the entire table.
   * @param {'ROW' | 'COL' | 'TABLE'} area The area of the table to be deleted.
   */
  function deleteTableArea(area) {
      if (!_tableSelected()) return;
      let command = deleteTableAreaCommand(area);
      let result = command(view.state, view.dispatch);
      view.focus();
      stateChanged();
      return result;
  }
  function deleteTableAreaCommand(area) {
      const commandAdapter = (state, dispatch) => {
          switch (area) {
              case 'ROW':
                  return deleteRow(state, dispatch);
              case 'COL':
                  return deleteColumn(state, dispatch);
              case 'TABLE':
                  return deleteTable(state, dispatch);
          }        return false;
      };

      return commandAdapter;
  }

  /**
   * Set the class of the table to style it using CSS.
   * The default draws a border around everything.
   * 
   * @param {'outer' | 'header' | 'cell' | 'none'} border Set the class of the table to correspond to caller's notion of border, so it displays properly.
   */
  function borderTable(border) {
      if (_tableSelected()) {
          let command = setBorderCommand(border);
          let result = command(view.state, view.dispatch, view);
          stateChanged();
          view.focus();
          return result;
      }
  }
  /**
   * Return whether the selection is within a table.
   * @returns {boolean} True if the selection is within a table
   */
  function _tableSelected() {
      return _getTableAttributes().table;
  }
  function _selectInFirstCell(state, dispatch) {
      const tableAttributes = _getTableAttributes(state);
      if (!tableAttributes.table) return;
      const nodeTypes = state.schema.nodes; 
      // Find the position of the first paragraph in the table
      let pPos;
      state.doc.nodesBetween(tableAttributes.from, tableAttributes.to, (node, pos) => {
          if ((!pPos) && (node.type === nodeTypes.paragraph)) {
              pPos = pos;
              return false;
          }
          return true;
      });
      if (!pPos) return;
      // Set the selection in the first paragraph in the first cell
      const $pos = state.doc.resolve(pPos);
      // When the first cell is an empty colspanned header, the $pos resolves to a table_cell,
      // so we need to use NodeSelection in that case.
      let selection = TextSelection.between($pos, $pos);
      const transaction = state.tr.setSelection(selection);
      state.apply(transaction);
      if (dispatch) {
          dispatch(transaction);
      }
  }
  /**
   * Merge any extra headers created after inserting a column or adding a header.
   * 
   * When inserting at the left or right column of a table, the addColumnBefore and 
   * addColumnAfter also insert a new cell/td within the header row. Since in 
   * the MarkupEditor, the row is always colspanned across all columns, we need to 
   * merge the cells together when this happens. The operations that insert internal 
   * columns don't cause the header row to have a new cell.
   */
  function _mergeHeaders(state, dispatch) {
      const nodeTypes = state.schema.nodes;
      const headers = [];
      let tableAttributes = _getTableAttributes(state);
      state.tr.doc.nodesBetween(tableAttributes.from, tableAttributes.to, (node, pos) => {
          if (node.type == nodeTypes.table_header) {
              headers.push(pos);
              return false;
          }
          return true;
      });
      if (headers.length > 1) {
          const firstHeaderPos = headers[0];
          const lastHeaderPos = headers[headers.length - 1];
          const rowSelection = CellSelection.create(state.tr.doc, firstHeaderPos, lastHeaderPos);
          const transaction = state.tr.setSelection(rowSelection);
          const newState = state.apply(transaction);
          mergeCells(newState, dispatch);
      }}
  function isTableSelected(state) {
      let tableSelected = false;
      state.doc.nodesBetween(state.selection.from, state.selection.to, (node) => {
          if (node.type === state.schema.nodes.table) {
              tableSelected = true;
              return false;
          }        return false;
      });
      return tableSelected
  }

  function tableHasHeader(state) {
      if (!isTableSelected) return false
      return _getTableAttributes(state).header === true
  }

  function setBorderCommand(border) {
      const commandAdapter = (viewState, dispatch, view) => {
          let state = view?.state ?? viewState;
          const selection = state.selection;
          let table, fromPos, toPos;
          state.doc.nodesBetween(selection.from, selection.to, (node, pos) => {
              if (node.type === state.schema.nodes.table) {
                  table = node;
                  fromPos = pos;
                  toPos = pos + node.nodeSize;
                  return false;
              }            return false;
          });
          if (!table) return false;
          if (dispatch) {
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
              }            // At this point, the state.selection is in the new header row we just added. By definition, 
              // the header is placed before the original selection, so we can add its size to the 
              // selection to restore the selection to where it was before.
               const transaction = view.state.tr
                  .setMeta("bordered-table", {border: border, fromPos: fromPos, toPos: toPos})
                  .setNodeMarkup(fromPos, table.type, table.attrs);
              view.dispatch(transaction);
          }

          return true;
      };

      return commandAdapter;
  }

  /**
   * Get the border around and within the cell.
   * @returns {'outer' | 'header' | 'cell' | 'none'} The type of table border known on the view holder's side.
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
      }    return border;
  }
  /**
   * Return the first node starting at depth 0 (the top) that is of type `type`.
   * @param {NodeType}    type The NodeType we are looking for that contains $pos.
   * @param {ResolvedPos} $pos A resolved position within a document node.
   * @returns Node | null
   */
  function outermostOfTypeAt(type, $pos) {
      const depth = $pos.depth;
      for (let i = 0; i < depth; i++) {
        if ($pos.node(i).type == type) return $pos.node(i);
      }    return null;
  }

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
  }
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
  }
  /**
   * Return a ProseMirror Slice derived from HTML text.
   * @param {string} html 
   * @returns Slice
   */
  function _sliceFromHTML(html) {
      const div = document.createElement('div');
      div.innerHTML = html ?? "";
      return _sliceFromElement(div);
  }
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
  }
  /**
   * Return whether node is a textNode or not
   */
  function _isTextNode(node) {
      return node && (node.nodeType === Node.TEXT_NODE);
  }
  /**
   * Return whether node is an ELEMENT_NODE or not
   */
  function _isElementNode(node) {
      return node && (node.nodeType === Node.ELEMENT_NODE);
  }
  /**
   * Return whether node is a format element; i.e., its nodeName is in _formatTags
   */
  function _isFormatElement(node) {
      return _isElementNode(node) && _formatTags.includes(node.nodeName);
  }
  /**
   * Return whether node has a void tag (i.e., does not need a terminator)
   */
  function _isVoidNode(node) {
      return node && (_voidTags.includes(node.nodeName));
  }
  /**
   * Return whether node is a link
   */
  function _isLinkNode(node) {
      return node && (node.nodeName === 'A');
  }

  class DOMAccess {

      constructor(prefix) {
          this.prefix = prefix ?? 'Markup';
      }

      setPrefix(prefix) {
          this.prefix = prefix;
      }

      /**
       * Return the toolbar div in `view`
       * @param {EditorView} view 
       * @returns {HTMLDivElement}  The toolbar div in the view
       */
      getToolbar() {
          return document.getElementById(this.prefix + "-toolbar");
      }

      getSearchItem() {
          return document.getElementById(this.prefix + '-searchitem')
      }

      getSearchbar() {
          return document.getElementById(this.prefix + "-searchbar");
      }

      getToolbarMore() {
          return document.getElementById(this.prefix + "-toolbar-more")
      }

      getWrapper() {
          return this.getToolbar().parentElement;
      }

      /** Adding promptShowing class on wrapper lets us suppress scroll while the prompt is showing */
      addPromptShowing() {
          setClass(getWrapper(), promptShowing(), true);
      }

      /** Removing promptShowing class on wrapper lets wrapper scroll again */
      removePromptShowing() {
          setClass(getWrapper(), promptShowing(), false);
      }

      promptShowing() {
          return this.prefix + "-prompt-showing"
      }

      searchbarShowing() {
          return this.prefix + "-searchbar-showing"
      }

      searchbarHidden() {
          return this.prefix + "-searchbar-hidden"
      }

  }

  let domAccess = new DOMAccess();
  const prefix = domAccess.prefix;
  const setPrefix = domAccess.setPrefix.bind(domAccess);
  const getToolbar = domAccess.getToolbar.bind(domAccess);
  domAccess.getSearchItem.bind(domAccess);
  const getSearchbar = domAccess.getSearchbar.bind(domAccess);
  const getToolbarMore = domAccess.getToolbarMore.bind(domAccess);
  const getWrapper = domAccess.getWrapper.bind(domAccess);
  const addPromptShowing = domAccess.addPromptShowing.bind(domAccess);
  const removePromptShowing = domAccess.removePromptShowing.bind(domAccess);
  const promptShowing = domAccess.promptShowing.bind(domAccess);
  const searchbarShowing = domAccess.searchbarShowing.bind(domAccess);
  const searchbarHidden = domAccess.searchbarHidden.bind(domAccess);

  function getMarkupEditorConfig() {
    return JSON.parse(window.sessionStorage.getItem("markupEditorConfig"))
  }

  function setMarkupEditorConfig(config) {
      window.sessionStorage.setItem("markupEditorConfig", JSON.stringify(config));
  }

  /**
   * 
   * @param {EditorView}  view
   * @param {string} text Text to be translated
   * @returns {string}    The translated text if the view supports it
   */
  function translate(view, text) {
      return view._props.translate ? view._props.translate(text) : text;
  }
  /**
   * Add or remove a class from the element.
   * 
   * Apparently a workaround for classList.toggle being broken in IE11
   * 
   * @param {HTMLElement}  dom 
   * @param {string}          cls The class name to add or remove
   * @param {boolean}         on  True to add the class name to the `classList`
   */
  function setClass(dom, cls, on) {
      if (on)
          dom.classList.add(cls);
      else
          dom.classList.remove(cls);
  }

  /**
   *  A set of MarkupEditor icons. Used to identify the icon for a 
   * `MenuItem` by specifying the `svg`. The `svg` value was obtained from
   * https://fonts.google.com/icons for the icons identified in the comment,
   * with the `fill` attribute removed so it can be set in css.
   */
  const icons = {
    undo: {
      // <span class="material-icons-outlined">undo</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M12.5 8c-2.65 0-5.05.99-6.9 2.6L2 7v9h9l-3.62-3.62c1.39-1.16 3.16-1.88 5.12-1.88 3.54 0 6.55 2.31 7.6 5.5l2.37-.78C21.08 11.03 17.15 8 12.5 8z"/></svg>'
    },
    redo: {
      // <span class="material-icons-outlined">redo</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M18.4 10.6C16.55 8.99 14.15 8 11.5 8c-4.65 0-8.58 3.03-9.96 7.22L3.9 16c1.05-3.19 4.05-5.5 7.6-5.5 1.95 0 3.73.72 5.12 1.88L13 16h9V7l-3.6 3.6z"/></svg>'
    },
    strong: {
      // <span class="material-icons-outlined">format_bold</span>
      svg: `<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M15.6 10.79c.97-.67 1.65-1.77 1.65-2.79 0-2.26-1.75-4-4-4H7v14h7.04c2.09 0 3.71-1.7 3.71-3.79 0-1.52-.86-2.82-2.15-3.42zM10 6.5h3c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5h-3v-3zm3.5 9H10v-3h3.5c.83 0 1.5.67 1.5 1.5s-.67 1.5-1.5 1.5z"/></svg>`
    },
    em: {
      // <span class="material-icons-outlined">format_italic</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M200-200v-100h160l120-360H320v-100h400v100H580L460-300h140v100H200Z"/></svg>'
    },
    u: {
      // <span class="material-icons-outlined">format_underlined</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M200-120v-80h560v80H200Zm280-160q-101 0-157-63t-56-167v-330h103v336q0 56 28 91t82 35q54 0 82-35t28-91v-336h103v330q0 104-56 167t-157 63Z"/></svg>'
    },
    s: {
      // <span class="material-icons-outlined">strikethrough_s</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M486-160q-76 0-135-45t-85-123l88-38q14 48 48.5 79t85.5 31q42 0 76-20t34-64q0-18-7-33t-19-27h112q5 14 7.5 28.5T694-340q0 86-61.5 133T486-160ZM80-480v-80h800v80H80Zm402-326q66 0 115.5 32.5T674-674l-88 39q-9-29-33.5-52T484-710q-41 0-68 18.5T386-640h-96q2-69 54.5-117.5T482-806Z"/></svg>'
    },
    code: {
      // <span class="material-icons-outlined">data_object</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M560-160v-80h120q17 0 28.5-11.5T720-280v-80q0-38 22-69t58-44v-14q-36-13-58-44t-22-69v-80q0-17-11.5-28.5T680-720H560v-80h120q50 0 85 35t35 85v80q0 17 11.5 28.5T840-560h40v160h-40q-17 0-28.5 11.5T800-360v80q0 50-35 85t-85 35H560Zm-280 0q-50 0-85-35t-35-85v-80q0-17-11.5-28.5T120-400H80v-160h40q17 0 28.5-11.5T160-600v-80q0-50 35-85t85-35h120v80H280q-17 0-28.5 11.5T240-680v80q0 38-22 69t-58 44v14q36 13 58 44t22 69v80q0 17 11.5 28.5T280-240h120v80H280Z"/></svg>'
    },
    sub: {
      // <span class="material-icons-outlined">subscript</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M760-160v-80q0-17 11.5-28.5T800-280h80v-40H760v-40h120q17 0 28.5 11.5T920-320v40q0 17-11.5 28.5T880-240h-80v40h120v40H760Zm-525-80 185-291-172-269h106l124 200h4l123-200h107L539-531l186 291H618L482-457h-4L342-240H235Z"/></svg>'
    },
    sup: {
      // <span class="material-icons-outlined">superscript</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M760-600v-80q0-17 11.5-28.5T800-720h80v-40H760v-40h120q17 0 28.5 11.5T920-760v40q0 17-11.5 28.5T880-680h-80v40h120v40H760ZM235-160l185-291-172-269h106l124 200h4l123-200h107L539-451l186 291H618L482-377h-4L342-160H235Z"/></svg>'
    },
    link: {
      // <span class="material-icons-outlined">link</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 0 24 24" width="24px"><path d="M0 0h24v24H0V0z" fill="none"/><path d="M17 7h-4v2h4c1.65 0 3 1.35 3 3s-1.35 3-3 3h-4v2h4c2.76 0 5-2.24 5-5s-2.24-5-5-5zm-6 8H7c-1.65 0-3-1.35-3-3s1.35-3 3-3h4V7H7c-2.76 0-5 2.24-5 5s2.24 5 5 5h4v-2zm-3-4h8v2H8z"/></svg>',
    },
    image: {
      // <span class="material-icons-outlined">image</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm0-80h560v-560H200v560Zm40-80h480L570-480 450-320l-90-120-120 160Zm-40 80v-560 560Z"/></svg>'
    },
    table: {
      // <span class="material-icons-outlined">table</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M200-120q-33 0-56.5-23.5T120-200v-560q0-33 23.5-56.5T200-840h560q33 0 56.5 23.5T840-760v560q0 33-23.5 56.5T760-120H200Zm240-240H200v160h240v-160Zm80 0v160h240v-160H520Zm-80-80v-160H200v160h240Zm80 0h240v-160H520v160ZM200-680h560v-80H200v80Z"/></svg>'
    },
    bulletList: {
      // <span class="material-icons-outlined">format_list_bulleted</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M360-200v-80h480v80H360Zm0-240v-80h480v80H360Zm0-240v-80h480v80H360ZM200-160q-33 0-56.5-23.5T120-240q0-33 23.5-56.5T200-320q33 0 56.5 23.5T280-240q0 33-23.5 56.5T200-160Zm0-240q-33 0-56.5-23.5T120-480q0-33 23.5-56.5T200-560q33 0 56.5 23.5T280-480q0 33-23.5 56.5T200-400Zm0-240q-33 0-56.5-23.5T120-720q0-33 23.5-56.5T200-800q33 0 56.5 23.5T280-720q0 33-23.5 56.5T200-640Z"/></svg>'
    },
    orderedList: {
      // <span class="material-icons-outlined">format_list_numbered</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M120-80v-60h100v-30h-60v-60h60v-30H120v-60h120q17 0 28.5 11.5T280-280v40q0 17-11.5 28.5T240-200q17 0 28.5 11.5T280-160v40q0 17-11.5 28.5T240-80H120Zm0-280v-110q0-17 11.5-28.5T160-510h60v-30H120v-60h120q17 0 28.5 11.5T280-560v70q0 17-11.5 28.5T240-450h-60v30h100v60H120Zm60-280v-180h-60v-60h120v240h-60Zm180 440v-80h480v80H360Zm0-240v-80h480v80H360Zm0-240v-80h480v80H360Z"/></svg>'
    },
    blockquote: {
      // <span class="material-icons-outlined">format_indent_increase</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M120-120v-80h720v80H120Zm320-160v-80h400v80H440Zm0-160v-80h400v80H440Zm0-160v-80h400v80H440ZM120-760v-80h720v80H120Zm0 440v-320l160 160-160 160Z"/></svg>'
    },
    lift: {
      // <span class="material-icons-outlined">format_indent_decrease</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px"><path d="M120-120v-80h720v80H120Zm320-160v-80h400v80H440Zm0-160v-80h400v80H440Zm0-160v-80h400v80H440ZM120-760v-80h720v80H120Zm160 440L120-480l160-160v320Z"/></svg>'
    },
    search: {
      // <span class="material-symbols-outlined">search</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M784-120 532-372q-30 24-69 38t-83 14q-109 0-184.5-75.5T120-580q0-109 75.5-184.5T380-840q109 0 184.5 75.5T640-580q0 44-14 83t-38 69l252 252-56 56ZM380-400q75 0 127.5-52.5T560-580q0-75-52.5-127.5T380-760q-75 0-127.5 52.5T200-580q0 75 52.5 127.5T380-400Z"/></svg>'
    },
    searchForward: {
      // <span class="material-symbols-outlined">chevron_forward</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M504-480 320-664l56-56 240 240-240 240-56-56 184-184Z"/></svg>'
    },
    searchBackward: {
      // <span class="material-symbols-outlined">chevron_backward</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M560-240 320-480l240-240 56 56-184 184 184 184-56 56Z"/></svg>'
    },
    matchCase: {
      // <span class="material-symbols-outlined">match_case</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="m131-252 165-440h79l165 440h-76l-39-112H247l-40 112h-76Zm139-176h131l-64-182h-4l-63 182Zm395 186q-51 0-81-27.5T554-342q0-44 34.5-72.5T677-443q23 0 45 4t38 11v-12q0-29-20.5-47T685-505q-23 0-42 9.5T610-468l-47-35q24-29 54.5-43t68.5-14q69 0 103 32.5t34 97.5v178h-63v-37h-4q-14 23-38 35t-53 12Zm12-54q35 0 59.5-24t24.5-56q-14-8-33.5-12.5T689-393q-32 0-50 14t-18 37q0 20 16 33t40 13Z"/></svg>'
    },
    paragraphStyle: {
      // <span class="material-symbols-outlined">format_paragraph</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M360-160v-240q-83 0-141.5-58.5T160-600q0-83 58.5-141.5T360-800h360v80h-80v560h-80v-560H440v560h-80Z"/></svg>'
    },
    more: {
      // <span class="material-symbols-outlined">more_horiz</span>
      svg: '<svg xmlns="http://www.w3.org/2000/svg" height="24px" viewBox="0 -960 960 960" width="24px" fill="#1f1f1f"><path d="M240-400q-33 0-56.5-23.5T160-480q0-33 23.5-56.5T240-560q33 0 56.5 23.5T320-480q0 33-23.5 56.5T240-400Zm240 0q-33 0-56.5-23.5T400-480q0-33 23.5-56.5T480-560q33 0 56.5 23.5T560-480q0 33-23.5 56.5T480-400Zm240 0q-33 0-56.5-23.5T640-480q0-33 23.5-56.5T720-560q33 0 56.5 23.5T800-480q0 33-23.5 56.5T720-400Z"/></svg>'
    }
  };

  function getIcon(root, icon) {
      let doc = (root.nodeType == 9 ? root : root.ownerDocument) || document;
      let node = doc.createElement("span");
      node.className = prefix + "-icon";
      node.innerHTML = icon.svg;
      return node;
  }

  function crelt() {
    var elt = arguments[0];
    if (typeof elt == "string") elt = document.createElement(elt);
    var i = 1, next = arguments[1];
    if (next && typeof next == "object" && next.nodeType == null && !Array.isArray(next)) {
      for (var name in next) if (Object.prototype.hasOwnProperty.call(next, name)) {
        var value = next[name];
        if (typeof value == "string") elt.setAttribute(name, value);
        else if (value != null) elt[name] = value;
      }
      i++;
    }
    for (; i < arguments.length; i++) add(elt, arguments[i]);
    return elt
  }

  function add(elt, child) {
    if (typeof child == "string") {
      elt.appendChild(document.createTextNode(child));
    } else if (child == null) ; else if (child.nodeType != null) {
      elt.appendChild(child);
    } else if (Array.isArray(child)) {
      for (var i = 0; i < child.length; i++) add(elt, child[i]);
    } else {
      throw new RangeError("Unsupported child node: " + child)
    }
  }

  /* global view */

  /**
  An icon or label that, when clicked, executes a command.
  */
  class MenuItem {

    /**
     * Create a menu item.
     * 
     * @param {*} spec The spec used to create this item.
    */
    constructor(spec) {
      this.prefix = prefix + "-menuitem";
      this.spec = spec;
    }

    /**
    Renders the icon according to its [display
    spec](https://prosemirror.net/docs/ref/#menu.MenuItemSpec.display), and adds an event handler which
    executes the command when the representation is clicked.
    */
    render(view) {
      let spec = this.spec;
      let prefix = this.prefix;
      let dom = spec.render ? spec.render(view)
        : spec.icon ? getIcon(view.root, spec.icon)
          : spec.label ? crelt("div", null, translate(view, spec.label))
            : null;
      if (!dom)
        throw new RangeError("MenuItem without icon or label property");
      if (spec.title) {
        const title = (typeof spec.title === "function" ? spec.title(view.state) : spec.title);
        dom.setAttribute("title", translate(view, title));
      }
      if (spec.class)
        dom.classList.add(spec.class);
      if (spec.css)
        dom.style.cssText += spec.css;
      dom.addEventListener("mousedown", e => {
        e.preventDefault();
        if (!dom.classList.contains(prefix + "-disabled")) {
          let result = spec.run(view.state, view.dispatch, view, e);
          if (spec.callback) {
            spec.callback(result);
          }
        }
      });

      function update(state) {
        if (spec.select) {
          let selected = spec.select(state);
          dom.style.display = selected ? "" : "none";
          if (!selected)
            return false;
        }
        let enabled = true;
        if (spec.enable) {
          enabled = spec.enable(state) || false;
          setClass(dom, prefix + "-disabled", !enabled);
        }
        if (spec.active) {
          let active = enabled && spec.active(state) || false;
          setClass(dom, prefix + "-active", active);
        }
        return true;
      }
      return { dom, update };
    }
  }

  /**
  A drop-down menu, displayed as a label with a downwards-pointing
  triangle to the right of it.
  */
  class Dropdown {

    /**
    Create a dropdown wrapping the elements.
    */
    constructor(content, options = {}) {
      this.prefix = prefix + "-menu";
      this.options = options;
      if (this.options.indicator == undefined) this.options.indicator = true;
      this.content = Array.isArray(content) ? content : [content];
    }
    /**
    Render the dropdown menu and sub-items.
    */
    render(view) {
      let options = this.options;
      let content = renderDropdownItems(this.content, view);
      let win = view.dom.ownerDocument.defaultView || window;
      let indicator = crelt("span", "\u25BE");
      setClass(indicator, this.prefix + "-dropdown-indicator", true);
      let label;
      if (this.options.icon) {
        label = getIcon(view.root, this.options.icon);
        if (options.indicator) label.appendChild(indicator);
        setClass(label, this.prefix + "-dropdown-icon", true);
      } else {
        label = crelt("span", {
          class: this.prefix + "-dropdown",
          style: this.options.css
        });
        label.appendChild(crelt("span", this.options.label));
        label.appendChild(indicator);
      }
      if (this.options.title)
        label.setAttribute("title", translate(view, this.options.title));
      if (this.options.labelClass)
        label.classList.add(this.options.labelClass);
      let iconWrapClass = this.options.indicator ? "-dropdown-icon-wrap" : "-dropdown-icon-wrap-noindicator";
      let wrapClass = (this.options.icon) ? this.prefix + iconWrapClass : this.prefix + "-dropdown-wrap";
      let wrap = crelt("span", { class: wrapClass }, label);
      let open = null;
      let listeningOnClose = null;
      let close = () => {
        if (open && open.close()) {
          open = null;
          win.removeEventListener("mousedown", listeningOnClose);
        }
      };
      label.addEventListener("mousedown", e => {
        e.preventDefault();
        markMenuEvent(e);
        if (open) {
          close();
        }
        else {
          open = this.expand(wrap, content.dom);
          win.addEventListener("mousedown", listeningOnClose = () => {
            if (!isMenuEvent(wrap))
              close();
          });
        }
      });

      function update(state) {
        if (options.enable) {
          let enabled = options.enable(state) || false;
          setClass(label, this.prefix + "-disabled", !enabled);
        }
        if (options.titleUpdate) {
          let newTitle = options.titleUpdate(state);
          label.replaceChild(document.createTextNode(newTitle), label.firstChild);
        }
        let inner = content.update(state);
        wrap.style.display = inner ? "" : "none";
        return inner;
      }
      return { dom: wrap, update };
    }

    expand(dom, items) {
      let menuDOM = crelt("div", { class: this.prefix + "-dropdown-menu" + (this.options.class || "") }, items);
      let done = false;
      function close() {
        if (done)
          return false;
        done = true;
        dom.removeChild(menuDOM);
        return true;
      }
      dom.appendChild(menuDOM);
      return { close, node: menuDOM };
    }
  }

  /**
  Represents a submenu wrapping a group of elements that start
  hidden and expand to the right when hovered over or tapped.
  */
  class DropdownSubmenu {

    /**
    Creates a submenu for the given group of menu elements. The
    following options are recognized:
    */
    constructor(content, options = {}) {
      this.prefix = prefix + "-menu";
      this.options = options;
      this.content = Array.isArray(content) ? content : [content];
    }

    /**
    Renders the submenu.
    */
    render(view) {
      let options = this.options;
      let items = renderDropdownItems(this.content, view);
      let win = view.dom.ownerDocument.defaultView || window;
      let label = crelt("div", { class: this.prefix + "-submenu-label" }, translate(view, this.options.label || ""));
      let wrap = crelt("div", { class: this.prefix + "-submenu-wrap" }, label, crelt("div", { class: this.prefix + "-submenu" }, items.dom));
      let listeningOnClose = null;
      label.addEventListener("mousedown", e => {
        e.preventDefault();
        markMenuEvent(e);
        setClass(wrap, this.prefix + "-submenu-wrap-active", false);
        if (!listeningOnClose)
          win.addEventListener("mousedown", listeningOnClose = () => {
            if (!isMenuEvent(wrap)) {
              wrap.classList.remove(this.prefix + "-submenu-wrap-active");
              win.removeEventListener("mousedown", listeningOnClose);
              listeningOnClose = null;
            }
          });
      });
      function update(state) {
        let enabled = true;
        if (options.enable) {
          enabled = options.enable(state) || false;
          setClass(label, this.prefix + "-disabled", !enabled);
        }
        let inner = items.update(state);
        wrap.style.display = inner ? "" : "none";
        return inner;
      }
      return { dom: wrap, update };
    }
  }

  class ParagraphStyleItem {

    constructor(nodeType, style, options) {
      this.style = style;
      this.label = options["label"] ?? "Unknown";  // It should always be specified
      this.keymap = options["keymap"];             // It may or may not exist
      this.item = this.paragraphStyleItem(nodeType, style, options);
    }

    paragraphStyleItem(nodeType, style, options) {
      let command = setStyleCommand(style);
      let passedOptions = {
          run: command,
          enable(state) { return command(state) },
          active(state) {
              let { $from, to, node } = state.selection;
              if (node)
                  return node.hasMarkup(nodeType, options.attrs);
              return to <= $from.end() && $from.parent.hasMarkup(nodeType, options.attrs);
          }
      };
      for (let prop in options)
          passedOptions[prop] = options[prop];
      return new MenuItem(passedOptions);
    }

    render(view) {
      let {dom, update} = this.item.render(view);
      let keymapElement = crelt ('span', {class: prefix + '-stylelabel-keymap'}, this.keymap);
      // Add some space between the label and keymap, css uses whitespace: pre to preserve it
      let styledElement = crelt(this.style, {class: prefix + '-stylelabel'}, this.label + '  ', keymapElement);
      dom.replaceChild(styledElement, dom.firstChild);
      return {dom, update}
    }
  }

  /**
   * DialogItem provides common functionality for MenuItems that present dialogs next to 
   * a selection, such as LinkItem and ImageItem. The shared functionality mainly deals 
   * with opening, closing, and positioning the dialog so it stays in view as much as possible.
   * Each of the subclasses defines its `dialogWidth` and `dialogHeight` and deals with its 
   * own content/layout.
   */
  class DialogItem {

      constructor(config) {
          this.config = config;
          this.dialog = null;
          this.selectionDiv = null;
          this.selectionDivRect = null;
      }

      /**
       * Command to open the link dialog and show it modally.
       *
       * @param {EditorState} state 
       * @param {fn(tr: Transaction)} dispatch 
       * @param {EditorView} view 
       */
      openDialog(state, dispatch, view) {
          this.createDialog(view);
          this.dialog.show();
      }

      /**
       * Create and append a div that encloses the selection, with a class that displays it properly.
       */
      setSelectionDiv() {
          this.selectionDiv = crelt('div', { id: prefix + '-selection', class: prefix + '-selection' });
          this.selectionDiv.style.top = this.selectionDivRect.top + 'px';
          this.selectionDiv.style.left = this.selectionDivRect.left + 'px';
          this.selectionDiv.style.width = this.selectionDivRect.width + 'px';
          this.selectionDiv.style.height = this.selectionDivRect.height + 'px';
          getWrapper().appendChild(this.selectionDiv);
      }

      /**
       * Return an object with location and dimension properties for the selection rectangle.
       * @returns {Object}  The {top, left, right, width, height, bottom} of the selection.
       */
      getSelectionDivRect() {
          let wrapper = view.dom.parentElement;
          let originY = wrapper.getBoundingClientRect().top;
          let originX = wrapper.getBoundingClientRect().left;
          let scrollY = wrapper.scrollTop;   // The editor scrolls within its wrapper
          let scrollX = window.scrollX;      // The editor doesn't scroll horizontally
          let selrect = getSelectionRect();
          let top = selrect.top + scrollY - originY;
          let left = selrect.left + scrollX - originX;
          let right = selrect.right;
          let width = selrect.right - selrect.left;
          let height = selrect.bottom - selrect.top;
          let bottom = selrect.bottom;
          return { top: top, left: left, right: right, width: width, height: height, bottom: bottom }
      }

      /**
       * Set the `dialog` location on the screen so it is adjacent to the selection.
       */
      setDialogLocation() {
          let dialogHeight = this.dialogHeight;
          let dialogWidth = this.dialogWidth;

          // selRect is the position within the document. So, doesn't change even if the document is scrolled.
          let selrect = this.selectionDivRect;

          // The dialog needs to be positioned within the document regardless of scroll, too, but the position is
          // set based on the direction from selrect that has the most screen real-estate. We always prefer right 
          // or left of the selection if we can fit it in the visible area on either side. We can bias it as 
          // close as we can to the vertical center. If we can't fit it right or left, then we will put it above
          // or below, whichever fits, biasing alignment as close as we can to the horizontal center.
          // Generally speaking, the selection itself is on the screen, so we want the dialog to be adjacent to 
          // it with the best chance of showing the entire dialog.
          let wrapper = view.dom.parentElement;
          let originX = wrapper.getBoundingClientRect().left;
          let scrollY = wrapper.scrollTop;   // The editor scrolls within its wrapper
          let scrollX = window.scrollX;      // The editor doesn't scroll horizontally
          let style = this.dialog.style;
          let toolbarHeight = getToolbar().getBoundingClientRect().height;
          let minTop = toolbarHeight + scrollY + 4;
          let maxTop = scrollY + innerHeight - dialogHeight - 4;
          let minLeft = scrollX + 4;
          let maxLeft = innerWidth - dialogWidth - 4;
          let fitsRight = window.innerWidth - selrect.right - scrollX > dialogWidth + 4;
          let fitsLeft = selrect.left - scrollX > dialogWidth + 4;
          let fitsTop = selrect.top - scrollY - toolbarHeight > dialogHeight + 4;
          if (fitsRight) {           // Put dialog right of selection
              style.left = selrect.right + 4 + scrollX - originX + 'px';
              style.top = Math.min(Math.max((selrect.top + (selrect.height / 2) - (dialogHeight / 2)), minTop), maxTop) + 'px';
          } else if (fitsLeft) {     // Put dialog left of selection
              style.left = selrect.left - dialogWidth - 4 + scrollX - originX + 'px';
              style.top = Math.min(Math.max((selrect.top + (selrect.height / 2) - (dialogHeight / 2)), minTop), maxTop) + 'px';
          } else if (fitsTop) {     // Put dialog above selection
              style.left = Math.min(Math.max((selrect.left + (selrect.width / 2) - (dialogWidth / 2)), minLeft), maxLeft) + 'px';
              style.top = Math.min(Math.max((selrect.top - dialogHeight - 4), minTop), maxTop) + 'px';
          } else {                                          // Put dialog below selection, even if it's off the screen somewhat
              style.left = Math.min(Math.max((selrect.left + (selrect.width / 2) - (dialogWidth / 2)), minLeft), maxLeft) + 'px';
              style.top = Math.min((selrect.bottom + 4), maxTop) + 'px';
          }
      }

      /**
       * Close the dialog, deleting the dialog and selectionDiv and clearing out state.
       */
      closeDialog() {
          removePromptShowing();
          this.toolbarOverlay?.parentElement?.removeChild(this.toolbarOverlay);
          this.overlay?.parentElement?.removeChild(this.overlay);
          this.selectionDiv?.parentElement?.removeChild(this.selectionDiv);
          this.selectionDiv = null;
          this.dialog?.close();
          this.dialog?.parentElement?.removeChild(this.dialog);
          this.dialog = null;
          this.okUpdate = null;
          this.cancelUpdate = null;
      }

      /**
       * Show the MenuItem that LinkItem holds in its `item` property.
       * @param {EditorView} view 
       * @returns {Object}    The {dom, update} object for `item`.
       */
      render(view) {
          return this.item.render(view);
      }

  }

  /**
   * Represents the link MenuItem in the toolbar, which opens the link dialog and maintains its state.
   */
  class LinkItem extends DialogItem {

    constructor(config) {
      super(config);
      let keymap = this.config.keymap;
      let options = {
        enable: () => { return true }, // Always enabled because it is presented modally
        active: (state) => { return markActive(state, state.schema.marks.link) },
        title: 'Insert/edit link' + keyString('link', keymap),
        icon: icons.link
      };

      // If `behavior.insertLink` is true, the LinkItem just invokes the delegate's 
      // `markupInsertLink` method, passing the `state`, `dispatch`, and `view` like any 
      // other command. Otherwise, we use the default dialog.
      if ((this.config.behavior.insertLink) && (this.config.delegate?.markupInsertLink)) {
        this.command = this.config.delegate.markupInsertLink;
      } else {
        this.command = this.openDialog.bind(this);
      }
      this.item = cmdItem(this.command, options);

      // We need the dialogHeight and width because we can only position the dialog top and left. 
      // You would think that an element could be positioned by specifying right and bottom, but 
      // apparently not. Even when width is fixed, specifying right doesn't work. The values below
      // are dependent on toolbar.css for .Markup-prompt-link.
      this.dialogHeight = 104;
      this.dialogWidth = 317;
    }

    /**
     * Create the dialog element for adding/modifying links. Append it to the wrapper after the toolbar.
     * 
     * @param {EditorView} view 
     */
    createDialog(view) {
      this.href = getLinkAttributes().href;   // href is what is linked-to, undefined if there is no link at selection

      // Select the full link if the selection is in one, and then set selectionDivRect that surrounds it
      selectFullLink(view);
      this.selectionDivRect = this.getSelectionDivRect();

      // Show the selection, because the view is not focused, so it doesn't otherwise show up
      this.setSelectionDiv();

      // Create the dialog in the proper position
      this.dialog = crelt('dialog', { class: prefix + '-prompt', contenteditable: 'false' });
      setClass(this.dialog, prefix + '-prompt-link', true);
      this.setDialogLocation();

      let title = crelt('p', (this.href) ? 'Edit link' : 'Insert link');
      this.dialog.appendChild(title);

      this.setInputArea(view);
      this.setButtons(view);
      this.okUpdate(view.state);
      this.cancelUpdate(view.state);
      
      let wrapper = getWrapper();
      addPromptShowing();
      wrapper.appendChild(this.dialog);

      // Add an overlay so we can get a modal effect without using showModal
      // showModal puts the dialog in the top-layer, so it slides over the toolbar 
      // when scrolling and ignores z-order. Good article: https://bitsofco.de/accessible-modal-dialog/.
      // We also have to add a separate toolbarOverlay over the toolbar to prevent interaction with it, 
      // because it sits at a higher z-level than the prompt and overlay.
      this.overlay = crelt('div', {class: prefix + '-prompt-overlay', tabindex: "-1", contenteditable: 'false'});
      this.overlay.addEventListener('click', () => {
        this.closeDialog();
      });
      wrapper.appendChild(this.overlay);

      this.toolbarOverlay = crelt('div', {class: prefix + '-toolbar-overlay', tabindex: "-1", contenteditable: 'false'});
      if (getSearchbar()) {
        setClass(this.toolbarOverlay, searchbarShowing(), true);
      } else {
        setClass(this.toolbarOverlay, searchbarHidden(), true);
      }
      this.toolbarOverlay.addEventListener('click', () => {
        this.closeDialog();
      });
      wrapper.appendChild(this.toolbarOverlay);
    }

    /**
     * Create and add the input element for the URL.
     * 
     * Capture Enter to perform the command of the active button, either OK or Cancel.
     * 
     * @param {*} view 
     */
    setInputArea(view) {
      this.hrefArea = crelt('input', { type: 'text', placeholder: 'Enter url...' });
      this.hrefArea.value = this.href ?? '';
      this.hrefArea.addEventListener('input', () => {
        if (this.isValid()) {
          setClass(this.okDom, 'Markup-menuitem-disabled', false);
        } else {
          setClass(this.okDom, 'Markup-menuitem-disabled', true);
        }      this.okUpdate(view.state);
        this.cancelUpdate(view.state);
      });
      this.hrefArea.addEventListener('keydown', e => {   // Use keydown because 'input' isn't triggered for Enter
        if (e.key === 'Enter') {
          e.preventDefault();
          if (this.isValid()) {
            this.insertLink(view.state, view.dispatch, view);
          } else {
            this.closeDialog();
          }
        } else if (e.key === 'Tab') {
          e.preventDefault();
        } else if (e.key === 'Escape') {
          this.closeDialog();
        }
      });
      this.dialog.appendChild(this.hrefArea);
    }

    /**
     * Create and append the buttons in the `dialog`.
     * 
     * Track the `dom` and `update` properties for the OK and Cancel buttons so we can show when
     * they are active as a way to indicate the default action on Enter in the `hrefArea`.
     * 
     * @param {EditorView} view 
     */
    setButtons(view) {
      let buttonsDiv = crelt('div', { class: prefix + '-prompt-buttons' });
      this.dialog.appendChild(buttonsDiv);

      // Only insert the Remove button if we have a link selected
      if (this.isValid()) {
        let removeItem = cmdItem(this.deleteLink.bind(this), {
          class: prefix + '-menuitem',
          title: 'Remove',
          enable: () => { return true }
        });
        let {dom} = removeItem.render(view);
        buttonsDiv.appendChild(dom);
      }

      // Insert the dropdown to identify local links to headers
      let localRefDropdown = this.getLocalRefDropdown();
      if (localRefDropdown) {
        let {dom: localRefDom} = localRefDropdown.render(view);
        let itemWrapper = crelt('span', {class: prefix + '-menuitem'}, localRefDom);
        buttonsDiv.appendChild(itemWrapper);
      } else {
        let spacer = crelt('div', document.createTextNode('\u200b'));
        buttonsDiv.appendChild(spacer);
      }

      let group = crelt('div', {class: prefix + '-prompt-buttongroup'});
      let okItem = cmdItem(this.insertLink.bind(this), {
        class: prefix + '-menuitem',
        title: 'OK',
        active: () => {
          return this.isValid()
        },
        enable: () => {
          return this.isValid()
        }
      });
      let {dom: okDom, update: okUpdate} = okItem.render(view);
      this.okDom = okDom;
      this.okUpdate = okUpdate;
      group.appendChild(this.okDom);

      let cancelItem = cmdItem(this.closeDialog.bind(this), {
        class: prefix + '-menuitem',
        title: 'Cancel',
        active: () => {
          return !this.isValid()
        },
        enable: () => {
          return true
        }
      });
      let {dom: cancelDom, update: cancelUpdate} = cancelItem.render(view);
      this.cancelDom = cancelDom;
      this.cancelUpdate = cancelUpdate;
      group.appendChild(this.cancelDom);

      buttonsDiv.appendChild(group);
    }

    getLocalRefDropdown() {
      let localRefItems = this.getLocalRefItems();
      if (localRefItems.length == 0) { return null }
      return new Dropdown(localRefItems, {
        title: 'Insert link to header',
        label: 'H1-6'
        // Note: enable doesn't work for Dropdown
      })
    }

    getLocalRefItems() {
      let submenuItems = [];
      let headersByLevel = headers(view.state);
      for (let i = 1; i < 7; i++) {
        let hTag = 'H' + i.toString();
        let menuItems = [];
        let hNodes = headersByLevel[i];
        if (hNodes && hNodes.length > 0) {
          for (let j = 0; j < hNodes.length; j++) {
            // Add a MenuItem that invokes the insertInternalLinkCommand passing the hTag and the index into hElements
            menuItems.push(this.refMenuItem(hTag, j, hNodes[j].node.textContent));
          }
          submenuItems.push(new DropdownSubmenu(
            menuItems, {
            title: 'Link to ' + hTag,
            label: hTag,
            enable: () => { return menuItems.length > 0 }
          }
          ));
        }
      }
      return submenuItems
    }

    // Return a MenuItem with class `prefex + menuitem-clipped` because the text inside of a header is unlimited.
    // The `insertInternalLinkCommand` executes the callback providing a unique id for the header based on its 
    // contents, along with the tag and index into headers with that tag in the document being edited.
    refMenuItem(hTag, index, label) {
      return cmdItem(
        idForInternalLinkCommand(hTag, index), 
        { 
          label: label, 
          class: prefix + '-menuitem-clipped',
          callback: (result) => { 
            if (result) {
              this.hTag = result.hTag;
              this.index = result.index;
              this.id = '#' + result.id;
              this.hrefArea.value = this.id;
              this.okUpdate(view.state);
              this.cancelUpdate(view.state);
            }
          }
        }
      )
    }

    // Return true if `hrefValue()` is a valid ID for a header or if the URL can be parsed.
    // A valid ID begins with # and has no whitespace in it.
    isValid() {
      let href = this.hrefValue();
      return (this.isInternalLink() && (href.indexOf(' ') == -1)) || URL.canParse(href)
    }

    /**
     * Return the string from the `hrefArea`.
     * @returns {string}
     */
    hrefValue() {
      return this.hrefArea.value
    }

    /**
     * Insert the link provided in the hrefArea if it's valid, deleting any existing link first. Close if it worked.
     * 
     * @param {EditorState} state 
     * @param {fn(tr: Transaction)} dispatch 
     * @param {EditorView} view 
     */
    insertLink(state, dispatch, view) {
      if (!this.isValid()) return;
      if (this.href) deleteLinkCommand()(state, dispatch, view);
      let command;
      if (this.isInternalLink()) {
        // It could have been edited, not just inserted by selecting from H1-6
        if (this.hrefValue() == this.id) {
          // Id was set from H1=6 and nothing has changed. So, insert the link
          // based on the hTag and its index into headers with that hTag.
          command = insertInternalLinkCommand(this.hTag, this.index);
        } else {
          // Otherwise, just insert the link to an ID, which may not exist
          command = insertLinkCommand(this.hrefValue());
        }
      } else {
        command = insertLinkCommand(this.hrefValue());
      }
      let result = command(view.state, view.dispatch);
      if (result) this.closeDialog();
    }

    isInternalLink() {
      return this.hrefValue().startsWith('#')
    }

    /**
     * Delete the link at the selection. Close if it worked.
     * 
     * @param {EditorState} state 
     * @param {fn(tr: Transaction)} dispatch 
     * @param {EditorView} view 
     */
    deleteLink(state, dispatch, view) {
      let command = deleteLinkCommand();
      let result = command(state, dispatch, view);
      if (result) this.closeDialog();
    }

  }

  /**
   * Represents the image MenuItem in the toolbar, which opens the image dialog and maintains its state.
   * Requires commands={getImageAttributes, insertImageCommand, modifyImageCommand, getSelectionRect}
   */
  class ImageItem extends DialogItem {

    constructor(config) {
      super(config);
      let options = {
        enable: () => { return true }, // Always enabled because it is presented modally
        active: (state) => { return getImageAttributes(state).src  },
        title: 'Insert/edit image' + keyString('image', config.keymap),
        icon: icons.image
      };

      // If `behavior.insertImage` is true, the ImageItem just invokes the delegate's 
      // `markupInsertImage` method, passing the `state`, `dispatch`, and `view` like any 
      // other command. Otherwise, we use the default dialog.
      if ((config.behavior.insertImage) && (config.delegate?.markupInsertImage)) {
        this.command = config.delegate.markupInsertImage;
      } else {
        this.command = this.openDialog.bind(this);
      }

      this.item = cmdItem(this.command, options);
      this.isValid = false;
      this.preview = null;

      // We need the dialogHeight and width because we can only position the dialog top and left. 
      // You would think that an element could be positioned by specifying right and bottom, but 
      // apparently not. Even when width is fixed, specifying right doesn't work. The values below
      // are dependent on toolbar.css for .Markup-prompt-image.
      this.dialogHeight = 134;
      this.dialogWidth = 317;
    }

    /**
     * Create the dialog element for adding/modifying images. Append it to the wrapper after the toolbar.
     * 
     * @param {EditorView} view 
     */
    createDialog(view) {
      let {src, alt} = getImageAttributes(view.state);
      this.src = src;   // src for the selected image, undefined if there is no image at selection
      this.alt = alt;

      // Set selectionDivRect that surrounds the selection
      this.selectionDivRect = this.getSelectionDivRect();

      // Show the selection, because the view is not focused, so it doesn't otherwise show up
      this.setSelectionDiv();

      // Create the dialog in the proper position
      this.dialog = crelt('dialog', { class: prefix + '-prompt', contenteditable: 'false' });
      setClass(this.dialog, prefix + '-prompt-image', true);
      this.setDialogLocation();

      let title = crelt('p', (this.src) ? 'Edit image' : 'Insert image');
      this.dialog.appendChild(title);

      this.setInputArea(view);
      this.setButtons(view);
      this.updatePreview();

      let wrapper = getWrapper();
      addPromptShowing();
      wrapper.appendChild(this.dialog);

      // Add an overlay so we can get a modal effect without using showModal
      // showModal puts the dialog in the top-laver, so it slides over the toolbar 
      // when scrolling and ignores z-order. Good article: https://bitsofco.de/accessible-modal-dialog/.
      // We also have to add a separate toolbarOverlay over the toolbar to prevent interaction with it, 
      // because it sits at a higher z-level than the prompt and overlay.
      this.overlay = crelt('div', {class: prefix + '-prompt-overlay', tabindex: "-1", contenteditable: 'false'});
      this.overlay.addEventListener('click', () => {
        this.closeDialog();
      });
      wrapper.appendChild(this.overlay);
      this.toolbarOverlay = crelt('div', {class: prefix + '-toolbar-overlay', tabindex: "-1", contenteditable: 'false'});
      if (getSearchbar()) {
        setClass(this.toolbarOverlay, searchbarShowing(), true);
      } else {
        setClass(this.toolbarOverlay, searchbarHidden(), true);
      }
      this.toolbarOverlay.addEventListener('click', () => {
        this.closeDialog();
      });
      wrapper.appendChild(this.toolbarOverlay);
    }

    /**
     * Create and add the input elements.
     * 
     * Capture Enter to perform the command of the active button, either OK or Cancel.
     * 
     * @param {*} view 
     */
    setInputArea(view) {
      this.srcArea = crelt('input', { type: 'text', placeholder: 'Enter url...' });
      this.srcArea.value = this.src ?? '';
      this.srcArea.addEventListener('input', () => {
        // Update the img src as we type, which will cause this.preview to load, which may result in 
        // "Not allowed to load local resource" at every keystroke until the image loads properly.
        this.updatePreview();
      });
      this.srcArea.addEventListener('keydown', e => {   // Use keydown because 'input' isn't triggered for Enter
        if (e.key === 'Enter') {
          e.preventDefault();
          if (this.isValid) {
            this.insertImage(view.state, view.dispatch, view);
          } else {
            this.closeDialog();
          }
        } else if (e.key === 'Tab') {
          e.preventDefault();
          this.altArea.focus();
        } else if (e.key === 'Escape') {
          this.closeDialog();
        }
      });
      this.dialog.appendChild(this.srcArea);

      this.altArea = crelt('input', { type: 'text', placeholder: 'Enter description...' });
      this.altArea.value = this.alt ?? '';
      this.altArea.addEventListener('keydown', e => {   // Use keydown because 'input' isn't triggered for Enter
        if (e.key === 'Enter') {
          e.preventDefault();
          if (this.isValid) {
            this.insertImage(view.state, view.dispatch, view);
          } else {
            this.closeDialog();
          }
        } else if (e.key === 'Tab') {
          e.preventDefault();
          this.srcArea.focus();
        } else if (e.key === 'Escape') {
          this.closeDialog();
        }
      });
      this.dialog.appendChild(this.altArea);
    }

    /**
     * Create and append the buttons in the `dialog`.
     * 
     * Track the `dom` and `update` properties for the OK and Cancel buttons so we can show when
     * they are active as a way to indicate the default action on Enter in the input areas.
     * 
     * @param {EditorView} view 
     */
    setButtons(view) {
      let buttonsDiv = crelt('div', { class: prefix + '-prompt-buttons' });
      this.dialog.appendChild(buttonsDiv);

      // When local images are allowed, we insert a "Select..." button that will bring up a 
      // file chooser. However, the MarkupEditor can't do that itself, so it invokes the 
      // delegate's `markupSelectImage` method if it exists. Thus, when `selectImage` is 
      // true in BehaviorConfig, that method should exist. It should bring up a file chooser
      // and then invoke `MU.insertImage`.
      if (this.config.behavior.selectImage) {
        this.preview = null;
        let selectItem = cmdItem(this.selectImage.bind(this), {
          class: prefix + '-menuitem',
          title: 'Select...',
          active: () => { return false },
          enable: () => { return true }
        });
        let {dom} = selectItem.render(view);
        buttonsDiv.appendChild(dom);
      } else {
        // If there is no Select button, we insert a tiny preview to help.
        this.preview = this.getPreview();
        buttonsDiv.appendChild(this.preview);
      }

      let group = crelt('div', {class: prefix + '-prompt-buttongroup'});
      let okItem = cmdItem(this.insertImage.bind(this), {
        class: prefix + '-menuitem',
        title: 'OK',
        active: () => {
          return this.isValid
        },
        enable: () => {
          // We enable the OK button to allow saving even invalid src values. For example, 
          // maybe you are offline and can't reach a URL or you will later put the image 
          // file into place. However, pressing Enter will result in `closeDialog` being 
          // executed unless the OK button is active; i.e., only if `srcValue()` is valid.
          return this.srcValue().length > 0
        }
      });
      let {dom: okDom, update: okUpdate} = okItem.render(view);
      this.okDom = okDom;
      this.okUpdate = okUpdate;
      group.appendChild(this.okDom);

      let cancelItem = cmdItem(this.closeDialog.bind(this), {
        class: prefix + '-menuitem',
        title: 'Cancel',
        active: () => {
          return !this.isValid
        },
        enable: () => {
          return true
        }
      });
      let {dom: cancelDom, update: cancelUpdate} = cancelItem.render(view);
      this.cancelDom = cancelDom;
      this.cancelUpdate = cancelUpdate;
      group.appendChild(this.cancelDom);

      buttonsDiv.appendChild(group);
    }

    getPreview() {
      let preview = crelt('img');
      preview.style.visibility = 'hidden';
      preview.addEventListener('load', () => {
        this.isValid = true;
        preview.style.visibility = 'visible';
        setClass(this.okDom, 'Markup-menuitem-disabled', false);
        setClass(this.srcArea, 'invalid', false);
        this.okUpdate(view.state);
        this.cancelUpdate(view.state);
      });
      preview.addEventListener('error', () => {
        this.isValid = false;
        preview.style.visibility = 'hidden';
        setClass(this.okDom, 'Markup-menuitem-disabled', true);
        setClass(this.srcArea, 'invalid', true);
        this.okUpdate(view.state);
        this.cancelUpdate(view.state);
      });
      return preview
    }

    updatePreview() {
      if (this.preview) this.preview.src = this.srcValue();
    }

    /**
     * Return the string from the `srcArea`.
     * @returns {string}
     */
    srcValue() {
      return this.srcArea.value
    }

    /**
     * Return the string from the `altArea`.
     * @returns {string}
     */
    altValue() {
      return this.altArea.value
    }

    /** Tell the delegate to select an image to insert, because we don't know how to do that */
    selectImage(state, dispatch, view) {
      this.closeDialog();
      if (this.config.delegate?.markupSelectImage) this.config.delegate?.markupSelectImage(view);
    }

    /**
     * Insert the image provided in the srcArea if it's valid, modifying image if it exists. Close if it worked.
     * Note that the image that is saved might be not exist or be properly formed.
     * 
     * @param {EditorState} state 
     * @param {fn(tr: Transaction)} dispatch 
     * @param {EditorView} view 
     */
    insertImage(state, dispatch, view) {
      let newSrc = this.srcValue();
      let newAlt = this.altValue();
      let command = (this.src) ? modifyImageCommand(newSrc, newAlt) : insertImageCommand(newSrc, newAlt);
      let result = command(view.state, view.dispatch, view);
      if (result) this.closeDialog();
    }

  }

  /**
   * A MenuItem that inserts a table of size rows/cols and invokes `onMouseover` when 
   * the mouse is over it to communicate the size of table it will create when selected.
   */
  class TableInsertItem {

    constructor(rows, cols, onMouseover, options) {
      this.prefix = prefix + "-menuitem";
      this.rows = rows;
      this.cols = cols;
      this.onMouseover = onMouseover;
      this.command = insertTableCommand(this.rows, this.cols);
      this.item = this.tableInsertItem(this.command, options);
    }

    tableInsertItem(command, options) {
      let passedOptions = {
        run: command,
        enable(state) { return command(state); },
      };
      for (let prop in options)
        passedOptions[prop] = options[prop];
      return new MenuItem(passedOptions);
    }

    render(view) {
      let {dom, update} = this.item.render(view);
      dom.addEventListener('mouseover', () => {
        this.onMouseover(this.rows, this.cols);
      });
      return {dom, update}
    }

  }

  /**
    A submenu for creating a table, which contains many TableInsertItems each of which 
    will insert a table of a specific size. The items are bounded divs in a css grid 
    layout that highlight to show the size of the table being created, so we end up with 
    a compact way to display 24 TableInsertItems.
    */
  class TableCreateSubmenu {
    constructor(options = {}) {
      this.prefix = prefix + "-menu";
      this.options = options;
      this.content = [];
      this.maxRows = 6;
      this.maxCols = 4;
      this.rowSize = 0;
      this.colSize = 0;
      for (let row = 0; row < this.maxRows; row++) {
        for (let col = 0; col < this.maxCols; col++) {
          // If we want the MenuItem div to respond to keydown, it needs to contain something, 
          // in this case a non-breaking space. Just ' ' doesn't work.
          let options = {
            label: '\u00A0', 
            active: () => {
              return (row < this.rowSize) && (col < this.colSize)
            }
          };
          let insertItem = new TableInsertItem(row + 1, col + 1, this.onMouseover.bind(this), options);
          this.content.push(insertItem);
        }
      }
    }

    /**
     * Track rowSize and columnSize as we drag over an item in the `sizer`.
     * @param {number} rows 
     * @param {number} cols 
     */
    onMouseover(rows, cols) {
      this.rowSize = rows;
      this.colSize = cols;
      this.itemsUpdate(view.state);
    }

    resetSize() {
      this.rowSize = 0;
      this.colSize = 0;
    }

    /**
    Renders the submenu.
    */
    render(view) {
      let resetSize = this.resetSize.bind(this);
      let options = this.options;
      let items = renderDropdownItems(this.content, view);
      this.itemsUpdate = items.update;  // Track the update method so we can update as the mouse is over items
      let win = view.dom.ownerDocument.defaultView || window;
      let label = crelt("div", { class: this.prefix + "-submenu-label" }, translate(view, this.options.label || ""));
      let sizer = crelt("div", { class: this.prefix + "-tablesizer" }, items.dom);
      let wrap = crelt("div", { class: this.prefix + "-submenu-wrap" }, label, sizer);
      let listeningOnClose = null;
      // Clear the sizer when the mouse moves outside of it
      // It's not enough to just resetSize, because it doesn't clear properly until the 
      // mouse is back over an item.
      sizer.addEventListener("mouseleave", () => {this.onMouseover.bind(this)(0, 0);});
      label.addEventListener("mousedown", e => {
        e.preventDefault();
        markMenuEvent(e);
        setClass(wrap, this.prefix + "-submenu-wrap-active", false);
        if (!listeningOnClose)
          win.addEventListener("mousedown", listeningOnClose = () => {
            if (!isMenuEvent(wrap)) {
              wrap.classList.remove(this.prefix + "-submenu-wrap-active");
              win.removeEventListener("mousedown", listeningOnClose);
              listeningOnClose = null;
            }
          });
      });
      function update(state) {
        resetSize();
        let enabled = true;
        if (options.enable) {
          enabled = options.enable(state) || false;
          setClass(label, this.prefix + "-disabled", !enabled);
        }
        let inner = items.update(state);
        wrap.style.display = inner ? "" : "none";
        return inner;
      }
      return { dom: wrap, update };
    }

  }

  /**
   * Represents the search MenuItem in the toolbar, which hides/shows the search bar and maintains its state.
   */
  class SearchItem {

    constructor(config) {
      let keymap = config.keymap;
      let options = {
        enable: () => { return true },
        active: () => { return this.showing() },
        title: 'Toggle search' + keyString('search', keymap),
        icon: icons.search,
        id: prefix + '-searchitem'
      };
      this.command = this.toggleSearch.bind(this);
      this.item = cmdItem(this.command, options);
      this.text = '';
      this.caseSensitive = false;
    }

    showing() {
      return getSearchbar() != null;
    }

    toggleSearch(state, dispatch, view) {
      if (this.showing()) {
        this.hideSearchbar();
      } else {
        this.showSearchbar(state, dispatch, view);
      }
      this.update && this.update(state);
    }

    hideSearchbar() {
      let searchbar = getSearchbar();
      searchbar.parentElement.removeChild(searchbar);
      this.matchCaseDom = null;
      this.matchCaseItem = null;
      this.stopSearching();
    }

    stopSearching(focus=true) {
      cancelSearch();
      this.setStatus();
      if (focus) view.focus();
    }

    showSearchbar(state, dispatch, view) {
      let toolbar = getToolbar();
      if (!toolbar) return;
      let input = crelt('input', { type: 'search', placeholder: 'Search document...' });
      input.addEventListener('keydown', e => {   // Use keydown because 'input' isn't triggered for Enter
        if (e.key === 'Enter') {
          let direction = (e.shiftKey) ? 'backward' : 'forward';
          if (direction == 'forward') {
            this.searchForwardCommand(view.state, view.dispatch, view);
          } else {
            this.searchBackwardCommand(view.state, view.dispatch, view);
          }
        }
      });
      input.addEventListener('input', e => {    // Use input so e.target.value contains what was typed
        this.text = e.target.value;
        this.stopSearching(false);              // Stop searching but leave focus in the input field
      });
      let idClass = prefix + "-searchbar";
      let searchbar = crelt("div", { class: idClass, id: idClass }, input);
      this.addSearchButtons(view, searchbar);
      let beforeTarget = getToolbarMore() ? getToolbarMore().nextSibling : toolbar.nextSibling;
      toolbar.parentElement.insertBefore(searchbar, beforeTarget);
    }

    setStatus() {
      let count = matchCount();
      let index = matchIndex();
      if (this.status) this.status.innerHTML = this.statusString(count, index);
    }

    statusString(count, index) {
      if (count == null) {
        return "";
      } else if (count == 0) {
        return "No matches";
      }    return `${index}/${count}`;
    }

    addSearchButtons(view, searchbar) {
      
      // Overlay the status (index/count) on the input field
      this.status = crelt("span", {class: prefix + "-searchbar-status"});

      // The searchBackward and searchForward buttons don't need updating
      let searchBackward = this.searchBackwardCommand.bind(this);
      let searchBackwardItem = cmdItem(searchBackward, {title: "Search backward", icon: icons.searchBackward});
      let searchBackwardDom = searchBackwardItem.render(view).dom;
      let searchBackwardSpan = crelt("span", {class: prefix + "-menuitem"}, searchBackwardDom);
      let searchForward = this.searchForwardCommand.bind(this);
      let searchForwardItem = cmdItem(searchForward, {title: "Search forward", icon: icons.searchForward});
      let searchForwardDom = searchForwardItem.render(view).dom;
      let searchForwardSpan = crelt("span", {class: prefix + "-menuitem"}, searchForwardDom);
      let separator = crelt("span", {class: prefix + "-menuseparator"});

      // The toggleCase button needs to indicate the state of `caseSensitive`. Because the MenuItems we use 
      // in the SearchBar are not in a separate Plugin, and they are not part of the toolbar content, 
      // we need to handle updating "manually" by tracking and replacing the MenuItem and the dom it 
      // produces using its `render` method.
      let toggleMatchCase = this.toggleMatchCaseCommand.bind(this);
      this.matchCaseItem = cmdItem(
        toggleMatchCase, {
          title: "Match case", 
          icon: icons.matchCase,
          enable: () => {return true},
          active: () => {return this.caseSensitive}
        }
      );
      let {dom, update} = this.matchCaseItem.render(view);
      this.matchCaseDom = dom;
      let matchCaseSpan = crelt("span", {class: prefix + "-menuitem"}, this.matchCaseDom);

      // Add the divs holding the MenuItems
      searchbar.appendChild(this.status);
      searchbar.appendChild(searchBackwardSpan);
      searchbar.appendChild(searchForwardSpan);
      searchbar.appendChild(separator);
      searchbar.appendChild(matchCaseSpan);

      // Then update the matchCaseItem to indicate the current setting, which is held in this 
      // SearchItem.
      update(view.state);
    }

    searchForwardCommand(state, dispatch, view) {
      let command = searchForCommand(this.text, "forward");
      command(state, dispatch, view);
      this.scrollToSelection(view);
      this.setStatus();
    }

    searchBackwardCommand(state, dispatch, view) {
      let command = searchForCommand(this.text, "backward");
      command(state, dispatch, view);
      this.scrollToSelection(view);
      this.setStatus();
    }

    toggleMatchCaseCommand(state, dispatch, view) {
      this.caseSensitive = !this.caseSensitive;
      matchCase(this.caseSensitive);
      if (view) {
        this.stopSearching(false);
        let {dom, update} = this.matchCaseItem.render(view);
        this.matchCaseDom.parentElement.replaceChild(dom, this.matchCaseDom);
        this.matchCaseDom = dom;
        update(state);
      }
    }
    
    /**
     * Use the dom to scroll to the node at the selection. The scrollIntoView when setting the 
     * selection in prosemirror-search findCommand doesn't work, perhaps because the selection 
     * is set on state.doc instead of state.tr.doc. 
     * 
     * TODO: This method has some problems in that it can
     * scroll to a paragraph, and then the next element will be in a bold section within the 
     * paragraph, causing it to jump. It would be much better if the prosemirror-search 
     * scrollIntoView worked properly.
     * 
     * @param {EditorView} view 
     */
    scrollToSelection(view) {
      const { node } = view.domAtPos(view.state.selection.anchor);
      // In case node is a Node not an Element
      let element = (node instanceof Element) ? node : node.parentElement;
      element?.scrollIntoView(false);
    }

    render(view) {
      let {dom, update} = this.item.render(view);
      this.update = update;
      return {dom, update};
    }

  }

  /** A special item for showing a "more" button in the toolbar, which shows its `items` as a sub-toolbar */
  class MoreItem {

    constructor(items) {
      let options = {
        enable: () => { return true },
        active: () => { return this.showing() },
        title: 'Show more',
        icon: icons.more
      };
      this.command = this.toggleMore.bind(this);
      this.item = cmdItem(this.command, options);
      this.items = items;
    }

    showing() {
      return getToolbarMore() != null;
    }

    toggleMore(state, dispatch, view) {
      if (this.showing()) {
        this.hideMore();
      } else {
        this.showMore(state, dispatch, view);
      }
      this.update && this.update(state);
    }

    hideMore() {
      let toolbarMore = getToolbarMore();
      toolbarMore.parentElement.removeChild(toolbarMore);
    }

    showMore(state, dispatch, view) {
      let toolbar = getToolbar();
      if (!toolbar) return;
      let idClass = prefix + "-toolbar-more";
      let toolbarMore = crelt('div', { class: idClass, id: idClass } );
      let {dom, update} = renderGrouped(view, [this.items]);
      toolbarMore.appendChild(dom);
      toolbar.parentElement.insertBefore(toolbarMore, toolbar.nextSibling);
      // Then update the moreItem to show it's active
      update(view.state);
    }

    render(view) {
      let {dom, update} = this.item.render(view);
      this.update = update;
      return {dom, update};
    }

  }

  /**
   * Return a MenuItem that runs the command when selected.
   * 
   * The label is the same as the title, and the MenuItem will be enabled/disabled based on 
   * what `cmd(state)` returns unless otherwise specified in `options`.
   * @param {Command}     cmd 
   * @param {*} options   The spec for the MenuItem
   * @returns {MenuItem}
   */
  function cmdItem(cmd, options) {
    let passedOptions = {
      label: options.title,
      run: cmd
    };
    for (let prop in options) passedOptions[prop] = options[prop];
    if ((!options.enable || options.enable === true) && !options.select)
      passedOptions[options.enable ? "enable" : "select"] = state => cmd(state);

    return new MenuItem(passedOptions)
  }

  /** Return a span for a separator between groups of MenuItems */
  function separator() {
      return crelt("span", { class: prefix + "-menuseparator" });
  }

  /**
   * Return whether the selection in state is within a mark of type `markType`.
   * @param {EditorState} state 
   * @param {MarkType} type 
   * @returns {boolean} True if the selection is within a mark of type `markType`
   */
  function markActive(state, type) {
    let { from, $from, to, empty } = state.selection;
    if (empty) return type.isInSet(state.storedMarks || $from.marks())
    else return state.doc.rangeHasMark(from, to, type)
  }

  /**
   * Return a string intended for the user to see showing the first key mapping for `itemName`.
   * @param {string} itemName           The name of the item in the keymap
   * @param {[string : string]} keymap  The mapping between item names and hotkeys
   * @returns string
   */
  function keyString(itemName, keymap) {
    return ' (' + baseKeyString(itemName, keymap) + ')'
  }

  function baseKeyString(itemName, keymap) {
    let keyString = keymap[itemName];
    if (!keyString) return ''
    if (keyString instanceof Array) keyString = keyString[0];  // Use the first if there are multiple
    // Clean up to something more understandable
    keyString = keyString.replaceAll('Mod', 'Cmd');
    keyString = keyString.replaceAll('Cmd', '\u2318');     // ⌘
    keyString = keyString.replaceAll('Ctrl', '\u2303');    // ⌃
    keyString = keyString.replaceAll('Shift', '\u21E7');   // ⇧
    keyString = keyString.replaceAll('Alt', '\u2325');     // ⌥
    keyString = keyString.replaceAll('-', '');
    return keyString
  }

  function renderGrouped(view, content) {
      let result = document.createDocumentFragment();
      let updates = [], separators = [];
      for (let i = 0; i < content.length; i++) {
          let items = content[i], localUpdates = [], localNodes = [];
          for (let j = 0; j < items.length; j++) {
              let { dom, update } = items[j].render(view);
              let span = crelt("span", { class: prefix + "-menuitem" }, dom);
              result.appendChild(span);
              localNodes.push(span);
              localUpdates.push(update);
          }
          if (localUpdates.length) {
              updates.push(combineUpdates(localUpdates, localNodes));
              if (i < content.length - 1)
                  separators.push(result.appendChild(separator()));
          }
      }
      function update(state) {
          let something = false, needSep = false;
          for (let i = 0; i < updates.length; i++) {
              let hasContent = updates[i](state);
              if (i)
                  separators[i - 1].style.display = needSep && hasContent ? "" : "none";
              needSep = hasContent;
              if (hasContent)
                  something = true;
          }
          return something;
      }
      return { dom: result, update };
  }

  /**
   * Like `renderGrouped`, but at `wrapIndex` in the `content`, place a `MoreItem` that 
   * will display a subtoolbar of `content` items starting at `wrapIndex` when it is 
   * pressed. The `MoreItem` renders using `renderGrouped`, not `renderGroupedFit`. Let's 
   * face it, if you need to wrap a toolbar into more than two lines, you need to think
   * through your life choices.
   * 
   * @param {EditorView} view 
   * @param {[MenuItem | [MenuItem]]} content 
   * @param {number}  wrapAtIndex             The index in  content` to wrap in another toolbar
   * @returns 
   */
  function renderGroupedFit(view, content, wrapAtIndex) {
    let result = document.createDocumentFragment();
    let updates = [], separators = [];
    let itemIndex = 0;
    let moreItems = [];
    for (let i = 0; i < content.length; i++) {
      let items = content[i], localUpdates = [], localNodes = [];
      for (let j = 0; j < items.length; j++) {
        if (itemIndex >= wrapAtIndex) {
          // Track the items to be later rendered in the "more" dropdown
          moreItems.push(items[j]);
        } else {
          let { dom, update } = items[j].render(view);
          let span = crelt("span", { class: prefix + "-menuitem" }, dom);
          result.appendChild(span);
          localNodes.push(span);
          localUpdates.push(update);
        }
        itemIndex++;
      }
      if (localUpdates.length) {
        updates.push(combineUpdates(localUpdates, localNodes));
        if (i < content.length - 1)
          separators.push(result.appendChild(separator()));
      }
    }
    if (moreItems.length > 0) {
      let more = new MoreItem(moreItems);
      let {dom, update} = more.render(view);
      let span = crelt("span", { class: prefix + "-menuitem" }, dom);
      result.appendChild(span);
      updates.push(update);
    }
    function update(state) {
      let something = false, needSep = false;
      for (let i = 0; i < updates.length; i++) {
        let hasContent = updates[i](state);
        if (i)
          separators[i - 1].style.display = needSep && hasContent ? "" : "none";
        needSep = hasContent;
        if (hasContent)
          something = true;
      }
      return something;
    }
    return { dom: result, update };
  }

  function renderDropdownItems(items, view) {
      let rendered = [], updates = [];
      for (let i = 0; i < items.length; i++) {
          let { dom, update } = items[i].render(view);
          rendered.push(crelt("div", { class: prefix + "-menu-dropdown-item" }, dom));
          updates.push(update);
      }    return { dom: rendered, update: combineUpdates(updates, rendered) };
  }

  function combineUpdates(updates, nodes) {
      return (state) => {
          let something = false;
          for (let i = 0; i < updates.length; i++) {
              let up = updates[i](state);
              nodes[i].style.display = up ? "" : "none";
              if (up)
                  something = true;
          }
          return something;
      };
  }

  let lastMenuEvent = { time: 0, node: null };

  function markMenuEvent(e) {
      lastMenuEvent.time = Date.now();
      lastMenuEvent.node = e.target;
  }

  function isMenuEvent(wrapper) {
      return Date.now() - 100 < lastMenuEvent.time &&
          lastMenuEvent.node && wrapper.contains(lastMenuEvent.node);
  }

  /**
   * Adapted, expanded, and copied-from prosemirror-menu under MIT license.
   * Original prosemirror-menu at https://github.com/prosemirror/prosemirror-menu.
   * 
   * Adaptations:
   *  - Modify buildMenuItems to use a `config` object that specifies visibility and content
   *  - Use separate buildKeymap in keymap.js with a `config` object that specifies key mappings
   *  - Modify icons to use SVG from Google Material Fonts
   *  - Allow Dropdown menus to be icons, not just labels
   *  - Replace use of prompt with custom dialogs for links and images
   * 
   * Expansions:
   *  - Added table support using MarkupEditor capabilities for table editing
   *  - Use MarkupEditor capabilities for list/denting across range
   *  - Use MarkupEditor capability for toggling and changing list types
   *  - Added SearchItem, LinkItem, ImageItem
   *  - Added TableCreateSubmenu and TableInsertItem in support of table creation
   *  - Added ParagraphStyleItem to support showing font sizes for supported styles
   * 
   * Copied:
   *  - MenuItem
   *  - Dropdown
   *  - DropdownSubmenu
   *  - Various "helper methods" returning MenuItems
   */


  /**
   * Build an array of MenuItems and nested MenuItems that comprise the content of the Toolbar 
   * based on the `config` and `schema`.
   * 
   * This is the first entry point for menu that is called from `setup/index.js', returning the 
   * contents that `renderGrouped` can display. It also sets the prefix used locally.
   * 
   * @param {string}  basePrefix      The prefix used when building style strings, "Markup" by default.
   * @param {Object}  config          The MarkupEditor.config.
   * @param {Schema}  schema          The schema that holds node and mark types.
   * @returns [MenuItem]              The array of MenuItems or nested MenuItems used by `renderGrouped`.
   */
  function buildMenuItems(config, schema) {
    let itemGroups = [];
    let ordering = config.toolbar.ordering;
    let { correctionBar, insertBar, formatBar, styleMenu, styleBar, search } = config.toolbar.visibility;
    if (correctionBar) {
      itemGroups.push({item: correctionBarItems(config), order: ordering.correctionBar});
    }
    if (insertBar) {
      itemGroups.push({item: insertBarItems(config), order: ordering.insertBar});
    }
    if (styleMenu) {
      itemGroups.push({item: styleMenuItems(config, schema), order: ordering.styleMenu});
    }
    if (styleBar) {
      itemGroups.push({item: styleBarItems(config, schema), order: ordering.styleBar});
    }
    if (formatBar) {
      itemGroups.push({item: formatItems(config, schema), order: ordering.formatBar});
    }
    if (search) {
      itemGroups.push({item: [new SearchItem(config)], order: ordering.search});
    }
    itemGroups.sort((a, b) => a.order - b.order);
    return itemGroups.map((ordered) => ordered.item)
  }

  /* Correction Bar (Undo, Redo) */

  function correctionBarItems(config) {
    let keymap = config.keymap;
    let items = [];
    items.push(undoItem({ title: 'Undo' + keyString('undo', keymap), icon: icons.undo }));
    items.push(redoItem({ title: 'Redo' + keyString('redo', keymap), icon: icons.redo }));
    return items;
  }

  function undoItem(options) {
    let passedOptions = {
      enable: (state) => undoCommand()(state)
    };
    for (let prop in options)
      passedOptions[prop] = options[prop];
    return cmdItem(undoCommand(), passedOptions)
  }

  function redoItem(options) {
    let passedOptions = {
      enable: (state) => redoCommand()(state)
    };
    for (let prop in options)
      passedOptions[prop] = options[prop];
    return cmdItem(redoCommand(), passedOptions)
  }

  /* Insert Bar (Link, Image, Table) */

  /**
   * Return the MenuItems for the style bar, as specified in `config`.
   * @param {Object} config The config object with booleans indicating whether list and denting items are included
   * @returns {[MenuItem]}  An array or MenuItems to be shown in the style bar
   */
  function insertBarItems(config) {
    let items = [];
    let { link, image, tableMenu } = config.toolbar.insertBar;
    if (link) {
      items.push(new LinkItem(config));
    }
    if (image) {
      let imageCommands = {getImageAttributes, insertImageCommand, modifyImageCommand, getSelectionRect};
      items.push(new ImageItem(config, imageCommands));
    }
    if (tableMenu) items.push(tableMenuItems(config));
    return items;
  }

  function tableMenuItems(config) {
    let items = [];
    let { header, border } = config.toolbar.tableMenu;
    items.push(new TableCreateSubmenu({title: 'Insert table', label: 'Insert'}));
    let addItems = [];
    addItems.push(tableEditItem(addRowCommand('BEFORE'), {label: 'Row above'}));
    addItems.push(tableEditItem(addRowCommand('AFTER'), {label: 'Row below'}));
    addItems.push(tableEditItem(addColCommand('BEFORE'), {label: 'Column before'}));
    addItems.push(tableEditItem(addColCommand('AFTER'), {label: 'Column after'}));
    if (header) addItems.push(
      tableEditItem(
        addHeaderCommand(), {
          label: 'Header',
          enable: (state) => { return isTableSelected(state) && !tableHasHeader(state) },
        }));
    items.push(new DropdownSubmenu(
      addItems, {
        title: 'Add row/column', 
        label: 'Add',
        enable: (state) => { return isTableSelected(state) }
      }));
    let deleteItems = [];
    deleteItems.push(tableEditItem(deleteTableAreaCommand('ROW'), {label: 'Row'}));
    deleteItems.push(tableEditItem(deleteTableAreaCommand('COL'), {label: 'Column'}));
    deleteItems.push(tableEditItem(deleteTableAreaCommand('TABLE'), {label: 'Table'}));
    items.push(new DropdownSubmenu(
      deleteItems, {
        title: 'Delete row/column', 
        label: 'Delete',
        enable: (state) => { return isTableSelected(state) }
      }));
    if (border) {
      let borderItems = [];
      borderItems.push(tableBorderItem(setBorderCommand('cell'), {label: 'All'}));
      borderItems.push(tableBorderItem(setBorderCommand('outer'), {label: 'Outer'}));
      borderItems.push(tableBorderItem(setBorderCommand('header'), {label: 'Header'}));
      borderItems.push(tableBorderItem(setBorderCommand('none'), {label: 'None'}));
      items.push(new DropdownSubmenu(
        borderItems, {
          title: 'Set border', 
          label: 'Border',
          enable: (state) => { return isTableSelected(state) }
        }));
    }
    return new Dropdown(items, { title: 'Insert/edit table', icon: icons.table })
  }

  function tableEditItem(command, options) {
    let passedOptions = {
      run: command,
      enable(state) { return command(state); },
      active() { return false }  // FIX
    };
    for (let prop in options)
      passedOptions[prop] = options[prop];
    return new MenuItem(passedOptions);
  }

  function tableBorderItem(command, options) {
    let passedOptions = {
      run: command,
      enable(state) { return command(state); },
      active() { return false }  // FIX
    };
    for (let prop in options)
      passedOptions[prop] = options[prop];
    return new MenuItem(passedOptions);
  }

  /* Style Bar (List, Indent, Outdent) */

  /**
   * Return the MenuItems for the style bar, as specified in `config`.
   * @param {Object} config The config object with booleans indicating whether list and denting items are included
   * @param {Schema} schema 
   * @returns {[MenuItem]}  An array or MenuItems to be shown in the style bar
   */
  function styleBarItems(config, schema) {
    let keymap = config.keymap;
    let items = [];
    let { list, dent } = config.toolbar.styleBar;
    if (list) {
      let bullet = toggleListItem(
        schema,
        schema.nodes.bullet_list,
        { title: 'Toggle bulleted list' + keyString('bullet', keymap), icon: icons.bulletList }
      );
      let number = toggleListItem(
        schema,
        schema.nodes.ordered_list,
        { title: 'Toggle numbered list' + keyString('number', keymap), icon: icons.orderedList }
      );
      items.push(bullet);
      items.push(number);
    }
    if (dent) {
      let indent = indentItem({ title: 'Increase indent' + keyString('indent', keymap), icon: icons.blockquote });
      let outdent = outdentItem({ title: 'Decrease indent' + keyString('outdent', keymap), icon: icons.lift });
      items.push(indent);
      items.push(outdent);
    }
    return items;
  }

  function toggleListItem(schema, nodeType, options) {
    let passedOptions = {
      active: (state) => { return listActive(state, nodeType) },
      enable: true
    };
    for (let prop in options) passedOptions[prop] = options[prop];
    return cmdItem(wrapInListCommand(schema, nodeType), passedOptions)
  }

  function listActive(state, nodeType) {
    let listType = getListType(state);
    return listType === listTypeFor(nodeType, state.schema)
  }

  function indentItem(options) {
    let passedOptions = {
      active: (state) => { return isIndented(state) },
      enable: true
    };
    for (let prop in options) passedOptions[prop] = options[prop];
    return cmdItem(indentCommand(), passedOptions)
  }

  function outdentItem(options) {
    let passedOptions = {
      active: (state) => { return isIndented(state) },
      enable: true
    };
    for (let prop in options) passedOptions[prop] = options[prop];
    return cmdItem(outdentCommand(), passedOptions)
  }

  /* Format Bar (B, I, U, etc) */

  /**
   * Return the array of formatting MenuItems that should show per the config.
   * 
   * @param {Object} config   The MarkupEditor.config with boolean values in config.toolbar.formatBar.
   * @returns [MenuItem]      The array of MenuItems that show as passed in `config`
   */
  function formatItems(config, schema) {
    let keymap = config.keymap;
    let items = [];
    let { bold, italic, underline, code, strikethrough, subscript, superscript } = config.toolbar.formatBar;
    if (bold) items.push(formatItem(schema.marks.strong, 'B', { title: 'Toggle bold' + keyString('bold', keymap), icon: icons.strong }));
    if (italic) items.push(formatItem(schema.marks.em, 'I', { title: 'Toggle italic' + keyString('italic', keymap), icon: icons.em }));
    if (underline) items.push(formatItem(schema.marks.u, 'U', { title: 'Toggle underline' + keyString('underline', keymap), icon: icons.u }));
    if (code) items.push(formatItem(schema.marks.code, 'CODE', { title: 'Toggle code' + keyString('code', keymap), icon: icons.code }));
    if (strikethrough) items.push(formatItem(schema.marks.s, 'DEL', { title: 'Toggle strikethrough' + keyString('strikethrough', keymap), icon: icons.s }));
    if (subscript) items.push(formatItem(schema.marks.sub, 'SUB', { title: 'Toggle subscript' + keyString('subscript', keymap), icon: icons.sub }));
    if (superscript) items.push(formatItem(schema.marks.sup, 'SUP', { title: 'Toggle superscript' + keyString('superscript', keymap), icon: icons.sup }));
    return items;
  }

  function formatItem(markType, markName, options) {
    let passedOptions = {
      active: (state) => { return markActive(state, markType) },
      enable: (state) => { return toggleFormatCommand(markName)(state) }
    };
    for (let prop in options) passedOptions[prop] = options[prop];
    return cmdItem(toggleFormatCommand(markName), passedOptions)
  }

  /* Style DropDown (P, H1-H6, Code) */

  /**
   * Return the Dropdown containing the styling MenuItems that should show per the config.
   * 
   * @param {Object}  config          The MarkupEditor.config.
   * @param {Schema}  schema          The schema that holds node and mark types.
   * @returns [Dropdown]  The array of MenuItems that show as passed in `config`
   */
  function styleMenuItems(config, schema) {
    let keymap = config.keymap;
    let items = [];
    let { p, h1, h2, h3, h4, h5, h6, pre } = config.toolbar.styleMenu;
    if (p) items.push(new ParagraphStyleItem(schema.nodes.paragraph, 'P', { label: p, keymap: baseKeyString('p', keymap) }));
    if (h1) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H1', { label: h1, keymap: baseKeyString('h1', keymap), attrs: { level: 1 }}));
    if (h2) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H2', { label: h2, keymap: baseKeyString('h2', keymap), attrs: { level: 2 }}));
    if (h3) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H3', { label: h3, keymap: baseKeyString('h3', keymap), attrs: { level: 3 }}));
    if (h4) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H4', { label: h4, keymap: baseKeyString('h4', keymap), attrs: { level: 4 }}));
    if (h5) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H5', { label: h5, keymap: baseKeyString('h5', keymap), attrs: { level: 5 }}));
    if (h6) items.push(new ParagraphStyleItem(schema.nodes.heading, 'H6', { label: h6, keymap: baseKeyString('h6', keymap), attrs: { level: 6 }}));
    if (pre) items.push(new ParagraphStyleItem(schema.nodes.code_block, 'PRE', { label: pre }));
    return [new Dropdown(items, { title: 'Set paragraph style', icon: icons.paragraphStyle })]
  }

  /**
  Input rules are regular expressions describing a piece of text
  that, when typed, causes something to happen. This might be
  changing two dashes into an emdash, wrapping a paragraph starting
  with `"> "` into a blockquote, or something entirely different.
  */
  class InputRule {
      /**
      Create an input rule. The rule applies when the user typed
      something and the text directly in front of the cursor matches
      `match`, which should end with `$`.
      
      The `handler` can be a string, in which case the matched text, or
      the first matched group in the regexp, is replaced by that
      string.
      
      Or a it can be a function, which will be called with the match
      array produced by
      [`RegExp.exec`](https://developer.mozilla.org/en-US/docs/Web/JavaScript/Reference/Global_Objects/RegExp/exec),
      as well as the start and end of the matched range, and which can
      return a [transaction](https://prosemirror.net/docs/ref/#state.Transaction) that describes the
      rule's effect, or null to indicate the input was not handled.
      */
      constructor(
      /**
      @internal
      */
      match, handler, options = {}) {
          this.match = match;
          this.match = match;
          this.handler = typeof handler == "string" ? stringHandler(handler) : handler;
          this.undoable = options.undoable !== false;
          this.inCode = options.inCode || false;
          this.inCodeMark = options.inCodeMark !== false;
      }
  }
  function stringHandler(string) {
      return function (state, match, start, end) {
          let insert = string;
          if (match[1]) {
              let offset = match[0].lastIndexOf(match[1]);
              insert += match[0].slice(offset + match[1].length);
              start += offset;
              let cutOff = start - end;
              if (cutOff > 0) {
                  insert = match[0].slice(offset - cutOff, offset) + insert;
                  start = end;
              }
          }
          return state.tr.insertText(insert, start, end);
      };
  }
  const MAX_MATCH = 500;
  /**
  Create an input rules plugin. When enabled, it will cause text
  input that matches any of the given rules to trigger the rule's
  action.
  */
  function inputRules({ rules }) {
      let plugin = new Plugin({
          state: {
              init() { return null; },
              apply(tr, prev) {
                  let stored = tr.getMeta(this);
                  if (stored)
                      return stored;
                  return tr.selectionSet || tr.docChanged ? null : prev;
              }
          },
          props: {
              handleTextInput(view, from, to, text) {
                  return run(view, from, to, text, rules, plugin);
              },
              handleDOMEvents: {
                  compositionend: (view) => {
                      setTimeout(() => {
                          let { $cursor } = view.state.selection;
                          if ($cursor)
                              run(view, $cursor.pos, $cursor.pos, "", rules, plugin);
                      });
                  }
              }
          },
          isInputRules: true
      });
      return plugin;
  }
  function run(view, from, to, text, rules, plugin) {
      if (view.composing)
          return false;
      let state = view.state, $from = state.doc.resolve(from);
      let textBefore = $from.parent.textBetween(Math.max(0, $from.parentOffset - MAX_MATCH), $from.parentOffset, null, "\ufffc") + text;
      for (let i = 0; i < rules.length; i++) {
          let rule = rules[i];
          if (!rule.inCodeMark && $from.marks().some(m => m.type.spec.code))
              continue;
          if ($from.parent.type.spec.code) {
              if (!rule.inCode)
                  continue;
          }
          else if (rule.inCode === "only") {
              continue;
          }
          let match = rule.match.exec(textBefore);
          let tr = match && match[0].length >= text.length &&
              rule.handler(state, match, from - (match[0].length - text.length), to);
          if (!tr)
              continue;
          if (rule.undoable)
              tr.setMeta(plugin, { transform: tr, from, to, text });
          view.dispatch(tr);
          return true;
      }
      return false;
  }
  /**
  This is a command that will undo an input rule, if applying such a
  rule was the last thing that the user did.
  */
  const undoInputRule = (state, dispatch) => {
      let plugins = state.plugins;
      for (let i = 0; i < plugins.length; i++) {
          let plugin = plugins[i], undoable;
          if (plugin.spec.isInputRules && (undoable = plugin.getState(state))) {
              if (dispatch) {
                  let tr = state.tr, toUndo = undoable.transform;
                  for (let j = toUndo.steps.length - 1; j >= 0; j--)
                      tr.step(toUndo.steps[j].invert(toUndo.docs[j]));
                  if (undoable.text) {
                      let marks = tr.doc.resolve(undoable.from).marks();
                      tr.replaceWith(undoable.from, undoable.to, state.schema.text(undoable.text, marks));
                  }
                  else {
                      tr.delete(undoable.from, undoable.to);
                  }
                  dispatch(tr);
              }
              return true;
          }
      }
      return false;
  };

  /**
  Converts double dashes to an emdash.
  */
  const emDash = new InputRule(/--$/, "—", { inCodeMark: false });
  /**
  Converts three dots to an ellipsis character.
  */
  const ellipsis = new InputRule(/\.\.\.$/, "…", { inCodeMark: false });
  /**
  “Smart” opening double quotes.
  */
  const openDoubleQuote = new InputRule(/(?:^|[\s\{\[\(\<'"\u2018\u201C])(")$/, "“", { inCodeMark: false });
  /**
  “Smart” closing double quotes.
  */
  const closeDoubleQuote = new InputRule(/"$/, "”", { inCodeMark: false });
  /**
  “Smart” opening single quotes.
  */
  const openSingleQuote = new InputRule(/(?:^|[\s\{\[\(\<'"\u2018\u201C])(')$/, "‘", { inCodeMark: false });
  /**
  “Smart” closing single quotes.
  */
  const closeSingleQuote = new InputRule(/'$/, "’", { inCodeMark: false });
  /**
  Smart-quote related input rules.
  */
  const smartQuotes = [openDoubleQuote, closeDoubleQuote, openSingleQuote, closeSingleQuote];

  /**
  Build an input rule for automatically wrapping a textblock when a
  given string is typed. The `regexp` argument is
  directly passed through to the `InputRule` constructor. You'll
  probably want the regexp to start with `^`, so that the pattern can
  only occur at the start of a textblock.

  `nodeType` is the type of node to wrap in. If it needs attributes,
  you can either pass them directly, or pass a function that will
  compute them from the regular expression match.

  By default, if there's a node with the same type above the newly
  wrapped node, the rule will try to [join](https://prosemirror.net/docs/ref/#transform.Transform.join) those
  two nodes. You can pass a join predicate, which takes a regular
  expression match and the node before the wrapped node, and can
  return a boolean to indicate whether a join should happen.
  */
  function wrappingInputRule(regexp, nodeType, getAttrs = null, joinPredicate) {
      return new InputRule(regexp, (state, match, start, end) => {
          let attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
          let tr = state.tr.delete(start, end);
          let $start = tr.doc.resolve(start), range = $start.blockRange(), wrapping = range && findWrapping(range, nodeType, attrs);
          if (!wrapping)
              return null;
          tr.wrap(range, wrapping);
          let before = tr.doc.resolve(start - 1).nodeBefore;
          if (before && before.type == nodeType && canJoin(tr.doc, start - 1) &&
              (!joinPredicate || joinPredicate(match, before)))
              tr.join(start - 1);
          return tr;
      });
  }
  /**
  Build an input rule that changes the type of a textblock when the
  matched text is typed into it. You'll usually want to start your
  regexp with `^` to that it is only matched at the start of a
  textblock. The optional `getAttrs` parameter can be used to compute
  the new node's attributes, and works the same as in the
  `wrappingInputRule` function.
  */
  function textblockTypeInputRule(regexp, nodeType, getAttrs = null) {
      return new InputRule(regexp, (state, match, start, end) => {
          let $start = state.doc.resolve(start);
          let attrs = getAttrs instanceof Function ? getAttrs(match) : getAttrs;
          if (!$start.node(-1).canReplaceWith($start.index(-1), $start.indexAfter(-1), nodeType))
              return null;
          return state.tr
              .delete(start, end)
              .setBlockType(start, start, nodeType, attrs);
      });
  }

  /**
   * Return a map of Commands that will be invoked when key combos are pressed.
   * 
   * @param {Object}  config      The MarkupEditor.config
   * @param {Schema}  schema      The schema that holds node and mark types.
   * @returns [String : Command]  Commands bound to keys identified by strings (e.g., "Mod-b")
   */
  function buildKeymap(config, schema) {
      let keymap = config.keymap;   // Shorthand
      let keys = {};

      /** Allow keyString to be a string or array of strings identify the map from keys to cmd */
      function bind(keyString, cmd) {
          if (keyString instanceof Array) {
              for (let key of keyString) { keys[key] = cmd; }
          } else {
              if (keyString?.length > 0) {
                  keys[keyString] = cmd;
              } else {
                  delete keys[keyString];
              }
          }
      }

      // MarkupEditor-specific
      // We need to know when Enter is pressed, so we can identify a change on the Swift side.
      // In ProseMirror, empty paragraphs don't change the doc until they contain something, 
      // so we don't get a notification until something is put in the paragraph. By chaining 
      // the handleEnter with splitListItem that is bound to Enter here, it always executes, 
      // but splitListItem will also execute, as will anything else beyond it in the chain 
      // if splitListItem returns false (i.e., it doesn't really split the list).
      bind("Enter", chainCommands(handleEnter, splitListItem(schema.nodes.list_item)));
      // The MarkupEditor handles Shift-Enter as searchBackward when search is active.
      bind("Shift-Enter", handleShiftEnter);
      // The MarkupEditor needs to be notified of state changes on Delete, like Backspace
      bind("Delete", handleDelete);
      // Table navigation by Tab/Shift-Tab
      bind('Tab', goToNextCell(1));
      bind('Shift-Tab', goToNextCell(-1));

      // Text formatting
      bind(keymap.bold, toggleFormatCommand('B'));
      bind(keymap.italic, toggleFormatCommand('I'));
      bind(keymap.underline, toggleFormatCommand('U'));
      bind(keymap.code, toggleFormatCommand('CODE'));
      bind(keymap.strikethrough, toggleFormatCommand('DEL'));
      bind(keymap.subscript, toggleFormatCommand('SUB'));
      bind(keymap.superscript, toggleFormatCommand('SUP'));
      // Correction (needs to be chained with stateChanged also)
      bind(keymap.undo, undoCommand());
      bind(keymap.redo, redoCommand());
      bind("Backspace", chainCommands(handleDelete, undoInputRule));
      // List types
      bind(keymap.bullet, wrapInListCommand(schema, schema.nodes.bullet_list));
      bind(keymap.number, wrapInListCommand(schema, schema.nodes.ordered_list));
      // Denting
      bind(keymap.indent, indentCommand());
      bind(keymap.outdent, outdentCommand());
      // Insert
      bind(keymap.link, new LinkItem(config).command);
      bind(keymap.image, new ImageItem(config).command);
      bind(keymap.table, new TableInsertItem().command); // TODO: Doesn't work properly
      // Styling
      bind(keymap.p, setStyleCommand('P'));
      bind(keymap.h1, setStyleCommand('H1'));
      bind(keymap.h2, setStyleCommand('H2'));
      bind(keymap.h3, setStyleCommand('H3'));
      bind(keymap.h4, setStyleCommand('H4'));
      bind(keymap.h5, setStyleCommand('H5'));
      bind(keymap.h6, setStyleCommand('H6'));
      // Search
      bind(keymap.search, new SearchItem(config).command);
      return keys
  }

  exports.toolbarView = void 0;

  function toolbar(content) {
    let view = function view(editorView) {
      exports.toolbarView = new ToolbarView(editorView, content);
      return exports.toolbarView;
    };
    return new Plugin({view})
  }

  class ToolbarView {

    constructor(editorView, content) {
      this.prefix = prefix + "-toolbar";
      this.editorView = editorView;
      this.content = content;
      this.root = editorView.root;

      // Embed the toolbar and editorView in a wrapper.
      this.wrapper = crelt("div", {class: this.prefix + "-wrapper"});
      this.toolbar = this.wrapper.appendChild(crelt("div", {class: this.prefix, id: this.prefix}));
      // Since the menu adjusts to fit using a `MoreItem` for contents that doesn't fit, 
      // we need to refresh how it is rendered when resizing takes place.
      window.addEventListener('resize', ()=>{ this.refresh(); });
      this.toolbar.className = this.prefix;
      if (editorView.dom.parentNode)
        editorView.dom.parentNode.replaceChild(this.wrapper, editorView.dom);
      this.wrapper.appendChild(editorView.dom);

      let {dom, update} = renderGrouped(editorView, this.content);
      this.contentUpdate = update;
      this.toolbar.appendChild(dom);
      this.update();
    }

    update() {
      if (this.editorView.root != this.root) {
        this.refreshFit();
        this.root = this.editorView.root;
      }
      // Returning this.fitToolbar() will return this.contentUpdate(this.editorView.state) for 
      // the menu that fits in the width.
      return this.fitToolbar();
    }

    /**
     * Insert an array of MenuItems at the front of the toolbar
     * @param {[MenuItem]} items 
     */
    prepend(items) {
      this.content = [items].concat(this.content);
      this.refreshFit();
    }

    /**
     * Add an array of MenuItems at the end of the toolbar
     * @param {[MenuItem]} items 
     */
    append(items) {
      this.content = this.content.concat([items]);
      this.refreshFit();
    }

    /** Refresh the toolbar, wrapping at the item at `wrapAtIndex` */
    refreshFit(wrapAtIndex) {
      let { dom, update } = renderGroupedFit(this.editorView, this.content, wrapAtIndex);
      this.contentUpdate = update;
      // dom is an HTMLDocumentFragment and needs to replace all of menu
      this.toolbar.innerHTML = '';
      this.toolbar.appendChild(dom);
    }

    /** 
     * Refresh the toolbar with all items and then fit it. 
     * We need to do this because when resize makes the toolbar wider, we don't want to keep 
     * the same `MoreItem` in place if more fits in the toolbar itself.
     */
    refresh() {
      let { dom, update } = renderGrouped(this.editorView, this.content);
      this.contentUpdate = update;
      this.toolbar.innerHTML = '';
      this.toolbar.appendChild(dom);
      this.fitToolbar();
    }

    /**
     * Fit the items in the toolbar into the toolbar width,
     * 
     * If the toolbar as currently rendered does not fit in the width, then execute `refreshFit`,
     * identifying the item to be replaced by a "more" button. That button will be a MoreItem
     * that toggles a sub-toolbar containing the items starting with the one at wrapAtIndex.
     */
    fitToolbar() {
      let items = this.toolbar.children;
      let menuRect = this.toolbar.getBoundingClientRect();
      let menuRight = menuRect.right;
      let separatorHTML = separator().outerHTML;
      let wrapAtIndex = -1; // Track the last non-separator (i.e., content) item that was fully in-width
      for (let i = 0; i < items.length; i++) {
        let item = items[i];
        let itemRight = item.getBoundingClientRect().right;
        if (item.outerHTML != separatorHTML) {
          if (itemRight > menuRight) {
            wrapAtIndex = Math.max(wrapAtIndex, 0);
            this.refreshFit(wrapAtIndex, 0); // Wrap starting at the item before this one, so the new DropDown fits
            return this.contentUpdate(this.editorView.state);        }
          wrapAtIndex++;  // Only count items that are not separators
        } 
      }
      return this.contentUpdate(this.editorView.state);
    }

    destroy() {
      if (this.wrapper.parentNode)
        this.wrapper.parentNode.replaceChild(this.editorView.dom, this.wrapper);
    }

  }

  /* eslint no-cond-assign: 0 */

  // : (NodeType) → InputRule
  // Given a blockquote node type, returns an input rule that turns `"> "`
  // at the start of a textblock into a blockquote.
  function blockQuoteRule(nodeType) {
    return wrappingInputRule(/^\s*>\s$/, nodeType)
  }

  // : (NodeType) → InputRule
  // Given a list node type, returns an input rule that turns a number
  // followed by a dot at the start of a textblock into an ordered list.
  function orderedListRule(nodeType) {
    return wrappingInputRule(/^(\d+)\.\s$/, nodeType, match => ({order: +match[1]}),
                             (match, node) => node.childCount + node.attrs.order == +match[1])
  }

  // : (NodeType) → InputRule
  // Given a list node type, returns an input rule that turns a bullet
  // (dash, plush, or asterisk) at the start of a textblock into a
  // bullet list.
  function bulletListRule(nodeType) {
    return wrappingInputRule(/^\s*([-+*])\s$/, nodeType)
  }

  // : (NodeType) → InputRule
  // Given a code block node type, returns an input rule that turns a
  // textblock starting with three backticks into a code block.
  function codeBlockRule(nodeType) {
    return textblockTypeInputRule(/^```$/, nodeType)
  }

  // : (NodeType, number) → InputRule
  // Given a node type and a maximum level, creates an input rule that
  // turns up to that number of `#` characters followed by a space at
  // the start of a textblock into a heading whose level corresponds to
  // the number of `#` signs.
  function headingRule(nodeType, maxLevel) {
    return textblockTypeInputRule(new RegExp("^(#{1," + maxLevel + "})\\s$"),
                                  nodeType, match => ({level: match[1].length}))
  }

  // : (Schema) → Plugin
  // A set of input rules for creating the basic block quotes, lists,
  // code blocks, and heading.
  function buildInputRules(schema) {
    let rules = smartQuotes.concat(ellipsis, emDash), type;
    if (type = schema.nodes.blockquote) rules.push(blockQuoteRule(type));
    if (type = schema.nodes.ordered_list) rules.push(orderedListRule(type));
    if (type = schema.nodes.bullet_list) rules.push(bulletListRule(type));
    if (type = schema.nodes.code_block) rules.push(codeBlockRule(type));
    if (type = schema.nodes.heading) rules.push(headingRule(type, 6));
    return inputRules({rules})
  }

  /**
   * The tablePlugin handles decorations that add CSS styling 
   * for table borders.
   */
  const tablePlugin = new Plugin({
    state: {
      init(_, {doc}) {
        return DecorationSet.create(doc, [])
      },
      apply(tr, set) {
        if (tr.getMeta('bordered-table')) {
          const {border, fromPos, toPos} = tr.getMeta('bordered-table');
          return DecorationSet.create(tr.doc, [
            Decoration.node(fromPos, toPos, {class: 'bordered-table-' + border})
          ])
        } else if (set) {
          // map other changes so our decoration stays put
          // (e.g. user is typing so decoration's pos must change)
          return set.map(tr.mapping, tr.doc)
        }
      }
    },
    props: {
      decorations: (state) => { return tablePlugin.getState(state) }
    }
  });

  const searchModePlugin  = new Plugin({
    state: {
      init(_, {doc}) {
        return DecorationSet.create(doc, [])
      },
      apply(tr, set) {
        if (tr.getMeta('search$')) {
          if (searchIsActive()) {
            const nodeSelection = new NodeSelection(tr.doc.resolve(0));
            const decoration = Decoration.node(nodeSelection.from, nodeSelection.to, {class: 'searching'});
            return DecorationSet.create(tr.doc, [decoration])
          }
        } else if (set) {
          // map other changes so our decoration stays put 
          // (e.g. user is typing so decoration's pos must change)
          return set.map(tr.mapping, tr.doc)
        }
      }
    },
    props: {
      decorations: (state) => { return searchModePlugin.getState(state) }
    }
  }); 

  /**
   * The imagePlugin handles the interaction with the Swift side that we need for images.
   * Specifically, we want notification that an image was added at load time, but only once. 
   * The loaded event can fire multiple times, both when the initial ImageView is created 
   * as an img element is found, but also whenever the ImageView is recreated. This happens
   * whenever we resize and image and dispatch a transaction to update its state.
   * 
   * We want a notification on the Swift side for the first image load, because when we insert 
   * a new image, that new image is placed in cached storage but has not been saved for the doc.
   * This is done using postMessage to send 'addedImage', identifying the src. However, we don't 
   * want to tell the Swift side we added an image every time we resize it. To deal with this 
   * problem, we set 'imageLoaded' metadata in the transaction that is dispatched on at load. The 
   * first time, we update the Map held in the imagePlugin. When we resize, the image loads again 
   * as the ImageView gets recreated, but in the plugin, we can check the Map to see if we already 
   * loaded it once and avoid notifying the Swift side multiple times.
   * 
   * The Map is keyed by the src for the image. If the src is duplicated in the document, we only 
   * get one 'addedImage' notification.
   */
  const imagePlugin = new Plugin({
    state: {
      init() {
        return new Map()
      },
      apply(tr, srcMap) {
        if (tr.getMeta('imageLoaded')) {
          const src = tr.getMeta('imageLoaded').src;
          const srcIsLoaded = srcMap.get(src) == true;
          if (!srcIsLoaded) {
            srcMap.set(src, true);
            postMessage({ 'messageType': 'addedImage', 'src': src, 'divId': (selectedID ?? '') });
          }
            // We already notified of a state change, and this one causes callbackInput which 
            // is used to track changes
            //stateChanged();
        }
        return srcMap
      }
    },
    props: {
      attributes: (state) => { return imagePlugin.getState(state) }
    }
  });

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
        const doc = state.doc;
        if (doc.childCount == 1 && doc.firstChild.isTextblock && doc.firstChild.content.size == 0) {
          const allSelection = new AllSelection(doc);
          // The attributes are applied to the empty paragraph and styled based on editor.css
          const decoration = Decoration.node(allSelection.from, allSelection.to, {class: 'placeholder', placeholder: placeholderText});
          return DecorationSet.create(doc, [decoration])
        }
      }
    }
  });

  /**
   * Insert an array of MenuItems or a single MenuItem at the front of the toolbar
   * @param {[MenuItem] | MenuItem} menuItems 
   */
  function prependToolbar(menuItems) {
    let items = Array.isArray(menuItems) ? menuItems : [menuItems];
    exports.toolbarView.prepend(items);
  }

  /**
   * Append an array of MenuItems or a single MenuItem at the end of the toolbar
   * @param {[MenuItem] | MenuItem} menuItems 
   */
  function appendToolbar(menuItems) {
    let items = Array.isArray(menuItems) ? menuItems : [menuItems];
    exports.toolbarView.append(items);
  }

  function toggleSearch() {
    let searchItem = new SearchItem(getMarkupEditorConfig());
    // TODO: How to not rely on toolbarView being present
    let view = exports.toolbarView.editorView;
    searchItem.toggleSearch(view.state, view.dispatch, view);
  }

  function openLinkDialog() {
    let linkItem = new LinkItem(getMarkupEditorConfig());
    let view = exports.toolbarView.editorView;
    linkItem.openDialog(view.state, view.dispatch, view);
  }

  function openImageDialog() {
    let imageItem = new ImageItem(getMarkupEditorConfig());
    let view = exports.toolbarView.editorView;
    imageItem.openDialog(view.state, view.dispatch, view);
  }

  /**
   * Return an array of Plugins used for the MarkupEditor
   * @param {Schema} schema The schema used for the MarkupEditor
   * @returns 
   */
  function markupSetup(config, schema) {
    setPrefix('Markup');
    let plugins = [
      buildInputRules(schema),
      keymap(buildKeymap(config, schema)),
      keymap(baseKeymap),
      dropCursor(),
      gapCursor(),
    ];

    // Only show the toolbar if the config indicates it is visible
    if (config.toolbar.visibility.toolbar) {
      let content = buildMenuItems(config, schema);
      plugins.push(toolbar(content));
    }

    plugins.push(history());

    // Add the plugin that handles table borders
    plugins.push(tablePlugin);

    // Add the plugin that handles placeholder display for an empty document
    if (config?.placeholder) setPlaceholder(config.placeholder);
    plugins.push(placeholderPlugin);

    // Add the plugin to handle notifying the Swift side of images loading
    plugins.push(imagePlugin);

    // Add the plugins that performs search, decorates matches, and indicates searchmode
    plugins.push(search());
    //TODO: Is this plugin needed when used with Swift. It is not for the browser.
    //plugins.push(searchModePlugin)

    return plugins;
  }

  /**
   * `ToolbarConfig.standard()` is the default for the MarkupEditor and is designed to correspond 
   * to GitHub flavored markdown. It can be overridden by passing it a new config when instantiating
   * the MarkupEditor. You can use the pre-defined static methods like `full` or customize what they 
   * return. The predefined statics each allow you to turn on or off the `correctionBar` visibility.
   * The `correctionBar` visibility is off by default, because while it's useful for touch devices 
   * without a keyboard, undo/redo are mapped to the hotkeys most people have in muscle memory.
   * 
   * To customize the menu bar, for example, in your index.html:
   * 
   *    let toolbarConfig = MU.ToolbarConfig.full(true);  // Grab the full toolbar, including correction, as a baseline
   *    toolbarConfig.insertBar.table = false;               // Turn off table insert
   *    const markupEditor = new MU.MarkupEditor(
   *      document.querySelector('#editor'),
   *      {
   *        html: '<h1>Hello, world!</h1>',
   *        toolbar: toolbarConfig,
   *      }
   *    )
   *    
   * Turn off entire toolbars and menus using the "visibility" settings. Turn off specific items
   * within a toolbar or menu using the settings specific to that toolbar or menu. Customize 
   * left-to-right ordering using the "ordering" settings.
   */
  class ToolbarConfig {

    static all = {
      "visibility": {             // Control the visibility of toolbars, etc
        "toolbar": true,          // Whether the toolbar is visible at all
        "correctionBar": true,    // Whether the correction bar (undo/redo) is visible
        "insertBar": true,        // Whether the insert bar (link, image, table) is visible
        "styleMenu": true,        // Whether the style menu (p, h1-h6, code) is visible
        "styleBar": true,         // Whether the style bar (bullet/numbered lists) is visible
        "formatBar": true,        // Whether the format bar (b, i, u, etc) is visible
        "search": true,           // Whether the search item (hide/show search bar) is visible
      },
      "ordering": {               // Control the ordering of toolbars, etc, ascending left-to-right
        "correctionBar": 10,      // Correction bar order if it is visible
        "insertBar": 20,          // Insert bar (link, image, table) order if it is visible
        "styleMenu": 30,          // Style menu (p, h1-h6, code) order if it is visible
        "styleBar": 40,           // Style bar (bullet/numbered lists) order if it is visible
        "formatBar": 50,          // Format bar (b, i, u, etc) order if it is visible
        "search": 60,             // Search item (hide/show search bar) order if it is visible
      },
      "insertBar": {
        "link": true,             // Whether the link menu item is visible
        "image": true,            // Whether the image menu item is visible
        "tableMenu": true,        // Whether the table menu is visible
      },
      "formatBar": {
        "bold": true,             // Whether the bold menu item is visible
        "italic": true,           // Whether the italic menu item is visible
        "underline": true,        // Whether the underline menu item is visible
        "code": true,             // Whether the code menu item is visible
        "strikethrough": true,    // Whether the strikethrough menu item is visible
        "subscript": true,        // Whether the subscript menu item is visible
        "superscript": true,      // Whether the superscript menu item is visible
      },
      "styleMenu": {
        "p": "Body",              // The label in the menu for "P" style
        "h1": "H1",               // The label in the menu for "H1" style
        "h2": "H2",               // The label in the menu for "H2" style
        "h3": "H3",               // The label in the menu for "H3" style
        "h4": "H4",               // The label in the menu for "H4" style
        "h5": "H5",               // The label in the menu for "H5" style
        "h6": "H6",               // The label in the menu for "H6" style
        "pre": "Code",            // The label in the menu for "PRE" aka code_block style
      },
      "styleBar": {
        "list": true,             // Whether bullet and numbered list items are visible
        "dent": true,             // Whether indent and outdent items are visible
      },
      "tableMenu": {
        "header": true,           // Whether the "Header" item is visible in the "Table->Add" menu
        "border": true,           // Whether the "Border" item is visible in the "Table" menu
      },
    }

    static full(correction=false) {
      let full = this.all;
      full.visibility.correctionBar = correction;
      return full
    }

    static standard(correction=false) {
      return this.markdown(correction)
    }

    static desktop(correction=false) {
      return this.full(correction)
    }

    static markdown(correction=false) {
      let markdown = this.full(correction);
      markdown.formatBar.underline = false;
      markdown.formatBar.subscript = false;
      markdown.formatBar.superscript = false;
      return markdown
    }
  }

  /**
   * `KeymapConfig.standard()` is the default for the MarkupEditor. It can be overridden by 
   * passing a new KeymapConfig when instantiating the MarkupEditor. You can use the pre-defined 
   * static methods like `standard()` or customize what it returns.
   * 
   * To customize the key mapping, for example, in your index.html:
   * 
   *    let keymapConfig = MU.KeymapConfig.standard();    // Grab the standard keymap config as a baseline
   *    keymapConfig.link = ["Ctrl-L", "Ctrl-l"];         // Use Control+L instead of Command+k
   *    const markupEditor = new MU.MarkupEditor(
   *      document.querySelector('#editor'),
   *      {
   *        html: '<h1>Hello, world!</h1>',
   *        keymap: keymapConfig,
   *      }
   *    )
   *    
   * Note that the key mapping will exist and work regardless of whether you disable a toolbar 
   * or a specific item in a menu. For example, undo/redo by default map to Mod-z/Shift-Mod-z even  
   * though the "correctionBar" is off by default in the MarkupEditor. You can remove a key mapping 
   * by setting its value to null or an empty string. 
   */
  class KeymapConfig {
      static all = {
          // Correction
          "undo": "Mod-z",
          "redo": "Shift-Mod-z",
          // Insert
          "link": ["Mod-K", "Mod-k"],
          "image": ["Mod-G", "Mod-g"],
          //"table": ["Mod-T", "Mod-t"],  // Does not work anyway
          // Stylemenu
          "p": "Ctrl-Shift-0",
          "h1": "Ctrl-Shift-1",
          "h2": "Ctrl-Shift-2",
          "h3": "Ctrl-Shift-3",
          "h4": "Ctrl-Shift-4",
          "h5": "Ctrl-Shift-5",
          "h6": "Ctrl-Shift-6",
          // Stylebar
          "bullet": ["Ctrl-U", "Ctrl-u"],
          "number": ["Ctrl-O", "Ctrl-o"],
          "indent": ["Mod-]", "Ctrl-q"],
          "outdent": ["Mod-[", "Shift-Ctrl-q"],
          // Format
          "bold": ["Mod-B", "Mod-b"],
          "italic": ["Mod-I", "Mod-i"],
          "underline": ["Mod-U", "Mod-u"],
          "strikethrough": ["Ctrl-S", "Ctrl-s"],
          "code": "Mod-`",
          "subscript": "Ctrl-Mod--",
          "superscript": "Ctrl-Mod-+",
          // Search
          "search": ["Ctrl-F", "Ctrl-f"],
      }

      static full() {
          return this.all
      }

      static standard() {
          return this.markdown()
      }

      static desktop() {
          return this.full()
      }

      static markdown() {
          let markdown = this.full();
          markdown.underline = null;
          markdown.subscript = null;
          markdown.superscript = null;
          return markdown
      }
  }

  /**
   * `BehaviorConfig.standard()` is the default for the MarkupEditor. It can be overridden by 
   * passing a new BehaviorConfig when instantiating the MarkupEditor.
   * 
   * To customize the behavior config, for example, in your index.html:
   * 
   *    let behaviorConfig = MU.BehaviorConfig.desktop();    // Use the desktop editor config as a baseline
   *    const markupEditor = new MU.MarkupEditor(
   *      document.querySelector('#editor'),
   *      {
   *        html: '<h1>Hello, world!</h1>',
   *        behavior: behaviorConfig,
   *      }
   *    )
   */
  class BehaviorConfig {

      static all = {
          "focusAfterLoad": true,     // Whether the editor should take focus after loading
          "selectImage": false,       // Whether to show a "Select..." button in the Insert Image dialog
          "insertLink": false,        // Whether to defer to the MarkupDelegate rather than use the default LinkDialog
          "insertImage": false,       // Whether to defer to the MarkupDelagate rather than use the default ImageDialog
      }

      static standard() { 
          return this.all
      }

      static desktop() { 
          let desktop = this.all;
          desktop.selectImage = true;
          return desktop
      }

  }

  /* global MU */

  /**
   * The MessageHandler receives `postMessage` from the MarkupEditor as the document state changes.
   * 
   * You can set the MessageHandler used by the MarkupEditor using `MU.setMessageHandler`. This is how 
   * the MarkupEditor is embedded in Swift and VSCode. If you don't set your own MessageHandler, then 
   * this is the default version that will be used. These other MessageHandlers will typically use the 
   * same MarkupDelegate pattern to route document state notifications to an app-specific delegate.
   * 
   * Although the default MessageHandler does some important work, like loading content when the view 
   * is ready, its primary job is to let your MarkupDelegate know of state changes in the document. 
   * This is so that your app that uses the MarkupEditor can take action if needed.
   * 
   * Note that delegate can be undefined, and any of `markup` methods invoked in it may also be 
   * undefined. This way, you only need to implement delegate methods that are useful in your app.
   * For example, if you want to track if any changes have occurred in the document, you would want 
   * to implement `markupInput` so you know some input/change has occurred. You could then do a kind 
   * of auto-save method within your app, for example.
   */
  class MessageHandler {
      constructor(markupEditor) {
          this.markupEditor = markupEditor;
      }

      /**
       * Take action when messages we care about come in.
       * @param {string | JSON} message   The message passed from the MarkupEditor as the state changes. 
       */
      postMessage(message) {
          let config = this.markupEditor.config;
          let delegate = config.delegate;

          if (message.startsWith('input')) {
              // Some input or change happened in the document, so let the delegate know immediately 
              // if it exists, and return. Input happens with every keystroke and editing operation, 
              // so generally delegate should be doing very little, except perhaps noting that the 
              // document has changed. However, what your delegate does is very application-specific.
              delegate?.markupInput && delegate?.markupInput(message, this.markupEditor);
              return
          }
          switch (message) {
              // The editor posts `ready` when all scripts are loaded, so we can set the HTML. If HTML
              // is an empty document, then the config.placeholder will be shown.
              case 'ready':
                  this.loadContents(config);
                  delegate?.markupReady && delegate?.markupReady(this.markupEditor);
                  return
              case "updateHeight":
                  delegate?.markupUpdateHeight && delegate?.markupUpdateHeight(getHeight(), this.markupEditor);
                  return
              case "selectionChanged":
                  delegate?.markupSelectionChanged && delegate?.markupSelectionChanged(this.markupEditor);
                  return
              case "clicked":
                  delegate?.markupClicked && delegate?.markupClicked(this.markupEditor);
                  return
              case "searched":
                  delegate?.markupSearched && delegate?.markupSearched(this.markupEditor);
                  return
              default:
                  // By default, try to process the message as a JSON object, and if it's not parseable, 
                  // then log to the console so we know about it during development. Between the `postMessage` 
                  // method and its companion `receivedMessageData`, every message received from the 
                  // MarkupEditor should be handled, with no exceptions. Otherwise, something is going 
                  // on over in the web view that we are ignoring, and while we might want to ignore it, 
                  // we don't want anything to slip thru the cracks here.
                  try {
                      const messageData = JSON.parse(message);
                      this.receivedMessageData(messageData);
                  } catch {
                      console.log("Unhandled message: " + message);
                  }
          }
      }

      /**
       * Examine the `messageData.messageType` and take appropriate action with the other 
       * data that is supplied in the `messageData`.
       * 
       * @param {Object} messageData The object obtained by parsing the JSON of a message.
       */
      receivedMessageData(messageData) {
          let delegate = this.markupEditor.config.delegate;
          let messageType = messageData.messageType;
          switch (messageType) {
              case "log":
                  console.log(messageData.log);
                  return
              case "error": {
                  let code = messageData.code;
                  let message = messageData.message;
                  if (!code || !message) {
                      console.log("Bad error message.");
                      return
                  }
                  let info = messageData.info;
                  let alert = messageData.alert ?? true;
                  delegate?.markupError && delegate?.markupError(code, message, info, alert);
                  return
              }
              case "copyImage":
                  console.log("fix copyImage " + messageData.src);
                  return
              case "addedImage": {
                  if (!delegate?.markupImageAdded) return;
                  let divId = messageData.divId;
                  // Even if divid is identified, if it's empty or the editor element, then
                  // use the old call without divid to maintain compatibility with earlier versions
                  // that did not support multi-contenteditable divs.
                  if ((divId.length == 0) || (divId == "editor")) {
                      delegate.markupImageAdded(this.markupEditor, messageData.src);
                  } else if (!divId.length == 0) {
                      delegate?.markupImageAdded(this.markupEditor, messageData.src, divId);
                  } else {
                      console.log("Error: The div id for the image could not be decoded.");
                  }
                  return
              }
              case "deletedImage":
                  console.log("fix deletedImage " + messageData.src);
                  return
              case "buttonClicked":
                  console.log("fix deletedImage " + messageData.src);
                  return
              default:
                  console.log(`Unknown message of type ${messageType}: ${messageData}.`);
          }
      }

      /** This really doesn't do anything for now, but it a placeholder */
      loadUserFiles(config) {
          let scriptFiles = config.userScriptFiles;
          let cssFiles = config.userCssFiles;
          loadUserFiles(scriptFiles, cssFiles);
      }

      /** Load the contents from `filename`, or if not specified, from `html` */
      loadContents(config) {
          let filename = config.filename;
          let base = config.base;
          let focusAfterLoad = config.behavior.focusAfterLoad;
          if (filename) {
              fetch(filename)
                  .then((response) => response.text())
                  .then((text) => {
                      // A fetch failure returns 'Cannot GET <filename with path>'
                      MU.setHTML(text, focusAfterLoad, base);
                  })
                  .catch(() => {
                      // But just in case, report a failure if needed.
                      MU.setHTML(`<p>Failed to load ${filename}.</p>`, focusAfterLoad);
                  });
          } else {
              let html = config.html ?? '<p></p>';
              MU.setHTML(html, focusAfterLoad);
          }
      }
  }

  /**
   * The MarkupEditor holds the properly set-up EditorView and any additional configuration.
   */
  class MarkupEditor {
    constructor(target, config) {
      this.element = target ?? document.querySelector("#editor");

      // Make sure config always contains menu, keymap, and behavior
      this.config = config ?? {};
      if (!this.config.toolbar) this.config.toolbar = ToolbarConfig.standard();
      if (!this.config.keymap) this.config.keymap = KeymapConfig.standard();
      if (!this.config.behavior) this.config.behavior = BehaviorConfig.standard();
      setMarkupEditorConfig(this.config);

      this.html = this.config.html ?? emptyHTML();
      setMessageHandler(this.config.messageHandler ?? new MessageHandler(this));
      window.view = new EditorView(this.element, {
        state: EditorState.create({
          // For the MarkupEditor, we can just use the editor element. 
          // There is no need to use a separate content element.
          doc: DOMParser.fromSchema(schema).parse(this.element),
          plugins: markupSetup(this.config, schema)
        }),
        nodeViews: {
          link(node, view, getPos) { return new LinkView(node, view, getPos)},
          image(node, view, getPos) { return new ImageView(node, view, getPos) },
          div(node, view, getPos) { return new DivView(node, view, getPos) },
        },
        // All text input makes callbacks to indicate the document state has changed.
        // For history, used handleTextInput, but that fires *before* input happens.
        // Note the `setTimeout` hack is used to have the function called after the change
        // for things things other than the `input` event.
        handleDOMEvents: {
          'input': () => { callbackInput(); },
          'focus': () => { setTimeout(() => focused());},
          'blur': () => { setTimeout(() => blurred());},
          'cut': () => { setTimeout(() => { callbackInput(); }, 0); },
          'click': () => { setTimeout(() => { clicked(); }, 0); },
          'delete': () => { setTimeout(() => { callbackInput(); }, 0); },
        },
        handlePaste() {
          setTimeout(() => { callbackInput(); }, 0);
          return false
        },
        handleKeyDown(view, event) {
          switch (event.key) {
            case 'Enter':
            case 'Delete':
            case 'Backspace':
              { setTimeout(() => { handleEnter(); }, 0); }
          }
          return false
        },
        // Use createSelectionBetween to handle selection and click both.
        // Here we guard against selecting across divs.
        createSelectionBetween(view, $anchor, $head) {
          const divType = view.state.schema.nodes.div;
          const range = $anchor.blockRange($head);
          // Find the divs that the anchor and head reside in.
          // Both, one, or none can be null.
          const fromDiv = outermostOfTypeAt(divType, range.$from);
          const toDiv = outermostOfTypeAt(divType, range.$to);
          // If selection is all within one div, then default occurs; else return existing selection
          if ((fromDiv || toDiv) && !$anchor.sameParent($head)) {
            if (fromDiv != toDiv) {
              return view.state.selection;    // Return the existing selection
            }
          }        resetSelectedID(fromDiv?.attrs.id ?? toDiv?.attrs.id ?? null);  // Set the selectedID to the div's id or null.
          selectionChanged();
          // clicked(); // TODO: Removed, but is it needed in Swift MarkupEditor?
          return null;                        // Default behavior should occur
        }
      });
    }
  }

  exports.BehaviorConfig = BehaviorConfig;
  exports.Dropdown = Dropdown;
  exports.DropdownSubmenu = DropdownSubmenu;
  exports.KeymapConfig = KeymapConfig;
  exports.MarkupEditor = MarkupEditor;
  exports.MenuItem = MenuItem;
  exports.ToolbarConfig = ToolbarConfig;
  exports.addButton = addButton;
  exports.addCol = addCol;
  exports.addDiv = addDiv;
  exports.addHeader = addHeader;
  exports.addRow = addRow;
  exports.appendToolbar = appendToolbar;
  exports.borderTable = borderTable;
  exports.cancelSearch = cancelSearch;
  exports.cmdItem = cmdItem;
  exports.cutImage = cutImage;
  exports.deactivateSearch = deactivateSearch;
  exports.deleteLink = deleteLink;
  exports.deleteTableArea = deleteTableArea;
  exports.doRedo = doRedo;
  exports.doUndo = doUndo;
  exports.emptyDocument = emptyDocument;
  exports.endModalInput = endModalInput;
  exports.focus = focus;
  exports.focusOn = focusOn;
  exports.getDataImages = getDataImages;
  exports.getHTML = getHTML;
  exports.getHeight = getHeight;
  exports.getMarkupEditorConfig = getMarkupEditorConfig;
  exports.getSelectionState = getSelectionState;
  exports.getTestHTML = getTestHTML;
  exports.indent = indent;
  exports.insertImage = insertImage;
  exports.insertLink = insertLink;
  exports.insertTable = insertTable;
  exports.isChanged = isChanged;
  exports.loadUserFiles = loadUserFiles;
  exports.modifyImage = modifyImage;
  exports.openImageDialog = openImageDialog;
  exports.openLinkDialog = openLinkDialog;
  exports.outdent = outdent;
  exports.padBottom = padBottom;
  exports.pasteHTML = pasteHTML;
  exports.pasteText = pasteText;
  exports.prependToolbar = prependToolbar;
  exports.removeAllDivs = removeAllDivs;
  exports.removeButton = removeButton;
  exports.removeDiv = removeDiv;
  exports.renderDropdownItems = renderDropdownItems;
  exports.renderGrouped = renderGrouped;
  exports.replaceStyle = replaceStyle;
  exports.resetSelection = resetSelection;
  exports.savedDataImage = savedDataImage;
  exports.searchFor = searchFor;
  exports.setHTML = setHTML;
  exports.setMarkupEditorConfig = setMarkupEditorConfig;
  exports.setMessageHandler = setMessageHandler;
  exports.setPlaceholder = setPlaceholder;
  exports.setStyle = setStyle;
  exports.setTestHTML = setTestHTML;
  exports.setTopLevelAttributes = setTopLevelAttributes;
  exports.startModalInput = startModalInput;
  exports.testBlockquoteEnter = testBlockquoteEnter;
  exports.testExtractContents = testExtractContents;
  exports.testListEnter = testListEnter;
  exports.testPasteHTMLPreprocessing = testPasteHTMLPreprocessing;
  exports.testPasteTextPreprocessing = testPasteTextPreprocessing;
  exports.toggleBold = toggleBold;
  exports.toggleCode = toggleCode;
  exports.toggleItalic = toggleItalic;
  exports.toggleListItem = toggleListItem$1;
  exports.toggleSearch = toggleSearch;
  exports.toggleStrike = toggleStrike;
  exports.toggleSubscript = toggleSubscript;
  exports.toggleSuperscript = toggleSuperscript;
  exports.toggleUnderline = toggleUnderline;

}));

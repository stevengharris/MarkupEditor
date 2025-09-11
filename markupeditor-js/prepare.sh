#!/bin/bash

echo "Updating dependencies from markupeditor-base..."
SCRIPT="./node_modules/markupeditor-base/dist/markupeditor.umd.js"
MARKUPCSS="./node_modules/markupeditor-base/styles/markup.css"
MIRRORCSS="./node_modules/markupeditor-base/styles/mirror.css"
READY=true
if [ ! -e "$SCRIPT" ]; then
  echo "$SCRIPT does not exist."
  READY=false
fi
if [ ! -e "$MARKUPCSS" ]; then
  echo "$MARKUPCSS does not exist."
  READY=false
fi
if [ ! -e "$MIRRORCSS" ]; then
  echo "$MIRRORCSS does not exist."
  READY=false
fi
if [ ! $READY ]; then
    echo "Did you run npm install?"
    exit 1
fi
set -v
cp -f $SCRIPT ../MarkupEditor/Resources/markup.js
cp -f $MARKUPCSS ../MarkupEditor/Resources/markup.css
cp -f $MIRRORCSS ../MarkupEditor/Resources/mirror.css

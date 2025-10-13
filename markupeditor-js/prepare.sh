#!/bin/bash

echo "Updating dependencies from markupeditor-base..."
SCRIPT="./node_modules/markupeditor-base/dist/markupeditor.umd.js"
MARKUPCSS="./node_modules/markupeditor-base/styles/markup.css"
MIRRORCSS="./node_modules/markupeditor-base/styles/mirror.css"
TEST="./node_modules/markupeditor-base/test"
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
if [ ! -e "$TEST" ]; then
  echo "$TEST does not exist."
  READY=false
fi
if [ ! $READY ]; then
    echo "Did you run npm install?"
    exit 1
fi
echo " Copying $SCRIPT\n  to ../MarkupEditor/Resources/markup.js"
cp -f "$SCRIPT" ../MarkupEditor/Resources/markup.js
echo " Copying $MARKUPCSS\n  to ../MarkupEditor/Resources/markup.css"
cp -f "$MARKUPCSS" ../MarkupEditor/Resources/markup.css
echo " Copying $MIRRORCSS\n  to ../MarkupEditor/Resources/mirror.css"
cp -f "$MIRRORCSS" ../MarkupEditor/Resources/mirror.css
echo " Copying ${TEST}/*.json\n  to ../MarkupEditorTests/BaseTests/"
# The simple cp with wildcarded "${TEST}*.json" fails, so used find + exec cp
find $TEST -name "*.json" -exec cp {} "../MarkupEditorTests/BaseTests/" \;

#!/bin/bash

echo "Updating dependencies from markupeditor-base..."
MUSCRIPT="./node_modules/markupeditor-base/dist/markupeditor.umd.js"
MUSTYLE="./node_modules/markupeditor-base/styles/markupeditor.css"
MIRRORCSS="./node_modules/markupeditor-base/styles/mirror.css"
MARKUPCSS="./node_modules/markupeditor-base/styles/markup.css"
TOOLBARCSS="./node_modules/markupeditor-base/styles/toolbar.css"
COMPONENT="./node_modules/markupeditor-base/webcomponent/markup-editor.js"

# Determine whether the required JavaScript dependencies are available
READY=true
if [ ! -e "$MUSCRIPT" ]; then
  echo "Error: $MUSCRIPT does not exist."
  READY=false
fi
if [ ! -e "$MUSTYLE" ]; then
  echo "Error: $MUSTYLE does not exist."
  READY=false
fi
if [ ! -e "$MIRRORCSS" ]; then
  echo "Error: $MIRRORCSS does not exist."
  READY=false
fi
if [ ! -e "$MARKUPCSS" ]; then
  echo "Error: $MARKUPCSS does not exist."
  READY=false
fi
if [ ! -e "$TOOLBARCSS" ]; then
  echo "Error: $TOOLBARCSS does not exist."
  READY=false
fi
if [ ! -e "$COMPONENT" ]; then
  echo "Error: $COMPONENT does not exist."
  READY=false
fi
if [ "$READY" = false ]; then
    echo "Did you run npm install?"
    exit 1
fi
echo " Copying $MUSCRIPT\n  to ../MarkupEditor/Resources/markup.js"
cp -f "$MUSCRIPT" ../MarkupEditor/Resources/markupeditor.umd.js
echo " Copying $MUSTYLE\n  to ../MarkupEditor/Resources/markupeditor.css"
cp -f "$MUSTYLE" ../MarkupEditor/Resources/markupeditor.css
echo " Copying $MIRRORCSS\n  to ../MarkupEditor/Resources/mirror.css"
cp -f "$MIRRORCSS" ../MarkupEditor/Resources/mirror.css
echo " Copying $MARKUPCSS\n  to ../MarkupEditor/Resources/markup.css"
cp -f "$MARKUPCSS" ../MarkupEditor/Resources/markup.css
echo " Copying $TOOLBARCSS\n  to ../MarkupEditor/Resources/toolbar.css"
cp -f "$TOOLBARCSS" ../MarkupEditor/Resources/toolbar.css
echo " Copying $COMPONENT\n  to ../MarkupEditor/Resources/markup-editor.js"
cp -f "$COMPONENT" ../MarkupEditor/Resources/markup-editor.js

# Determine whether the test dependencies are available
TEST="./node_modules/markupeditor-base/test"
if [ ! -e "$TEST" ]; then
  echo "Warning: $TEST does not exist."
  echo "To run tests, you must install using a local markupeditor-base dev-dependency."
else
    echo " Copying test data ${TEST}/*.json\n  to ../MarkupEditorTests/BaseTests/"
    # The simple cp with wildcarded "${TEST}*.json" fails, so used find + exec cp
    find $TEST -name "*.json" -exec cp {} "../MarkupEditorTests/BaseTests/" \;
fi

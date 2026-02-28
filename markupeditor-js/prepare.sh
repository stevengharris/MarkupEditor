#!/bin/bash

echo "Updating dependencies from markupeditor base project..."
COMPONENT="./node_modules/markupeditor/dist/markup-editor.js"
TOOLBARCONFIG="./node_modules/markupeditor/config/toolbarconfig.json"
KEYMAPCONFIG="./node_modules/markupeditor/config/keymapconfig.json"
BEHAVIORCONFIG="./node_modules/markupeditor/config/behaviorconfig.json"

# Determine whether the required JavaScript dependencies are available
READY=true
if [ ! -e "$COMPONENT" ]; then
  echo "Error: $COMPONENT does not exist."
  READY=false
fi
if [ ! -e "$TOOLBARCONFIG" ]; then
  echo "Error: $TOOLBARCONFIG does not exist."
  READY=false
fi
if [ ! -e "$KEYMAPCONFIG" ]; then
  echo "Error: $KEYMAPCONFIG does not exist."
  READY=false
fi
if [ ! -e "$BEHAVIORCONFIG" ]; then
  echo "Error: $BEHAVIORCONFIG does not exist."
  READY=false
fi
if [ "$READY" = false ]; then
    echo "Did you run npm install?"
    exit 1
fi
echo " Copying $COMPONENT\n  to ../MarkupEditor/Resources/"
cp -f "$COMPONENT" ../MarkupEditor/Resources/
echo " Copying $TOOLBARCONFIG\n  to ../MarkupEditor/Resources/"
cp -f "$TOOLBARCONFIG" ../MarkupEditor/Resources/
echo " Copying $KEYMAPCONFIG\n  to ../MarkupEditor/Resources/"
cp -f "$KEYMAPCONFIG" ../MarkupEditor/Resources/
echo " Copying $BEHAVIORCONFIG\n  to ../MarkupEditor/Resources/"
cp -f "$BEHAVIORCONFIG" ../MarkupEditor/Resources/

# Determine whether the test dependencies are available
TEST="./node_modules/markupeditor/test"
if [ ! -e "$TEST" ]; then
  echo "Warning: $TEST does not exist."
  echo "To run tests, you must install using a local markupeditor dev-dependency."
else
    echo " Copying test data ${TEST}/*.json\n  to ../MarkupEditorTests/BaseTests/Data"
    # The simple cp with wildcarded "${TEST}*.json" fails, so used find + exec cp
    find $TEST -name "*.json" -exec cp {} "../MarkupEditorTests/BaseTests/Data/" \;
fi

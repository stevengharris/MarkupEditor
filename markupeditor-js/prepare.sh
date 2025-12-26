#!/bin/bash

echo "Updating dependencies from markupeditor base project..."
COMPONENT="./node_modules/markupeditor/dist/markup-editor.js"

# Determine whether the required JavaScript dependencies are available
READY=true
if [ ! -e "$COMPONENT" ]; then
  echo "Error: $COMPONENT does not exist."
  READY=false
fi
if [ "$READY" = false ]; then
    echo "Did you run npm install?"
    exit 1
fi
echo " Copying $COMPONENT\n  to ../MarkupEditor/Resources/markup-editor.js"
cp -f "$COMPONENT" ../MarkupEditor/Resources/markup-editor.js

# Determine whether the test dependencies are available
TEST="./node_modules/markupeditor/test"
if [ ! -e "$TEST" ]; then
  echo "Warning: $TEST does not exist."
  echo "To run tests, you must install using a local markupeditor dev-dependency."
else
    echo " Copying test data ${TEST}/*.json\n  to ../MarkupEditorTests/BaseTests/"
    # The simple cp with wildcarded "${TEST}*.json" fails, so used find + exec cp
    find $TEST -name "*.json" -exec cp {} "../MarkupEditorTests/BaseTests/" \;
fi

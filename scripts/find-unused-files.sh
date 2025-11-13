#!/bin/bash

# Find unused TypeScript/JavaScript files in assets/js/
# Usage: ./scripts/find-unused-files.sh

set -e

ASSETS_DIR="assets/js"
EXCLUDE_DIRS="(__tests__|node_modules)"

echo "Finding unused files in $ASSETS_DIR..."
echo "============================================"
echo ""

# Get all source files (excluding tests and node_modules)
mapfile -t SOURCE_FILES < <(find "$ASSETS_DIR" -type f \( -name "*.ts" -o -name "*.tsx" -o -name "*.js" -o -name "*.jsx" \) | grep -vE "$EXCLUDE_DIRS" | sort)

UNUSED_FILES=()

for file in "${SOURCE_FILES[@]}"; do
  # Skip entry point and type definition files
  if [[ "$file" == "assets/js/app.ts" ]] || [[ "$file" == *"/types/"* ]]; then
    continue
  fi

  # Get the base filename without extension for searching
  basename=$(basename "$file" | sed 's/\.[^.]*$//')

  # Search for imports of this file in non-test files
  # Look for: import ... from './path/to/file' or require('./path/to/file')
  if ! grep -r --include="*.ts" --include="*.tsx" --include="*.js" --include="*.jsx" \
       --exclude-dir="__tests__" --exclude-dir="node_modules" \
       -E "(from ['\"].*${basename}['\"]|require\(['\"].*${basename})" \
       "$ASSETS_DIR" > /dev/null 2>&1; then
    UNUSED_FILES+=("$file")
  fi
done

if [ ${#UNUSED_FILES[@]} -eq 0 ]; then
  echo "✓ No unused files found!"
else
  echo "Found ${#UNUSED_FILES[@]} unused files:"
  echo ""
  for file in "${UNUSED_FILES[@]}"; do
    echo "  - $file"
  done
  echo ""
  echo "These files are either not imported at all, or only imported in test files."
fi

echo ""
echo "============================================"
echo "Done!"

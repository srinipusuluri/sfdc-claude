#!/usr/bin/env bash
# PostToolUse — auto-format Apex/LWC/XML files after Edit or Write
set -euo pipefail

PAYLOAD=$(cat)
FILE_PATH=$(printf '%s' "$PAYLOAD" | python3 -c \
  "import sys,json; d=json.load(sys.stdin); print(d.get('tool_input',{}).get('file_path',''))" 2>/dev/null || echo "")

# Only act on files inside force-app/
if ! echo "$FILE_PATH" | grep -q "force-app/"; then
  exit 0
fi

format_file() {
  local path="$1"
  local ext="${path##*.}"

  case "$ext" in
    cls|trigger)
      if command -v prettier >/dev/null 2>&1; then
        prettier --plugin=prettier-plugin-apex --write "$path" 2>/dev/null && \
          echo "  ✓ Formatted (prettier-apex): $(basename "$path")" || true
      fi
      ;;
    html|js|css)
      if command -v prettier >/dev/null 2>&1; then
        prettier --write "$path" 2>/dev/null && \
          echo "  ✓ Formatted (prettier): $(basename "$path")" || true
      fi
      ;;
    xml)
      if command -v xmllint >/dev/null 2>&1; then
        TMP=$(mktemp)
        xmllint --format "$path" > "$TMP" 2>/dev/null && mv "$TMP" "$path" && \
          echo "  ✓ Formatted (xmllint): $(basename "$path")" || rm -f "$TMP"
      fi
      ;;
  esac
}

format_file "$FILE_PATH"
exit 0  # Always exit 0 — formatter errors should never block editing

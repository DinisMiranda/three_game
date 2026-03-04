#!/usr/bin/env bash
# Run GdUnit4 tests from the project root.
# For macOS and Linux (also WSL / Git Bash on Windows).
# Requires Godot 4.x. Set GODOT_BIN if Godot is not in PATH.

set -e
cd "$(dirname "$0")"

if [ -z "$GODOT_BIN" ] || ! [ -x "$GODOT_BIN" ]; then
  if [ -n "$GODOT_BIN" ] && ! [ -x "$GODOT_BIN" ]; then
    echo "GODOT_BIN is set to '$GODOT_BIN' but that path is not executable."
  fi
  GODOT_BIN=""
  if command -v godot >/dev/null 2>&1; then
    GODOT_BIN=godot
  elif [ -x "/Applications/Godot.app/Contents/MacOS/Godot" ]; then
    GODOT_BIN="/Applications/Godot.app/Contents/MacOS/Godot"
  elif [ -x "/usr/bin/godot" ]; then
    GODOT_BIN="/usr/bin/godot"
  elif [ "$(uname -s)" = "Darwin" ]; then
    GODOT_APP=$(mdfind "kMDItemCFBundleIdentifier == 'org.godotengine.godot'" 2>/dev/null | head -1)
    if [ -z "$GODOT_APP" ]; then
      GODOT_APP=$(mdfind "kMDItemDisplayName == 'Godot'" 2>/dev/null | grep -E "Godot\.app$" | head -1)
    fi
    if [ -n "$GODOT_APP" ] && [ -x "$GODOT_APP/Contents/MacOS/Godot" ]; then
      GODOT_BIN="$GODOT_APP/Contents/MacOS/Godot"
    fi
  fi
  if [ -z "$GODOT_BIN" ]; then
    echo "Godot not found. Set GODOT_BIN to your Godot 4 executable, e.g.:"
    echo "  export GODOT_BIN=/path/to/Godot"
    echo "  ./run_tests.sh"
    exit 1
  fi
fi

export GODOT_BIN
chmod +x addons/gdUnit4/runtest.sh
./addons/gdUnit4/runtest.sh -a tests
exit_code=$?
if command -v python3 >/dev/null 2>&1; then
  python3 scripts/print_coverage.py
else
  chmod +x scripts/print_coverage.sh 2>/dev/null || true
  ./scripts/print_coverage.sh
fi
exit $exit_code

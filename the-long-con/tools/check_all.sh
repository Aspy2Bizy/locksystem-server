#!/usr/bin/env bash
# Parse-check every GDScript file. Usage: tools/check_all.sh  (needs `godot` on PATH)
# Autoload names (DataDB, Events, Session) are not registered in --check-only mode, so those errors are ignored.
set -u
cd "$(dirname "$0")/.."
fail=0
for f in $(find scripts tools tests -name '*.gd' | sort); do
  out=$(timeout 30 godot --headless --check-only -s "res://$f" 2>&1 | grep -E "SCRIPT ERROR|Parse Error|ERROR" | grep -vE "Identifier not found: (DataDB|Events|Session|DevTools|Net)|Failed to load script" | head -3)
  if [ -n "$out" ]; then echo "== $f"; echo "$out"; fail=1; fi
done
exit $fail

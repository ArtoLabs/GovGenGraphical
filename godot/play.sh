#!/bin/sh
# Start the Godot client. It wakes the Python engine (../bridge/server.py) by itself.
#   ./play.sh            use `godot` / `godot4` from the PATH, or a Godot 4 binary beside the GovGen folder
#   GODOT=/path/to/godot ./play.sh
here="$(cd "$(dirname "$0")" && pwd)"
godot="${GODOT:-}"
if [ -z "$godot" ]; then
  for candidate in "$(command -v godot4 2>/dev/null)" "$(command -v godot 2>/dev/null)" "$here"/../../Godot_v4*x86_64 "$here"/../Godot_v4*x86_64; do
    if [ -n "$candidate" ] && [ -x "$candidate" ]; then godot="$candidate"; break; fi
  done
fi
if [ -z "$godot" ]; then
  echo "Godot 4 was not found. Set GODOT=/path/to/the/godot/binary, or open godot/project.godot in the Godot editor and press F5." >&2
  exit 1
fi
if [ ! -d "$here/.godot" ]; then
  "$godot" --headless --path "$here" --import >/dev/null 2>&1   # first run: let Godot index the art
fi
exec "$godot" --path "$here" "$@"

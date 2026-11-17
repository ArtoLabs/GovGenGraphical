# GovGen in Godot

The graphical game: a scrolling, zoomable world with the HUD over it. It shows everything the terminal
HUD shows, with the same keys, plus the mouse.

It is a **client**. The game itself is still the Python engine in the folder above: this project starts
`bridge/server.py`, which runs the engine and tells the client what to draw. Every rule, the NPCs and the
saved game are the engine's, so nothing here can drift from the Python game, and both displays play the
same save (`saves/savegame.json`).

## Running

Open `godot/project.godot` in Godot 4.7 and press F5, or from this folder:

```bash
./play.sh
```

Python 3.10 or newer is needed. It is looked for in a `venv` or `.venv` beside the GovGen folder or
inside it, then as `python3`. The engine needs nothing installed for this (Textual is only for the
terminal HUD).

| To change | Set |
|---|---|
| which Python runs the engine | `GOVGEN_PYTHON=/path/to/python` |
| where the engine is | `GOVGEN_ENGINE_DIR=/path/to/GovGen` |
| the save file | `GOVGEN_SAVE_FILE=/path/to/save.json` |
| use an engine that is already running | `GOVGEN_CONNECT=127.0.0.1:47800` (start it with `python -m bridge.server`) |

## Playing

The clock never waits. Letters act, F-keys look, exactly as in the terminal HUD; every key is also a
keycap you can click (Tab shows or hides them).

| | |
|---|---|
| Drag, or ←↑↓→ (Shift: faster) | move the map |
| Wheel, or + and - | zoom |
| Home / End | back to the camp / find yourself and follow |
| Click the small map | jump there |
| Click a tile | what and who is there (status line) |
| Click a person | go to them; click again for their card |
| V N A D C F R O E W J X P H G I | the actions (vote, nominate, appoint, dismiss, call vote, reform, research, orders, needs, work, job, wake/stop, persuade, challenge, resign, inventory) |
| F1 F2 F3 F4 F7 F8 F9 F12 (or K) | help, tribe, government, innovations, log, you, society, crafts |
| Space, F5, F6, M | pause, speed, chronicle detail, auto/manual |
| F10 or Ctrl+Q, Esc | save and quit, the menu |
| F11 | full screen |

## What is drawn

- **The ground** is one shader over the whole 200 x 120 grid (`scripts/world/ground.gdshader`): terrain
  borders are bent and blended, water moves, shores foam, the camp has trodden earth, the land takes the
  season's colour and snow lies in winter.
- **Trees, rocks, reeds, flowers** are placed from each tile's own coordinates, so the world looks the
  same every time. They share a y-sorted layer with the people, who walk behind and in front of them.
- **The camp**: the fire (lit or out, with its light at night), the store, the workshop, the council
  ground, a sleeping mat for everyone.
- **People** are layered sprites (body, clothes, hair). They walk the paths the engine gives them, and
  their animation follows what they are doing. Office holders dress differently; children are smaller;
  the dead lie where they slept until they are laid to rest.
- **Places Scouts found** stand on the map with a badge of the trips left.
- **Day and night** tint the world; the top bar's wheel shows the time.

## How it is put together

```
scripts/core/net.gd           starts the engine, one JSON object per line over a local socket
scripts/core/game_state.gd    the latest view, the definitions, the chronicle (autoload G)
scripts/world/                the world: art.gd (every sprite's place), world.gd, person.gd, the shader
scripts/ui/                   the HUD's panels; kit.gd holds the colours, fonts and theme
scripts/ui/windows/           the F-key screens, the pickers, the inventory
scripts/dev/shot.gd           runs a scripted session and saves pictures (for checking)
tools/prepare_assets.py       copies the art out of the downloaded packs
```

The client holds no rules. It draws `engine.observe()` as it arrives (about five times a second) and
moves people along their paths in between. The picker behind each action key is built by the engine
(`ui/model.py`), as it is for the terminal HUD, so a new action, item, job or age made in the data files
shows up here without changing this project.

To put in better art, change the paths and rectangles in `scripts/world/art.gd`. Credits for what is
there now are in `CREDITS.md`.

## Checking it without playing

```bash
godot --path godot -- --shots=/tmp/out "--script=wait:2;call:start_new:5;state;wait:4;shot:main;key:F2;wait:1;shot:tribe;quit"
```

Set `GOVGEN_SAVE_FILE` first so your own save is left alone.

## Not done yet

- Buildings: the engine has none designed, so none are drawn.
- The engine must be on the same machine; an exported game would still need the GovGen folder and Python.
- Only one figure base (the LPC male body) for everyone; women and children differ by clothes and size.

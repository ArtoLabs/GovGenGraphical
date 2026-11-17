# Art and fonts in the Godot client

Everything under `assets/` comes from free packs, copied in by `tools/prepare_assets.py`.
The licence files that came with each pack are in `assets/licenses/`.

| What | Where it is used | By | Licence |
|---|---|---|---|
| `assets/terrain/lpc_terrain.png` | the ground textures, rocks and boulders, reeds, lilies, the standing stone | Liberated Pixel Cup contributors: Lanea Zimmerman (Sharm), Daniel Eddeland, Casper Nilsson, Matthew Nash, Nushio, William Thompsonj, Adrix89, Johann Charlot, Skyler Robert Colladay and others (full list: `assets/licenses/lpc_terrain_attribution.txt`) | CC-BY-SA 3.0 / GPL 3.0 |
| `assets/char/**` | every person: body, clothes, hair, the walking, working, spear and lying animations | Johannes Sjölund (wulax), on the Liberated Pixel Cup base figures by Stephen Challener (Redshrike) | Liberated Pixel Cup entry: CC-BY-SA 3.0 / GPL 3.0 (the pack's own README names no licence; check opengameart.org before you distribute) |
| `assets/trees/trees.png` | trees, bushes, ferns, flowers | Luis Zuno (ansimuz) | CC0 |
| `assets/props/roguelike.png` | the campfire, crates, sacks, stumps, logs, berry bushes | Kenney (kenney.nl), with Lynn Evers | CC0 |
| `assets/fonts/NotoColorEmoji.ttf` | every icon that the game data gives as an emoji (items, jobs, innovations, needs) | Google | SIL Open Font Licence 1.1 |

The CC-BY-SA art must keep its credit and stay under the same licence if you pass the game on.
Art you replace later only needs a new line in `scripts/world/art.gd` (and here).

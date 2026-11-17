#!/usr/bin/env python3
"""Copy the art the Godot client uses out of the downloaded asset packs into godot/assets/.

    python3 godot/tools/prepare_assets.py [path to the folder holding the packs]

The packs are expected as they unzip (default: ../assets next to the GovGen folder):
    terrain.png                     LPC terrain (CC-BY-SA 3.0 / GPL 3.0)
    lpc_entry/png/<animation>/      LPC character sheets, 64x64 frames (CC-BY-SA 3.0 / GPL 3.0)
    trees_and_bushes_pack/*.psd     trees and bushes by ansimuz (CC0)
    Spritesheet/roguelikeSheet_transparent.png   Kenney roguelike pack (CC0)
Only this script knows where things come from; scripts/world/art.gd knows where they are used.
Needs Pillow (for the layered tree file).
"""
import shutil
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parent / "assets"
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else HERE.parent.parent.parent / "assets"
ANIMATIONS = ["walkcycle", "slash", "thrust", "bow", "spellcast", "hurt"]


def copy(src: Path, dst: Path):
    dst.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(src, dst)


def main():
    if not SRC.is_dir():
        sys.exit(f"No asset packs at {SRC}")
    copy(SRC / "terrain.png", OUT / "terrain" / "lpc_terrain.png")
    for anim in ANIMATIONS:
        for f in sorted((SRC / "lpc_entry" / "png" / anim).glob("*.png")):
            copy(f, OUT / "char" / anim / f.name)
    copy(SRC / "Spritesheet" / "roguelikeSheet_transparent.png", OUT / "props" / "roguelike.png")
    # The trees come as a layered file: the layer with the trees (no background) on the full canvas.
    from PIL import Image
    from psd_layers import tree_layer
    (OUT / "trees").mkdir(parents=True, exist_ok=True)
    tree_layer(SRC / "trees_and_bushes_pack" / "trees-and-bushes.psd").save(OUT / "trees" / "trees.png")
    # Licences travel with the art.
    lic = OUT / "licenses"
    copy(SRC / "License.txt", lic / "kenney_roguelike_CC0.txt")
    copy(SRC / "Attribution.txt", lic / "lpc_terrain_attribution.txt")
    copy(SRC / "lpc_entry" / "README", lic / "lpc_characters_README.txt")
    copy(SRC / "trees_and_bushes_pack" / "license.txt", lic / "trees_and_bushes_CC0.txt")
    emoji = Path("/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf")
    if emoji.exists():
        copy(emoji, OUT / "fonts" / "NotoColorEmoji.ttf")
    else:
        print("Noto Color Emoji not found on this system: copy NotoColorEmoji.ttf into godot/assets/fonts/ yourself "
              "(icons in the game data are emoji).")
    print(f"Assets copied to {OUT}")


if __name__ == "__main__":
    sys.path.insert(0, str(HERE))
    main()

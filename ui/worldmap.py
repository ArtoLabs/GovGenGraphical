"""The world map on the HUD: a window onto world/map.py that scrolls like a top-down RPG map.

Fully zoomed out, a tile is two characters wide and one row high (about square in a terminal), drawn
with its terrain's glyphs and colours from data/rules/map.json. Zooming in (map.json 'zoom') draws
every tile two or three times as big, with the same texture, so the camp can be looked at closely.
On top of the ground are the things on it: the fire, the store, places found, and the people, who
are drawn where they are between tiles as they walk; zoomed in, each has their name under them.

The camera is the tile in the window's top-left corner; arrows, the mouse wheel or dragging move it,
and it stops at the edges of the world.

Only this file knows how anything is drawn. A graphical client (Godot) replaces it with a TileMapLayer,
sprites and a Camera2D over the same WorldMap and the same view data (core/movement.py observe()).
"""
from typing import Any, Dict, List, Optional, Tuple

from rich.cells import cell_len
from rich.segment import Segment
from rich.style import Style
from textual import events
from textual.message import Message
from textual.strip import Strip
from textual.widget import Widget

from world.map import BY_CODE, CAMP, HOME, ZOOM_LEVELS, WorldMap, position_at

VOID = Style(bgcolor="#05070c")
STRUCTURE = "#f0e0b0"
YOU, ADULT, CHILD, WALKING = "#7dff6b", "#ffffff", "#ffd9a0", "#fff27a"
LABEL = "#e8e8e8"
MARKERS = CAMP.get("markers", {})


class WorldMapView(Widget):
    """A scrolling, zooming view of a WorldMap and the people on it."""

    class TileClicked(Message):
        def __init__(self, x: int, y: int):
            super().__init__()
            self.x, self.y = x, y

    def __init__(self, world: WorldMap, **kwargs):
        super().__init__(**kwargs)
        self.world = world
        self.cam_x = self.cam_y = 0     # the tile in the top-left corner
        self.zoom = ZOOM_LEVELS[0]      # rows of text per tile (a tile is twice as many characters wide)
        self.margins = (0, 0, 0, 0)     # screen cells covered by panels: left, top, right, bottom
        self.scene: Optional[Dict[str, Any]] = None   # the engine's view of the map (people, spots, sites)
        self.clock = 0.0
        self._centred = False
        self._drag: Optional[Tuple[int, int, int, int]] = None  # screen x, y and camera x, y when it began
        self._dragged = False
        self._styles: Dict[Tuple[str, str, bool], Style] = {}
        self._rows: Dict[Tuple[int, int], Tuple[List[str], List[str]]] = {}   # (zoom, row) -> chars, backgrounds
        self._things: Dict[int, List[Tuple[int, str, str, bool]]] = {}        # row -> (column, text, colour, bold)

    # ------------------------------------------------------------------ #
    # Camera and zoom
    # ------------------------------------------------------------------ #
    @property
    def tile_width(self) -> int:
        return 2 * self.zoom

    @property
    def tiles_wide(self) -> int:
        return max(1, self.size.width // self.tile_width)

    @property
    def tiles_high(self) -> int:
        return max(1, self.size.height // self.zoom)

    def move_to(self, x: int, y: int):
        """Put tile (x, y) in the top-left corner, as far as the edges of the world allow."""
        x = max(0, min(x, self.world.width - self.tiles_wide))
        y = max(0, min(y, self.world.height - self.tiles_high))
        if (x, y) != (self.cam_x, self.cam_y):
            self.cam_x, self.cam_y = x, y
            self.refresh()

    def pan(self, dx: int, dy: int):
        self.move_to(self.cam_x + dx, self.cam_y + dy)

    def _middle(self) -> Tuple[int, int]:
        """The screen cell in the middle of the part of the map that no panel covers."""
        left, top, right, bottom = self.margins
        return (left + (self.size.width - right)) // 2, (top + (self.size.height - bottom)) // 2

    def centre_on(self, x: float, y: float):
        """Show tile (x, y) in the middle of the part of the map that no panel covers."""
        mx, my = self._middle()
        self.move_to(int(round(x - mx / self.tile_width)), int(round(y - my / self.zoom)))

    def centre_on_home(self):
        self.centre_on(*self.world.home)

    def centre_on_person(self, name: str) -> bool:
        for p in (self.scene or {}).get("people", []):
            if p["name"] == name:
                self.centre_on(*position_at(p["pos"], p["legs"], self.clock))
                return True
        return False

    def set_zoom(self, step: int) -> int:
        """Zoom in (+1) or out (-1) a level, keeping what is in the middle of the open map in the middle."""
        i = ZOOM_LEVELS.index(self.zoom) if self.zoom in ZOOM_LEVELS else 0
        new = ZOOM_LEVELS[max(0, min(len(ZOOM_LEVELS) - 1, i + step))]
        if new != self.zoom:
            mx, my = self._middle()
            cx, cy = self.cam_x + mx / self.tile_width, self.cam_y + my / self.zoom
            self.zoom = new
            self.cam_x = self.cam_y = -1  # force the move
            self._place_things()
            self.centre_on(cx, cy)
            self.refresh()
        return self.zoom

    def tile_at(self, x: int, y: int) -> Tuple[int, int]:
        """The tile under a point of this widget."""
        return self.cam_x + x // self.tile_width, self.cam_y + y // self.zoom

    def on_resize(self):
        if not self._centred and self.size.width and self.size.height:
            self._centred = True
            self.centre_on_home()
        else:
            self.move_to(self.cam_x, self.cam_y)  # keep inside the world

    # ------------------------------------------------------------------ #
    # What is on the ground: the fire, the store, places found, people
    # ------------------------------------------------------------------ #
    def show(self, scene: Optional[Dict[str, Any]], clock: float):
        """The latest view of the map and the moment to draw it at (people move between views)."""
        self.scene, self.clock = scene, clock
        before = self._things
        self._place_things()
        if self._things != before:
            self.refresh()

    def people_at(self, x: int, y: int) -> List[str]:
        out = []
        for p in (self.scene or {}).get("people", []):
            px, py = position_at(p["pos"], p["legs"], self.clock)
            if (int(round(px)), int(round(py))) == (x, y):
                out.append(p["name"])
        return out

    def _put(self, x: float, y: float, text: str, colour: str, bold: bool = True, row: int = 0):
        """Draw `text` centred on the middle of tile position (x, y), `row` rows below its middle row."""
        z = self.zoom
        line = int(round(y * z)) + (z - 1) // 2 + row
        col = int(round(x * 2 * z)) + z - cell_len(text) // 2 - (cell_len(text) % 2)
        self._things.setdefault(line, []).append((max(0, col), text, colour, bold))

    def _place_things(self):
        self._things = {}
        scene = self.scene
        z = self.zoom
        if scene is None:
            self._put(*self.world.home, HOME.get("marker", "⌂"), "#ffffff")
            return
        for s in scene.get("sites", []):
            self._put(s["x"], s["y"], s["icon"], "#ffffff")
        for name, (x, y) in scene.get("spots", {}).items():
            if name == "fire":
                self._put(x, y, MARKERS.get("fire", "*") if scene.get("fire_burning") else MARKERS.get("fire_out", "░░"),
                          "#ff9a3c" if scene.get("fire_burning") else "#777777")
            elif name in MARKERS:
                self._put(x, y, MARKERS[name], "#e0c080")
            elif z >= 2:
                self._put(x, y, name, "#b0a890", bold=False, row=1)
        # People last, so they show on top. Those on the same spot share it: one figure and a count.
        spots: Dict[Tuple[int, int], List[Dict[str, Any]]] = {}
        for p in scene.get("people", []):
            x, y = position_at(p["pos"], p["legs"], self.clock)
            p = dict(p, x=x, y=y, walking=any(leg["t0"] <= self.clock < leg["t1"] for leg in p["legs"]))
            spots.setdefault((int(round(x * 2 * z)), int(round(y * z))), []).append(p)
        for group in spots.values():
            group.sort(key=lambda p: not p["you"])
            p = group[0]
            colour = YOU if p["you"] else WALKING if p["walking"] else CHILD if p["child"] else ADULT
            figure = "☺" if p["child"] else "☻"
            self._put(p["x"], p["y"], figure + (str(min(len(group), 9)) if len(group) > 1 else " "), colour)
            if z >= 2:
                room = 2 * z + 2
                label = p["name"][:room] if len(group) == 1 else (p["name"][:room - 2] + f"+{len(group) - 1}")
                self._put(p["x"], p["y"], label, YOU if p["you"] else LABEL, bold=p["you"], row=1)

    # ------------------------------------------------------------------ #
    # Drawing
    # ------------------------------------------------------------------ #
    def _style(self, colour: str, background: str, bold: bool = False) -> Style:
        key = (colour, background, bold)
        style = self._styles.get(key)
        if style is None:
            style = self._styles[key] = Style(color=colour, bgcolor=background, bold=bold)
        return style

    def _ground(self, row: int) -> Tuple[List[str], List[str], List[str]]:
        """One row of the whole map at this zoom, a cell at a time: characters, colours, backgrounds."""
        key = (self.zoom, row)
        found = self._rows.get(key)
        if found is None:
            z, world = self.zoom, self.world
            ty = row // z
            chars: List[str] = []
            colours: List[str] = []
            grounds: List[str] = []
            for tx in range(world.width):
                structure = world.structure_at(tx, ty)
                terrain = BY_CODE[world.tiles[ty][tx]]
                for sub in range(z):
                    px = tx * z + sub  # each tile is z by z patches, each two characters: the same texture, bigger
                    glyph = structure.glyph if structure is not None else \
                        terrain.glyphs[((px * 73856093) ^ (row * 19349663)) % len(terrain.glyphs)]
                    chars.extend(glyph)
                    colours.extend((STRUCTURE if structure is not None else terrain.color,) * 2)
                    grounds.extend((terrain.background,) * 2)
            found = self._rows[key] = (chars, colours, grounds)
        return found

    def render_line(self, y: int) -> Strip:
        width = self.size.width
        z = self.zoom
        row = self.cam_y * z + y
        if not 0 <= row < self.world.height * z:
            return Strip([Segment(" " * width, VOID)], width)
        chars, colours, grounds = self._ground(row)
        first = self.cam_x * 2 * z
        last = min(len(chars), first + width)
        text = chars[first:last]
        colour = colours[first:last]
        bold = [False] * len(text)
        for col, label, tint, strong in self._things.get(row, ()):
            at = col - first
            for ch in label:
                wide = cell_len(ch)
                if wide and 0 <= at and at + wide <= len(text):
                    text[at], colour[at], bold[at] = ch, tint, strong
                    if wide == 2:
                        text[at + 1] = ""
                at += wide
        segments: List[Segment] = []
        run: List[str] = []
        current: Optional[Style] = None
        ground = grounds[first:last]
        for i, ch in enumerate(text):
            style = self._style(colour[i], ground[i], bold[i])
            if style is not current:
                if run:
                    segments.append(Segment("".join(run), current))
                run, current = [], style
            run.append(ch)
        if run:
            segments.append(Segment("".join(run), current))
        if len(text) < width:
            segments.append(Segment(" " * (width - len(text)), VOID))
        return Strip(segments).crop(0, width)

    # ------------------------------------------------------------------ #
    # Mouse: drag to move the map, wheel to scroll it, click a tile to ask what it is
    # ------------------------------------------------------------------ #
    def on_mouse_down(self, event: events.MouseDown):
        self._drag = (event.screen_x, event.screen_y, self.cam_x, self.cam_y)
        self._dragged = False
        self.capture_mouse()

    def on_mouse_move(self, event: events.MouseMove):
        if self._drag is None:
            return
        sx, sy, cx, cy = self._drag
        dx, dy = (sx - event.screen_x) // self.tile_width, (sy - event.screen_y) // self.zoom
        if dx or dy:
            self._dragged = True
        self.move_to(cx + dx, cy + dy)

    def on_mouse_up(self, event: events.MouseUp):
        if self._drag is None:
            return
        self._drag = None
        self.release_mouse()
        if not self._dragged:
            x, y = self.tile_at(event.x, event.y)
            if self.world.in_bounds(x, y):
                self.post_message(self.TileClicked(x, y))

    def on_mouse_scroll_up(self, event: events.MouseScrollUp):
        if event.ctrl:
            self.set_zoom(1)
        else:
            self.pan(-3, 0) if event.shift else self.pan(0, -2)

    def on_mouse_scroll_down(self, event: events.MouseScrollDown):
        if event.ctrl:
            self.set_zoom(-1)
        else:
            self.pan(3, 0) if event.shift else self.pan(0, 2)

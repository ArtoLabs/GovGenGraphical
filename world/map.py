"""The world map: a grid of square tiles, each one kind of terrain (data/rules/map.json).

Like world/items.py this knows nothing of governments, the engine or any display, and it is not yet
tied to the game's rules: nobody walks on it and nothing is built on it. What is here:

    TERRAIN            every kind of terrain (name, whether it can be walked or built on, how slow it is)
    WorldMap           the grid, where home is, the camp's spots (fire, store, beds...), and the
                       structures standing on it; finds paths (find_path) and places to do things (pick)
    generate(seed)     grow a world from a seed: the same seed always gives the same world
    world_map()        the game's map (data/rules/map.json says how big, and which seed)

The grid is plain data, laid out the way a tile engine wants it (Godot's TileMapLayer, Unreal's Paper
tile maps): `tiles[y][x]` is a one-character terrain code, x grows east and y grows south, and a
structure covers a rectangle of whole tiles. to_dict() gives the map as rows of text, one character per
tile, which any engine can read back. How a tile LOOKS is the display's business: the text HUD draws
the glyphs and colours in map.json; a graphical client uses its own art per terrain key.
"""
import heapq
import random
from dataclasses import dataclass, field
from typing import Any, Dict, Iterator, List, Optional, Tuple

from utils.data_files import load_json, require
from utils.game_data import RULES_DIR, public

_data = load_json(RULES_DIR / "map.json")
GENERATION: Dict[str, Any] = _data["generation"]
HOME: Dict[str, Any] = public(_data.get("home", {}))
CAMP: Dict[str, Any] = public(_data.get("camp", {}))
TRAVEL: Dict[str, Any] = public(_data.get("travel", {}))
PLACES: Dict[str, Dict[str, Any]] = public(_data.get("places", {}))
SITE_RANGE: Dict[str, Any] = public(_data.get("sites", {}))
ZOOM_LEVELS: List[int] = [int(z) for z in _data.get("zoom", {}).get("levels", [1])]
CAMP_SPOTS = ("fire", "store", "workshop", "council", "bed", "by_fire")
Tile = Tuple[int, int]
_STEPS = ((1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (1, -1), (-1, 1), (-1, -1))
_DIAGONAL = 1.41421356


@dataclass(frozen=True)
class Terrain:
    key: str
    code: str            # one character: this terrain in a saved map
    name: str
    description: str = ""
    walkable: bool = True
    buildable: bool = False
    move_cost: float = 1   # how slow it is to cross (1: open ground)
    fresh_water: bool = False
    glyphs: Tuple[str, ...] = ("  ",)   # text display: two characters per tile, mixed for texture
    color: str = "#ffffff"
    background: str = "#000000"


def _load_terrain() -> Dict[str, Terrain]:
    found: Dict[str, Terrain] = {}
    for key, d in public(_data["terrain"]).items():
        where = f"map.json terrain '{key}'"
        require(isinstance(d.get("code"), str) and len(d["code"]) == 1, where, "needs a 'code' of one character")
        require(all(len(g) == 2 for g in d.get("glyphs", ["  "])), where, "every glyph must be two characters")
        found[key] = Terrain(key=key, code=d["code"], name=d.get("name", key), description=d.get("description", ""),
                             walkable=d.get("walkable", True), buildable=d.get("buildable", False),
                             move_cost=d.get("move_cost", 1), fresh_water=d.get("fresh_water", False),
                             glyphs=tuple(d.get("glyphs", ["  "])), color=d.get("color", "#ffffff"),
                             background=d.get("background", "#000000"))
    require(len({t.code for t in found.values()}) == len(found), "map.json", "two terrains share a 'code'")
    return found


TERRAIN: Dict[str, Terrain] = _load_terrain()
BY_CODE: Dict[str, Terrain] = {t.code: t for t in TERRAIN.values()}
for _key, _place in PLACES.items():
    require(_place.get("at") in (None, *CAMP_SPOTS), f"map.json places '{_key}'", f"unknown camp spot '{_place.get('at')}'")
    for _name in _place.get("terrain", []):
        require(_name in TERRAIN, f"map.json places '{_key}'", f"unknown terrain '{_name}'")
for _name in [lv["terrain"] for lv in GENERATION["levels"] if lv["terrain"] != "land"] + \
             [lv["terrain"] for lv in GENERATION["land"]] + \
             [GENERATION["marsh"]["terrain"], GENERATION["rivers"]["terrain"]]:
    require(_name in TERRAIN, "map.json generation", f"unknown terrain '{_name}'")


@dataclass
class Structure:
    """Something built on the map: it covers the rectangle of tiles from (x, y), `width` by `height`."""
    key: str
    name: str
    x: int
    y: int
    width: int = 1
    height: int = 1
    glyph: str = "▓▓"   # text display: drawn on each of its tiles

    def tiles(self) -> Iterator[Tuple[int, int]]:
        return ((self.x + dx, self.y + dy) for dy in range(self.height) for dx in range(self.width))

    def to_dict(self) -> Dict[str, Any]:
        return {"key": self.key, "name": self.name, "x": self.x, "y": self.y, "width": self.width,
                "height": self.height, "glyph": self.glyph}


@dataclass
class WorldMap:
    width: int
    height: int
    tiles: List[List[str]]                 # tiles[y][x]: a terrain code
    home: Tuple[int, int] = (0, 0)         # the tile the camp (village, city...) is centred on
    seed: Optional[int] = None
    structures: List[Structure] = field(default_factory=list)
    spots: Dict[str, Tile] = field(default_factory=dict)   # the camp's named places: fire, store, workshop...
    beds: List[Tile] = field(default_factory=list)         # sleeping places around the fire
    _occupied: Dict[Tuple[int, int], Structure] = field(default_factory=dict, repr=False)
    _walk: Optional[List[List[float]]] = field(default=None, repr=False)   # walk from the fire to every tile
    _candidates: Dict[str, List[Tuple[float, Tile]]] = field(default_factory=dict, repr=False)

    def in_bounds(self, x: int, y: int) -> bool:
        return 0 <= x < self.width and 0 <= y < self.height

    def terrain_at(self, x: int, y: int) -> Optional[Terrain]:
        return BY_CODE[self.tiles[y][x]] if self.in_bounds(x, y) else None

    def set_terrain(self, x: int, y: int, key: str):
        self.tiles[y][x] = TERRAIN[key].code

    def structure_at(self, x: int, y: int) -> Optional[Structure]:
        return self._occupied.get((x, y))

    def can_build(self, x: int, y: int, width: int = 1, height: int = 1) -> bool:
        """True if a structure `width` by `height` tiles fits with its top-left corner at (x, y): every
        tile is on the map, buildable ground, and free."""
        for ty in range(y, y + height):
            for tx in range(x, x + width):
                t = self.terrain_at(tx, ty)
                if t is None or not t.buildable or (tx, ty) in self._occupied:
                    return False
        return True

    def build(self, structure: Structure) -> bool:
        if not self.can_build(structure.x, structure.y, structure.width, structure.height):
            return False
        self.structures.append(structure)
        for tile in structure.tiles():
            self._occupied[tile] = structure
        return True

    def remove(self, structure: Structure):
        self.structures.remove(structure)
        for tile in structure.tiles():
            self._occupied.pop(tile, None)

    def near(self, x: int, y: int, radius: int) -> Iterator[Tuple[int, int]]:
        """Every tile on the map within `radius` tiles of (x, y), diagonals included."""
        for ty in range(max(0, y - radius), min(self.height, y + radius + 1)):
            for tx in range(max(0, x - radius), min(self.width, x + radius + 1)):
                yield tx, ty

    def describe(self, x: int, y: int) -> str:
        """'Forest: woodland...' for the tile, or what stands on it."""
        t = self.terrain_at(x, y)
        if t is None:
            return "The edge of the world."
        s = self.structure_at(x, y)
        if s:
            return f"{s.name}, on {t.name.lower()}."
        can = "can be built on" if t.buildable else "can't be built on"
        return f"{t.name}: {t.description} ({can})"

    def to_dict(self) -> Dict[str, Any]:
        return {"width": self.width, "height": self.height, "seed": self.seed, "home": list(self.home),
                "rows": ["".join(row) for row in self.tiles],
                "structures": [s.to_dict() for s in self.structures]}

    @classmethod
    def from_dict(cls, d: Dict[str, Any]) -> 'WorldMap':
        m = cls(d["width"], d["height"], [list(row) for row in d["rows"]], tuple(d["home"]), d.get("seed"))
        for s in d.get("structures", []):
            m.build(Structure(**s))
        m.lay_out_camp()
        return m

    # ------------------------------------------------------------------ #
    # Walking
    # ------------------------------------------------------------------ #
    def walkable(self, x: int, y: int) -> bool:
        return self.in_bounds(x, y) and BY_CODE[self.tiles[y][x]].walkable

    def step_cost(self, a: Tile, b: Tile) -> float:
        """How long the step from tile a to the tile b next to it takes, in tiles of open ground: the
        ground stepped onto sets the pace, and a diagonal step is longer."""
        cost = BY_CODE[self.tiles[b[1]][b[0]]].move_cost
        return cost * _DIAGONAL if a[0] != b[0] and a[1] != b[1] else cost

    def path_cost(self, path: List[Tile]) -> float:
        return sum(self.step_cost(a, b) for a, b in zip(path, path[1:]))

    def _neighbours(self, x: int, y: int) -> Iterator[Tile]:
        for dx, dy in _STEPS:
            nx, ny = x + dx, y + dy
            if self.walkable(nx, ny) and (not (dx and dy) or (self.walkable(x + dx, y) and self.walkable(x, y + dy))):
                yield nx, ny  # no cutting a corner between two tiles that can't be crossed

    def find_path(self, start: Tile, goal: Tile) -> List[Tile]:
        """The quickest way on foot from one tile to another, as the list of tiles walked (both ends
        included). A* over the eight neighbours. If the goal can't be reached, the way to the reachable
        tile nearest to it; [start] if there is nowhere to go."""
        start, goal = (int(start[0]), int(start[1])), (int(goal[0]), int(goal[1]))
        if start == goal:
            return [start]

        def reach(a: Tile) -> float:  # never more than the real cost: every step costs at least 1 a tile
            dx, dy = abs(a[0] - goal[0]), abs(a[1] - goal[1])
            return max(dx, dy) + (_DIAGONAL - 1) * min(dx, dy)

        came: Dict[Tile, Tile] = {}
        cost = {start: 0.0}
        heap = [(reach(start), 0.0, start)]
        closest, closest_far = start, reach(start)
        done = set()
        while heap:
            _, so_far, here = heapq.heappop(heap)
            if here in done:
                continue
            done.add(here)
            if here == goal:
                closest = goal
                break
            far = reach(here)
            if far < closest_far:
                closest, closest_far = here, far
            if len(done) > 20000:
                break
            for nxt in self._neighbours(*here):
                new = so_far + self.step_cost(here, nxt)
                if new < cost.get(nxt, 1e18):
                    cost[nxt] = new
                    came[nxt] = here
                    heapq.heappush(heap, (new + reach(nxt), new, nxt))
        path = [closest]
        while path[-1] != start:
            path.append(came[path[-1]])
        return path[::-1]

    def walk_from_fire(self) -> List[List[float]]:
        """For every tile, how long the walk from the fire is, in tiles of open ground (inf: no way)."""
        if self._walk is None:
            inf = float("inf")
            walk = [[inf] * self.width for _ in range(self.height)]
            fire = self.spots.get("fire", self.home)
            walk[fire[1]][fire[0]] = 0.0
            heap = [(0.0, fire)]
            while heap:
                so_far, here = heapq.heappop(heap)
                if so_far > walk[here[1]][here[0]]:
                    continue
                for nxt in self._neighbours(*here):
                    new = so_far + self.step_cost(here, nxt)
                    if new < walk[nxt[1]][nxt[0]]:
                        walk[nxt[1]][nxt[0]] = new
                        heapq.heappush(heap, (new, nxt))
            self._walk = walk
        return self._walk

    def distance_from_fire(self, x: float, y: float) -> float:
        """Tiles from the fire as the crow flies."""
        fx, fy = self.spots.get("fire", self.home)
        return max(abs(x - fx), abs(y - fy))

    def in_camp(self, x: float, y: float) -> bool:
        return self.distance_from_fire(x, y) <= CAMP.get("radius", 8)

    # ------------------------------------------------------------------ #
    # The camp, and places to do things
    # ------------------------------------------------------------------ #
    def lay_out_camp(self):
        """Put the camp's spots around the fire (map.json 'camp'): the fire on the home tile, each named
        spot on the free walkable tile nearest to where the file puts it, and a ring of sleeping places."""
        hx, hy = self.home
        self.spots = {"fire": (hx, hy)}
        taken = {(hx, hy)}

        def nearest_free(x: int, y: int) -> Tile:
            for r in range(0, 12):
                ring = sorted((t for t in self.near(x, y, r) if max(abs(t[0] - x), abs(t[1] - y)) == r),
                              key=lambda t: (t[0] - x) ** 2 + (t[1] - y) ** 2)
                for t in ring:
                    if t not in taken and self.walkable(*t) and self.terrain_at(*t).buildable:
                        return t
            return hx, hy

        for name, (dx, dy) in CAMP.get("spots", {}).items():
            self.spots[name] = nearest_free(hx + dx, hy + dy)
            taken.add(self.spots[name])
        near, far = CAMP.get("beds", [2, 3])
        self.beds = [t for t in self.near(hx, hy, far)
                     if near <= max(abs(t[0] - hx), abs(t[1] - hy)) <= far and t not in taken and self.walkable(*t)]
        self.beds.sort(key=lambda t: ((t[0] * 7919 + t[1] * 104729) % 97, t))  # scattered, the same every time
        self._walk, self._candidates = None, {}

    def spot(self, name: str, rng: Optional[random.Random] = None, bed: Optional[Tile] = None) -> Tile:
        """The tile of a camp spot. 'by_fire' is one of the tiles next to the fire; 'bed' is `bed`."""
        fire = self.spots.get("fire", self.home)
        if name == "bed":
            return bed or fire
        if name == "by_fire":
            around = [t for t in self._neighbours(*fire) if t not in self.spots.values()] or [fire]
            return (rng or random).choice(around)
        return self.spots.get(name, fire)

    def _place_tiles(self, key: str, spec: Dict[str, Any]) -> List[Tuple[float, Tile]]:
        """Every tile a kind of place could be, nearest first by the walk from the fire."""
        if key not in self._candidates:
            walk = self.walk_from_fire()
            codes = {TERRAIN[k].code for k in spec["terrain"]} if spec.get("terrain") else None
            spots = set(self.spots.values())
            found = [(walk[y][x], (x, y)) for y in range(self.height) for x in range(self.width)
                     if walk[y][x] != float("inf") and (codes is None or self.tiles[y][x] in codes)
                     and (x, y) not in spots]
            found.sort()
            self._candidates[key] = found
        return self._candidates[key]

    def pick(self, place: str, rng: random.Random, min_distance: Optional[float] = None,
             max_distance: Optional[float] = None) -> Optional[Tile]:
        """A tile for a kind of place out on the map (map.json 'places'): of its terrain, between its
        distances from the fire (or those given), one of its 'nearest'. If nothing lies in that range, the
        nearest tile of that terrain beyond it. None if the map has no such ground at all."""
        spec = PLACES.get(place, {})
        tiles = self._place_tiles(place, spec)
        if not tiles:
            return None
        low = spec.get("min_distance", 0) if min_distance is None else min_distance
        high = spec.get("max_distance", float("inf")) if max_distance is None else max_distance
        ranged = [t for d, t in tiles if low <= d <= high]
        if not ranged:
            beyond = [t for d, t in tiles if d >= low]
            return beyond[0] if beyond else tiles[-1][1]
        nearest = spec.get("nearest")
        return rng.choice(ranged[:int(nearest)] if nearest else ranged)

    @staticmethod
    def is_trip(place: str) -> bool:
        """Is this kind of place out on the map (a trip there and back), not a spot in camp?"""
        spec = PLACES.get(place, {})
        return "at" not in spec and not spec.get("stay")


# --------------------------------------------------------------------------- #
# Growing a world
# --------------------------------------------------------------------------- #
def _noise(rng: random.Random, width: int, height: int, feature: float, octaves: int) -> List[List[float]]:
    """A width x height field of smooth random values, 0 to 1: layers of value noise, each twice as
    fine and half as strong as the one before."""
    field_ = [[0.0] * width for _ in range(height)]
    strength, size = 1.0, max(2.0, float(feature))
    for _ in range(max(1, octaves)):
        gw, gh = int(width / size) + 2, int(height / size) + 2
        grid = [[rng.random() for _ in range(gw)] for _ in range(gh)]
        for y in range(height):
            fy = y / size
            y0 = int(fy)
            ty = fy - y0
            ty = ty * ty * (3 - 2 * ty)
            top, bottom, row = grid[y0], grid[y0 + 1], field_[y]
            for x in range(width):
                fx = x / size
                x0 = int(fx)
                tx = fx - x0
                tx = tx * tx * (3 - 2 * tx)
                a = top[x0] + (top[x0 + 1] - top[x0]) * tx
                b = bottom[x0] + (bottom[x0 + 1] - bottom[x0]) * tx
                row[x] += (a + (b - a) * ty) * strength
        strength, size = strength / 2, max(2.0, size / 2)
    return field_


def _stretch(field_: List[List[float]]):
    """Rescale a field in place so that its values run from 0 to 1."""
    low = min(min(row) for row in field_)
    span = (max(max(row) for row in field_) - low) or 1.0
    for row in field_:
        for x, v in enumerate(row):
            row[x] = (v - low) / span


def _pick(levels: List[Dict[str, Any]], value: float) -> str:
    return next((lv["terrain"] for lv in levels if value < lv["below"]), levels[-1]["terrain"])


def _run_rivers(rng: random.Random, m: WorldMap, heights: List[List[float]]):
    """Rivers start on high ground and run downhill, tile by tile, until they meet water."""
    rules = GENERATION["rivers"]
    river = TERRAIN[rules["terrain"]].code
    high = {TERRAIN[k].code for k in ("hills", "mountains") if k in TERRAIN}
    wet = {t.code for t in TERRAIN.values() if not t.buildable and not t.walkable or t.key == "water"} | {river}
    springs = [(x, y) for y in range(m.height) for x in range(m.width) if m.tiles[y][x] in high]
    rng.shuffle(springs)
    made = 0
    for x, y in springs:
        if made >= rules.get("count", 0):
            break
        if any(m.tiles[ty][tx] == river for tx, ty in m.near(x, y, 12)):
            continue  # too close to another river's course
        path, seen = [], {(x, y)}
        for _ in range(rules.get("max_length", 200)):
            path.append((x, y))
            steps = [(heights[ny][nx] + rng.random() * 0.004, nx, ny)
                     for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
                     if m.in_bounds(nx, ny) and (nx, ny) not in seen]
            if not steps:
                break
            _, x, y = min(steps)
            seen.add((x, y))
            if m.tiles[y][x] in wet and BY_CODE[m.tiles[y][x]].key != "peaks":
                break
        else:
            continue  # never reached water: not a river
        if len(path) < 12:
            continue
        for px, py in path:
            if BY_CODE[m.tiles[py][px]].key != "peaks":
                m.tiles[py][px] = river
        made += 1


def _find_home(m: WorldMap) -> Tuple[int, int]:
    """Open, buildable ground as near the middle of the map as there is, with clear ground around it and
    (if anywhere has it) fresh water close by."""
    clear, reach = HOME.get("clear", 1), HOME.get("near_water", 3)
    cx, cy = m.width // 2, m.height // 2
    best: Dict[bool, Tuple[float, Tuple[int, int]]] = {}
    for y in range(m.height):
        for x in range(m.width):
            if not all(m.terrain_at(tx, ty).buildable for tx, ty in m.near(x, y, clear)) or \
                    len(list(m.near(x, y, clear))) < (2 * clear + 1) ** 2:
                continue
            dist = (x - cx) ** 2 + (y - cy) ** 2
            if True in best and dist >= best[True][0]:
                continue
            watered = any(m.terrain_at(tx, ty).fresh_water for tx, ty in m.near(x, y, reach))
            if watered in best and dist >= best[watered][0]:
                continue
            best[watered] = (dist, (x, y))
    choice = best.get(True) or best.get(False)
    return choice[1] if choice else (cx, cy)


def generate(seed: Optional[int] = None, width: Optional[int] = None, height: Optional[int] = None) -> WorldMap:
    """Grow a world. It uses its own random generator, never the game's, so making a map changes nothing
    about how a seeded game plays out."""
    if seed is None:
        seed = random.Random().randrange(1 << 30)
    rng = random.Random(seed)
    width, height = int(width or _data["width"]), int(height or _data["height"])
    g = GENERATION
    heights = _noise(rng, width, height, g["feature_size"], g["octaves"])
    wetness = _noise(rng, width, height, g.get("moisture_feature_size", g["feature_size"]), g["octaves"])
    _stretch(heights)
    falloff = g.get("edge_falloff", 0)
    for y in range(height):
        for x in range(width):
            edge = max(abs(2 * x / (width - 1) - 1), abs(2 * y / (height - 1) - 1)) if width > 1 and height > 1 else 0
            heights[y][x] -= falloff * edge ** 3 * heights[y][x]
    _stretch(heights)
    _stretch(wetness)
    marsh = g["marsh"]
    tiles = []
    for y in range(height):
        row = []
        for x in range(width):
            h, w = heights[y][x], wetness[y][x]
            key = _pick(g["levels"], h)
            if key == "land":
                key = marsh["terrain"] if h < marsh["below"] and w >= marsh["wetness"] else _pick(g["land"], w)
            row.append(TERRAIN[key].code)
        tiles.append(row)
    m = WorldMap(width, height, tiles, seed=seed)
    _run_rivers(rng, m, heights)
    m.home = _find_home(m)
    m.lay_out_camp()
    return m


_world: Optional[WorldMap] = None


def world_map() -> WorldMap:
    """The game's map, grown once from the seed in data/rules/map.json."""
    global _world
    if _world is None:
        _world = generate(_data.get("seed"))
    return _world


def position_at(pos: Tuple[float, float], legs: List[Dict[str, Any]], clock: float) -> Tuple[float, float]:
    """Where someone is at `clock`: `pos` is where they end up once every leg of their walk is done; a
    leg is {'t0', 't1', 'path': [[x, y]...], 'at': [how far along the path each tile is, 0 to 1]}.
    Between two tiles they are part way (fractions), so a display can move them smoothly."""
    for leg in legs:
        if clock < leg["t0"]:
            return tuple(leg["path"][0])
        if clock < leg["t1"]:
            share = (clock - leg["t0"]) / max(1e-9, leg["t1"] - leg["t0"])
            path, at = leg["path"], leg["at"]
            for i in range(1, len(path)):
                if share <= at[i]:
                    part = (share - at[i - 1]) / max(1e-9, at[i] - at[i - 1])
                    (ax, ay), (bx, by) = path[i - 1], path[i]
                    return ax + (bx - ax) * part, ay + (by - ay) * part
            return tuple(path[-1])
    return tuple(legs[-1]["path"][-1]) if legs else tuple(pos)

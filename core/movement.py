"""People's bodies on the world map: where everyone is, and the walking that every action now takes.

The rules of the game are untouched. An action still keeps someone busy until a moment set when they
begin it; what is new is that the moment depends on the walk. When an action begins, this module
works out where it is done (the fire, the store, a bed, the nearest woods, a place a Scout found...),
finds the way there on foot (world/map.py find_path) and lays out a plan:

    work at a spot in camp     walk there, then all of the work's own time
    a trip out of camp         walk there, the work on the spot (travel.trip_work_share of the task's
                               time), then walk back to the store with what was found
    eat, sleep, warm up, rest  walk to the fire or to one's own sleeping place, then the usual time

Where someone is at any moment follows from their plan (world.map.position_at), so nothing has to
tick: the display asks where everyone is whenever it draws. Taking from or putting into the store needs
a body in camp, and shows as a walk to the store.

Politics (voting, nominating, appointing, persuading...) takes no walking: it is done in passing, as
before, even in the middle of other work.

Everything about the map is in data/rules/map.json ('camp', 'travel', 'places', 'sites'); a task says
where it is done with its 'place'.
"""
import random
from typing import Any, Dict, List, Optional, Tuple

from core import work as WORK
from core.actions import Action
from world import environment
from world.character import RULES as CHARACTER
from world.map import CAMP, PLACES, SITE_RANGE, TRAVEL, Tile, WorldMap, position_at, world_map

HOURS_PER_TILE: float = float(TRAVEL.get("life_hours_per_tile", 0.035)) * environment.HOURS_PER_LIFE_HOUR
TRIP_WORK_SHARE: float = float(TRAVEL.get("trip_work_share", 0.5))
CARE_PLACES = {"sleep": "bed", "eat": "by_fire", "warm_up": "by_fire"}  # any other lasting care: by the fire


class Movement:
    def __init__(self, engine, world: Optional[WorldMap] = None):
        self.engine = engine
        self.world = world or world_map()
        self.rng = random.Random(self.world.seed)   # its own dice: where people wander never touches the game's
        self.people: Dict[str, Dict[str, Any]] = {}  # name -> {pos, legs, bed, dest}
        self._planned: Dict[str, Tuple[Any, Optional[Dict[str, Any]]]] = {}
        self._store_at: Dict[str, int] = {}          # who went to the store at this very moment
        for p in engine.players:
            self.add(p.name)

    # ------------------------------------------------------------------ #
    # Who is where
    # ------------------------------------------------------------------ #
    @property
    def clock(self) -> int:
        return self.engine.clock

    def add(self, name: str, beside: Optional[str] = None):
        """A person appears: at their own sleeping place (a newborn: at their mother's)."""
        other = self.people.get(beside) if beside else None
        if other is not None:
            bed = list(other["bed"])
        else:
            beds = self.world.beds or [self.world.spots["fire"]]
            used = {tuple(b["bed"]) for b in self.people.values()}
            bed = list(next((b for b in beds if b not in used), beds[len(self.people) % len(beds)]))
        self.people[name] = {"pos": list(bed), "legs": [], "bed": bed, "dest": None}

    def forget(self, name: str):
        self.people.pop(name, None)
        self._planned.pop(name, None)
        self._store_at.pop(name, None)

    def position(self, name: str) -> Tuple[float, float]:
        """Where they are right now (part way between two tiles while walking)."""
        b = self.people.get(name)
        if b is None:
            return tuple(self.world.spots["fire"])
        return position_at(b["pos"], b["legs"], self.clock)

    def tile(self, name: str) -> Tile:
        x, y = self.position(name)
        return int(round(x)), int(round(y))

    def in_camp(self, name: str) -> bool:
        """In camp (map.json camp.radius): near enough to use the store."""
        return name not in self.people or self.world.in_camp(*self.position(name))

    def walking(self, name: str) -> bool:
        b = self.people.get(name)
        return bool(b) and any(leg["t0"] <= self.clock < leg["t1"] for leg in b["legs"])

    def halt(self, name: str):
        """Stop where they stand (woken, collapsed, called away): whatever was left of their walk is dropped."""
        b = self.people.get(name)
        if b is not None:
            b["pos"], b["legs"] = list(self.tile(name)), []

    # ------------------------------------------------------------------ #
    # Where things are done
    # ------------------------------------------------------------------ #
    def _spot(self, name: str, spot: str) -> Tile:
        b = self.people[name]
        here = self.tile(name)
        fire = self.world.spots["fire"]
        if spot == "by_fire" and here != fire and max(abs(here[0] - fire[0]), abs(here[1] - fire[1])) <= 1:
            return here  # already sitting by it
        return self.world.spot(spot, self.rng, tuple(b["bed"]))

    def _place(self, name: str, place: str) -> Tuple[Tile, bool]:
        """(tile, is it a trip out of camp) for a kind of place (map.json 'places')."""
        spec = PLACES.get(place)
        if spec is None:
            return self._spot(name, "by_fire"), False
        if "at" in spec:
            return self._spot(name, spec["at"]), False
        tile = self.world.pick(place, self.rng)
        return (tile, self.world.is_trip(place)) if tile else (self._spot(name, "by_fire"), False)

    def _target(self, player, action: Action) -> Optional[Tuple[Tile, bool, Optional[Dict[str, Any]]]]:
        """Where an action is done: (tile, is it a trip, what the trip is looking for), or None if it takes
        no walking."""
        e, name, kind = self.engine, player.name, action.type
        if kind in ("work", "craft"):
            t = WORK.work(kind, action.params.get("task") or action.params.get("recipe"))
            if t is None:
                return None
            if t.scouts_for:  # a Scout goes looking where such a place could be: what they find lies there
                place = WORK.SITE_KINDS[t.scouts_for].get("place", "scouting")
                tile = self.world.pick(place if place in PLACES else "scouting", self.rng,
                                       SITE_RANGE.get("min_distance", 8), SITE_RANGE.get("max_distance", 26))
                return (tile, True, {"tile": list(tile), "site_for": t.scouts_for}) if tile else None
            site = e.production.site_of(t.site) if t.site else None
            if site is not None and site.get("at"):
                return tuple(site["at"]), True, None
            place = t.place or ("workshop" if t.recipe else "council" if (t.offices or t.any_office) else "camp")
            tile, trip = self._place(name, place)
            return tile, trip, ({"tile": list(tile), "site_for": "*"} if t.makes_sites else None)
        if kind == "care":
            care = CHARACTER.care_actions.get(action.params.get("kind"))
            if care is None or care.instant:
                return None
            return self._spot(name, CARE_PLACES.get(action.params["kind"], "by_fire")), False, None
        if kind == "wait":
            return self._spot(name, "bed"), False, None
        if kind == "treat":  # the sick go to the healer's place
            opt = e.life.treatment_for(player)
            healer = opt["healer"].name if opt else None
            return (tuple(self.people[healer]["bed"]), False, None) if healer in self.people else None
        if kind == "heal":   # a healer goes to the sick
            patient = action.params.get("patient")
            return (self.tile(patient), False, None) if patient in self.people else None
        if kind == "activity":
            a = e.life.activity(action.params.get("activity", "")) or {}
            tile, trip = self._place(name, a.get("place") or ("play" if a.get("group", "play") == "play" else "council"))
            return tile, trip, None
        return None

    # ------------------------------------------------------------------ #
    # Plans
    # ------------------------------------------------------------------ #
    def _leg(self, start: int, path: List[Tile]) -> Optional[Dict[str, Any]]:
        if len(path) < 2:
            return None
        costs = [self.world.step_cost(a, b) for a, b in zip(path, path[1:])]
        total = sum(costs) or 1.0
        at, so_far = [0.0], 0.0
        for c in costs:
            so_far += c
            at.append(round(so_far / total, 4))
        return {"t0": start, "t1": start + max(1, int(round(total * HOURS_PER_TILE))),
                "path": [list(t) for t in path], "at": at}

    def _walk(self, legs: List[Dict[str, Any]], when: int, a: Tile, b: Tile) -> int:
        """Add the walk from a to b to `legs`, starting at `when`; returns when they arrive."""
        leg = self._leg(when, self.world.find_path(a, b))
        if leg is None:
            return when
        legs.append(leg)
        return leg["t1"]

    def plan(self, player, action: Action) -> Optional[Dict[str, Any]]:
        """The walking an action takes if begun now: {'total': game hours until it is done, 'legs',
        'pos': where they end up, 'dest'}. None for actions that take no walking. Asked twice at the same
        moment it gives the same plan, so what is promised is what happens."""
        name = player.name
        if name not in self.people:
            return None
        # The same moment, action and time on the spot: the same plan (a speed tool picked up since changes it).
        key = (self.clock, action.key(), self.engine.base_duration(action, player), self._store_at.get(name))
        cached = self._planned.get(name)
        if cached is not None and cached[0] == key:
            return cached[1]
        plan = self._make_plan(player, action)
        self._planned[name] = (key, plan)
        return plan

    def _make_plan(self, player, action: Action) -> Optional[Dict[str, Any]]:
        target = self._target(player, action)
        if target is None:
            return None
        tile, trip, dest = target
        name, now = player.name, self.clock
        base = self.engine.base_duration(action, player)
        here = self.tile(name)
        store = self.world.spots.get("store", self.world.spots["fire"])
        legs: List[Dict[str, Any]] = []
        when = now
        if self._store_at.get(name) == now and self.world.in_camp(*here):  # fetched a tool or materials first
            when = self._walk(legs, when, here, store)
            here = store
        when = self._walk(legs, when, here, tile)
        end = tile
        if trip:
            when += max(1, int(round(base * TRIP_WORK_SHARE)))
            when = self._walk(legs, when, tile, store)
            end = store
        else:
            when += base
        return {"total": max(1, when - now), "legs": legs, "pos": list(end), "dest": dest}

    def commit(self, player, action: Action):
        """The action has begun: the body sets off on its plan."""
        b = self.people.get(player.name)
        plan = self.plan(player, action)
        self._planned.pop(player.name, None)
        if b is None or plan is None:
            return
        b["legs"], b["pos"], b["dest"] = plan["legs"], plan["pos"], plan["dest"]

    def go(self, name: str, spot: str):
        """Walk to a camp spot now, without it being an action of its own (called to a contest)."""
        b = self.people.get(name)
        if b is None:
            return
        here, to = self.tile(name), self._spot(name, spot)
        b["legs"] = []
        self._walk(b["legs"], self.clock, here, to)
        b["pos"] = list(to)

    def store_visit(self, name: str):
        """They take from or put into the store. If an action begins at this moment its walk goes by the
        store; otherwise someone standing still in camp is seen to walk over to the store and back."""
        b = self.people.get(name)
        if b is None:
            return
        self._store_at[name] = self.clock
        if any(leg["t1"] > self.clock for leg in b["legs"]):
            return  # on their way somewhere already
        here = self.tile(name)
        store = self.world.spots.get("store")
        if store is None or here == store or not self.world.in_camp(*here):
            return
        b["legs"] = []
        back = self._walk(b["legs"], self.clock, here, store)
        self._walk(b["legs"], back, store, here)
        b["pos"] = list(here)

    def site_spot(self, kind: str, by: str) -> List[int]:
        """Where a newly found (or planted) place of this kind lies: where its finder went looking, else
        somewhere such a place could be."""
        dest = (self.people.get(by) or {}).get("dest") or {}
        if dest.get("site_for") in (kind, "*"):
            return list(dest["tile"])
        place = WORK.SITE_KINDS.get(kind, {}).get("place", "scouting")
        tile = self.world.pick(place if place in PLACES else "scouting", self.rng,
                               SITE_RANGE.get("min_distance", 8), SITE_RANGE.get("max_distance", 26))
        return list(tile or self.world.spots["fire"])

    def walks(self, player) -> Dict[str, Dict[str, float]]:
        """For telling a player what their work will take: for each piece of work they could do that means
        a trip, {'walk': about how long the walk there and back is, 'share': the share of the task's own
        time spent on the spot}, in hours of the day-night cycle. The real walk is found on setting out."""
        per_tile = float(TRAVEL.get("life_hours_per_tile", 0.035))
        walk = self.world.walk_from_fire()
        out: Dict[str, Dict[str, float]] = {}
        for kind, key, _ in self.engine.work_options(player):
            t = WORK.work(kind, key)
            if t is None:
                continue
            site = self.engine.production.site_of(t.site) if t.site else None
            if t.scouts_for:
                far = (SITE_RANGE.get("min_distance", 8) + SITE_RANGE.get("max_distance", 26)) / 2
            elif site is not None and site.get("at"):
                far = walk[site["at"][1]][site["at"][0]]
            else:
                place = t.place or ""
                spec = PLACES.get(place, {})
                if not spec or "at" in spec or not self.world.is_trip(place):
                    continue
                tiles = self.world._place_tiles(place, spec)
                far = next((d for d, _ in tiles if d >= spec.get("min_distance", 0)), None)
                if far is None:
                    continue
            if far != float("inf"):
                out[key] = {"walk": round(2 * far * per_tile, 2), "share": TRIP_WORK_SHARE}
        return out

    # ------------------------------------------------------------------ #
    # For displays, and saving
    # ------------------------------------------------------------------ #
    def observe(self, player) -> Dict[str, Any]:
        """The map as plain data: where everyone is and is walking, the camp's spots, places found.
        A display finds where someone is at any moment with world.map.position_at(pos, legs, clock)."""
        now = self.clock
        e = self.engine
        people = []
        for p in e.players:
            b = self.people.get(p.name)
            if b is None:
                continue
            x, y = self.position(p.name)
            people.append({"name": p.name, "x": round(x, 2), "y": round(y, 2), "pos": list(b["pos"]),
                           "legs": [leg for leg in b["legs"] if leg["t1"] > now],
                           "walking": self.walking(p.name), "you": p is player,
                           "child": not e.life.of_age(p, "work"), "bed": list(b["bed"])})
        sites = [{"kind": s["kind"], "x": s["at"][0], "y": s["at"][1],
                  "icon": WORK.SITE_KINDS[s["kind"]].get("icon", "•"), "short": WORK.SITE_KINDS[s["kind"]].get("short", s["kind"]),
                  "by": s["by"], "loads": s["loads"]}
                 for s in e.production.sites if s.get("at") and s["loads"] > 0]
        return {"clock": now, "people": people, "sites": sites,
                "spots": {k: list(v) for k, v in self.world.spots.items()},
                "fire_burning": e.fire_state() != "out" if hasattr(e, "production") else True,
                "radius": CAMP.get("radius", 8)}

    def to_dict(self) -> Dict[str, Any]:
        version, internal, gauss = self.rng.getstate()
        return {"seed": self.world.seed,
                "dice": [version, list(internal), gauss],  # so a saved game goes on exactly as it would have
                "store_at": dict(self._store_at),
                "people": {n: {"pos": b["pos"], "legs": b["legs"], "bed": b["bed"], "dest": b["dest"]}
                           for n, b in self.people.items()}}

    def load_state(self, data: Dict[str, Any]):
        """A saved game's bodies. People the save doesn't know (an older save) start at their beds; places
        found before there was a map are given a spot on it."""
        data = data or {}
        saved = data.get("people", {}) if data.get("seed") == self.world.seed else {}
        if saved and data.get("dice"):
            version, internal, gauss = data["dice"]
            self.rng.setstate((version, tuple(internal), gauss))
            self._store_at = dict(data.get("store_at", {}))
        for name, b in saved.items():
            if name in self.people and self.world.walkable(*b["pos"]):
                self.people[name] = {"pos": list(b["pos"]), "legs": list(b.get("legs", [])),
                                     "bed": list(b.get("bed", b["pos"])), "dest": b.get("dest")}
        for site in self.engine.production.sites:
            if not site.get("at") or not self.world.walkable(*site["at"]):
                site["at"] = self.site_spot(site["kind"], "")

"""The game as a local server for a graphical client (the Godot project in godot/).

    python -m bridge.server --port 0 --port-file /tmp/govgen.port

The game itself is untouched: this is one more display on top of HUDController (controllers/hud.py) and
the display-neutral view model (ui/model.py), exactly as the terminal HUD (ui/hud.py) is. The game loop
runs in its own thread; this module sends what the HUD would draw to the client and passes the client's
choices back. Everything on the wire is one JSON object per line.

To the client:
    hello      once, on connecting: the world map, the definitions a display needs (attributes, skills,
               needs, items, action keys...) and whether there is a saved game
    started    the game has begun (new or continued)
    state      the latest view (engine.observe) with what ui/model.py makes of it: the action groups,
               the innovation catalogue, ballot tags, the store line, the pace of the clock
    messages   new chronicle entries
    alerts     ballots and contests that opened, moved on or closed (ui/model.py BallotWatcher)
    result     whether something you chose was carried out
    status     a line for the status bar
    menu       the picker tree behind an action key (asked for with 'menu')
    crafts     the crafting chart (asked for with 'crafts')
    bye        the game is over or saved; the server stops

From the client:
    start      {new, seed}          begin: continue the save, or a new game
    menu       {kind}               the picker for an action kind ('vote', 'work'...)
    act        {action}             do it: {type, params}, as listed in a menu or made by the inventory
    crafts     {}                   the crafting chart
    speed      {value?}             next playback speed, or the one given
    pause      {on?}                pause or resume
    auto       {on}                 played like an NPC, or by you
    detail     {level}              remembered with the save
    quit       {}                   save and stop
"""
import argparse
import dataclasses
import json
import os
import queue
import random
import socket
import sys
import threading
import time
from pathlib import Path
from typing import Any, Dict, List, Optional

PROTOCOL = 1
STATE_GAP = 0.2      # real seconds between two views sent (people on the map walk on between them)
DISCONNECTED = object()


def _jsonable(o: Any) -> Any:
    if dataclasses.is_dataclass(o):
        return dataclasses.asdict(o)
    if isinstance(o, (set, frozenset)):
        return sorted(o)
    if isinstance(o, Path):
        return str(o)
    return str(o)


def _clean(o: Any) -> Any:
    """inf and nan are not JSON: a display reads them as 'none'."""
    if isinstance(o, float):
        return o if o == o and o not in (float("inf"), float("-inf")) else None
    if isinstance(o, dict):
        return {str(k): _clean(v) for k, v in o.items()}
    if isinstance(o, (list, tuple)):
        return [_clean(v) for v in o]
    return o


def _whole(o: Any) -> Any:
    """JSON has only one kind of number, and some clients send 3 as 3.0: whole numbers come back as they were
    (slots, counts, offer ids)."""
    if isinstance(o, float) and o.is_integer():
        return int(o)
    if isinstance(o, dict):
        return {k: _whole(v) for k, v in o.items()}
    if isinstance(o, list):
        return [_whole(v) for v in o]
    return o


def encode(message: Dict[str, Any]) -> bytes:
    try:
        text = json.dumps(message, default=_jsonable, ensure_ascii=False, allow_nan=False)
    except ValueError:
        text = json.dumps(_clean(json.loads(json.dumps(message, default=_jsonable))), ensure_ascii=False)
    return text.encode("utf-8") + b"\n"


# --------------------------------------------------------------------------- #
# What a display needs to know that never changes while the game runs
# --------------------------------------------------------------------------- #
def static_data() -> Dict[str, Any]:
    from core import calendar
    from core.game import SPEEDS
    from innovations.innovation import AGES, INTERFACE_ICONS
    from ui.model import ACTION_KINDS, ACTION_SECTIONS
    from world import environment
    from world.character import RULES as CHARACTER
    from world.items import ITEMS
    from world.map import CAMP, HOME, TERRAIN, ZOOM_LEVELS, world_map

    world = world_map()
    section_of = {t: name for name, types in ACTION_SECTIONS for t in types}
    return {
        "map": {**world.to_dict(), "spots": {k: list(v) for k, v in world.spots.items()},
                "beds": [list(b) for b in world.beds], "radius": CAMP.get("radius", 8),
                "zoom_levels": ZOOM_LEVELS, "home_marker": HOME.get("marker", ""),
                "terrain": {t.key: {"code": t.code, "name": t.name, "description": t.description,
                                    "walkable": t.walkable, "buildable": t.buildable, "move_cost": t.move_cost,
                                    "fresh_water": t.fresh_water, "color": t.color, "background": t.background}
                            for t in TERRAIN.values()}},
        "character": {
            "attr_max": CHARACTER.attr_max, "skill_max": CHARACTER.skill_max,
            "attributes": {k: {"name": a.name, "abbr": a.abbr, "description": a.description}
                           for k, a in CHARACTER.attributes.items()},
            "skills": {k: {"name": s.name, "attribute": s.attribute, "description": s.description}
                       for k, s in CHARACTER.skills.items()},
            "needs": {k: {"name": n.name, "icon": n.icon} for k, n in CHARACTER.needs.items()},
            "care": {k: {"label": c.label, "instant": c.instant} for k, c in CHARACTER.care_actions.items()},
        },
        "items": {k: {"name": i.name, "icon": i.icon, "kind": i.kind, "description": i.description,
                      "max_stack": i.max_stack, "value": i.value, "uses": i.uses, "use": i.use,
                      "use_label": i.use_label, "breaks": i.breaks} for k, i in ITEMS.items()},
        "interface_icons": dict(INTERFACE_ICONS),
        "ages": [{"key": a.key, "name": a.name, "description": a.description} for a in AGES],
        "time": {"hours_per_day": calendar.HOURS_PER_DAY, "hours_per_year": calendar.HOURS_PER_YEAR,
                 "days_per_year": calendar.DAYS_PER_YEAR, "days_per_season": calendar.DAYS_PER_SEASON,
                 "seasons": calendar.SEASONS, "hours_per_life_hour": environment.HOURS_PER_LIFE_HOUR,
                 "cycle_hours": environment.CYCLE_HOURS, "dawn": environment.DAWN, "dusk": environment.DUSK,
                 "start": environment.START},
        "action_kinds": [{"type": k.type, "hotkey": k.hotkey, "label": k.label, "title": k.title,
                          "window": k.window, "section": section_of.get(k.type, "Other")} for k in ACTION_KINDS],
        "action_sections": [name for name, _ in ACTION_SECTIONS],
        "detail_levels": {"full": "everything everyone does, with reasons",
                          "politics": "everything except everyday life (eating, sleeping, resting)",
                          "summary": "important events only"},
        "speeds": list(SPEEDS),
    }


def action_dict(a) -> Dict[str, Any]:
    return {"type": a.type, "params": a.params, "label": a.label, "group": a.group}


def menu_dict(menu, group) -> Dict[str, Any]:
    """A ui.model Menu as plain data; every item that acts carries its action and how long it takes."""
    items = []
    for it in menu.items:
        d: Dict[str, Any] = {"label": it.label, "detail": it.detail}
        if it.action is not None:
            d["action"] = action_dict(it.action)
        if it.submenu is not None:
            d["submenu"] = menu_dict(it.submenu, group)
        if it.text_prompt:
            d["text_prompt"] = it.text_prompt
        if it.ranked:
            d["ranked"] = list(it.ranked)
        if it.profile:
            d["profile"] = it.profile
        if it.profiles:
            d["profiles"] = {k: v for k, v in it.profiles.items() if v}
        items.append(d)
    return {"title": menu.title, "note": menu.note, "items": items}


# --------------------------------------------------------------------------- #
class Session:
    """One client, one game."""

    def __init__(self, conn: socket.socket, save_file: Path, seed: Optional[int], speed: Optional[float]):
        self.conn = conn
        self.save_file = save_file
        self.seed, self.speed = seed, speed
        self.inbox: "queue.Queue[Any]" = queue.Queue()
        self.send_lock = threading.Lock()
        self.game = None
        self.controller = None
        self.thread: Optional[threading.Thread] = None
        self.errors: List[BaseException] = []
        self.version = -1
        self.view: Optional[Dict[str, Any]] = None
        self.legal: list = []
        self.history: list = []
        self.watcher = None
        self.last_state = 0.0
        self.force_state = False
        self.alive = True
        self.stop = False

    # ------------------------------------------------------------------ #
    # The wire
    # ------------------------------------------------------------------ #
    def send(self, type_: str, **data):
        if not self.alive:
            return
        try:
            payload = encode({"type": type_, **data})
        except RuntimeError:
            return  # the game thread changed something mid-way; the next view is right behind
        try:
            with self.send_lock:
                self.conn.sendall(payload)
        except OSError:
            self.alive = False

    def _read(self):
        buffer = b""
        try:
            while True:
                chunk = self.conn.recv(65536)
                if not chunk:
                    break
                buffer += chunk
                while b"\n" in buffer:
                    line, buffer = buffer.split(b"\n", 1)
                    if line.strip():
                        try:
                            self.inbox.put(json.loads(line.decode("utf-8")))
                        except ValueError:
                            pass
        except OSError:
            pass
        self.inbox.put(DISCONNECTED)

    # ------------------------------------------------------------------ #
    def run(self):
        from core.save import save_summary
        threading.Thread(target=self._read, name="bridge-read", daemon=True).start()
        self.send("hello", protocol=PROTOCOL, save=save_summary(self.save_file), **static_data())
        while self.alive and not self.stop:
            try:
                cmd = self.inbox.get(timeout=0.05)
            except queue.Empty:
                cmd = None
            if cmd is DISCONNECTED:
                self.alive = False
                break
            if cmd is not None:
                try:
                    self.handle(cmd)
                except Exception as e:  # a bad request must never take the game down
                    from utils.logging_config import logger
                    logger.exception("bridge: could not handle %r", cmd)
                    self.send("status", text=f"Something went wrong: {e}", style="red")
            if self.game is not None:
                self.pump()
                if self.thread is not None and not self.thread.is_alive():
                    break
        self.finish()

    # ------------------------------------------------------------------ #
    # Starting and stopping
    # ------------------------------------------------------------------ #
    def start(self, new: bool, seed: Optional[int]):
        if self.game is not None:
            return
        from core.game import Pacer
        from core.main import build_game
        from core.save import load_save, rng_state_from_json, save_game, save_summary
        from ui.model import BallotWatcher
        from utils.settings import load_settings
        settings = load_settings()
        if seed is None:
            seed = self.seed
        if seed is not None:
            settings["seed"] = seed
        pacer = Pacer(settings["real_seconds_per_game_year"],
                      self.speed if self.speed is not None else settings["playback_speed"])
        saved = None
        if not new and save_summary(self.save_file):
            saved = load_save(self.save_file)
        if saved:
            random.setstate(rng_state_from_json(saved["random_state"]))
        elif settings["seed"] is not None:
            random.seed(settings["seed"])
        game = build_game(settings, saved=saved, pacer=pacer, hud=True)
        save_file = self.save_file
        game.autosave = lambda g: save_game(g, save_file) if g.engine.players else None
        realtime = [c for c in game.controllers.values() if c.realtime]
        if not realtime:
            raise ValueError("data/players.json has nobody for you to play (no player with \"controller\": \"human\")")
        self.controller = realtime[0]
        self.watcher = BallotWatcher()
        self.game = game

        def play():
            try:
                game.run()
            except BaseException as e:
                from utils.logging_config import logger
                logger.exception("Game loop crashed")
                self.errors.append(e)

        self.thread = threading.Thread(target=play, name="game-loop", daemon=True)
        self.thread.start()
        self.send("started", continued=bool(saved), you=self.controller.name)

    def finish(self):
        """The client left or the game ended: stop the loop at a safe moment, save, say goodbye."""
        game = self.game
        if game is None:
            self.send("bye", reason="closed", text="")
            return
        if self.controller is not None:
            self.controller.quit()
        game.request_stop()
        if self.thread is not None:
            self.thread.join(timeout=15)
        self.pump(final=True)
        from core.calendar import format_date
        from core.save import save_game
        engine = game.engine
        if self.errors:
            self.send("bye", reason="error", text=f"The game stopped on an error: {self.errors[0]!r} (see govgen.log)")
        elif engine.started and not engine.players:
            self.send("bye", reason="extinct", text=f"The tribe is no more: everyone had died by "
                                                    f"{format_date(engine.clock)}. The save was left as it was.")
        elif engine.started:
            save_game(game, self.save_file)
            self.send("bye", reason="saved", text=f"Game saved at {format_date(engine.clock)}.")
        else:
            self.send("bye", reason="closed", text="")

    # ------------------------------------------------------------------ #
    # From the game to the client
    # ------------------------------------------------------------------ #
    def pump(self, final: bool = False):
        from core.calendar import format_date
        c = self.controller
        messages = c.drain_messages()
        if messages:
            self.history.extend(messages)
            del self.history[:-5000]
            self.send("messages", items=[
                {"text": m.text, "important": m.important, "reason": m.reason, "header": m.header, "time": m.time,
                 "date": format_date(m.time, short=True) if m.time is not None else "", "category": m.category}
                for m in messages])
        for decision, ok, why in c.drain_results():
            if ok:
                text, style = f"Done: {decision.action.label or decision.action.type.replace('_', ' ')}.", "green"
            else:
                if not why or "cannot do that right now" in why:
                    why = "it's no longer possible (a ballot may have closed, or things changed while you chose)."
                text, style = f"Couldn't do that: {why}", "red"
            self.send("result", ok=ok, text=text, style=style, action=decision.action.type)
            self.force_state = True
        version, view, legal = c.snapshot()
        if view is None or version == self.version and not self.force_state:
            return
        now = time.monotonic()
        if not (final or self.force_state) and now - self.last_state < STATE_GAP:
            return
        self.version, self.view, self.legal = version, view, legal
        self.last_state, self.force_state = now, False
        self.send_state(view, legal)

    def send_state(self, view: Dict[str, Any], legal: list):
        from ui import model
        model.use_terms(view)
        recent = [m.text for m in self.history[-80:] if m.important]
        alerts = self.watcher.update(view, legal, recent)
        if alerts:
            self.send("alerts", items=[dataclasses.asdict(a) for a in alerts])
        pacer = self.game.pacer
        groups = model.action_groups(view, legal)
        rows = model.innovation_catalog(view)
        age_name, shown = model.current_age_innovations(view)
        ui = {
            "groups": [{"type": g.kind.type, "available": g.available, "count": len(g.actions)} for g in groups],
            "legal": [action_dict(a) for a in legal],
            "innovations": [dataclasses.asdict(r) for r in rows],
            "age_name": age_name,
            "age_innovations": [r.name for r in shown],
            "ballots": {b["key"]: list(model.ballot_status(b, legal, view["free"])) for b in view["ballots"]},
            "camp_line": model.camp_line(view),
            "life_status": [list(x) for x in model.life_status((view.get("character") or {}).get("life") or {})],
            "protected_note": model.protected_note(view),
            "pacer": {"speed": pacer.speed, "paused": pacer.paused, "label": pacer.describe(),
                      "seconds_per_year": pacer.seconds_per_year},
            "auto": bool(self.controller.auto), "detail": self.controller.detail,
        }
        self.send("state", version=self.version, view=view, ui=ui)

    # ------------------------------------------------------------------ #
    # From the client to the game
    # ------------------------------------------------------------------ #
    def handle(self, cmd: Dict[str, Any]):
        kind = cmd.get("cmd")
        if kind == "start":
            try:
                self.start(bool(cmd.get("new")), cmd.get("seed"))
            except Exception as e:
                from utils.logging_config import logger
                logger.exception("bridge: could not start the game")
                self.send("error", text=f"The game could not start: {e}")
            return
        if kind == "quit":
            if self.controller is not None:
                self.controller.quit()  # the game loop saves nothing itself: finish() does, once it has stopped
            else:
                self.stop = True
            return
        if self.game is None or self.controller is None:
            return
        c, pacer = self.controller, self.game.pacer
        if kind == "menu":
            self.menu(cmd.get("kind", ""))
        elif kind == "act":
            self.act(cmd.get("action") or {})
        elif kind == "crafts":
            self.crafts()
        elif kind == "speed":
            if "value" in cmd:
                pacer.speed = float(cmd["value"])
            else:
                pacer.next_speed()
            self.force_state = True
        elif kind == "pause":
            pacer.paused = (not pacer.paused) if cmd.get("on") is None else bool(cmd["on"])
            self.send("status", text="Paused. You can still act." if pacer.paused else "Resumed.", style="yellow")
            self.force_state = True
        elif kind == "auto":
            c.set_auto(bool(cmd.get("on")))
            self.send("status", style="magenta" if c.auto else "green", text=(
                "AUTO: you are played like any other member of the tribe. You can still pause and look at everything; "
                "M takes you back to manual." if c.auto else
                "MANUAL: you choose again. Whatever you were doing carries on until it is done."))
            self.force_state = True
        elif kind == "detail":
            if cmd.get("level") in ("full", "politics", "summary"):
                c.detail = cmd["level"]
            self.force_state = True

    def _resolve(self, a: Dict[str, Any]):
        """The legal action the client means (so its params are exactly the engine's), or a new one (a quick
        action from the inventory window)."""
        from core.actions import Action, FREE_PARAMS
        params = dict(a.get("params") or {})
        fixed = {k: v for k, v in params.items() if k not in FREE_PARAMS}
        free = {k: v for k, v in params.items() if k in FREE_PARAMS}
        for cand in self.legal:
            if cand.type != a.get("type"):
                continue
            theirs = {k: v for k, v in cand.params.items() if k not in FREE_PARAMS}
            if json.loads(json.dumps(theirs, default=_jsonable)) == fixed:
                return cand.with_params(**_whole(free)) if free else cand
        return Action(a.get("type", ""), _whole(params), a.get("label", ""), a.get("group", ""))

    def act(self, a: Dict[str, Any]):
        from controllers.base import Decision
        if not a.get("type"):
            return
        self.controller.submit(Decision(self._resolve(a)))

    def menu(self, kind: str):
        from controllers.base import Decision
        from ui import model
        from world.environment import format_life_duration
        view, legal, c = self.view, self.legal, self.controller
        if view is None:
            return
        if c.auto:
            self.send("menu", kind=kind, unavailable="You are on AUTO: the game plays you like any other member. "
                                                     "Press M to take over.")
            return
        model.use_terms(view)
        group = next((g for g in model.action_groups(view, legal) if g.kind.type == kind), None)
        if group is None:
            return
        if not group.available:
            if not view["free"]:
                why = (f"You are busy ({view['doing']}) for {format_life_duration(view['busy_hours_left'])} more"
                       + (" (X to stop)." if view.get("can_stop") else "."))
            elif kind in ("persuade", "challenge") and view.get("contest_cooldown_hours"):
                why = (f"You lost your last contest: no new campaign or challenge for "
                       f"{format_life_duration(view['contest_cooldown_hours'])}.")
            elif kind in ("persuade", "challenge") and model.protected_note(view):
                why = model.protected_note(view).strip()
            else:
                why = f"{group.kind.label}: nothing you can do there right now."
            self.send("menu", kind=kind, unavailable=why)
            return
        if kind == "stop":
            c.submit(Decision(group.actions[0]))
            self.send("status", text="Getting up…", style="dim")
            return
        try:
            menu = menu_dict(model.build_menu(group, view), group)
        except Exception:
            self.send("menu", kind=kind, unavailable="Things changed while you chose; try again.")
            return
        self.send("menu", kind=kind, label=group.kind.label, menu=menu)

    def crafts(self):
        from ui import model
        view = self.view
        if view is None:
            return
        model.use_terms(view)
        rows = []
        for r in model.craft_catalog(view):
            rows.append({"item": r.item, "icon": r.icon, "name": r.name, "kind": r.kind, "status": r.status,
                         "why": r.why, "store": r.store, "by": r.by, "research": r.research, "takes": r.takes,
                         "used_for": r.used_for, "used": bool(r.used_by),
                         "detail": [list(x) for x in model.craft_detail(view, r)]})
        self.send("crafts", age=(view.get("crafts") or {}).get("age", ""), rows=rows, filters=model.CRAFT_FILTERS)


# --------------------------------------------------------------------------- #
def main():
    parser = argparse.ArgumentParser(description="GovGen as a local server for a graphical client")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=47800, help="0 = any free port (see --port-file)")
    parser.add_argument("--port-file", help="write the port being listened on to this file")
    parser.add_argument("--save-file", help="the save to continue and write (default: saves/savegame.json)")
    parser.add_argument("--seed", type=int, help="random seed for a new game")
    parser.add_argument("--speed", type=float, help="playback speed to start at (0 = as fast as possible)")
    parser.add_argument("--wait", type=float, default=120, help="give up if no client connects within this many seconds")
    args = parser.parse_args()

    import logging
    from core.save import SAVE_FILE
    from utils.logging_config import logger
    for handler in list(logger.handlers):  # errors still go to govgen.log
        if type(handler) is logging.StreamHandler:
            logger.removeHandler(handler)

    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind((args.host, args.port))
    server.listen(1)
    port = server.getsockname()[1]
    if args.port_file:
        tmp = args.port_file + ".tmp"
        with open(tmp, "w", encoding="utf-8") as f:
            f.write(str(port))
        os.replace(tmp, args.port_file)
    print(f"GOVGEN_PORT={port}", flush=True)
    server.settimeout(args.wait)
    try:
        conn, _ = server.accept()
    except socket.timeout:
        print("No client connected; stopping.", flush=True)
        return
    finally:
        server.close()
    conn.setsockopt(socket.IPPROTO_TCP, socket.TCP_NODELAY, 1)
    session = Session(conn, Path(args.save_file) if args.save_file else SAVE_FILE, args.seed, args.speed)
    try:
        session.run()
    finally:
        try:
            conn.close()
        except OSError:
            pass
        if args.port_file:
            try:
                os.remove(args.port_file)
            except OSError:
                pass


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent.parent))
    main()

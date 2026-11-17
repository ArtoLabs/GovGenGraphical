extends Node
## What the client knows about the game: the definitions sent once on connecting (`defs`), the latest
## view (`view`: exactly what the engine's observe() gives) with what ui/model.py made of it (`ui`), the
## chronicle and the alerts. Panels read from here and redraw on `state_changed`; nothing here draws.

signal hello_received
signal game_started(continued: bool)
signal state_changed
signal chronicle_added(items: Array)
signal alerts_added(items: Array)
signal status_changed(text: String, style: String)
signal action_result(ok: bool, text: String)
signal menu_received(msg: Dictionary)
signal crafts_received(msg: Dictionary)
signal game_over(reason: String, text: String)
signal engine_error(text: String)

const DEFAULT_TERMS := {"society": "society", "members": "Members", "member": "Member", "store": "Store",
		"store_name": "store", "home": "home"}

var defs: Dictionary = {}
var view: Dictionary = {}
var ui: Dictionary = {}
var version := -1
var history: Array = []     # every chronicle entry so far (the last 5000)
var alerts: Array = []      # ballot and contest alerts (the last 30)
var alert_msec := 0
var view_msec := 0
var in_game := false
var _players: Dictionary = {}


func _ready() -> void:
	Net.message.connect(_on_message)


func reset() -> void:
	view = {}
	ui = {}
	version = -1
	history = []
	alerts = []
	in_game = false
	_players = {}


func _on_message(m: Dictionary) -> void:
	match m.get("type", ""):
		"hello":
			defs = m
			hello_received.emit()
		"started":
			in_game = true
			game_started.emit(bool(m.get("continued", false)))
		"state":
			view = m["view"]
			ui = m["ui"]
			version = int(m.get("version", 0))
			view_msec = Time.get_ticks_msec()
			_players = {}
			for p in view.get("players", []):
				_players[p["name"]] = p
			state_changed.emit()
		"messages":
			var items: Array = m.get("items", [])
			history.append_array(items)
			if history.size() > 5000:
				history = history.slice(history.size() - 5000)
			chronicle_added.emit(items)
		"alerts":
			var items: Array = m.get("items", [])
			alerts.append_array(items)
			if alerts.size() > 30:
				alerts = alerts.slice(alerts.size() - 30)
			alert_msec = Time.get_ticks_msec()
			alerts_added.emit(items)
		"status":
			status_changed.emit(str(m.get("text", "")), str(m.get("style", "")))
		"result":
			action_result.emit(bool(m.get("ok", false)), str(m.get("text", "")))
			status_changed.emit(str(m.get("text", "")), str(m.get("style", "")))
		"menu":
			menu_received.emit(m)
		"crafts":
			crafts_received.emit(m)
		"bye":
			in_game = false
			game_over.emit(str(m.get("reason", "")), str(m.get("text", "")))
		"error":
			engine_error.emit(str(m.get("text", "")))


# --------------------------------------------------------------------------- #
# Asking the game for things
# --------------------------------------------------------------------------- #
func act(action: Dictionary) -> void:
	Net.send({"cmd": "act", "action": {"type": action.get("type", ""), "params": action.get("params", {}),
			"label": action.get("label", ""), "group": action.get("group", "")}})


func quick(type: String, params: Dictionary = {}) -> void:
	Net.send({"cmd": "act", "action": {"type": type, "params": params}})


func ask_menu(kind: String) -> void:
	Net.send({"cmd": "menu", "kind": kind})


# --------------------------------------------------------------------------- #
# Reading the view
# --------------------------------------------------------------------------- #
func has_view() -> bool:
	return not view.is_empty()


func you() -> String:
	return str(view.get("you", ""))


func player(pname: String) -> Dictionary:
	return _players.get(pname, {})


func me() -> Dictionary:
	return player(you())


func players() -> Array:
	return view.get("players", [])


func term(word: String) -> String:
	var t: Dictionary = view.get("terms", {})
	return str(t.get(word, DEFAULT_TERMS.get(word, word)))


func item(key: String) -> Dictionary:
	return defs.get("items", {}).get(key, {"name": key, "icon": "•", "kind": "material", "description": "",
			"max_stack": 1, "value": 1, "uses": 0, "use": {}, "use_label": "Use", "breaks": 0})


func attributes() -> Dictionary:
	return defs.get("character", {}).get("attributes", {})


func skills() -> Dictionary:
	return defs.get("character", {}).get("skills", {})


func needs() -> Dictionary:
	return defs.get("character", {}).get("needs", {})


func attr_max() -> float:
	return float(defs.get("character", {}).get("attr_max", 10))


func skill_max() -> float:
	return float(defs.get("character", {}).get("skill_max", 10))


func time_def(key: String, fallback: float) -> float:
	return float(defs.get("time", {}).get(key, fallback))


func occupation_icons(p: Dictionary) -> String:
	var out := ""
	var occ: Dictionary = view.get("occupations", {})
	for o in p.get("occupations", []):
		out += str(occ.get(o, {}).get("icon", ""))
	return out


func positions_of(p: Dictionary) -> String:
	var parts: Array = []
	parts.append_array(p.get("offices", []))
	parts.append_array(p.get("statuses", []))
	return ", ".join(PackedStringArray(parts))


func skill_average(skill_values: Dictionary) -> float:
	if skill_values.is_empty():
		return 0.0
	var total := 0.0
	for v in skill_values.values():
		total += float(v)
	return total / skill_values.size()


func group(kind: String) -> Dictionary:
	for g in ui.get("groups", []):
		if g["type"] == kind:
			return g
	return {}


func legal(type: String) -> Array:
	var out: Array = []
	for a in ui.get("legal", []):
		if a["type"] == type:
			out.append(a)
	return out


func innovation(iname: String) -> Dictionary:
	for r in ui.get("innovations", []):
		if r["name"] == iname:
			return r
	return {}


func inventory_of(pname: String) -> Dictionary:
	if pname == you() and view.has("possessions"):
		return view["possessions"].get("inventory", {})
	var inv = player(pname).get("inventory")
	return inv if inv is Dictionary else {}


# --------------------------------------------------------------------------- #
# Time
# --------------------------------------------------------------------------- #
func game_rate() -> float:
	## Game hours that pass in one real second right now.
	var pacer: Dictionary = ui.get("pacer", {})
	if pacer.is_empty() or pacer.get("paused", false) or float(pacer.get("speed", 1)) <= 0.0:
		return 0.0
	return time_def("hours_per_year", 8640) / float(pacer.get("seconds_per_year", 300)) * float(pacer["speed"])


func clock() -> float:
	## The game clock now: people on the map walk on between two views (at most a day ahead).
	var base := float(view.get("map", {}).get("clock", view.get("time", 0)))
	return base + minf(24.0, (Time.get_ticks_msec() - view_msec) / 1000.0 * game_rate())


func fmt_life(calendar_hours: float) -> String:
	## A span of game time as people feel it: hours and minutes of the day-night cycle.
	var minutes := calendar_hours / time_def("hours_per_life_hour", 1080) * 60.0
	if minutes < 1.0:
		return "a moment"
	if minutes < 60.0:
		return "%d min" % int(round(minutes))
	var hours := minutes / 60.0
	return ("%.1f h" % hours) if hours < 10.0 else ("%d h" % int(round(hours)))


func fmt_life_hours(life_hours: float) -> String:
	return fmt_life(life_hours * time_def("hours_per_life_hour", 1080))


func num(v) -> String:
	## A number without a needless '.0' (Python's ':g').
	if v == null:
		return "-"
	var f := float(v)
	if is_equal_approx(f, round(f)):
		return str(int(round(f)))
	return String.num(f, 2).rstrip("0").rstrip(".") if absf(f) < 100 else str(int(round(f)))

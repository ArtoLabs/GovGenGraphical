class_name PickerWindow
extends GameWindow
## Choose one thing from a list: press the key shown, use the arrows and Enter, or click. A choice may
## open another list, ask for a ranking of candidates, or for a line of text. Esc goes back.
##
## The lists behind the action keys come ready-made from the game (ui/model.py build_menu); the client
## also uses this window for its own small questions (how many, to whom): then `local` is set and
## `finished` carries the chosen item.

signal finished(item)

const KEYS := "123456789abcdefghijklmnopqrstuvwxyz"

var local := false
var _menus: Array = []
var _label := ""
var _legend: RichTextLabel
var _scroll: ScrollContainer
var _list: VBoxContainer
var _edit: LineEdit
var _note: RichTextLabel
var _rows: Array = []
var _index := 0
var _mode := "menu"            # menu, rank, text
var _rank_item: Dictionary = {}
var _ranking: Array = []
var _pending: Dictionary = {}
var _pending_item: Dictionary = {}
var _done := false


class Row extends PanelContainer:
	signal chosen
	signal hovered
	var text_label: RichTextLabel
	var _plain: StyleBoxFlat
	var _hot: StyleBoxFlat

	func _init(text: String) -> void:
		_plain = UI.box(Color(1, 1, 1, 0.035), Color(1, 1, 1, 0.05), 5, 10, 1, 6)
		_hot = UI.box(Color(0.30, 0.26, 0.15, 0.95), UI.GOLD, 5, 10, 1, 6)
		add_theme_stylebox_override("panel", _plain)
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		text_label = UI.rich(14)
		text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		text_label.text = text
		add_child(text_label)

	func set_hot(on: bool) -> void:
		add_theme_stylebox_override("panel", _hot if on else _plain)

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			chosen.emit()
		elif event is InputEventMouseMotion:
			hovered.emit()


func _init() -> void:
	super()
	wide = false


func open_menu(menu: Dictionary, label: String) -> void:
	_menus = [menu]
	_label = label


func build() -> void:
	_legend = UI.rich(13)
	_legend.visible = false
	content.add_child(_legend)
	_list = UI.vbox(4)
	_scroll = UI.scroll(_list)
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	content.add_child(_scroll)
	_edit = LineEdit.new()
	_edit.visible = false
	_edit.text_submitted.connect(_on_text)
	_edit.gui_input.connect(func(event):
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			_edit.accept_event()
			back())
	content.add_child(_edit)
	_note = UI.rich(13)
	content.add_child(_note)
	_show()


func _items() -> Array:
	return _menus[-1].get("items", [])


func _show() -> void:
	for r in _rows:
		r.queue_free()
	_rows = []
	_edit.visible = _mode == "text"
	_scroll.visible = _mode != "text"
	var menu: Dictionary = _menus[-1]
	var people := false
	var texts: Array = []
	if _mode == "rank":
		set_title(str(_rank_item.get("label", "Rank the candidates")))
		var profiles: Dictionary = _rank_item.get("profiles", {}) if _rank_item.get("profiles") is Dictionary else {}
		people = not profiles.is_empty()
		var names: Array = _rank_item.get("ranked", [])
		for i in range(names.size()):
			var cand := str(names[i])
			var place := _ranking.find(cand) + 1
			var key := KEYS[i] if i < KEYS.length() else " "
			if profiles.has(cand):
				texts.append(_profile(profiles[cand], key, place))
			elif place > 0:
				texts.append(UI.c(UI.GREEN, UI.b("  %d. %s" % [place, UI.esc(cand)])))
			else:
				texts.append("%s %s" % [UI.c(UI.GREEN, UI.b(" %s " % key)), UI.esc(cand)])
		_legend.text = _legend_text(profiles.values()) if people else ""
		_note.text = UI.dim("Press keys in order of preference · Backspace undoes · Enter is done · Esc cancels")
	elif _mode == "text":
		set_title(str(_pending_item.get("text_prompt", "")))
		_note.text = UI.dim("Enter confirms · Esc cancels")
		_legend.text = ""
	else:
		set_title(str(menu.get("title", "")))
		var items := _items()
		var shown: Array = []
		for item in items:
			if item.get("profile") is Dictionary:
				people = true
				shown.append(item["profile"])
		for i in range(items.size()):
			var item: Dictionary = items[i]
			var key := KEYS[i] if i < KEYS.length() else " "
			if item.get("profile") is Dictionary:
				texts.append(_profile(item["profile"], key, 0))
			else:
				var t := "%s %s%s" % [UI.c(UI.GREEN, UI.b(" %s " % key)), UI.esc(item.get("label", "")), UI.c(UI.GOLD, " ▸") if item.has("submenu") else ""]
				if str(item.get("detail", "")) != "":
					t += "\n" + UI.dim("      " + UI.esc(item["detail"]).replace("\n", "\n      "))
				texts.append(t)
		_legend.text = _legend_text(shown) if people else ""
		var note := str(menu.get("note", "")).strip_edges()
		_note.text = (UI.c(UI.YELLOW, UI.esc(note)) + "\n" if note != "" else "") + UI.dim("Key, ↑↓ and Enter, or a click chooses · Esc goes back")
	_legend.visible = _legend.text != ""
	custom_minimum_size = Vector2(minf(1240.0 if people else dialog_width, hud.root.size.x * 0.94), 0)
	for i in range(texts.size()):
		var row := Row.new(texts[i])
		var at := i
		row.chosen.connect(func(): _click(at))
		row.hovered.connect(func(): _set_index(at))
		_list.add_child(row)
		_rows.append(row)
	_index = clampi(_index, 0, maxi(0, _rows.size() - 1))
	_mark()
	var each := 74.0 if people else 50.0
	_scroll.custom_minimum_size = Vector2(0, minf(texts.size() * each + 10.0, hud.root.size.y * 0.66))
	if _mode == "text":
		_edit.text = ""
		_edit.grab_focus.call_deferred()
	_refit.call_deferred()


func _refit() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	_scroll.custom_minimum_size = Vector2(0, minf(_list.get_combined_minimum_size().y + 4.0, hud.root.size.y * 0.66))
	fit()


func _mark() -> void:
	for i in range(_rows.size()):
		(_rows[i] as Row).set_hot(i == _index and _mode != "text")


func _set_index(i: int) -> void:
	if i != _index:
		_index = i
		_mark()


func _legend_text(profiles: Array) -> String:
	## One line explaining the candidate cards: what Fit means and which stats the job uses.
	var pr = null
	for p in profiles:
		if p is Dictionary and p.get("position") != null:
			pr = p
			break
	if pr == null:
		return ""
	var used: Array = []
	for a in pr.get("attributes", []):
		used.append(str(a["name"]))
	if pr.get("skill") is Dictionary:
		used.append(str(pr["skill"]["name"]) + " skill")
	var t := "Fit = how well each would do the work of %s today. It draws on the stats shown, most important first" % pr["position"]
	if not used.is_empty():
		t += " (%s)" % ", ".join(PackedStringArray(used))
	t += "."
	for p in profiles:
		if p is Dictionary and p.get("rank_move") != null and float(p.get("rank_move")) != 0.0:
			t += " ▲/▼: higher or lower work than they have now; they warm to the leaders for a step up and resent a step down."
			break
	return UI.dim(UI.esc(t))


static func ordinal(n: int) -> String:
	if n % 100 >= 10 and n % 100 <= 20:
		return "%dth" % n
	return "%d%s" % [n, {1: "st", 2: "nd", 3: "rd"}.get(n % 10, "th")]


func _profile(pr: Dictionary, key: String, ranked: int) -> String:
	## A person in a pick list: who they are, how well they would do the job, the stats the job uses.
	var t := UI.c(UI.GREEN, UI.b(" %d." % ranked)) if ranked > 0 else UI.c(UI.GREEN, UI.b(" %s " % key))
	t += " " + UI.c(UI.GREEN if pr.get("you", false) else UI.TEXT, UI.b(UI.esc(pr["name"])))
	t += UI.dim(" %d %s" % [int(pr.get("age", 0)), str(pr.get("life_stage", "")).to_lower()])
	var positions := str(pr.get("positions", ""))
	t += "  ·  " + UI.c(UI.CYAN, UI.esc(positions if positions != "" else G.term("member")))
	if not (pr.get("occupations", []) as Array).is_empty():
		t += UI.c(UI.CYAN, "  ·  %s %s" % [pr.get("occupation_icons", ""), UI.esc(", ".join(PackedStringArray(pr["occupations"])))])
	if pr.get("doing") != null:
		t += UI.dim("  ·  %s" % UI.esc(pr["doing"]))
	if pr.get("you", false):
		t += UI.c(UI.GREEN, UI.b("   (you)"))
	if pr.get("holds_it", false):
		t += UI.c(UI.YELLOW, "   holds it now")
	var move = pr.get("rank_move")
	if move != null and float(move) != 0.0:
		t += UI.c(UI.GREEN if float(move) > 0 else UI.RED, "   %s (%s%s rank)" % ["▲ a step up" if float(move) > 0 else "▼ a step down",
				"+" if float(move) > 0 else "", G.num(move)])
	if ranked > 0:
		t += UI.c(UI.GREEN, UI.b("   ← your %s choice" % ordinal(ranked)))
	t += "\n      "
	if pr.get("fit") != null:
		var fit := float(pr["fit"])
		var colour := UI.level_color(fit)
		t += UI.b("Fit ") + UI.c(colour, UI.text_bar(fit, 100, 12)) + UI.c(colour, UI.b(" %d" % int(round(fit)))) + UI.dim("  │")
	for a in pr.get("attributes", []):
		var abbr := str(a["abbr"])
		t += "  %s %s %d" % [UI.b(abbr) if float(a.get("weight", 0)) >= 0.8 else abbr,
				UI.c(UI.ATTRIBUTE, UI.text_bar(float(a["value"]), G.attr_max(), 5)), int(a["value"])]
	if pr.get("skill") is Dictionary:
		var s: Dictionary = pr["skill"]
		t += "  %s %s %.1f" % [UI.b(UI.esc(s["name"])), UI.c(UI.SKILL, UI.text_bar(float(s["value"]), G.skill_max(), 5)), float(s["value"])]
	if pr.get("mood") != null:
		t += UI.dim("  │  mood ") + UI.c(UI.level_color(float(pr["mood"])), "%d" % int(round(float(pr["mood"]))))
	t += "\n      " + UI.i(UI.esc(pr.get("description", "")))
	if not (pr.get("traits", []) as Array).is_empty():
		t += UI.dim("  (%s)" % ", ".join(PackedStringArray(pr["traits"])))
	return t


# --------------------------------------------------------------------------- #
# Choosing
# --------------------------------------------------------------------------- #
func _click(i: int) -> void:
	_index = i
	if _mode == "rank":
		_rank(i)
	else:
		_choose(i)


func _choose(i: int) -> void:
	var items := _items()
	if i < 0 or i >= items.size():
		return
	var item: Dictionary = items[i]
	if item.has("submenu"):
		_menus.append(item["submenu"])
		_index = 0
		_show()
		return
	if local:
		_finish(item)
		return
	if item.get("ranked") is Array and not (item["ranked"] as Array).is_empty():
		_rank_item = item
		_ranking = []
		_mode = "rank"
		_index = 0
		_show()
		return
	_take(item, item.get("action", {}))


func _take(item: Dictionary, action: Dictionary) -> void:
	if action.is_empty():
		return
	if str(item.get("text_prompt", "")) != "" and _mode != "text":
		_pending = action
		_pending_item = item
		_mode = "text"
		_show()
		return
	G.act(action)
	hud.status.say("%s: %s…" % [_label, str(item.get("label", ""))], "dim")
	_finish(item)


func _rank(i: int) -> void:
	var names: Array = _rank_item.get("ranked", [])
	if i < 0 or i >= names.size() or names[i] in _ranking:
		return
	_ranking.append(names[i])
	if _ranking.size() == names.size():
		_rank_done()
	else:
		_show()


func _rank_done() -> void:
	if _ranking.is_empty():
		return
	var base: Dictionary = _rank_item.get("action", {})
	var params: Dictionary = (base.get("params", {}) as Dictionary).duplicate()
	params["choice"] = _ranking[0]
	params["ranking"] = _ranking.duplicate()
	var item := _rank_item
	_mode = "menu"
	_take(item, {"type": base.get("type", "vote"), "params": params, "label": str(_ranking[0]), "group": base.get("group", "")})


func _on_text(text: String) -> void:
	var action := _pending.duplicate(true)
	var params: Dictionary = (action.get("params", {}) as Dictionary).duplicate()
	params["text"] = text.strip_edges()
	action["params"] = params
	G.act(action)
	hud.status.say("%s: %s…" % [_label, str(_pending_item.get("label", ""))], "dim")
	_finish(_pending_item)


func _finish(item) -> void:
	_done = true
	finished.emit(item)
	closed.emit()


func close() -> void:
	if not _done:
		_done = true
		finished.emit(null)
		hud.status.say("Cancelled.", "dim")
	closed.emit()


func back() -> void:
	if _mode != "menu":
		_mode = "menu"
		_show()
	elif _menus.size() > 1:
		_menus.pop_back()
		_index = 0
		_show()
	else:
		close()


func handle_key(key: InputEventKey) -> bool:
	if _mode == "text":
		return false
	match key.keycode:
		KEY_UP:
			_set_index(maxi(0, _index - 1))
			_scroll.ensure_control_visible(_rows[_index]) if not _rows.is_empty() else null
			return true
		KEY_DOWN:
			_set_index(mini(_rows.size() - 1, _index + 1))
			_scroll.ensure_control_visible(_rows[_index]) if not _rows.is_empty() else null
			return true
		KEY_ENTER, KEY_KP_ENTER:
			if key.echo:
				return true
			if _mode == "rank":
				_rank_done()
			else:
				_choose(_index)
			return true
		KEY_BACKSPACE:
			if _mode == "rank" and not _ranking.is_empty():
				_ranking.pop_back()
				_show()
			return true
	if key.echo:
		return true
	var ch := key_char(key)
	var i := KEYS.find(ch) if ch != "" else -1
	if i >= 0:
		if _mode == "rank":
			_rank(i)
		else:
			_choose(i)
		return true
	return false

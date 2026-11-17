class_name InventoryWindow
extends GameWindow
## The inventory window: a grid of slots, the item under the cursor, the camp store and trade offers.
##
## Your own (I):  arrows or a click choose a slot · Enter picks a stack up, then places it · S picks up
## half · O sorts · U uses (eat, drink) · D puts in the store · G gives · T offers a trade (once the
## Barter System is known) · Tab switches to the store (Enter takes all, 1 takes one) · Y / N answer an
## offer made to you · C withdraws yours.
## Someone else's (F2, or click them): look at what they carry; T asks for the item under the cursor,
## G gives them something of yours.
##
## Every change goes to the game as a quick action (it takes no game time); the window redraws from the
## next view, so it always shows what the game holds.

const SLOT := Vector2(152, 64)

var owner_name := ""
var _cursor := 0
var _ground_cursor := 0
var _focus_ground := false
var _holding = null              # {"slot": int, "count": int} (count 0 = the whole stack)
var _busy := false
var _summary: RichTextLabel
var _grid: GridContainer
var _cells: Array = []
var _detail: RichTextLabel
var _ground_box: PanelContainer
var _ground_title: Label
var _ground: RichTextLabel
var _offers: RichTextLabel
var _keys: HFlowContainer
var _keys_mode := ""
var _status: Label
var _ground_style: StyleBoxFlat
var _ground_focus_style: StyleBoxFlat


class SlotCell extends Control:
	signal clicked
	var stack = null
	var selected := false
	var holding := false

	func _init() -> void:
		custom_minimum_size = InventoryWindow.SLOT
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func show_stack(s, is_selected: bool, is_holding: bool) -> void:
		stack = s
		selected = is_selected
		holding = is_holding
		queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			accept_event()
			clicked.emit()

	func _draw() -> void:
		var rect := Rect2(Vector2(2, 2), size - Vector2(4, 4))
		var bg := Color(0.10, 0.12, 0.16) if stack != null else Color(0.07, 0.08, 0.11)
		var border := UI.BORDER_DIM if stack != null else Color(0.17, 0.18, 0.21)
		var width := 1
		if holding:
			bg = Color(0.14, 0.26, 0.15)
			border = UI.GREEN
			width = 2
		elif selected:
			border = UI.GOLD
			width = 2
		draw_style_box(UI.box(bg, border, 6, 0, width), rect)
		if stack == null:
			draw_string(UI.font, Vector2(rect.position.x + rect.size.x * 0.5 - 3, rect.position.y + rect.size.y * 0.5 + 6), "·",
					HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color(0.35, 0.37, 0.41))
			return
		var item := G.item(str(stack["item"]))
		draw_string(UI.font, Vector2(10, 34), str(item.get("icon", "•")), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color.WHITE)
		draw_string(UI.bold, Vector2(46, 28), str(item.get("name", "")), HORIZONTAL_ALIGNMENT_LEFT, size.x - 52, 13, UI.TEXT)
		var n := int(stack["count"])
		var text := "×%d" % n
		draw_string(UI.bold if n > 1 else UI.font, Vector2(46, 48), text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.YELLOW if n > 1 else UI.DIM)
		var extra := ""
		if n >= int(item.get("max_stack", 1)) and int(item.get("max_stack", 1)) > 1:
			extra = "full"
		elif int(item.get("uses", 0)) > 0:
			extra = "%d uses" % int(stack.get("uses", item.get("uses", 0)))
		if extra != "":
			draw_string(UI.font, Vector2(88, 48), extra, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.DIM)


func _init() -> void:
	super()
	wide = false
	dialog_width = 1180.0


func own() -> bool:
	return owner_name == G.you()


func inv() -> Dictionary:
	var found := G.inventory_of(owner_name)
	return found if not found.is_empty() else {"slots": [], "size": 0, "columns": 4, "free": 0}


func _poss() -> Dictionary:
	return G.view.get("possessions", {})


func build() -> void:
	close_key = KEY_NONE
	set_title("Your inventory" if own() else "%s's inventory" % owner_name)
	set_hint("handling items takes no time · Esc closes")
	_summary = UI.rich(14)
	content.add_child(_summary)
	var main := UI.hbox(14)
	content.add_child(main)
	var bag := inv()
	_grid = GridContainer.new()
	_grid.columns = maxi(1, int(bag.get("columns", 4)))
	_grid.add_theme_constant_override("h_separation", 0)
	_grid.add_theme_constant_override("v_separation", 0)
	_grid.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	main.add_child(_grid)
	for i in range(int(bag.get("size", 0))):
		var cell := SlotCell.new()
		var at := i
		cell.clicked.connect(func(): _click_slot(at))
		_grid.add_child(cell)
		_cells.append(cell)
	var side := UI.vbox(8)
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	main.add_child(side)
	_detail = UI.rich(14)
	side.add_child(_boxed("Item", _detail))
	_ground = UI.rich(14)
	_ground.meta_underlined = false
	_ground.meta_clicked.connect(_click_ground)
	_ground_box = _boxed(G.term("store_name").capitalize(), _ground)
	_ground_style = _ground_box.get_theme_stylebox("panel")
	_ground_focus_style = UI.box(UI.INSET, UI.GOLD, 5, 10, 2, 6)
	_ground_box.visible = own()
	side.add_child(_ground_box)
	_offers = UI.rich(14)
	side.add_child(_boxed("Trade offers", _offers))
	_keys = HFlowContainer.new()
	_keys.add_theme_constant_override("h_separation", 16)
	_keys.add_theme_constant_override("v_separation", 4)
	content.add_child(_keys)
	_status = UI.label("", 14, UI.DIM)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(_status)


func _boxed(title: String, inner: Control) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.INSET, UI.BORDER_DIM, 5, 10, 1, 6))
	var v := UI.vbox(3)
	panel.add_child(v)
	v.add_child(UI.label(title, 12, UI.GOLD, true))
	v.add_child(inner)
	return panel


static func describe(stacks: Array) -> String:
	## '3 Wood, 2 Stone'
	var bits: Array = []
	for s in stacks:
		bits.append("%d %s" % [int(s["count"]), G.item(str(s["item"]))["name"]])
	return ", ".join(PackedStringArray(bits))


func hear(items: Array) -> void:
	## New chronicle lines: say how your trades went.
	var me := G.you()
	for m in items:
		var text := str(m["text"])
		if text.contains("%s's trade" % me) or text.contains("between %s and" % me):
			show_result(text + ".", "green" if text.contains(" accepts ") else "yellow")


func show_result(text: String, style: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UI.style_color(style))


# --------------------------------------------------------------------------- #
# Drawing
# --------------------------------------------------------------------------- #
func refresh() -> void:
	if not own() and G.player(owner_name).is_empty():
		close()   # they have died
		return
	var bag := inv()
	var slots: Array = bag.get("slots", [])
	_cursor = clampi(_cursor, 0, maxi(0, slots.size() - 1))
	var t := UI.dim("%d/%d slots used" % [int(bag.get("size", 0)) - int(bag.get("free", 0)), int(bag.get("size", 0))])
	var hands = _poss().get("hands")
	if own() and hands != null and str(hands) != "":
		t += UI.c(UI.RED, UI.b("   you can't handle items while %s" % hands))
	if _holding != null:
		var s = slots[_holding["slot"]] if int(_holding["slot"]) < slots.size() else null
		if s != null:
			var n := int(_holding["count"]) if int(_holding["count"]) > 0 else int(s["count"])
			t += UI.c(UI.YELLOW, UI.b("   moving %s: click a slot or press Enter to place it, Esc to cancel" % describe([{"item": s["item"], "count": n}])))
		else:
			_holding = null
	_summary.text = t
	for i in range(_cells.size()):
		var stack = slots[i] if i < slots.size() else null
		(_cells[i] as SlotCell).show_stack(stack, i == _cursor and not _focus_ground, _holding != null and int(_holding["slot"]) == i)
	_show_detail(slots)
	if own():
		_show_ground()
	_show_offers()
	_show_keys()
	fit.call_deferred()


func _show_detail(slots: Array) -> void:
	var s = slots[_cursor] if _cursor < slots.size() and not _focus_ground else null
	if _focus_ground:
		var ground: Array = _poss().get("ground", [])
		s = ground[_ground_cursor] if _ground_cursor < ground.size() else null
	if s == null:
		_detail.text = UI.dim("Nothing here." if _focus_ground else "An empty slot.")
		return
	var item := G.item(str(s["item"]))
	var t := UI.b("%s %s" % [item["icon"], UI.esc(item["name"])]) + UI.c(UI.YELLOW, UI.b("   ×%d" % int(s["count"]))) + UI.dim("   (stacks to %d)" % int(item.get("max_stack", 1))) + "\n"
	t += UI.i(UI.esc(item.get("description", ""))) + "\n"
	t += UI.dim("Trade value ") + UI.b(G.num(item.get("value", 1))) + UI.dim(" each")
	var uses := int(item.get("uses", 0))
	if uses > 0:
		var left := int(s.get("uses", uses))
		t += "\n" + UI.dim("Wear ") + UI.c(UI.RED if left <= uses / 4 else UI.GREEN, UI.b("%d of %d uses left" % [left, uses]))
	var use: Dictionary = item.get("use", {}) if item.get("use") is Dictionary else {}
	if not use.is_empty():
		var bits: Array = []
		for need in use:
			bits.append("%s +%s" % [need, G.num(use[need])])
		t += "\n" + UI.c(UI.GREEN, "%s: %s" % [item.get("use_label", "Use"), ", ".join(PackedStringArray(bits))])
	_detail.text = t


func _show_ground() -> void:
	var ground: Array = _poss().get("ground", [])
	_ground_cursor = clampi(_ground_cursor, 0, maxi(0, ground.size() - 1))
	_ground_box.add_theme_stylebox_override("panel", _ground_focus_style if _focus_ground else _ground_style)
	var t := ""
	if ground.is_empty():
		t += UI.dim("The %s is empty." % G.term("store_name")) + "\n"
	var line := ""
	for i in range(ground.size()):
		var s: Dictionary = ground[i]
		var item := G.item(str(s["item"]))
		var here := _focus_ground and i == _ground_cursor
		var entry := "%s%s %s %s" % [UI.c(UI.GREEN, "▶") if here else " ", item["icon"], UI.b(UI.esc(item["name"])), UI.c(UI.YELLOW, "×%d" % int(s["count"]))]
		if here:
			entry = "[bgcolor=#4d4226]%s[/bgcolor]" % entry
		line += "[url=%d]%s[/url]     " % [i, entry]
		if i % 3 == 2:
			t += line.strip_edges() + "\n"
			line = ""
	if line != "":
		t += line.strip_edges() + "\n"
	t += UI.dim("Tab: " + ("back to your pack" if _focus_ground else "take things from the store (or click one)"))
	_ground.text = t


func _show_offers() -> void:
	var offers: Array = _poss().get("offers", [])
	var me := G.you()
	var t := ""
	for o in offers:
		if not own() and not (owner_name in [o["from"], o["to"]]):
			continue
		var give := describe(o.get("give", []))
		var want := describe(o.get("want", []))
		if str(o["from"]) == me:
			t += UI.b("You → %s: " % o["to"]) + "%s for %s" % [give if give != "" else "nothing", want if want != "" else "nothing"] \
					+ UI.dim("  waiting for an answer (C withdraws)") + "\n"
		else:
			t += UI.c(UI.GREEN, UI.b("%s → you: " % o["from"])) + "%s for your %s" % [give if give != "" else "nothing", want if want != "" else "nothing"] \
					+ UI.c(UI.GREEN, UI.b("  Y accept · N decline")) + "\n"
	_offers.text = t.strip_edges() if t != "" else UI.dim("No open offers.")


func _show_keys() -> void:
	var barter := bool(_poss().get("barter", false))
	var mode := "%s|%s|%s|%s" % [own(), _focus_ground, _holding != null, barter]
	if mode == _keys_mode:
		return
	_keys_mode = mode
	for c in _keys.get_children():
		c.queue_free()
	var keys: Array = []
	if own() and _focus_ground:
		keys = [["↑↓", "choose", ""], ["Enter", "take all", "enter"], ["1", "take one", "1"], ["Tab", "back to pack", "tab"]]
	elif own():
		keys = [["←↑↓→", "move", ""], ["Enter", "move stack" if _holding == null else "place", "enter"], ["S", "split", "s"],
				["U", "use", "u"], ["D", "to store", "d"], ["G", "give", "g"]]
		if barter:
			keys.append(["T", "trade", "t"])
		keys.append_array([["O", "sort", "o"], ["Tab", "store", "tab"]])
	else:
		keys = [["←↑↓→", "look", ""], ["T", "ask for this or trade" if barter else "ask for this", "t"], ["G", "give them something", "g"]]
	keys.append(["Esc", "close", "esc"])
	for k in keys:
		var b := KeyButton.new(str(k[0]), str(k[1]))
		var what := str(k[2])
		if what != "":
			b.pressed.connect(func(): _do(what))
		_keys.add_child(b)


# --------------------------------------------------------------------------- #
# Input
# --------------------------------------------------------------------------- #
func _submit(type: String, params: Dictionary, text: String) -> void:
	G.quick(type, params)
	show_result(text + "…", "dim")


func back() -> void:
	if _holding != null:
		_holding = null
		refresh()
		return
	close()


func _click_slot(index: int) -> void:
	_focus_ground = false
	_cursor = index
	if own():
		_enter()
	refresh()


func _click_ground(meta) -> void:
	if not own():
		return
	var i := int(str(meta))
	if _focus_ground and i == _ground_cursor:
		_ground_key("enter")   # a second click on it takes it
	else:
		_focus_ground = true
		_holding = null
		_ground_cursor = i
	refresh()


func _stack():
	var slots: Array = inv().get("slots", [])
	return slots[_cursor] if _cursor < slots.size() else null


func _enter() -> void:
	if _holding == null:
		if _stack() != null:
			_holding = {"slot": _cursor, "count": 0}
		return
	var src := int(_holding["slot"])
	var count := int(_holding["count"])
	_holding = null
	if src != _cursor:
		var params := {"slot": src, "to": _cursor}
		if count > 0:
			params["count"] = count
		_submit("move_item", params, "Moving")


func handle_key(key: InputEventKey) -> bool:
	var what := ""
	match key.keycode:
		KEY_LEFT:
			what = "left"
		KEY_RIGHT:
			what = "right"
		KEY_UP:
			what = "up"
		KEY_DOWN:
			what = "down"
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
			what = "enter"
		KEY_TAB:
			what = "tab"
		KEY_ESCAPE:
			return false
		_:
			what = key_char(key)
	if what == "":
		return false
	if key.echo and not (what in ["left", "right", "up", "down"]):
		return true
	return _do(what)


func _do(what: String) -> bool:
	if _busy:
		return true
	var handled := true
	if what == "esc":
		back()
		return true
	if what == "i" and _holding == null:
		close()
		return true
	if what == "tab" and own():
		_focus_ground = not _focus_ground
		_holding = null
	elif _focus_ground and own():
		handled = _ground_key(what)
	elif what in ["left", "right", "up", "down"]:
		var cols := maxi(1, int(inv().get("columns", 4)))
		var step: int = {"left": -1, "right": 1, "up": -cols, "down": cols}[what]
		if _cursor + step >= 0 and _cursor + step < int(inv().get("size", 0)):
			_cursor += step
	elif not own():
		handled = _other_key(what)
	else:
		handled = _own_key(what)
	if handled:
		refresh()
	return handled


func _own_key(k: String) -> bool:
	var s = _stack()
	match k:
		"enter":
			_enter()
		"s":
			if s != null and int(s["count"]) > 1:
				_holding = {"slot": _cursor, "count": int(s["count"]) / 2}
		"o":
			_submit("sort_items", {}, "Sorting")
		"u":
			if s != null:
				var item := G.item(str(s["item"]))
				if item.get("use") is Dictionary and not (item["use"] as Dictionary).is_empty():
					_submit("use_item", {"slot": _cursor}, "%sing" % item.get("use_label", "Us"))
				else:
					show_result("%s can't be used like that." % item["name"], "yellow")
		"d":
			if s != null:
				_drop(_cursor, s)
		"g":
			if s != null:
				_give_own(_cursor, s)
		"t":
			if bool(_poss().get("barter", false)):
				_trade_from_own()
			else:
				return false
		"y", "n", "c":
			_answer(k)
		_:
			return false
	return true


func _ground_key(k: String) -> bool:
	var ground: Array = _poss().get("ground", [])
	match k:
		"up", "left":
			_ground_cursor = maxi(0, _ground_cursor - (3 if k == "up" else 1))
		"down", "right":
			_ground_cursor = mini(maxi(0, ground.size() - 1), _ground_cursor + (3 if k == "down" else 1))
		"enter", "p", "1":
			if not ground.is_empty():
				var s: Dictionary = ground[_ground_cursor]
				var n := 1 if k == "1" else int(s["count"])
				_submit("pick_up", {"item": s["item"], "count": n}, "Picking up %s" % describe([{"item": s["item"], "count": n}]))
		"y", "n", "c":
			_answer(k)
		_:
			return false
	return true


func _other_key(k: String) -> bool:
	match k:
		"t":
			_ask_trade(_stack())
		"g":
			_give_to(owner_name)
		_:
			return false
	return true


# --------------------------------------------------------------------------- #
# Small questions: how many, to whom, which thing
# --------------------------------------------------------------------------- #
static func count_choices(most: int) -> Array:
	## Sensible amounts to offer: 1, 2, 3, 5, 10... up to `most` (always included).
	var out: Array = []
	for n in [1, 2, 3, 5, 10, 15, 20]:
		if n < most:
			out.append(n)
	if most >= 1:
		out.append(most)
	return out


func _count(item_key: String, most: int, verb: String):
	if most <= 1:
		return most
	var items: Array = []
	for n in count_choices(most):
		items.append({"label": "%d%s" % [n, " (all)" if n == most else ""], "value": n})
	var chosen = await hud.pick({"title": "%s how many %s?" % [verb, G.item(item_key)["name"]], "note": "", "items": items})
	return 0 if chosen == null else int(chosen["value"])


func _person(title: String):
	var items: Array = []
	for p in G.players():
		if str(p["name"]) == G.you():
			continue
		var bag = p.get("inventory")
		var note := "%d free slots" % (int(bag.get("free", 0)) if bag is Dictionary else 0)
		if p.get("doing") != null:
			note += " · %s" % p["doing"]
		items.append({"label": str(p["name"]), "detail": note, "value": str(p["name"])})
	var chosen = await hud.pick({"title": title, "note": "", "items": items})
	return "" if chosen == null else str(chosen["value"])


func _merged(pname: String) -> Array:
	## Someone's items, merged by kind (for the trade pickers).
	var totals := {}
	for s in G.inventory_of(pname).get("slots", []):
		if s != null:
			totals[s["item"]] = int(totals.get(s["item"], 0)) + int(s["count"])
	var out: Array = []
	for key in G.defs.get("items", {}):
		if totals.has(key):
			out.append({"item": key, "count": totals[key]})
	return out


func _choose_stack(title: String, stacks: Array, verb: String, allow_nothing: String = ""):
	## Pick one kind of item and an amount. Returns null (cancelled), [] ('nothing', if allowed) or [stack].
	var items: Array = []
	for s in stacks:
		var item := G.item(str(s["item"]))
		items.append({"label": "%s %s  ×%d" % [item["icon"], item["name"], int(s["count"])], "detail": "worth %s each" % G.num(item.get("value", 1)), "value": s})
	if allow_nothing != "":
		items.append({"label": allow_nothing, "value": {}})
	if items.is_empty():
		return null
	var chosen = await hud.pick({"title": title, "note": "", "items": items})
	if chosen == null:
		return null
	var s: Dictionary = chosen["value"]
	if s.is_empty():
		return []
	var n = await _count(str(s["item"]), int(s["count"]), verb)
	return null if int(n) <= 0 else [{"item": s["item"], "count": int(n)}]


static func worth(stacks: Array) -> float:
	var total := 0.0
	for s in stacks:
		total += float(G.item(str(s["item"])).get("value", 1)) * int(s["count"])
	return total


# --------------------------------------------------------------------------- #
# Things you do
# --------------------------------------------------------------------------- #
func _drop(slot: int, s: Dictionary) -> void:
	_busy = true
	var n = await _count(str(s["item"]), int(s["count"]), "Put in the store")
	_busy = false
	if int(n) > 0:
		_submit("drop_item", {"slot": slot, "count": int(n)}, "Putting %s in the store" % describe([{"item": s["item"], "count": int(n)}]))


func _give_own(slot: int, s: Dictionary) -> void:
	_busy = true
	var to = await _person("Give %s to whom?" % G.item(str(s["item"]))["name"])
	var n = 0
	if str(to) != "":
		n = await _count(str(s["item"]), int(s["count"]), "Give")
	_busy = false
	if str(to) != "" and int(n) > 0:
		_submit("give_item", {"slot": slot, "to": to, "count": int(n)}, "Giving %s to %s" % [describe([{"item": s["item"], "count": int(n)}]), to])


func _give_to(to: String) -> void:
	var mine := _merged(G.you())
	if mine.is_empty():
		show_result("You have nothing to give.", "yellow")
		return
	_busy = true
	var chosen = await _choose_stack("Give %s what?" % to, mine, "Give")
	_busy = false
	if chosen == null or (chosen as Array).is_empty():
		return
	var s: Dictionary = chosen[0]
	# From the fullest slots of that item first, one quick action per slot.
	var slots: Array = G.inventory_of(G.you()).get("slots", [])
	var order: Array = []
	for i in range(slots.size()):
		if slots[i] != null and slots[i]["item"] == s["item"]:
			order.append([int(slots[i]["count"]), i])
	order.sort_custom(func(a, b): return a[0] > b[0])
	var left := int(s["count"])
	for entry in order:
		if left <= 0:
			break
		var n := mini(left, int(entry[0]))
		G.quick("give_item", {"slot": entry[1], "to": to, "count": n})
		left -= n
	show_result("Giving %s to %s…" % [describe(chosen), to], "dim")


func _trade_from_own() -> void:
	_busy = true
	var to = await _person("Trade with whom?")
	if str(to) != "":
		await _trade(str(to), null)
	_busy = false


func _ask_trade(s) -> void:
	_busy = true
	await _trade(owner_name, s)
	_busy = false


func _trade(to: String, wanted) -> void:
	## Build an offer: what you want of theirs, then what you give for it.
	var want = null
	if wanted == null:
		want = await _choose_stack("What do you want from %s?" % to, _merged(to), "Ask for", "Nothing — just give them something")
	else:
		var total := int(wanted["count"])
		for x in _merged(to):
			if x["item"] == wanted["item"]:
				total = int(x["count"])
		var n = await _count(str(wanted["item"]), total, "Ask for")
		want = null if int(n) <= 0 else [{"item": wanted["item"], "count": int(n)}]
	if want == null:
		return
	if not bool(_poss().get("barter", false)):   # no Barter System yet: only ask as a gift
		if not (want as Array).is_empty():
			_submit("offer_trade", {"to": to, "give": [], "want": want}, "Asking %s for %s" % [to, describe(want)])
		return
	var give = await _choose_stack("What do you give %s%s?" % [to, (" for %s" % describe(want)) if not (want as Array).is_empty() else ""],
			_merged(G.you()), "Give", "Nothing — ask for it as a gift" if not (want as Array).is_empty() else "")
	if give == null or ((give as Array).is_empty() and (want as Array).is_empty()):
		return
	var note := "(worth %s for %s; they value food and water more when they need it)" % [G.num(worth(give)), G.num(worth(want))]
	_submit("offer_trade", {"to": to, "give": give, "want": want}, "Offering %s %s for %s %s" % [to,
			describe(give) if not (give as Array).is_empty() else "nothing", describe(want) if not (want as Array).is_empty() else "nothing", note])


func _answer(k: String) -> void:
	var offers: Array = _poss().get("offers", [])
	var me := G.you()
	if k == "c":
		for o in offers:
			if str(o["from"]) == me:
				_submit("cancel_trade", {"offer": o["id"]}, "Withdrawing the offer to %s" % o["to"])
				return
		return
	for o in offers:
		if str(o["to"]) == me:
			_submit("answer_trade", {"offer": o["id"], "accept": k == "y"}, ("Accepting" if k == "y" else "Declining") + " %s's offer" % o["from"])
			return

class_name HUD
extends CanvasLayer
## Everything drawn over the world: the panels at the edges, the windows that open over them, and the
## keys. The world shows through wherever no panel is, and takes the mouse there.
##
##   top bar: date, age, government, sky, camp store, pace
##   YOU            (the world)                         TRIBE / FOUND PLACES
##   CHRONICLE      ACTIONS AND KEYS                    MAP
##   GOVERNMENT AND VOTES                               INNOVATION POOL
##   status line
##
## Letters act, F-keys look, the mouse and arrows move the map: the same keys as the terminal HUD.

const LEFT_WIDTH := 410.0
const RIGHT_WIDTH := 392.0
const DETAILS := ["full", "politics", "summary"]

var world: World
var root: Control
var overlay: WorldOverlay
var top: TopBar
var you: YouPanel
var chronicle: ChroniclePanel
var tribe: TribePanel
var minimap: Minimap
var gov: GovPanel
var pool: InnovationPanel
var actions: ActionBar
var status: StatusBar
var toasts: Toasts

var _window_layer: Control
var _veil: ColorRect
var _windows: Array = []
var _dirty := true
var _since := 1.0
var _left: Control
var _right: Control
var _bottom: Control
var _map_panel: Control
var _hotkeys: Dictionary = {}


func _ready() -> void:
	layer = 5
	root = Control.new()
	root.theme = UI.theme()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	overlay = WorldOverlay.new()
	overlay.world = world
	root.add_child(overlay)

	var frame := VBoxContainer.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("separation", 0)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(frame)
	top = TopBar.new()
	top.help_pressed.connect(func(): open_window("help"))
	top.menu_pressed.connect(func(): open_window("menu"))
	frame.add_child(top)

	var middle := UI.hbox(0)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var padded := UI.margin(middle, 8, 8, 8, 8)
	padded.mouse_filter = Control.MOUSE_FILTER_IGNORE
	padded.size_flags_vertical = Control.SIZE_EXPAND_FILL
	frame.add_child(padded)

	var left := UI.vbox(8)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left.custom_minimum_size = Vector2(LEFT_WIDTH, 0)
	middle.add_child(left)
	_left = left
	you = YouPanel.new()
	you.hud = self
	left.add_child(you)
	left.add_child(UI.spacer())
	chronicle = ChroniclePanel.new()
	chronicle.custom_minimum_size = Vector2(0, 250)
	left.add_child(chronicle)

	var centre := UI.vbox(8)
	centre.mouse_filter = Control.MOUSE_FILTER_IGNORE
	centre.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	middle.add_child(centre)
	toasts = Toasts.new()
	centre.add_child(toasts)
	centre.add_child(UI.spacer())
	actions = ActionBar.new()
	actions.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	actions.action_pressed.connect(act)
	actions.command_pressed.connect(command)
	centre.add_child(actions)

	var right := UI.vbox(8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.custom_minimum_size = Vector2(RIGHT_WIDTH, 0)
	middle.add_child(right)
	_right = right
	tribe = TribePanel.new()
	tribe.person_clicked.connect(_on_person_clicked)
	tribe.place_clicked.connect(func(tile):
		world.following = ""
		world.centre_on(world.tile_centre(tile)))
	right.add_child(tribe)
	right.add_child(UI.spacer())
	var map_panel := TitledPanel.new("Map", "click to move · wheel zooms")
	minimap = Minimap.new(world)
	map_panel.body.add_child(minimap)
	right.add_child(map_panel)
	_map_panel = map_panel

	var bottom := UI.hbox(8)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bottom.custom_minimum_size = Vector2(0, 178)
	var bottom_pad := UI.margin(bottom, 8, 0, 8, 6)
	bottom_pad.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(bottom_pad)
	_bottom = bottom_pad
	gov = GovPanel.new()
	gov.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bottom.add_child(gov)
	pool = InnovationPanel.new()
	pool.custom_minimum_size = Vector2(590, 0)
	pool.innovation_clicked.connect(func(iname): open_window("innovations", iname))
	bottom.add_child(pool)
	status = StatusBar.new()
	frame.add_child(status)

	_window_layer = Control.new()
	_window_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_window_layer)
	_veil = ColorRect.new()
	_veil.color = Color(0, 0, 0, 0.5)
	_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_veil.visible = false
	_veil.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed:
			close_top())
	_window_layer.add_child(_veil)

	for k in G.defs.get("action_kinds", []):
		_hotkeys[str(k["hotkey"]).to_upper()] = str(k["type"])

	G.state_changed.connect(func(): _dirty = true)
	G.chronicle_added.connect(_on_chronicle)
	G.alerts_added.connect(_on_alerts)
	G.status_changed.connect(say)
	G.menu_received.connect(_on_menu)
	world.tile_picked.connect(func(text): say(text, "dim"))
	world.person_picked.connect(func(pname): _on_person_clicked(pname, true))
	chronicle.rebuild()
	say("Welcome. The clock is running. F1 for help; letters act, F-keys look.", "dim")
	_refresh()


func _process(delta: float) -> void:
	_since += delta
	if _dirty and _since >= 0.12:
		_refresh()
	# How far the open middle of the screen is from the screen's centre, so 'home' lands in the open.
	var screen := root.size
	var keys_box := (actions.size.y + 8.0) if actions.visible else 0.0
	world.view_shift = Vector2((_left.size.x - _right.size.x) * 0.5, (top.size.y - _bottom.size.y - status.size.y - keys_box) * 0.5)
	world.keys_enabled = _windows.is_empty()
	if screen.x <= 0:
		return


func _refresh() -> void:
	_dirty = false
	_since = 0.0
	if not G.has_view():
		return
	top.refresh()
	you.refresh()
	# The tribe list takes what room is left between the top bar and the small map, and scrolls beyond that.
	var room := root.size.y - top.size.y - _bottom.size.y - status.size.y - 16.0 - _map_panel.size.y - 8.0
	tribe.refresh(maxf(110.0, room - tribe.overhead()))
	gov.refresh()
	pool.refresh()
	actions.refresh()
	status.refresh()
	for w in _windows:
		w.refresh()


func say(text: String, style: String = "") -> void:
	status.say(text, style)
	if not _windows.is_empty():
		_windows[-1].show_result(text, style)


# --------------------------------------------------------------------------- #
# News
# --------------------------------------------------------------------------- #
func _on_chronicle(items: Array) -> void:
	chronicle.add(items)
	var me := G.you()
	for m in items:
		var category := str(m.get("category", ""))
		var text := str(m["text"])
		if category == "find":
			toasts.show_toast("Scouting", text, UI.GOLD, 6.0)
		elif category == "vital":
			toasts.show_toast("Life and death", text, UI.RED if (text.contains("died") or text.contains("dead")) else UI.GREEN, 8.0)
		elif category == "illness" and me != "" and (text.begins_with(me + " ") or text.contains(" %s " % me)):
			toasts.show_toast("You are ill", text, UI.RED, 8.0)
	for w in _windows:
		w.hear(items)


func _on_alerts(items: Array) -> void:
	for a in items:
		if str(a["level"]) in ["action", "urgent"]:
			toasts.show_toast("Government", "%s %s" % [a.get("icon", ""), a["text"]], UI.RED if str(a["level"]) == "urgent" else UI.GREEN, 6.0)
	_dirty = true


func _on_person_clicked(pname: String, twice: bool) -> void:
	overlay.selected = pname
	tribe.set_selected(pname)
	if twice:
		open_window("person", pname)
	else:
		world.find_person(pname)
		var p := G.player(pname)
		if not p.is_empty():
			var doing = p.get("doing")
			say("%s, %d: %s. Click again for more." % [pname, int(p.get("age", 0)), str(doing) if doing != null else "free"], "dim")


# --------------------------------------------------------------------------- #
# Acting
# --------------------------------------------------------------------------- #
func act(kind: String) -> void:
	## An action key was pressed (or its keycap clicked): open your pack, or ask the game for the picker.
	if not G.has_view():
		return
	if kind == "inventory":
		open_window("inventory", G.you())
		return
	G.ask_menu(kind)


func _on_menu(msg: Dictionary) -> void:
	if msg.has("unavailable"):
		say(str(msg["unavailable"]), "yellow")
		return
	if not msg.has("menu"):
		return
	var picker := PickerWindow.new()
	picker.open_menu(msg["menu"], str(msg.get("label", "")))
	_push(picker, "picker")


func pick(menu: Dictionary):
	## A picker for a choice the client makes itself (how many, to whom...): waits for the answer, which
	## is the chosen item, or null if it was closed. Call with `await`.
	var picker := PickerWindow.new()
	picker.local = true
	picker.open_menu(menu, "")
	_push(picker, "picker")
	var chosen = await picker.finished
	return chosen


func command(what: String) -> void:
	if what.begins_with("win:"):
		open_window(what.substr(4))
		return
	match what:
		"pause":
			Net.send({"cmd": "pause"})
		"speed":
			Net.send({"cmd": "speed"})
		"auto":
			Net.send({"cmd": "auto", "on": not bool(G.ui.get("auto", false))})
		"detail":
			var now := DETAILS.find(str(G.ui.get("detail", "full")))
			var level: String = DETAILS[(now + 1) % DETAILS.size()]
			Net.send({"cmd": "detail", "level": level})
			G.ui["detail"] = level
			chronicle.rebuild()
			say("Chronicle shows %s." % G.defs.get("detail_levels", {}).get(level, level), "dim")
		"quit":
			get_parent().call("request_quit")
		"zoom_in":
			world.zoom_by(1.3)
		"zoom_out":
			world.zoom_by(1.0 / 1.3)
		"home":
			world.go_home()
		"me":
			if not world.find_person(G.you()):
				say("You are not on the map.", "yellow")
		"toggle":
			actions.visible = not actions.visible
		"fullscreen":
			var win := get_window()
			win.mode = Window.MODE_MAXIMIZED if win.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


# --------------------------------------------------------------------------- #
# Windows
# --------------------------------------------------------------------------- #
func open_window(kind: String, arg: String = "") -> void:
	if not G.has_view():
		return
	if not _windows.is_empty() and _windows[-1].kind == kind and kind != "inventory" and kind != "person":
		close_top()   # the key that opened a screen also closes it
		return
	var w: GameWindow
	match kind:
		"help":
			w = HelpWindow.new()
		"tribe":
			w = TribeWindow.new()
		"government":
			w = GovernmentWindow.new()
		"innovations":
			var iw := InnovationsWindow.new()
			iw.focus_name = arg
			w = iw
		"log":
			w = LogWindow.new()
		"character":
			w = CharacterWindow.new()
		"society":
			w = SocietyWindow.new()
		"crafts":
			w = CraftsWindow.new()
		"inventory":
			var inv := InventoryWindow.new()
			inv.owner_name = arg if arg != "" else G.you()
			w = inv
		"person":
			var pw := PersonWindow.new()
			pw.pname = arg
			w = pw
		"menu":
			w = MenuWindow.new()
		_:
			return
	_push(w, kind)


func _push(w: GameWindow, kind: String) -> void:
	w.hud = self
	w.kind = kind
	w.closed.connect(func(): _remove(w))
	_window_layer.add_child(w)
	_windows.append(w)
	w.place(root.size)
	w.build()
	w.refresh()
	w.fit()
	w.fit.call_deferred()
	_arrange()


func _remove(w: GameWindow) -> void:
	if w in _windows:
		_windows.erase(w)
		w.queue_free()
		_arrange()


func close_top() -> void:
	if not _windows.is_empty():
		_windows[-1].close()


func _arrange() -> void:
	_veil.visible = not _windows.is_empty()
	_window_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not _windows.is_empty():
		_window_layer.move_child(_veil, _window_layer.get_child_count() - 1)
		_window_layer.move_child(_windows[-1], _window_layer.get_child_count() - 1)


# --------------------------------------------------------------------------- #
# Keys
# --------------------------------------------------------------------------- #
func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey) or not event.pressed:
		return
	var key: InputEventKey = event
	if key.ctrl_pressed and key.keycode == KEY_Q:
		command("quit")
		get_viewport().set_input_as_handled()
		return
	if key.keycode == KEY_F11:
		command("fullscreen")
		get_viewport().set_input_as_handled()
		return
	if not _windows.is_empty():
		var w: GameWindow = _windows[-1]
		if w.handle_key(key):
			pass
		elif key.keycode == KEY_ESCAPE or (w.close_key != KEY_NONE and key.keycode == w.close_key):
			if not key.echo:
				w.back()
		get_viewport().set_input_as_handled()
		return
	if key.echo or key.alt_pressed or key.ctrl_pressed or key.meta_pressed:
		return
	var handled := true
	match key.keycode:
		KEY_F1:
			open_window("help")
		KEY_F2:
			open_window("tribe")
		KEY_F3:
			open_window("government")
		KEY_F4:
			open_window("innovations")
		KEY_F5:
			command("speed")
		KEY_F6:
			command("detail")
		KEY_F7:
			open_window("log")
		KEY_F8:
			open_window("character")
		KEY_F9:
			open_window("society")
		KEY_F10:
			command("quit")
		KEY_F12, KEY_K:
			open_window("crafts")
		KEY_M:
			command("auto")
		KEY_SPACE:
			command("pause")
		KEY_TAB:
			command("toggle")
		KEY_HOME:
			command("home")
		KEY_END:
			command("me")
		KEY_PLUS, KEY_EQUAL, KEY_KP_ADD:
			command("zoom_in")
		KEY_MINUS, KEY_KP_SUBTRACT:
			command("zoom_out")
		KEY_ESCAPE:
			open_window("menu")
		_:
			var name := OS.get_keycode_string(key.keycode).to_upper()
			if _hotkeys.has(name):
				act(_hotkeys[name])
			else:
				handled = false
	if handled:
		get_viewport().set_input_as_handled()

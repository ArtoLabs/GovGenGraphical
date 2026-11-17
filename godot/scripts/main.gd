extends Node
## The root of the client: wakes the engine, shows the title, then the world with the HUD over it.

var world: World
var hud: Node
var title: TitleScreen
var _ui_layer: CanvasLayer
var _quitting := false
var _quit_wait := 0.0
var _end_dialog: Control


func _ready() -> void:
	get_tree().auto_accept_quit = false
	if not Shot.active:
		get_window().mode = Window.MODE_MAXIMIZED
	_ui_layer = CanvasLayer.new()
	_ui_layer.layer = 10
	add_child(_ui_layer)
	title = TitleScreen.new()
	_ui_layer.add_child(title)
	title.start_requested.connect(_start)
	title.quit_requested.connect(request_quit)
	G.hello_received.connect(_on_hello)
	G.state_changed.connect(_on_state)
	G.game_over.connect(_on_game_over)
	G.engine_error.connect(func(text): title.show_problem(text))
	Net.offline.connect(_on_offline)
	Net.launch()


func _on_hello() -> void:
	if world != null:
		world.queue_free()
	world = World.new()
	add_child(world)
	move_child(world, 0)
	world.build(G.defs["map"])
	title.show_ready(G.defs.get("save"))


func _start(new_game: bool, seed_value) -> void:
	Net.send({"cmd": "start", "new": new_game, "seed": seed_value})


func start_new(seed_text: String = "") -> void:
	## (For the screenshot helper.)
	_start(true, int(seed_text) if seed_text.is_valid_int() else null)


func continue_game() -> void:
	## (For the screenshot helper.)
	_start(false, null)


func open_person(pname: String) -> void:
	## (For the screenshot helper.)
	if hud != null:
		hud.open_window("person", pname)


func _on_state() -> void:
	if world != null:
		world.refresh()
	if hud == null and world != null:
		title.visible = false
		hud = HUD.new()
		hud.world = world
		add_child(hud)
		world.find_person(G.you(), false)


func _on_offline(reason: String) -> void:
	if _quitting:
		get_tree().quit()
		return
	if hud != null:
		_show_end("The game engine stopped", reason)
	else:
		title.visible = true
		title.show_problem(reason)


func _on_game_over(reason: String, text: String) -> void:
	if _quitting:
		get_tree().quit()
		return
	match reason:
		"extinct":
			_show_end("The tribe is no more", text)
		"error":
			_show_end("The game stopped", text)
		_:
			_show_end("Game saved", text)


func _show_end(heading: String, text: String) -> void:
	if _end_dialog != null:
		return
	var veil := ColorRect.new()
	veil.color = Color(0, 0, 0, 0.6)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.theme = UI.theme()
	_ui_layer.add_child(veil)
	_end_dialog = veil
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(UI.PANEL_SOLID, UI.GOLD, 8, 28, 2, 22))
	centre.add_child(panel)
	var v := UI.vbox(14)
	panel.add_child(v)
	v.add_child(UI.label(heading, 30, UI.GOLD, true))
	var body := UI.label(text, 17)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(520, 0)
	v.add_child(body)
	var row := UI.hbox(10)
	v.add_child(row)
	var again := UI.button("Back to the title", "", 17)
	again.pressed.connect(_back_to_title)
	row.add_child(again)
	var quit := UI.button("Quit", "", 17)
	quit.pressed.connect(func(): get_tree().quit())
	row.add_child(quit)


func _back_to_title() -> void:
	if _end_dialog != null:
		_end_dialog.queue_free()
		_end_dialog = null
	if hud != null:
		hud.queue_free()
		hud = null
	G.reset()
	Net.close()
	title.visible = true
	title.show_waiting("Waking the game engine…")
	Net.launch()


func request_quit() -> void:
	## Save and leave: the engine saves when told to stop, then says goodbye.
	if _quitting:
		return
	_quitting = true
	_quit_wait = 0.0
	if Net.state == Net.ONLINE:
		Net.send({"cmd": "quit"})
		if hud != null and hud.has_method("say"):
			hud.call("say", "Saving…", "yellow")
	else:
		Net.kill_engine()
		get_tree().quit()


func _process(delta: float) -> void:
	if _quitting:
		_quit_wait += delta
		if _quit_wait > 10.0:
			Net.kill_engine()
			get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()

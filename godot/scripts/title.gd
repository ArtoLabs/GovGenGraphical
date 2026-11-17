class_name TitleScreen
extends Control
## The first screen: the world behind a veil, and whether to go on with the saved game or begin anew.

signal start_requested(new_game: bool, seed_value)
signal quit_requested

var _status: Label
var _buttons: VBoxContainer
var _continue: Button
var _new: Button
var _seed: LineEdit


func _ready() -> void:
	theme = UI.theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.03, 0.05, 0.62)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centre)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.06, 0.085, 0.95), UI.GOLD, 10, 36, 2, 28))
	panel.custom_minimum_size = Vector2(560, 0)
	centre.add_child(panel)
	var v := UI.vbox(12)
	panel.add_child(v)
	var name_label := UI.label("GovGen", 64, UI.GOLD, true)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(name_label)
	var sub := UI.label("Lead a tribe out of the first age", 20, UI.TEXT)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	v.add_child(UI.spacer(false, Vector2(0, 10)))
	_status = UI.label("Waking the game engine…", 16, UI.DIM)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(480, 0)
	v.add_child(_status)
	_buttons = UI.vbox(10)
	_buttons.visible = false
	v.add_child(_buttons)
	_continue = UI.button("Continue", "Go on with the saved game", 20)
	_continue.custom_minimum_size = Vector2(0, 52)
	_continue.pressed.connect(func(): _begin(false))
	_buttons.add_child(_continue)
	_new = UI.button("New game", "Begin with a new tribe (the save is replaced at the first autosave)", 20)
	_new.custom_minimum_size = Vector2(0, 52)
	_new.pressed.connect(func(): _begin(true))
	_buttons.add_child(_new)
	var row := UI.hbox(8)
	row.add_child(UI.label("Seed", 14, UI.DIM))
	_seed = LineEdit.new()
	_seed.placeholder_text = "any number, for a game you can repeat (optional)"
	_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(_seed)
	_buttons.add_child(row)
	var quit := UI.button("Quit", "", 16)
	quit.pressed.connect(func(): quit_requested.emit())
	v.add_child(quit)
	var hint := UI.label("The clock never waits for you. Letters act, F-keys look, the mouse moves the map.  F1: help", 13, UI.DIM)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(hint)


func show_ready(save_summary) -> void:
	## The engine is up: offer the saved game (if there is one) or a new one.
	_buttons.visible = true
	_continue.disabled = false
	_new.disabled = false
	if save_summary == null or str(save_summary) == "":
		_continue.visible = false
		_status.text = "No saved game yet."
	else:
		_continue.visible = true
		_continue.text = "Continue  ·  %s" % str(save_summary).split(" (saved")[0]
		_status.text = "Saved game: %s" % str(save_summary)


func show_problem(text: String) -> void:
	_buttons.visible = false
	_status.text = text
	_status.add_theme_color_override("font_color", UI.RED)


func show_waiting(text: String) -> void:
	_status.text = text
	_status.add_theme_color_override("font_color", UI.DIM)
	_continue.disabled = true
	_new.disabled = true


func _begin(new_game: bool) -> void:
	var seed_text := _seed.text.strip_edges()
	show_waiting("Gathering the tribe…")
	start_requested.emit(new_game, int(seed_text) if seed_text.is_valid_int() else null)

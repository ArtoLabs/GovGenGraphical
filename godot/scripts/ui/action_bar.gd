class_name ActionBar
extends TitledPanel
## Every key as a keycap you can also click: your actions (politics, leading, life), then the screens,
## the game's controls and the map. Tab shows or hides it; the keys work either way.

signal action_pressed(kind: String)
signal command_pressed(command: String)

const KEYS := [
	["Look", [["F1", "Help", "win:help"], ["F2", "Tribe", "win:tribe"], ["F3", "Government", "win:government"],
			["F4", "Innovations", "win:innovations"], ["F7", "Log", "win:log"], ["F8", "You", "win:character"],
			["F9", "Society", "win:society"], ["F12", "Crafts", "win:crafts"]]],
	["Game", [["Space", "Pause", "pause"], ["F5", "Speed", "speed"], ["F6", "Chronicle detail", "detail"],
			["M", "Auto/manual", "auto"], ["F10", "Save+quit", "quit"]]],
	["Map", [["←↑↓→", "Move", ""], ["+", "Zoom in", "zoom_in"], ["-", "Zoom out", "zoom_out"],
			["Home", "Back home", "home"], ["End", "Find yourself", "me"], ["Tab", "Hide these keys", "toggle"]]],
]

var _buttons: Dictionary = {}


func _init() -> void:
	super("Actions and keys", "Tab hides")
	body.add_theme_constant_override("separation", 3)
	for section in G.defs.get("action_sections", []):
		var row := _row(str(section))
		for k in G.defs.get("action_kinds", []):
			if str(k["section"]) != str(section):
				continue
			var b := KeyButton.new(str(k["hotkey"]).to_upper(), str(k["label"]), str(k["title"]))
			var kind := str(k["type"])
			b.pressed.connect(func(): action_pressed.emit(kind))
			row.add_child(b)
			_buttons[kind] = b
	for section in KEYS:
		var row := _row(str(section[0]))
		for k in section[1]:
			var b := KeyButton.new(str(k[0]), str(k[1]), "", "look")
			var command := str(k[2])
			if command != "":
				b.pressed.connect(func(): command_pressed.emit(command))
			row.add_child(b)


func _row(title: String) -> HBoxContainer:
	var line := UI.hbox(10)
	body.add_child(line)
	var name_label := UI.label(title, 12, UI.DIM)
	name_label.custom_minimum_size = Vector2(62, 0)
	line.add_child(name_label)
	var row := UI.hbox(14)
	line.add_child(row)
	return row


func refresh() -> void:
	for g in G.ui.get("groups", []):
		var b: KeyButton = _buttons.get(g["type"])
		if b != null:
			b.set_available(bool(g.get("available", false)))

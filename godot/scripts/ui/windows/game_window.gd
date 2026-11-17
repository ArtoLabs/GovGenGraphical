class_name GameWindow
extends PanelContainer
## A window over the HUD: a title bar and a body. Big ones (wide) fill most of the screen, as the
## F-key screens do; small ones are dialogs that sit in the middle and fit what they hold.
## The game keeps running behind every one of them.

signal closed

var hud
var kind := ""
var close_key: Key = KEY_NONE     # the key that opened it closes it again
var wide := true
var dialog_width := 760.0
var content: VBoxContainer
var _title: Label
var _hint: Label


func _init() -> void:
	add_theme_stylebox_override("panel", UI.box(UI.PANEL_SOLID, UI.GOLD, 8, 16, 2, 12))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(8)
	add_child(v)
	var head := UI.hbox(12)
	v.add_child(head)
	_title = UI.label("", 19, UI.GOLD, true)
	_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(_title)
	_hint = UI.label("Esc closes", 12, UI.DIM)
	head.add_child(_hint)
	var x := UI.button("✕", "Close (Esc)", 14)
	x.pressed.connect(close)
	head.add_child(x)
	content = UI.vbox(8)
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(content)


func set_title(text: String) -> void:
	_title.text = text


func set_hint(text: String) -> void:
	_hint.text = text


func place(_screen: Vector2) -> void:
	if wide:
		anchor_left = 0.03
		anchor_right = 0.97
		anchor_top = 0.05
		anchor_bottom = 0.95
		offset_left = 0
		offset_right = 0
		offset_top = 0
		offset_bottom = 0
	else:
		custom_minimum_size = Vector2(dialog_width, 0)
		fit()


func fit() -> void:
	## (Dialogs) take the size of what is inside, and sit in the middle of the screen.
	if wide or not is_inside_tree():
		return
	var room: Vector2 = (get_parent() as Control).size
	var want := get_combined_minimum_size()
	want.x = minf(want.x, room.x - 20.0)
	size = want
	position = ((room - size) * 0.5).round()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_SORT_CHILDREN:
		if not wide and is_inside_tree():
			var room: Vector2 = (get_parent() as Control).size
			position = ((room - size) * 0.5).round()


func build() -> void:
	pass


func refresh() -> void:
	pass


func hear(_items: Array) -> void:
	pass


func show_result(_text: String, _style: String) -> void:
	pass


func handle_key(_key: InputEventKey) -> bool:
	return false


func back() -> void:
	close()


func close() -> void:
	closed.emit()


static func key_char(key: InputEventKey) -> String:
	## The letter or digit of a key press, lower case ("" for anything else).
	if key.unicode > 32:
		return char(key.unicode).to_lower()
	var name := OS.get_keycode_string(key.keycode)
	return name.to_lower() if name.length() == 1 else ""


static func section(parent: Control, title: String, hint: String = "") -> VBoxContainer:
	## A headed block inside a window; returns the box to fill.
	var v := UI.vbox(4)
	var head := UI.hbox(10)
	head.add_child(UI.label(title, 15, UI.GOLD, true))
	if hint != "":
		var h := UI.label(hint, 12, UI.DIM)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		head.add_child(h)
	v.add_child(head)
	parent.add_child(v)
	return v

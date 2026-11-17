class_name TitledPanel
extends PanelContainer
## A HUD panel: a small gold title, a dim hint beside it, and whatever is put in `body`.

var body: VBoxContainer
var _title: Label
var _hint: Label
var _normal: StyleBoxFlat
var _alert: StyleBoxFlat


func _init(title: String = "", hint: String = "") -> void:
	_normal = UI.box(UI.PANEL, UI.BORDER, 6, 10, 1, 7)
	_alert = UI.box(UI.PANEL, UI.GREEN, 6, 10, 2, 7)
	add_theme_stylebox_override("panel", _normal)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var v := UI.vbox(4)
	add_child(v)
	var head := UI.hbox(8)
	v.add_child(head)
	_title = UI.label(title, 13, UI.GOLD, true)
	head.add_child(_title)
	head.add_child(UI.spacer())
	_hint = UI.label(hint, 12, UI.DIM)
	head.add_child(_hint)
	body = UI.vbox(4)
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(body)


func set_title(text: String) -> void:
	_title.text = text


func set_hint(text: String) -> void:
	_hint.text = text


func set_attention(on: bool) -> void:
	add_theme_stylebox_override("panel", _alert if on else _normal)

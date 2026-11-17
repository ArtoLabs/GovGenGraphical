class_name MemberCard
extends PanelContainer
## One member of the tribe as a card: a portrait, who they are, then boxes of meters for their
## attributes, body, contentment and skills. Used on the Tribe screen and when you click someone.

signal clicked

const LINES := 6

var pname := ""
var _portrait: Portrait
var _name: Label
var _doing: Label
var _head: RichTextLabel
var _boxes: Dictionary = {}
var _plain: StyleBoxFlat
var _mine: StyleBoxFlat
var _chosen: StyleBoxFlat
var _you := false


func _init() -> void:
	_plain = UI.box(UI.INSET, UI.BORDER_DIM, 6, 10, 1, 8)
	_mine = UI.box(UI.INSET, UI.GREEN, 6, 10, 1, 8)
	_chosen = UI.box(Color(0.17, 0.16, 0.12, 0.98), UI.GOLD, 6, 10, 2, 8)
	add_theme_stylebox_override("panel", _plain)
	mouse_filter = Control.MOUSE_FILTER_STOP
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var v := UI.vbox(6)
	add_child(v)
	var top := UI.hbox(10)
	v.add_child(top)
	_portrait = Portrait.new(54)
	top.add_child(_portrait)
	var right := UI.vbox(2)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(right)
	var line := UI.hbox(8)
	right.add_child(line)
	_name = UI.label("", 16, UI.TEXT, true)
	line.add_child(_name)
	line.add_child(UI.spacer())
	_doing = UI.label("", 13, UI.YELLOW)
	line.add_child(_doing)
	_head = UI.rich(13)
	_head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(_head)
	var boxes := UI.hbox(6)
	v.add_child(boxes)
	for title in ["Stats", "Body", "Content", "Skills"]:
		var box := PanelContainer.new()
		box.add_theme_stylebox_override("panel", UI.box(Color(0, 0, 0, 0.22), Color(1, 1, 1, 0.06), 4, 7, 1, 4))
		box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		box.size_flags_stretch_ratio = 0.8 if title == "Stats" else 1.0
		box.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var bv := UI.vbox(2)
		box.add_child(bv)
		bv.add_child(UI.label(title, 11, UI.DIM))
		var m := MeterList.new()
		m.font_size = 12
		m.row_height = 17
		m.bar_height = 7.0
		m.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bv.add_child(m)
		boxes.add_child(box)
		_boxes[title] = m


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		clicked.emit()


func set_selected(on: bool) -> void:
	add_theme_stylebox_override("panel", _chosen if on else (_mine if _you else _plain))


func show_person(p: Dictionary, world: World) -> void:
	pname = str(p["name"])
	_you = pname == G.you()
	_portrait.frame_colour = UI.GREEN if _you else UI.BORDER
	_portrait.show_person(pname, world)
	_name.text = pname + ("  (you)" if _you else "")
	_name.add_theme_color_override("font_color", UI.GREEN if _you else UI.TEXT)
	var doing = p.get("doing")
	_doing.text = str(doing) if doing != null else "free"
	_doing.add_theme_color_override("font_color", UI.YELLOW if doing != null else UI.GREEN)
	_head.text = Rows.head_line(p)
	var lines := maxi(LINES, (G.view.get("satisfaction", {}) as Dictionary).size() + 1)
	(_boxes["Stats"] as MeterList).set_rows(Rows.attributes(p), lines)
	(_boxes["Body"] as MeterList).set_rows(Rows.body(p.get("sheet", {}), true), lines)
	(_boxes["Content"] as MeterList).set_rows(Rows.content(p.get("satisfaction", {}), p.get("mood"), p.get("content_rising")), lines)
	(_boxes["Skills"] as MeterList).set_rows(Rows.skills(p.get("sheet", {}).get("skills", {}), lines), lines)

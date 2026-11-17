class_name StatusBar
extends PanelContainer
## The line along the bottom: who you are, and the latest answer to something you did or asked.

var _text: RichTextLabel
var _status := ""
var _colour := UI.DIM


func _init() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(0.045, 0.055, 0.075, 0.97), UI.BORDER, 0, 12, 1, 4))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := UI.hbox(16)
	add_child(h)
	_text = UI.rich(14)
	_text.autowrap_mode = TextServer.AUTOWRAP_OFF
	_text.clip_contents = true
	_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(_text)
	var hints := UI.label("Tab actions · F1 help · Space pause · drag or ←↑↓→ moves the map · wheel zooms · Home camp · End you", 12, UI.DIM)
	hints.size_flags_horizontal = Control.SIZE_SHRINK_END
	h.add_child(hints)


func say(text: String, style: String = "") -> void:
	_status = text
	_colour = UI.style_color(style)
	refresh()


func refresh() -> void:
	var who := ""
	if G.has_view():
		var pos: Array = G.view.get("your_positions", [])
		who = "%s (%s)" % [G.you(), ", ".join(PackedStringArray(pos)) if not pos.is_empty() else G.term("member")]
	_text.text = "%s %s" % [UI.b(UI.esc(who) + " ▸"), UI.c(_colour, UI.esc(_status))]

class_name KeyButton
extends Control
## A key and what it does, drawn as a keycap with a label: click it or press the key.

signal pressed

var key_text := ""
var label_text := ""
var available := true
var kind := "action"     # "action": green keycap, "look": blue
var _hover := false
const SIZE := 14


func _init(key: String = "", label: String = "", tip: String = "", look: String = "action") -> void:
	key_text = key
	label_text = label
	tooltip_text = tip
	kind = look
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func set_available(on: bool) -> void:
	if on != available:
		available = on
		queue_redraw()


func _get_minimum_size() -> Vector2:
	var f := UI.bold if UI.bold != null else get_theme_default_font()
	if f == null:
		return Vector2(80, 26)
	var kw := maxf(24.0, f.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 12.0)
	var lw := f.get_string_size(label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x
	return Vector2(kw + 6.0 + lw + 6.0, 26)


func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_ENTER:
		_hover = true
		queue_redraw()
	elif what == NOTIFICATION_MOUSE_EXIT:
		_hover = false
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		pressed.emit()


func _draw() -> void:
	var f := UI.bold
	var kw := maxf(24.0, f.get_string_size(key_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 12.0)
	var cap := StyleBoxFlat.new()
	cap.set_corner_radius_all(4)
	var bright := UI.GREEN if kind == "action" else UI.CYAN
	cap.bg_color = (bright if available else Color(0.24, 0.25, 0.28))
	if _hover and available:
		cap.bg_color = cap.bg_color.lightened(0.25)
	cap.border_color = cap.bg_color.darkened(0.45)
	cap.border_width_bottom = 2
	draw_style_box(cap, Rect2(0, 2, kw, 22))
	var base := 2.0 + (22.0 - f.get_height(SIZE)) * 0.5 + f.get_ascent(SIZE)
	draw_string(f, Vector2(0, base), key_text, HORIZONTAL_ALIGNMENT_CENTER, kw, SIZE,
			Color(0.04, 0.06, 0.04) if available else Color(0.5, 0.52, 0.55))
	var text_colour := (Color.WHITE if _hover else UI.TEXT) if available else Color(0.48, 0.5, 0.54)
	draw_string(UI.font, Vector2(kw + 6.0, base), label_text, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, text_colour)

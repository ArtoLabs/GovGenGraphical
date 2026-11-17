class_name MeterList
extends Control
## Rows of `label  bar  note` in aligned columns, drawn in one go (no child nodes), so dozens of them can
## be on screen and refreshed several times a second. A row is a Dictionary:
##   {label, value, total, color, note}   optional: label_color, note_color, strong
## or {text, color} for a plain line.

var rows: Array = []
var font_size := 14
var row_height := 21
var max_bar := 240.0
var min_lines := 0
var bar_height := 9.0
var min_bar := 36.0


func set_rows(new_rows: Array, lines: int = -1) -> void:
	rows = new_rows
	if lines >= 0:
		min_lines = lines
	update_minimum_size()
	queue_redraw()


func _get_minimum_size() -> Vector2:
	return Vector2(110, maxi(rows.size(), min_lines) * row_height)


static func row(label: String, value: float, total: float, color: Color, note: String = "",
		note_color: Color = UI.TEXT, strong: bool = false) -> Dictionary:
	return {"label": label, "value": value, "total": total, "color": color, "note": note,
			"note_color": note_color, "strong": strong}


func _draw() -> void:
	var font := UI.font if UI.font != null else get_theme_default_font()
	var strong_font := UI.bold if UI.bold != null else font
	var label_w := 0.0
	var note_w := 0.0
	for r in rows:
		if r.has("text"):
			continue
		var lf := strong_font if r.get("strong", false) else font
		label_w = maxf(label_w, lf.get_string_size(str(r.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x + 1.0)
		note_w = maxf(note_w, font.get_string_size(str(r.get("note", "")), HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x)
	label_w = minf(label_w, size.x * 0.42)
	var room := size.x - label_w - note_w - (8.0 if label_w > 0 else 0.0) - (8.0 if note_w > 0 else 0.0)
	if room < min_bar:
		note_w = maxf(0.0, note_w - (min_bar - room))
		room = min_bar
	var bar_w := clampf(room, 24.0, max_bar)
	var bar_x := label_w + (8.0 if label_w > 0 else 0.0)
	var ascent := font.get_ascent(font_size)
	var track := StyleBoxFlat.new()
	track.set_corner_radius_all(4)
	track.bg_color = UI.TRACK
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(4)
	var y := 0.0
	for r in rows:
		var base := y + (row_height - font.get_height(font_size)) * 0.5 + ascent
		if r.has("text"):
			draw_string(font, Vector2(0, base), str(r["text"]), HORIZONTAL_ALIGNMENT_LEFT, size.x, font_size, r.get("color", UI.DIM))
			y += row_height
			continue
		var f := strong_font if r.get("strong", false) else font
		draw_string(f, Vector2(0, base), str(r.get("label", "")), HORIZONTAL_ALIGNMENT_LEFT, label_w + 2.0, font_size, r.get("label_color", UI.TEXT))
		var rect := Rect2(bar_x, y + (row_height - bar_height) * 0.5, bar_w, bar_height)
		draw_style_box(track, rect)
		var total := float(r.get("total", 100))
		var frac := 0.0 if total <= 0.0 else clampf(float(r.get("value", 0)) / total, 0.0, 1.0)
		if frac > 0.0:
			fill.bg_color = r.get("color", UI.GREEN)
			draw_style_box(fill, Rect2(rect.position, Vector2(maxf(3.0, bar_w * frac), bar_height)))
		if note_w > 0.0:
			draw_string(font, Vector2(bar_x + bar_w + 8.0, base), str(r.get("note", "")), HORIZONTAL_ALIGNMENT_LEFT, note_w + 2.0, font_size, r.get("note_color", UI.TEXT))
		y += row_height

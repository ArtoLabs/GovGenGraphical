class_name WorldOverlay
extends Control
## What is written over the world, always the same size on screen however far the map is zoomed:
## people's names and what they are doing, the camp's places, and a badge on each found place.

var world: World
var selected := ""


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(_delta: float) -> void:
	queue_redraw()


var _taken: Array = []


func _text(at: Vector2, text: String, size: int, colour: Color, strong: bool = false, apart: bool = false) -> void:
	var f := UI.bold if strong else UI.font
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := Vector2(at.x - w * 0.5, at.y)
	if apart:   # a name that would cover another one moves up above it
		var box := Rect2(pos.x - 2.0, pos.y - size, w + 4.0, size + 3.0)
		for _try in range(6):
			var clash := false
			for other in _taken:
				if box.intersects(other):
					clash = true
					break
			if not clash:
				break
			box.position.y -= size + 3.0
		_taken.append(box)
		pos.y = box.position.y + size
	draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, Color(0, 0, 0, 0.85))
	draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, colour)


func _badge(at: Vector2, text: String, size: int, border: Color) -> void:
	var w := UI.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x + 14.0
	var rect := Rect2(at.x - w * 0.5, at.y - size - 6.0, w, size + 10.0)
	draw_style_box(UI.box(Color(0.05, 0.06, 0.08, 0.88), border, 9, 0, 1), rect)
	draw_string(UI.font, Vector2(rect.position.x + 7.0, rect.position.y + size + 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, UI.TEXT)


func _draw() -> void:
	if world == null or world.camera == null or not G.has_view():
		return
	_taken = []
	var zoom := world.camera.zoom.x
	var bounds := Rect2(Vector2(-80, -40), size + Vector2(160, 80))
	if zoom >= 1.3:
		var names := {"store": G.term("store_name").capitalize(), "workshop": "Workshop", "council": "Council ground"}
		for spot in names:
			if world.spots.has(spot):
				var at := world.world_to_screen(world.tile_centre(world.spots[spot]) + Vector2(0, 26))
				if bounds.has_point(at):
					_text(at, names[spot], 12, Color(0.92, 0.86, 0.70, 0.9))
	for s in world.sites():
		var at := world.world_to_screen(world.tile_centre(Vector2(s["x"], s["y"])) + Vector2(0, -30))
		if bounds.has_point(at):
			var text := "%s %s" % [s["icon"], G.num(s["loads"])] if zoom < 1.3 else "%s %s · %s" % [s["icon"], s["short"], G.num(s["loads"])]
			_badge(at, text, 13, UI.GOLD)
	var bodies := world.bodies()
	for name in bodies:
		var at := world.world_to_screen(bodies[name].head_position())
		if bounds.has_point(at):
			_text(at, "💀 " + name, 12, UI.RED)
	for name in world.people:
		var p: Person = world.people[name]
		var at := world.world_to_screen(p.head_position())
		if not bounds.has_point(at):
			continue
		var colour := UI.GREEN if p.is_you else (UI.YELLOW if p.moving else UI.TEXT)
		if zoom < 0.8:
			# Far out: a dot for everyone, so they can still be found.
			var feet := world.world_to_screen(p.position)
			draw_circle(feet, 4.5, Color(0, 0, 0, 0.8))
			draw_circle(feet, 3.2, colour)
			if p.is_you:
				_text(feet + Vector2(0, -8), name, 12, colour, true)
			continue
		var label: String = name if p.bubble == "" or zoom < 1.0 else "%s %s" % [p.bubble, name]
		_text(at + Vector2(0, -2), label, 13 if p.is_you or name == selected else 12, colour, p.is_you, true)
		if name == selected and not p.is_you:
			var feet := world.world_to_screen(p.position)
			draw_arc(feet, 14.0 * zoom * 0.5, 0.0, TAU, 24, UI.GOLD, 2.0, true)

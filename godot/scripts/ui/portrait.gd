class_name Portrait
extends Control
## A small picture of someone: their figure's head and shoulders in a frame.

var pname := ""
var world: World
var frame_colour := UI.BORDER


func _init(side: int = 64) -> void:
	custom_minimum_size = Vector2(side, side * 1.1)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_person(person_name: String, in_world: World) -> void:
	pname = person_name
	world = in_world
	queue_redraw()


func _draw() -> void:
	draw_style_box(UI.box(Color(0.16, 0.19, 0.16, 1.0), frame_colour, 6, 0, 2), Rect2(Vector2.ZERO, size))
	if world == null or not world.people.has(pname):
		return
	var person: Person = world.people[pname]
	var inner := Rect2(Vector2(3, 3), size - Vector2(6, 6))
	var side := minf(inner.size.x / 36.0, inner.size.y / 40.0)
	var dst := Rect2(inner.position + (inner.size - Vector2(36, 40) * side) * 0.5, Vector2(36, 40) * side)
	Person.draw_bust(self, person.outfit(), dst)

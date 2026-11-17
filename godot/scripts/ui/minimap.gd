class_name Minimap
extends Control
## The whole world at a glance: terrain, the camp, places found, everyone, and the part the screen shows.
## Click or drag on it to move the view.

var world: World
var _tex: ImageTexture
var _since := 0.0


func _init(in_world: World) -> void:
	world = in_world
	_tex = ImageTexture.create_from_image(world.minimap_image())
	custom_minimum_size = Vector2(366, 366.0 * world.height / world.width)
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	mouse_filter = Control.MOUSE_FILTER_STOP
	tooltip_text = "Click or drag to move the view"


func _process(delta: float) -> void:
	_since += delta
	if _since > 0.1:
		_since = 0.0
		queue_redraw()


func _draw() -> void:
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	var k := size / (Vector2(world.width, world.height) * Art.TILE)
	var fire := world.tile_centre(world.spots["fire"]) * k
	draw_arc(fire, float(G.defs["map"].get("radius", 5)) * Art.TILE * k.x, 0.0, TAU, 20, Color(1, 0.85, 0.5, 0.7), 1.0, true)
	draw_circle(fire, 3.0, Color(1.0, 0.55, 0.15))
	for s in world.sites():
		var at := world.tile_centre(Vector2(s["x"], s["y"])) * k
		draw_rect(Rect2(at - Vector2(2.5, 2.5), Vector2(5, 5)), UI.GOLD)
		draw_rect(Rect2(at - Vector2(2.5, 2.5), Vector2(5, 5)), Color.BLACK, false, 1.0)
	for name in world.people:
		var p: Person = world.people[name]
		var at := p.position * k
		draw_circle(at, 2.6, Color(0, 0, 0, 0.9))
		draw_circle(at, 1.8, UI.GREEN if p.is_you else Color.WHITE)
	var view := world.visible_world_rect()
	draw_rect(Rect2(view.position * k, view.size * k).intersection(Rect2(Vector2.ZERO, size)), Color(1, 1, 1, 0.95), false, 1.5)
	draw_rect(Rect2(Vector2.ZERO, size), UI.BORDER, false, 1.0)


func _gui_input(event: InputEvent) -> void:
	var go := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		go = true
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
		go = true
	if go:
		accept_event()
		world.following = ""
		world.centre_on(event.position / size * Vector2(world.width, world.height) * Art.TILE)

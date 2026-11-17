class_name World
extends Node2D
## The world map as a place: the ground (one shader over the whole grid), what grows and lies on it,
## the camp around its fire, the places Scouts have found, and everyone walking about. It shows what
## the game says (G.defs["map"] once, G.view["map"] as it changes) and decides nothing.
##
## Map tiles are Art.TILE world pixels. Things that stand up (trees, rocks, props, people) share one
## y-sorted layer, so a person walks behind a tree that is south of them and in front of one north.

signal tile_picked(text: String)
signal person_picked(pname: String)

const SEGMENT := 40          # tiles of a row drawn by one decoration chunk
const BLOCK := 20            # tiles across a block of things lying flat on the ground
const MAX_ZOOM := 4.0
const SEASON_LEAVES := {"Spring": Color(0.90, 1.0, 0.80), "Summer": Color(1, 1, 1),
		"Autumn": Color(1.0, 0.80, 0.52), "Winter": Color(0.80, 0.84, 0.88)}
const SEASON_SNOW := {"Spring": 0.0, "Summer": 0.0, "Autumn": 0.0, "Winter": 0.85}

var width := 0
var height := 0
var terrain_defs: Dictionary = {}    # terrain key -> its definition
var spots: Dictionary = {}           # camp spot -> Vector2i
var people: Dictionary = {}          # name -> Person
var camera: Camera2D
var target_zoom := 1.6
var following := ""                  # the person the view keeps on (until you move it yourself)
var view_shift := Vector2.ZERO       # screen pixels from the screen's centre to the middle of what no panel covers
var keys_enabled := true
var night := 0.0                     # 0 broad day, 1 deep night (for anything that glows)

var _kinds: PackedStringArray = []   # terrain key of every tile, row by row
var _material: ShaderMaterial
var _flat: Node2D
var _sorted: Node2D
var _leafy: Array = []
var _daylight: CanvasModulate
var _fire: FireProp
var _store: Prop
var _beds: Prop
var _site_nodes: Dictionary = {}
var _body_nodes: Dictionary = {}
var _known_beds: Dictionary = {}
var _drag_from := Vector2.ZERO
var _drag_cam := Vector2.ZERO
var _dragging := false
var _dragged := false
var _zoom_anchor_screen := Vector2.ZERO
var _zoom_anchor_world := Vector2.ZERO
var _zoom_anchored := false
var _leaf := Color.WHITE
var _snow := 0.0


# --------------------------------------------------------------------------- #
# Small drawing nodes
# --------------------------------------------------------------------------- #
class Chunk extends Node2D:
	## A handful of trees, rocks or flowers drawn in one go. An item is
	## [sheet (0 trees, 1 terrain, 2 props), source, where, scale, colour, flipped] or ["shadow", where, radius].
	var items: Array = []

	func _draw() -> void:
		for it in items:
			if it[0] is String:
				draw_set_transform(it[1], 0.0, Vector2(1.0, 0.42))
				draw_circle(Vector2.ZERO, it[2], Color(0, 0, 0, 0.22))
				draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			elif it[0] == 2:
				Art.draw_k(self, it[1], it[2], it[3], it[4], it[5])
			else:
				Art.draw_piece(self, Art.trees() if it[0] == 0 else Art.terrain(), it[1], it[2], it[3], it[4], it[5])


class Prop extends Node2D:
	## Something that draws itself with a function given to it (the store, a found place, sleeping mats).
	var painter: Callable

	func _draw() -> void:
		if painter.is_valid():
			painter.call(self)


class FireProp extends Node2D:
	## The fire the camp lives around: a ring of stones, flames while it burns, embers, and its light.
	var burning := true
	var darkness := 0.0
	var _t := 0.0
	var _light: PointLight2D
	var _embers: CPUParticles2D

	func _ready() -> void:
		var gradient := Gradient.new()
		gradient.set_color(0, Color(1, 1, 1, 1))
		gradient.set_color(1, Color(0, 0, 0, 0))
		gradient.add_point(0.45, Color(0.45, 0.45, 0.45, 0.45))
		var tex := GradientTexture2D.new()
		tex.gradient = gradient
		tex.fill = GradientTexture2D.FILL_RADIAL
		tex.fill_from = Vector2(0.5, 0.5)
		tex.fill_to = Vector2(1.0, 0.5)
		tex.width = 256
		tex.height = 256
		_light = PointLight2D.new()
		_light.texture = tex
		_light.texture_scale = 3.4
		_light.color = Color(1.0, 0.70, 0.40)
		_light.position = Vector2(0, -10)
		add_child(_light)
		_embers = CPUParticles2D.new()
		_embers.position = Vector2(0, -14)
		_embers.amount = 16
		_embers.lifetime = 1.5
		_embers.direction = Vector2(0, -1)
		_embers.spread = 28.0
		_embers.gravity = Vector2(0, -26)
		_embers.initial_velocity_min = 10.0
		_embers.initial_velocity_max = 26.0
		_embers.scale_amount_min = 1.5
		_embers.scale_amount_max = 2.6
		var ramp := Gradient.new()
		ramp.set_color(0, Color(1.0, 0.85, 0.35, 0.95))
		ramp.set_color(1, Color(1.0, 0.25, 0.05, 0.0))
		_embers.color_ramp = ramp
		add_child(_embers)

	func _process(delta: float) -> void:
		_t += delta
		_embers.emitting = burning
		_light.enabled = burning
		_light.energy = (0.25 + 1.15 * darkness) * (0.9 + 0.1 * sin(_t * 9.0) + 0.06 * sin(_t * 23.0))
		queue_redraw()

	func _draw() -> void:
		var stones: Array = Art.ROCKS_SMALL
		for half in [0, 1]:   # the stones behind the flames, the fire, the stones in front
			for i in range(8):
				var a := TAU * i / 8.0 + 0.2
				if (sin(a) < 0.0) != (half == 0):
					continue
				Art.draw_piece(self, Art.terrain(), stones[i % stones.size()], Vector2(cos(a) * 19.0, 6.0 + sin(a) * 9.0), 0.62,
						Color(0.78, 0.78, 0.8))
			if half == 0:
				if burning:
					Art.draw_k(self, Art.K_FIRE[int(_t * 7.0) % 2], Vector2(0, 8), 2.0)
				else:
					Art.draw_k(self, Art.K_FIRE_OUT, Vector2(0, 8), 2.0, Color(0.55, 0.55, 0.58))


# --------------------------------------------------------------------------- #
# Building the world (once)
# --------------------------------------------------------------------------- #
func build(map: Dictionary) -> void:
	width = int(map["width"])
	height = int(map["height"])
	terrain_defs = map.get("terrain", {})
	var by_code := {}
	for key in terrain_defs:
		by_code[str(terrain_defs[key]["code"])] = key
	_kinds.resize(width * height)
	var rows: Array = map["rows"]
	for y in range(height):
		var row: String = rows[y]
		for x in range(width):
			_kinds[y * width + x] = by_code.get(row[x], "plains")
	for name in map.get("spots", {}):
		spots[name] = Vector2i(int(map["spots"][name][0]), int(map["spots"][name][1]))
	if not spots.has("fire"):
		spots["fire"] = Vector2i(int(map["home"][0]), int(map["home"][1]))

	_build_ground()
	_flat = Node2D.new()
	add_child(_flat)
	_beds = Prop.new()
	_beds.painter = _paint_beds
	add_child(_beds)
	_sorted = Node2D.new()
	_sorted.y_sort_enabled = true
	add_child(_sorted)
	_grow()
	_build_camp()
	_daylight = CanvasModulate.new()
	add_child(_daylight)
	camera = Camera2D.new()
	add_child(camera)
	camera.make_current()
	camera.zoom = Vector2(target_zoom, target_zoom)
	go_home()


func kind_at(x: int, y: int) -> String:
	if x < 0 or y < 0 or x >= width or y >= height:
		return ""
	return _kinds[y * width + x]


func _build_ground() -> void:
	var ids := Image.create(width, height, false, Image.FORMAT_R8)
	for y in range(height):
		for x in range(width):
			var id: int = Art.TERRAIN_ID.get(_kinds[y * width + x], Art.UNKNOWN_TERRAIN)
			ids.set_pixel(x, y, Color(id / 255.0, 0, 0))
	# Three layers of smooth noise, one in each colour channel, for bending borders and mixing textures.
	var noise_image := Image.create(256, 256, false, Image.FORMAT_RGB8)
	var layers: Array = []
	for seed in [11, 23, 37]:
		var n := FastNoiseLite.new()
		n.seed = seed
		n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		n.frequency = 0.03
		n.fractal_octaves = 3
		layers.append(n.get_seamless_image(256, 256))
	for y in range(256):
		for x in range(256):
			noise_image.set_pixel(x, y, Color(layers[0].get_pixel(x, y).r, layers[1].get_pixel(x, y).r, layers[2].get_pixel(x, y).r))
	_material = ShaderMaterial.new()
	_material.shader = load("res://scripts/world/ground.gdshader")
	_material.set_shader_parameter("terrain_map", ImageTexture.create_from_image(ids))
	_material.set_shader_parameter("ground", Art.ground_array())
	_material.set_shader_parameter("noise_tex", ImageTexture.create_from_image(noise_image))
	_material.set_shader_parameter("map_size", Vector2(width, height))
	_material.set_shader_parameter("tile_px", float(Art.TILE))
	_material.set_shader_parameter("camp", Vector2(spots["fire"]))
	var white := Image.create(1, 1, false, Image.FORMAT_RGB8)
	white.fill(Color.WHITE)
	var ground := Sprite2D.new()
	ground.texture = ImageTexture.create_from_image(white)
	ground.centered = false
	ground.scale = Vector2(width, height) * Art.TILE
	ground.material = _material
	add_child(ground)


func _grow() -> void:
	## Trees, rocks, reeds and flowers: the same on every run, since each tile's are picked from its
	## own coordinates.
	var fire: Vector2i = spots["fire"]
	var flat: Dictionary = {}     # block -> items
	var tall: Dictionary = {}     # [row, segment, leafy] -> items
	var T := float(Art.TILE)
	for y in range(height):
		for x in range(width):
			if maxi(absi(x - fire.x), absi(y - fire.y)) <= 3:
				continue
			var kind := _kinds[y * width + x]
			var r := Art.hash2(x, y, 1)
			var at := Vector2(x * T + T * 0.5 + (Art.hash2(x, y, 2) - 0.5) * 20.0, y * T + T - 4.0 + (Art.hash2(x, y, 3) - 0.5) * 12.0)
			var flip := Art.hash2(x, y, 4) < 0.5
			var size := Art.hash2(x, y, 5)
			var pick := Art.hash2(x, y, 6)
			var shade := 0.9 + 0.1 * Art.hash2(x, y, 7)
			var tone := Color(shade, shade, shade)
			var item = null
			var leafy := true
			var lies_flat := false
			var shadow := 0.0
			match kind:
				"forest":
					if r < 0.30:
						var s := 0.50 + 0.30 * size
						item = [0, Art.TREE_A if pick < 0.5 else Art.TREE_B, at, s, tone, flip]
						shadow = 34.0 * s
					elif r < 0.44:
						item = [0, [Art.BUSH, Art.FERN, Art.CONE_BUSH][int(pick * 3) % 3], at, 0.8 + 0.4 * size, tone, flip]
					elif r < 0.50:
						item = [0, Art.SPROUT if pick < 0.6 else Art.FLOWER, at, 1.0, tone, flip]
						lies_flat = true
				"deep_forest":
					var dark := Color(shade * 0.80, shade * 0.88, shade * 0.84)
					if r < 0.52:
						var s := 0.68 + 0.36 * size
						item = [0, Art.TREE_B if pick < 0.6 else Art.TREE_A, at, s, dark, flip]
						shadow = 36.0 * s
					elif r < 0.72:
						item = [0, Art.FERN if pick < 0.6 else Art.CONE_BUSH, at, 0.9 + 0.5 * size, dark, flip]
				"plains":
					if r < 0.007:
						item = [0, Art.TREE_A if pick < 0.5 else Art.TREE_B, at, 0.50 + 0.2 * size, tone, flip]
						shadow = 20.0
					elif r < 0.022:
						item = [0, Art.BUSH if pick < 0.6 else Art.CONE_BUSH, at, 0.75 + 0.3 * size, tone, flip]
					elif r < 0.060:
						item = [0, [Art.FLOWER_BUSH, Art.FLOWER, Art.SPROUT][int(pick * 3) % 3], at, 1.0, tone, flip]
						lies_flat = true
				"marsh":
					if r < 0.30:
						item = [1, Art.REEDS[int(pick * 4) % 4], at, 0.55 + 0.25 * size, tone, flip]
					elif r < 0.42:
						item = [1, Art.LILIES[int(pick * 5) % 5], at, 0.8, tone, flip]
						lies_flat = true
				"hills":
					leafy = false
					if r < 0.09:
						item = [1, Art.BOULDERS_BROWN[int(pick * 3) % 3], at, 0.60 + 0.35 * size, tone, flip]
						shadow = 16.0
					elif r < 0.22:
						item = [1, Art.ROCKS_MEDIUM_BROWN[int(pick * 2) % 2], at, 0.7 + 0.3 * size, tone, flip]
					elif r < 0.36:
						item = [1, Art.ROCKS_SMALL[int(pick * 4) % 4], at, 1.0, Color(0.92, 0.84, 0.66), flip]
						lies_flat = true
					elif r < 0.40:
						item = [0, Art.BUSH, at, 0.7 + 0.3 * size, Color(0.92, 0.9, 0.7), flip]
						leafy = true
				"mountains":
					leafy = false
					if r < 0.40:
						item = [1, Art.BOULDERS_DARK[int(pick * 3) % 3], at, 0.95 + 0.75 * size, tone, flip]
						shadow = 22.0
					elif r < 0.66:
						item = [1, Art.ROCKS_MEDIUM_DARK[int(pick * 3) % 3], at, 0.9 + 0.5 * size, tone, flip]
					elif r < 0.80:
						item = [1, Art.ROCKS_SMALL[int(pick * 4) % 4], at, 1.1, Color(0.7, 0.7, 0.74), flip]
						lies_flat = true
				"peaks":
					leafy = false
					if r < 0.72:
						item = [1, Art.ROCK_WHITE, at, 2.2 + 1.5 * size, tone, flip]
						shadow = 24.0
					elif r < 0.9:
						item = [1, Art.BOULDERS_DARK[int(pick * 3) % 3], at, 1.2 + 0.6 * size, Color(0.9, 0.92, 0.96), flip]
				"sand":
					leafy = false
					if r < 0.035:
						item = [1, Art.ROCKS_SMALL[int(pick * 4) % 4], at, 0.9, Color(0.95, 0.9, 0.8), flip]
						lies_flat = true
			if item == null:
				continue
			var block := Vector2i(x / BLOCK, y / BLOCK)
			if shadow > 0.0:
				flat.get_or_add(block, []).append(["shadow", at + Vector2(0, -2), shadow])
			if lies_flat:
				flat.get_or_add(block, []).append(item)
			else:
				tall.get_or_add([y, x / SEGMENT, leafy], []).append(item)
	for block in flat:
		var node := Chunk.new()
		node.items = flat[block]
		_flat.add_child(node)
	for key in tall:
		var node := Chunk.new()
		var base := Vector2(0, (int(key[0]) + 1) * T - 4.0)
		for it in tall[key]:
			it[2] -= base
		node.items = tall[key]
		node.position = base
		_sorted.add_child(node)
		if key[2]:
			_leafy.append(node)


func tile_centre(tile) -> Vector2:
	return (Vector2(tile) + Vector2(0.5, 0.5)) * Art.TILE


func _build_camp() -> void:
	_fire = FireProp.new()
	_fire.position = tile_centre(spots["fire"])
	_sorted.add_child(_fire)
	if spots.has("store"):
		_store = Prop.new()
		_store.position = tile_centre(spots["store"]) + Vector2(0, 8)
		_store.painter = _paint_store
		_sorted.add_child(_store)
	if spots.has("workshop"):
		var shop := Prop.new()
		shop.position = tile_centre(spots["workshop"]) + Vector2(0, 8)
		shop.painter = func(c: CanvasItem):
			Art.draw_k(c, Art.K_LOGS, Vector2(22, 4), 2.0)
			Art.draw_k(c, Art.K_STUMP, Vector2(-22, 2), 2.0)
			Art.draw_k(c, Art.K_STUMP_AXE, Vector2(0, 6), 2.0)
		_sorted.add_child(shop)
	if spots.has("council"):
		var council := Prop.new()
		council.position = tile_centre(spots["council"]) + Vector2(0, 6)
		council.painter = func(c: CanvasItem):
			for i in range(5):
				var a := PI * (0.12 + 0.19 * i)
				Art.draw_piece(c, Art.terrain(), Art.ROCKS_MEDIUM_DARK[i % 3], Vector2(cos(a) * 30.0, 10.0 + sin(a) * 9.0), 0.7)
			Art.draw_piece(c, Art.terrain(), Art.STANDING_STONE, Vector2(0, 0), 1.0)
		_sorted.add_child(council)


func _paint_store(c: CanvasItem) -> void:
	var total := 0
	var wood := 0
	var food := 0
	for s in G.view.get("possessions", {}).get("ground", []):
		total += int(s["count"])
		var kind := str(G.item(s["item"]).get("kind", ""))
		if s["item"] == "wood":
			wood += int(s["count"])
		if kind == "food":
			food += int(s["count"])
	if wood > 0:
		Art.draw_k(c, Art.K_LOGS, Vector2(-26, 2), 2.0)
	if total > 30:
		Art.draw_k(c, Art.K_CRATES[1], Vector2(-4, -22), 2.0)
	Art.draw_k(c, Art.K_CRATES[0], Vector2(-8, 4), 2.0, Color.WHITE if total > 0 else Color(0.8, 0.8, 0.8))
	if total > 8:
		Art.draw_k(c, Art.K_CRATES[1], Vector2(12, 6), 2.0)
	if food > 0:
		Art.draw_k(c, Art.K_SACK, Vector2(30, 6), 2.0)


func _paint_beds(c: CanvasItem) -> void:
	## A sleeping mat of hides for everyone, at their own place around the fire.
	for name in _known_beds:
		if not people.has(name):
			continue
		var at := tile_centre(_known_beds[name]) + Vector2(0, 6)
		var h := absi(hash(name))
		var hide := Color(0.50 + (h % 7) * 0.02, 0.38 + (h % 5) * 0.02, 0.26 + (h % 3) * 0.02)
		var mat := StyleBoxFlat.new()
		mat.bg_color = hide
		mat.set_corner_radius_all(4)
		mat.border_color = hide.darkened(0.35)
		mat.set_border_width_all(1)
		c.draw_style_box(mat, Rect2(at - Vector2(14, 9), Vector2(28, 18)))
		mat.bg_color = hide.lightened(0.25)
		mat.set_border_width_all(0)
		c.draw_style_box(mat, Rect2(at - Vector2(11, 7), Vector2(8, 14)))


func _site_painter(kind: String) -> Callable:
	match Art.SITE_PROPS.get(kind, "flag"):
		"berry":
			return func(c: CanvasItem):
				Art.draw_k(c, Art.K_FRUIT_BUSH, Vector2(-16, -2), 2.0)
				Art.draw_k(c, Art.K_BERRY_BUSH, Vector2(14, 0), 2.0)
				Art.draw_k(c, Art.K_BERRY_BUSH, Vector2(-2, 10), 2.0, Color.WHITE, true)
		"deadwood":
			return func(c: CanvasItem):
				Art.draw_k(c, Art.K_DEAD_TREE, Vector2(-8, 4), 2.0)
				Art.draw_k(c, Art.K_LOGS, Vector2(18, 8), 2.0)
		"stone":
			return func(c: CanvasItem):
				Art.draw_piece(c, Art.terrain(), Art.ROCKS_MEDIUM_DARK[1], Vector2(-14, 2), 1.0)
				Art.draw_piece(c, Art.terrain(), Art.ROCK_WHITE, Vector2(8, 6), 1.3)
				Art.draw_piece(c, Art.terrain(), Art.ROCKS_SMALL[0], Vector2(22, 8), 1.0)
		"tracks":
			return func(c: CanvasItem):
				for i in range(6):
					var at := Vector2(-20 + i * 8, 2 - (i % 2) * 7 + i)
					c.draw_circle(at, 2.4, Color(0.16, 0.11, 0.07, 0.75))
					c.draw_circle(at + Vector2(3, -2), 1.6, Color(0.16, 0.11, 0.07, 0.75))
				Art.draw_piece(c, Art.trees(), Art.FERN, Vector2(18, -2), 0.8)
		"pool":
			return func(c: CanvasItem):
				c.draw_set_transform(Vector2(0, 0), 0.0, Vector2(1.0, 0.5))
				c.draw_circle(Vector2.ZERO, 22.0, Color(0.55, 0.85, 1.0, 0.35))
				c.draw_arc(Vector2.ZERO, 22.0, 0.0, TAU, 24, Color(0.9, 0.98, 1.0, 0.8), 1.5)
				c.draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.9, 0.98, 1.0, 0.6), 1.5)
				c.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
				Art.draw_piece(c, Art.terrain(), Art.REEDS[1], Vector2(-22, 6), 0.5)
		"herb":
			return func(c: CanvasItem):
				Art.draw_piece(c, Art.trees(), Art.FLOWER_BUSH, Vector2(-12, 0), 1.3)
				Art.draw_k(c, Art.K_HERB, Vector2(12, 4), 2.0)
				Art.draw_piece(c, Art.trees(), Art.SPROUT, Vector2(2, 10), 1.1)
		"garden":
			return func(c: CanvasItem):
				Art.draw_piece(c, Art.terrain(), Art.GARDEN_PLOT, Vector2(0, 32), 1.0)
	return func(c: CanvasItem):
		c.draw_line(Vector2(0, 6), Vector2(0, -34), Color(0.4, 0.28, 0.16), 3.0)
		c.draw_colored_polygon(PackedVector2Array([Vector2(1, -34), Vector2(22, -27), Vector2(1, -20)]), Color(0.9, 0.3, 0.25))


# --------------------------------------------------------------------------- #
# Following the game
# --------------------------------------------------------------------------- #
func refresh() -> void:
	## A new view has arrived.
	var scene: Dictionary = G.view.get("map", {})
	var seen := {}
	for p in scene.get("people", []):
		var name: String = p["name"]
		seen[name] = true
		var person: Person = people.get(name)
		if person == null:
			person = Person.new()
			person.setup(name)
			person.tile_pos = Person.position_at(p["pos"], p.get("legs", []), G.clock())
			person.position = tile_centre(person.tile_pos)
			_sorted.add_child(person)
			people[name] = person
		person.refresh(p, G.player(name))
		_known_beds[name] = Vector2(p["bed"][0], p["bed"][1])
	for name in people.keys():
		if not seen.has(name):
			people[name].queue_free()
			people.erase(name)
	_beds.queue_redraw()
	if _store != null:
		_store.queue_redraw()
	_fire.burning = bool(scene.get("fire_burning", true))
	# Places found.
	var sites := {}
	for s in scene.get("sites", []):
		var key := "%s:%d:%d" % [s["kind"], int(s["x"]), int(s["y"])]
		sites[key] = true
		if not _site_nodes.has(key):
			var node := Prop.new()
			node.position = tile_centre(Vector2(s["x"], s["y"])) + Vector2(0, 6)
			node.painter = _site_painter(str(s["kind"]))
			_sorted.add_child(node)
			_site_nodes[key] = node
	for key in _site_nodes.keys():
		if not sites.has(key):
			_site_nodes[key].queue_free()
			_site_nodes.erase(key)
	# The dead, until they are laid to rest.
	var dead := {}
	for b in G.view.get("life", {}).get("bodies", []):
		var name: String = b["name"]
		dead[name] = true
		if not _body_nodes.has(name):
			var body := Person.new()
			var fire: Vector2i = spots["fire"]
			var where: Vector2 = _known_beds.get(name, Vector2(fire) + Vector2(3, 2))
			body.lie_dead(name, where)
			_sorted.add_child(body)
			_body_nodes[name] = body
	for name in _body_nodes.keys():
		if not dead.has(name):
			_body_nodes[name].queue_free()
			_body_nodes.erase(name)
			_known_beds.erase(name)


func sites() -> Array:
	return G.view.get("map", {}).get("sites", [])


func bodies() -> Dictionary:
	return _body_nodes


func _season_now() -> Array:
	## [leaf colour, snow] for today. Leaves slide from one season's colour to the next over a season's first
	## ten days; snow comes over the first ten days of winter and melts over its last ten.
	var seasons: Array = G.defs.get("time", {}).get("seasons", ["Spring", "Summer", "Autumn", "Winter"])
	var per := G.time_def("days_per_season", 90)
	var day := fmod(G.clock(), G.time_def("hours_per_year", 8640)) / G.time_def("hours_per_day", 24)
	var index := int(day / per) % seasons.size()
	var into_days := fmod(day, per)
	var into := clampf(into_days / 10.0, 0.0, 1.0)
	var now: String = seasons[index]
	var before: String = seasons[(index + seasons.size() - 1) % seasons.size()]
	var leaf: Color = SEASON_LEAVES.get(before, Color.WHITE).lerp(SEASON_LEAVES.get(now, Color.WHITE), into)
	var lying := float(SEASON_SNOW.get(now, 0.0)) * minf(into, clampf((per - into_days) / 10.0, 0.0, 1.0))
	return [leaf, lying]


func _sky_colour(phase: float) -> Color:
	## The light of the day-night cycle: phase 0 is midnight, 0.5 noon.
	var dawn := G.time_def("dawn", 0.25)
	var dusk := G.time_def("dusk", 0.75)
	var dark := Color(0.34, 0.42, 0.70)
	var day := Color(1, 1, 1)
	var keys := [[0.0, dark], [dawn - 0.045, dark], [dawn, Color(0.96, 0.74, 0.62)], [dawn + 0.06, day],
			[dusk - 0.06, day], [dusk, Color(1.0, 0.68, 0.50)], [dusk + 0.055, dark], [1.0, dark]]
	for i in range(1, keys.size()):
		if phase <= keys[i][0]:
			var span: float = keys[i][0] - keys[i - 1][0]
			var t: float = 0.0 if span <= 0.0 else (phase - float(keys[i - 1][0])) / span
			return (keys[i - 1][1] as Color).lerp(keys[i][1], t)
	return dark


func _process(delta: float) -> void:
	if camera == null or not G.has_view():
		return
	var cycle := G.time_def("cycle_hours", 25920)
	var phase := fmod(fmod(G.clock(), cycle) / cycle + G.time_def("start", 0.27), 1.0)
	var sky := _sky_colour(phase)
	_daylight.color = sky
	night = clampf((1.0 - sky.g) / 0.58, 0.0, 1.0)
	_fire.darkness = night
	var season := _season_now()
	if not (season[0] as Color).is_equal_approx(_leaf) or absf(season[1] - _snow) > 0.004:
		_leaf = season[0]
		_snow = season[1]
		_material.set_shader_parameter("leaf_tint", Vector3(_leaf.r, _leaf.g, _leaf.b))
		_material.set_shader_parameter("snow", _snow)
		var tint := _leaf.lerp(Color(0.92, 0.95, 1.0), _snow * 0.35)
		for node in _leafy:
			node.modulate = tint
	_spread_people()
	_move_camera(delta)


func _spread_people() -> void:
	## People standing on the same tile stand in a little ring, not on top of each other.
	var by_tile := {}
	for name in people:
		var p: Person = people[name]
		if p.moving:
			p.spread = Vector2.ZERO
			continue
		by_tile.get_or_add(Vector2i(p.tile_pos.round()), []).append(name)
	for tile in by_tile:
		var names: Array = by_tile[tile]
		if names.size() == 1:
			people[names[0]].spread = Vector2.ZERO
			continue
		names.sort()
		for i in range(names.size()):
			var a := TAU * i / names.size() + 0.6
			var r := 9.0 + 2.5 * names.size()
			people[names[i]].spread = Vector2(cos(a) * r, sin(a) * r * 0.6)


# --------------------------------------------------------------------------- #
# The camera
# --------------------------------------------------------------------------- #
func min_zoom() -> float:
	var screen := get_viewport_rect().size
	return maxf(screen.x / (width * Art.TILE), screen.y / (height * Art.TILE))


func centre_on(world_point: Vector2) -> void:
	camera.position = world_point - view_shift / camera.zoom.x
	_clamp_camera()


func go_home() -> void:
	following = ""
	centre_on(tile_centre(spots["fire"]))


func find_person(pname: String, follow: bool = true) -> bool:
	if not people.has(pname):
		return false
	following = pname if follow else ""
	centre_on(people[pname].position + Vector2(0, -20))
	return true


func zoom_by(factor: float, anchor_screen = null) -> void:
	target_zoom = clampf(target_zoom * factor, min_zoom(), MAX_ZOOM)
	_zoom_anchored = anchor_screen != null
	if _zoom_anchored:
		_zoom_anchor_screen = anchor_screen
		_zoom_anchor_world = screen_to_world(anchor_screen)


func pan(screen_pixels: Vector2) -> void:
	following = ""
	_zoom_anchored = false
	camera.position += screen_pixels / camera.zoom.x
	_clamp_camera()


func screen_to_world(screen_point: Vector2) -> Vector2:
	return camera.position + (screen_point - get_viewport_rect().size * 0.5) / camera.zoom.x


func world_to_screen(world_point: Vector2) -> Vector2:
	return (world_point - camera.position) * camera.zoom.x + get_viewport_rect().size * 0.5


func visible_world_rect() -> Rect2:
	var half := get_viewport_rect().size * 0.5 / camera.zoom.x
	return Rect2(camera.position - half, half * 2.0)


func _clamp_camera() -> void:
	var half := get_viewport_rect().size * 0.5 / camera.zoom.x
	var size := Vector2(width, height) * Art.TILE
	camera.position.x = clampf(camera.position.x, minf(half.x, size.x * 0.5), maxf(size.x - half.x, size.x * 0.5))
	camera.position.y = clampf(camera.position.y, minf(half.y, size.y * 0.5), maxf(size.y - half.y, size.y * 0.5))


func _move_camera(delta: float) -> void:
	target_zoom = clampf(target_zoom, min_zoom(), MAX_ZOOM)
	if absf(camera.zoom.x - target_zoom) > 0.0005:
		var z := lerpf(camera.zoom.x, target_zoom, clampf(delta * 12.0, 0.0, 1.0))
		if absf(z - target_zoom) < 0.002:
			z = target_zoom
		camera.zoom = Vector2(z, z)
		if _zoom_anchored:
			camera.position = _zoom_anchor_world - (_zoom_anchor_screen - get_viewport_rect().size * 0.5) / z
	if keys_enabled:
		var push := Vector2.ZERO
		if Input.is_key_pressed(KEY_LEFT):
			push.x -= 1.0
		if Input.is_key_pressed(KEY_RIGHT):
			push.x += 1.0
		if Input.is_key_pressed(KEY_UP):
			push.y -= 1.0
		if Input.is_key_pressed(KEY_DOWN):
			push.y += 1.0
		if push != Vector2.ZERO:
			pan(push * delta * (1800.0 if Input.is_key_pressed(KEY_SHIFT) else 700.0))
	if following != "" and people.has(following):
		var want: Vector2 = people[following].position + Vector2(0, -20) - view_shift / camera.zoom.x
		camera.position = camera.position.lerp(want, clampf(delta * 6.0, 0.0, 1.0))
	_clamp_camera()


func _unhandled_input(event: InputEvent) -> void:
	if camera == null:
		return
	if event is InputEventMouseButton:
		if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(1.15, event.position)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.0 / 1.15, event.position)
		elif event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			if event.pressed:
				_dragging = true
				_dragged = false
				_drag_from = event.position
				_drag_cam = camera.position
			elif _dragging:
				_dragging = false
				if not _dragged and event.button_index == MOUSE_BUTTON_LEFT:
					_click(screen_to_world(event.position))
	elif event is InputEventMouseMotion and _dragging:
		if event.position.distance_to(_drag_from) > 5.0:
			_dragged = true
		if _dragged:
			following = ""
			_zoom_anchored = false
			camera.position = _drag_cam - (event.position - _drag_from) / camera.zoom.x
			_clamp_camera()


# --------------------------------------------------------------------------- #
# Asking what is somewhere
# --------------------------------------------------------------------------- #
func person_at(world_point: Vector2) -> String:
	var best := ""
	var best_y := -1e9
	for name in people:
		var p: Person = people[name]
		if p.contains_point(world_point) and p.position.y > best_y:
			best = name
			best_y = p.position.y
	return best


func people_on(tile: Vector2i) -> Array:
	var out: Array = []
	for name in people:
		if Vector2i(people[name].tile_pos.round()) == tile:
			out.append(name)
	return out


func describe(tile: Vector2i) -> String:
	var here: Array = []
	for name in spots:
		if spots[name] != tile:
			continue
		match name:
			"fire":
				here.append("The fire of the %s%s" % [G.term("home"), "" if _fire.burning else " (it has gone out)"])
			"store":
				here.append("The %s" % G.term("store_name"))
			"workshop":
				here.append("The workshop: where things are made")
			"council":
				here.append("The council ground")
			_:
				here.append(str(name).capitalize())
	for s in sites():
		if int(s["x"]) == tile.x and int(s["y"]) == tile.y:
			here.append("%s The %s %s found (about %s trips' worth left)" % [s["icon"], s["short"], s["by"], G.num(s["loads"])])
	var names := people_on(tile)
	if names.size() > 0:
		here.append(", ".join(PackedStringArray(names)) + (" is here" if names.size() == 1 else " are here"))
	var text := "(%d, %d) " % [tile.x, tile.y]
	for h in here:
		text += h + ". "
	var t: Dictionary = terrain_defs.get(kind_at(tile.x, tile.y), {})
	if t.is_empty():
		return text + "The edge of the world."
	return text + "%s: %s (%s)" % [t.get("name", ""), t.get("description", ""),
			"can be built on" if t.get("buildable", false) else "can't be built on"]


func _click(world_point: Vector2) -> void:
	var who := person_at(world_point)
	if who != "":
		person_picked.emit(who)
		return
	var tile := Vector2i((world_point / Art.TILE).floor())
	if tile.x >= 0 and tile.y >= 0 and tile.x < width and tile.y < height:
		tile_picked.emit(describe(tile))


func minimap_image() -> Image:
	var img := Image.create(width, height, false, Image.FORMAT_RGB8)
	for y in range(height):
		for x in range(width):
			var c: Color = Art.MINIMAP.get(_kinds[y * width + x], Color(0.3, 0.5, 0.3))
			var shade := 0.93 + 0.07 * Art.hash2(x, y, 9)
			img.set_pixel(x, y, Color(c.r * shade, c.g * shade, c.b * shade))
	return img

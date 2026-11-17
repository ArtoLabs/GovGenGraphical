class_name Art
extends RefCounted
## Where every picture in the world comes from. To swap in better art later, change the paths and
## rectangles here: nothing else in the client knows which sheet a tree or a tent is on.

const TILE := 32                       # a map tile in world pixels (LPC tiles are 32 px)

const TERRAIN_SHEET := "res://assets/terrain/lpc_terrain.png"
const TREES_SHEET := "res://assets/trees/trees.png"
const PROPS_SHEET := "res://assets/props/roguelike.png"   # Kenney: 16 px tiles, 1 px apart
const CHAR_DIR := "res://assets/char/"

# The order of the ground textures in the array the ground shader reads; four variants of each,
# as (column, row) of 32 px tiles on the LPC terrain sheet: the plain tile first.
const GROUND := [
	[Vector2i(28, 3), Vector2i(27, 5), Vector2i(28, 5), Vector2i(29, 5)],    # 0 water
	[Vector2i(1, 9), Vector2i(0, 11), Vector2i(1, 11), Vector2i(2, 11)],     # 1 grass
	[Vector2i(3, 11), Vector2i(4, 11), Vector2i(5, 11), Vector2i(1, 9)],     # 2 meadow (flowers)
	[Vector2i(7, 9), Vector2i(6, 11), Vector2i(7, 11), Vector2i(8, 11)],     # 3 dark grass
	[Vector2i(19, 9), Vector2i(18, 11), Vector2i(19, 11), Vector2i(20, 11)], # 4 sand
	[Vector2i(1, 3), Vector2i(1, 5), Vector2i(2, 5), Vector2i(1, 3)],        # 5 dirt
	[Vector2i(13, 3), Vector2i(13, 5), Vector2i(14, 5), Vector2i(13, 3)],    # 6 rock
	[Vector2i(19, 15), Vector2i(18, 17), Vector2i(19, 17), Vector2i(20, 17)],# 7 snow
]

# The number the ground shader knows each kind of terrain by (data/rules/map.json 'terrain' keys).
const TERRAIN_ID := {"deep_water": 0, "water": 1, "river": 2, "sand": 3, "plains": 4, "marsh": 5,
		"forest": 6, "deep_forest": 7, "hills": 8, "mountains": 9, "peaks": 10}
const UNKNOWN_TERRAIN := 4

# Colours for the small map (one pixel per tile).
const MINIMAP := {"deep_water": Color("1b3f73"), "water": Color("2f6fb0"), "river": Color("4d9be0"),
		"sand": Color("d9c58a"), "plains": Color("5c9a45"), "marsh": Color("4d7a5e"),
		"forest": Color("2f7a35"), "deep_forest": Color("1c5427"), "hills": Color("a08e58"),
		"mountains": Color("8a8580"), "peaks": Color("eef2f6")}

# Trees and bushes (ansimuz), on TREES_SHEET.
const TREE_A := Rect2(0, 7, 113, 113)
const TREE_B := Rect2(120, 7, 102, 130)
const FERN := Rect2(224, 6, 30, 39)
const CONE_BUSH := Rect2(261, 1, 25, 30)
const FLOWER_BUSH := Rect2(227, 55, 21, 19)
const FLOWER := Rect2(255, 50, 15, 13)
const SPROUT := Rect2(228, 88, 19, 18)
const BUSH := Rect2(240, 116, 32, 37)

# Rocks, reeds and lilies, on TERRAIN_SHEET.
const BOULDERS_BROWN := [Rect2(770, 625, 61, 43), Rect2(834, 628, 58, 41), Rect2(898, 622, 29, 44)]
const BOULDERS_DARK := [Rect2(770, 689, 61, 43), Rect2(834, 692, 58, 41), Rect2(898, 686, 29, 44)]
const ROCKS_MEDIUM_BROWN := [Rect2(962, 451, 28, 27), Rect2(960, 576, 32, 32)]
const ROCKS_MEDIUM_DARK := [Rect2(960, 548, 31, 22), Rect2(994, 547, 28, 27), Rect2(992, 612, 31, 22)]
const ROCK_WHITE := Rect2(932, 451, 20, 25)
const ROCKS_SMALL := [Rect2(971, 491, 18, 15), Rect2(933, 528, 15, 11), Rect2(1003, 587, 18, 15), Rect2(933, 624, 15, 11)]
const STANDING_STONE := Rect2(995, 643, 24, 59)
const REEDS := [Rect2(0, 736, 32, 64), Rect2(32, 736, 32, 64), Rect2(64, 736, 32, 64), Rect2(96, 736, 32, 64)]
const LILIES := [Rect2(224, 545, 31, 31), Rect2(256, 544, 32, 24), Rect2(288, 544, 32, 30), Rect2(321, 544, 31, 24), Rect2(354, 548, 30, 28)]
const GARDEN_PLOT := Rect2(96, 640, 96, 96)

# Kenney props, as (column, row, tiles wide, tiles high) on PROPS_SHEET.
const K_FIRE_OUT := [13, 8, 1, 1]
const K_FIRE := [[14, 8, 1, 1], [15, 8, 1, 1]]
const K_CRATES := [[47, 17, 1, 1], [48, 17, 1, 1], [49, 17, 1, 1]]
const K_SACK := [41, 10, 1, 1]
const K_CHEST := [13, 7, 1, 1]
const K_LOGS := [53, 22, 1, 1]
const K_STUMP := [53, 19, 1, 1]
const K_STUMP_AXE := [53, 21, 1, 1]
const K_BERRY_BUSH := [24, 9, 1, 1]
const K_FRUIT_BUSH := [23, 9, 1, 1]
const K_DEAD_TREE := [27, 10, 1, 2]
const K_HERB := [25, 11, 1, 1]
const K_ROCKS_GREY := [55, 21, 1, 1]
const K_ROCKS_WATER := [55, 24, 1, 1]
const K_SKULL := [49, 9, 1, 1]
const K_MUSHROOM := [48, 7, 1, 1]

# The look of a found place, by its kind (the age's work.json 'site_kinds'); anything else gets a flag.
const SITE_PROPS := {"plants": "berry", "wood": "deadwood", "stone": "stone", "game": "tracks",
		"fish": "pool", "herbs": "herb", "garden": "garden"}

# Character sheets: frames across, rows (up, left, down, right), the name of the body file.
const ANIMS := {
	"walkcycle": {"frames": 9, "rows": 4, "body": "BODY_male"},
	"slash": {"frames": 6, "rows": 4, "body": "BODY_human"},
	"thrust": {"frames": 8, "rows": 4, "body": "BODY_animation"},
	"bow": {"frames": 13, "rows": 4, "body": "BODY_animation"},
	"spellcast": {"frames": 7, "rows": 4, "body": "BODY_male"},
	"hurt": {"frames": 6, "rows": 1, "body": "BODY_male"},
}
const FRAME := 64
# Layers of a figure, drawn in this order (bottom first).
const LAYER_ORDER := ["BEHIND", "BODY", "FEET", "LEGS", "TORSO", "BELT", "HEAD", "HANDS", "WEAPON"]

const SKIN_TONES := [Color(1.0, 0.95, 0.9), Color(0.96, 0.84, 0.72), Color(0.86, 0.70, 0.56), Color(0.72, 0.55, 0.42),
		Color(0.58, 0.42, 0.32), Color(0.46, 0.33, 0.25)]
const HAIR_TONES := [Color(1.0, 0.95, 0.75), Color(0.75, 0.52, 0.30), Color(0.48, 0.32, 0.20), Color(0.28, 0.20, 0.15),
		Color(0.16, 0.13, 0.12), Color(0.85, 0.42, 0.22)]
const CLOTH_TONES := [Color(0.80, 0.68, 0.50), Color(0.66, 0.50, 0.34), Color(0.74, 0.58, 0.36), Color(0.58, 0.44, 0.30),
		Color(0.70, 0.62, 0.52), Color(0.62, 0.52, 0.36), Color(0.76, 0.52, 0.36), Color(0.56, 0.56, 0.42)]

static var _cache: Dictionary = {}


static func tex(path: String) -> Texture2D:
	if not _cache.has(path):
		_cache[path] = load(path) if ResourceLoader.exists(path) else null
	return _cache[path]


static func terrain() -> Texture2D:
	return tex(TERRAIN_SHEET)


static func trees() -> Texture2D:
	return tex(TREES_SHEET)


static func props() -> Texture2D:
	return tex(PROPS_SHEET)


static func char_sheet(anim: String, layer_file: String) -> Texture2D:
	return tex(CHAR_DIR + anim + "/" + layer_file + ".png")


static func draw_k(canvas: CanvasItem, k: Array, at: Vector2, px: float = 2.0, modulate: Color = Color.WHITE,
		flip: bool = false, outline: bool = true) -> void:
	## Draw a Kenney prop with its bottom-centre at `at`, each art pixel `px` world pixels big, with a dark
	## edge so it stands out from the ground. Props more than one tile big are drawn tile by tile, since
	## the sheet has a gap between tiles.
	var sheet := props()
	if sheet == null:
		return
	var w := int(k[2])
	var h := int(k[3])
	var size := 16.0 * px
	var origin := at - Vector2(w * size * 0.5, h * size)
	var passes: Array = [[Vector2.ZERO, modulate]]
	if outline:
		var edge := Color(0.13, 0.09, 0.06, modulate.a)
		passes = [[Vector2(-1.5, 0), edge], [Vector2(1.5, 0), edge], [Vector2(0, -1.5), edge], [Vector2(0, 1.5), edge],
				[Vector2.ZERO, modulate]]
	for one in passes:
		for ty in range(h):
			for tx in range(w):
				var src := Rect2((int(k[0]) + tx) * 17, (int(k[1]) + ty) * 17, 16, 16)
				var col := (w - 1 - tx) if flip else tx
				var dst := Rect2(origin + one[0] + Vector2(col * size, ty * size), Vector2(size, size))
				if flip:
					dst.size.x = -size
					dst.position.x += size
				canvas.draw_texture_rect_region(sheet, dst, src, one[1])


static func draw_piece(canvas: CanvasItem, sheet: Texture2D, src: Rect2, at: Vector2, scale: float = 1.0,
		modulate: Color = Color.WHITE, flip: bool = false) -> void:
	## Draw a region of a sheet with its bottom-centre at `at`.
	if sheet == null:
		return
	var size := src.size * scale
	var dst := Rect2(at - Vector2(size.x * 0.5, size.y), size)
	if flip:
		dst.position.x += size.x
		dst.size.x = -size.x
	canvas.draw_texture_rect_region(sheet, dst, src, modulate)


static func ground_array() -> Texture2DArray:
	## The ground textures as one array texture (with mipmaps, for when the map is zoomed far out).
	var sheet := terrain()
	var out := Texture2DArray.new()
	if sheet == null:
		return out
	var whole := sheet.get_image()
	if whole.is_compressed():
		whole.decompress()
	whole.convert(Image.FORMAT_RGBA8)
	var images: Array[Image] = []
	for kind in GROUND:
		for cell in kind:
			var img := whole.get_region(Rect2i(cell.x * TILE, cell.y * TILE, TILE, TILE))
			img.generate_mipmaps()
			images.append(img)
	out.create_from_images(images)
	return out


static func hash2(x: int, y: int, salt: int = 0) -> float:
	## A number from 0 to 1 that is always the same for the same tile: decoration never jumps about.
	var n := (x * 374761393 + y * 668265263 + salt * 2147483647) & 0x7fffffff
	n = (n ^ (n >> 13)) * 1274126177 & 0x7fffffff
	n = n ^ (n >> 16)
	return float(n % 100003) / 100003.0

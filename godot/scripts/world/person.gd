class_name Person
extends Node2D
## One member of the tribe on the map: a figure built from layered sprite sheets (body, clothes, hair)
## that walks along the path the game gave it and plays a fitting animation for what it is doing.
## Where it stands at any moment follows from the game's plan (`legs`), exactly as world/map.py
## position_at() works it out, so nothing here decides anything.

const FEET := Vector2(-32, -60)      # where the 64 px frame sits so that the feet are on the node
const WALK_FPS := 10.0
const WORK_FPS := 8.0

var pname := ""
var info: Dictionary = {}            # this person in view.map.people: pos, legs, bed, you, child
var data: Dictionary = {}            # this person in view.players
var tile_pos := Vector2.ZERO         # where they are, in tiles (fractions while walking)
var moving := false
var dead := false
var is_you := false
var bubble := ""                     # an icon for what they are doing, drawn over their head
var anim := ""
var facing := 2                      # 0 up, 1 left, 2 down, 3 right
var _outfit: Array = []              # [slot, file, colour]
var _outfit_key := ""
var _sprites: Dictionary = {}        # slot+file -> Sprite2D
var _weapon := ""
var _time := 0.0
var _seed := 0
var _jitter := Vector2.ZERO
var _lying := false
var _work_anim := "slash"
var spread := Vector2.ZERO           # set by the world when several people stand on one tile


func setup(person_name: String) -> void:
	pname = person_name
	_seed = absi(hash(person_name))
	_jitter = Vector2((_seed % 13) - 6, ((_seed / 13) % 9) - 4)
	_time = (_seed % 100) / 50.0


func refresh(map_person: Dictionary, player: Dictionary) -> void:
	info = map_person
	data = player
	is_you = bool(info.get("you", false))
	var life: Dictionary = data.get("life") if data.get("life") is Dictionary else {}
	var age := float(data.get("age", 25))
	scale = Vector2.ONE * (clampf(0.52 + age * 0.035, 0.52, 0.86) if life.get("child", false) else 1.0)
	_dress(life, age)
	_read_doing(life)
	queue_redraw()


func lie_dead(person_name: String, at_tile: Vector2) -> void:
	## The dead lie where they slept until someone lays them to rest.
	setup(person_name)
	dead = true
	tile_pos = at_tile
	position = (at_tile + Vector2(0.5, 0.5)) * Art.TILE + _jitter
	_outfit = [["BODY", "BODY", Color(0.62, 0.62, 0.66)], ["LEGS", "LEGS_pants_greenish", Color(0.5, 0.5, 0.52)],
			["TORSO", "TORSO_robe_shirt_brown", Color(0.55, 0.55, 0.58)], ["HEAD", "HEAD_hair_blonde", Color(0.5, 0.5, 0.5)]]
	_outfit_key = "dead"
	_lying = true
	_show("hurt", 5, 0)


# --------------------------------------------------------------------------- #
# Clothes
# --------------------------------------------------------------------------- #
func _dress(life: Dictionary, age: float) -> void:
	var female := str(life.get("gender_name", "")) == "Female"
	var child := bool(life.get("child", false))
	var offices: Array = data.get("offices", [])
	var top_rank := 0.0
	var mine := 0.0
	var religious := false
	for name in G.view.get("offices", {}):
		var o: Dictionary = G.view["offices"][name]
		top_rank = maxf(top_rank, float(o.get("rank", 0)))
		if name in offices:
			mine = maxf(mine, float(o.get("rank", 0)))
			religious = religious or ("religious" in o.get("interfaces", []))
	var leader := not offices.is_empty() and mine >= top_rank and top_rank > 0.0
	var key := "%s|%s|%s|%s|%s|%s" % [female, child, offices, religious, leader, int(age) / 5]
	if key == _outfit_key:
		return
	_outfit_key = key
	var s := _seed
	var skin: Color = Art.SKIN_TONES[s % Art.SKIN_TONES.size()]
	var hair: Color = Art.HAIR_TONES[(s / 7) % Art.HAIR_TONES.size()]
	if age >= 38.0:
		hair = hair.lerp(Color(0.86, 0.86, 0.88), clampf((age - 34.0) / 12.0, 0.3, 0.9))
	var cloth: Color = Art.CLOTH_TONES[(s / 13) % Art.CLOTH_TONES.size()]
	var cloth2: Color = Art.CLOTH_TONES[(s / 29) % Art.CLOTH_TONES.size()]
	var out: Array = [["BODY", "BODY", skin]]
	if religious:
		out.append(["LEGS", "LEGS_robe_skirt", Color(0.86, 0.80, 0.70)])
		out.append(["TORSO", "TORSO_robe_shirt_brown", Color(1, 1, 1)])
		out.append(["BELT", "BELT_rope", Color.WHITE])
		out.append(["HEAD", "HEAD_robe_hood", Color.WHITE])
	else:
		if female:
			out.append(["LEGS", "LEGS_robe_skirt", cloth2])
		else:
			out.append(["LEGS", "LEGS_pants_greenish", cloth2.lerp(Color(0.75, 0.62, 0.45), 0.5)])
		match (s / 3) % 3:
			0:
				out.append(["TORSO", "TORSO_leather_armor_shirt_white", cloth])
			1:
				out.append(["TORSO", "TORSO_robe_shirt_brown", cloth.lerp(Color.WHITE, 0.5)])
			_:
				out.append(["TORSO", "TORSO_leather_armor_shirt_white", cloth2])
				if not child:
					out.append(["TORSO", "TORSO_leather_armor_torso", Color.WHITE])
		out.append(["BELT", "BELT_rope" if (s / 5) % 2 == 0 else "BELT_leather", Color.WHITE])
		if not child and (s / 11) % 2 == 0:
			out.append(["FEET", "FEET_shoes_brown", Color.WHITE])
		out.append(["HEAD", "HEAD_hair_blonde", hair])
		if not offices.is_empty():
			out.append(["TORSO", "TORSO_leather_armor_shoulders", Color.WHITE])
		if leader:
			out.append(["HEAD", "HEAD_leather_armor_hat", Color(1.0, 0.92, 0.72)])
	_outfit = out
	anim = ""  # the sprites are built again with the new clothes


func _read_doing(life: Dictionary) -> void:
	var doing := str(data.get("doing", "")) if data.get("doing") != null else ""
	var d := doing.to_lower()
	_lying = d.begins_with("sleeping")
	_weapon = ""
	bubble = ""
	_work_anim = ""
	if life.get("illness") != null:
		bubble = str(life["illness"].get("icon", "🤒"))
	if d == "":
		return
	if _lying:
		bubble = "💤"
	elif d.begins_with("eating"):
		bubble = "🍖"
	elif d.begins_with("drinking"):
		bubble = "💧"
	elif d.begins_with("warming"):
		bubble = "🔥"
	elif d.begins_with("resting") or d.begins_with("recovering"):
		pass
	else:
		_work_anim = "slash"
		for word in ["hunt", "patrol", "fish", "guard", "spear"]:
			if d.contains(word):
				_work_anim = "thrust"
				_weapon = "WEAPON_spear"
		for word in ["ritual", "council", "story", "tale", "heal", "tend", "duties", "stud", "persuad", "campaign",
				"oration", "rally", "speak", "vot", "nominat", "appoint", "dismiss", "research", "order", "reform"]:
			if d.contains(word):
				_work_anim = "spellcast"
				_weapon = ""
		if d.contains("fight"):
			_work_anim = "slash"
			_weapon = "WEAPON_dagger"
		if bubble == "":
			bubble = G.occupation_icons(data)
			if d.contains("persuad") or d.contains("campaign") or d.contains("oration") or d.contains("rally"):
				bubble = "📢"
			elif d.contains("fight") or d.contains("challeng"):
				bubble = "⚔"


# --------------------------------------------------------------------------- #
# Moving and animating
# --------------------------------------------------------------------------- #
static func position_at(pos, legs, clock: float) -> Vector2:
	## world/map.py position_at(): where someone is at `clock` on the way along their legs.
	for leg in legs:
		var path: Array = leg["path"]
		if clock < float(leg["t0"]):
			return Vector2(path[0][0], path[0][1])
		if clock < float(leg["t1"]):
			var share := (clock - float(leg["t0"])) / maxf(1e-9, float(leg["t1"]) - float(leg["t0"]))
			var at: Array = leg["at"]
			for i in range(1, path.size()):
				if share <= float(at[i]):
					var part := (share - float(at[i - 1])) / maxf(1e-9, float(at[i]) - float(at[i - 1]))
					var a := Vector2(path[i - 1][0], path[i - 1][1])
					var b := Vector2(path[i][0], path[i][1])
					return a.lerp(b, part)
			return Vector2(path[-1][0], path[-1][1])
	if legs.size() > 0:
		var last: Array = legs[-1]["path"]
		return Vector2(last[-1][0], last[-1][1])
	return Vector2(pos[0], pos[1])


func _process(delta: float) -> void:
	if dead or info.is_empty():
		return
	_time += delta
	var clock := G.clock()
	var legs: Array = info.get("legs", [])
	var now := position_at(info.get("pos", [0, 0]), legs, clock)
	var step := now - tile_pos
	moving = false
	for leg in legs:
		if float(leg["t0"]) <= clock and clock < float(leg["t1"]):
			moving = true
			break
	if moving and step.length() > 0.0005:
		if absf(step.x) > absf(step.y):
			facing = 3 if step.x > 0 else 1
		else:
			facing = 2 if step.y > 0 else 0
	tile_pos = now
	var target := (now + Vector2(0.5, 0.5)) * Art.TILE + (Vector2.ZERO if moving else _jitter * 0.4 + spread)
	position = target if position.distance_to(target) > 80.0 else position.lerp(target, clampf(delta * 14.0, 0.0, 1.0))
	if moving:
		_show("walkcycle", 1 + int(_time * WALK_FPS) % 8, facing)
	elif _lying:
		_show("hurt", 5, 0)
	elif _work_anim != "":
		var frames: int = Art.ANIMS[_work_anim]["frames"]
		_show(_work_anim, int(_time * WORK_FPS) % frames, facing if facing != 0 else 2)
	else:
		_show("walkcycle", 0, 2 if not moving and facing == 0 else facing)


func _show(animation: String, frame: int, row: int) -> void:
	if animation != anim:
		anim = animation
		_build_sprites()
	var spec: Dictionary = Art.ANIMS[anim]
	var rect := Rect2(frame * Art.FRAME, (row if int(spec["rows"]) > 1 else 0) * Art.FRAME, Art.FRAME, Art.FRAME)
	for s in _sprites.values():
		s.region_rect = rect


func _build_sprites() -> void:
	for s in _sprites.values():
		s.queue_free()
	_sprites = {}
	var spec: Dictionary = Art.ANIMS[anim]
	var wear: Array = _outfit.duplicate()
	if _weapon != "" and not _lying:
		wear.append(["WEAPON", _weapon, Color.WHITE])
	for slot in Art.LAYER_ORDER:
		for piece in wear:
			if piece[0] != slot:
				continue
			var file: String = str(spec["body"]) if piece[1] == "BODY" else str(piece[1])
			var sheet := Art.char_sheet(anim, file)
			if sheet == null:
				continue
			var sprite := Sprite2D.new()
			sprite.texture = sheet
			sprite.centered = false
			sprite.region_enabled = true
			sprite.region_rect = Rect2(0, 0, Art.FRAME, Art.FRAME)
			sprite.modulate = piece[2]
			sprite.position = FEET + (Vector2(0, 14) if _lying else Vector2.ZERO)
			add_child(sprite)
			_sprites[slot + file + str(_sprites.size())] = sprite


func _draw() -> void:
	if dead:
		return
	# A soft shadow, and a ring under the one you play.
	draw_set_transform(Vector2(0, -1), 0.0, Vector2(1.0, 0.42))
	draw_circle(Vector2.ZERO, 12.0, Color(0, 0, 0, 0.28))
	if is_you:
		draw_arc(Vector2.ZERO, 16.0, 0.0, TAU, 28, Color(0.45, 1.0, 0.45, 0.95), 2.5, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func outfit() -> Array:
	return _outfit


static func draw_bust(canvas: CanvasItem, wear: Array, rect: Rect2) -> void:
	## A portrait: the head and shoulders of a figure dressed in `wear`, facing us.
	var src := Rect2(14, 2 * Art.FRAME + 8, 36, 40)
	for slot in Art.LAYER_ORDER:
		for piece in wear:
			if piece[0] != slot or slot == "WEAPON":
				continue
			var file: String = str(Art.ANIMS["walkcycle"]["body"]) if piece[1] == "BODY" else str(piece[1])
			var sheet := Art.char_sheet("walkcycle", file)
			if sheet != null:
				canvas.draw_texture_rect_region(sheet, rect, src, piece[2])


func head_position() -> Vector2:
	## Just above the head, in world pixels: where a name or an icon goes.
	return position + Vector2(0, (-22.0 if _lying or dead else -54.0) * scale.y)


func contains_point(world_point: Vector2) -> bool:
	var local := (world_point - position) / scale
	if _lying or dead:
		return Rect2(-22, -14, 44, 26).has_point(local)
	return Rect2(-13, -52, 26, 56).has_point(local)

class_name TribePanel
extends TitledPanel
## Top right: everyone on one line each (mood, name, work, office, what they are doing), the dead not
## yet laid to rest, and under them the places Scouts have found. Click someone to go to them.

signal person_clicked(pname: String, twice: bool)
signal place_clicked(tile: Vector2)

var _scroll: ScrollContainer
var _list: TribeList
var _places_title: Label
var _places: RichTextLabel


class TribeList extends Control:
	signal picked(pname: String, twice: bool)
	const ROW := 22
	const SIZE := 13
	var rows: Array = []      # players, then bodies
	var hover := -1
	var selected := ""

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_rows(r: Array) -> void:
		rows = r
		update_minimum_size()
		queue_redraw()

	func _get_minimum_size() -> Vector2:
		return Vector2(300, rows.size() * ROW)

	func _notification(what: int) -> void:
		if what == NOTIFICATION_MOUSE_EXIT:
			hover = -1
			queue_redraw()

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventMouseMotion:
			var i := int(event.position.y / ROW)
			if i != hover:
				hover = i
				queue_redraw()
		elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var i := int(event.position.y / ROW)
			if i >= 0 and i < rows.size() and not rows[i].has("body"):
				accept_event()
				picked.emit(str(rows[i]["name"]), event.double_click)

	func _draw() -> void:
		var f := UI.font
		var fb := UI.bold
		var you := G.you()
		var needs := G.needs()
		var office_w := 0.0
		for p in rows:
			if not p.has("body"):
				var held := G.positions_of(p)
				if held != "":
					office_w = maxf(office_w, f.get_string_size(held, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 8.0)
		office_w = minf(office_w, 96.0)
		for i in range(rows.size()):
			var p: Dictionary = rows[i]
			var y := i * ROW
			var base := y + (ROW - f.get_height(SIZE)) * 0.5 + f.get_ascent(SIZE)
			if i == hover or str(p.get("name", "")) == selected:
				draw_style_box(UI.box(Color(1, 1, 1, 0.07 if i == hover else 0.04), Color.TRANSPARENT, 4, 0, 0), Rect2(-4, y, size.x + 8, ROW))
			if p.has("body"):
				var b: Dictionary = p["body"]
				draw_string(f, Vector2(0, base), str(b.get("icon", "💀")), HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE, UI.TEXT)
				draw_string(fb, Vector2(22, base), str(b["name"]), HORIZONTAL_ALIGNMENT_LEFT, 66, SIZE, UI.RED)
				var how := ("%s sees to it" % b["handler"]) if b.get("handler") != null and str(b.get("handler")) != "" else ("unburied %dd (W)" % int(b.get("days", 0)))
				draw_string(f, Vector2(92, base), "died at %d · %s" % [int(b.get("age", 0)), how], HORIZONTAL_ALIGNMENT_LEFT, size.x - 92, SIZE, UI.RED)
				continue
			draw_circle(Vector2(6, y + ROW * 0.5), 5.0, UI.level_color(float(p.get("mood", 50))))
			draw_string(fb, Vector2(18, base), str(p["name"]), HORIZONTAL_ALIGNMENT_LEFT, 62, SIZE, UI.GREEN if p["name"] == you else UI.TEXT)
			draw_string(f, Vector2(82, base), G.occupation_icons(p), HORIZONTAL_ALIGNMENT_LEFT, 26, SIZE, UI.TEXT)
			var pos := G.positions_of(p)
			if pos != "":
				draw_string(f, Vector2(110, base), pos, HORIZONTAL_ALIGNMENT_LEFT, office_w - 4.0, SIZE, UI.CYAN)
			var flags := ""
			for k in needs:
				if p.get("sheet", {}).get("needs", {}).get(k, {}).get("critical", false):
					flags += str(needs[k]["icon"])
			flags += Rows.life_icons(p)
			var life: Dictionary = p.get("life") if p.get("life") is Dictionary else {}
			var child: bool = bool(life.get("child", false)) or not bool(life.get("of_age", true))
			if not p.get("can_vote", true) and not child:
				flags += "✗"
			var x := 110.0 + office_w
			if flags != "":
				draw_string(f, Vector2(x, base), flags, HORIZONTAL_ALIGNMENT_LEFT, 60, SIZE, UI.RED)
				x += minf(60.0, f.get_string_size(flags, HORIZONTAL_ALIGNMENT_LEFT, -1, SIZE).x + 4.0)
			var doing = p.get("doing")
			var text := ""
			var colour := UI.DIM
			if doing != null and not str(doing).begins_with("resting"):
				text = str(doing)
				colour = UI.YELLOW
			elif doing == null and p.get("waiting_for") != null and str(p.get("waiting_for")) != "":
				text = "needs " + str(p["waiting_for"]).substr(2)
				colour = UI.YELLOW
			elif doing == null:
				text = "free"
				colour = UI.GREEN
			else:
				text = str(p.get("last_deed")) if p.get("last_deed") != null else "at home"
			draw_string(f, Vector2(x, base), text, HORIZONTAL_ALIGNMENT_LEFT, maxf(20.0, size.x - x), SIZE, colour)


func _init() -> void:
	super("Tribe", "F2 details")
	_list = TribeList.new()
	_list.picked.connect(func(n, twice): person_clicked.emit(n, twice))
	_scroll = UI.scroll(_list)
	_scroll.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	body.add_child(_scroll)
	_places_title = UI.label("Found places", 13, UI.GOLD, true)
	body.add_child(_places_title)
	_places = UI.rich(13)
	_places.meta_underlined = false
	_places.meta_clicked.connect(func(meta):
		var xy := str(meta).split(",")
		if xy.size() == 2:
			place_clicked.emit(Vector2(float(xy[0]), float(xy[1]))))
	body.add_child(_places)


func overhead() -> float:
	## How tall the panel is apart from the list of people (its title, the found places, its edges).
	return maxf(60.0, size.y - _scroll.size.y)


func set_selected(pname: String) -> void:
	_list.selected = pname
	_list.queue_redraw()


func refresh(max_height: float) -> void:
	set_title(G.term("members"))
	var rows: Array = G.players().duplicate()
	for b in G.view.get("life", {}).get("bodies", []):
		rows.append({"body": b})
	_list.set_rows(rows)
	_scroll.custom_minimum_size = Vector2(0, minf(rows.size() * TribeList.ROW, max_height))
	var camp: Dictionary = G.view.get("camp", {})
	var t := ""
	var where := {}
	for s in G.view.get("map", {}).get("sites", []):
		where["%s|%s" % [s["kind"], s["by"]]] = "%s,%s" % [s["x"], s["y"]]
	for x in camp.get("sites", []):
		var loads := float(x.get("loads", 0))
		var total := maxf(1.0, float(x.get("total", 1)))
		var line := "%s %s %s %s trips\n" % [x.get("icon", ""), UI.b(UI.esc(x.get("short", ""))),
				UI.c(UI.GREEN if loads > total / 3.0 else UI.YELLOW, UI.text_bar(loads, total, 6)), G.num(loads)]
		line += UI.dim("     found by %s · gone in %s" % [x.get("by", ""), G.fmt_life(float(x.get("hours_left", 0)) * G.time_def("hours_per_life_hour", 1080))])
		var key := "%s|%s" % [x.get("kind", ""), x.get("by", "")]
		t += ("[url=%s]%s[/url]\n" % [where[key], line]) if where.has(key) else line + "\n"
	for x in (camp.get("spent_sites", []) as Array).slice(0, 3):
		t += UI.dim("%s %s  %s (%s)" % [x.get("icon", ""), x.get("short", ""), x.get("how", ""), x.get("by", "")]) + "\n"
	if t == "":
		t = UI.dim("None yet: a Scout can look for berry grounds, game trails, deadwood… (W)")
	_places.text = t.strip_edges()

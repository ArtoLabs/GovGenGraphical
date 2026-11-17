class_name SocietyWindow
extends GameWindow
## F9: how well the society works (its qualities and who feeds them) and how everyone feels.

var _head: RichTextLabel
var _qualities: MeterList
var _tree: Tree
var _foot: RichTextLabel
var _columns := 0


func build() -> void:
	close_key = KEY_F9
	set_title("Society")
	set_hint("wheel or PgUp PgDn scroll · F9 or Esc closes · updates live")
	var inner := UI.vbox(10)
	var scroll := UI.scroll(inner)
	content.add_child(scroll)
	_head = UI.rich(15)
	inner.add_child(_head)
	_qualities = MeterList.new()
	_qualities.max_bar = 200.0
	_qualities.min_bar = 140.0
	inner.add_child(_qualities)
	var box := section(inner, "How content everyone is", "each meter moves toward what they experience, faster or slower by tools, choice of work, Warriors on patrol, rituals… (F8 shows what moves yours)")
	_tree = Tree.new()
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_search = false
	_tree.scroll_vertical_enabled = false
	_tree.focus_mode = Control.FOCUS_NONE
	box.add_child(_tree)
	_foot = UI.rich(13)
	inner.add_child(_foot)
	_foot.text = UI.dim("Ability is not contentment: it is how well someone does their best job or office right now (attributes and skill, " \
			+ "less when tired or unwell). It sets how much their work yields and how much it adds to the qualities above. It dips as " \
			+ "they tire and recovers with sleep; it grows as they practise.\n" \
			+ "Patience: unhappy people put up with it for a while before they act. While patience lasts (∙ to ◔) they only grumble; " \
			+ "once it runs out (●) they campaign, challenge, call for removal votes and change. It comes back once their Leaders " \
			+ "(and Society) contentment recovers.")


func _detail(q: Dictionary) -> String:
	var d: Dictionary = q.get("detail", {}) if q.get("detail") is Dictionary else {}
	var shock := (" · %s from a death, coming back" % G.num(round(float(d["shock"])))) if d.get("shock") != null and float(d.get("shock")) != 0.0 else ""
	if d.has("level"):
		return "+%s each time someone warms up at the fire%s%s" % [G.num(d.get("per_use", 0)),
				(", -%s a day-night otherwise" % G.num(d["fall_per_day"])) if d.get("fall_per_day") != null and float(d.get("fall_per_day")) != 0.0 else "; otherwise it stays the same", shock]
	if d.has("seats"):
		var seats: Array = []
		for s in d["seats"]:
			seats.append("%s: %s %d" % [s[0], s[1] if s[1] != null and str(s[1]) != "" else "vacant", int(round(float(s[2])))])
		return ", ".join(PackedStringArray(seats)) + shock
	var who: Array = []
	for w in d.get("workers", []):
		who.append("%s %d" % [w[1], int(round(float(w[2])))])
	var t := "work %s of %s needed · %s" % [G.num(d.get("supply", 0)), G.num(d.get("need", 0)), ", ".join(PackedStringArray(who)) if not who.is_empty() else "nobody"]
	if d.get("all_categories") is Array and not (d["all_categories"] as Array).is_empty():
		var have: Array = d.get("categories", [])
		t += " · kinds covered: %s (of %s)" % [", ".join(PackedStringArray(have)) if not have.is_empty() else "none", ", ".join(PackedStringArray(d["all_categories"]))]
	if d.get("on_hand") is Dictionary:
		t += " · on hand %s of %s points" % [G.num(d["on_hand"].get("have", 0)), G.num(d["on_hand"].get("want", 0))]
	if d.get("sick") is Dictionary and float(d["sick"].get("count", 0)) > 0:
		t += " · %d ill" % int(d["sick"]["count"])
	return t + shock


func refresh() -> void:
	var v := G.view
	var soc: Dictionary = v.get("society", {})
	var score := float(soc.get("score", 0))
	_head.text = UI.c(UI.CYAN, UI.b("Society ")) + UI.c(UI.level_color(score), UI.b("%d/100" % int(round(score)))) \
			+ UI.dim("   how well the %s works (the weighted average of the qualities below)" % G.term("society"))
	var rows: Array = []
	for q in soc.get("qualities", {}).values():
		var label := "%s %s" % [q.get("icon", ""), q.get("name", "")]
		if not q.get("active", false):
			rows.append({"text": "%s    not yet (needs an innovation)" % label, "color": UI.DIM})
			continue
		var val := float(q["value"])
		rows.append(MeterList.row(label, val, 100, UI.level_color(val), "%d   %s" % [int(round(val)), _detail(q)], UI.DIM, true))
	_qualities.set_rows(rows)

	var meters: Dictionary = v.get("satisfaction", {})
	var count := meters.size() + 4
	if count != _columns:
		_columns = count
		_tree.columns = count
		var titles: Array = [G.term("member")]
		for key in meters:
			titles.append(str(meters[key]["name"]))
		titles.append_array(["Mood", "Ability", "Patience"])
		for i in range(count):
			_tree.set_column_title(i, str(titles[i]))
			_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
			_tree.set_column_expand(i, true)
			_tree.set_column_custom_minimum_width(i, 150 if i == 0 else 90)
	_tree.clear()
	var root := _tree.create_item()
	for p in G.players():
		var it := _tree.create_item(root)
		it.set_text(0, str(p["name"]))
		it.set_custom_color(0, UI.GREEN if p["name"] == G.you() else UI.TEXT)
		var col := 1
		for key in meters:
			var val := float(p.get("satisfaction", {}).get(key, 50))
			it.set_text(col, "%d" % int(round(val)))
			it.set_custom_color(col, UI.level_color(val))
			col += 1
		var mood := float(p.get("mood", 50))
		it.set_text(col, "%d" % int(round(mood)))
		it.set_custom_color(col, UI.level_color(mood))
		var wq = p.get("work_quality")
		it.set_text(col + 1, "-" if wq == null else "%d" % int(round(float(wq))))
		it.set_custom_color(col + 1, UI.DIM if wq == null else UI.level_color(float(wq)))
		var cell := Rows.patience_cell(p.get("patience", {}))
		it.set_text(col + 2, str(cell[0]))
		it.set_custom_color(col + 2, cell[1])
	_tree.custom_minimum_size = Vector2(0, 40 + G.players().size() * 30)

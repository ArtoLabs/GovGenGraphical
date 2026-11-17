class_name YouPanel
extends TitledPanel
## Top left: who you are, your place in the tribe, what you are doing, your body's meters, and one bar
## each for ability, skills and mood. Everything it leaves out is on F8.

var hud
var _portrait: Portrait
var _id: RichTextLabel
var _state: RichTextLabel
var _stop: Button
var _meters: MeterList


func _init() -> void:
	super("You", "F8 more")
	var top := UI.hbox(10)
	body.add_child(top)
	_portrait = Portrait.new(62)
	_portrait.frame_colour = UI.GREEN
	top.add_child(_portrait)
	_id = UI.rich(14)
	top.add_child(_id)
	var row := UI.hbox(8)
	body.add_child(row)
	_state = UI.rich(14)
	row.add_child(_state)
	_stop = UI.button("X stop", "X: wake up, or stop what you are doing", 13)
	_stop.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_stop.pressed.connect(func(): G.ask_menu("stop"))
	row.add_child(_stop)
	_meters = MeterList.new()
	_meters.max_bar = 200.0
	body.add_child(_meters)


func refresh() -> void:
	var v := G.view
	var me := G.me()
	if me.is_empty():
		return
	var c: Dictionary = v["character"]
	var life: Dictionary = c.get("life") if c.get("life") is Dictionary else {}
	_portrait.show_person(G.you(), hud.world)
	var head := "%s %s  %s %d %s" % [UI.b(UI.c(UI.GREEN, UI.esc(G.you()))), life.get("gender_icon", ""), UI.dim("age"),
			int(c["age"]), UI.dim("(%s)" % c.get("life_stage", ""))]
	if c.get("body_temperature") != null:
		head += UI.dim("  %.1f°C" % float(c["body_temperature"]))
	# Offices and statuses, then work.
	var parts: Array = []
	for pos in me.get("offices", []):
		parts.append(UI.c(UI.CYAN, UI.b(UI.esc(pos))))
	for pos in me.get("statuses", []):
		parts.append(UI.c(UI.RED, UI.b(UI.esc(pos))))
	var line := ", ".join(PackedStringArray(parts)) if not parts.is_empty() else UI.c(UI.CYAN, UI.b(UI.esc(G.term("member"))))
	var child: bool = bool(life.get("child", false))
	if not (me.get("occupations", []) as Array).is_empty():
		line += UI.dim(" · ") + UI.c(UI.CYAN, "%s %s" % [G.occupation_icons(me), UI.esc(", ".join(PackedStringArray(me["occupations"])))])
	elif (me.get("offices", []) as Array).is_empty():
		line += UI.dim(" · a child (W: play, study)" if child else " · no work (J)")
	if not me.get("can_vote", true) and life.get("of_age", true):
		line += UI.c(UI.RED, " · cannot vote")
	elif not me.get("can_vote", true):
		line += UI.dim(" · votes from %s" % G.num(life.get("politics_age", 14)))
	var roles: Array = v.get("your_interfaces", [])
	var role_line := UI.dim("no roles yet")
	if not roles.is_empty():
		var named: Array = []
		for k in roles:
			named.append("[hint=%s]%s[/hint]" % [str(k).replace("_", " "), Rows.role_icon(k)])
		role_line = UI.dim("roles ") + " ".join(PackedStringArray(named))
		if roles.size() <= 2:
			var words: Array = []
			for k in roles:
				words.append("%s %s" % [Rows.role_icon(k), str(k).replace("_", " ")])
			role_line = "  ".join(PackedStringArray(words))
	_id.text = "%s\n%s\n%s" % [head, line, role_line]

	var lines: Array = []
	if v.get("free", false):
		lines.append(UI.tag("READY", UI.GREEN) + UI.dim(" free to act"))
	else:
		lines.append(UI.tag(str(v.get("doing", "busy")) if v.get("doing") != null else "busy", UI.YELLOW)
				+ UI.dim(" %s left" % G.fmt_life(float(v.get("busy_hours_left", 0)))))
	_stop.visible = not v.get("free", false) and bool(v.get("can_stop", false))
	var side = v.get("side")
	if side is Dictionary and float(side.get("hours_left", 0)) > 0:
		lines.append(UI.tag(str(side.get("doing", "talking")), UI.YELLOW) + UI.dim(" %s left · on the side" % G.fmt_life(float(side["hours_left"]))))
	elif side is Dictionary and side.get("can_talk", false):
		lines.append(UI.tag("P", UI.GREEN) + UI.c(UI.GREEN, " ready to talk again") + UI.dim(" (while you work)"))
	for entry in G.ui.get("life_status", []):
		match str(entry[0]):
			"illness":
				lines.append(UI.tag(str(entry[1]), UI.RED, Color.WHITE) + " " + UI.c(UI.RED, UI.esc(entry[2])))
			"pregnancy":
				var pr: Dictionary = life.get("pregnancy", {})
				lines.append(UI.tag(str(entry[1]), UI.MAGENTA) + " " + UI.c(UI.MAGENTA, UI.text_bar(float(pr.get("share", 0)), 1.0, 12))
						+ " " + UI.dim(UI.esc(entry[2])))
			_:
				lines.append(UI.tag(str(entry[1]), UI.CYAN) + " " + UI.dim(UI.esc(entry[2])))
	if float(v.get("contest_cooldown_hours", 0)) > 0:
		lines.append(UI.dim("lost a contest: no campaign or challenge for %s" % G.fmt_life(float(v["contest_cooldown_hours"]))))
	var ic = v.get("in_contest")
	if ic is Dictionary:
		var hint: String = {"audience": UI.c(UI.GREEN, UI.b("P")) + " speak", "duel": "fighting"}.get(str(ic.get("style", "")), "")
		lines.append(UI.tag("%s vs %s" % [ic.get("name", ""), ic.get("opponent", "")], UI.MAGENTA.darkened(0.4), Color.WHITE) + " " + hint)
	_state.text = "\n".join(PackedStringArray(lines))

	var rows := Rows.body(c, true)
	var ab = v.get("ability")
	if ab is Dictionary:
		rows.append(MeterList.row("Ability", float(ab["value"]), 100, UI.level_color(float(ab["value"])), "%d" % int(round(float(ab["value"])))))
	var skill := G.skill_average(c.get("skills", {}))
	rows.append(MeterList.row("Skills", skill, G.skill_max(), UI.SKILL, "%.1f avg" % skill))
	var mood := float(v.get("mood", 50))
	rows.append(MeterList.row("Mood", mood, 100, UI.level_color(mood), "%d" % int(round(mood)), UI.TEXT, true))
	_meters.set_rows(rows)

class_name CharacterWindow
extends GameWindow
## F8: your full character sheet. Who you are, your roles and ability, attributes, body, life,
## every contentment meter with what moves it, your patience, and every skill.

var _portrait: Portrait
var _head: RichTextLabel
var _roles: RichTextLabel
var _attributes: MeterList
var _body: MeterList
var _body_note: RichTextLabel
var _life: RichTextLabel
var _content: RichTextLabel
var _skills_head: Label
var _skills: MeterList


func build() -> void:
	close_key = KEY_F8
	set_title("Your character")
	set_hint("wheel or PgUp PgDn scroll · F8 or Esc closes · updates live")
	var top := UI.hbox(14)
	content.add_child(top)
	_portrait = Portrait.new(84)
	_portrait.frame_colour = UI.GREEN
	top.add_child(_portrait)
	_head = UI.rich(15)
	top.add_child(_head)
	var columns := UI.hbox(28)
	var scroll := UI.scroll(columns)
	content.add_child(scroll)
	var left := UI.vbox(14)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(left)
	var right := UI.vbox(14)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_child(right)

	_roles = UI.rich(14)
	section(left, "Roles", "what your office or membership lets you do (F3 says which office gives what)").add_child(_roles)
	_attributes = _meters()
	section(left, "Attributes").add_child(_attributes)
	var body_box := section(left, "Body")
	_body = _meters()
	body_box.add_child(_body)
	_body_note = UI.rich(13)
	body_box.add_child(_body_note)
	_life = UI.rich(14)
	section(left, "Life").add_child(_life)

	_content = UI.rich(14)
	section(right, "Content", "each meter moves toward what you experience").add_child(_content)
	var skills_box := section(right, "Skills", "they grow while you do the work that uses them; talent (the attribute) speeds learning")
	_skills_head = UI.label("", 13, UI.DIM)
	skills_box.add_child(_skills_head)
	_skills = _meters()
	skills_box.add_child(_skills)


func _meters() -> MeterList:
	var m := MeterList.new()
	m.max_bar = 170.0
	m.min_bar = 110.0
	return m


func refresh() -> void:
	var v := G.view
	var c: Dictionary = v["character"]
	var me := G.me()
	if me.is_empty():
		return
	_portrait.show_person(G.you(), hud.world)
	var positions: Array = v.get("your_positions", [])
	var t := UI.c(UI.CYAN, UI.b(UI.esc(G.you()))) + "  age %d (%s)  ·  %s" % [int(c["age"]), c.get("life_stage", ""),
			UI.esc(", ".join(PackedStringArray(positions))) if not positions.is_empty() else G.term("member")]
	var jobs: Array = v.get("your_occupations", [])
	if not jobs.is_empty():
		t += UI.c(UI.CYAN, "  ·  %s %s" % [G.occupation_icons(me), UI.esc(", ".join(PackedStringArray(jobs)))])
	t += "\n" + UI.i(UI.esc(me.get("description", "")))
	t += "\n" + UI.dim("Traits: %s" % ", ".join(PackedStringArray(c.get("traits", []))))
	_head.text = t

	# Roles and ability
	var r := ""
	var ab = v.get("ability")
	if ab is Dictionary:
		var val := float(ab["value"])
		r += UI.b("Ability ") + UI.c(UI.level_color(val), "%d %s" % [int(round(val)), UI.text_bar(val, 100, 12)]) + "  " + UI.dim(Rows.ability_note(ab)) + "\n"
		r += UI.dim("How well you do your job right now: talent, skill, and how tired or unwell you are.") + "\n"
	var roles: Array = v.get("your_interfaces", [])
	for key in roles:
		r += "%s %s\n" % [Rows.role_icon(key), str(key).replace("_", " ")]
	if roles.is_empty():
		r += UI.dim("No roles yet.") + "\n"
	_roles.text = r.strip_edges()

	var rows: Array = []
	var defs := G.attributes()
	for k in defs:
		var val := float(c.get("attributes", {}).get(k, 0))
		rows.append(MeterList.row(str(defs[k]["name"]), val, G.attr_max(), UI.ATTRIBUTE, "%d   %s" % [int(val), defs[k].get("description", "")], UI.DIM, true))
	_attributes.set_rows(rows)

	_body.set_rows(Rows.body(c, true))
	var note := ""
	if c.get("body_temperature") != null:
		var w: Dictionary = v.get("world", {})
		note += "Temperature %.1f°C  (air %s°C, comfortable at %s°C)\n" % [float(c["body_temperature"]), G.num(w.get("temperature")), G.num(w.get("comfort"))]
	note += UI.dim("Press E to eat, drink, sleep or warm up. Needs fall over the day-night cycle; an empty one wears down health. " \
			+ "Health comes back only while you are not working (fastest resting or asleep).")
	_body_note.text = note

	var life: Dictionary = c.get("life") if c.get("life") is Dictionary else {}
	var l := "%s %s, %s%s\n" % [life.get("gender_icon", ""), life.get("gender_name", ""), str(c.get("life_stage", "")).to_lower(),
			(", mother %s" % life["mother"]) if life.get("mother") != null and str(life.get("mother")) != "" else ""]
	for entry in G.ui.get("life_status", []):
		var colour := UI.RED if str(entry[0]) == "illness" else (UI.MAGENTA if str(entry[0]) == "pregnancy" else UI.CYAN)
		l += UI.c(colour, UI.b(UI.esc(entry[1]) + ": ")) + UI.esc(entry[2]) + "\n"
		if str(entry[0]) == "pregnancy" and life.get("pregnancy") is Dictionary:
			l += UI.c(UI.MAGENTA, UI.text_bar(float(life["pregnancy"].get("share", 0)), 1.0, 30)) + "\n"
		if str(entry[0]) == "illness" and life.get("illness") is Dictionary and str(life["illness"].get("description", "")) != "":
			l += UI.dim(UI.esc(life["illness"]["description"])) + "\n"
	if life.get("child", false) and life.get("growth") is Dictionary:
		var bits: Array = []
		for k in life["growth"]:
			bits.append("%s %d (%d%%)" % [defs.get(k, {}).get("abbr", k), int(c.get("attributes", {}).get(k, 0)) + 1, int(round(float(life["growth"][k]) * 100.0))])
		l += UI.dim("Growing toward: " + ", ".join(PackedStringArray(bits))) + "\n"
	l += UI.dim("Work from age %s; vote and hold office from %s. The old fall ill more often and are cured less often." % [G.num(life.get("work_age", 9)), G.num(life.get("politics_age", 14))])
	_life.text = l

	_content.text = _contentment(v)

	var skill_values: Dictionary = c.get("skills", {})
	_skills_head.text = "average %.1f of %s" % [G.skill_average(skill_values), G.num(G.skill_max())]
	rows = []
	var sdefs := G.skills()
	for k in sdefs:
		var val := float(skill_values.get(k, 0))
		var abbr := str(defs.get(sdefs[k].get("attribute", ""), {}).get("abbr", ""))
		var row := MeterList.row(str(sdefs[k]["name"]), val, G.skill_max(), UI.SKILL, "%.1f  (%s) %s" % [val, abbr, sdefs[k].get("description", "")], UI.DIM, val > 0.0)
		if val <= 0.0:
			row["label_color"] = UI.DIM
		rows.append(row)
	_skills.set_rows(rows)


func _contentment(v: Dictionary) -> String:
	## Each of your contentment meters: where it is heading and what speeds or slows its rise.
	var t := ""
	var doing = v.get("working_now")
	if doing != null and str(doing) != "":
		var what := str(doing)
		t += UI.dim("(working as %s now)" % (what.substr(7) if what.begins_with("office:") else what)) + "\n"
	else:
		t += UI.dim("(not working your job right now: Work does not rise)") + "\n"
	for key in v.get("satisfaction", {}):
		var m: Dictionary = v["satisfaction"][key]
		var val := float(m["value"])
		t += UI.b(UI.esc(m["name"])) + "  " + UI.c(UI.level_color(val), "%d %s " % [int(round(val)), UI.text_bar(val, 100, 12)])
		if m.get("rising") == null:
			t += "\n"
			continue
		t += UI.c(UI.GREEN, "▲ rising") if m["rising"] else UI.c(UI.RED, "▼ falling")
		if m.get("target") != null:
			t += UI.dim(" toward %d" % int(round(float(m["target"]))))
		var factors: Array = m.get("factors", []) if m.get("factors") is Array else []
		var bits: Array = []
		for f in factors:
			bits.append("%s: %s%s" % [f.get("label", ""), f.get("detail", ""), (" ×%s" % G.num(f["mult"])) if f.get("mult") != null else ""])
		if not bits.is_empty():
			t += "\n" + UI.dim("      " + (("rises ×%s as fast: " % G.num(m["multiplier"])) if m.get("multiplier") != null else "") + UI.esc(" · ".join(PackedStringArray(bits))))
		t += "\n"
	t += UI.dim("Work rises only while you work your job (W): faster with the right tools (two or more, faster still), the more of " \
			+ "your age's jobs are open, and the better you fit it. Safety rises with Warriors on patrol and every position filled; " \
			+ "Comfort with the fire being used (people warming up), care, and the Spirit Keeper's rituals; Leaders with everything " \
			+ "else going well.") + "\n"
	var pat = v.get("patience")
	if pat is Dictionary and not pat.is_empty():
		t += "\n" + UI.c(UI.GOLD, UI.b("Patience")) + UI.dim("  how long you'd put up with things before moving against those in charge (NPCs act only once theirs runs out)") + "\n"
		for key in pat:
			var d: Dictionary = pat[key]
			var name := str(v.get("satisfaction", {}).get(key, {}).get("name", key))
			var cell := Rows.patience_cell({key: d})
			t += UI.b(UI.esc(name)) + "  " + UI.c(cell[1], str(cell[0])) + UI.dim("   unhappy %s of %s hours allowed while %s is below %s" % [G.num(d.get("unrest", 0)),
					G.num(d.get("grace", 0)), name, G.num(d.get("below", 0))]) + "\n"
	var ab = v.get("ability")
	if ab is Dictionary:
		t += "\n" + UI.c(UI.GOLD, UI.b("Ability")) + "  " + UI.c(UI.level_color(float(ab["value"])), UI.b("%d/100 as %s" % [int(round(float(ab["value"]))), ab.get("job", "")]))
		var skill := (" and %s %.2f" % [str(ab["skill_name"]).to_lower(), float(ab.get("skill_level", 0))]) if ab.get("skill_name") != null and str(ab.get("skill_name")) != "" else ""
		var tired := (", tired -%d" % int(round(float(ab["tired"])))) if float(ab.get("tired", 0)) >= 0.5 else ""
		var unwell := (", unwell -%d" % int(round(float(ab["unwell"])))) if float(ab.get("unwell", 0)) >= 0.5 else ""
		t += "\n" + UI.dim("Not contentment: how well you do the job. %s%s make %d rested and well%s%s. Work your job (W) to practise the skill." % [
				", ".join(PackedStringArray(ab.get("attributes", []))), skill, int(round(float(ab.get("rested", 0)))), tired, unwell])
	return t

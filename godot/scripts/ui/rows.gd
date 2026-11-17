class_name Rows
extends RefCounted
## What the meters show, worked out from the view: the same rows wherever a person's body, contentment,
## skills or attributes appear (your own panel, the tribe's cards, a person's card).

const HEALTH_ICON := "💗"


static func body(sheet: Dictionary, words: bool = true) -> Array:
	## Health and every need, each with its word ('Full', 'Thirsty'), or its number where room is short.
	var hp := float(sheet.get("health", 0))
	var rows: Array = [MeterList.row(HEALTH_ICON, hp, 100, UI.RED if hp < 50 else UI.GREEN,
			("Health %d" % int(hp)) if words else str(int(hp)), UI.RED if hp < 50 else UI.TEXT)]
	var defs := G.needs()
	for k in defs:
		var need: Dictionary = sheet.get("needs", {}).get(k, {})
		var v := float(need.get("value", 0))
		var critical := bool(need.get("critical", false))
		rows.append(MeterList.row(str(defs[k]["icon"]), v, 100, UI.need_color(v, critical),
				str(need.get("label", "")) if words else str(int(v)), UI.RED if critical else UI.TEXT))
	return rows


static func content(satisfaction: Dictionary, mood = null, rising = null) -> Array:
	## The contentment meters, then mood if given. An arrow after the number: rising or falling.
	var rows: Array = []
	var meters: Dictionary = G.view.get("satisfaction", {})
	for key in meters:
		var m: Dictionary = meters[key]
		var val := float(satisfaction.get(key, 50))
		var up = m.get("rising") if rising == null else (rising as Dictionary).get(key)
		var arrow := "" if up == null else ("▲" if up else "▼")
		rows.append(MeterList.row(str(m["name"]), val, 100, UI.level_color(val), "%d%s" % [int(round(val)), arrow]))
	if mood != null:
		rows.append(MeterList.row("Mood", float(mood), 100, UI.level_color(float(mood)), "%d" % int(round(float(mood))), UI.TEXT, true))
	return rows


static func skills(skill_values: Dictionary, limit: int) -> Array:
	## Their best skills (only those above nothing).
	var best: Array = []
	for k in skill_values:
		if float(skill_values[k]) > 0.0:
			best.append([float(skill_values[k]), k])
	best.sort_custom(func(a, b): return a[0] > b[0])
	if best.is_empty():
		return [{"text": "no skills yet", "color": UI.DIM}]
	var rows: Array = []
	var defs := G.skills()
	for entry in best.slice(0, limit):
		rows.append(MeterList.row(str(defs.get(entry[1], {}).get("name", entry[1])), entry[0], G.skill_max(), UI.SKILL, "%.1f" % entry[0]))
	return rows


static func attributes(p: Dictionary) -> Array:
	var rows: Array = []
	var defs := G.attributes()
	for k in defs:
		var v := float(p.get(k, 0))
		rows.append(MeterList.row(str(defs[k]["abbr"]), v, G.attr_max(), UI.ATTRIBUTE, str(int(v)), UI.TEXT, true))
	return rows


static func life_icons(p: Dictionary) -> String:
	## Icons for what someone's body is going through: ill, with child, a child or a baby.
	var life = p.get("life")
	if not (life is Dictionary):
		return ""
	var out := ""
	if life.get("illness") != null:
		out += str(life["illness"].get("icon", "🤒"))
	if life.get("pregnancy") != null:
		out += str(life["pregnancy"].get("icon", "🤰"))
	if life.get("child", false):
		out += "👶" if float(p.get("age", 0)) < 2 else "🧒"
	return out


static func patience_cell(patience) -> Array:
	## [text, colour] for someone's patience with the leaders (or the society, if that is worse).
	if not (patience is Dictionary) or patience.is_empty():
		return ["-", UI.DIM]
	var worst = null
	for d in patience.values():
		if worst == null or float(d["left"]) < float(worst["left"]) or \
				(float(d["left"]) == float(worst["left"]) and float(d["restless"]) > float(worst["restless"])):
			worst = d
	if float(worst["restless"]) > 0 or float(worst["left"]) <= 0:
		return ["● out", UI.RED]
	if float(worst["unrest"]) <= 0:
		return ["∙ fine", UI.GREEN]
	var left := float(worst["left"])
	return ["◔ thin" if left < 0.4 else ("◑ wearing" if left < 0.75 else "◕ grumbling"), UI.YELLOW if left < 0.4 else UI.YELLOW.darkened(0.25)]


static func carried(inv) -> String:
	## '🎒 4/16  🪨 3  🪵 2': what someone carries, in one line (BBCode).
	if not (inv is Dictionary) or inv.is_empty():
		return ""
	var totals := {}
	for s in inv.get("slots", []):
		if s != null:
			totals[s["item"]] = int(totals.get(s["item"], 0)) + int(s["count"])
	var t := UI.dim("🎒 %d/%d" % [int(inv["size"]) - int(inv["free"]), int(inv["size"])])
	for key in G.defs.get("items", {}):
		if totals.has(key):
			t += "  %s %d" % [G.item(key)["icon"], totals[key]]
	if totals.is_empty():
		t += UI.dim("  carries nothing")
	return t


static func ability_note(ab: Dictionary) -> String:
	## 'STR+WIS · leadership 3.2 · tired -8': what the ability rests on and what drags it down.
	var bits: Array = []
	for a in (ab.get("attributes", []) as Array).slice(0, 3):
		bits.append(str(a).substr(0, 3).to_upper())
	var t := "+".join(PackedStringArray(bits))
	if ab.get("skill_name") != null and str(ab.get("skill_name")) != "":
		t += " · %s %.1f" % [str(ab["skill_name"]).to_lower(), float(ab.get("skill_level", 0))]
	for pair in [["tired", "tired"], ["unwell", "ill"]]:
		if float(ab.get(pair[0], 0)) >= 1.0:
			t += " · %s -%d" % [pair[1], int(round(float(ab[pair[0]])))]
	return t


static func role_icon(key: String) -> String:
	return str(G.defs.get("interface_icons", {}).get(key, "•"))


static func head_line(p: Dictionary) -> String:
	## A member's card heading (BBCode): age, health of body, office and work, ability, description.
	var life: Dictionary = p.get("life") if p.get("life") is Dictionary else {}
	var sheet: Dictionary = p.get("sheet", {})
	var t := UI.dim("%s age %d (%s)" % [life.get("gender_icon", ""), int(p.get("age", 0)), sheet.get("life_stage", "")])
	if life.get("illness") != null:
		t += "  " + UI.c(UI.RED, UI.b("%s %s" % [life["illness"]["icon"], str(life["illness"]["name"]).to_lower()]))
	if life.get("pregnancy") != null:
		var pr: Dictionary = life["pregnancy"]
		t += "  %s %s" % [pr["icon"], UI.c(UI.MAGENTA, "%s month %d/%d" % [UI.text_bar(float(pr["share"]), 1.0, 8), int(round(float(pr["months"]))), int(round(float(pr["term_months"])))])]
	elif life.get("child", false) and life.get("illness") == null:
		t += "  " + life_icons(p)
	var positions := G.positions_of(p)
	t += "  ·  " + UI.c(UI.CYAN, UI.b(UI.esc(positions if positions != "" else G.term("member"))))
	if not (p.get("occupations", []) as Array).is_empty():
		t += "  ·  " + UI.c(UI.CYAN, "%s %s" % [G.occupation_icons(p), UI.esc(", ".join(PackedStringArray(p["occupations"])))])
	if p.get("work_quality") != null:
		var wq := float(p["work_quality"])
		t += UI.dim("  ·  ability ") + UI.c(UI.level_color(wq), UI.b("%d" % int(round(wq))))
	if not p.get("can_vote", true) and life.get("of_age", true):
		t += UI.c(UI.RED, "  ·  cannot vote")
	if sheet.get("body_temperature") != null:
		t += UI.dim("  ·  %.1f°C" % float(sheet["body_temperature"]))
	t += "\n" + UI.i(UI.esc(p.get("description", "")))
	if life.get("mother") != null and str(life.get("mother")) != "":
		t += UI.dim("  (mother: %s)" % life["mother"])
	if not (p.get("traits", []) as Array).is_empty():
		t += UI.dim("  " + ", ".join(PackedStringArray(p["traits"])))
	t += "\n" + carried(p.get("inventory"))
	return t

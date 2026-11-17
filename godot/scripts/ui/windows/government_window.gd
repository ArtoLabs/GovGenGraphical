class_name GovernmentWindow
extends GameWindow
## F3: who is how far persuaded in every running campaign, then the offices, statuses, the work of
## the tribe, and the forms of government that could come next.

var _text: RichTextLabel


func build() -> void:
	close_key = KEY_F3
	set_title("Government")
	set_hint("wheel or PgUp PgDn scroll · F3 or Esc closes")
	_text = UI.rich(15, false)
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_ALL
	content.add_child(_text)
	_text.grab_focus.call_deferred()


func _head(text: String) -> String:
	return "\n" + UI.c(UI.GOLD, UI.b(text)) + "\n"


func _contest_meters() -> String:
	## Each running campaign or oration: how far every listener is won over.
	var v := G.view
	var contests: Array = []
	for c in v.get("contests", []):
		if str(c.get("style", "")) in ["persuasion", "audience"]:
			contests.append(c)
	if contests.is_empty():
		return ""
	contests.sort_custom(func(a, b): return (a["your_role"] in ["challenger", "defender"]) and not (b["your_role"] in ["challenger", "defender"]))
	var t := UI.c(UI.GOLD, UI.b("Campaigns and orations: who is how far persuaded")) + "\n"
	t += "[table=%d]" % contests.size()
	for c in contests:
		var cell := UI.b("%s %s %s" % [c.get("icon", ""), "persuaded by" if str(c["style"]) == "persuasion" else "for", UI.esc(c["challenger"])])
		cell += "\n" + UI.dim("   (%s)" % UI.esc(c["office"])) + "\n"
		for p in G.players():
			var name := str(p["name"])
			var m = c.get("meters", {}).get(name)
			if m == null and name != str(c["challenger"]) and name != str(c.get("defender", "")):
				continue
			cell += UI.c(UI.GREEN if name == G.you() else UI.TEXT, UI.b(UI.esc(name))) + "  "
			if m == null:
				cell += UI.c(UI.CYAN, "campaigning" if name == str(c["challenger"]) else "defending") + "\n"
			else:
				cell += UI.c(UI.GREEN if float(m) >= 50 else UI.YELLOW, "%s %d%%" % [UI.text_bar(float(m), 100, 10), int(round(float(m)))]) + "\n"
		t += "[cell padding=0,0,40,0]%s[/cell]" % cell
	t += "[/table]\n"
	return t


func refresh() -> void:
	var v := G.view
	var gov: Dictionary = v["government"]
	var t := _contest_meters()
	t += UI.c(UI.CYAN, UI.b(UI.esc(gov["name"]))) + "  (%s)\n%s\nChanged by %s.\n" % [gov.get("age", ""), UI.esc(gov.get("description", "")), gov.get("reformed_by", "")]
	t += _head("Offices")
	for name in v.get("offices", {}):
		var o: Dictionary = v["offices"][name]
		var holders: Array = o.get("holders", [])
		t += "  " + UI.b("%s (%d/%d): " % [UI.esc(name), holders.size(), int(o.get("seats", 1))]) + (UI.esc(", ".join(PackedStringArray(holders))) if not holders.is_empty() else UI.c(UI.YELLOW, "vacant"))
		if not o.get("unlocked", true):
			t += UI.c(UI.RED, "  [lb]needs %s]" % ", ".join(PackedStringArray(o.get("requires", []))))
		var ways: Array = ["persuasion"] if o.get("persuadable", false) else []
		var kinds: Array = o.get("challenges", [])
		if not kinds.is_empty():
			ways.append("challenge (%s)" % ", ".join(PackedStringArray(kinds)).replace("skill", "a contest in one's own work"))
		var also := ("\n    Can also be taken by %s" % " or ".join(PackedStringArray(ways))) if not ways.is_empty() else ""
		var roles: Array = o.get("interfaces", [])
		t += "\n" + UI.dim("    %s\n    Chosen by %s; removed by %s%s\n    Roles: %s" % [UI.esc(o.get("description", "")),
				o.get("selected_by", ""), o.get("removed_by", ""), also, ", ".join(PackedStringArray(roles)).replace("_", " ") if not roles.is_empty() else "none"]) + "\n"
	if not (v.get("statuses", {}) as Dictionary).is_empty():
		t += _head("Statuses")
	for name in v.get("statuses", {}):
		var s: Dictionary = v["statuses"][name]
		var holders: Array = s.get("holders", [])
		t += "  " + UI.b(UI.esc(name) + ": ") + (UI.esc(", ".join(PackedStringArray(holders))) if not holders.is_empty() else "none")
		if not s.get("unlocked", true):
			t += UI.c(UI.RED, "  [lb]needs %s]" % ", ".join(PackedStringArray(s.get("requires", []))))
		t += "\n" + UI.dim("    %s Granted by %s." % [UI.esc(s.get("description", "")), s.get("granted_by", "")]) + "\n"
	var shared: Array = gov.get("member_interfaces", [])
	t += "\nEvery member can use: %s. A player may hold %d office(s).\n" % [", ".join(PackedStringArray(shared)).replace("_", " ") if not shared.is_empty() else "nothing",
			int(gov.get("max_offices_per_player", 1))]
	t += _head("Work (occupations)")
	for name in v.get("occupations", {}):
		var o: Dictionary = v["occupations"][name]
		var holders: Array = o.get("holders", [])
		var seats := "%d/%d" % [holders.size(), int(o["seats"])] if o.get("seats") != null and int(o.get("seats")) > 0 else "%d" % holders.size()
		t += "  " + UI.b("%s %s (%s): " % [o.get("icon", ""), UI.esc(name), seats]) + (UI.esc(", ".join(PackedStringArray(holders))) if not holders.is_empty() else UI.dim("nobody"))
		if not o.get("unlocked", true):
			t += UI.c(UI.RED, "  [lb]needs %s]" % ", ".join(PackedStringArray(o.get("requires", []))))
		var by: Array = o.get("appointed_by", [])
		var how := "Anyone may volunteer" if o.get("open", false) and by.is_empty() else "Appointed by the %s%s" % [" or ".join(PackedStringArray(by)), "; volunteers welcome" if o.get("open", false) else ""]
		var skill := ("; trains %s" % o["skill"]) if o.get("skill") != null and str(o.get("skill")) != "" else ""
		t += "\n" + UI.dim("    %s %s. Suits %s%s; +%s innovation pts/yr." % [UI.esc(o.get("description", "")), how,
				", ".join(PackedStringArray(o.get("attributes", []))), skill, G.num(o.get("points", 0))]) + "\n"
	t += _head("Possible reforms")
	var reforms: Array = gov.get("available_reforms", [])
	if reforms.is_empty():
		t += UI.dim("  None yet. New forms of government open with new ages and innovations.") + "\n"
	elif int(gov.get("reform_cooldown_days", 0)) > 0:
		t += UI.c(UI.YELLOW, "  No reform for %d more days." % int(gov["reform_cooldown_days"])) + "\n"
	for r in reforms:
		var offices: Array = []
		for n in r.get("offices", {}):
			var seats := int(r["offices"][n].get("seats", 1))
			offices.append("%s x%d" % [n, seats] if seats > 1 else str(n))
		var yours = r.get("outcome", {}).get(G.you())
		t += "  " + UI.b(UI.esc(r["name"])) + UI.dim(" (%s): %s\n    Offices: %s\n    You would be: %s" % [r.get("age", ""), UI.esc(r.get("description", "")),
				", ".join(PackedStringArray(offices)), str(yours) if yours != null and str(yours) != "" else "no office"]) + "\n"
	if _text.text != t:
		var at := _text.get_v_scroll_bar().value
		_text.text = t
		_text.get_v_scroll_bar().set_deferred("value", at)

class_name GovPanel
extends TitledPanel
## Along the bottom: the government and society at the left, a card for every running contest and open
## ballot (each with its countdown) in the middle, the latest alerts at the right. F3 has the rest.

const TAG := {"info": [Color(0.5, 0.52, 0.56), Color(0.05, 0.05, 0.05)], "action": [UI.GREEN, Color(0.04, 0.08, 0.04)],
		"urgent": [UI.RED, Color.WHITE], "done": [UI.CYAN, Color(0.03, 0.07, 0.09)]}

var _head: RichTextLabel
var _cards: HBoxContainer
var _news: RichTextLabel
var _labels: Array = []


func _init() -> void:
	super("Government and votes", "F3 more")
	var h := UI.hbox(12)
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(h)
	_head = UI.rich(13)
	_head.custom_minimum_size = Vector2(280, 0)
	_head.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	h.add_child(_head)
	h.add_child(VSeparator.new())
	_cards = UI.hbox(8)
	var scroll := ScrollContainer.new()
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(_cards)
	h.add_child(scroll)
	h.add_child(VSeparator.new())
	_news = UI.rich(13, false)
	_news.custom_minimum_size = Vector2(400, 0)
	_news.size_flags_horizontal = Control.SIZE_SHRINK_END
	_news.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_child(_news)


static func tag(text: String, level: String) -> String:
	var st: Array = TAG.get(level, TAG["info"])
	return UI.tag(text, st[0], st[1])


func refresh() -> void:
	var v := G.view
	var gov: Dictionary = v["government"]
	var t := UI.c(UI.CYAN, UI.b(UI.esc(gov["name"]))) + UI.dim("  changed by %s" % gov.get("reformed_by", ""))
	var reforms: Array = gov.get("available_reforms", [])
	var names: Array = []
	for r in reforms:
		names.append(str(r["name"]))
	t += "\n" + UI.dim("Reforms ") + (UI.esc(", ".join(PackedStringArray(names))) if not names.is_empty() else "none yet")
	if not reforms.is_empty() and int(gov.get("reform_cooldown_days", 0)) > 0:
		t += UI.dim(" (not for %d days)" % int(gov["reform_cooldown_days"]))
	elif not reforms.is_empty() and gov.get("reform_mode") != null:
		t += UI.c(UI.GREEN, " (%s: F)" % ("by your decree" if str(gov["reform_mode"]) == "decree" else "you may call a vote"))
	var soc: Dictionary = v.get("society", {})
	if not soc.is_empty():
		t += "\n" + UI.dim("Society ") + UI.c(UI.level_color(float(soc["score"])), UI.b("%d" % int(round(float(soc["score"]))))) + UI.dim("  F9") + "\n"
		for q in soc.get("qualities", {}).values():
			if q.get("active", false):
				t += "[hint=%s]%s%s[/hint] " % [q.get("name", ""), q.get("icon", ""), UI.c(UI.level_color(float(q["value"])), "%d" % int(round(float(q["value"]))))]
	_head.text = t

	var needs_you := false
	var texts: Array = []
	var mine_first: Array = v.get("contests", []).duplicate()
	mine_first.sort_custom(func(a, b): return (a["your_role"] in ["challenger", "defender"]) and not (b["your_role"] in ["challenger", "defender"]))
	for c in mine_first:
		var made := _contest_card(c)
		texts.append(made[0])
		needs_you = needs_you or made[1]
	for b in v.get("ballots", []):
		var status: Array = G.ui.get("ballots", {}).get(b["key"], ["WATCHING", "info"])
		var level := str(status[1])
		needs_you = needs_you or level in ["action", "urgent"]
		var stage := "Nominations" if b.get("nominating", false) else "Voting"
		var card := tag(str(status[0]), level) + " " + UI.b(UI.esc(b["label"])) + "\n"
		if b.get("nominating", false):
			var noms: Array = b.get("nominations", [])
			card += UI.dim("Nominated: ") + (UI.esc(", ".join(PackedStringArray(noms))) if not noms.is_empty() else "nobody yet") + "\n"
		else:
			card += UI.dim("Choices: ") + UI.esc(" / ".join(PackedStringArray(b.get("choices", [])))) \
					+ UI.dim("  %d/%d voted" % [int(b.get("votes_cast", 0)), int(b.get("electorate_size", 0))]) + "\n"
		var left := int(b["days_left"]) if b.get("days_left") != null else 0
		var total := int(b["phase_days"]) if b.get("phase_days") != null else 30
		var colour := UI.RED if left <= 3 else (UI.YELLOW if left <= 10 else UI.GREEN)
		card += UI.c(colour, "%s %s close in %d day%s" % [UI.text_bar(left, total, 12), stage, left, "" if left == 1 else "s"])
		if str(status[0]) == "CANDIDATE":
			var by = b.get("nominated_by", {}).get(G.you())
			var how := ("%s put you forward" % by) if by != null and str(by) != G.you() else "you are standing"
			card += "\n" + UI.c(UI.alert_color(level), "%s. N declines." % how)
		elif level in ["action", "urgent"]:
			var key := "N" if str(status[0]) == "NOMINATE" else "V"
			var hint := "Busy: vote when you are free." if str(status[0]) == "VOTE WHEN FREE" else "Press %s to %s." % [key, "nominate" if key == "N" else "vote"]
			card += "\n" + UI.c(UI.alert_color(level), UI.b(hint))
		texts.append(card)
	_show_cards(texts)
	set_attention(needs_you)

	var news := ""
	if texts.is_empty():
		news += UI.dim("No open elections, votes or contests.") + "\n"
	var recent: Array = G.alerts.slice(maxi(0, G.alerts.size() - 5))
	recent.reverse()
	var fresh := Time.get_ticks_msec() - G.alert_msec < 4000
	for i in range(recent.size()):
		var a: Dictionary = recent[i]
		var text := UI.c(UI.alert_color(str(a["level"])), UI.esc(a["text"]))
		if i == 0 and fresh and str(a["level"]) in ["action", "urgent"]:
			text = tag(str(a["text"]), str(a["level"]))
		news += "%s %s %s\n" % [a.get("icon", ""), UI.dim(str(a.get("date", ""))), text]
	_news.text = news.strip_edges()


func _show_cards(texts: Array) -> void:
	if texts.size() != _labels.size():
		for c in _cards.get_children():
			c.queue_free()
		_labels = []
		for i in range(texts.size()):
			var panel := PanelContainer.new()
			panel.add_theme_stylebox_override("panel", UI.box(UI.INSET, UI.BORDER_DIM, 5, 9, 1, 6))
			panel.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			var r := UI.rich(13)
			r.custom_minimum_size = Vector2(300, 0)
			r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			panel.add_child(r)
			_cards.add_child(panel)
			_labels.append(r)
	for i in range(texts.size()):
		if (_labels[i] as RichTextLabel).text != texts[i]:
			(_labels[i] as RichTextLabel).text = texts[i]


func _contest_card(c: Dictionary) -> Array:
	## [BBCode, does it need you] for a running persuasion campaign or challenge.
	var role := str(c.get("your_role", ""))
	var mine := role in ["challenger", "defender"]
	var style := str(c.get("style", ""))
	var t := tag("PERSUASION" if style == "persuasion" else "CHALLENGE", "urgent" if mine else "info")
	if style == "pending":
		t += " " + UI.b("⏳ %s challenges %s for %s" % [c["challenger"], c["defender"], c["office"]]) + "\n"
		var kinds: Array = []
		for a in c.get("allowed", []):
			kinds.append(str(a["name"]).to_lower())
		t += "%s chooses the contest: %s\n" % [c["defender"], ", ".join(PackedStringArray(kinds))]
		t += UI.dim("%s to choose" % G.fmt_life(float(c.get("hours_left", 0))))
		if role == "defender":
			t += "\n" + UI.c(UI.RED, UI.b("Press H to choose your contest!"))
		return [t, mine]
	if style == "persuasion":
		var whom := (" (replacing %s)" % c["defender"]) if c.get("defender") != null and str(c.get("defender")) != "" else ""
		t += " " + UI.b("%s %s → %s%s" % [c.get("icon", ""), c["challenger"], c["office"], whom]) + "\n"
		var sup := float(c.get("support", 0))
		var need := float(c.get("success_at", 50))
		t += UI.c(UI.GREEN if sup >= need else UI.YELLOW, "%s persuaded %s %d%%" % [G.term("members"), UI.text_bar(sup, 100, 12), int(round(sup))])
		t += UI.dim(" (needs %d%%)" % int(need)) + "\n"
	else:
		t += " " + UI.b("%s %s vs %s for %s: %s" % [c.get("icon", ""), c["challenger"], c["defender"], c["office"], str(c.get("name", "")).to_lower()]) + "\n"
		if style == "audience":
			var sup := float(c.get("support", 0))
			t += UI.c(UI.GREEN if sup > 50 else UI.YELLOW, "Crowd for %s %s %d%%" % [c["challenger"], UI.text_bar(sup, 100, 12), int(round(sup))]) + "\n"
		elif style == "duel":
			var m := float(c.get("meters", {}).get("momentum", 50))
			t += "%s %s %s  " % [c["defender"], UI.text_bar(m, 100, 12), c["challenger"]]
			t += UI.c(UI.GREEN if m > 50 else UI.YELLOW, "%s for %s" % ["gaining" if m > 50 else ("losing" if m < 50 else "even"), c["challenger"]]) + "\n"
		else:
			var sc: Dictionary = c.get("scores", {})
			t += "%s %s %s  ·  %s %s %s\n" % [c["challenger"], G.num(sc.get(c["challenger"], 0)), c.get("unit", ""),
					c["defender"], G.num(sc.get(c["defender"], 0)), c.get("unit", "")]
	var left := float(c.get("hours_left", 0))
	t += UI.dim("%s %s left" % [UI.text_bar(left, float(c.get("total_hours", 1)), 12), G.fmt_life(left)])
	if role == "challenger" and style == "persuasion":
		t += "\n" + UI.c(UI.GREEN, UI.b("Press P to win people over."))
	elif role == "defender" and style == "persuasion":
		t += "\n" + UI.c(UI.RED, UI.b("Press P to keep people on your side!"))
	elif role == "audience" and style == "persuasion":
		t += "\n" + UI.dim("You are %d%% persuaded." % int(round(float(c.get("meters", {}).get(G.you(), 0)))))
	elif mine and style == "audience":
		t += "\n" + UI.c(UI.RED if role == "defender" else UI.GREEN, UI.b("Press P to speak to the listeners!"))
	elif mine:
		t += "\n" + UI.c(UI.RED if role == "defender" else UI.GREEN, UI.b("You are in this contest."))
	return [t, mine]

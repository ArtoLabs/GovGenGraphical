class_name InnovationPanel
extends TitledPanel
## Bottom right: what is being researched and what is queued, the next age, and an icon for everything
## discovered or open to research. Click an icon to see it in the innovations window (F4).

signal innovation_clicked(iname: String)

var _text: RichTextLabel


func _init() -> void:
	super("Innovation pool", "click an icon, or F4")
	_text = UI.rich(14)
	_text.meta_underlined = false
	_text.meta_clicked.connect(func(meta): innovation_clicked.emit(str(meta)))
	body.add_child(_text)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		innovation_clicked.emit("")


func _icon(row: Dictionary) -> String:
	return "[url=%s][hint=%s]%s[/hint][/url]" % [str(row["name"]), str(row["name"]), row.get("icon", "?")]


func refresh() -> void:
	var v := G.view
	var rows := {}
	for r in G.ui.get("innovations", []):
		rows[r["name"]] = r
	var lines: Array = []
	var res = v.get("researching")
	if res is Dictionary and rows.has(res["innovation"]):
		var row: Dictionary = rows[res["innovation"]]
		var line := "%s %s %s %s %d/%d" % [UI.dim("Researching"), _icon(row), UI.b(UI.esc(row["name"])),
				UI.c(UI.CYAN, UI.text_bar(float(res["points"]), float(res["cost"]), 10)), int(res["points"]), int(res["cost"])]
		var queue: Array = v.get("research_queue", [])
		if queue.size() > 1:
			line += "   " + UI.dim("then") + " "
			for n in queue.slice(1):
				if rows.has(n):
					line += _icon(rows[n]) + " "
		lines.append(line)
	else:
		lines.append(UI.dim("Researching ") + UI.c(UI.YELLOW, "nothing - press R to queue an innovation"))
	var next := UI.dim("latest age reached")
	if v.get("next_age") is Dictionary:
		next = UI.b(UI.esc(v["next_age"]["name"])) + " needs "
		var needs: Dictionary = v["next_age"]["needs"]
		for n in needs:
			next += "%s%s  " % [_icon(rows[n]) if rows.has(n) else UI.esc(n), UI.c(UI.GREEN, "✓") if needs[n] else UI.dim("·")]
	lines.append("%s %d %s   %s %s" % [UI.dim("Points"), int(v.get("points", 0)), UI.dim("(+%s/yr)" % G.num(v.get("points_per_year", 0))),
			UI.dim("Next age"), next])
	var found := ""
	var found_n := 0
	var open := ""
	var open_n := 0
	for name in rows:
		if rows[name]["status"] == "discovered":
			found += _icon(rows[name]) + " "
			found_n += 1
		elif rows[name]["status"] == "available":
			open += _icon(rows[name]) + " "
			open_n += 1
	lines.append(UI.dim("Discovered %d  " % found_n) + found)
	if open_n > 0:
		lines.append(UI.dim("Available %d   " % open_n) + open)
	_text.text = "\n".join(PackedStringArray(lines))

class_name InnovationsWindow
extends GameWindow
## F4: the innovations of the age with their status. Enter (or a double click) queues the highlighted
## one for research; S and I step through the status and role filters.

const STATUS := {"discovered": ["✓", UI.GREEN], "researching": ["▶", UI.YELLOW], "queued": ["…", UI.YELLOW],
		"available": ["○", UI.CYAN], "locked": ["·", UI.DIM]}
const STATUS_FILTERS := ["all", "available", "in progress", "discovered", "locked"]

var focus_name := ""
var _head: RichTextLabel
var _tree: Tree
var _detail: RichTextLabel
var _status_filter := 0
var _role_filter := -1
var _shown: Array = []
var _key := ""


func build() -> void:
	close_key = KEY_F4
	set_title("Innovations")
	set_hint("↑↓ choose · Enter researches it · S status filter · I role filter · F4 or Esc closes")
	_head = UI.rich(14)
	content.add_child(_head)
	_tree = Tree.new()
	_tree.columns = 8
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_search = false
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles := ["", "", "Innovation", "Kind", "Who researches it", "Cost", "Needs", "Status"]
	var widths := [34, 40, 250, 190, 280, 80, 0, 210]
	for i in range(8):
		_tree.set_column_title(i, titles[i])
		_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		_tree.set_column_expand(i, widths[i] == 0)
		if widths[i] > 0:
			_tree.set_column_custom_minimum_width(i, widths[i])
	_tree.item_selected.connect(_on_selected)
	_tree.item_activated.connect(_research)
	content.add_child(_tree)
	_detail = UI.rich(14)
	_detail.custom_minimum_size = Vector2(0, 96)
	content.add_child(_detail)
	_tree.grab_focus.call_deferred()


func _rows() -> Array:
	var wanted: Array = G.ui.get("age_innovations", [])
	var out: Array = []
	for r in G.ui.get("innovations", []):
		if r["name"] in wanted:
			out.append(r)
	return out


func _roles() -> Array:
	return (G.defs.get("interface_icons", {}) as Dictionary).keys()


func refresh() -> void:
	var rows := _rows()
	var status: String = STATUS_FILTERS[_status_filter]
	var role := "" if _role_filter < 0 else str(_roles()[_role_filter])
	var shown: Array = []
	for r in rows:
		if role != "" and str(r["interface"]) != role:
			continue
		if status == "in progress":
			if not (str(r["status"]) in ["researching", "queued"]):
				continue
		elif status != "all" and str(r["status"]) != status:
			continue
		shown.append(r)
	var counts := {"discovered": 0, "researching": 0, "queued": 0, "available": 0, "locked": 0}
	for r in rows:
		counts[r["status"]] = int(counts.get(r["status"], 0)) + 1
	_head.text = "%s  %s     %s" % [UI.c(UI.CYAN, UI.b("Innovations of the %s" % G.ui.get("age_name", ""))),
			UI.dim("%d discovered · %d in progress · %d available · %d locked" % [counts["discovered"], counts["researching"] + counts["queued"], counts["available"], counts["locked"]]),
			UI.c(UI.YELLOW, "showing: %s, %s" % [status, role.replace("_", " ") if role != "" else "all roles"])]
	# Fill the table again only when what it shows has changed, so the highlight stays put.
	var key := ""
	for r in shown:
		key += "%s:%s:%s|" % [r["name"], r["status"], r["you_can_research"]]
	if key == _key:
		return
	_key = key
	var keep := focus_name
	var chosen := _tree.get_selected()
	if keep == "" and chosen != null:
		keep = str(_shown[int(chosen.get_metadata(0))]["name"]) if int(chosen.get_metadata(0)) < _shown.size() else ""
	focus_name = ""
	_shown = shown
	_tree.clear()
	var root := _tree.create_item()
	var mine: Array = G.view.get("your_interfaces", [])
	var select: TreeItem = null
	for i in range(shown.size()):
		var r: Dictionary = shown[i]
		var st: Array = STATUS[r["status"]]
		var colour: Color = st[1]
		var it := _tree.create_item(root)
		it.set_metadata(0, i)
		it.set_text(0, str(st[0]))
		it.set_custom_color(0, colour)
		it.set_text(1, str(r.get("icon", "")))
		it.set_text(2, str(r["name"]))
		it.set_custom_color(2, colour if str(r["status"]) != "locked" else UI.DIM)
		it.set_text(3, str(r["interface"]).replace("_", " "))
		it.set_custom_color(3, UI.TEXT if r["interface"] in mine else UI.DIM)
		var who: Array = G.view.get("research_roles", {}).get(r["interface"], [])
		it.set_text(4, ", ".join(PackedStringArray(who)) if not who.is_empty() else "nobody yet")
		it.set_custom_color(4, UI.CYAN if not who.is_empty() else UI.RED)
		it.set_text(5, str(int(r["cost"])))
		var needs: Array = r.get("prerequisites", [])
		it.set_text(6, ", ".join(PackedStringArray(needs)) if not needs.is_empty() else "—")
		it.set_custom_color(6, UI.DIM if needs.is_empty() else (UI.RED if not (r.get("missing", []) as Array).is_empty() else UI.GREEN))
		it.set_text(7, str(r["status"]) + (" (you can)" if r.get("you_can_research", false) else ""))
		it.set_custom_color(7, colour)
		if str(r["name"]) == keep:
			select = it
	if select == null and root.get_child_count() > 0:
		select = root.get_child(0)
	if select != null:
		select.select(0)
		_tree.scroll_to_item(select)
		_show_detail(int(select.get_metadata(0)))
	else:
		_detail.text = UI.dim("Nothing to show with these filters.")


func _on_selected() -> void:
	var it := _tree.get_selected()
	if it != null:
		_show_detail(int(it.get_metadata(0)))


func _show_detail(i: int) -> void:
	if i < 0 or i >= _shown.size():
		_detail.text = ""
		return
	var r: Dictionary = _shown[i]
	var t := UI.b("%s %s" % [r.get("icon", ""), UI.esc(r["name"])]) + "  (%s, %s, cost %d)\n%s\n" % [str(r["interface"]).replace("_", " "), r.get("age", ""), int(r["cost"]), UI.esc(r.get("description", ""))]
	var who: Array = G.view.get("research_roles", {}).get(r["interface"], [])
	t += UI.c(UI.CYAN if not who.is_empty() else UI.RED, "Researched by: " + (", ".join(PackedStringArray(who)) if not who.is_empty() else "no role in this government")) + "\n"
	var needs: Array = r.get("prerequisites", [])
	if not needs.is_empty():
		var bits: Array = []
		for p in needs:
			bits.append(str(p) + (" (missing)" if p in r.get("missing", []) else ""))
		t += UI.dim("Needs: " + ", ".join(PackedStringArray(bits))) + "\n"
	if str(r.get("why_locked", "")) != "":
		t += UI.c(UI.RED, "Locked: " + UI.esc(r["why_locked"])) + "\n"
	if str(r.get("unlocks", "")) != "":
		t += UI.c(UI.GREEN, "Opens: " + UI.esc(r["unlocks"])) + "\n"
	_detail.text = t.strip_edges()


func _research() -> void:
	var it := _tree.get_selected()
	if it == null:
		return
	var r: Dictionary = _shown[int(it.get_metadata(0))]
	for a in G.legal("research"):
		if str(a["params"].get("innovation", "")) == str(r["name"]):
			G.act(a)
			hud.say("Queuing %s for research." % r["name"], "green")
			close()
			return
	var why := str(r.get("why_locked", ""))
	if why == "":
		why = ("it is already " + str(r["status"])) if str(r["status"]) != "available" else "none of your roles can research it, or you are busy"
	hud.say("Can't research %s: %s." % [r["name"], why], "yellow")


func show_result(text: String, style: String) -> void:
	_detail.text = UI.c(UI.style_color(style), UI.esc(text))


func handle_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	if key.keycode == KEY_S:
		_status_filter = (_status_filter + 1) % STATUS_FILTERS.size()
		_key = ""
		refresh()
		return true
	if key.keycode == KEY_I:
		_role_filter = _role_filter + 1 if _role_filter + 1 < _roles().size() else -1
		_key = ""
		refresh()
		return true
	if key.keycode in [KEY_ENTER, KEY_KP_ENTER]:
		_research()
		return true
	return false

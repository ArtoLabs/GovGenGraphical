class_name CraftsWindow
extends GameWindow
## F12 or K: the crafting chart. Every item the tribe can make or find in this age, who makes it, the
## research, tools and materials it takes, where those come from, and whether it can be had now.

const STATUS := {"ready": ["✓", UI.GREEN], "short": ["…", UI.YELLOW], "no_tool": ["…", UI.YELLOW],
		"no_worker": ["…", UI.YELLOW], "research": ["✗", UI.RED]}
const FILTERS := ["all", "can be had now", "not yet"]

var _head: RichTextLabel
var _tree: Tree
var _detail: RichTextLabel
var _rows: Array = []
var _shown: Array = []
var _filter := 0
var _age := ""
var _since := 0.0


func build() -> void:
	close_key = KEY_F12
	set_title("Crafting and gathering")
	set_hint("↑↓ choose an item · S shows all / can be had now / not yet · F12, K or Esc closes")
	_head = UI.rich(14)
	content.add_child(_head)
	_tree = Tree.new()
	_tree.columns = 10
	_tree.hide_root = true
	_tree.column_titles_visible = true
	_tree.select_mode = Tree.SELECT_ROW
	_tree.allow_search = false
	_tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var titles := ["", "", "Item", "Kind", "Made / found by", "Research", "Takes", "Store", "Now", "Used by"]
	var widths := [30, 38, 180, 90, 190, 200, 280, 64, 250, 0]
	for i in range(10):
		_tree.set_column_title(i, titles[i])
		_tree.set_column_title_alignment(i, HORIZONTAL_ALIGNMENT_LEFT)
		_tree.set_column_expand(i, widths[i] == 0)
		_tree.set_column_clip_content(i, true)
		if widths[i] > 0:
			_tree.set_column_custom_minimum_width(i, widths[i])
	_tree.item_selected.connect(_on_selected)
	content.add_child(_tree)
	_detail = UI.rich(14, false)
	_detail.custom_minimum_size = Vector2(0, 210)
	content.add_child(_detail)
	G.crafts_received.connect(_on_crafts)
	Net.send({"cmd": "crafts"})
	_tree.grab_focus.call_deferred()


func _process(delta: float) -> void:
	_since += delta
	if _since > 3.0:   # the store and the workers change while the chart is open
		_since = 0.0
		Net.send({"cmd": "crafts"})


func _on_crafts(msg: Dictionary) -> void:
	_rows = msg.get("rows", [])
	_age = str(msg.get("age", ""))
	_fill()


func _fill() -> void:
	var which: String = FILTERS[_filter]
	var keep := ""
	var chosen := _tree.get_selected()
	if chosen != null and int(chosen.get_metadata(0)) < _shown.size():
		keep = str(_shown[int(chosen.get_metadata(0))]["item"])
	_shown = []
	var ready := 0
	for r in _rows:
		if str(r["status"]) == "ready":
			ready += 1
		if which == "all" or (str(r["status"]) == "ready") == (which == "can be had now"):
			_shown.append(r)
	_head.text = "%s  %s     %s" % [UI.c(UI.CYAN, UI.b("Crafting and gathering — %s" % _age)),
			UI.dim("%d items · %d can be had now · %d not yet" % [_rows.size(), ready, _rows.size() - ready]),
			UI.c(UI.YELLOW, "showing: %s" % which)]
	_tree.clear()
	var root := _tree.create_item()
	var select: TreeItem = null
	for i in range(_shown.size()):
		var r: Dictionary = _shown[i]
		var st: Array = STATUS.get(r["status"], ["?", UI.DIM])
		var it := _tree.create_item(root)
		it.set_metadata(0, i)
		it.set_text(0, str(st[0]))
		it.set_custom_color(0, st[1])
		it.set_text(1, str(r.get("icon", "")))
		it.set_text(2, str(r["name"]))
		it.set_text(3, str(r["kind"]))
		it.set_custom_color(3, UI.DIM)
		it.set_text(4, str(r.get("by", "")))
		var research: Array = r.get("research", [])
		var names: Array = []
		var missing := false
		for x in research:
			names.append(str(x["name"]))
			missing = missing or not x.get("done", false)
		it.set_text(5, ", ".join(PackedStringArray(names)) if not names.is_empty() else "—")
		it.set_custom_color(5, UI.DIM if names.is_empty() else (UI.RED if missing else UI.GREEN))
		it.set_text(6, str(r.get("takes", "")))
		it.set_text(7, str(int(r.get("store", 0))))
		it.set_custom_color(7, UI.DIM if int(r.get("store", 0)) == 0 else UI.TEXT)
		it.set_text(8, str(r.get("why", "")))
		it.set_custom_color(8, st[1])
		it.set_text(9, str(r.get("used_for", "")).replace("\n", "; "))
		it.set_custom_color(9, UI.CYAN if r.get("used", false) else UI.DIM)
		if str(r["item"]) == keep:
			select = it
	if select == null and root.get_child_count() > 0:
		select = root.get_child(0)
	if select != null:
		select.select(0)
		_show_detail(int(select.get_metadata(0)))
	else:
		_detail.text = ""


func _on_selected() -> void:
	var it := _tree.get_selected()
	if it != null:
		_show_detail(int(it.get_metadata(0)))


func _show_detail(i: int) -> void:
	if i < 0 or i >= _shown.size():
		return
	var t := ""
	for part in _shown[i].get("detail", []):
		var text := UI.esc(part[0])
		var style := str(part[1])
		if style == "bold":
			text = UI.b(text)
		elif style != "":
			text = UI.c(UI.style_color(style), text)
		t += text
	if _detail.text != t:
		_detail.text = t


func handle_key(key: InputEventKey) -> bool:
	if key.echo:
		return false
	if key.keycode == KEY_S:
		_filter = (_filter + 1) % FILTERS.size()
		_fill()
		return true
	if key.keycode == KEY_K:
		close()
		return true
	return false

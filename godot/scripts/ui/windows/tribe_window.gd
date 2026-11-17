class_name TribeWindow
extends GameWindow
## F2: everyone in the tribe as a card of meters, live. Arrows choose a member; Enter or a click opens
## their inventory (to ask them for something, give, or trade).

var _head: RichTextLabel
var _grid: GridContainer
var _scroll: ScrollContainer
var _cards: Array = []
var _selected := 0


func build() -> void:
	close_key = KEY_F2
	set_title(G.term("members"))
	set_hint("Arrows choose · Enter or a click opens their inventory · F2 or Esc closes · bars update live")
	_head = UI.rich(14)
	content.add_child(_head)
	_grid = GridContainer.new()
	_grid.columns = 3 if hud.root.size.x >= 2300 else 2
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	_scroll = UI.scroll(_grid)
	content.add_child(_scroll)
	var names: Array = []
	for p in G.players():
		names.append(p["name"])
	_selected = maxi(0, names.find(G.you()))


func _head_text() -> String:
	var players := G.players()
	var t := UI.dim("%d people" % players.size())
	var total := 0.0
	var kids := 0
	var ill: Array = []
	for p in players:
		total += float(p.get("mood", 50))
		var life: Dictionary = p.get("life") if p.get("life") is Dictionary else {}
		if life.get("child", false):
			kids += 1
		if life.get("illness") != null:
			ill.append(str(p["name"]))
	if not players.is_empty():
		var avg := total / players.size()
		t += UI.dim("   ·   average mood ") + UI.c(UI.level_color(avg), UI.b("%d" % int(round(avg))))
	if kids > 0:
		t += UI.dim("   ·   %d children" % kids)
	if not ill.is_empty():
		t += UI.c(UI.RED, UI.b("   ·   ill: %s" % ", ".join(PackedStringArray(ill))))
	var life: Dictionary = G.view.get("life", {})
	var bodies: Array = life.get("bodies", [])
	if not bodies.is_empty():
		var names: Array = []
		for b in bodies:
			names.append(str(b["name"]))
		t += UI.c(UI.RED, UI.b("   ·   %d dead lying in camp: %s (sickness spreads ×%s)" % [bodies.size(), ", ".join(PackedStringArray(names)), G.num(life.get("illness_factor", 1))]))
	t += UI.dim("   ·   born %d, died %d" % [int(life.get("births", 0)), int(life.get("deaths", 0))])
	t += "\n" + UI.dim("Stats: attributes (1-10) · Body: health and needs · Content: how satisfied they are (0-100) · Skills: their best (0-10)")
	return t


func refresh() -> void:
	_head.text = _head_text()
	var players := G.players()
	var same := players.size() == _cards.size()
	if same:
		for i in range(players.size()):
			if (_cards[i] as MemberCard).pname != str(players[i]["name"]):
				same = false
				break
	if not same:   # someone was born or has died
		for c in _cards:
			c.queue_free()
		_cards = []
		for p in players:
			var card := MemberCard.new()
			var who := str(p["name"])
			card.clicked.connect(func(): _open(who))
			_grid.add_child(card)
			_cards.append(card)
		_selected = clampi(_selected, 0, maxi(0, _cards.size() - 1))
	for i in range(players.size()):
		(_cards[i] as MemberCard).show_person(players[i], hud.world)
		(_cards[i] as MemberCard).set_selected(i == _selected)


func _open(who: String) -> void:
	for i in range(_cards.size()):
		if (_cards[i] as MemberCard).pname == who:
			_selected = i
	hud.open_window("inventory", who)


func handle_key(key: InputEventKey) -> bool:
	if _cards.is_empty():
		return false
	var step := 0
	match key.keycode:
		KEY_LEFT:
			step = -1
		KEY_RIGHT:
			step = 1
		KEY_UP:
			step = -_grid.columns
		KEY_DOWN:
			step = _grid.columns
		KEY_ENTER, KEY_KP_ENTER, KEY_I:
			if not key.echo:
				_open((_cards[_selected] as MemberCard).pname)
			return true
		_:
			return false
	if _selected + step >= 0 and _selected + step < _cards.size():
		_selected += step
		for i in range(_cards.size()):
			(_cards[i] as MemberCard).set_selected(i == _selected)
		_scroll.ensure_control_visible(_cards[_selected])
	return true

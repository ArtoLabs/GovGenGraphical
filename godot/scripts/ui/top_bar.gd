class_name TopBar
extends PanelContainer
## The bar along the top: the date and age, the sky, what the shared store holds, and the clock's pace.

signal menu_pressed
signal help_pressed

var _info: RichTextLabel
var _sky: RichTextLabel
var _store: RichTextLabel
var _dial: SkyDial
var _mode: Button
var _pause: Button
var _speeds: Array = []


class SkyDial extends Control:
	## A little wheel of the day: the sun (or the moon) goes round it.
	var phase := 0.3
	var dawn := 0.25
	var dusk := 0.75

	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5 - 1.0
		draw_circle(c, r, Color(0.10, 0.14, 0.30))
		# The lit half of the wheel is the day: from dawn to dusk, noon at the top.
		var a0 := (dawn - 0.25) * TAU + PI
		var a1 := (dusk - 0.25) * TAU + PI
		var pts := PackedVector2Array([c])
		for i in range(25):
			var a := lerpf(a0, a1, i / 24.0)
			pts.append(c + Vector2(cos(a), sin(a)) * r)
		draw_colored_polygon(pts, Color(0.45, 0.72, 0.95))
		draw_arc(c, r, 0.0, TAU, 32, UI.BORDER, 1.5, true)
		var a := (phase - 0.25) * TAU + PI
		var day := phase >= dawn and phase < dusk
		draw_circle(c + Vector2(cos(a), sin(a)) * (r - 6.0), 4.5, Color(1.0, 0.86, 0.3) if day else Color(0.92, 0.94, 1.0))


func _init() -> void:
	add_theme_stylebox_override("panel", UI.box(Color(0.045, 0.055, 0.075, 0.96), UI.BORDER, 0, 12, 1, 5))
	mouse_filter = Control.MOUSE_FILTER_STOP
	var h := UI.hbox(12)
	add_child(h)
	h.add_child(UI.label("GovGen", 20, UI.GOLD, true))
	_info = _line()
	h.add_child(_info)
	_dial = SkyDial.new()
	h.add_child(_dial)
	_sky = _line()
	h.add_child(_sky)
	_store = _line()
	h.add_child(_store)
	h.add_child(UI.spacer())
	_mode = UI.button("MANUAL", "M: you choose (manual), or the game plays you like any other member (auto)", 13)
	_mode.pressed.connect(func(): Net.send({"cmd": "auto", "on": not bool(G.ui.get("auto", false))}))
	h.add_child(_mode)
	_pause = UI.button("❚❚", "Space: pause or resume (you can still act while paused)", 14)
	_pause.custom_minimum_size = Vector2(40, 0)
	_pause.pressed.connect(func(): Net.send({"cmd": "pause"}))
	h.add_child(_pause)
	var speeds := UI.hbox(2)
	h.add_child(speeds)
	for value in G.defs.get("speeds", [1, 5, 20, 0]):
		var b := UI.button("max" if float(value) == 0.0 else "%sx" % G.num(value), "F5 steps through the speeds", 13)
		b.toggle_mode = true
		b.custom_minimum_size = Vector2(40, 0)
		var v := float(value)
		b.pressed.connect(func(): Net.send({"cmd": "speed", "value": v}))
		speeds.add_child(b)
		_speeds.append([v, b])
	var help := UI.button("?", "F1: how to play", 15)
	help.custom_minimum_size = Vector2(32, 0)
	help.pressed.connect(func(): help_pressed.emit())
	h.add_child(help)
	var menu := UI.button("☰", "Esc: menu (save and quit)", 15)
	menu.custom_minimum_size = Vector2(32, 0)
	menu.pressed.connect(func(): menu_pressed.emit())
	h.add_child(menu)


func _line() -> RichTextLabel:
	var r := UI.rich(15)
	r.autowrap_mode = TextServer.AUTOWRAP_OFF
	r.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func refresh() -> void:
	var v := G.view
	var sep := UI.c(UI.BORDER, "  │  ")
	var season_icon: String = {"Spring": "🌱", "Summer": "🌞", "Autumn": "🍂", "Winter": "❄"}.get(str(v.get("season", "")), "")
	_info.text = "%s %s%s%s%s%s" % [season_icon, UI.b(UI.esc(v.get("date", ""))), sep, UI.esc(v["age"]["name"]), sep,
			UI.c(UI.CYAN, UI.esc(v["government"]["name"]))]
	var w: Dictionary = v.get("world", {})
	_dial.phase = float(w.get("phase", 0.3))
	_dial.dawn = G.time_def("dawn", 0.25)
	_dial.dusk = G.time_def("dusk", 0.75)
	_dial.queue_redraw()
	var until := "dawn" if w.get("night", false) else "dusk"
	var fire := UI.c(UI.YELLOW, UI.b("🔥 %s°C" % G.num(w.get("fire_temperature")))) if w.get("fire", false) else UI.c(UI.RED, UI.b("no fire"))
	_sky.text = "%s %s  %s   air %s°C   %s" % [UI.b(str(w.get("time_of_day", ""))), UI.dim("to " + until),
			UI.c(UI.GOLD if not w.get("night", false) else UI.BLUE, UI.text_bar(1.0 - float(w.get("half_progress", 0)), 1.0, 6)), G.num(w.get("temperature")), fire]
	var parts: Array = []
	for g in G.ui.get("camp_line", []):
		var empty: bool = bool(g.get("empty_warning", false)) and int(g.get("count", 0)) == 0
		parts.append("[hint=%s]%s %s[/hint]" % [str(g.get("label", "")), g.get("icon", ""),
				UI.c(UI.RED if empty else UI.TEXT, UI.b(str(int(g.get("count", 0)))))])
	_store.text = sep + UI.dim(G.term("store").to_lower() + "  ") + "   ".join(PackedStringArray(parts)) if not parts.is_empty() else ""
	var pacer: Dictionary = G.ui.get("pacer", {})
	var paused := bool(pacer.get("paused", false))
	_pause.text = "▶" if paused else "❚❚"
	_pause.add_theme_color_override("font_color", UI.RED if paused else UI.TEXT)
	for pair in _speeds:
		(pair[1] as Button).set_pressed_no_signal(is_equal_approx(float(pacer.get("speed", 1)), pair[0]))
	var auto := bool(G.ui.get("auto", false))
	_mode.text = "AUTO" if auto else "MANUAL"
	_mode.add_theme_color_override("font_color", UI.MAGENTA if auto else UI.GREEN)
	_mode.add_theme_color_override("font_hover_color", UI.MAGENTA if auto else UI.GREEN)

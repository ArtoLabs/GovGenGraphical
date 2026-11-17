class_name UI
extends RefCounted
## The look of the game in one place: colours, fonts, the theme every panel uses, and small helpers for
## building labels, boxes and BBCode. Change a colour here and the whole HUD follows.

const PANEL := Color(0.066, 0.078, 0.105, 0.965)
const PANEL_SOLID := Color(0.075, 0.088, 0.118, 1.0)
const INSET := Color(0.11, 0.13, 0.17, 0.95)
const BORDER := Color(0.47, 0.40, 0.26)
const BORDER_DIM := Color(0.27, 0.29, 0.34)
const GOLD := Color(0.93, 0.78, 0.44)
const TEXT := Color(0.93, 0.91, 0.86)
const DIM := Color(0.60, 0.63, 0.68)
const GREEN := Color(0.44, 0.84, 0.45)
const YELLOW := Color(0.96, 0.79, 0.30)
const RED := Color(1.0, 0.42, 0.37)
const CYAN := Color(0.40, 0.82, 0.92)
const MAGENTA := Color(0.84, 0.55, 0.92)
const PURPLE := Color(0.66, 0.56, 0.98)
const BLUE := Color(0.36, 0.66, 1.0)
const ORANGE := Color(1.0, 0.62, 0.28)
const TRACK := Color(1, 1, 1, 0.09)
const SKILL := CYAN
const ATTRIBUTE := PURPLE

static var font: Font
static var bold: Font
static var _theme: Theme


static func theme() -> Theme:
	if _theme == null:
		_theme = _build_theme()
	return _theme


static func _build_theme() -> Theme:
	var fallbacks: Array[Font] = []
	var symbols := SystemFont.new()
	symbols.font_names = PackedStringArray(["DejaVu Sans", "Noto Sans Symbols2", "Segoe UI Symbol", "Apple Symbols", "sans-serif"])
	fallbacks.append(symbols)
	if ResourceLoader.exists("res://assets/fonts/NotoColorEmoji.ttf"):
		fallbacks.append(load("res://assets/fonts/NotoColorEmoji.ttf"))
	else:
		var emoji := SystemFont.new()
		emoji.font_names = PackedStringArray(["Noto Color Emoji", "Segoe UI Emoji", "Apple Color Emoji"])
		fallbacks.append(emoji)
	var regular := FontVariation.new()
	regular.base_font = ThemeDB.fallback_font
	regular.fallbacks = fallbacks
	font = regular
	var strong := FontVariation.new()
	strong.base_font = ThemeDB.fallback_font
	strong.variation_embolden = 0.7
	strong.fallbacks = fallbacks
	bold = strong

	var t := Theme.new()
	t.default_font = font
	t.default_font_size = 15
	t.set_color("font_color", "Label", TEXT)
	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_font("bold_font", "RichTextLabel", bold)
	t.set_font("normal_font", "RichTextLabel", font)
	t.set_font("italics_font", "RichTextLabel", font)
	t.set_font("bold_italics_font", "RichTextLabel", bold)
	t.set_constant("line_separation", "RichTextLabel", 2)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 6, 10, 1))
	t.set_stylebox("panel", "Panel", box(PANEL, BORDER, 6, 10, 1))

	t.set_stylebox("normal", "Button", box(Color(0.16, 0.19, 0.25, 0.95), BORDER_DIM, 5, 8, 1, 4))
	t.set_stylebox("hover", "Button", box(Color(0.22, 0.27, 0.35, 1.0), GOLD, 5, 8, 1, 4))
	t.set_stylebox("pressed", "Button", box(Color(0.30, 0.26, 0.15, 1.0), GOLD, 5, 8, 1, 4))
	t.set_stylebox("disabled", "Button", box(Color(0.11, 0.12, 0.15, 0.85), Color(0.2, 0.21, 0.24), 5, 8, 1, 4))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", GOLD)
	t.set_color("font_disabled_color", "Button", Color(0.45, 0.47, 0.5))

	t.set_stylebox("normal", "LineEdit", box(Color(0.05, 0.06, 0.08, 1.0), BORDER, 4, 8, 1, 5))
	t.set_stylebox("focus", "LineEdit", box(Color(0.05, 0.06, 0.08, 1.0), GOLD, 4, 8, 1, 5))
	t.set_color("font_color", "LineEdit", TEXT)

	for bar in ["VScrollBar", "HScrollBar"]:
		t.set_stylebox("scroll", bar, box(Color(1, 1, 1, 0.04), Color.TRANSPARENT, 4, 3, 0, 3))
		t.set_stylebox("grabber", bar, box(Color(0.47, 0.40, 0.26, 0.8), Color.TRANSPARENT, 4, 3, 0, 3))
		t.set_stylebox("grabber_highlight", bar, box(GOLD, Color.TRANSPARENT, 4, 3, 0, 3))
		t.set_stylebox("grabber_pressed", bar, box(GOLD, Color.TRANSPARENT, 4, 3, 0, 3))

	t.set_stylebox("panel", "Tree", box(Color(0.05, 0.06, 0.08, 0.6), BORDER_DIM, 4, 4, 1))
	t.set_stylebox("focus", "Tree", StyleBoxEmpty.new())
	t.set_stylebox("selected", "Tree", box(Color(0.30, 0.26, 0.15, 0.9), Color.TRANSPARENT, 3, 2, 0))
	t.set_stylebox("selected_focus", "Tree", box(Color(0.36, 0.31, 0.17, 1.0), Color.TRANSPARENT, 3, 2, 0))
	t.set_stylebox("title_button_normal", "Tree", box(Color(0.13, 0.15, 0.20, 1.0), BORDER_DIM, 0, 6, 1, 4))
	t.set_stylebox("title_button_hover", "Tree", box(Color(0.13, 0.15, 0.20, 1.0), BORDER_DIM, 0, 6, 1, 4))
	t.set_stylebox("title_button_pressed", "Tree", box(Color(0.13, 0.15, 0.20, 1.0), BORDER_DIM, 0, 6, 1, 4))
	t.set_color("font_color", "Tree", TEXT)
	t.set_color("title_button_color", "Tree", GOLD)
	t.set_color("guide_color", "Tree", Color(1, 1, 1, 0.05))
	t.set_constant("v_separation", "Tree", 5)
	t.set_constant("h_separation", "Tree", 8)
	t.set_constant("draw_guides", "Tree", 1)

	t.set_stylebox("panel", "TooltipPanel", box(Color(0.04, 0.05, 0.07, 0.97), GOLD, 5, 8, 1, 6))
	t.set_color("font_color", "TooltipLabel", TEXT)
	t.set_font_size("font_size", "TooltipLabel", 14)
	t.set_stylebox("panel", "PopupPanel", box(PANEL_SOLID, GOLD, 6, 10, 1))
	t.set_constant("separation", "VBoxContainer", 4)
	t.set_constant("separation", "HBoxContainer", 6)
	t.set_constant("h_separation", "HFlowContainer", 6)
	t.set_constant("v_separation", "HFlowContainer", 6)
	return t


static func box(bg: Color, border: Color = Color.TRANSPARENT, radius: int = 6, margin_h: int = 8,
		border_width: int = 1, margin_v: int = -1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width if border.a > 0.0 else 0)
	s.set_corner_radius_all(radius)
	s.content_margin_left = margin_h
	s.content_margin_right = margin_h
	s.content_margin_top = margin_v if margin_v >= 0 else margin_h * 0.7
	s.content_margin_bottom = margin_v if margin_v >= 0 else margin_h * 0.7
	s.anti_aliasing = true
	return s


static func label(text: String = "", size: int = 15, color: Color = TEXT, strong: bool = false) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if strong:
		l.add_theme_font_override("font", bold)
	return l


static func rich(size: int = 15, fit: bool = true) -> RichTextLabel:
	## A BBCode label that grows to fit its text (or scrolls, with fit = false).
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = fit
	r.scroll_active = not fit
	r.selection_enabled = false
	r.mouse_filter = Control.MOUSE_FILTER_PASS
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	for n in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		r.add_theme_font_size_override(n, size)
	return r


static func hbox(sep: int = 6) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", sep)
	return h


static func vbox(sep: int = 4) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	return v


static func spacer(expand: bool = true, min_size: Vector2 = Vector2.ZERO) -> Control:
	var s := Control.new()
	s.custom_minimum_size = min_size
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if expand:
		s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return s


static func margin(child: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(child)
	return m


static func scroll(child: Control, horizontal: bool = false) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if horizontal else ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.add_child(child)
	return s


static func button(text: String, tip: String = "", size: int = 15) -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", size)
	return b


# --------------------------------------------------------------------------- #
# BBCode
# --------------------------------------------------------------------------- #
static func esc(text) -> String:
	return str(text).replace("[", "[lb]")


static func c(color: Color, text) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), str(text)]


static func b(text) -> String:
	return "[b]%s[/b]" % str(text)


static func i(text) -> String:
	return "[i]%s[/i]" % str(text)


static func dim(text) -> String:
	return c(DIM, text)


static func tag(text: String, bg: Color, fg: Color = Color(0.05, 0.05, 0.05)) -> String:
	return "[bgcolor=#%s][color=#%s][b] %s [/b][/color][/bgcolor]" % [bg.to_html(false), fg.to_html(false), esc(text)]


static func text_bar(done: float, total: float, width: int = 12) -> String:
	var filled := 0
	if total > 0.0:
		filled = clampi(int(round(width * done / total)), 0, width)
	return "█".repeat(filled) + c(Color(0.24, 0.26, 0.31), "█".repeat(width - filled))


# --------------------------------------------------------------------------- #
# Colours with a meaning
# --------------------------------------------------------------------------- #
static func level_color(value: float) -> Color:
	## For a 0-100 value where higher is better (contentment, quality, mood).
	return GREEN if value >= 65.0 else (YELLOW if value >= 45.0 else RED)


static func need_color(value: float, critical: bool) -> Color:
	return RED if critical or value < 25.0 else (YELLOW if value < 50.0 else GREEN)


static func style_color(style: String) -> Color:
	## The engine names colours as the text HUD did ('bold red', 'dim', 'green'...).
	if style.contains("red"):
		return RED
	if style.contains("green"):
		return GREEN
	if style.contains("yellow"):
		return YELLOW
	if style.contains("magenta"):
		return MAGENTA
	if style.contains("cyan"):
		return CYAN
	if style.contains("dim"):
		return DIM
	return TEXT


static func alert_color(level: String) -> Color:
	match level:
		"action":
			return GREEN
		"urgent":
			return RED
		"done":
			return CYAN
	return TEXT

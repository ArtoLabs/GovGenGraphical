class_name Toasts
extends VBoxContainer
## News that should not be missed slides in under the top bar and fades by itself: a death, a birth,
## what a Scout found, a ballot that needs you.

const MOST := 5


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER


func show_toast(title: String, text: String, colour: Color, seconds: float = 7.0) -> void:
	while get_child_count() >= MOST:
		var old := get_child(0)
		remove_child(old)
		old.queue_free()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.box(Color(0.05, 0.06, 0.08, 0.95), colour, 6, 12, 2, 8))
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size = Vector2(520, 0)
	var r := UI.rich(14)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.text = "%s\n%s" % [UI.c(colour, UI.b(UI.esc(title))), UI.esc(text)]
	panel.add_child(r)
	add_child(panel)
	panel.modulate.a = 0.0
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(seconds)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)

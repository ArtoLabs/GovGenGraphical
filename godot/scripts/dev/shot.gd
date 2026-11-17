extends Node
## A helper for checking the game without a person at the keyboard: runs a little script of steps and
## saves pictures of the screen. It does nothing unless asked on the command line:
##
##   godot --path godot -- --shots=/tmp/out "--script=state;wait:3;shot:main;key:F2;wait:1;shot:tribe;quit"
##
## Steps: wait:<seconds>  state (wait for the first view)  shot:<name>  key:<F2|W|Escape...>
##        click:<x>,<y>  wheel:<up|down>  call:<method of Main>[:argument]  quit

var _steps: PackedStringArray = []
var _at := 0
var _out := ""
var _wait := 0.0
var _busy := false
var _patience := 0.0
var active := false


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shots="):
			_out = a.substr(8)
		elif a.begins_with("--script="):
			_steps = a.substr(9).split(";", false)
	if _out == "":
		set_process(false)
		return
	active = true
	DirAccess.make_dir_recursive_absolute(_out)
	process_mode = Node.PROCESS_MODE_ALWAYS


func _process(delta: float) -> void:
	if _busy:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	if _at >= _steps.size():
		set_process(false)
		var main_node := get_tree().root.get_node_or_null("Main")
		if main_node != null and main_node.has_method("request_quit"):
			main_node.call("request_quit")
		else:
			get_tree().quit()
		return
	var step := _steps[_at]
	var parts := step.split(":", true, 1)
	var arg := parts[1] if parts.size() > 1 else ""
	match parts[0]:
		"wait":
			_wait = float(arg)
		"state":
			_patience += delta
			if not G.has_view() and _patience < 40.0:
				_wait = 0.2
				return
		"shot":
			_busy = true
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(_out.path_join(arg + ".png"))
			_busy = false
		"key":
			_key(arg)
		"click":
			var xy := arg.split(",")
			_click(Vector2(float(xy[0]), float(xy[1])), MOUSE_BUTTON_LEFT)
		"rclick":
			var xy := arg.split(",")
			_click(Vector2(float(xy[0]), float(xy[1])), MOUSE_BUTTON_RIGHT)
		"wheel":
			var ev := InputEventMouseButton.new()
			ev.button_index = MOUSE_BUTTON_WHEEL_UP if arg == "up" else MOUSE_BUTTON_WHEEL_DOWN
			ev.pressed = true
			ev.position = get_viewport().get_visible_rect().size * 0.5
			ev.global_position = ev.position
			Input.parse_input_event(ev)
		"call":
			var bits := arg.split(":", true, 1)
			var main := get_tree().root.get_node_or_null("Main")
			if main != null and main.has_method(bits[0]):
				if bits.size() > 1:
					main.call(bits[0], bits[1])
				else:
					main.call(bits[0])
		"fps":
			print("FPS %d  (%s)" % [Engine.get_frames_per_second(), arg])
		"quit":
			_at = _steps.size()
			return
	_at += 1


func _key(key_name: String) -> void:
	var code := OS.find_keycode_from_string(key_name)
	for pressed in [true, false]:
		var ev := InputEventKey.new()
		ev.keycode = code
		ev.physical_keycode = code
		ev.pressed = pressed
		if key_name.length() == 1:
			ev.unicode = key_name.to_lower().unicode_at(0)
		Input.parse_input_event(ev)


func _click(at: Vector2, button: MouseButton) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	Input.parse_input_event(move)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = button
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		Input.parse_input_event(ev)

extends Node
## The line to the game: starts the Python engine (bridge/server.py) and talks to it over a local socket,
## one JSON object per line. Nothing else in the client knows there is a socket.
##
## Where things are found (each can be overridden with an environment variable):
##   GOVGEN_ENGINE_DIR  the folder holding bridge/server.py (default: the folder above this project)
##   GOVGEN_PYTHON      the Python to run it with (default: a venv next to the engine, else python3)
##   GOVGEN_CONNECT     host:port of a server that is already running (then none is started)
##   GOVGEN_SAVE_FILE   another save file than the engine's saves/savegame.json

signal message(msg: Dictionary)
signal online
signal offline(reason: String)

enum { IDLE, LAUNCHING, CONNECTING, ONLINE, CLOSED }

var state := IDLE
var problem := ""
var pid := -1
var _tcp := StreamPeerTCP.new()
var _buffer := PackedByteArray()
var _port_file := ""
var _waited := 0.0
var _host := "127.0.0.1"
var _port := 0
var _said_bye := false


func engine_dir() -> String:
	var env := OS.get_environment("GOVGEN_ENGINE_DIR")
	if env != "":
		return env
	var here := ProjectSettings.globalize_path("res://").trim_suffix("/")
	var tries := [here.get_base_dir(), here, OS.get_executable_path().get_base_dir(),
			OS.get_executable_path().get_base_dir().get_base_dir()]
	for d in tries:
		if FileAccess.file_exists(d.path_join("bridge/server.py")):
			return d
	return here.get_base_dir()


func python_path() -> String:
	var env := OS.get_environment("GOVGEN_PYTHON")
	if env != "":
		return env
	var e := engine_dir()
	var tries := []
	for base in [e.get_base_dir(), e]:
		for venv in ["venv", ".venv"]:
			tries.append(base.path_join(venv).path_join("bin/python"))
			tries.append(base.path_join(venv).path_join("Scripts/python.exe"))
	for p in tries:
		if FileAccess.file_exists(p):
			return p
	return "python" if OS.get_name() == "Windows" else "python3"


func launch() -> void:
	## Start the engine (or connect to the one named by GOVGEN_CONNECT) and say `online` once it answers.
	if state == LAUNCHING or state == CONNECTING or state == ONLINE:
		return
	problem = ""
	_said_bye = false
	_buffer = PackedByteArray()
	_tcp = StreamPeerTCP.new()
	_waited = 0.0
	var direct := OS.get_environment("GOVGEN_CONNECT")
	if direct != "":
		var parts := direct.split(":")
		_host = parts[0] if parts[0] != "" else "127.0.0.1"
		_port = int(parts[1]) if parts.size() > 1 else 47800
		_begin_connect()
		return
	var script := engine_dir().path_join("bridge/server.py")
	if not FileAccess.file_exists(script):
		_fail("The game engine was not found: there is no bridge/server.py in %s. Set GOVGEN_ENGINE_DIR to the GovGen folder." % engine_dir())
		return
	_port_file = OS.get_user_data_dir().path_join("server_port_%d.txt" % OS.get_process_id())
	if FileAccess.file_exists(_port_file):
		DirAccess.remove_absolute(_port_file)
	var args := PackedStringArray([script, "--port", "0", "--port-file", _port_file])
	var save := OS.get_environment("GOVGEN_SAVE_FILE")
	if save != "":
		args.append_array(PackedStringArray(["--save-file", save]))
	pid = OS.create_process(python_path(), args)
	if pid <= 0:
		_fail("Python could not be started (%s). Set GOVGEN_PYTHON to your Python 3." % python_path())
		return
	state = LAUNCHING


func send(data: Dictionary) -> void:
	if state != ONLINE:
		return
	_tcp.put_data((JSON.stringify(data) + "\n").to_utf8_buffer())


func close() -> void:
	## Drop the line (the engine saves and stops when its client leaves).
	if state == ONLINE or state == CONNECTING:
		_tcp.disconnect_from_host()
	state = CLOSED


func kill_engine() -> void:
	if pid > 0 and OS.is_process_running(pid):
		OS.kill(pid)
	pid = -1


func _fail(text: String) -> void:
	problem = text
	state = CLOSED
	offline.emit(text)


func _begin_connect() -> void:
	_tcp = StreamPeerTCP.new()
	var err := _tcp.connect_to_host(_host, _port)
	if err != OK:
		_fail("Could not reach the game engine on %s:%d." % [_host, _port])
		return
	state = CONNECTING


func _process(delta: float) -> void:
	match state:
		LAUNCHING:
			_waited += delta
			if FileAccess.file_exists(_port_file):
				var text := FileAccess.get_file_as_string(_port_file).strip_edges()
				if text.is_valid_int():
					_port = int(text)
					_host = "127.0.0.1"
					_begin_connect()
					return
			if pid > 0 and not OS.is_process_running(pid):
				_fail("The game engine stopped as soon as it started. Try it by hand to see why:\n%s %s" % [python_path(), engine_dir().path_join("bridge/server.py")])
			elif _waited > 30.0:
				_fail("The game engine did not answer within 30 seconds.")
		CONNECTING:
			_tcp.poll()
			var s := _tcp.get_status()
			if s == StreamPeerTCP.STATUS_CONNECTED:
				_tcp.set_no_delay(true)
				state = ONLINE
				online.emit()
			elif s == StreamPeerTCP.STATUS_ERROR or s == StreamPeerTCP.STATUS_NONE:
				_fail("Could not reach the game engine on %s:%d." % [_host, _port])
		ONLINE:
			_tcp.poll()
			var s := _tcp.get_status()
			if s != StreamPeerTCP.STATUS_CONNECTED:
				state = CLOSED
				if not _said_bye:
					offline.emit("The line to the game engine dropped.")
				return
			var n := _tcp.get_available_bytes()
			if n > 0:
				var got := _tcp.get_data(n)
				if got[0] == OK:
					_buffer.append_array(got[1])
					_split_lines()


func _split_lines() -> void:
	var start := 0
	while true:
		var end := _buffer.find(10, start)
		if end < 0:
			break
		var line := _buffer.slice(start, end).get_string_from_utf8()
		start = end + 1
		if line.strip_edges() == "":
			continue
		var parsed = JSON.parse_string(line)
		if parsed is Dictionary:
			if parsed.get("type", "") == "bye":
				_said_bye = true
			message.emit(parsed)
	if start > 0:
		_buffer = _buffer.slice(start)

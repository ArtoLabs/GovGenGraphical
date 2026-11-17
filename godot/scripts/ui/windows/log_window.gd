class_name LogWindow
extends GameWindow
## F7: the whole chronicle so far, at the level of detail chosen with F6.

const MOST := 2500

var _log: RichTextLabel


func build() -> void:
	close_key = KEY_F7
	set_title("Chronicle")
	set_hint("showing %s · wheel or PgUp PgDn scroll · F7 or Esc closes" % G.defs.get("detail_levels", {}).get(G.ui.get("detail", "full"), ""))
	_log = UI.rich(14, false)
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.focus_mode = Control.FOCUS_ALL
	content.add_child(_log)
	var detail := str(G.ui.get("detail", "full"))
	var lines: Array = []
	for i in range(G.history.size() - 1, -1, -1):
		var text := ChroniclePanel.line(G.history[i], detail)
		if text != "":
			lines.append(text)
			if lines.size() >= MOST:
				break
	lines.reverse()
	_log.text = "\n".join(PackedStringArray(lines))
	_log.grab_focus.call_deferred()


func hear(items: Array) -> void:
	var detail := str(G.ui.get("detail", "full"))
	for m in items:
		var text := ChroniclePanel.line(m, detail)
		if text != "":
			_log.append_text("\n" + text)

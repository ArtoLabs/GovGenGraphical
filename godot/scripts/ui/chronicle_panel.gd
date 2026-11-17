class_name ChroniclePanel
extends TitledPanel
## Bottom left: the latest things that happened (F7 shows all of it, F6 changes how much is told).

const KEEP := 250

var _log: RichTextLabel
var _shown := 0


func _init() -> void:
	super("Chronicle", "F7 all · F6 detail")
	_log = UI.rich(13, false)
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.custom_minimum_size = Vector2(0, 150)
	body.add_child(_log)


static func line(m: Dictionary, detail: String) -> String:
	## One chronicle entry as BBCode, or "" if it is hidden at this level of detail.
	if detail == "summary" and not m.get("important", true):
		return ""
	if detail == "politics" and str(m.get("category", "")) == "life":
		return ""
	if m.get("header", false):
		return UI.c(UI.CYAN, UI.b(UI.esc(m["text"])))
	var t := ""
	if str(m.get("date", "")) != "":
		t += UI.dim(str(m["date"]) + " ")
	var text := UI.esc(m["text"])
	if m.get("important", true):
		t += UI.c(UI.YELLOW, text)
	elif str(m.get("category", "")) == "life":
		t += UI.c(UI.GREEN.darkened(0.15), text)
	else:
		t += text
	if detail == "full" and m.get("reason") != null and str(m.get("reason")) != "":
		t += "\n" + UI.dim(UI.i("   (%s)" % UI.esc(m["reason"])))
	return t


func add(items: Array) -> void:
	var detail := str(G.ui.get("detail", "full"))
	for m in items:
		var text := line(m, detail)
		if text != "":
			_log.append_text(text + "\n")
			_shown += 1
	if _shown > KEEP * 2:
		rebuild()


func rebuild() -> void:
	_log.clear()
	_shown = 0
	var detail := str(G.ui.get("detail", "full"))
	var lines: Array = []
	for i in range(G.history.size() - 1, -1, -1):
		var text := line(G.history[i], detail)
		if text != "":
			lines.append(text)
			if lines.size() >= KEEP:
				break
	lines.reverse()
	for text in lines:
		_log.append_text(text + "\n")
	_shown = lines.size()

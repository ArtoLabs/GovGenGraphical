class_name MenuWindow
extends GameWindow
## Esc on the main screen: the game's own menu.


func _init() -> void:
	super()
	wide = false
	dialog_width = 420.0


func build() -> void:
	set_title("GovGen")
	set_hint("")
	var note := UI.label("The game keeps running while this is open. Space pauses it.", 13, UI.DIM)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(note)
	for entry in [["Back to the game", "", "resume"], ["How to play  (F1)", "", "help"],
			["Pause or resume  (Space)", "", "pause"], ["Full screen  (F11)", "", "fullscreen"],
			["Save and quit  (F10)", "The game is saved; you go on from here next time", "quit"]]:
		var b := UI.button(str(entry[0]), str(entry[1]), 17)
		b.custom_minimum_size = Vector2(0, 44)
		var what := str(entry[2])
		b.pressed.connect(func(): _do(what))
		content.add_child(b)


func _do(what: String) -> void:
	close()
	match what:
		"help":
			hud.open_window("help")
		"resume":
			pass
		_:
			hud.command(what)

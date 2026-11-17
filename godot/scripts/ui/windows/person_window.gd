class_name PersonWindow
extends GameWindow
## Someone you clicked on the map or in the tribe list: their card, live, and what you can do about them.

var pname := ""
var _card: MemberCard


func _init() -> void:
	super()
	wide = false
	dialog_width = 900.0


func build() -> void:
	set_title(pname)
	_card = MemberCard.new()
	content.add_child(_card)
	var row := UI.hbox(8)
	content.add_child(row)
	var inv := UI.button("🎒 Inventory" if pname == G.you() else "🎒 Their inventory: ask, give, trade", "", 14)
	inv.pressed.connect(func():
		var who := pname
		close()
		hud.open_window("inventory", who))
	row.add_child(inv)
	var go := UI.button("Follow on the map", "Keep the view on them until you move the map", 14)
	go.pressed.connect(func():
		hud.world.find_person(pname)
		close())
	row.add_child(go)
	if pname == G.you():
		var sheet := UI.button("Character sheet (F8)", "", 14)
		sheet.pressed.connect(func():
			close()
			hud.open_window("character"))
		row.add_child(sheet)


func refresh() -> void:
	var p := G.player(pname)
	if p.is_empty():
		close()   # they have died
		return
	_card.show_person(p, hud.world)
	fit.call_deferred()

class_name HelpWindow
extends GameWindow
## F1: how to play.


func build() -> void:
	close_key = KEY_F1
	set_title("How to play")
	set_hint("wheel or PgUp PgDn scroll · F1 or Esc closes")
	var r := UI.rich(15, false)
	r.size_flags_vertical = Control.SIZE_EXPAND_FILL
	r.focus_mode = Control.FOCUS_ALL
	r.text = _text()
	content.add_child(r)
	r.grab_focus.call_deferred()


func _h(text: String) -> String:
	return "\n" + UI.c(UI.GOLD, UI.b(text)) + "\n"


func _keys(rows: Array) -> String:
	var t := "[table=2]"
	for row in rows:
		t += "[cell padding=12,1,16,1]%s[/cell][cell]%s[/cell]" % [UI.c(UI.GREEN, UI.b(str(row[0]))), str(row[1])]
	return t + "[/table]\n"


func _text() -> String:
	var home := G.term("home")
	var t := ""
	t += "The game runs in real time. The clock never waits for you: other members of the tribe act, ballots open and close, " \
		+ "and research advances while you think. Every action keeps you busy for a while (the picker says how long). Politics runs " \
		+ "on days and work on hours, so while you are out working, crafting, resting or eating you can still vote, nominate, " \
		+ "appoint, persuade or challenge without stopping; only keys you can't use right now are greyed out.\n"
	t += _h("The screen")
	t += "The world fills the screen and runs on behind the panels at the edges. Top left is you: who you are, your office and " \
		+ "work, what you are doing, your body's meters, and one bar each for Ability (how well you do your job now), Skills (the " \
		+ "average of all your skills) and Mood (the average of your contentment); F8 has the rest. Bottom left is the chronicle's " \
		+ "latest lines (F7: all of it). Right: the tribe, the places found, and the small map. Along the bottom: the government, " \
		+ "open votes and contests, and the innovation pool. The box of actions and keys sits over the bottom of the map; Tab shows " \
		+ "or hides it, and the keys work either way. News that matters slides in under the top bar.\n"
	t += _h("The world")
	t += "Plains, forest and deep forest, hills, mountains and snowy peaks, marsh, beach, rivers and sea. Drag the map with the " \
		+ "mouse or use the arrow keys (Shift: faster); the wheel or + and - zoom; Home goes back to the %s, End finds you and " % home \
		+ "follows you until you move the map. Click the small map to jump anywhere. Click a tile to hear what and who is there. " \
		+ "Click a person to go to them; click them again (or twice in the tribe list) for their card.\n" \
		+ "The %s lies around its fire, inside the ring of trodden earth: the store, the workshop where things are made, the " % home \
		+ "council ground with its standing stone, and a sleeping mat for everyone. At night the fire lights the %s (if it is " % home \
		+ "burning). The land turns with the seasons, and in winter snow lies on it.\n" \
		+ "People walk to wherever a thing is done, and the walk takes time: a Gatherer walks to the woods or the river and back " \
		+ "to the store, so how long they are gone depends on how far it is. Sleeping happens on one's own mat, eating and " \
		+ "warming up beside the fire, crafting at the workshop, an office's work at the council ground. The store can only be " \
		+ "used in the %s. Voting, nominating, appointing and persuading take no walking. An icon over someone's head says what " % home \
		+ "they are doing; badges mark the places Scouts have found, with the trips left in each.\n"
	t += _h("The tribe list")
	t += "One line each: a dot for mood (green content, red unhappy), name, work, office, then what they are doing (yellow: busy " \
		+ "now; dim: their last deed, or at home). A red icon is a need gone critical; 🤒 ill, 🤰 with child, 🧒 a child, ✗ cannot " \
		+ "vote, 💀 dead and not yet laid to rest. F2 shows everyone in full, F9 the society.\n"
	t += _h("Actions (letters, or click the keycaps)")
	t += _keys([
		["V", "Vote on an open ballot"],
		["N", "Nominate a candidate (one election at a time each), or decline your own nomination"],
		["A", "Appoint someone to a position you control"],
		["D", "Dismiss someone from a position you control, or release them from an appointment"],
		["C", "Call a vote: remove an office holder, grant or lift a status"],
		["F", "Reform the government into another form of the same age (by decree or by calling a vote); a new age changes the government by itself"],
		["R", "Queue an innovation for research (one of your roles must be able to)"],
		["O", "Give an order from one of your roles (propose a law, levy a tax...)"],
		["E", "Look after yourself: eat, drink, sleep, warm up by the fire, see the healer"],
		["W", "Work: do your job's work (forage, hunt, tend the fire, patrol, lead a ritual, see to your office...) or craft tools. Children play and study instead. Your Work contentment rises only while you work your job"],
		["J", "Job: volunteer for open work (Gatherer, Firekeeper...) or give up your job"],
		["X", "Wake up, or stop resting or warming up early"],
		["P", "Persuade: campaign for an office, win people over, rally them against a rival, or speak in an oration"],
		["H", "Challenge an office holder (they choose the contest), or choose yours when challenged"],
		["G", "Resign from an office you hold"],
		["I", "Inventory: move, split, sort, use, drop and pick up items, give and trade. Handling items takes no time, but not while asleep"],
	])
	t += "In a picker: press the key shown, use ↑↓ and Enter, or click. Esc goes back.\n"
	t += _h("Living off the land")
	t += "Food and water come only from work. Gatherers forage and fetch water (only they do); what they bring back goes to the " \
		+ "%s, and every meal and drink uses it up (your own pack first). With nothing to eat or drink, people go hungry " % G.term("store_name") \
		+ "and thirsty and lose health; at no health they die. In winter warmth falls fast (very fast with no fire) and freezing " \
		+ "drains health: resting by the fire only keeps the cold off, so warm up by it (E). The fire burns wood: the Firekeeper " \
		+ "must keep feeding it. Most jobs open only through research (Toolmaking, Hunting, Fishing, Tracking, Herbalism, Camp " \
		+ "Defense...). Some work needs a tool: you can be appointed before one exists, and take one from the store the moment the " \
		+ "Toolmaker makes it. The top bar counts what the store holds. F12 (or K) shows everything that can be made or found and " \
		+ "what it takes.\n" \
		+ "Trips out (foraging, wood, stone, hunting, fishing, herbs) often come back empty. A Scout brings nothing back but " \
		+ "chooses what to look for and usually finds it: a found place holds several trips' worth, and every trip of that kind " \
		+ "goes there and pays off for certain until it is used up. Unused places are lost after a while.\n"
	t += _h("Life and death")
	t += "People are born, grow up, fall ill and die. Anyone may fall ill, the old far more often, and hard work makes it " \
		+ "likelier. While ill your health drains; at nothing you die. Only a healer can cure it: press E, See the healer. Health " \
		+ "comes back otherwise only while you rest, not while you work. The dead lie in the %s until someone carries them away, " % home \
		+ "burns or buries them (W); while they lie there, sickness spreads. Now and then a woman becomes pregnant; she can't work " \
		+ "for the last three months, then a baby joins the tribe. Children don't work until 9: they play and study (W), and what " \
		+ "they choose sets their attributes. They vote and hold office from 14. If you die, you play on as your eldest child (or " \
		+ "else the youngest adult).\n"
	t += _h("Hiring and firing")
	t += "A leader may appoint and dismiss as often as they like. Moving someone to other work costs only a little of their " \
		+ "contentment; a step up pleases, a step down sours. Dismissing someone outright hurts: their Work and Leaders contentment " \
		+ "drops at once and stays low for a while, and the rest of the tribe is unsettled too. An unhappy tribe gives its leaders " \
		+ "time: people grumble first, and only when their patience runs out (the chronicle warns you; F9 shows everyone's) do they " \
		+ "campaign, challenge or vote them out.\n"
	t += _h("Screens and controls")
	t += _keys([
		["F1", "This help"],
		["F2", "Tribe: everyone as a card of meters; arrows choose a member, Enter or a click opens their inventory"],
		["F3", "Government: who is how far persuaded in running campaigns, offices, statuses, work and possible reforms"],
		["F4", "Innovations of the current age: status and what each needs; Enter queues research"],
		["F5", "Change the speed of the clock (or click a speed in the top bar)"],
		["Space", "Pause or resume (you can still act)"],
		["F6", "Chronicle detail: everything / no everyday life / important only"],
		["F7", "The whole chronicle"],
		["F8", "Your character sheet: attributes, roles and ability, body, contentment, every skill"],
		["F9", "Society: how well the tribe works and how content everyone is"],
		["F10", "Save and quit (also Ctrl+Q, or the menu on Esc)"],
		["F11", "Full screen"],
		["F12 / K", "Crafting chart: every item that can be made or found in this age and what it takes"],
		["M", "Auto / manual: on auto the game plays your character exactly like an NPC; M again gives you back control"],
		["Tab", "Show or hide the box of actions and keys"],
		["←↑↓→", "Move the map (Shift: faster); or drag it with the mouse"],
		["+  -", "Zoom in and out (or the mouse wheel)"],
		["Home / End", "Back to the %s / find yourself and follow" % home],
	])
	return t

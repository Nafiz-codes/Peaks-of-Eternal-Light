extends CanvasLayer
signal finished
const LINE := "Welcome, Commander! I'm Dr. Maya Chen, your flight engineer and instructor. I'll guide you through the equipment, scientific data, and mission procedures."
const INTRODUCTIONS := {
 "crew_briefing": {"speaker": "Dr. Maya Chen", "text": LINE},
 "water_recycler": {"speaker": "Dr. Alex Rivera", "text": "Dr. Alex Rivera, planetary geologist. I'm here to help us understand the Moon's terrain, history, and potential resources."},
 "food_storage": {"speaker": "Sam Okafor", "text": "And I'm Sam Okafor, robotics and habitat engineer. Give me the equipment, and I'll help turn it into a functioning base."},
 "storm_damage": {"speaker": "Dr. Maya Chen", "text": "Commander, the dust storm damaged some of our structures. Walk up to a marked one and press E to repair it, or talk to me if you decide to leave them. Unrepaired, they will give us far less."},
 "radiation_alert": {"speaker": "Dr. Maya Chen", "text": "Commander, a solar radiation wave is about to hit the base! Talk to each of us, me included, and order us into the radiation shielding habitat before it arrives."},
 "radiation_no_shelter": {"speaker": "Dr. Maya Chen", "text": "Commander, a solar radiation wave is about to hit the base, and we have no radiation shielding habitat to hide in. Brace yourselves: the crew will need treatment afterwards."},
 "radiation_order_crew_briefing": {"speaker": "Dr. Maya Chen", "text": "Understood, Commander. Heading into the shelter now."},
 "radiation_order_water_recycler": {"speaker": "Dr. Alex Rivera", "text": "On my way to the radiation habitat, Commander."},
 "radiation_order_food_storage": {"speaker": "Sam Okafor", "text": "Securing my tools and heading for the shelter, Commander."},
 "mission_review": {"speaker": "Dr. Maya Chen", "text": "Commander, the days we were scheduled to run this base are complete. Now we check whether we've done enough for it to be the stepping stone for humanity's first Moon base. Running the resource check now."},
 "mission_ready": {"speaker": "Dr. Maya Chen", "text": "Power, water, oxygen and food are all in good shape. It's confirmed, Commander: this outpost is ready to become humanity's first Moon base."},
 "mission_short": {"speaker": "Dr. Maya Chen", "text": "Not yet, Commander."},
 "redirect_food_storage": {"speaker": "Dr. Maya Chen", "text": "Sam wanted a word with you, Commander. You'll find him at his work area."},
 "redirect_water_recycler": {"speaker": "Dr. Maya Chen", "text": "Alex has something to discuss with you, Commander. Go and find him."},
}
const SEQUENCES := {
	# Before the final operation: how little time is left, what is still short, then Alex.
	"storm_lost_contact": [
		["crew_briefing", "serious", "Commander, two things, and neither can wait. First: our mission window is almost over. After the next operation, I run the final resource check."],
		["crew_briefing", "concerned", "{shortfall}"],
		["player", "questioning", "And the second thing?"],
		["crew_briefing", "concerned", "We've lost contact with Alex. He went out to check a reading before the storm and hasn't reported back. Take the rover to his last known location and bring him home."]
	],
	"maya_closing": [
		["crew_briefing", "neutral", "We all have our specialties, Commander. But you'll be making the final decisions."],
		["crew_briefing", "neutral", "Before we send anyone farther out, we need reliable power. Your first solar panel is free, so let's put it to good use. Choose a location with as little shadow as possible."],
		["player", "questioning", "And after we have power?"],
		["crew_briefing", "confident", "Build my Operations station. From there, I can monitor our systems, assess routes, and coordinate the crew. We'll expand the outpost as the mission demands it."]
	],
	"maya_radiation_prep": [
		["crew_briefing", "smiling", "Good work, Commander. We've mapped our first survey locations. But operating a lunar base means preparing for dangers we can't always see coming."],
		["player", "questioning", "What should we prepare for?"],
		["crew_briefing", "neutral", "Solar-particle events. I recommend building a Comms Relay. It'll give us a day of advance warning, so we'll have time to prepare instead of reacting at the last moment."],
		["player", "questioning", "What if the crew is outside when one arrives?"],
		["crew_briefing", "concerned", "That's why we should also build a Radiation Shielding Habitat. Anyone inside will be protected during a radiation wave. It'll reduce our everyday radiation exposure, too."],
		["crew_briefing", "neutral", "Both structures will cost resources, Commander. You can build them now or take the risk and continue without them. It's your decision."]
	],
	"sam_engineering": [
		["food_storage", "neutral", "That was rough. I'll check everyone for exposure. We also need to get the rover ready for its next expedition."],
		["player", "questioning", "Is something wrong with the rover?"],
		["food_storage", "confident", "Not necessarily. But our next mission needs its sampling equipment working properly. Build my Engineering station, and I'll have a proper base for rover servicing, robotics and repairs."],
		["food_storage", "smiling", "Better to check everything here than discover a problem halfway across the lunar surface."]
	],
	"alex_science": [
		["water_recycler", "concerned", "Everyone's safe, Commander, but that wave reminded me how little we still know about this place."],
		["player", "questioning", "What do you need?"],
		["water_recycler", "confident", "A Science station. Our next expedition will bring back ice samples, and I'll need somewhere to store and study them and to keep our instruments calibrated."],
		["water_recycler", "neutral", "And we should think about long-term food supplies. We can't depend entirely on what we brought from Earth."],
		["player", "questioning", "Can we produce food here?"],
		["water_recycler", "confident", "Yes. A Greenhouse Module grows food every day, and its plants give us oxygen too. That would help us build a more sustainable reserve."]
	],
	"alex_resources": [
		["water_recycler", "smiling", "Excellent work, Commander. We've collected our samples, but bringing them back is only the first step."],
		["player", "questioning", "What's next?"],
		["water_recycler", "neutral", "The samples confirm water ice at the prospect. We can now deploy a Water Extractor at that location."],
		["player", "questioning", "How much water could it provide?"],
		["water_recycler", "confident", "A steady supply every day, and we can split some of it into oxygen. It's a real source for the outpost, but we'll need to monitor what the site actually produces."]
	],
	"storm_warning": [
		["crew_briefing", "concerned", "Commander, a dust storm is heading our way. Visibility will drop, and our solar panels will lose half their light."],
		["player", "questioning", "What about our structures?"],
		["crew_briefing", "neutral", "The panels, extractors and greenhouses are exposed. We can pack them away until it passes, which costs the crew time and supplies, or leave them in the open and risk damage. It's your call."]
	],
	"crew_habitation": [
		["food_storage", "smiling", "Glad we've got Alex back. Between the radiation wave, the storm and the rescue, this crew has been through a lot."],
		["player", "questioning", "What can we do to make the outpost better for everyone?"],
		["food_storage", "neutral", "A Habitat Extension would help. It'll give us more living space, reduce stress, and add capacity for two more crew members if this base grows."],
		["food_storage", "smiling", "We've survived the emergencies, Commander. Now let's make this place somewhere people can actually live and work for longer."]
	],
	"sam_alex": [
		["player", "questioning", "Sam, have you heard from Alex since the dust storm?"],
		["food_storage", "concerned", "Nothing. I’ve been calling since the dust cleared. I marked where Alex last checked in on your map. I hope you find him. I’ll keep the radio on."]
	],
	"rover_briefing": [
		["crew_briefing", "smiling", "The structures are in place. It’s time to explore more of the Moon. Now head over to the lander to drive your very own rover."],
		["player", "questioning", "How will I control the rover?"],
		["crew_briefing", "confident", "You can do it from inside the lander. Once you’re there, we’ll get ready for your first rover expedition."]
	],
	"crew_briefing": [
		["crew_briefing", "smiling", "Welcome to the Moon. I’m Dr. Maya Chen, your flight engineer and training officer. I’ll help you learn the equipment and work safely out here."],
		["player", "questioning", "Where do I start?"],
		["crew_briefing", "neutral", "First, meet your crew. Sam keeps our equipment and habitat running and Alex leads our science work. Then come back to me and we’ll get started on construction."],
		["crew_briefing", "neutral", "One more thing. The four bars at the top right are our reserves: power, food, oxygen and water. The crew uses them every day, and once we start building they only rise if the base produces more than we consume."],
		["player", "questioning", "And the gold marks on the bars?"],
		["crew_briefing", "confident", "Those are our targets: {goals}. Reach all four by the end of the mission and this outpost is ready to become humanity's first Moon base. Fall short, and it won't be."]
	],
	"food_storage": [
		["food_storage", "smiling", "Hey, what's up. I’m Sam Okafor. Your guy for robotics, habitat operations and whatever needs fixing."],
		["player", "questioning", "So you’re the person to ask about rovers and construction?"],
		["food_storage", "smiling", "Exactly. Rovers, building equipment, life-support maintenance—that’s my territory. I’m also the crew’s medical officer, so let me know if you’re feeling unwell."]
	],
	"water_recycler": [
		["water_recycler", "smiling", "Hello! I’m Dr. Alex Rivera, lunar geologist and resource scientist."],
		["water_recycler", "confident", "I study what the rocks and terrain can tell us about this place."],
		["player", "questioning", "What will we be investigating?"],
		["water_recycler", "neutral", "We’ll collect samples and examine possible signs of water ice in shadowed terrain. I’ll also do my best to help you interpret the observations and NASA data as we go."]
	]
}
var dialogue_id := "crew_briefing"
var text_override := ""
var player: Node
var content: Control
var view: Control
var lines: Array = []
var line_index := 0
var timer: Tween
var ending := false

func _ready() -> void:
	name = "MayaIntroduction"
	layer = 95
	player = get_parent().get_node("Outpost/Astronaut")
	view = preload("res://src/ui/conversation_view.gd").new()
	add_child(view)
	content = view
	view.begin(get_parent())
	if SEQUENCES.has(dialogue_id) and text_override.is_empty():
		lines = SEQUENCES[dialogue_id].duplicate(true)
	else:
		var entry: Dictionary = INTRODUCTIONS[dialogue_id]
		var id := "crew_briefing"
		if entry.speaker == "Dr. Alex Rivera": id = "water_recycler"
		elif entry.speaker == "Sam Okafor": id = "food_storage"
		lines = [[id, "neutral", entry.text if text_override.is_empty() else text_override]]
	_show_line()

func _show_line() -> void:
	var line: Array = lines[line_index]
	var text := str(line[2]).replace("Commander", get_node("/root/MissionSession").commander_address())
	if text.contains("{shortfall}"):
		text = text.replace("{shortfall}", _shortfall_line())
	if text.contains("{goals}"):
		# The victory targets come from the simulator, so the line always matches the bars.
		var goals: Dictionary = preload("res://src/simulation/mission_simulator.gd").MISSION_GOALS
		text = text.replace("{goals}", "%d kilowatt-hours of power, %d kilograms of food, %d kilograms of oxygen and %d litres of water" % [goals.power_kwh, goals.food_kg, goals.oxygen_kg, goals.water_l])
	view.present(line[0], text, line[1])
	view.hint.text = "E / Enter / click: continue · %d / %d" % [line_index + 1, lines.size()]
	timer = create_tween()
	timer.tween_interval(maxf(6.0, str(line[2]).length() * 0.065))
	timer.tween_callback(advance)

## What still stands between the base and the good ending, from the live reserves.
func _shortfall_line() -> String:
	var session := get_node("/root/MissionSession")
	var state: Variant = session.dashboard_state
	if state == null: return "Keep every reserve above its gold line."
	var names := {"power": "power", "water": "water", "oxygen": "oxygen", "food": "food"}
	var short: Array = []
	for key in session.dashboard_simulator.base_shortfalls(state): short.append(names.get(key, key))
	if short.is_empty():
		return "Right now every reserve is above its gold line. Keep it that way: the crew uses them every day, and one bad stretch could still sink us."
	var listed: String = short[0] if short.size() == 1 else ", ".join(short.slice(0, short.size() - 1)) + " and " + str(short[-1])
	return "Right now we're short on %s. Every reserve has to reach its gold line by then, so build more greenhouses, extractors and solar panels while there's still time." % listed

func advance() -> void:
	if ending: return
	if timer != null and timer.is_valid(): timer.kill()
	line_index += 1
	if line_index < lines.size():
		_show_line()
	else:
		ending = true
		view.end()
		finished.emit()
		queue_free()

func _input(event: InputEvent) -> void:
	if ending: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_ENTER, KEY_SPACE]:
		get_viewport().set_input_as_handled()
		advance()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		advance()

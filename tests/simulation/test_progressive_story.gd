extends SceneTree
## Continuous resource time, goal lines, repeatable producers and story unlocks.
const Sim = preload("res://src/simulation/mission_simulator.gd")
const Story = preload("res://src/simulation/story.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _init() -> void:
	call_deferred("run")

func run() -> void:
	var sim := Sim.new()
	check(sim.load_contracts() == OK, "Contracts load")
	sim.events.clear()
	var state: Variant = sim.begin_mission("ridge_a")
	# A quarter of a day of play charges a quarter of the crew's daily oxygen.
	var oxygen: float = state.oxygen_kg
	check(not sim.tick_time(state, Sim.DAY_SECONDS * 0.25), "A part day does not close the day")
	check(is_equal_approx(oxygen - state.oxygen_kg, state.oxygen_consumed_kg * 0.25), "Oxygen drains in proportion to play time")
	check(sim.tick_time(state, Sim.DAY_SECONDS * 0.75), "A whole day of play is ready to close")
	var charged: float = state.oxygen_kg
	sim.close_day(state)
	check(state.sol == 1 and is_equal_approx(state.oxygen_kg, charged) and is_zero_approx(state.day_progress), "Closing the day does not charge it twice")
	# A manual rest charges only what is left of the day.
	sim.tick_time(state, Sim.DAY_SECONDS * 0.5)
	var before_rest: float = state.oxygen_kg
	sim.advance_sol(state)
	check(is_equal_approx(before_rest - state.oxygen_kg, state.oxygen_consumed_kg * 0.5), "Resting charges the rest of the day only")

	# Producers: oxygen from extractors and greenhouses, copies add output, food can rise.
	var base: Variant = sim.begin_mission("ridge_a")
	base.food_kg = 500.0
	base.oxygen_kg = 500.0
	base.water_l = 900.0
	base.volatile_prospect_status = "extraction_candidate"
	for id in ["water_extractor", "greenhouse"]:
		check(sim.queue_construction(base, id).ok and sim.complete_construction(base, id), "Builds " + id)
	sim.tick_time(base, 0.01)
	var one_house: float = base.food_consumed_kg
	check(sim.buy_structure_copy(base, "greenhouse") == "" and sim.buy_structure_copy(base, "greenhouse") == "", "Greenhouse copies can be bought")
	sim.tick_time(base, 0.01)
	check(is_equal_approx(one_house - base.food_consumed_kg, 2.0 * Sim.GREENHOUSE_FOOD_KG), "Each greenhouse copy adds its food")
	check(base.food_consumed_kg < 0.0 and base.oxygen_consumed_kg < 0.0, "Enough producers make food and oxygen rise")
	check(sim.buy_structure_copy(base, "comms_relay") == "structure", "Only producers repeat")
	check(not sim.demolish_structure(base, "greenhouse").ok, "The first greenhouse stays while copies remain")
	var water: float = base.water_l
	check(not sim.sell_structure_copy(base, "greenhouse").is_empty() and base.structure_copies.greenhouse == 1 and base.water_l > water, "Selling a copy refunds it")

	# Goals decide Maya's review.
	var review: Variant = sim.begin_mission("ridge_a")
	for key in Sim.MISSION_GOALS: review.set(key, Sim.MISSION_GOALS[key] - 1.0)
	check(sim.base_shortfalls(review).size() == 4, "Every reserve under its goal is short")
	for key in Sim.MISSION_GOALS: review.set(key, Sim.MISSION_GOALS[key])
	check(sim.base_shortfalls(review).is_empty(), "Reserves at their goals pass the review")

	# Session: nothing drains before the first structure; copies survive saving.
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	check(session.start_selected_mission() == OK, "Mission starts")
	var start_oxygen: float = session.dashboard_state.oxygen_kg
	session.tick_play(60.0)
	check(session.dashboard_state.oxygen_kg == start_oxygen, "Resources wait for the first structure")
	session.solar_placement = {"transform": Transform3D.IDENTITY, "kwh_per_sol": 30.0}
	session.tick_play(60.0)
	check(session.dashboard_state.oxygen_kg < start_oxygen, "Resources drain once something is built")
	var live: Variant = session.dashboard_state
	live.volatile_prospect_status = "extraction_candidate"
	check(sim.queue_construction(live, "water_extractor").ok, "Extractor queued")
	session.dashboard_simulator.complete_construction(live, "water_extractor")
	session.building_placements["water_extractor"] = Transform3D.IDENTITY
	check(session.buy_structure_copy("water_extractor", Transform3D(Basis(), Vector3(9, 0, 9))) == "", "Session buys an extractor copy")
	var restored := Save.decode(Save.capture(session))
	check(not restored.is_empty() and restored.extra_buildings.size() == 1 and restored.state.structure_copies.water_extractor == 1, "Copies survive save and load")
	var broken := Save.capture(session)
	broken.extra_buildings = []
	check(Save.decode(broken).is_empty(), "A save whose copies lost their placements is rejected")

	# Story: buildings unlock as the crew asks; saves past a beat count it as heard.
	var d: Dictionary = preload("res://src/simulation/rover_expedition.gd").fresh()
	check(not Story.unlocked("maya_station", {}, d) and Story.unlocked("maya_station", {"maya_closing": true}, d), "Maya's station waits for her request")
	d.completed = [0]
	check(Story.pending_beat("crew_briefing", {}, d) == "maya_radiation_prep", "After the survey Maya talks about radiation")
	d["radiation"] = "done"
	check(Story.pending_beat("food_storage", {}, d) == "sam_engineering", "After the wave Sam asks for his station")
	d.completed = [0, 1]
	check(Story.pending_beat("water_recycler", {}, d) == "alex_science", "After Frozen Horizon Alex asks for his station")
	d["dust_storm_complete"] = true
	check(Story.unlocked("water_extractor", {}, d) and Story.pending_beat("water_recycler", {}, d) == "", "An old save past the storm keeps the extractor unlocked")
	d.completed = [0, 1, 2]
	check(Story.pending_beat("food_storage", {}, d) == "crew_habitation" and not Story.unlocked("habitat_module", {}, d), "After Lifeline Sam and Alex talk about living here")
	check(Story.unlocked("greenhouse", {"alex_science": true}, d), "The greenhouse comes with Alex's Science station")
	print("PROGRESSIVE STORY: %d failures" % failures)
	quit(failures)

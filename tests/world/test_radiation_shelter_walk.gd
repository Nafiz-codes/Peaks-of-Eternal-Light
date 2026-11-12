extends SceneTree
## Radiation wave in the real outpost: crew route around structures to a far habitat,
## step out spread apart, walk back to work, and Sam's and Alex's stations can still be
## placed afterwards (and at every story stage where they are unlocked).
const Rules = preload("res://src/simulation/rover_expedition.gd")
var failures := 0
var world: Node3D
var session: Node
var placement: Node
var player: Node3D
var camera: Camera3D

func _init() -> void: call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

## Aims the placement at candidate spots until one is valid, then confirms it there.
func place(id: String, rows: Array, columns: Array) -> bool:
	placement._select(id)
	if not placement.active: return false
	for z in rows:
		for x in columns:
			var spot := Vector3(x, 0, z)
			player.global_position = spot + Vector3(0, 0, 8)
			camera.global_position = spot + Vector3(0, 7, 1)
			camera.look_at(spot)
			placement.yaw = PI
			placement.route_checked_at = 0
			placement._physics_process(0)
			if placement.valid:
				placement.confirm()
				return true
	placement._cancel()
	return false

func crew_spread() -> float:
	var nearest := INF
	var ids: Array = Rules.RADIATION_CREW
	for a in ids.size():
		for b in range(a + 1, ids.size()):
			nearest = minf(nearest, world.get_node("Outpost/" + ids[a]).global_position.distance_to(world.get_node("Outpost/" + ids[b]).global_position))
	return nearest

func run() -> void:
	session = root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.maya_intro_complete = true
	for flag in ["water_recycler", "food_storage", "maya_closing", "rover_briefing", "maya_radiation_prep"]:
		session.crew_introductions[flag] = true
	world = preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var state: Variant = session.dashboard_state
	for key in ["power_kwh", "water_l", "oxygen_kg", "food_kg"]: state.set(key, 290.0)
	placement = world.get_node("SolarPlacement")
	placement.set_physics_process(false)
	var crew := world.get_node("CrewFieldwork")
	crew.set_physics_process(false)
	player = world.get_node("Outpost/Astronaut")
	player.set_physics_process(false)
	camera = Camera3D.new()
	world.add_child(camera)
	camera.current = true
	check(place("solar_array", [6, 10], [-10, -5, 0, 5]), "Solar panel placed")
	check(place("maya_station", [-9, -4, 1, 6, 10, 16], [-10, -5, 0, 5, 10]), "Maya's station placed before the wave")
	# A 13 m habitat well outside the original 14 m crew pad.
	check(place("shielding_wall", [-26, -24, 24, 26], [-10, -5, 0, 5, 10]), "Radiation habitat placed far from the base")
	var storm := world.get_node("RadiationStorm")
	var shelter: Node3D = world.construction_view.completed.get("shielding_wall")
	check(shelter != null and Vector2(shelter.global_position.x, shelter.global_position.z).length() > 14.0, "Habitat stands outside the old route radius")

	# Survey done, Maya's warning given: order everyone into the habitat.
	var data: Dictionary = world.get_node("RoverTraining").data
	data.completed = [0]
	data["radiation"] = "orders"
	data["radiation_told"] = []
	data["radiation_elapsed"] = 0.0
	for id in Rules.RADIATION_CREW: storm.order_into_shelter(id)
	var routed := {}
	for step in 1200: # Up to 40 s of walking at 30 steps per second.
		storm._walk_to_shelter(1.0 / 30.0)
		for id in storm.shelter_paths: routed[id] = true
		if data.get("radiation_inside", []).size() == 3: break
	check(data.get("radiation_inside", []).size() == 3, "All three crew reach the habitat")
	check(routed.size() == 3, "Each crew member walked a checked route, not a straight line through structures")
	for id in Rules.RADIATION_CREW:
		var actor: Node3D = world.get_node("Outpost/" + id)
		check(actor.global_position.distance_to(storm.shelter_door(actor.global_position)) < 0.6, id + " went in at the habitat door")

	# The Commander shelters too, and must come out clear of the crew and of structures.
	player.global_position = storm.shelter_door(player.global_position)
	storm._enter_player_shelter()
	# The wave passes: they come out spread apart and head back to work.
	storm.start_wave()
	data["radiation_elapsed"] = storm.WAVE_SECONDS - 0.01
	storm._process(0.1)
	check(Rules.radiation(data) == "done", "The wave ends")
	check(crew_spread() > 2.5, "Crew step out at least 2.5 m apart: %.2f m" % crew_spread())
	check(not storm.player_inside, "The Commander leaves the habitat with the crew")
	var routes: RefCounted = crew.route_service
	for id in Rules.RADIATION_CREW:
		var actor: Node3D = world.get_node("Outpost/" + id)
		check(actor.global_position.distance_to(player.global_position) > 2.0, "The Commander does not come out on top of " + id)
		check(not routes.overlaps_structure(actor.global_position), id + " does not come out inside a structure")
	check(not routes.overlaps_structure(player.global_position - Vector3.UP * 0.2), "The Commander does not come out inside a structure")
	var exits := {}
	for id in Rules.RADIATION_CREW:
		exits[id] = world.get_node("Outpost/" + id).global_position
		check(crew.data.crew[id].phase == "Returning", id + " found a route back to work: " + str(crew.data.crew[id].phase))
	for step in 400: # 40 s of crew time.
		crew._physics_process(0.1)
	for id in Rules.RADIATION_CREW:
		if crew._wants_commander(id): continue # Sam and Alex walk up to the Commander with their requests.
		check(world.get_node("Outpost/" + id).global_position.distance_to(exits[id]) > 3.0, id + " walked away from the habitat")
	check(crew_spread() > 0.8, "Crew never end up standing inside each other")

	# Sam's and Alex's requests after the wave unlock their stations: both must be placeable.
	for flag in ["sam_engineering", "alex_science"]: session.crew_introductions[flag] = true
	for id in ["sam_station", "alex_station"]:
		check(place(id, [-9, -4, 1, 6, 10, 16, -18], [-10, -5, 0, 5, 10, -18, 18]), id + " can be placed after the radiation wave")
	# Every later stage: each station can be taken down and placed again elsewhere.
	for stage in [[0, 1], [0, 1, 2]]:
		data.completed = stage
		for id in ["sam_station", "alex_station"]:
			placement.target = placement.stations[id]
			placement._destroy_target()
			check(not session.station_placements.has(id), id + " removed")
			check(place(id, [16, 10, 6, 1, -4, -9, -18, 22, -22], [18, 10, 5, 0, -5, -10, -18, 24, -24]), "%s can be placed again after operation %d" % [id, stage.size()])
	# No route at all: nobody teleports, and the Commander is told who is stuck.
	var stuck: Node3D = world.get_node("Outpost/crew_briefing")
	var stuck_at := stuck.position
	data.completed = [0]
	data["radiation"] = "orders"
	data["radiation_told"] = ["crew_briefing"]
	data["radiation_inside"] = []
	crew.route_service.radius = 0.5 # Nowhere is walkable.
	for step in 90: storm._walk_to_shelter(1.0 / 30.0)
	check(stuck.position.distance_to(stuck_at) < 0.01 and not data.get("radiation_inside", []).has("crew_briefing"), "Without a path Maya stays where she is (no teleport)")
	var notice: Label = world.get_node("MissionHUD").announcement
	check(notice.visible and notice.text.contains("Maya") and notice.text.contains("path"), "The Commander is told Maya can't find a path: " + notice.text)
	world.queue_free()
	await process_frame
	print("RADIATION SHELTER WALK: %d failures" % failures)
	quit(1 if failures else 0)

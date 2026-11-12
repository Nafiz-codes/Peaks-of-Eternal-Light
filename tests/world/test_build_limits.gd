extends SceneTree
## Eight generating structures at most, and the walkable-path grid under a placement.
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.maya_intro_complete = true
	var world: Node3D = preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var state: Variant = session.dashboard_state
	for key in ["power_kwh", "water_l", "oxygen_kg", "food_kg"]: state.set(key, 290.0)

	# Generator limit: the free panel plus seven bought ones fill all eight slots.
	session.solar_placement = {"transform": Transform3D.IDENTITY, "kwh_per_sol": 10.0}
	session.extra_panels = []
	for index in 6: session.extra_panels.append({"transform": Transform3D.IDENTITY, "kwh_per_sol": 10.0})
	check(session.generator_count() == 7 and not session.generator_limit_reached(), "Seven generators leave room for one more")
	check(session.buy_solar_panel(Transform3D.IDENTITY, 10.0) == "", "The eighth generator can be bought")
	check(session.generator_limit_reached(), "Eight generators reach the limit")
	check(session.buy_solar_panel(Transform3D.IDENTITY, 10.0) == "space", "No ninth solar panel")
	check(session.queue_structure("greenhouse").get("error", "") == "generator_limit", "No greenhouse past the limit either")
	session.sell_solar_panel(0)
	check(not session.generator_limit_reached() and session.queue_structure("greenhouse").get("ok", false), "Removing one frees a slot for a greenhouse")
	check(session.generator_count() == 8, "Extractors and greenhouses count toward the same limit")

	# Walkable-path grid under a building being placed.
	session.extra_panels = []
	var placement := world.get_node("SolarPlacement")
	placement.set_physics_process(false)
	var player: Node3D = world.get_node("Outpost/Astronaut")
	player.set_physics_process(false)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.current = true
	session.crew_introductions["maya_radiation_prep"] = true
	placement._select("comms_relay")
	var spot := Vector3(-5, 0, 6)
	player.global_position = spot + Vector3(0, 0, 8)
	camera.global_position = spot + Vector3(0, 7, 1)
	camera.look_at(spot)
	placement._physics_process(0)
	var grid: MultiMeshInstance3D = placement.walk_grid
	check(grid != null and grid.visible and grid.multimesh.instance_count > 0, "Blocked cells are drawn under the building")
	var open := 0
	var blocked := 0
	if grid != null:
		for cell_open in placement.walk_grid_open:
			if cell_open: open += 1
			else: blocked += 1
	check(open == 0 and blocked > 0, "Only blocked cells (e.g. the new footprint) are drawn: %d open, %d blocked" % [open, blocked])
	placement._cancel()
	placement._physics_process(0)
	check(not grid.visible, "The grid disappears when placement ends")
	world.queue_free()
	await process_frame
	print("BUILD LIMITS: %d failures" % failures)
	quit(1 if failures else 0)

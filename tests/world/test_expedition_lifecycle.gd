extends SceneTree
var failures := 0
var assertions := 0
func _initialize(): call_deferred("run")
func check(value: bool, message: String):
	assertions += 1
	if not value:
		failures += 1
		push_error(message)
func run():
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.dashboard_state.sol = 2
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	var controller := world.get_node("RoverTraining")
	controller.set_physics_process(false)
	controller.data.mission = 0
	controller.dialogue = 9
	controller.motor.volume_db = -28
	controller._transition(true)
	check(controller.transitioning,"Departure fade started")
	session.reset_current_mission()
	controller._sync()
	check(not controller.transitioning and controller.fade.color.a == 0,"Reset cancels transition and clears fade")
	check(controller.dialogue == 0 and controller.busy_id == "","Reset releases tool/dialogue locks")
	check(controller.motor.volume_db == -80,"Reset silences previous motor activity")
	await create_timer(1).timeout
	check(controller.data.location == "outpost" and controller.data.mission == -1,"Old transition cannot mutate replacement campaign")
	var save = preload("res://src/runtime/mission_save.gd")
	var legacy: Dictionary = save.capture(session)
	check(legacy.version == save.VERSION, "Canonical saves use current version")
	check(world.find_children("StationAstronaut", "Node3D", true, false).size() == 3, "Three reused NPC models")
	check(world.get_node("Outpost/Astronaut").get_meta("crew_id") == "CREW_01", "Player is the sole Commander")
	check(world.get_node("Outpost/crew_briefing").get_meta("crew_id") == "CREW_02", "Maya uses the existing briefing astronaut")
	check(world.get_node("Outpost/water_recycler").get_meta("crew_id") == "CREW_03", "Alex uses the existing science astronaut")
	check(world.get_node("Outpost/food_storage").get_meta("crew_id") == "CREW_04", "Sam uses the existing engineering astronaut")
	check(not world.get_node("Outpost/power_console").has_node("StationAstronaut"), "Power console has no fourth NPC")
	var old_five: Dictionary = legacy.duplicate(true)
	old_five.version = 1
	old_five.state.crew_size = 5
	var old_field: Dictionary = old_five.state.fieldwork
	old_field.crew.power_console = old_field.crew.water_recycler.duplicate(true)
	old_field.crew.power_console.task = "deploy"
	old_field.crew.power_console.site = "instrument_a"
	old_field.crew.power_console.phase = "Paused"
	old_field.locks["seismometer"] = "power_console"
	var migrated: Dictionary = save.decode(old_five)
	check(not migrated.is_empty(), "Version 1 five-person save migrates")
	if not migrated.is_empty():
		check(migrated.state.crew_size == 4 and migrated.state.fieldwork.crew.size() == 3, "Migration removes only retired actor")
		check(migrated.state.fieldwork.pending_deployment == "instrument_a", "Old deployment queued for Alex")
		check(not migrated.state.fieldwork.locks.has("seismometer"), "Retired actor cannot retain tool locks")
		check(migrated.state.fieldwork.crew.water_recycler == old_field.crew.water_recycler, "Alex's current checkpoint remains intact")
		check(migrated.state.water_l == legacy.state.water_l and migrated.state.power_kwh == legacy.state.power_kwh, "Migration preserves earned reserves")
	legacy.version = 1
	legacy.state.crew_size = 4
	legacy.state.erase("rover_expedition")
	var restored: Dictionary = save.decode(legacy)
	check(not restored.is_empty() and restored.state.crew_size == 4,"Older four-person saves migrate")
	var provisions: float = restored.state.power_kwh
	check(save.restore(session,legacy) == OK,"Older save restores")
	check(is_equal_approx(save.decode(save.capture(session)).state.power_kwh,provisions),"Repeated save load preserves reserves")
	controller._sync()
	controller.data.mission = 0
	controller.data.surveys = ["alpha","beta","gamma"]
	controller.data.location = "expedition"
	controller.data.phase = "returning"
	var returning := save.capture(session)
	check(save.restore(session,returning) == OK,"Returning snapshot restores")
	controller._sync()
	check(controller.data.location == "expedition" and controller.data.phase == "active" and not controller.data.completed.has(0),"Interrupted return remains uncompleted at extraction")
	world.queue_free()
	await process_frame
	await process_frame
	print("EXPEDITION LIFECYCLE: %d failures / %d assertions" % [failures,assertions])
	quit(1 if failures else 0)

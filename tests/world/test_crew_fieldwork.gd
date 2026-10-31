extends SceneTree
var failures := 0
var assertions := 0
var field: Node
var world: Node3D
var session: Node
var player: Node3D
var facing_failures := 0
var moving_crew: Dictionary = {}

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)

func tick_until(id: String, phase: String, limit := 600, accompany := false) -> bool:
	for i in range(limit):
		await physics_frame
		if accompany:
			player.position = field.actors[id].position + Vector3(0, 0, 1.5)
		for other in field.IDS:
			var before: Vector3 = field.actors[other].position
			field._tick(other, 0.25)
			verify_facing(other, before)
		if field.data.crew[id].phase == phase:
			return true
	print("Task did not reach ", phase, ": ", field.data.crew[id])
	return false

func verify_facing(id: String, before: Vector3) -> void:
	var actor: Node3D = field.actors[id]
	var travel := actor.position - before
	travel.y = 0.0
	if travel.length_squared() < 0.000001:
		return
	moving_crew[id] = true
	# The imported suit's +Z front is rotated 180 degrees by StationAstronaut.
	var suit_front: Vector3 = actor.get_node("StationAstronaut").global_basis.z.normalized()
	if suit_front.dot(travel.normalized()) < 0.99:
		facing_failures += 1
	var tool: Node3D = field.props[id]
	if (tool.global_position - actor.global_position).dot(suit_front) <= 0.0:
		facing_failures += 1

func run() -> void:
	session = root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	world = preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	await physics_frame
	field = world.get_node("CrewFieldwork")
	player = world.get_node("Outpost/Astronaut")
	field.set_physics_process(false)
	player.set_physics_process(false)
	session.start_selected_mission()
	for id in field.IDS:
		field.data.crew[id].auto_attempted = true
	check(world.find_children("StationAstronaut", "Node3D", true, false).size() == 3, "Exactly three existing NPC models.")
	check(field.actors.size() == 3 and field.SPECIALTIES.size() == 3, "Three canonical identities receive specialties.")
	var path: PackedVector3Array = field.route_service.route(field.homes.water_recycler, field.SITES.sample_a)
	check(not path.is_empty(), "Sampling location reachable on real terrain.")
	player.position = field.actors.water_recycler.position + Vector3(0, 0, 1.5)
	check(field.assign("water_recycler", "sample", "sample_a"), "Assign geology collection.")
	check(not field.reserve("crew_briefing", ["camera"]), "Shared camera cannot be double-booked.")
	check(await tick_until("water_recycler", "Working", 600, true), "Geologist physically reaches sampling location.")
	check(field.data.samples.is_empty(), "No samples before collection.")
	check(field.assist("water_recycler"), "Nearby player assists the current work step.")
	field.pause_work("water_recycler")
	var progress: float = field.data.crew.water_recycler.progress
	field._tick("water_recycler", 50)
	check(field.data.crew.water_recycler.progress == progress, "Pause preserves progress.")
	check(field.reserve("crew_briefing", ["camera"]), "Paused task releases shared camera.")
	check(not field.resume_work("water_recycler"), "Cannot resume while another user owns required tool.")
	field._release("crew_briefing")
	check(field.resume_work("water_recycler"), "Resume at valid checkpoint.")
	check(await tick_until("water_recycler", "Returning", 600, true), "Collection, photo and label finish before transport.")
	check(field.data.samples.sample_a.storage == "carried" and field.data.samples.sample_a.photographed and field.data.samples.sample_a.labelled, "Sample record captures evidence and carrier, not storage.")
	check(field.data.samples.sample_a.photo.position == field.data.samples.sample_a.location, "Photographic documentation retains collection location.")
	var save := preload("res://src/runtime/mission_save.gd")
	var captured := save.capture(session)
	check(save.decode(captured).state.fieldwork.samples.sample_a.storage == "carried", "In-transit results survive save decode.")
	check(save.restore(session, captured) == OK, "Restore an in-progress outing.")
	field.sync()
	check(field.data.crew.water_recycler.phase == "Returning" and field.data.crew.water_recycler.cargo == "sample_a", "Restored carrier and return checkpoint remain intact.")
	check(await tick_until("water_recycler", "Available", 600, true), "Sample transported to storage and astronaut returns.")
	check(field.data.samples.sample_a.storage == "base", "Storage changes only after physical return.")
	check(not field.assign("water_recycler", "sample", "sample_a"), "Duplicate collection refused.")
	check(field.sample_visuals.sample_a.visible == false and field.storage_visual.visible, "Collected rock disappears and stored container becomes visible.")
	check(field.assign("water_recycler", "deploy", "instrument_a"), "Assign instrument deployment with equipment buddy.")
	for i in range(600):
		await physics_frame
		for other in field.IDS:
			field._tick(other, 0.25)
		if field.data.crew.water_recycler.phase == "Working" and field.data.crew.water_recycler.step == 2:
			break
	check(field.data.instrument.get("status") == "positioned", "Positioning leaves a real but unverified instrument.")
	field.return_to_base("water_recycler")
	check(await tick_until("water_recycler", "Available"), "Deployment can be interrupted after positioning.")
	await tick_until("food_storage", "Available")
	check(field.assign("water_recycler", "deploy", "instrument_b"), "Reassignment recovers incomplete deployment.")
	check(field.data.crew.water_recycler.site == "instrument_a" and field.data.crew.water_recycler.step == 2, "Recovery uses existing site and verification checkpoint, not a duplicate instrument.")
	check(await tick_until("water_recycler", "Available"), "Deployment completes and field pair returns.")
	check(field.data.instrument.get("status") == "operational", "Deployment changes actual instrument state.")
	check(field.data.instrument.get("photographed", false), "Installation photograph is recorded.")
	check(not field.assign("water_recycler", "deploy", "instrument_b"), "Already deployed instrument cannot be duplicated.")
	field.data.instrument.battery_remaining = 0.1
	field._physics_process(0.2)
	check(field.data.instrument.status == "battery depleted", "Finite instrument battery stops operation.")
	await tick_until("food_storage", "Available")
	session.dashboard_state.rover_health = 30.0
	field.data.power_priority = "maintenance"
	var kits: int = field.data.stock.repair_kit
	var materials: float = session.dashboard_state.materials
	check(field.assign("food_storage", "repair"), "Assign supported rover maintenance.")
	check(not field.consume_manual_repair(), "Player cannot use a rover worksite reserved for maintenance.")
	check(await tick_until("food_storage", "Available"), "Maintenance completes inspection, repair and verification.")
	check(session.dashboard_state.rover_health == 70.0 and field.data.stock.repair_kit == kits - 1 and session.dashboard_state.materials == materials - field.config.repair_materials, "Repair consumes limited kit/material and restores configured health.")
	check(not field.data.readiness.is_empty(), "Readiness inspection persists.")
	check(field.assign("crew_briefing", "navigate", "sample_a"), "Assign coordinator route assessment.")
	check(await tick_until("crew_briefing", "Available"), "Coordinator completes route / return-resource report.")
	check(field.data.routes.has("sample_a") and field.data.routes.sample_a.return_oxygen_kg > 0, "Route includes measured distance and modeled return oxygen.")
	session.dashboard_state.active_events.append({"event_id": "comms_blackout"})
	check("location unconfirmed" in field.describe("crew_briefing"), "Communication blackout hides live crew positions.")
	session.dashboard_state.active_events.clear()
	check("Unknown" in field.assess_route("unexplored").text, "No omniscient route to unexplored destinations.")
	var barrier := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(3, 4, 3)
	shape.shape = box
	barrier.add_child(shape)
	world.add_child(barrier)
	barrier.position = field.SITES.sample_b + Vector3(0, 1, 0)
	await physics_frame
	await physics_frame
	player.position = field.actors.water_recycler.position + Vector3(0, 0, 1.5)
	check(not field.assign("water_recycler", "sample", "sample_b") and field.data.crew.water_recycler.phase == "Blocked", "Blocked destination reports a safe fallback.")
	barrier.queue_free()
	await physics_frame
	await physics_frame
	check(field.resume_work("water_recycler"), "Clearing blocker permits recovery.")
	check(field.assist("water_recycler"), "Player helps prepare tools for resumed outing.")
	field.pause_work("water_recycler")
	field.return_to_base("water_recycler")
	check(await tick_until("water_recycler", "Available", 600, true), "Interrupted optional excursion returns safely.")
	field.data.stock.repair_kit = 0
	check(not field.assign("food_storage", "repair") and field.data.crew.food_storage.phase == "Waiting for assistance", "Missing parts block repair instead of granting free health.")
	field.data.player_cargo.repair_kit = 1
	player.position = field.actors.food_storage.position + Vector3(0, 0, 1.5)
	check(field.deliver("food_storage", "repair_kit"), "Player delivers carried replacement part.")
	check(field.resume_work("food_storage"), "Delivered part unblocks task.")
	field.pause_work("food_storage")
	var oxygen: float = session.dashboard_state.oxygen_kg
	session.dashboard_state.oxygen_kg = 0.5
	field.resume_work("food_storage")
	field._tick("food_storage", 1.0)
	check(field.data.crew.food_storage.phase in ["Responding to a hazard", "Blocked"], "Low reserve stops optional work.")
	session.dashboard_state.oxygen_kg = oxygen
	field.return_to_base("food_storage")
	await tick_until("food_storage", "Available")
	player.position = field.actors.crew_briefing.position + Vector3(0, 0, 1.5)
	check(field.follow("crew_briefing"), "Coordinator can accompany the player locally.")
	check(await tick_until("crew_briefing", "Working"), "Accompanying NPC walks to the player.")
	check(not field.assist("crew_briefing"), "Following has no invalid specialist work step to assist.")
	field.return_to_base("crew_briefing")
	check(await tick_until("crew_briefing", "Available"), "Follow can be interrupted by a return order.")
	field.data.crew.crew_briefing.auto_attempted = false
	field.elapsed = field.config.autonomy_delay_seconds
	field._tick("crew_briefing", 0.1)
	check(field.data.crew.crew_briefing.phase == "Preparing", "Available coordinator starts useful work autonomously.")
	field.pause_work("crew_briefing")
	paused = true
	check(not field.command("crew_briefing", "resume"), "Game pause prevents task commands.")
	paused = false
	player.position = field.LOCKER + Vector3(0, 0.8, 0)
	var containers: int = field.data.stock.container
	check(field.collect_supply("container") and field.data.stock.container == containers - 1, "Collecting a container transfers finite stock to player.")
	check(not field.collect_supply("container"), "Carry capacity prevents repeated container pickup.")
	var invalid := save.capture(session)
	invalid.state.fieldwork.crew.crew_briefing.position = "invalid"
	check(save.decode(invalid).is_empty(), "Malformed persisted crew position is rejected.")
	captured.state.erase("fieldwork")
	check(not save.decode(captured).is_empty(), "Old saves without fieldwork remain compatible.")
	check(moving_crew.size() == 3, "Facing verification covers all three existing NPCs in motion.")
	check(facing_failures == 0, "Astronauts face their travel direction with tools in front on outbound, return and follow paths.")
	if "--capture" in OS.get_cmdline_user_args():
		world.get_node("MissionHUD").inspect_station("crew_briefing")
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/crew-fieldwork-dialogue.png")
	print("Crew fieldwork: %d failures / %d assertions." % [failures, assertions])
	quit(1 if failures else 0)

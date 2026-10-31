extends Node3D
## Persistent field routines attached to the three canonical station astronauts.
const IDS := ["water_recycler", "food_storage", "crew_briefing"]
const SPECIALTIES := {
	"water_recycler": "Alex Rivera · Geology, samples and scientific instruments",
	"food_storage": "Sam Okafor · Engineering, habitat and medical support", "crew_briefing": "Maya Chen · Training, safety and navigation"}
const STEPS := {
	"sample": ["Inspect rock and surroundings", "Photograph undisturbed sample", "Collect with tongs", "Label sample and location"],
	"deploy": ["Unpack seismometer", "Position and level sensor", "Connect local battery and verify", "Photograph installation"],
	"inspect": ["Check rover energy and condition", "Inspect exposed wheel equipment for dust", "Record tools and replacement needs"],
	"repair": ["Inspect rover damage", "Fit replacement component", "Verify repaired equipment"],
	"navigate": ["Check local radio contact", "Assess established science route", "Estimate return oxygen and log crew status"]}
const SITES := {"sample_a": Vector3(-3, 0, 7), "sample_b": Vector3(4, 0, 8),
	"instrument_a": Vector3(-7, 0, 7), "instrument_b": Vector3(-5, 0, 9)}
const LOCKER := Vector3(0, 0, 6)
var config: Dictionary
var world: Node3D
var session: Node
var state: Variant = null
var data: Dictionary = {}
var actors: Dictionary = {}
var homes: Dictionary = {}
var props: Dictionary = {}
var labels: Dictionary = {}
var route_service: RefCounted
var elapsed := 0.0
var notify_elapsed := 0.0
var instrument: MeshInstance3D
var instrument_label: Label3D
var sample_visuals: Dictionary = {}
var storage_visual: MeshInstance3D
signal changed

func _ready() -> void:
	world = get_parent()
	session = get_node("/root/MissionSession")
	config = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/fieldwork.json"))
	for id in IDS:
		var actor := world.get_node("Outpost/" + id) as Node3D
		actors[id] = actor
		homes[id] = actor.position
		var label := Label3D.new()
		label.name = "FieldworkLabel"
		label.position.y = 2.0
		label.font_size = 22
		label.pixel_size = 0.005
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		actor.add_child(label)
		labels[id] = label
		var prop := _box(actor, Vector3(0.32, 0.18, 0.23), Vector3(0.4, 1.05, -0.25), Color("d8b871"))
		prop.name = "FieldTool"
		# Primitive fallback props preserve the original astronaut model and rig.
		var lens := _box(prop, Vector3(0.12, 0.12, 0.12), Vector3(0, 0, -0.16), Color("222936"))
		lens.name = "CameraLens"
		for side in [-1, 1]:
			var tong := _box(prop, Vector3(0.025, 0.48, 0.025), Vector3(side * 0.06, -0.27, 0), Color("abb3ba"))
			tong.name = "Tong" + str(side)
		prop.hide()
		props[id] = prop
	route_service = preload("res://src/world/crew_routes.gd").new(world, config.survey_radius_m)
	_box(self, Vector3(0.7, 0.45, 0.5), LOCKER + Vector3(0, 0.225, 0), Color("c5c7bd"))
	storage_visual = _box(self, Vector3(0.25, 0.2, 0.25), LOCKER + Vector3(0, 0.55, 0), Color("e8ae61"))
	storage_visual.hide()
	_add_label("FIELD SUPPLIES / SAMPLE STORAGE\nCollect supplies through crew conversation nearby", LOCKER + Vector3(0, 0.9, 0))
	for key in SITES:
		_box(self, Vector3(0.08, 0.5, 0.08), SITES[key] + Vector3(0, 0.25, 0), Color("e8ae61"))
		_add_label(key.replace("_", " ").to_upper(), SITES[key] + Vector3(0, 0.65, 0))
		if key.begins_with("sample"):
			var rock := MeshInstance3D.new()
			var mesh := SphereMesh.new()
			mesh.radius = 0.16
			mesh.height = 0.22
			rock.mesh = mesh
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("72716b")
			material.roughness = 1.0
			rock.material_override = material
			add_child(rock)
			rock.position = SITES[key] + Vector3(0.45, 0.1, 0)
			sample_visuals[key] = rock
	instrument = _box(self, Vector3(0.55, 0.35, 0.55), Vector3.ZERO, Color("d3bd85"))
	instrument.name = "FieldSeismometer"
	instrument.hide()
	instrument_label = _add_label("", Vector3.ZERO)
	session.state_changed.connect(sync)
	sync()

func _box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material_override = material
	parent.add_child(mesh)
	mesh.position = pos
	return mesh

func _add_label(text: String, pos: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.font_size = 20
	label.pixel_size = 0.004
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.position = pos
	add_child(label)
	return label

func sync() -> void:
	if state == session.dashboard_state:
		return
	state = session.dashboard_state
	elapsed = 0.0
	if state == null:
		data = {}
		return
	if state.fieldwork.is_empty():
		state.fieldwork = {"crew": {}, "locks": {}, "samples": {}, "instrument": {}, "log": [],
			"stock": {"container": int(config.initial_containers), "repair_kit": int(config.initial_repair_kits)},
			"player_cargo": {"container": 0, "repair_kit": 0}, "routes": {}, "readiness": {}, "power_priority": "science"}
	data = state.fieldwork
	for id in IDS:
		if not data.crew.has(id):
			data.crew[id] = {"phase": "Available", "task": "", "step": 0, "progress": 0.0,
				"position": homes[id], "target": homes[id], "site": "", "path": PackedVector3Array(),
				"message": "Ready for local fieldwork.", "checkpoint": "Preparing", "cargo": "",
				"container": false, "kit": false, "last_sol": -1, "auto_attempted": false, "alternative": false}
		actors[id].position = data.crew[id].position
		_update_visual(id, false)
	_restore_instrument()
	changed.emit()

func _restore_instrument() -> void:
	var stored := false
	for key in sample_visuals:
		sample_visuals[key].visible = not data.samples.has(key)
		stored = stored or data.samples.get(key, {}).get("storage", "") == "base"
	storage_visual.visible = stored
	instrument.visible = not data.instrument.is_empty()
	if instrument.visible:
		instrument.position = data.instrument.position + Vector3(0, 0.175, 0)
		instrument_label.position = instrument.position + Vector3(0, 0.7, 0)
		instrument_label.text = "SEISMOMETER / " + str(data.instrument.status).to_upper()
	else:
		instrument_label.text = ""

func _physics_process(delta: float) -> void:
	sync()
	if state == null or get_tree().paused or state.mission_outcome.get("status") != "in_progress":
		return
	elapsed += delta
	for id in IDS:
		if id == "crew_briefing" and not state.rover_expedition.is_empty() and state.sol >= 6 and not state.rover_expedition.completed.has(2):
			continue
		_tick(id, delta)
	# Local instrument records only modeled health/uptime, never invented moonquakes.
	if data.instrument.get("status", "") == "operational":
		data.instrument.uptime += delta
		data.instrument.battery_remaining = maxf(0.0, data.instrument.get("battery_remaining", config.instrument_battery_seconds) - delta)
		data.instrument.measurements = "Sensor self-test passed; %.0f s operating; %.0f s local battery remaining. No seismic signal model is available." % [data.instrument.uptime, data.instrument.battery_remaining]
		if data.instrument.battery_remaining <= 0.0:
			data.instrument.status = "battery depleted"
			data.instrument.measurements = "Battery depleted. Reassign instrument service to charge and verify the existing installation."
			_restore_instrument()
			_report("water_recycler", data.crew.water_recycler.phase, "Instrument battery depleted. Local data retained; service requires allocated power.")
	notify_elapsed += delta
	if notify_elapsed >= 1.0:
		notify_elapsed = 0.0
		changed.emit()

func _report(id: String, phase: String, message: String) -> void:
	var c: Dictionary = data.crew[id]
	if c.phase == phase and c.message == message:
		return
	c.phase = phase
	c.message = message
	data.log.append({"sol": state.sol, "crew": id, "phase": phase, "text": message})
	if data.log.size() > 100:
		data.log.pop_front()
	_update_visual(id, false)
	changed.emit()

func _tools(task: String) -> Array:
	match task:
		"sample": return ["camera", "tongs", "field_team"]
		"deploy": return ["camera", "level", "field_team", "seismometer"]
		"inspect", "repair": return ["maintenance_tools", "rover_worksite"]
		"navigate": return ["route_tablet"]
		"follow": return ["field_team"]
	return []

func reserve(id: String, items: Array) -> bool:
	if id not in IDS:
		return false
	for item in items:
		if data.locks.has(item) and data.locks[item] != id:
			return false
	for item in items:
		data.locks[item] = id
	return true

func _release(id: String) -> void:
	for item in data.locks.keys():
		if data.locks[item] == id:
			data.locks.erase(item)

func assign(id: String, task: String, site := "") -> bool:
	if id == "crew_briefing" and state != null and state.sol >= 6 and not state.rover_expedition.get("completed", []).has(2):
		return false
	if state == null or not session.can_advance() or get_tree().paused or not IDS.has(id):
		return false
	var c: Dictionary = data.crew[id]
	if c.phase != "Available":
		return false
	if not task in {"water_recycler": ["sample", "deploy"], "food_storage": ["inspect", "repair"], "crew_briefing": ["navigate"]}[id]:
		return false
	if site.is_empty():
		site = "sample_a" if task in ["sample", "navigate"] else "instrument_a"
	if task in ["sample", "deploy", "navigate"] and not SITES.has(site):
		return false
	if task == "sample" and (not site.begins_with("sample") or data.samples.has(site)):
		_report(id, "Available", "That sample is already collected or the site is unsuitable.")
		return false
	if task == "deploy" and (not site.begins_with("instrument") or data.instrument.get("status", "") == "operational"):
		_report(id, "Available", "The instrument is already positioned; resume its existing task.")
		return false
	c.task = task
	c.site = site
	c.step = 0
	if task == "deploy" and not data.instrument.is_empty():
		site = data.instrument.site
		c.site = site
		c.step = 3 if data.instrument.status == "verified" else 2
	c.progress = 0.0
	c.alternative = false
	c.checkpoint = "Preparing"
	c.target = SITES.get(site, homes[id])
	if task in ["inspect", "repair"]:
		c.site = "rover"
		c.target = world.get_node("Outpost/Rover").position + Vector3(-3.0, 0, 0)
	elif task == "navigate":
		c.target = homes[id]
	return _prepare(id)

func _prepare(id: String) -> bool:
	var c: Dictionary = data.crew[id]
	if c.task in ["inspect", "repair"]:
		c.target = world.get_node("Outpost/Rover").position + Vector3(-3.0, 0, 0)
	if state.oxygen_kg <= config.oxygen_reserve_kg:
		_block(id, "Base oxygen reserve is too low. Change plans or restore supplies.")
		return false
	if not reserve(id, _tools(c.task) + ["site:" + str(c.site)]):
		_block(id, "A shared tool or work location is reserved. Return to base or retry after release.")
		return false
	if c.task == "sample" and not c.container:
		if data.stock.container <= 0:
			_wait(id, "I need an empty sample container. Deliver one from the field supplies locker.")
			return false
		data.stock.container -= 1
		c.container = true
	if c.task == "deploy":
		var buddy: Dictionary = data.crew.food_storage
		if buddy.task != "buddy" and buddy.phase != "Available":
			_wait(id, "I need the equipment specialist for the field team. Finish or return their current task.")
			return false
		if buddy.task != "buddy":
			buddy.task = "buddy"
			buddy.target = c.target + Vector3(1.1, 0, 0)
			buddy.path = route_service.route(actors.food_storage.position, buddy.target)
			if buddy.path.is_empty():
				buddy.task = ""
				_block(id, "The equipment specialist has no safe route to the deployment site.")
				return false
			_report("food_storage", "Traveling", "Accompanying the instrument specialist; carrying setup tools.")
	if c.task == "repair":
		if world.get_node("RoverHull").active:
			_block(id, "Park the rover before maintenance.")
			return false
		if state.rover_health >= 100.0:
			_block(id, "Rover is already healthy. Return and request an inspection instead.")
			return false
		if not c.kit:
			if data.stock.repair_kit <= 0:
				_wait(id, "This repair needs a replacement kit. Supplies are finite; reduced capability may be necessary.")
				return false
			data.stock.repair_kit -= 1
			c.kit = true
		if state.materials < config.repair_materials:
			_block(id, "Insufficient mission materials for this repair.")
			return false
	if c.task in ["inspect", "repair"] and world.get_node("RoverHull").active:
		_block(id, "Park the rover before approaching its equipment.")
		return false
	c.path = route_service.route(actors[id].position, c.target)
	if c.path.is_empty():
		_block(id, "No safe local path. Ask navigation to assess an alternative, or return to base.")
		return false
	if c.task == "sample" and not _player_near(id, config.companion_distance_m):
		_wait(id, "Please accompany me to the sample site. I will wait here with the tools.")
		return false
	var return_path: PackedVector3Array = route_service.route(c.target, homes[id])
	if return_path.is_empty():
		_block(id, "No verified return path from that work site. Choose another site or clear the corridor.")
		return false
	var distance := _path_length(actors[id].position, c.path) + _path_length(c.target, return_path)
	if state.oxygen_kg < config.oxygen_reserve_kg + distance * config.oxygen_per_metre_kg:
		_block(id, "The planned outing would use the reserved return oxygen. Shorten the excursion.")
		return false
	_report(id, "Preparing", "Checking tools, container and local return route.")
	return true

func _path_length(origin: Vector3, path: PackedVector3Array) -> float:
	var total := 0.0
	for point in path:
		total += origin.distance_to(point)
		origin = point
	return total

func _wait(id: String, reason: String) -> void:
	_release(id)
	_report(id, "Waiting for assistance", reason)

func _block(id: String, reason: String) -> void:
	_release(id)
	_report(id, "Blocked", reason)

func _player_near(id: String, distance: float = 3.2) -> bool:
	var player := world.get_node("Outpost/Astronaut")
	return not player.seated and player.global_position.distance_to(actors[id].global_position) <= distance

func _tick(id: String, delta: float) -> void:
	var c: Dictionary = data.crew[id]
	if c.phase == "Available":
		if id == "water_recycler" and data.has("pending_deployment"):
			var site: String = data.pending_deployment
			assign(id, "deploy", site)
			if c.task == "deploy" or data.instrument.get("status", "") == "operational":
				data.erase("pending_deployment")
			return
		if elapsed >= config.autonomy_delay_seconds and not c.auto_attempted:
			c.auto_attempted = true
			var task: String = {"water_recycler": "sample", "food_storage": "inspect", "crew_briefing": "navigate"}[id]
			assign(id, task)
		return
	if c.phase in ["Paused", "Blocked", "Responding to a hazard"]:
		return
	if c.phase != "Returning" and (state.oxygen_kg <= config.oxygen_reserve_kg or not state.pending_events.is_empty() or _active_event("solar_particle_event")):
		c.checkpoint = c.phase
		_release(id)
		_report(id, "Responding to a hazard", "Work stopped: check mission decisions and oxygen reserve. Resume or order a safe return.")
		return
	if c.phase == "Waiting for assistance":
		if c.task == "deploy" and c.step == 2 and actors.food_storage.position.distance_to(c.target) <= 2.5:
			resume_work(id)
		return
	if c.task == "sample" and c.phase != "Returning" and not _player_near(id, config.companion_distance_m):
		c.checkpoint = c.phase
		_wait(id, "Companion out of range. Rejoin me and resume; the sample remains with me.")
		return
	if c.task in ["inspect", "repair"] and world.get_node("RoverHull").active:
		c.checkpoint = c.phase
		_block(id, "Rover is moving. Park it and resume the inspection.")
		return
	if c.phase in ["Traveling", "Returning"]:
		_move(id, delta)
		return
	if c.task == "follow":
		var player := world.get_node("Outpost/Astronaut")
		if player.seated or player.position.length() > config.survey_radius_m:
			c.checkpoint = "Traveling"
			_wait(id, "Excursion boundary reached. I will not enter unexplored terrain alone.")
		elif player.position.distance_to(actors[id].position) > 2.5:
			c.target = player.position + Vector3(-1.3, 0, 0)
			c.path = route_service.route(actors[id].position, c.target)
			if c.path.is_empty():
				c.checkpoint = "Traveling"
				_block(id, "Your new route is obstructed. Regroup or return to base.")
			else:
				_report(id, "Traveling", "Following your local excursion.")
		return
	if c.task == "buddy":
		return
	c.progress += delta
	_update_visual(id, false)
	match c.phase:
		"Preparing":
			if c.progress >= config.prepare_seconds:
				c.progress = 0.0
				_report(id, "Traveling", "Moving along the checked local route.")
		"Working":
			if c.progress >= config.step_seconds:
				_complete_step(id)
		"Recording results":
			if c.progress >= config.record_seconds:
				_record(id)

func _move(id: String, delta: float) -> void:
	var c: Dictionary = data.crew[id]
	# Let the equipment buddy clear the shared deployment area before Alex returns.
	if id == "water_recycler" and c.task == "deploy" and c.phase == "Returning" and data.crew.food_storage.task == "buddy" and data.crew.food_storage.phase == "Returning":
		_update_visual(id, false)
		return
	var actor: Node3D = actors[id]
	if c.path.is_empty():
		if c.phase == "Returning":
			_finish(id)
		elif c.task == "follow":
			_report(id, "Working", "With you. Maintaining local visual contact.")
		elif c.task == "buddy":
			_report(id, "Working", "At the instrument site. Ready to help position and verify.")
		else:
			c.progress = 0.0
			_report(id, "Working", STEPS[c.task][c.step])
		return
	var next: Vector3 = c.path[0]
	var before := actor.position
	var carry_help: bool = c.get("carry_assistance", false) and _player_near(id)
	var after := before.move_toward(next, config.walk_speed_mps * (1.1 if carry_help else 1.0) * delta)
	if not route_service.clear_segment(before, after):
		c.checkpoint = c.phase
		_block(id, "The route has become blocked. Stopped safely; assess an alternative or return.")
		return
	# Keep astronauts from overlapping even though route planning ignores their bodies.
	for other in IDS:
		if other != id and after.distance_to(actors[other].position) < 0.8 and after.distance_to(actors[other].position) < before.distance_to(actors[other].position):
			c.checkpoint = c.phase
			_block(id, "Another crew member occupies the path. Regroup or retry after they move.")
			return
	var distance := before.distance_to(after)
	state.oxygen_kg = maxf(0.0, state.oxygen_kg - distance * config.oxygen_per_metre_kg)
	actor.position = after
	c.position = after
	if distance > 0.0001:
		# StationAstronaut has the same 180-degree model correction as the player:
		# the suited character faces the actor's -Z axis, not +Z.
		actor.rotation.y = atan2(before.x - next.x, before.z - next.z)
	_update_visual(id, true)
	if after.distance_to(next) < 0.05:
		c.path.remove_at(0)

func _complete_step(id: String) -> void:
	var c: Dictionary = data.crew[id]
	if c.task == "sample":
		if not c.container:
			c.checkpoint = "Working"
			_wait(id, "I need a sample container before collection can continue.")
			return
		if c.step == 1:
			c.photo = {"position": sample_visuals[c.site].position, "sol": state.sol, "purpose": "Undisturbed sample documentation"}
		elif c.step == 2:
			if data.samples.has(c.site):
				_block(id, "Sample already collected; duplicate collection prevented.")
				return
			data.samples[c.site] = {"id": c.site, "location": sample_visuals[c.site].position, "collector": id, "photo": c.photo.duplicate(true),
				"photographed": true, "labelled": false, "storage": "carried", "carrier": id,
				"sol": state.sol, "observation": "Surface rock documented before collection. Composition not yet analyzed."}
			c.cargo = c.site
			_restore_instrument()
		elif c.step == 3 and data.samples.has(c.site):
			data.samples[c.site].labelled = true
	elif c.task == "deploy":
		if c.step == 1:
			data.instrument = {"position": c.target, "site": c.site, "status": "positioned", "uptime": 0.0,
				"photographed": false, "measurements": "Awaiting leveling and verification."}
			_restore_instrument()
		elif c.step == 2:
			if actors.food_storage.position.distance_to(c.target) > 2.5 and not c.get("joint_verification", false):
				c.checkpoint = "Working"
				_wait(id, "The instrument is positioned. Bring the equipment specialist or assist with verification.")
				return
			if state.power_kwh < config.verification_power_kwh or data.power_priority != "science":
				c.checkpoint = "Working"
				_block(id, "Verification needs allocated science power. Choose science priority or defer deployment.")
				return
			state.power_kwh -= config.verification_power_kwh
			data.instrument.status = "verified"
			data.instrument.battery_remaining = config.instrument_battery_seconds
			session.state_changed.emit()
		elif c.step == 3:
			data.instrument.photographed = true
			data.instrument.photo = {"position": c.target, "sol": state.sol, "purpose": "Installation documentation"}
			data.instrument.status = "operational"
			_restore_instrument()
	elif c.task == "repair" and c.step == 1:
		if not c.kit or state.materials < config.repair_materials or data.power_priority != "maintenance":
			c.checkpoint = "Working"
			_block(id, "Repair needs one kit, mission material and maintenance priority. Choose what to defer.")
			return
		state.materials -= config.repair_materials
		c.kit = false
		state.rover_health = minf(100.0, state.rover_health + config.repair_points)
		world.get_node("RoverHull")._update_health()
		session.state_changed.emit()
	c.step += 1
	c.progress = 0.0
	if c.step >= STEPS[c.task].size():
		_report(id, "Recording results", "Recording the work and preparing to return.")
	else:
		_report(id, "Working", STEPS[c.task][c.step])

func _record(id: String) -> void:
	var c: Dictionary = data.crew[id]
	if c.task in ["inspect", "repair"]:
		data.readiness = {"sol": state.sol, "health": state.rover_health, "power_kwh": state.power_kwh,
			"text": "Rover checked; exposed equipment visually inspected for dust. No dust fault sensor exists. Remaining kits: %d. Health: %.0f/100." % [data.stock.repair_kit, state.rover_health]}
	elif c.task == "navigate":
		assess_route(c.site)
	return_to_base(id)

func return_to_base(id: String) -> bool:
	if data.is_empty() or not IDS.has(id):
		return false
	var c: Dictionary = data.crew[id]
	c.target = LOCKER + Vector3(-1.0, 0, 0) if not str(c.cargo).is_empty() else homes[id]
	c.path = route_service.route(actors[id].position, c.target)
	_release(id)
	if c.path.is_empty():
		c.checkpoint = "Returning"
		_block(id, "Return path blocked. Holding tools and samples here; request a route assessment.")
		return false
	_report(id, "Returning", "Returning with carried items; nothing is transferred until arrival.")
	if id == "water_recycler" and data.crew.food_storage.task == "buddy":
		return_to_base("food_storage")
	return true

func _finish(id: String) -> void:
	var c: Dictionary = data.crew[id]
	if not str(c.cargo).is_empty():
		if not data.samples[c.cargo].labelled:
			c.step = 3
			c.progress = 0.0
			_report(id, "Working", "Labeling the carried sample before storage.")
			return
		data.samples[c.cargo].storage = "base"
		data.samples[c.cargo].carrier = ""
		c.cargo = ""
		c.container = false
		_restore_instrument()
		# After deposit, physically return to the original station.
		c.target = homes[id]
		c.path = route_service.route(actors[id].position, c.target)
		if not c.path.is_empty():
			return
		c.checkpoint = "Returning"
		_block(id, "Samples deposited safely, but the path back to my station is blocked.")
		return
	if c.container:
		data.stock.container += 1
		c.container = false
	if c.kit:
		data.stock.repair_kit += 1
		c.kit = false
	_release(id)
	c.last_sol = state.sol
	c.task = ""
	c.progress = 0.0
	_report(id, "Available", "Back at base. Work and carried materials are recorded.")

func pause_work(id: String) -> void:
	if data.is_empty() or data.crew[id].phase in ["Available", "Paused"]:
		return
	var c: Dictionary = data.crew[id]
	c.checkpoint = c.phase if not c.phase in ["Blocked", "Waiting for assistance", "Responding to a hazard"] else c.checkpoint
	_release(id)
	_report(id, "Paused", "Paused at this step. Carried items remain with me; tools are released for the team.")

func resume_work(id: String) -> bool:
	if data.is_empty() or not session.can_advance():
		return false
	var c: Dictionary = data.crew[id]
	if not c.phase in ["Paused", "Blocked", "Waiting for assistance", "Responding to a hazard"]:
		return false
	if c.checkpoint == "Returning":
		return return_to_base(id)
	if c.checkpoint == "Preparing":
		return _prepare(id)
	if not reserve(id, _tools(c.task) + ["site:" + str(c.site)]):
		_block(id, "Required shared tools are still reserved by another astronaut.")
		return false
	if c.task == "sample" and not _player_near(id, config.companion_distance_m):
		return false
	if c.checkpoint == "Traveling":
		c.path = route_service.route(actors[id].position, c.target)
		if c.path.is_empty():
			_block(id, "No safe path. Hold position or approve another destination.")
			return false
	_report(id, c.checkpoint, "Resuming from the last valid step.")
	return true

func assist(id: String) -> bool:
	if data.is_empty() or not _player_near(id) or get_tree().paused or not session.can_advance():
		return false
	var c: Dictionary = data.crew[id]
	if c.phase == "Preparing":
		c.progress = minf(config.prepare_seconds, c.progress + config.prepare_seconds * 0.5)
		_report(id, "Preparing", "Checking and packing the tools together.")
		return true
	if c.phase == "Traveling":
		c.carry_assistance = true
		_report(id, "Traveling", "Helping carry the equipment. Stay beside me along the checked route.")
		return true
	if c.phase == "Waiting for assistance":
		if c.task == "deploy" and c.step == 2:
			c.joint_verification = true
		return resume_work(id)
	if c.phase != "Working" or not c.task in STEPS:
		return false
	if c.task == "deploy" and c.step == 2:
		c.joint_verification = true
	c.progress = minf(config.step_seconds, c.progress + config.step_seconds * 0.5)
	_report(id, "Working", "Thank you. Working together: " + str(STEPS[c.task][c.step]))
	return true

static func valid_save(saved: Dictionary, legacy := false) -> bool:
	if saved.is_empty():
		return true
	for key in ["crew", "locks", "samples", "instrument", "stock", "player_cargo", "routes", "readiness"]:
		if not saved.get(key) is Dictionary:
			return false
	if not saved.get("log") is Array or saved.log.size() > 100 or not saved.get("power_priority") in ["science", "maintenance"]:
		return false
	if saved.has("pending_deployment") and saved.pending_deployment not in ["instrument_a", "instrument_b"]:
		return false
	if not legacy and saved.crew.size() != IDS.size():
		return false
	for inventory in [saved.stock, saved.player_cargo]:
		for item in ["container", "repair_kit"]:
			if not inventory.get(item) is int or inventory[item] < 0:
				return false
	var valid_ids: Array = IDS + (["power_console"] if legacy and saved.crew.has("power_console") else [])
	for id in valid_ids:
		if not saved.crew.get(id) is Dictionary:
			return false
		var c: Dictionary = saved.crew[id]
		for key in ["phase", "task", "site", "message", "checkpoint", "cargo"]:
			if not c.get(key) is String:
				return false
		for key in ["position", "target"]:
			if not c.get(key) is Vector3 or not c[key].is_finite():
				return false
		if not c.get("path") is PackedVector3Array or not c.get("step") is int or not c.get("progress") is float:
			return false
		for point in c.path:
			if not point.is_finite():
				return false
		if not c.phase in ["Available", "Preparing", "Traveling", "Working", "Recording results", "Returning", "Waiting for assistance", "Blocked", "Paused", "Responding to a hazard"]:
			return false
		if c.task != "" and not c.task in STEPS and not c.task in ["buddy", "follow"]:
			return false
		if not is_finite(c.progress) or c.progress < 0 or c.step < 0:
			return false
		if c.task in STEPS and c.step > STEPS[c.task].size():
			return false
		for key in ["container", "kit", "auto_attempted", "alternative"]:
			if not c.get(key) is bool:
				return false
		if not c.get("last_sol") is int:
			return false
	for item in saved.locks:
		if not item is String or not saved.locks[item] in valid_ids:
			return false
	for site in saved.samples:
		var sample: Variant = saved.samples[site]
		if not site in SITES or not sample is Dictionary:
			return false
		if not sample.get("location") is Vector3 or not sample.location.is_finite() or not sample.get("storage") in ["carried", "base"]:
			return false
		for key in ["id", "collector", "carrier", "observation"]:
			if not sample.get(key) is String:
				return false
		if not sample.get("labelled") is bool or not sample.get("photographed") is bool or not sample.get("sol") is int:
			return false
	for c in saved.crew.values():
		if not c.cargo.is_empty() and not saved.samples.has(c.cargo):
			return false
	if not saved.instrument.is_empty():
		var instrument_state: Dictionary = saved.instrument
		if not instrument_state.get("position") is Vector3 or not instrument_state.position.is_finite():
			return false
		if not instrument_state.get("status") in ["positioned", "verified", "operational", "battery depleted"] or not instrument_state.get("site") in SITES:
			return false
		if not instrument_state.get("uptime") is float or not is_finite(instrument_state.uptime) or instrument_state.uptime < 0.0:
			return false
		if not instrument_state.get("photographed") is bool or not instrument_state.get("measurements") is String:
			return false
	for route in saved.routes.values():
		if not route is Dictionary or not route.get("text") is String:
			return false
	for entry in saved.log:
		if not entry is Dictionary or not entry.get("sol") is int or not entry.get("text") is String:
			return false
	return true

static func migrate_legacy(saved: Dictionary) -> void:
	if saved.is_empty() or not saved.crew.has("power_console"):
		return
	# Keep Alex's current job and carried sample; queue the retired actor's
	# deployment using the instrument's existing recorded progress.
	var retired: Dictionary = saved.crew.power_console
	if retired.task == "deploy" and retired.site in ["instrument_a", "instrument_b"]:
		saved.pending_deployment = retired.site
	if retired.container:
		saved.stock.container += 1
	if retired.kit:
		saved.stock.repair_kit += 1
	for item in saved.locks.keys():
		if saved.locks[item] == "power_console":
			saved.locks.erase(item)
	if saved.crew.food_storage.task == "buddy":
		var buddy: Dictionary = saved.crew.food_storage
		buddy.task = ""
		buddy.phase = "Available"
		buddy.path = PackedVector3Array()
		buddy.message = "Instrument team reassigned to Alex. Ready for orders."
	saved.crew.erase("power_console")

func collect_supply(item: String) -> bool:
	if data.is_empty() or not item in ["container", "repair_kit"] or world.get_node("Outpost/Astronaut").global_position.distance_to(LOCKER) > 3.5:
		return false
	if data.stock[item] <= 0 or data.player_cargo[item] >= 1:
		return false
	data.stock[item] -= 1
	data.player_cargo[item] += 1
	changed.emit()
	return true

func deliver(id: String, item: String) -> bool:
	if data.is_empty() or not _player_near(id) or not item in ["container", "repair_kit"] or data.player_cargo[item] <= 0:
		return false
	var c: Dictionary = data.crew[id]
	var key := "container" if item == "container" else "kit"
	if c[key] or (item == "container" and id != "water_recycler") or (item == "repair_kit" and id != "food_storage"):
		return false
	c[key] = true
	data.player_cargo[item] -= 1
	changed.emit()
	return true

func consume_manual_repair() -> bool:
	if data.is_empty():
		return false
	var near_base: bool = world.get_node("Outpost/Rover").position.length() <= config.survey_radius_m
	if data.locks.has("rover_worksite"):
		return false
	var carried: bool = data.player_cargo.repair_kit > 0
	var inventory: Dictionary = data.player_cargo if carried else data.stock
	if not carried and not near_base:
		return false
	if inventory.repair_kit <= 0 or state.materials < config.repair_materials:
		return false
	inventory.repair_kit -= 1
	state.materials -= config.repair_materials
	changed.emit()
	return true

func assess_route(site: String) -> Dictionary:
	if not SITES.has(site):
		return {"text": "Unknown destination. Only marked local locations have been surveyed."}
	var path: PackedVector3Array = route_service.route(homes.crew_briefing, SITES[site])
	var distance := 0.0
	var prior: Vector3 = homes.crew_briefing
	for point in path:
		distance += prior.distance_to(point)
		prior = point
	var report := {"reachable": not path.is_empty(), "path": path, "metres": distance,
		"return_oxygen_kg": distance * 2.0 * config.oxygen_per_metre_kg,
		"text": "Checked local corridor: %.1f m one way; %.4f kg modeled round-trip oxygen per astronaut. Beyond the marked landing area is unassessed." % [distance, distance * 2.0 * config.oxygen_per_metre_kg] if not path.is_empty() else "The local route is blocked. Hold at base; no verified alternative yet."}
	data.routes[site] = report
	return report

func follow(id: String) -> bool:
	if data.is_empty() or not _player_near(id, config.companion_distance_m):
		return false
	var c: Dictionary = data.crew[id]
	if c.phase != "Available" or not reserve(id, ["field_team"]):
		return false
	c.task = "follow"
	c.site = ""
	c.target = world.get_node("Outpost/Astronaut").position + Vector3(-1.3, 0, 0)
	c.path = route_service.route(actors[id].position, c.target)
	if c.path.is_empty():
		c.checkpoint = "Traveling"
		_block(id, "Cannot reach you safely. Stay within the surveyed local area.")
		return false
	_report(id, "Traveling", "Accompanying you within the marked landing area.")
	return true

func _update_visual(id: String, moving: bool) -> void:
	if id == "crew_briefing" and state != null and state.sol >= 6 and not state.rover_expedition.get("completed", []).has(2):
		labels[id].hide()
		props[id].hide()
		return
	if data.is_empty():
		return
	var c: Dictionary = data.crew[id]
	labels[id].text = SPECIALTIES[id] + "\n" + c.phase + (" · " + str(c.step + 1) if c.phase == "Working" else "")
	props[id].visible = not c.phase == "Available"
	# Existing walk clip plus visible camera/tool movement; no new character assets.
	props[id].position.y = 1.05 + (sin(c.progress * 2.0) * 0.08 if c.phase == "Working" else 0.0)
	props[id].rotation.x = sin(c.progress * 2.0) * 0.3 if c.phase == "Working" else 0.0
	var photo: bool = c.task in STEPS and c.phase == "Working" and c.step < STEPS[c.task].size() and "Photograph" in STEPS[c.task][c.step]
	props[id].position.y = 1.4 if photo else props[id].position.y
	props[id].get_node("CameraLens").visible = photo
	for side in [-1, 1]:
		var tong: MeshInstance3D = props[id].get_node("Tong" + str(side))
		tong.visible = c.task == "sample" and c.phase == "Working" and c.step == 2
		tong.rotation.z = side * (0.12 + absf(sin(c.progress * 1.5)) * 0.12)
	for node in actors[id].find_children("*", "AnimationPlayer", true, false):
		var clip := "moon_walk" if moving else "idle"
		if node.has_animation(clip) and node.current_animation != clip:
			node.get_animation(clip).loop_mode = Animation.LOOP_LINEAR
			node.play(clip, 0.18)
			node.speed_scale = 0.55 if moving else 1.0

func describe(id: String) -> String:
	if id not in IDS:
		return "Power console: engineering telemetry. Speak with Sam for fieldwork."
	if data.is_empty():
		return SPECIALTIES[id] + ": start the mission to begin fieldwork."
	var c: Dictionary = data.crew[id]
	var text := "%s\n%s — %s\n" % [SPECIALTIES[id], c.phase, c.message]
	if c.task in STEPS:
		text += "Step %d / %d · %.0f%%\n" % [mini(c.step + 1, STEPS[c.task].size()), STEPS[c.task].size(), minf(100, c.progress / config.step_seconds * 100)]
	if id == "water_recycler":
		for sample in data.samples.values():
			text += "\n%s · %s · %s · %s" % [sample.id, sample.location, sample.storage, sample.observation]
	if id == "water_recycler":
		text += "Seismometers detect ground motion. This battery-powered game instrument needs leveling and a local self-test; it logs locally, without a cable to base.\n"
		text += str(data.instrument.get("measurements", "Instrument packed. Choose a marked deployment site."))
	elif id == "food_storage":
		text += str(data.readiness.get("text", "No field inspection recorded yet."))
		text += "\nKits at base: %d · materials %.1f · priority: %s" % [data.stock.repair_kit, state.materials, data.power_priority]
	else:
		for other in IDS:
			var distance: float = actors[id].position.distance_to(actors[other].position)
			text += "\n%s: %s" % [SPECIALTIES[other], str(data.crew[other].phase) + " at " + str(actors[other].position) if distance <= config.radio_range_m and not _active_event("comms_blackout") else "No current radio contact; location unconfirmed."]
		for route in data.routes.values():
			text += "\n" + route.text
		for entry in data.log.slice(maxi(0, data.log.size() - 5)):
			text += "\nSol %d: %s" % [entry.sol, entry.text]
	return text

func _active_event(event_id: String) -> bool:
	for event in state.active_events:
		if event.get("event_id") == event_id:
			return true
	return false

func command(id: String, action: String, argument := "") -> bool:
	if data.is_empty() or get_tree().paused or not IDS.has(id):
		return false
	var ok := true
	match action:
		"sample", "deploy", "inspect", "repair", "navigate": ok = assign(id, action, argument)
		"pause": pause_work(id)
		"resume": ok = resume_work(id)
		"assist": ok = assist(id)
		"return": ok = return_to_base(id)
		"regroup":
			for other in IDS:
				if data.crew[other].phase != "Available":
					return_to_base(other)
		"follow": ok = follow(id)
		"collect": ok = collect_supply(argument)
		"deliver": ok = deliver(id, argument)
		"priority":
			if id == "food_storage" and argument in ["science", "maintenance"]:
				data.power_priority = argument
		"assess":
			var assessment := assess_route(argument)
			data.crew[id].message = assessment.text
		"alternative":
			var c: Dictionary = data.crew[id]
			var path: PackedVector3Array = route_service.route(actors[id].position, c.target)
			c.alternative = not path.is_empty()
			c.path = path
			c.message = "I found a checked local approach. Approve it to continue." if c.alternative else "No verified alternative. Hold position, clear the obstacle or change plans."
		"approve":
			ok = data.crew[id].alternative and resume_work(id)
		"decline":
			data.crew[id].auto_attempted = true
			data.crew[id].message = "Optional detour declined. Standing by at base."
		"status": pass
		_: ok = false
	if not ok and not data.crew[id].phase in ["Blocked", "Waiting for assistance"]:
		data.crew[id].message = "Cannot do that now. Check task state, proximity, shared tools and available supplies."
	changed.emit()
	return ok

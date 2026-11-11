extends Node3D
## Marks damaged structures in the world and runs the repair minigame on them.
## Damage itself lives in MissionState.damaged_structures; this only shows and clears it.
const Rules = preload("res://src/simulation/rover_expedition.gd")
const Minigame = preload("res://src/ui/repair_minigame.gd")
var world: Node3D
var session: Node
var points: Dictionary = {} # structure id -> Area3D on that structure
var minigame: CanvasLayer

func _ready() -> void:
	name = "StructureRepairs"
	world = get_parent()
	session = get_node("/root/MissionSession")

func _process(_delta: float) -> void:
	var state: Variant = session.dashboard_state
	var damaged: Dictionary = {} if state == null else state.damaged_structures
	# Structures are rebuilt when moved, so a marker can lose its parent at any time.
	for id in points.keys():
		# Also re-mark when the marked structure is replaced (e.g. the free panel removed).
		if not damaged.has(id) or not is_instance_valid(points[id]) or points[id].get_parent() != _structure(str(id)): _unmark(id)
	for id in damaged:
		if points.has(id): continue
		var target := _structure(str(id))
		if target != null: points[id] = _mark(str(id), target)
	# The storm repairs are over once nothing marked is left to fix.
	var data: Dictionary = world.get_node("RoverTraining").data
	if Rules.aftermath(data) == "repairs" and points.is_empty() and not is_instance_valid(minigame):
		data["aftermath"] = "alert"
		session.capture_sol_checkpoint()
		session.state_changed.emit()

func _structure(id: String) -> Node3D:
	if id == "solar_panel":
		var placement := world.get_node_or_null("SolarPlacement")
		if placement == null: return null
		# The damage covers every panel; mark the free one, or a bought one if it is gone.
		if placement.placed: return placement.solar_panel
		return placement.extra_panels[0] if not placement.extra_panels.is_empty() else null
	return world.construction_view.completed.get(id)

func _mark(id: String, target: Node3D) -> Area3D:
	var hull := Vector3(3.0, 2.2, 3.0) # The hand-placed solar panel.
	var model := target.get_node_or_null("NASAModel")
	if model != null and model.has_meta("hull_size"): hull = model.get_meta("hull_size")
	var area := Area3D.new()
	area.name = "RepairPoint"
	area.set_meta("interaction_id", "repair:" + id)
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	# Reach from anywhere beside the structure, whatever its size.
	sphere.radius = maxf(hull.x, hull.z) * 0.5 + 1.5
	shape.shape = sphere
	shape.position.y = 0.9
	area.add_child(shape)
	var label := Label3D.new()
	label.text = "DAMAGED\nPress E to repair · costs supplies"
	label.font = world.tag_font(700)
	label.font_size = 44
	label.pixel_size = 0.006
	label.outline_size = 10
	label.outline_modulate = Color(0.02, 0.03, 0.05, 0.85)
	label.modulate = Color("ff8a3d")
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.position.y = hull.y + 1.0
	area.add_child(label)
	target.add_child(area)
	area.body_entered.connect(world._on_interaction_area_entered.bind(area))
	area.body_exited.connect(world._on_interaction_area_exited.bind(area))
	return area

func _unmark(id: String) -> void:
	var area: Variant = points[id]
	points.erase(id)
	if is_instance_valid(area):
		world.get_node("Outpost/Astronaut").clear_nearby_interactable(area)
		area.queue_free()

## Nearest damaged structure to a point, for the objective marker (null when none).
func nearest(from: Vector3) -> Variant:
	var best: Variant = null
	for area in points.values():
		if is_instance_valid(area) and (best == null or from.distance_to(area.global_position) < from.distance_to(best)):
			best = area.global_position
	return best

func start(id: String) -> void:
	var state: Variant = session.dashboard_state
	if state == null or not state.damaged_structures.has(id) or is_instance_valid(minigame): return
	var player := world.get_node("Outpost/Astronaut")
	if player.ui_blocked or player.seated: return
	# Repairs use the crew's spare parts and time: half the structure's build cost.
	var cost: Dictionary = session.dashboard_simulator.repair_cost(state, id)
	var missing: String = session.dashboard_simulator.missing_for(state, cost)
	var hud := world.get_node("MissionHUD")
	if not missing.is_empty():
		hud.notice.text = "Not enough %s to repair it. Repair costs %s." % [missing, world.cost_text(cost)]
		return
	hud.notice.text = "Repair cost: " + world.cost_text(cost)
	minigame = Minigame.new()
	minigame.player = player
	minigame.title_text = "Solar panel" if id == "solar_panel" else str(session.dashboard_simulator._find_structure(id).get("name", id.replace("_", " ")))
	minigame.finished.connect(func(repaired: bool):
		if repaired: session.repair_structure(id))
	add_child(minigame)

extends CanvasLayer
## Always-visible objective and matching camera-projected destination marker.
var title: Label
var detail: Label
var marker: Label
var session: Node
var world: Node3D
var expeditions: Node
var expedition_view: Dictionary = {}
var mission_font: SystemFont

func _ready() -> void:
	name = "MissionTracker"
	layer = 87
	world = get_parent()
	session = get_node("/root/MissionSession")
	expeditions = world.get_node("RoverTraining")
	expeditions.hud_changed.connect(func(view: Dictionary): expedition_view = view)
	mission_font = preload("res://src/ui/ui_style.gd").objective_font()
	title = _label(20)
	title.position = Vector2(22, 20)
	title.size = Vector2(410, 36)
	title.text = ""
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	detail = _label(15)
	detail.position = Vector2(52, 60)
	detail.size = Vector2(360, 65)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	marker = _label(24)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.size = Vector2(140, 70)
	marker.hide()

func _label(font_size: int) -> Label:
	var result := preload("res://src/ui/ui_style.gd").objective_label(mission_font, font_size)
	add_child(result)
	return result

func _process(_delta: float) -> void:
	marker.hide()
	var rover_active: bool = expeditions.driver.active
	title.size.x = 360 if rover_active else 410
	var state = session.dashboard_state
	# Read only the authoritative campaign and expedition objectives.
	if state == null:
		title.text = ""
		detail.text = ""
		return
	var objective: String = str(state.mission_outcome.get("primary_objective", ""))
	var instruction: String = session.elapsed_time_label()
	var destination: Variant = null
	var player: Node3D = world.get_node("Outpost/Astronaut")
	var observer: Node3D = expeditions.driver if expeditions.driver.active else player
	var running: bool = state.mission_outcome.get("status", "") == "in_progress"
	if not running:
		instruction = str(state.mission_outcome.get("status", "")).capitalize()
	elif preload("res://src/world/dust_storm.gd").pending(expeditions.data):
		objective = "Dust storm"
		instruction = "Visibility reduced and solar power halved for the rest of this Earth day. Wait for the dust to clear."
	elif expeditions.Rules.radiation(expeditions.data) == "alert":
		objective = "Radiation alert"
		instruction = "Talk with Maya: press E when she is nearby."
		destination = world.get_node("Outpost/crew_briefing").global_position
	elif expeditions.Rules.radiation(expeditions.data) == "orders":
		var storm: Node = world.get_node("RadiationStorm")
		objective = "Get the crew to shelter"
		instruction = "Order each crew member into the radiation habitat (press E): %d / 3 · wave in %d s" % [expeditions.data.get("radiation_told", []).size(), storm.seconds_left()]
		destination = storm.next_crew_position(player.global_position)
	elif expeditions.Rules.radiation(expeditions.data) == "wave":
		objective = "Radiation wave"
		var exposed: int = 3 - (expeditions.data.get("radiation_told", []).size() if world.get_node("RadiationStorm").shelter_built() else 0)
		instruction = "Solar particles are hitting the base. %s Wait for the wave to pass." % ("All crew are sheltered." if exposed == 0 else "%d crew exposed: they need treatment and will work slower." % exposed)
	elif not session.maya_intro_complete:
		objective = "Talk with Maya"
		instruction = "Press E when Maya is nearby."
		destination = world.get_node("Outpost/crew_briefing").global_position
	elif expeditions.Rules.debrief(expeditions.data) in ["pending", "retry"]:
		objective = "Mission review"
		instruction = "Talk with Maya: press E when she is nearby." if expeditions.Rules.debrief(expeditions.data) == "pending" else "Build up power, water, oxygen and food, then talk with Maya again."
		destination = world.get_node("Outpost/crew_briefing").global_position
	elif expeditions.Rules.aftermath(expeditions.data) in ["briefing", "alert"]:
		objective = "Talk with Maya"
		instruction = "Press E when Maya is nearby."
		destination = world.get_node("Outpost/crew_briefing").global_position
	elif expeditions.Rules.aftermath(expeditions.data) == "repairs":
		var repairs: Node = world.get_node("StructureRepairs")
		objective = "Repair the storm damage"
		instruction = "%d damaged. Press E at a marked structure, or talk to Maya to leave them." % repairs.points.size()
		destination = repairs.nearest(player.global_position)
	elif not session.construction_ready() and expeditions.data.get("completed", []).is_empty() and expeditions.data.get("mission", -1) < 0:
		var built := 0
		for station in ["maya_station", "alex_station", "sam_station"]:
			if session.station_placements.has(station): built += 1
		objective = "Build the solar panel and 3 workstations"
		instruction = "Solar panels: %d/8 · Workstations: %d/3\nPress B to open construction." % [int(session.solar_placement.has("transform")) + session.extra_panels.size(), built]
	elif session.construction_ready() and expeditions.data.get("completed", []).is_empty() and expeditions.data.get("mission", -1) < 0 and not rover_active:
		if not session.crew_introductions.get("rover_briefing", false):
			objective = "Speak with Maya"
			instruction = "Press E near Maya, then choose Talk / Status."
			destination = world.get_node("Outpost/crew_briefing").global_position
		else:
			objective = "Go to the Lander and Drive the Rover"
			instruction = "Press E at the hatch to enter, then press R to control the rover."
			destination = world.get_node("LanderAccess").landing
	elif not expeditions.data.is_empty():
		var assignment: int = expeditions.available_assignment()
		if assignment >= 0:
			objective = expeditions.Rules.TITLES[assignment]
			instruction = str(expedition_view.get("objective", ""))
			if expeditions.data.location == "expedition":
				var navigation: Dictionary = expeditions._navigation()
				destination = navigation.get("destination")
			else:
				destination = expeditions.departure.global_position
			if not rover_active:
				objective = "Take control of the Rover again to start the next mission"
				instruction = "Enter the lander with E, then press R for " + expeditions.Rules.TITLES[assignment] + "."
				destination = world.get_node("LanderAccess").landing
	if rover_active and not expedition_view.is_empty():
		objective = str(expedition_view.get("title", objective))
		instruction = str(expedition_view.get("objective", instruction))
	# The first two completed expeditions hand control back to Maya, not Lifeline.
	var completed: Array = expeditions.data.get("completed", [])
	if running and completed.has(0) and completed.has(1) and not completed.has(2) and expeditions.data.get("mission", -1) != 2 and str(expeditions.data.get("aftermath", "briefing")) in ["briefing", "alert"]:
		objective = "Press R to exit Rover and talk to Maya." if rover_active else "Talk with Maya"
		instruction = "Exit the lander with E, then approach Maya." if rover_active else "Press E near Maya, then choose Talk / Status."
		destination = world.get_node("Outpost/crew_briefing").global_position
	title.text = "◆  " + objective
	detail.text = instruction
	if destination is Vector3:
		detail.text += "\n%.0f m" % observer.global_position.distance_to(destination)
	# Measure this frame's text before stacking instructions, status and health.
	var title_bottom: float = title.position.y + maxf(title.size.y, title.get_minimum_size().y)
	detail.position = Vector2(22, maxf(76, title_bottom + 8)) if rover_active else Vector2(52, maxf(60, title_bottom + 6))
	detail.size.x = 360
	if rover_active:
		var status_label: Label = expeditions.hud.result
		status_label.position = Vector2(22, detail.position.y + maxf(detail.size.y, detail.get_minimum_size().y) + 12)
		var health_y: float = status_label.position.y + (maxf(status_label.size.y, status_label.get_minimum_size().y) if not status_label.text.is_empty() else 0) + 18
		expeditions.driver.health_title.position.y = health_y
		expeditions.driver.health_bar.position.y = health_y + 26
	if destination is Vector3:
		var distance := observer.global_position.distance_to(destination)
		var camera := get_viewport().get_camera_3d()
		if camera == null: return
		var size := get_viewport().get_visible_rect().size
		var point: Vector3 = destination + Vector3.UP * 1.4
		var screen := camera.unproject_position(point)
		var behind := camera.is_position_behind(point)
		if behind:
			screen = Vector2(size.x - 80 if (point - camera.global_position).dot(camera.global_basis.x) > 0 else 80, size.y * 0.5)
		var bounded := screen.clamp(Vector2(80, 190), Vector2(maxf(81, size.x - 80), maxf(191, size.y - 80)))
		marker.text = "◆\n%.0f m" % distance
		marker.position = bounded - marker.size * 0.5
		marker.show()

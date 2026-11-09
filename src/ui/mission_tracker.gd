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
	detail.position = Vector2(22, maxf(76, title.position.y + title.size.y + 8)) if rover_active else Vector2(52, 60)
	detail.size.x = 360
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
		instruction = "Visibility reduced and solar power halved this sol. Wait for the dust to clear."
	elif not session.maya_intro_complete:
		objective = "Talk with Maya"
		instruction = "Press E when Maya is nearby."
		destination = world.get_node("Outpost/crew_briefing").global_position
	elif not session.construction_ready() and expeditions.data.get("completed", []).is_empty() and expeditions.data.get("mission", -1) < 0:
		objective = "Build the solar panel and three crew stations"
		instruction = "Press B to open construction."
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
	if rover_active and not expedition_view.is_empty():
		objective = str(expedition_view.get("title", objective))
		instruction = str(expedition_view.get("objective", instruction))
	title.text = "◆  " + objective
	detail.text = instruction
	if destination is Vector3:
		detail.text += "\n%.0f m" % observer.global_position.distance_to(destination)
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

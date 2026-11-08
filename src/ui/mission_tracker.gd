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
	mission_font = SystemFont.new()
	mission_font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	mission_font.font_weight = 500
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
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", mission_font)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", Color("f2d58c"))
	result.add_theme_color_override("font_outline_color", Color("101522"))
	result.add_theme_constant_override("outline_size", 3)
	add_child(result)
	return result

func _process(_delta: float) -> void:
	marker.hide()
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
	title.text = "◆  " + objective
	detail.text = instruction
	if destination is Vector3:
		var distance := observer.global_position.distance_to(destination)
		detail.text += "  %.0f m" % distance
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

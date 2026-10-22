extends Node
## Hatch interaction for the supplied Apollo capsule, including its own interior.
var player: CharacterBody3D
var landing: Vector3
var seat_eye: Vector3
var button: Button
var fade: ColorRect
var busy := false
var inside := false
var exterior_first_person := false
var rover_button: Button

func _ready() -> void:
	player = get_parent().get_node("Outpost/Astronaut")
	var habitat := get_parent().get_node("Outpost/Habitat")
	landing = habitat.get_node("HatchApproach").global_position
	seat_eye = habitat.get_node("SeatedEye").global_position
	inside = player.global_position.distance_to(seat_eye - Vector3(0, 1.1, 0)) < 0.2
	if inside:
		player.set_seated(true, seat_eye)
	var layer := CanvasLayer.new()
	layer.layer = 90
	add_child(layer)
	button = Button.new()
	button.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	button.offset_left = -180
	button.offset_right = 180
	button.offset_top = -110
	button.offset_bottom = -52
	button.add_theme_font_size_override("font_size", 20)
	button.pressed.connect(transfer)
	button.hide()
	layer.add_child(button)
	rover_button = Button.new()
	rover_button.position = Vector2(20, 110)
	rover_button.custom_minimum_size = Vector2(380, 52)
	rover_button.text = "Rover mission training  [R]"
	rover_button.pressed.connect(func(): get_parent().get_node("RoverHull").start_control())
	layer.add_child(rover_button)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	layer.add_child(fade)

func door_available() -> bool:
	if inside:
		return true
	var offset: Vector3 = player.global_position - landing
	return absf(offset.y) < 0.75 and Vector2(offset.x, offset.z).length() < 1.1

func _process(_delta: float) -> void:
	var driving: bool = get_parent().get_node("RoverHull").active
	rover_button.visible = inside and not busy and not driving and not player.ui_blocked
	var session := get_node("/root/MissionSession")
	rover_button.disabled = session.dashboard_state != null and not session.can_advance()
	rover_button.text = "Start rover mission training  [R]" if session.dashboard_state == null else ("Resolve mission decisions before driving" if rover_button.disabled else "Rover mission training  [R]")
	rover_button.tooltip_text = "Surface Survey → Frozen Horizon → Lifeline. Remote rover controls: hold F to scan, E to interact, L for headlights."
	button.visible = not busy and not player.ui_blocked and door_available()
	button.text = "Get outside  [E]" if inside else "Get inside  [E]"
	button.tooltip_text = "Press E to enter or exit. Esc opens the pause menu."

func _input(event: InputEvent) -> void:
	if get_parent().get_node("RoverHull").active:
		return
	if busy:
		get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E and button.visible:
			get_viewport().set_input_as_handled()
			transfer()
		elif inside and event.keycode == KEY_V:
			# Stay in the seated view until exiting the capsule.
			get_viewport().set_input_as_handled()

func transfer() -> void:
	if busy or player.ui_blocked or get_parent().get_node("RoverHull").active or not door_available():
		return
	busy = true
	button.hide()
	player.ui_blocked = true
	player.set_physics_process(false)
	player.velocity = Vector3.ZERO
	player.jump_requested = false
	var hud := get_parent().get_node("MissionHUD")
	hud.set_process_input(false)
	fade.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(fade, "modulate:a", 1.0, 0.85).set_trans(Tween.TRANS_SINE)
	await tween.finished
	if not inside:
		exterior_first_person = player.first_person
		player.global_position = seat_eye - Vector3(0, 1.1, 0)
		player.set_seated(true, seat_eye)
	else:
		player.set_seated(false)
		player.global_position = landing
		player.camera_yaw = PI
		player.camera_pitch = -0.22
		player.set_first_person(exterior_first_person)
	inside = not inside
	player.nearby_interactable = null
	player._sync_camera_rig()
	await get_tree().create_timer(0.2).timeout
	tween = create_tween()
	tween.tween_property(fade, "modulate:a", 0.0, 0.85).set_trans(Tween.TRANS_SINE)
	await tween.finished
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player.ui_blocked = false
	player.set_physics_process(true)
	hud.set_process_input(true)
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	busy = false

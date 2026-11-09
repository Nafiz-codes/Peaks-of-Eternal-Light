extends Camera3D
## Debug-only noclip spectator. The world keeps running while controls detach.

var active := false
var speed := 30.0
var previous_camera: Camera3D
var previous_mouse_mode: int
var hint: Label
var hud: CanvasLayer
var hud_was_visible := true
var suspended_controls: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	far = 12000.0
	var overlay := CanvasLayer.new()
	overlay.layer = 100
	add_child(overlay)
	hint = Label.new()
	hint.position = Vector2(18, 135)
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	overlay.add_child(hint)
	hint.hide()

func toggle() -> void:
	if active:
		finish()
		return
	if not OS.is_debug_build() or get_tree().paused:
		return
	var world := get_parent()
	if world.get_node("Outpost/Astronaut").ui_blocked:
		return
	for window in world.find_children("*", "Window", true, false):
		if window.visible: return
	previous_camera = get_viewport().get_camera_3d()
	if previous_camera == null: return
	global_transform = previous_camera.global_transform
	fov = previous_camera.fov
	previous_mouse_mode = Input.mouse_mode
	hud = world.get_node("MissionHUD")
	hud_was_visible = hud.visible
	hud.hide()
	for path in ["Outpost/Astronaut", "SolarPlacement", "LanderAccess"]:
		var controller := world.get_node(path)
		suspended_controls[controller] = controller.process_mode
		controller.process_mode = Node.PROCESS_MODE_DISABLED
	active = true
	make_current()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	hint.show()
	_update_hint()

func finish() -> void:
	if not active: return
	active = false
	for controller in suspended_controls:
		if is_instance_valid(controller): controller.process_mode = suspended_controls[controller]
	suspended_controls.clear()
	if is_instance_valid(previous_camera): previous_camera.make_current()
	if is_instance_valid(hud): hud.visible = hud_was_visible
	hint.hide()
	Input.set_mouse_mode(previous_mouse_mode)

func _exit_tree() -> void:
	if active: finish()

func _input(event: InputEvent) -> void:
	if not OS.is_debug_build(): return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_F8 or (active and event.keycode == KEY_ESCAPE):
			toggle()
			get_viewport().set_input_as_handled()
			return
	if not active: return
	if event is InputEventMouseMotion:
		var settings := get_node("/root/GameSettings")
		var sensitivity: float = 0.003 * float(settings.values.sensitivity)
		rotation.y -= event.relative.x * sensitivity
		rotation.x = clampf(rotation.x - event.relative.y * sensitivity * (-1.0 if settings.values.invert_y else 1.0), -1.55, 1.55)
		rotation.z = 0.0
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: speed = minf(speed * 1.5, 1000.0)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: speed = maxf(speed / 1.5, 1.0)
		_update_hint()
	get_viewport().set_input_as_handled()

func _process(delta: float) -> void:
	if not active: return
	# Scripted world events may switch views; retain spectator ownership until exit.
	if not current:
		previous_camera = get_viewport().get_camera_3d()
		make_current()
	var direction := global_basis * Vector3(
		float(Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_A)),
		0.0,
		float(Input.is_physical_key_pressed(KEY_S)) - float(Input.is_physical_key_pressed(KEY_W)))
	direction += Vector3.UP * (float(Input.is_physical_key_pressed(KEY_E) or Input.is_physical_key_pressed(KEY_SPACE)) - float(Input.is_physical_key_pressed(KEY_Q) or Input.is_physical_key_pressed(KEY_CTRL)))
	global_position += direction.normalized() * speed * (5.0 if Input.is_key_pressed(KEY_SHIFT) else 1.0) * delta

func _update_hint() -> void:
	hint.text = "SPECTATOR · Noclip\nWASD: fly · Mouse: look · Space/Ctrl: up/down · Shift: boost\nWheel: speed (%d m/s) · F8 / Esc: return" % roundi(speed)

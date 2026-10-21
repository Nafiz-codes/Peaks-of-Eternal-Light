extends Node
## Persistent UI feedback; rover playback pauses with the simulation.
signal rover_startup_finished(owner_id: int)
const HOVER := preload("res://Assets/audio/sfx/ui_hover.wav")
const CLICK := preload("res://Assets/audio/sfx/ui_click.wav")
const ROVER := preload("res://Assets/audio/sfx/rover_start.mp3")
const ROVER_CINEMATIC := preload("res://Assets/audio/sfx/rover_takeover.wav")
var hover_player: AudioStreamPlayer
var click_player: AudioStreamPlayer
var rover_player: AudioStreamPlayer
var hover_interval := 0.075
var cursor_speed := 0.0
var last_motion_usec := 0
var last_hover_usec := -1000000
var last_hover_id := 0
var mouse_dirty := false
var click_frame := -1
var rover_owner_id := 0
var hover_count := 0
var click_count := 0
var startup_count := 0
var quitting := false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus_name in ["UI_SFX", "Gameplay_SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.get_bus_index(bus_name), "Effects")
	hover_player = _player(HOVER, "UI_SFX", -6.0)
	click_player = _player(CLICK, "UI_SFX", -12.0)
	rover_player = _player(ROVER, "Gameplay_SFX", -12.0)
	rover_player.process_mode = Node.PROCESS_MODE_PAUSABLE
	rover_player.finished.connect(_rover_finished)
	get_tree().node_added.connect(_register_deferred)
	_register_tree(get_tree().root)

func _player(stream: AudioStream, bus: String, level: float) -> AudioStreamPlayer:
	var result := AudioStreamPlayer.new()
	result.stream = stream
	result.bus = bus
	result.volume_db = level
	result.max_polyphony = 1
	add_child(result)
	return result

func _register_tree(node: Node) -> void:
	_register(node)
	for child in node.get_children(): _register_tree(child)

func _register_deferred(node: Node) -> void:
	_register_id.call_deferred(node.get_instance_id())

func _register_id(id: int) -> void:
	var node := instance_from_id(id)
	if is_instance_valid(node): _register(node)

func _register(node: Node) -> void:
	if not is_instance_valid(node): return
	if node is BaseButton:
		if not node.pressed.is_connected(play_ui_click): node.pressed.connect(play_ui_click)
		if node is OptionButton and not node.item_selected.is_connected(_option_selected):
			node.item_selected.connect(_option_selected)
	elif node is Slider:
		var callback := _slider_changed.bind(node)
		if not node.value_changed.is_connected(callback): node.value_changed.connect(callback)
		if not node.drag_ended.is_connected(_slider_released): node.drag_ended.connect(_slider_released)

func _slider_released(changed: bool) -> void:
	if changed: play_ui_click()

func _option_selected(_index: int) -> void:
	play_ui_click()

func _slider_changed(_value: float, slider: Slider) -> void:
	if slider.has_focus() and slider.is_visible_in_tree() and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		play_ui_click()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var now := Time.get_ticks_usec()
		var dt := clampf(float(now - last_motion_usec) / 1000000.0, 0.001, 0.1)
		var measured: float = event.relative.length() / dt
		cursor_speed = lerpf(cursor_speed, minf(measured, 3000.0), 1.0 - exp(-25.0 * dt))
		last_motion_usec = now
		mouse_dirty = true

func hover_pitch(speed: float) -> float:
	return lerpf(0.94, 1.14, clampf(speed / 1800.0, 0.0, 1.0))

func _process(delta: float) -> void:
	if Time.get_ticks_usec() - last_motion_usec > 120000:
		cursor_speed = lerpf(cursor_speed, 0.0, 1.0 - exp(-8.0 * delta))
	if not mouse_dirty: return
	mouse_dirty = false
	var target: Control = get_viewport().gui_get_hovered_control()
	while target != null and not (target is BaseButton or target is Slider):
		target = target.get_parent_control()
	var valid := target != null and target.is_visible_in_tree() and target.mouse_filter != Control.MOUSE_FILTER_IGNORE
	if target is BaseButton: valid = valid and not target.disabled
	if target is Slider: valid = valid and target.editable
	var id := target.get_instance_id() if valid else 0
	if id != last_hover_id:
		last_hover_id = id
		if id != 0: play_ui_hover(cursor_speed)

func play_ui_hover(speed: float) -> void:
	var now := Time.get_ticks_usec()
	if now - last_hover_usec < hover_interval * 1000000.0: return
	last_hover_usec = now
	hover_player.pitch_scale = hover_pitch(speed)
	hover_player.play()
	hover_count += 1

func play_ui_click() -> void:
	# World handlers and a button signal can confirm the same action in one frame.
	var frame := Engine.get_process_frames()
	if click_frame == frame: return
	click_frame = frame
	click_player.play()
	click_count += 1

func quit_with_click() -> void:
	if quitting: return
	quitting = true
	play_ui_click()
	await get_tree().create_timer(CLICK.get_length(), true).timeout
	get_tree().quit()

func play_rover_startup(owner_node: Node, cinematic := false) -> void:
	if rover_owner_id == owner_node.get_instance_id() and rover_player.playing: return
	rover_player.stop()
	rover_player.stream = ROVER_CINEMATIC if cinematic else ROVER
	rover_player.pitch_scale = 1.0
	rover_owner_id = owner_node.get_instance_id()
	rover_player.play()
	startup_count += 1

func cancel_rover_startup(owner_node: Node) -> void:
	if rover_owner_id != owner_node.get_instance_id(): return
	rover_player.stop()
	rover_owner_id = 0

func _rover_finished() -> void:
	var owner_id := rover_owner_id
	rover_owner_id = 0
	rover_startup_finished.emit(owner_id)

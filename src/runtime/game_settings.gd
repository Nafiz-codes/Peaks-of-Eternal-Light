extends Node

signal settings_changed

const DEFAULTS := {"master": 0.8, "music": 0.7, "effects": 0.8,
	"sensitivity": 1.0, "invert_y": false, "quality": 1, "fullscreen": false,
	"brightness": 1.0, "reduce_motion": false}
var values: Dictionary = DEFAULTS.duplicate()
var settings_path := "user://settings.cfg"
var brightness_layer: CanvasLayer
var brightness_rect: ColorRect

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var config := ConfigFile.new()
	if config.load(settings_path) == OK:
		for key in DEFAULTS:
			var value: Variant = config.get_value("settings", key, DEFAULTS[key])
			if typeof(value) == typeof(DEFAULTS[key]):
				values[key] = value
	for key in ["master", "music", "effects"]:
		values[key] = clampf(float(values[key]), 0.0, 1.0)
	values.sensitivity = clampf(float(values.sensitivity), 0.25, 3.0)
	values.brightness = clampf(float(values.brightness), 0.6, 1.5)
	values.quality = clampi(int(values.quality), 0, 2)
	brightness_layer = CanvasLayer.new()
	brightness_layer.layer = 95
	add_child(brightness_layer)
	brightness_rect = ColorRect.new()
	brightness_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	brightness_layer.add_child(brightness_rect)
	brightness_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/ui/display_brightness.gdshader")
	brightness_rect.material = material
	apply()

func change(key: String, value: Variant) -> void:
	values[key] = value
	apply()
	var config := ConfigFile.new()
	for name_ in values:
		config.set_value("settings", name_, values[name_])
	config.save(settings_path)

func apply() -> void:
	for entry in [["Master", "master"], ["Music", "music"], ["Effects", "effects"]]:
		var bus := AudioServer.get_bus_index(entry[0])
		if bus < 0:
			AudioServer.add_bus()
			bus = AudioServer.bus_count - 1
			AudioServer.set_bus_name(bus, entry[0])
			AudioServer.set_bus_send(bus, "Master")
		var volume := float(values[entry[1]])
		AudioServer.set_bus_mute(bus, volume <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(volume, 0.0001)))
	get_node("/root/MissionSession").reduce_motion = values.reduce_motion
	get_viewport().msaa_3d = Viewport.MSAA_4X if values.quality == 2 else (Viewport.MSAA_2X if values.quality == 1 else Viewport.MSAA_DISABLED)
	if DisplayServer.get_name() != "headless":
		var mode := DisplayServer.window_get_mode()
		if values.fullscreen and mode != DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
		elif not values.fullscreen and mode == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if is_instance_valid(brightness_rect):
		brightness_rect.visible = not is_equal_approx(values.brightness, 1.0)
		brightness_rect.material.set_shader_parameter("brightness", values.brightness)
	var scene := get_tree().current_scene
	if scene != null and scene.has_method("refresh_feedback") and scene.is_node_ready():
		scene.refresh_feedback()
	settings_changed.emit()

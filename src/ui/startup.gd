extends Node
## Owns every cinematic tween. The original selector becomes current_scene at handoff.
enum State { INTRO, MENU_ENTERING, MENU_IDLE, STARTING_MISSION, GAMEPLAY }
const SELECTOR := "res://scenes/lunar_landing_selector.tscn"
const UI = preload("res://src/ui/ui_style.gd")
var state := State.INTRO
var sequence: Tween
var world: Node3D
var layer: CanvasLayer
var canvas: Control
var backdrop: ColorRect
var astronaut: TextureRect
var navigation: Control
var credits: Array[Control] = []
var buttons: Array[Button] = []
var skip: Button
var dialog: PanelContainer
var dialog_body: VBoxContainer
var elapsed := 0.0
var astronaut_departure := 0.0
var moon_progress := 0.0
var final_offset := 0.0
var ready_for_mission := false
var reduced := false
var menu_reveal := 0.0
var load_failed := false

func _ready() -> void:
	get_node("/root/GameMenu").set_process_input(false)
	reduced = get_node("/root/GameSettings").values.reduce_motion
	ResourceLoader.load_threaded_request(SELECTOR)
	_build()
	get_viewport().size_changed.connect(_layout)
	_layout()
	_intro()

func _build() -> void:
	layer = CanvasLayer.new()
	layer.layer = 50
	add_child(layer)
	canvas = Control.new()
	layer.add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	backdrop = ColorRect.new()
	backdrop.color = Color("050710")
	canvas.add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A fixed, seeded field: no particle simulation or full-screen effects pass.
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for i in range(65):
		var star := ColorRect.new()
		backdrop.add_child(star)
		star.anchor_left = rng.randf()
		star.anchor_top = rng.randf()
		star.size = Vector2.ONE * rng.randf_range(1.0, 2.0)
		star.color = Color(0.65, 0.8, 1.0, rng.randf_range(0.08, 0.32))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
	astronaut = TextureRect.new()
	astronaut.texture = preload("res://Assets/startup/astronaut.jpg")
	astronaut.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	astronaut.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var material := ShaderMaterial.new()
	material.shader = preload("res://Assets/startup/astronaut.gdshader")
	astronaut.material = material
	astronaut.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(astronaut)
	astronaut.modulate.a = 0.0
	navigation = Control.new()
	canvas.add_child(navigation)
	navigation.modulate.a = 0.0
	var eyebrow := _label("T E A M   H I E R A R C H Y   /   L U N A R   S I M U L A T I O N", 12, Color("86a6bb"))
	navigation.add_child(eyebrow)
	eyebrow.position = Vector2(0, 0)
	var title := _label("PEAKS OF\nETERNAL LIGHTS", 44, Color("edf5fa"))
	navigation.add_child(title)
	title.position = Vector2(0, 34)
	var sub := _label("A journey to the lunar frontier", 17, Color("8ea2b3"))
	navigation.add_child(sub)
	sub.position = Vector2(2, 151)
	for i in range(4):
		var button := Button.new()
		button.text = ["START MISSION", "MISSION BRIEFING", "SETTINGS", "EXIT"][i]
		button.position = Vector2(0, 216 + i * 57)
		button.size = Vector2(390, 49)
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.add_theme_font_size_override("font_size", 18)
		for entry in [["normal", 0.12, 1], ["hover", 0.25, 3], ["focus", 0.28, 3], ["pressed", 0.4, 4], ["disabled", 0.08, 1]]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(0.35, 0.52, 0.65, entry[1])
			style.border_color = Color(0.7, 0.85, 0.94, 0.7)
			style.border_width_left = entry[2]
			style.border_width_right = entry[2]
			style.content_margin_left = 24
			button.add_theme_stylebox_override(entry[0], style)
		button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		button.disabled = true
		navigation.add_child(button)
		buttons.append(button)
		button.pressed.connect([_start_mission, _briefing, _settings, _exit][i])
		button.mouse_entered.connect(_highlight.bind(button, true))
		button.mouse_exited.connect(_highlight.bind(button, false))
		button.focus_entered.connect(_highlight.bind(button, true))
		button.focus_exited.connect(_highlight.bind(button, false))
	var hint := _label("↑ ↓  NAVIGATE     ENTER  SELECT", 12, Color("7894a9"))
	navigation.add_child(hint)
	hint.position = Vector2(0, 465)
	for entry in [["Made with", "Godot", "G A M E   E N G I N E"], ["Created for", "NASA Space Apps Challenge 2026", "I N D E P E N D E N T   C H A L L E N G E   P R O J E C T"], ["Developed by", "Team Hierarchy", "P E A K S   O F   E T E R N A L   L I G H T S"]]:
		var credit := VBoxContainer.new()
		credit.add_theme_constant_override("separation", 18)
		canvas.add_child(credit)
		for index in range(3):
			var text := _label(entry[index], 36 if index == 1 else 14, Color("e2edf6") if index == 1 else Color("839fb5"))
			text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			credit.add_child(text)
		credit.modulate.a = 0.0
		credits.append(credit)
	skip = Button.new()
	skip.text = "SKIP INTRO   /   ESC"
	skip.flat = true
	canvas.add_child(skip)
	skip.pressed.connect(_enter_menu)
	dialog = PanelContainer.new()
	dialog.add_theme_stylebox_override("panel", UI.style(Color("0d1724"), Color("59788e")))
	canvas.add_child(dialog)
	dialog_body = VBoxContainer.new()
	dialog_body.add_theme_constant_override("separation", 18)
	dialog.add_child(dialog_body)
	dialog.hide()

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label

func _layout() -> void:
	var viewport := get_viewport().get_visible_rect().size
	var factor := minf(viewport.x / 1360.0, viewport.y / 820.0)
	navigation.scale = Vector2.ONE * factor
	navigation.position = Vector2(viewport.x * 0.09, (viewport.y - 500 * factor) * 0.5)
	astronaut.size = Vector2(1180, 820) * maxf(factor, viewport.y / 820.0)
	for credit in credits:
		credit.size = Vector2(1100, 160)
		credit.scale = Vector2.ONE * factor
		credit.position = (viewport - credit.size * factor) * 0.5
		credit.pivot_offset = credit.size * 0.5
	skip.position = Vector2(viewport.x - 200, viewport.y - 55)
	dialog.size = Vector2(600, 500)
	dialog.scale = Vector2.ONE * factor
	dialog.position = (viewport - dialog.size * factor) * 0.5

func _intro() -> void:
	sequence = create_tween().set_parallel(true)
	for i in range(credits.size()):
		var credit := credits[i]
		var delay := i * 2.05
		sequence.tween_property(credit, "modulate:a", 1.0, 0.55).set_delay(delay).set_trans(Tween.TRANS_SINE)
		sequence.tween_method(func(progress: float):
			var viewport := get_viewport().get_visible_rect().size
			var factor := minf(viewport.x / 1360.0, viewport.y / 820.0)
			credit.scale = Vector2.ONE * factor * lerpf(1.025, 1.0, progress)
		, 0.0, 1.0, 2.25).set_delay(delay).set_trans(Tween.TRANS_SINE)
		sequence.tween_property(credit, "modulate:a", 0.0, 0.55).set_delay(delay + 1.7).set_trans(Tween.TRANS_SINE)
	sequence.chain().tween_callback(_enter_menu)

func _highlight(button: Button, active: bool) -> void:
	if state != State.MENU_IDLE or button.disabled: return
	var previous: Tween = button.get_meta("highlight") if button.has_meta("highlight") else null
	if previous: previous.kill()
	var tween := create_tween()
	button.set_meta("highlight", tween)
	tween.tween_property(button, "position:x", 7.0 if active or button.has_focus() else 0.0, 0.14).set_trans(Tween.TRANS_SINE)

func _enter_menu() -> void:
	if state != State.INTRO:
		return
	state = State.MENU_ENTERING
	if sequence: sequence.kill()
	skip.hide()
	sequence = create_tween().set_parallel(true)
	for credit in credits:
		sequence.tween_property(credit, "modulate:a", 0.0, 0.4)
	sequence.tween_property(astronaut, "modulate:a", 1.0, 1.2).set_trans(Tween.TRANS_SINE)
	sequence.tween_property(navigation, "modulate:a", 1.0, 0.8).set_delay(0.45)
	sequence.tween_property(self, "menu_reveal", 1.0, 1.0).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	sequence.chain().tween_callback(func():
		state = State.MENU_IDLE
		for button in buttons: button.disabled = false
		buttons[0].disabled = not ready_for_mission
		buttons[0].grab_focus() if ready_for_mission else buttons[1].grab_focus())

func _process(delta: float) -> void:
	elapsed += delta
	if not ready_for_mission and not load_failed and ResourceLoader.load_threaded_get_status(SELECTOR) == ResourceLoader.THREAD_LOAD_FAILED:
		load_failed = true
		buttons[0].text = "MOON COULD NOT LOAD"
		buttons[0].tooltip_text = "Check the Godot output for missing project assets."
	if not ready_for_mission and ResourceLoader.load_threaded_get_status(SELECTOR) == ResourceLoader.THREAD_LOAD_LOADED:
		world = (ResourceLoader.load_threaded_get(SELECTOR) as PackedScene).instantiate()
		add_child(world)
		world.process_mode = Node.PROCESS_MODE_DISABLED
		world.menu_layer.hide()
		world.hide()
		final_offset = world.camera.h_offset
		ready_for_mission = true
		if state == State.MENU_IDLE: buttons[0].disabled = false
	var viewport := get_viewport().get_visible_rect().size
	navigation.position.x = viewport.x * 0.09 - (1.0 - menu_reveal) * 28.0
	var drift := Vector2.ZERO
	if state == State.MENU_IDLE and not reduced:
		drift = (canvas.get_local_mouse_position() / viewport - Vector2.ONE * 0.5) * 10.0
		drift.y += sin(elapsed * 0.65) * 4.0
	astronaut.position = Vector2(viewport.x * 0.67 - astronaut.size.x * 0.5 - astronaut_departure * viewport.x * 1.65, viewport.y - astronaut.size.y + maxf(0.0, (astronaut.size.y - astronaut.size.x * 412.0 / 735.0) * 0.5) + 8.0) + drift
	if state == State.STARTING_MISSION:
		# Screen-space distance is recomputed on resize; no Moon transforms change.
		var width: float = world.camera.size * viewport.x / viewport.y
		world.camera.h_offset = lerpf(-width * 0.5 - 10.5, 0.0, moon_progress)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if state == State.INTRO: _enter_menu()
		elif dialog.visible: _close_dialog()
		get_viewport().set_input_as_handled()

func _start_mission() -> void:
	if state != State.MENU_IDLE or not ready_for_mission or dialog.visible:
		return
	state = State.STARTING_MISSION
	for button in buttons:
		button.disabled = true
		var highlight: Tween = button.get_meta("highlight") if button.has_meta("highlight") else null
		if highlight: highlight.kill()
	var viewport := get_viewport().get_visible_rect().size
	world.camera.h_offset = -world.camera.size * viewport.x / viewport.y * 0.5 - 10.5
	world.show()
	sequence = create_tween().set_parallel(true)
	for i in range(buttons.size()):
		sequence.tween_property(buttons[i], "modulate:a", 0.0, 0.35).set_delay(i * 0.07)
	sequence.tween_property(navigation, "modulate:a", 0.0, 0.6).set_delay(0.15)
	sequence.tween_property(self, "astronaut_departure", 1.0, 2.0).set_delay(0.4).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_property(backdrop, "modulate:a", 0.0, 0.6).set_delay(0.3)
	sequence.tween_property(self, "moon_progress", 1.0, 2.0).set_delay(0.25).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	sequence.chain().tween_callback(_settle)

func _settle() -> void:
	state = State.GAMEPLAY
	sequence = create_tween()
	sequence.tween_property(world.camera, "h_offset", final_offset, 0.8).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_callback(_handoff)

func _handoff() -> void:
	world.menu_layer.show()
	world._update_site_callouts()
	for control in world.menu_layer.get_children():
		if control is Control:
			control.modulate.a = 0.0
			world.create_tween().tween_property(control, "modulate:a", 1.0, 0.45)
	world.reparent(get_tree().root)
	get_tree().current_scene = world
	world.process_mode = Node.PROCESS_MODE_INHERIT
	get_node("/root/GameMenu").set_process_input(true)
	queue_free()

func _open_dialog(title: String) -> void:
	for child in dialog_body.get_children():
		dialog_body.remove_child(child)
		child.queue_free()
	for button in buttons: button.disabled = true
	dialog_body.add_child(_label(title, 28, Color("e2edf6")))
	dialog.show()

func _dialog_back() -> void:
	var back := UI.button("BACK  /  ESC", _close_dialog)
	dialog_body.add_child(back)
	back.grab_focus()

func _close_dialog() -> void:
	dialog.hide()
	for button in buttons: button.disabled = false
	buttons[0].disabled = not ready_for_mission
	buttons[1].grab_focus()

func _briefing() -> void:
	_open_dialog("MISSION BRIEFING")
	var text := _label("Prepare for lunar exploration.\n\n1. Inspect the existing lunar globe.\n2. Select a marked landing site.\n3. Explore the outpost and mission dashboard.\n\nGlobe: right-drag to orbit · scroll to zoom.\nSelect a site label to begin landing.\n\nTraining simulation for the Space Apps challenge.\nNot an operational mission plan or NASA endorsement.", 18, Color("b9cbd9"))
	dialog_body.add_child(text)
	_dialog_back()

func _settings() -> void:
	_open_dialog("SETTINGS")
	var settings := get_node("/root/GameSettings")
	dialog_body.add_child(_label("Master volume", 18, Color.WHITE))
	var volume := HSlider.new()
	volume.max_value = 1.0
	volume.step = 0.01
	volume.value = settings.values.master
	volume.custom_minimum_size.y = 32
	volume.value_changed.connect(func(value: float): settings.change("master", value))
	dialog_body.add_child(volume)
	for entry in [["Fullscreen", "fullscreen"], ["Reduce idle motion", "reduce_motion"]]:
		var toggle := CheckButton.new()
		toggle.text = entry[0]
		toggle.button_pressed = settings.values[entry[1]]
		var key: String = entry[1]
		toggle.toggled.connect(func(value: bool):
			settings.change(key, value)
			reduced = settings.values.reduce_motion)
		dialog_body.add_child(toggle)
	var quality := OptionButton.new()
	for text in ["Graphics: low / no AA", "Graphics: medium / 2× AA", "Graphics: high / 4× AA"]: quality.add_item(text)
	quality.select(settings.values.quality)
	quality.item_selected.connect(func(index: int): settings.change("quality", index))
	dialog_body.add_child(quality)
	dialog_body.add_child(_label("Applied immediately · saved on this device", 14, Color("8ea2b3")))
	_dialog_back()

func _exit() -> void:
	if state == State.MENU_IDLE: get_tree().quit()

func _exit_tree() -> void:
	if sequence: sequence.kill()
	var menu := get_node_or_null("/root/GameMenu")
	if menu: menu.set_process_input(true)



extends Control
## Character carousel and modal identity entry, embedded in startup.
signal confirmed
signal back_requested
const UI = preload("res://src/ui/ui_style.gd")
const Identity = preload("res://src/runtime/commander_identity.gd")
var selected_id := ""
var cards: Array[Button] = []
var card_images: Array[TextureRect] = []
var textures: Dictionary = {}
var name_input: LineEdit
var validation: Label
var confirm_button: Button
var select_button: Button
var back_button: Button
var left_button: Button
var right_button: Button
var headline: Label
var content: Control
var modal: Control
var dialog: Panel
var blur: ColorRect
var stage: SubViewportContainer
var world: Node3D
var preview: TextureRect
var outgoing_preview: TextureRect
var slide_tween: Tween
var preview_origin := Vector2.ZERO
var session: Node
var busy := false
var reduced := false
var selected_index := 0

func _ready() -> void:
	name = "CommanderSelection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session = get_node("/root/MissionSession")
	reduced = get_node("/root/GameSettings").values.reduce_motion
	var background := TextureRect.new()
	background.texture = preload("res://Assets/ui/commander-moon.jpg")
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.modulate = Color(0.65, 0.65, 0.65, 1.0)
	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_stage()
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
	outgoing_preview = preview.duplicate() as TextureRect
	content.add_child(outgoing_preview)
	outgoing_preview.hide()
	headline = UI.label("Your Mission.\nYour Commander.", 36)
	headline.add_theme_font_override("font", preload("res://Assets/fonts/corpta-demo.regular.otf"))
	content.add_child(headline)
	headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	left_button = UI.button("‹", _cycle.bind(-1))
	right_button = UI.button("›", _cycle.bind(1))
	for button in [left_button, right_button]:
		button.add_theme_font_size_override("font_size", 46)
		content.add_child(button)
	left_button.tooltip_text = "Previous character"
	right_button.tooltip_text = "Next character"
	select_button = UI.button("Select", _open_name, true)
	select_button.add_theme_font_override("font", preload("res://Assets/fonts/corpta-demo.regular.otf"))
	content.add_child(select_button)
	for option in Identity.options():
		var id: String = option.variant_id
		textures[id] = load(Identity.asset_path(option.full_body_asset_id))
		var card := UI.button("", select_appearance.bind(id))
		card.name = id
		card.tooltip_text = "Character " + id.get_slice("-", 1)
		content.add_child(card)
		cards.append(card)
		var portrait := TextureRect.new()
		portrait.texture = Identity.texture_for_frame(Identity.frame(id, "frame_00"))
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		card_images.append(portrait)
	_build_modal()
	var draft: Dictionary = session.commander_draft
	name_input.text = str(draft.get("name", ""))
	select_appearance(str(draft.get("appearance_id", "commander-01")) if textures.has(draft.get("appearance_id", "commander-01")) else "commander-01")
	_layout()
	resized.connect(_layout)
	select_button.grab_focus()

func _build_stage() -> void:
	stage = SubViewportContainer.new()
	stage.stretch = true
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stage)
	var viewport := SubViewport.new()
	viewport.transparent_bg = true
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	stage.add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_CANVAS
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b7cde5")
	environment.environment.ambient_light_energy = 0.7
	world.add_child(environment)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(0, 2.5, 6)
	camera.look_at(Vector3(0, 1.05, 0))
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 3.1
	for pos in [Vector3(-3, 5, 4), Vector3(3, 3, -2)]:
		var light := OmniLight3D.new()
		world.add_child(light)
		light.position = pos
		light.omni_range = 12
		light.light_energy = 2.0
	var platform := MeshInstance3D.new()
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = 1.18
	cylinder.bottom_radius = 1.22
	cylinder.height = 0.16
	cylinder.radial_segments = 96
	platform.mesh = cylinder
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color("293b50")
	metal.metallic = 0.65
	metal.roughness = 0.35
	platform.material_override = metal
	world.add_child(platform)
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 1.13
	torus.outer_radius = 1.18
	ring.mesh = torus
	ring.position.y = 0.085
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color("9cd7ff")
	glow.emission_enabled = true
	glow.emission = Color("6fc4fa")
	ring.material_override = glow
	world.add_child(ring)

func _build_modal() -> void:
	modal = Control.new()
	add_child(modal)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blur = ColorRect.new()
	modal.add_child(blur)
	blur.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear_mipmap; void fragment(){ COLOR=vec4(textureLod(screen_texture,SCREEN_UV,3.0).rgb*0.48,1.0); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	blur.material = material
	dialog = Panel.new()
	dialog.theme = Theme.new()
	dialog.theme.default_font = preload("res://Assets/fonts/corpta-demo.regular.otf")
	dialog.add_theme_stylebox_override("panel", UI.style(Color("101a29"), Color("607b96")))
	modal.add_child(dialog)
	var title := UI.label("Enter Name", 30)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(title)
	_place(title, Rect2(24, 30, 392, 44))
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter Name"
	name_input.max_length = Identity.NAME_LIMIT
	name_input.add_theme_font_size_override("font_size", 22)
	dialog.add_child(name_input)
	_place(name_input, Rect2(32, 96, 376, 52))
	name_input.text_changed.connect(func(_value: String): _remember_draft(); _validate())
	name_input.text_submitted.connect(func(_value: String): _confirm())
	validation = UI.label("", 13, UI.AMBER)
	validation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(validation)
	_place(validation, Rect2(32, 155, 376, 42))
	back_button = UI.button("Back", _close_name)
	confirm_button = UI.button("Continue", _confirm, true)
	dialog.add_child(back_button)
	dialog.add_child(confirm_button)
	_place(back_button, Rect2(32, 210, 130, 48))
	_place(confirm_button, Rect2(180, 210, 228, 48))
	modal.hide()

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout() -> void:
	var factor := minf(size.x / 1360.0, size.y / 820.0)
	content.scale = Vector2.ONE * factor
	var w := size.x / factor
	var h := size.y / factor
	_place(headline, Rect2(60, 50, 400, 110))
	_place(select_button, Rect2(w - 230, 60, 170, 54))
	_place(stage, Rect2(w / 2 - 330, h - 735, 660, 580))
	_place(preview, Rect2(w / 2 - 180, h - 770, 360, 540))
	preview_origin = preview.position
	_finish_slide()
	(stage.get_child(0) as SubViewport).render_target_update_mode = SubViewport.UPDATE_ONCE
	_place(left_button, Rect2(w / 2 - 400, h * 0.46, 64, 72))
	_place(right_button, Rect2(w / 2 + 336, h * 0.46, 64, 72))
	for i in cards.size():
		_place(cards[i], Rect2(w / 2 - 414 + i * 212, h - 180, 192, 150))
		_place(card_images[i], Rect2(6, 6, 180, 138))
	dialog.scale = Vector2.ONE * minf(1.0, factor)
	dialog.size = Vector2(440, 290)
	dialog.position = (size - dialog.size * dialog.scale) / 2

func select_appearance(id: String, animate := true, direction := 0) -> void:
	if busy or modal.visible or not textures.has(id): return
	if selected_id == id: return
	var previous_index := selected_index
	var previous_texture := outgoing_preview.texture if outgoing_preview.visible else preview.texture
	_finish_slide()
	selected_id = id
	for i in cards.size():
		var chosen := str(cards[i].name) == id
		if chosen: selected_index = i
		var style := UI.style(Color("253746") if chosen else Color("101b28"), UI.AMBER if chosen else Color("42576a"))
		style.set_border_width_all(3 if chosen else 1)
		cards[i].add_theme_stylebox_override("normal", style)
	preview.texture = textures[id]
	if animate and not reduced and previous_texture != null:
		if direction == 0: direction = 1 if selected_index > previous_index else -1
		var offset := Vector2(150 * direction, 0)
		outgoing_preview.texture = previous_texture
		outgoing_preview.position = preview_origin
		outgoing_preview.size = preview.size
		outgoing_preview.modulate.a = 1.0
		outgoing_preview.show()
		preview.position = preview_origin + offset
		preview.modulate.a = 0.0
		preview.hide()
		slide_tween = create_tween().set_parallel(true)
		slide_tween.tween_property(outgoing_preview, "position", preview_origin - offset, 0.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		slide_tween.tween_property(outgoing_preview, "modulate:a", 0.0, 0.16)
		# Never render both characters in the same frame.
		slide_tween.chain().tween_callback(func():
			outgoing_preview.hide()
			preview.show())
		slide_tween.chain().tween_property(preview, "position", preview_origin, 0.22).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		slide_tween.parallel().tween_property(preview, "modulate:a", 1.0, 0.18)
	_remember_draft()
	_validate()

func _finish_slide() -> void:
	if slide_tween:
		slide_tween.kill()
		slide_tween = null
	preview.position = preview_origin
	preview.modulate.a = 1.0
	outgoing_preview.hide()
	preview.show()

func _cycle(direction: int) -> void:
	select_appearance(str(cards[posmod(selected_index + direction, cards.size())].name), true, direction)

func _open_name() -> void:
	if busy: return
	_finish_slide()
	modal.show()
	for button in cards + [left_button, right_button, select_button]: button.disabled = true
	_validate()
	name_input.grab_focus()

func _close_name() -> void:
	if busy: return
	modal.hide()
	for button in cards + [left_button, right_button, select_button]: button.disabled = false
	select_button.grab_focus()

func _remember_draft() -> void:
	session.commander_draft = {"appearance_id": selected_id, "name": name_input.text}

func _validate() -> void:
	var problem := Identity.name_error(name_input.text)
	validation.text = problem if not name_input.text.is_empty() else ""
	confirm_button.disabled = busy or selected_id.is_empty() or not problem.is_empty()
	select_button.disabled = busy or modal.visible

func _confirm() -> void:
	if busy or not modal.visible or confirm_button.disabled: return
	if not session.confirm_new_commander(selected_id, name_input.text): return
	busy = true
	confirm_button.disabled = true
	back_button.disabled = true
	name_input.editable = false
	var transition := create_tween()
	transition.tween_interval(0.1 if reduced else 0.3)
	transition.tween_property(self, "modulate:a", 0.0, 0.1 if reduced else 0.22)
	transition.tween_callback(func(): confirmed.emit())

func _back() -> void:
	if busy: return
	if modal.visible:
		_close_name()
		return
	_remember_draft()
	back_requested.emit()

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or busy: return
	if event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()
	elif not modal.visible and (event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right")):
		_cycle(-1 if event.is_action_pressed("ui_left") else 1)
		get_viewport().set_input_as_handled()

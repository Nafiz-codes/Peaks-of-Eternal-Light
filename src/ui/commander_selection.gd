extends Control
## Embedded in startup so the existing lunar-selector handoff remains intact.
signal confirmed
signal back_requested
const UI = preload("res://src/ui/ui_style.gd")
const Identity = preload("res://src/runtime/commander_identity.gd")
var selected_id := ""
var cards: Array[Button] = []
var card_images: Array[TextureRect] = []
var card_labels: Array[Label] = []
var preview: TextureRect
var name_input: LineEdit
var validation: Label
var confirm_button: Button
var back_button: Button
var headline: Label
var subtitle: Label
var eyebrow: Label
var step_label: Label
var name_label: Label
var preview_label: Label
var role_label: Label
var mission_label: Label
var footer_note: Label
var stage: Panel
var content: Control
var selected_note: Label
var busy := false
var preview_tween: Tween
var entrance: Tween
var textures: Dictionary = {}
var session: Node
var reduced := false

func _ready() -> void:
	name = "CommanderSelection"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	session = get_node("/root/MissionSession")
	reduced = get_node("/root/GameSettings").values.reduce_motion
	var background := ColorRect.new()
	background.color = Color("070d17")
	add_child(background)
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content = Control.new()
	add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage = Panel.new()
	stage.add_theme_stylebox_override("panel", UI.style(Color("0e1b2b"), Color("294459")))
	stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(stage)
	stage.draw.connect(_draw_stage)
	stage.resized.connect(func(): stage.queue_redraw())
	var glow := TextureRect.new()
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.18, 0.40, 0.58, 0.35), Color(0.04, 0.08, 0.14, 0)])
	var light := GradientTexture2D.new()
	light.gradient = gradient
	light.fill = GradientTexture2D.FILL_RADIAL
	light.fill_from = Vector2(0.5, 0.38)
	light.fill_to = Vector2(0.95, 0.80)
	glow.texture = light
	glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stage.add_child(glow)
	glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	preview = TextureRect.new()
	preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(preview)
	eyebrow = _label("PEAKS OF ETERNAL LIGHT  /  EXPEDITION PERSONNEL", 14, UI.BLUE)
	step_label = _label("01  /  COMMANDER     —     02  /  LANDING SITE", 12, UI.MUTED)
	headline = _label("Your mission.\nYour Commander.", 44, UI.TEXT)
	subtitle = _label("Choose the face of your expedition.", 17, UI.MUTED)
	selected_note = _label("SELECT AN APPEARANCE", 13, UI.AMBER)
	for option in Identity.options():
		var id: String = option.variant_id
		textures[id] = load(Identity.asset_path(option.full_body_asset_id))
		var card := UI.button("", select_appearance.bind(id))
		card.name = id
		card.tooltip_text = "Commander appearance " + id.get_slice("-", 1)
		card.clip_contents = true
		card.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var focus_style := UI.style(Color.TRANSPARENT, UI.BLUE)
		focus_style.set_border_width_all(2)
		card.add_theme_stylebox_override("focus", focus_style)
		content.add_child(card)
		cards.append(card)
		var portrait := TextureRect.new()
		portrait.texture = Identity.texture_for_frame(Identity.frame(id, "frame_00"))
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(portrait)
		card_images.append(portrait)
		var caption := UI.label("APPEARANCE " + id.get_slice("-", 1), 12)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(caption)
		card_labels.append(caption)
		card.mouse_entered.connect(_hover.bind(card, true))
		card.mouse_exited.connect(_hover.bind(card, false))
	name_label = _label("NAME YOUR COMMANDER", 13, UI.BLUE)
	name_input = LineEdit.new()
	name_input.placeholder_text = "Enter astronaut name"
	name_input.max_length = Identity.NAME_LIMIT
	name_input.add_theme_font_size_override("font_size", 21)
	name_input.add_theme_stylebox_override("normal", UI.style(Color("111f30"), Color("58778e")))
	name_input.add_theme_stylebox_override("focus", UI.style(Color("132637"), UI.AMBER))
	content.add_child(name_input)
	name_input.text_changed.connect(func(_text: String): _remember_draft(); _validate())
	name_input.text_submitted.connect(func(_text: String): _confirm())
	validation = _label("", 13, UI.AMBER)
	preview_label = _label("CREW 01  /  AWAITING SELECTION", 13, UI.AMBER)
	role_label = _label("SURFACE MISSION COMMANDER\n& EXPLORATION LEAD", 20, UI.TEXT)
	mission_label = _label("Lead a long-duration lunar research settlement.\nPlan the mission. Guide your crew. Make every resource count.", 15, UI.MUTED)
	footer_note = _label("ONE COMMANDER. THREE SPECIALISTS. ONE SHARED MISSION.", 12, UI.MUTED)
	back_button = UI.button("←  BACK", _back)
	confirm_button = UI.button("CONFIRM & CONTINUE  →", _confirm, true)
	content.add_child(back_button)
	content.add_child(confirm_button)
	confirm_button.add_theme_stylebox_override("normal", UI.style(Color("324353"), UI.AMBER))
	var draft: Dictionary = session.commander_draft
	name_input.text = str(draft.get("name", ""))
	if textures.has(draft.get("appearance_id", "")):
		select_appearance(draft.appearance_id, false)
	else:
		# A non-selected showcase is explicit; confirmation still requires a choice.
		if not cards.is_empty(): preview.texture = textures[str(cards[0].name)]
	_layout()
	resized.connect(_layout)
	_focus_paths()
	_validate()
	if not cards.is_empty(): cards[0].grab_focus()
	if not reduced:
		content.modulate.a = 0
		entrance = create_tween()
		entrance.tween_property(content, "modulate:a", 1.0, 0.28)

func _label(text: String, font_size: int, color: Color) -> Label:
	var label := UI.label(text, font_size, color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(label)
	return label

func _draw_stage() -> void:
	var center := Vector2(stage.size.x * 0.5, stage.size.y * 0.40)
	var radius := minf(stage.size.x * 0.38, stage.size.y * 0.32)
	var ink := Color(0.45, 0.70, 0.86, 0.13)
	for offset in [0.0, 22.0]:
		stage.draw_arc(center, radius + offset, -PI * 0.82, PI * 0.82, 90, ink, 1.0, true)
	for i in range(28):
		var angle := float(i) / 28.0 * TAU
		var direction := Vector2(cos(angle), sin(angle))
		stage.draw_line(center + direction * (radius + 27), center + direction * (radius + 33), ink, 1.0, true)
	stage.draw_line(Vector2(22, stage.size.y - 134), Vector2(stage.size.x - 22, stage.size.y - 134), ink, 1.0)

func _place(control: Control, rect: Rect2) -> void:
	control.position = rect.position
	control.size = rect.size

func _layout() -> void:
	if not is_instance_valid(content): return
	var factor := minf(1.0, minf(size.x / 960.0, size.y / 640.0))
	content.scale = Vector2.ONE * factor
	var w := size.x / factor
	var h := size.y / factor
	var margin := clampf(w * 0.045, 22, 80)
	var left := w * 0.40
	var stage_x := margin + left + 38
	var stage_w := w - stage_x - margin
	var compact := h < 760 or w < 1100
	headline.add_theme_font_size_override("font_size", 32 if compact else 44)
	_place(eyebrow, Rect2(margin, 26, w - margin * 2, 24))
	_place(step_label, Rect2(margin, 56, w - margin * 2, 24))
	_place(headline, Rect2(margin, 100, left, 100 if compact else 118))
	_place(subtitle, Rect2(margin, 183 if compact else 218, left, 30))
	_place(selected_note, Rect2(margin, 222 if compact else 266, left, 24))
	var grid_y := 252.0 if compact else 300.0
	var footer_y := h - 80
	var name_y := footer_y - 120
	var card_h := maxf(68, (name_y - grid_y - 22) / 2)
	var card_w := (left - 14) / 2
	for i in cards.size():
		_place(cards[i], Rect2(margin + (i % 2) * (card_w + 14), grid_y + (i / 2) * (card_h + 10), card_w, card_h))
		_place(card_images[i], Rect2(5, 5, card_w - 10, card_h - 29))
		_place(card_labels[i], Rect2(4, card_h - 25, card_w - 8, 22))
	_place(name_label, Rect2(margin, name_y, left, 22))
	_place(name_input, Rect2(margin, name_y + 28, left, 48))
	_place(validation, Rect2(margin, name_y + 80, left, 36))
	_place(stage, Rect2(stage_x, 100, stage_w, footer_y - 126))
	_place(preview, Rect2(stage_x + 8, 118, stage_w - 16, footer_y - 272))
	_place(preview_label, Rect2(stage_x + 22, 115, stage_w - 44, 24))
	_place(role_label, Rect2(stage_x + 22, footer_y - 154, stage_w - 44, 52))
	role_label.add_theme_font_size_override("font_size", 16 if compact else 20)
	_place(mission_label, Rect2(stage_x + 22, footer_y - 96, stage_w - 44, 62))
	mission_label.add_theme_font_size_override("font_size", 13 if compact else 15)
	_place(back_button, Rect2(margin, footer_y + 9, 125, 48))
	_place(confirm_button, Rect2(w - margin - 280, footer_y + 9, 280, 48))
	_place(footer_note, Rect2(margin + 145, footer_y + 15, w - margin * 2 - 450, 44))
	footer_note.visible = w >= 1100

func _focus_paths() -> void:
	var order: Array[Control] = []
	for card in cards: order.append(card)
	order.append_array([name_input, back_button, confirm_button])
	for i in order.size():
		order[i].focus_next = order[i].get_path_to(order[(i + 1) % order.size()])
		order[i].focus_previous = order[i].get_path_to(order[posmod(i - 1, order.size())])
	for i in cards.size():
		cards[i].focus_neighbor_left = cards[i].get_path_to(cards[i ^ 1])
		cards[i].focus_neighbor_right = cards[i].get_path_to(cards[i ^ 1])
		cards[i].focus_neighbor_top = cards[i].get_path_to(cards[i - 2] if i >= 2 else back_button)
		cards[i].focus_neighbor_bottom = cards[i].get_path_to(cards[i + 2] if i < 2 else name_input)

func _hover(card: Button, active: bool) -> void:
	if busy or reduced: return
	var old: Tween = card.get_meta("hover_tween", null)
	if old: old.kill()
	var tween := create_tween()
	card.set_meta("hover_tween", tween)
	tween.tween_property(card, "modulate", Color(1.12, 1.12, 1.12) if active else Color.WHITE, 0.12)

func select_appearance(id: String, animate := true) -> void:
	if busy or not textures.has(id): return
	selected_id = id
	selected_note.text = "SELECTED  /  APPEARANCE " + id.get_slice("-", 1)
	preview_label.text = "CREW 01  /  APPEARANCE " + id.get_slice("-", 1)
	for i in cards.size():
		var chosen := str(cards[i].name) == id
		card_labels[i].text = ("✓ SELECTED  /  " if chosen else "APPEARANCE ") + str(cards[i].name).get_slice("-", 1)
		var style := UI.style(Color("253746") if chosen else Color("101b28"), UI.AMBER if chosen else Color("42576a"))
		style.set_border_width_all(3 if chosen else 1)
		cards[i].add_theme_stylebox_override("normal", style)
	if preview_tween: preview_tween.kill()
	if reduced or not animate:
		preview.texture = textures[id]
		preview.modulate.a = 1
	else:
		preview_tween = create_tween()
		preview_tween.tween_property(preview, "modulate:a", 0.0, 0.08)
		preview_tween.tween_callback(func(): preview.texture = textures[id])
		preview_tween.tween_property(preview, "modulate:a", 1.0, 0.16)
	_remember_draft()
	_validate()

func _remember_draft() -> void:
	session.commander_draft = {"appearance_id": selected_id, "name": name_input.text}

func _validate() -> void:
	var problem := Identity.name_error(name_input.text)
	if selected_id.is_empty(): problem = "Choose an appearance, then enter your name."
	validation.text = problem if not problem.is_empty() else "Ready for assignment  ·  %d / %d characters" % [name_input.text.strip_edges().length(), Identity.NAME_LIMIT]
	confirm_button.disabled = busy or not problem.is_empty()

func _confirm() -> void:
	if busy or confirm_button.disabled: return
	if not session.confirm_new_commander(selected_id, name_input.text): return
	busy = true
	confirm_button.disabled = true
	back_button.disabled = true
	name_input.editable = false
	for card in cards: card.disabled = true
	validation.text = "COMMANDER CONFIRMED  /  " + session.commander_name()
	confirm_button.text = "COMMANDER CONFIRMED  ✓"
	if preview_tween: preview_tween.kill()
	preview.texture = textures[selected_id]
	preview.modulate.a = 1
	var transition := create_tween()
	transition.tween_interval(0.1 if reduced else 0.3)
	transition.tween_property(self, "modulate:a", 0.0, 0.1 if reduced else 0.22)
	transition.tween_callback(func(): confirmed.emit())

func _back() -> void:
	if busy: return
	_remember_draft()
	back_requested.emit()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		_back()
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if preview_tween: preview_tween.kill()
	if entrance: entrance.kill()

extends Control
## Shared in-world portrait dialogue; hides competing HUDs while open.
const Identity = preload("res://src/runtime/commander_identity.gd")
const IDS := {"crew_briefing": "CREW_02", "water_recycler": "CREW_03", "food_storage": "CREW_04"}
const PORTRAITS := {"crew_briefing": "res://Assets/characters/Maya_Chen/default/maya-dialogue-transparent.png", "food_storage": "res://Assets/characters/Sam_Okafor/default/sam-dialogue-transparent.png", "water_recycler": "res://Assets/characters/Alex_Rivera/default/alex-dialogue-transparent.png"}
const NAMES := {"crew_briefing": "Dr. Maya Chen", "water_recycler": "Dr. Alex Rivera", "food_storage": "Sam Okafor"}
var portrait: TextureRect
var speaker: Label
var speech: Label
var hint: Label
var choices: VBoxContainer
var hidden_nodes: Array = []
var player: Node
var previous_blocked := false
var previous_mouse := Input.MOUSE_MODE_CAPTURED
var active := false
var choice_actor: Node3D

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("conversation_modal")
	var shade := ColorRect.new()
	shade.name = "DialogueShade"
	shade.color = Color(0.01, 0.025, 0.04, 0.40)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var circle_shader := Shader.new()
	circle_shader.code = "shader_type canvas_item; uniform float diameter = 82.0; varying vec2 local_position; void vertex() { local_position = VERTEX / diameter; } void fragment() { vec4 pixel = texture(TEXTURE, UV); float radius = length(local_position - vec2(0.5)); pixel.a *= 1.0 - smoothstep(0.485, 0.5, radius); COLOR = pixel; }"
	var circle_material := ShaderMaterial.new()
	circle_material.shader = circle_shader
	portrait.material = circle_material
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_left = 0.45
	portrait.anchor_right = 0.55
	portrait.anchor_top = 0.59
	portrait.anchor_bottom = 0.69
	var column := Control.new()
	column.name = "DialogueColumn"
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	speaker = _label(column, 24, Color("ffd36a"))
	_place(speaker, 0.10, 0.83, 0.90, 0.865)
	var line := HSeparator.new()
	line.name = "GoldDivider"
	var gold := StyleBoxLine.new()
	gold.color = Color("ffd36a")
	gold.thickness = 1
	line.add_theme_stylebox_override("separator", gold)
	column.add_child(line)
	_place(line, 0.10, 0.875, 0.90, 0.877)
	speech = _label(column, 18, Color.WHITE)
	_place(speech, 0.06, 0.89, 0.94, 0.965)
	hint = _label(self, 11, Color("c8d5e2"))
	_place(hint, 0.10, 0.975, 0.90, 1.0)
	choices = VBoxContainer.new()
	add_child(choices)
	choices.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	choices.add_theme_constant_override("separation", 4)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")

func _place(control: Control, left: float, top: float, right: float, bottom: float) -> void:
	control.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	control.anchor_left = left
	control.anchor_top = top
	control.anchor_right = right
	control.anchor_bottom = bottom

func _label(parent: Node, size_: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size_)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color("101820"))
	label.add_theme_constant_override("outline_size", 4)
	parent.add_child(label)
	return label

func show_options_only() -> void:
	portrait.hide()
	get_node("DialogueColumn").hide()
	get_node("DialogueShade").hide()
	choices.show()

func present(id: String, text: String, expression := "neutral") -> void:
	get_node("DialogueColumn").show()
	get_node("DialogueShade").show()
	var session := get_node("/root/MissionSession")
	speaker.text = session.commander_name() if id == "player" else str(NAMES.get(id, id))
	speech.text = text
	var entry: Dictionary = {}
	if id == "player":
		entry = session.commander_portrait(expression)
		if not entry.is_empty():
			entry = entry.duplicate(true)
			entry.asset_path = "res://Assets/characters/Commander/%s/%s-dialogue-transparent.png" % [entry.variant_id, entry.variant_id]
	else:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/characters/preparation/expressions.json"))
		for frame in catalog.frames:
			if frame.character_id == IDS.get(id, "") and frame.suggested_emotion == expression:
				entry = frame
				break
	if id != "player" and not entry.is_empty():
		entry = entry.duplicate(true)
		entry.asset_path = PORTRAITS[id]
	portrait.texture = Identity.texture_for_frame(entry)
	portrait.visible = portrait.texture != null

func begin(world: Node) -> void:
	if active: return
	active = true
	player = world.get_node("Outpost/Astronaut")
	previous_blocked = player.ui_blocked
	player.ui_blocked = true
	previous_mouse = Input.mouse_mode
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	for node in world.find_children("*", "CanvasLayer", true, false):
		if node.is_ancestor_of(self): continue
		hidden_nodes.append([weakref(node), node.visible])
		node.hide()
	var hud := world.get_node("MissionHUD")
	for node in hud.get_children():
		if node is CanvasItem and not node.is_ancestor_of(self):
			hidden_nodes.append([weakref(node), node.visible])
			node.hide()
	# World-space labels can otherwise sit across faces or dialogue captions.
	for tag in world.find_children("*", "Label3D", true, false):
		hidden_nodes.append([weakref(tag), tag.visible])
		tag.hide()
func _process(_delta: float) -> void:
	if not active: return
	_position_choices()
	for entry in hidden_nodes:
		var node: Variant = entry[0].get_ref()
		if is_instance_valid(node): node.hide()

func end() -> void:
	if not active: return
	active = false
	for entry in hidden_nodes:
		var node: Variant = entry[0].get_ref()
		if is_instance_valid(node): node.visible = entry[1]
	hidden_nodes.clear()
	if is_instance_valid(player): player.ui_blocked = previous_blocked
	Input.mouse_mode = previous_mouse

func _exit_tree() -> void:
	end()

func _layout() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var factor := clampf(minf(viewport_size.x / 1360.0, viewport_size.y / 820.0), 0.65, 1.0)
	var diameter := 82.0 * factor
	portrait.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	portrait.position = Vector2((viewport_size.x - diameter) * 0.5, viewport_size.y * 0.83 - diameter - 6.0 * factor)
	portrait.size = Vector2(diameter, diameter)
	portrait.material.set_shader_parameter("diameter", diameter)
	speaker.add_theme_font_size_override("font_size", roundi(24 * factor))
	speech.add_theme_font_size_override("font_size", roundi(18 * factor))
	hint.add_theme_font_size_override("font_size", maxi(9, roundi(11 * factor)))
	for button in choices.get_children():
		if button is Button:
			button.custom_minimum_size.y = 28 * factor
			button.add_theme_font_size_override("font_size", maxi(9, roundi(11 * factor)))

func _position_choices() -> void:
	if choices.get_child_count() == 0: return
	var viewport_size := get_viewport().get_visible_rect().size
	var camera := get_viewport().get_camera_3d()
	var width := clampf(viewport_size.x * 0.18, 190.0, 245.0)
	choices.size = Vector2(width, choices.get_combined_minimum_size().y)
	var point := Vector2(viewport_size.x * 0.65, viewport_size.y * 0.30)
	if is_instance_valid(choice_actor) and camera != null:
		var target := choice_actor.global_position + Vector3(0, 1.3, 0)
		if not camera.is_position_behind(target):
			point = camera.unproject_position(target) + Vector2(clampf(viewport_size.x * 0.14, 110.0, 190.0), -choices.size.y * 0.5)
	# Keep the menu beside the actor and clear of the lower dialogue band.
	point.x = clampf(point.x, 12, maxf(12, viewport_size.x - width - 12))
	point.y = clampf(point.y, 12, maxf(12, viewport_size.y * 0.57 - choices.size.y))
	choices.position = point

extends Control
## Shared in-world portrait dialogue; hides competing HUDs while open.
const Identity = preload("res://src/runtime/commander_identity.gd")
const IDS := {"crew_briefing": "CREW_02", "water_recycler": "CREW_03", "food_storage": "CREW_04"}
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

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_to_group("conversation_modal")
	var shade := ColorRect.new()
	shade.color = Color(0.01, 0.025, 0.04, 0.40)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(portrait)
	portrait.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	portrait.anchor_left = 0.40
	portrait.anchor_right = 0.60
	portrait.anchor_top = 0.12
	portrait.anchor_bottom = 0.52
	var column := VBoxContainer.new()
	add_child(column)
	column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	column.anchor_left = 0.10
	column.anchor_right = 0.90
	column.anchor_top = 0.55
	column.anchor_bottom = 0.95
	column.add_theme_constant_override("separation", 12)
	speaker = _label(column, 24, Color("ffd36a"))
	var line := HSeparator.new()
	line.name = "GoldDivider"
	var gold := StyleBoxLine.new()
	gold.color = Color("ffd36a")
	gold.thickness = 1
	line.add_theme_stylebox_override("separator", gold)
	column.add_child(line)
	speech = _label(column, 20, Color.WHITE)
	speech.size_flags_vertical = Control.SIZE_EXPAND_FILL
	hint = _label(column, 13, Color("c8d5e2"))
	choices = VBoxContainer.new()
	add_child(choices)
	choices.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	choices.anchor_left = 0.68
	choices.anchor_right = 0.96
	choices.anchor_top = 0.14
	choices.anchor_bottom = 0.51
	choices.add_theme_constant_override("separation", 7)
	get_viewport().size_changed.connect(_layout)
	call_deferred("_layout")

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

func present(id: String, text: String, expression := "neutral") -> void:
	var session := get_node("/root/MissionSession")
	speaker.text = session.commander_name() if id == "player" else str(NAMES.get(id, id))
	speech.text = text
	var entry: Dictionary = {}
	if id == "player":
		entry = session.commander_portrait(expression)
	else:
		var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/characters/preparation/expressions.json"))
		for frame in catalog.frames:
			if frame.character_id == IDS.get(id, "") and frame.suggested_emotion == expression:
				entry = frame
				break
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
	speaker.add_theme_font_size_override("font_size", roundi(24 * factor))
	speech.add_theme_font_size_override("font_size", roundi(20 * factor))
	hint.add_theme_font_size_override("font_size", maxi(11, roundi(13 * factor)))
	for button in choices.get_children():
		if button is Button:
			button.custom_minimum_size.y = 38 * factor
			button.add_theme_font_size_override("font_size", maxi(12, roundi(16 * factor)))

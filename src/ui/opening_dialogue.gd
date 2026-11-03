extends CanvasLayer
## Player-paced opening cards. Pausing also prevents menu/gameplay input leaking through.
signal finished
const UI = preload("res://src/ui/ui_style.gd")
const Identity = preload("res://src/runtime/commander_identity.gd")
const PANEL_COLOR := Color(0.059, 0.078, 0.196, 0.75)
const BODY_SIZE := 26
const LEFT_PADDING := 0.15
const PANEL_HEIGHT := 0.28
const MENU_HEIGHT := 28.0
const MENU_ITEMS := ["SKIP", "AUTO", "Q.SAVE", "SAVE", "LOAD", "LOG", "ENCYCLOPEDIA", "CONFIG", "MENU"]
const NAMES := {"CREW_02": "Dr. Maya Chen", "CREW_03": "Dr. Alex Rivera", "CREW_04": "Sam Okafor"}
const SEQUENCES := {
	"welcome": [
		["CREW_02", "Warm smile", "Good to see you, Commander. I’m Dr. Maya Chen. Remember all that Moon training? Today we get to use it."],
		["CREW_02", "Focused", "First, pick how you’d like your astronaut to look."],
		["CREW_02", "Warm smile", "Then enter the name you want us to call you on this mission."]],
	"landing_site": [
		["CREW_02", "Focused", "Commander {player_name}, this is where we choose our home on the Moon. What do you two see?"],
		["CREW_03", "Excited", "Look at those crater rims. The rocks there might tell us what happened here long ago."],
		["CREW_04", "Slight smile", "Can we get the rover there? A short trip on the map can be a long ride over steep ground."],
		["CREW_03", "Thoughtful", "Good point. Let’s look for ground we can cross. I’d like to bring samples back, too."],
		["CREW_04", "Focused", "And check the sunlight. A sunnier site gives our solar panels more light to work with."],
		["CREW_02", "Encouraging smile", "Look at the sunlight and how steep the ground is. Then think about what you’d like us to explore. Where should we land?"]],
	"touchdown": [
		["CREW_04", "Relieved smile", "We’re down. I think I’ve been gripping that armrest since the last turn."],
		["CREW_03", "Wonder, then a smile", "I’ve stared at pictures of this place for years. I didn’t expect the shadows to look that long."],
		["CREW_04", "Warm smile", "Take a good look. We’ll need your eyes on the ground once the rover’s ready."],
		["CREW_02", "Quiet pride", "Nice work, crew. Take a moment. We’re on the Moon."]],
	"invitation": [["CREW_02", "Warm smile", "Commander, come see me when you’re ready. I’ve got our first job."]],
	"solar": [
		["CREW_02", "Focused", "Our first job is to set up a solar panel. It turns sunlight into electricity for our equipment."],
		["CREW_02", "Thoughtful", "See how far the shadows reach? A spot can be sunny now and fall into shade later."],
		["CREW_02", "Focused", "Try a few spots where the panel can stand safely. Turn it and see how the power reading changes."],
		["CREW_02", "Encouraging smile", "Pick the spot and angle that give us the most power over the mission. I’ll leave that choice to you."]]
}
var sequence := "welcome"
var preview_appearance := ""
var index := 0
var speaker: Label
var dialogue: Label
var npc: TextureRect
var commander: TextureRect
var panel: PanelContainer
var inset_portrait: TextureRect
var next_button: Button
var previous_paused := false
var previous_mouse := Input.MOUSE_MODE_VISIBLE
var previous_focus: Control
var closing := false
var restored := false
var panel_background: ColorRect
var menu_bar: HBoxContainer
var menu_strip: ColorRect
var indicator: Label
var indicator_phase := 0.0
var menu_was_open := false

static func body_texture(id: String, variant := "default") -> Texture2D:
	Identity._load_catalogs()
	for asset in Identity.asset_catalog.assets:
		if asset.character_id == id and asset.variant_id == variant and asset.asset_type == "full_body":
			var portrait := AtlasTexture.new()
			portrait.atlas = load(asset.path)
			# Show head, torso and hands at a readable scale rather than a small full figure.
			portrait.region = Rect2(0, 0, asset.width, float(asset.height) * 0.68)
			return portrait
	return null

static func npc_frame(id: String, cue: String) -> Dictionary:
	Identity._load_catalogs()
	var emotion := ""
	if cue in ["Warm smile", "Encouraging smile"]: emotion = "smiling"
	if cue == "Excited": emotion = "excited"
	if cue == "Focused": emotion = "thinking"
	var baseline: Dictionary = {}
	for entry in Identity.expression_catalog.frames:
		if entry.character_id != id: continue
		if entry.frame_index == 0: baseline = entry
		if not emotion.is_empty() and entry.suggested_emotion == emotion and entry.emotion_status == "visually_supported": return entry
	return baseline

func _ready() -> void:
	layer = 110
	process_mode = Node.PROCESS_MODE_ALWAYS
	previous_paused = get_tree().paused
	previous_mouse = Input.mouse_mode
	previous_focus = get_viewport().gui_get_focus_owner()
	get_tree().paused = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	var root := Control.new()
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	commander = _portrait(root, Rect2(0.03, 0.08, 0.32, 0.62))
	npc = _portrait(root, Rect2(0.65, 0.08, 0.32, 0.62))
	var session := get_node("/root/MissionSession")
	commander.texture = body_texture("CREW_01", preview_appearance if not preview_appearance.is_empty() else str(session.player_character.get("appearance_id", "")))
	panel = PanelContainer.new()
	panel_background = ColorRect.new()
	root.add_child(panel_background)
	panel_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gradient_shader := Shader.new()
	gradient_shader.code = "shader_type canvas_item; uniform vec4 ink : source_color; void fragment() { float edge = smoothstep(0.0, 0.07, UV.y); COLOR = vec4(ink.rgb + vec3(0.025) * (1.0 - UV.y), ink.a * edge); }"
	var gradient_material := ShaderMaterial.new()
	gradient_material.shader = gradient_shader
	gradient_material.set_shader_parameter("ink", PANEL_COLOR)
	panel_background.material = gradient_material
	root.add_child(panel)
	panel.anchor_left = 0.27
	panel.anchor_right = 0.97
	panel.anchor_top = 0.70
	panel.anchor_bottom = 0.97
	var panel_style := StyleBoxFlat.new()
	panel_style.bg_color = Color.TRANSPARENT
	panel_style.content_margin_left = 170
	panel_style.content_margin_right = 28
	panel_style.content_margin_top = 16
	panel_style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", panel_style)
	inset_portrait = _portrait(root, Rect2(0.04, 0.72, 0.12, 0.25))
	var box := UI.box()
	panel.add_child(box)
	speaker = UI.label("", 22, Color.WHITE)
	dialogue = UI.label("", 20, Color.WHITE)
	var font := load("res://Assets/fonts/Sentient/Sentient-Bold.otf") as Font
	var name_font := font
	speaker.add_theme_font_override("font", name_font)
	dialogue.add_theme_font_override("font", font)
	for label in [speaker, dialogue]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_color_override("font_outline_color", Color("080b12"))
		label.add_theme_constant_override("outline_size", 0)
		label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.6))
		label.add_theme_constant_override("shadow_offset_x", 1)
		label.add_theme_constant_override("shadow_offset_y", 2)
	dialogue.add_theme_constant_override("line_spacing", 10)
	dialogue.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(speaker)
	box.add_child(dialogue)
	next_button = UI.button("Continue  ·  Space / Enter", advance)
	next_button.add_theme_font_override("font", font)
	next_button.add_theme_color_override("font_color", Color.WHITE)
	next_button.add_theme_color_override("font_outline_color", Color("080b12"))
	next_button.add_theme_constant_override("outline_size", 3)
	for state in ["normal", "hover", "pressed", "disabled"]:
		next_button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var focus := StyleBoxFlat.new()
	focus.bg_color = Color.TRANSPARENT
	focus.border_color = Color("ffd36a")
	focus.border_width_bottom = 2
	next_button.add_theme_stylebox_override("focus", focus)
	# Keep the same button/interface; its transparent hit area covers the textbox.
	next_button.text = ""
	next_button.tooltip_text = "Continue · Space / Enter"
	next_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	root.add_child(next_button)
	indicator = UI.label("▶", 16, Color.WHITE)
	indicator.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(indicator)
	menu_strip = ColorRect.new()
	menu_strip.color = Color(0.015, 0.02, 0.055, 0.9)
	root.add_child(menu_strip)
	menu_bar = HBoxContainer.new()
	root.add_child(menu_bar)
	menu_bar.add_theme_constant_override("separation", 10)
	for item in MENU_ITEMS:
		var button := Button.new()
		button.text = item
		button.flat = true
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_override("font", font)
		button.add_theme_font_size_override("font_size", 12)
		button.add_theme_color_override("font_color", Color(1, 1, 1, 0.35 if item == "SKIP" else 0.65))
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		button.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
		button.add_theme_stylebox_override("hover", focus)
		button.pressed.connect(_menu_action.bind(item))
		menu_bar.add_child(button)
	root.resized.connect(_layout.bind(root, panel))
	_layout(root, panel)
	_show_card()
	next_button.grab_focus()

func _layout(root: Control, panel: PanelContainer) -> void:
	var compact := root.size.x < 1100
	dialogue.add_theme_font_size_override("font_size", BODY_SIZE - 2 if compact else BODY_SIZE)
	speaker.add_theme_font_size_override("font_size", BODY_SIZE if compact else BODY_SIZE + 2)
	next_button.add_theme_font_size_override("font_size", 18 if compact else 20)
	var style := panel.get_theme_stylebox("panel") as StyleBoxFlat
	style.content_margin_left = root.size.x * LEFT_PADDING
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -maxf(180.0, root.size.y * PANEL_HEIGHT) - MENU_HEIGHT
	panel.offset_bottom = -MENU_HEIGHT
	npc.anchor_bottom = 1.0 - maxf(270.0, root.size.y * 0.35) / root.size.y
	commander.anchor_bottom = npc.anchor_bottom
	inset_portrait.anchor_top = 1.0
	inset_portrait.anchor_bottom = 1.0
	inset_portrait.offset_top = panel.offset_top - 24
	inset_portrait.offset_bottom = panel.offset_bottom - 10
	for control in [panel_background, next_button]:
		control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		control.offset_top = panel.offset_top
		control.offset_bottom = panel.offset_bottom
	for control in [menu_strip, menu_bar]:
		control.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
		control.offset_top = -MENU_HEIGHT
	menu_bar.offset_left = root.size.x * LEFT_PADDING
	menu_bar.offset_right = -20

func _menu_action(item: String) -> void:
	var pages := {"SAVE": "saves", "LOAD": "saves", "ENCYCLOPEDIA": "science", "CONFIG": "settings", "MENU": "home"}
	if not pages.has(item): return
	var menu := get_node("/root/GameMenu")
	menu.open_menu()
	if menu.opened:
		menu.show_page(pages[item])
		menu_was_open = true

func _process(delta: float) -> void:
	var menu := get_node("/root/GameMenu")
	if menu_was_open and not menu.opened:
		get_tree().paused = true
		menu_was_open = false
	indicator_phase += delta
	indicator.visible = not closing and not menu.opened
	indicator.modulate.a = 0.65 + 0.35 * sin(indicator_phase * 4.0)
	# Label's shaped glyph bounds preserve the public plain-text value and wrapping.
	if not dialogue.text.is_empty():
		var end := dialogue.get_character_bounds(dialogue.text.length() - 1)
		indicator.position = dialogue.global_position + Vector2(end.end.x + 7, end.position.y)

func _portrait(root: Control, bounds: Rect2) -> TextureRect:
	var portrait := TextureRect.new()
	root.add_child(portrait)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Existing full-body PNGs include a faint translucent studio halo.
	# Keep the opaque character cutout while suppressing that background haze.
	var shader := Shader.new()
	shader.code = "shader_type canvas_item; void fragment() { COLOR.a = smoothstep(0.88, 0.98, COLOR.a); }"
	var material := ShaderMaterial.new()
	material.shader = shader
	portrait.material = material
	portrait.anchor_left = bounds.position.x
	portrait.anchor_top = bounds.position.y
	portrait.anchor_right = bounds.end.x
	portrait.anchor_bottom = bounds.end.y
	return portrait

func _show_card() -> void:
	var card: Array = SEQUENCES[sequence][index]
	show_speaker(card[0])
	dialogue.text = str(card[2]).replace("{player_name}", get_node("/root/MissionSession").commander_name())

func show_speaker(id: String) -> void:
	var is_commander := id == "CREW_01"
	commander.visible = is_commander
	npc.visible = not is_commander
	speaker.text = get_node("/root/MissionSession").commander_name() if is_commander else str(NAMES.get(id, ""))
	speaker.visible = not speaker.text.is_empty()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	if not is_commander: npc.texture = body_texture(id)
	inset_portrait.texture = commander.texture if is_commander else npc.texture
	if inset_portrait.texture is AtlasTexture:
		var closeup := inset_portrait.texture.duplicate() as AtlasTexture
		var dimensions := closeup.atlas.get_size()
		closeup.region = Rect2(dimensions.x * 0.20, 0, dimensions.x * 0.60, dimensions.y * 0.40)
		inset_portrait.texture = closeup

func _input(event: InputEvent) -> void:
	if get_node("/root/GameMenu").opened: return
	if event is InputEventKey:
		get_viewport().set_input_as_handled()
		if event.pressed and not event.echo and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]: advance()

func advance() -> void:
	if closing: return
	if index + 1 < SEQUENCES[sequence].size():
		index += 1
		_show_card()
		return
	closing = true
	next_button.disabled = true
	if sequence == "touchdown": await get_tree().create_timer(1.0).timeout
	_restore()
	finished.emit()
	queue_free()

func _restore() -> void:
	if restored: return
	restored = true
	get_tree().paused = previous_paused
	Input.mouse_mode = previous_mouse
	if is_instance_valid(previous_focus): previous_focus.grab_focus()

func _exit_tree() -> void:
	_restore()

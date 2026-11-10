extends CanvasLayer
signal finished
const LINE := "Welcome, Commander! I'm Dr. Maya Chen, your flight engineer and instructor. I'll guide you through the equipment, scientific data, and mission procedures."
const INTRODUCTIONS := {
 "crew_briefing": {"speaker": "Dr. Maya Chen", "text": LINE},
 "water_recycler": {"speaker": "Dr. Alex Rivera", "text": "Dr. Alex Rivera, planetary geologist. I'm here to help us understand the Moon's terrain, history, and potential resources."},
 "food_storage": {"speaker": "Sam Okafor", "text": "And I'm Sam Okafor, robotics and habitat engineer. Give me the equipment, and I'll help turn it into a functioning base."},
 "maya_closing": {"speaker": "Dr. Maya Chen", "text": "We all have our specialties, Commander. But you'll be making the final decisions."},
 "storm_damage": {"speaker": "Dr. Maya Chen", "text": "Commander, the dust storm damaged some of our structures. Walk up to a marked one and press E to repair it, or talk to me if you decide to leave them. Unrepaired, they will give us far less."},
 "storm_lost_contact": {"speaker": "Dr. Maya Chen", "text": "Commander, we've lost contact with Alex. He went out to check a reading before the storm and hasn't reported back. Take the rover to his last known location and bring him home."}
}
var dialogue_id := "crew_briefing"
var player: Node
var content: VBoxContainer
var previous_blocked := false
var build_hud: CanvasLayer
var previous_build_visible := false

func _ready() -> void:
	name = "MayaIntroduction"
	layer = 95
	player = get_parent().get_node("Outpost/Astronaut")
	previous_blocked = player.ui_blocked
	player.ui_blocked = true
	var placement := get_parent().get_node_or_null("SolarPlacement")
	if placement != null:
		build_hud = placement.hud
		previous_build_visible = build_hud.visible
		build_hud.hide()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	content = VBoxContainer.new()
	root.add_child(content)
	content.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	content.anchor_left = 0.12
	content.anchor_right = 0.88
	content.offset_top = -165
	content.offset_bottom = -35
	content.add_theme_constant_override("separation", 8)
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	var speech: Dictionary = INTRODUCTIONS[dialogue_id]
	var spoken_text: String = speech.text.replace("Commander", get_node("/root/MissionSession").commander_address())
	for entry in [[speech.speaker, Color("ffd36a"), 22], [spoken_text, Color.WHITE, 20]]:
		var label := Label.new()
		label.text = entry[0]
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if entry[0] == speech.speaker:
			var name_font := font.duplicate() as SystemFont
			name_font.font_weight = 600
			label.add_theme_font_override("font", name_font)
		else:
			label.add_theme_font_override("font", font)
		label.add_theme_font_size_override("font_size", entry[2])
		label.add_theme_color_override("font_color", entry[1])
		label.add_theme_color_override("font_outline_color", Color("141820"))
		label.add_theme_constant_override("outline_size", 4)
		content.add_child(label)
		if entry[0] == speech.speaker:
			var divider := TextureRect.new()
			divider.name = "GoldDivider"
			divider.custom_minimum_size.y = 9
			divider.mouse_filter = Control.MOUSE_FILTER_IGNORE
			divider.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			var gradient := Gradient.new()
			gradient.offsets = PackedFloat32Array([0.0, 0.2, 0.5, 0.8, 1.0])
			gradient.colors = PackedColorArray([Color(1, 0.77, 0.3, 0), Color(1, 0.77, 0.3, 0.5), Color(1, 0.86, 0.5, 1), Color(1, 0.77, 0.3, 0.5), Color(1, 0.77, 0.3, 0)])
			var texture := GradientTexture2D.new()
			texture.width = 256
			texture.height = 8
			texture.gradient = gradient
			divider.texture = texture
			var shader := Shader.new()
			shader.code = "shader_type canvas_item; void fragment() { vec4 gold = texture(TEXTURE, UV); float d = abs(UV.y - 0.5); float core = 1.0 - smoothstep(0.05, 0.17, d); float glow = exp(-d * 7.0) * 0.35; COLOR = vec4(gold.rgb, gold.a * min(1.0, core + glow)) * COLOR; }"
			var glow_material := ShaderMaterial.new()
			glow_material.shader = shader
			divider.material = glow_material
			content.add_child(divider)
	content.modulate.a = 0.0
	var fade := create_tween()
	fade.tween_property(content, "modulate:a", 1.0, 0.18)
	fade.tween_interval(maxf(6.0, spoken_text.length() * 0.055)) # Longer lines stay up longer.
	fade.tween_property(content, "modulate:a", 0.0, 0.18)
	fade.tween_callback(func():
		player.ui_blocked = previous_blocked
		finished.emit()
		queue_free())

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.keycode in [KEY_E, KEY_B, KEY_I]:
		get_viewport().set_input_as_handled()

func _exit_tree() -> void:
	if is_instance_valid(player): player.ui_blocked = previous_blocked
	if is_instance_valid(build_hud): build_hud.visible = previous_build_visible

extends Control
## Game ending: plays the ending film with the closing title over it, then the mission
## statistics, where the Commander can keep playing or return to the start menu.
## A failed mission (a reserve stayed empty, or the final review fell short) plays the
## abandoned-outpost film instead and can only return to the start menu.
## Esc or Enter skips the film. Without the film file the title shows on black.
const VIDEO_PATH := "res://Assets/video/ending.ogv"
const TITLE := "Humanity's New Frontier"
const FAILED_VIDEO_PATH := "res://Assets/video/bad_ending.ogv"
const FAILED_TITLE := "The Frontier Falls Silent"
const FAILURE_TEXT := {
	"review_shortfall": "The reserves fell short of the targets at Maya's final review.",
	"oxygen_depleted": "The outpost ran out of oxygen.",
	"water_depleted": "The outpost ran out of water.",
	"food_depleted": "The outpost ran out of food.",
	"power_depleted": "The outpost ran out of power.",
}
const TITLE_AT := 5.0 # Seconds into the film when the title starts to fade in.
const HOLD_AFTER := 3.0 # Seconds the title stays on the film's last frame.
const UI = preload("res://src/ui/ui_style.gd")
const OUTPOST := "res://scenes/lunar_outpost_3d.tscn"
const RESOURCES := [["Power", "power_kwh", "kWh"], ["Water", "water_l", "L"], ["Oxygen", "oxygen_kg", "kg"], ["Food", "food_kg", "kg"]]
var stats_shown := false
var video: VideoStreamPlayer
var title: Label
var cover: ColorRect
var finishing := false
var holding := false
var failed := false

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
	Engine.time_scale = 1.0 # A DEV speed-up must not rush the film.
	var state: Variant = get_node("/root/MissionSession").dashboard_state
	failed = state != null and state.mission_outcome.get("status", "") == "failure"
	var video_path := FAILED_VIDEO_PATH if failed else VIDEO_PATH
	get_node("/root/GameMenu").set_process_input(false)
	# The mission ambience carries across scene changes; silence it under the film.
	var music := get_node("/root/MenuMusic")
	for player in [music.player, music.ambient_player]:
		create_tween().tween_property(player, "volume_linear", 0.0, 1.0)
	var black := ColorRect.new()
	black.color = Color.BLACK
	add_child(black)
	black.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var has_video := ResourceLoader.exists(video_path)
	if has_video:
		var aspect := AspectRatioContainer.new()
		aspect.ratio = 16.0 / 9.0
		add_child(aspect)
		aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		video = VideoStreamPlayer.new()
		video.expand = true
		video.stream = load(video_path)
		aspect.add_child(video)
		video.finished.connect(_hold_then_finish, CONNECT_ONE_SHOT)
	title = Label.new()
	title.text = FAILED_TITLE if failed else TITLE
	title.add_theme_font_override("font", preload("res://Assets/fonts/corpta-demo.regular.otf"))
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", Color("b9c2cf") if failed else Color("f4f7fb"))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.75))
	title.add_theme_constant_override("outline_size", 10)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM if has_video else VERTICAL_ALIGNMENT_CENTER
	title.modulate.a = 0.0
	add_child(title)
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.offset_bottom = -90.0 if has_video else 0.0 # Near the bottom, clear of the frame edge.
	cover = ColorRect.new()
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var fade := create_tween()
	fade.tween_property(cover, "modulate:a", 0.0, 1.0)
	if has_video:
		video.play()
		fade.tween_interval(maxf(0.0, TITLE_AT - 1.0))
		fade.tween_property(title, "modulate:a", 1.0, 2.0)
		return
	fade.tween_property(title, "modulate:a", 1.0, 2.0)
	fade.tween_interval(4.0)
	fade.tween_callback(_finish)

func _process(_delta: float) -> void:
	# Pause just before the end so the last frame stays on screen under the title.
	if is_instance_valid(video) and video.is_playing() and not video.paused and video.get_stream_length() > 0.0 and video.stream_position >= video.get_stream_length() - 0.1:
		video.paused = true
		_hold_then_finish()

## The film's last frame stays on screen with the title, then everything fades to black.
func _hold_then_finish() -> void:
	if finishing or holding: return
	holding = true
	var hold := create_tween()
	hold.tween_property(title, "modulate:a", 1.0, 0.3)
	hold.tween_interval(HOLD_AFTER)
	hold.tween_callback(_finish)

func _input(event: InputEvent) -> void:
	# Skipping only applies to the film; the statistics screen uses its own buttons.
	if finishing: return
	if event.is_action_pressed("ui_cancel") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_finish()

func _finish() -> void:
	if finishing: return
	finishing = true
	var fade := create_tween()
	fade.tween_property(cover, "modulate:a", 1.0, 1.2)
	await fade.finished
	if is_instance_valid(video): video.stop()
	title.hide()
	_show_stats()
	move_child(cover, -1)
	create_tween().tween_property(cover, "modulate:a", 0.0, 0.8)

## Mission statistics in the pause menu's style: outcome, totals, reserves at the start
## and now, and the resource history graph.
func _show_stats() -> void:
	if stats_shown: return
	stats_shown = true
	var menu := get_node("/root/GameMenu")
	var session := get_node("/root/MissionSession")
	var state: Variant = session.dashboard_state
	var backdrop := ColorRect.new()
	var space := ShaderMaterial.new()
	space.shader = preload("res://src/ui/menu_space.gdshader")
	space.set_shader_parameter("earth_texture", preload("res://Assets/earth/Earth_Diffuse_6K.jpg"))
	backdrop.material = space
	add_child(backdrop)
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := MarginContainer.new()
	frame.theme = Theme.new()
	frame.theme.default_font = preload("res://Assets/fonts/corpta-demo.regular.otf")
	for side in ["left", "right"]: frame.add_theme_constant_override("margin_" + side, 42)
	for side in ["top", "bottom"]: frame.add_theme_constant_override("margin_" + side, 28)
	add_child(frame)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layout := UI.box()
	frame.add_child(layout)
	var heading := UI.label("MISSION FAILED" if failed else "MISSION COMPLETE", 34, Color("e0857a") if failed else UI.TEXT)
	heading.add_theme_color_override("font_shadow_color", Color("5a2a26") if failed else Color("28607d"))
	heading.add_theme_constant_override("shadow_offset_y", 3)
	layout.add_child(heading)
	layout.add_child(UI.label("%s  ·  %s" % [_site_name(session), session.commander_address()], 18, UI.AMBER))
	if failed and state != null:
		layout.add_child(UI.label(str(FAILURE_TEXT.get(str(state.mission_outcome.get("failure_reason", "")), "The outpost could not be sustained.")), 18, UI.MUTED))
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	columns.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(columns)
	var left := _panel(columns, menu)
	var right := _panel(columns, menu)
	right.get_parent().get_parent().size_flags_stretch_ratio = 1.4
	if state == null:
		left.add_child(UI.label("No mission data is loaded.", 18, UI.MUTED))
	else:
		_fill_stats(left, state)
		right.add_child(UI.label("RESERVES MISSION BY MISSION", 20, UI.BLUE))
		var chart := preload("res://src/ui/milestone_chart.gd").new()
		chart.set_points(_milestones(state))
		right.add_child(chart)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 16)
	layout.add_child(buttons)
	var keep := UI.button("Continue playing", _continue, state == null or state.mission_outcome.get("status", "") != "success")
	keep.visible = not failed # A failed outpost cannot be continued; start again from the menu.
	keep.tooltip_text = "Return to the outpost. Operation Surface Survey can be flown again."
	var leave := UI.button("Return to main menu", _to_main_menu)
	for button in [keep, leave]:
		button.custom_minimum_size = Vector2(260, 48)
		button.add_theme_font_size_override("font_size", 20)
		button.add_theme_stylebox_override("normal", menu._space_style(Color(0.02, 0.08, 0.13, 0.8), Color(0.18, 0.45, 0.58, 0.65)))
		button.add_theme_stylebox_override("hover", menu._space_style(Color(0.02, 0.28, 0.4, 0.85), Color("55dfff")))
		button.add_theme_stylebox_override("focus", menu._space_style(Color(0, 0, 0, 0), Color("83eaff")))
		buttons.add_child(button)
	(keep if not keep.disabled else leave).grab_focus()

func _panel(parent: Node, menu: Node) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", menu._space_style(Color(0.015, 0.045, 0.075, 0.76), Color(0.16, 0.48, 0.65, 0.55)))
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var content := UI.box()
	scroll.add_child(content)
	return content

func _fill_stats(parent: VBoxContainer, state: Variant) -> void:
	parent.add_child(UI.label("MISSION STATUS", 20, UI.BLUE))
	var expedition: Dictionary = state.rover_expedition
	var built: Array = state.built_structures.keys()
	for line in [
		"Rover operations completed: %d / 3" % expedition.get("completed", []).size(),
		"Rover distance driven: %.2f km" % state.rover_total_distance_km,
		"Structures built: %d" % built.size(),
		"Decisions made: %d" % state.resolved_events.size(),
		"Ice prospect: %s" % str(state.volatile_prospect_status).replace("_", " "),
	]:
		parent.add_child(UI.label(line, 17))
	parent.add_child(UI.label("RESERVES: START → NOW", 20, UI.BLUE))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 6)
	parent.add_child(grid)
	var initial: Dictionary = state.history[0] if not state.history.is_empty() else state.snapshot()
	for entry in RESOURCES:
		var start := float(initial.get(entry[1], 0.0))
		var now := float(state.get(entry[1]))
		var change := now - start
		grid.add_child(preload("res://src/ui/milestone_chart.gd").cell(entry[0], 16, UI.MUTED))
		grid.add_child(preload("res://src/ui/milestone_chart.gd").cell("%.1f" % start, 16))
		grid.add_child(preload("res://src/ui/milestone_chart.gd").cell("%.1f %s" % [now, entry[2]], 16))
		grid.add_child(preload("res://src/ui/milestone_chart.gd").cell("%+.1f" % change, 16, Color("72df9a") if change >= 0.0 else UI.AMBER))

## Landing, each rover operation and the review; older saves recorded none, so they
## fall back to the start and now.
func _milestones(state: Variant) -> Array:
	var points: Array = state.milestones.duplicate(true)
	if points.is_empty():
		var initial: Dictionary = state.history[0] if not state.history.is_empty() else state.snapshot()
		points.append({"label": "Landing", "power_kwh": initial.get("power_kwh", 0.0), "water_l": initial.get("water_l", 0.0), "oxygen_kg": initial.get("oxygen_kg", 0.0), "food_kg": initial.get("food_kg", 0.0)})
	if str(points[-1].get("label", "")) != "Mission review":
		points.append({"label": "Now", "power_kwh": state.power_kwh, "water_l": state.water_l, "oxygen_kg": state.oxygen_kg, "food_kg": state.food_kg})
	return points

func _site_name(session: Node) -> String:
	var document: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json"))
	if document is Dictionary:
		for site in document.get("sites", []):
			if site.get("site_id", "") == session.selected_site_id: return str(site.get("name", ""))
	return "Lunar outpost"

## Back to the outpost in free play: the mission reopens and Surface Survey can be replayed.
func _continue() -> void:
	var session := get_node("/root/MissionSession")
	if not session.continue_after_ending(): return
	# The film silenced the ambience; bring it back before the outpost loads.
	get_node("/root/MenuMusic")._apply_mix()
	get_node("/root/GameMenu").set_process_input(true)
	if get_tree().change_scene_to_file(OUTPOST) != OK:
		get_node("/root/GameMenu").set_process_input(false)

func _to_main_menu() -> void:
	# Back to the start menu without replaying the credits intro.
	var session := get_node("/root/MissionSession")
	session.skip_next_startup_intro = true
	if get_tree().change_scene_to_file("res://scenes/startup.tscn") != OK:
		session.skip_next_startup_intro = false

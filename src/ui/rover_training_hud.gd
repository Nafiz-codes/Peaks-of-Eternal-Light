extends CanvasLayer
var panel: PanelContainer
var title: Label
var objective: Label
var telemetry: Label
var detail: Label
var prompt: Label
var progress: ProgressBar
var result: Label
var waypoint: Label
var extraction_popup: VBoxContainer
var extraction_prompt: Label

func _ready() -> void:
	layer = 86
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	waypoint = Label.new()
	waypoint.custom_minimum_size.x = 280
	waypoint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waypoint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	waypoint.add_theme_font_size_override("font_size", 22)
	waypoint.add_theme_color_override("font_color", Color("83e8ef"))
	waypoint.add_theme_color_override("font_outline_color", Color.BLACK)
	waypoint.add_theme_constant_override("outline_size", 7)
	root.add_child(waypoint)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	panel.offset_left = -430
	panel.offset_right = -18
	panel.offset_top = 18
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.025, 0.055, 0.08, 0.94)
	style.border_color = Color("65dce5")
	style.border_width_left = 2
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)
	title = _label(column, 21, Color("83e8ef"))
	objective = _label(column, 18, Color.WHITE)
	telemetry = _label(column, 15, Color("9ed2db"))
	detail = _label(column, 16, Color("c3d0d8"))
	progress = ProgressBar.new()
	progress.custom_minimum_size.y = 16
	progress.show_percentage = false
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress)
	prompt = _label(column, 16, Color("ffd18a"))
	result = _label(column, 18, Color("83e8ef"))
	panel.hide()
	result.reparent(root)
	result.position = Vector2(22, 290)
	result.size.x = 360
	result.add_theme_font_size_override("font_size", 14)
	result.add_theme_color_override("font_outline_color", Color.BLACK)
	result.add_theme_constant_override("outline_size", 6)
	extraction_popup = VBoxContainer.new()
	root.add_child(extraction_popup)
	extraction_popup.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	extraction_popup.offset_left = -180
	extraction_popup.offset_right = 180
	extraction_popup.offset_top = -160
	extraction_popup.offset_bottom = -90
	extraction_popup.mouse_filter = Control.MOUSE_FILTER_IGNORE
	extraction_prompt = _label(extraction_popup, 18, Color.WHITE)
	extraction_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	extraction_prompt.add_theme_color_override("font_outline_color", Color.BLACK)
	extraction_prompt.add_theme_constant_override("outline_size", 6)
	progress.reparent(extraction_popup)
	get_viewport().size_changed.connect(_layout)
	_layout()
	hide()

func _label(parent: Node, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size.x = 360
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(label)
	return label

func _layout() -> void:
	var factor := clampf(get_viewport().get_visible_rect().size.y / 820.0, 0.65, 1.1)
	panel.scale = Vector2.ONE * factor
	panel.offset_left = -412.0 * factor - 18

func render(view: Dictionary) -> void:
	visible = view.visible
	if not visible: return
	title.text = view.title
	objective.text = view.objective
	telemetry.text = view.telemetry
	detail.text = view.detail
	prompt.text = view.prompt
	progress.value = view.progress * 100.0
	extraction_popup.visible = view.get("extract_nearby", false) or view.progress > 0.0
	extraction_prompt.text = view.get("extract_hint", "Hold E to scan")
	progress.visible = view.progress > 0.0
	result.text = view.result
	var navigation: Dictionary = view.get("navigation", {})
	waypoint.visible = false # MissionTracker owns the shared crescent destination marker.
	if waypoint.visible:
		waypoint.text = navigation.label
		waypoint.position = navigation.screen

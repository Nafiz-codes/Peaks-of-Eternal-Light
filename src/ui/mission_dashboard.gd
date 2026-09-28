extends Control

## Static Day 4 shell. It presents setup examples and makes no simulator calls.

const OutpostPreview = preload("res://src/ui/outpost_preview.gd")
const SPACE := Color("0b0d16")
const PANEL := Color("171c2b")
const TERRAIN := Color("101521")
const EDGE := Color("66738f")
const TEXT := Color("f1f3fa")
const MUTED := Color("b6c1d8")
const PURPLE := Color("b7a2ff")
const BLUE := Color("91cfff")
const AMBER := Color("ffd18a")

var readings: GridContainer
var identity_block: VBoxContainer
var left_column: VBoxContainer
var right_column: VBoxContainer


func _ready() -> void:
	get_viewport().size_changed.connect(_update_layout)
	_build()
	_update_layout()


func _build() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = SPACE
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(backdrop)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var page := MarginContainer.new()
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		page.add_theme_constant_override("margin_" + side, 28)
	scroll.add_child(page)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	page.add_child(column)

	var top := HFlowContainer.new()
	top.add_theme_constant_override("h_separation", 24)
	top.add_theme_constant_override("v_separation", 10)
	column.add_child(top)
	var identity := VBoxContainer.new()
	identity_block = identity
	identity.custom_minimum_size.x = 520
	top.add_child(identity)
	identity.add_child(_label("△  △  △     TRIARCHY / MISSION CONTROL", 15, PURPLE))
	identity.add_child(_label("Peaks of Eternal Light", 34, TEXT))
	identity.add_child(_label("by TRIARCHY", 14, MUTED))
	var clock := _panel()
	clock.custom_minimum_size = Vector2(245, 80)
	top.add_child(clock)
	var clock_text := VBoxContainer.new()
	clock_text.add_child(_label("RIDGE A / SETUP EXAMPLE", 13, BLUE))
	clock_text.add_child(_label("SOL 00 / 10", 25, TEXT))
	clock.add_child(clock_text)

	column.add_child(_rule())
	column.add_child(_label("MISSION DASHBOARD  /  STATIC UI PREVIEW", 15, PURPLE))
	column.add_child(_label("Example setup reserves from MissionSimulator. No mission is running.", 15, MUTED))
	readings = GridContainer.new()
	readings.columns = 6
	readings.add_theme_constant_override("h_separation", 10)
	readings.add_theme_constant_override("v_separation", 10)
	column.add_child(readings)
	_add_reading("ENERGY RESERVE", "120", "kWh", BLUE)
	_add_reading("WATER", "400", "L", BLUE)
	_add_reading("OXYGEN", "45", "kg · status pending", BLUE)
	_add_reading("FOOD", "30", "kg", BLUE)
	_add_reading("ACCUMULATED DOSE", "0", "mSv", AMBER)
	_add_reading("MATERIALS", "180", "game units", PURPLE)

	var content := HFlowContainer.new()
	content.add_theme_constant_override("h_separation", 16)
	content.add_theme_constant_override("v_separation", 16)
	column.add_child(content)
	var left := VBoxContainer.new()
	left_column = left
	left.custom_minimum_size.x = 560
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	content.add_child(left)
	var map_panel := _panel()
	left.add_child(map_panel)
	var map_stack := VBoxContainer.new()
	map_stack.add_theme_constant_override("separation", 12)
	map_panel.add_child(map_stack)
	map_stack.add_child(_label("OUTPOST / COMPOSITION STUDY", 16, TEXT))
	map_stack.add_child(_label("Habitat             Solar array             Rover", 14, BLUE))
	var preview := OutpostPreview.new()
	preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	map_stack.add_child(preview)
	map_stack.add_child(_label("Schematic placement only · infrastructure and rover state pending", 13, MUTED))
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 10)
	left.add_child(actions)
	actions.add_child(_disabled_button("BUILD / PLANNED"))
	actions.add_child(_disabled_button("ROVER / PLANNED"))
	var science := _panel()
	left.add_child(science)
	science.add_child(_label("MISSION SCIENCE / Authored explanations appear after integration.", 14, MUTED))

	var right := VBoxContainer.new()
	right_column = right
	right.custom_minimum_size.x = 310
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 16)
	content.add_child(right)
	var crew := _panel()
	right.add_child(crew)
	var crew_text := VBoxContainer.new()
	crew_text.add_theme_constant_override("separation", 8)
	crew.add_child(crew_text)
	crew_text.add_child(_label("CREW / 4 ROLES", 16, TEXT))
	for role in ["Commander", "Systems Engineer", "Botanist / Life Support", "Medical Officer"]:
		crew_text.add_child(_label("◇  " + role, 15, MUTED))
	crew_text.add_child(_label("Names pending · live health unavailable", 13, AMBER))
	var activity := _panel()
	right.add_child(activity)
	var activity_text := VBoxContainer.new()
	activity_text.add_theme_constant_override("separation", 8)
	activity.add_child(activity_text)
	activity_text.add_child(_label("MISSION ACTIVITY", 16, TEXT))
	activity_text.add_child(_label("No active events in the setup example.", 15, MUTED))
	activity_text.add_child(_label("Objective: sustain the crew for 10 sols.", 14, MUTED))
	activity_text.add_child(_label("Outcome rules pending", 13, AMBER))

	var warning := _panel()
	column.add_child(warning)
	warning.add_child(_label("!  MODEL IN PREPARATION / Resource trends and safety thresholds are unavailable.", 14, AMBER))
	var footer := HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", 18)
	footer.add_theme_constant_override("v_separation", 8)
	column.add_child(footer)
	footer.add_child(_label("SITE DATA UNVERIFIED     ·     PRESENTATION PREVIEW", 13, MUTED))
	footer.add_child(_disabled_button("RUN THE SOL / PLANNED"))


func _add_reading(title: String, value: String, unit: String, accent: Color) -> void:
	var card := _panel()
	card.custom_minimum_size.x = 158
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	readings.add_child(card)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 2)
	card.add_child(stack)
	stack.add_child(_label(title, 12, MUTED))
	stack.add_child(_label(value, 28, accent))
	stack.add_child(_label(unit, 13, MUTED))


func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	return panel


func _label(value: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_color_override("font_color", color)
	label.add_theme_font_size_override("font_size", font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label


func _disabled_button(value: String) -> Button:
	var button := Button.new()
	button.text = value
	button.disabled = true
	button.custom_minimum_size.y = 44
	button.add_theme_color_override("font_disabled_color", MUTED)
	var style := StyleBoxFlat.new()
	style.bg_color = TERRAIN
	style.border_color = EDGE
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.content_margin_left = 14
	style.content_margin_right = 14
	button.add_theme_stylebox_override("disabled", style)
	return button


func _rule() -> ColorRect:
	var rule := ColorRect.new()
	rule.color = EDGE
	rule.custom_minimum_size.y = 1
	return rule


func _update_layout() -> void:
	if readings == null:
		return
	var width := get_viewport_rect().size.x
	readings.columns = 6 if width >= 1220 else (3 if width >= 700 else 2)
	identity_block.custom_minimum_size.x = minf(520.0, width - 56.0)
	left_column.custom_minimum_size.x = 560.0 if width >= 1000 else maxf(0.0, width - 56.0)
	right_column.custom_minimum_size.x = 310.0 if width >= 1000 else maxf(0.0, width - 56.0)

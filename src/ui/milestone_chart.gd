extends VBoxContainer
## Reserves at each mission milestone (landing, each rover operation, the review),
## one resource at a time, plus a table of every reserve per milestone.
const UI = preload("res://src/ui/ui_style.gd")
const FIELDS := {"power_kwh": ["Power", "kWh"], "water_l": ["Water", "L"], "oxygen_kg": ["Oxygen", "kg"], "food_kg": ["Food", "kg"]}
var points: Array = [] # [{label, power_kwh, water_l, oxygen_kg, food_kg}]
var selected_field := "power_kwh"
var chart: Control

func set_points(milestones: Array) -> void:
	points = milestones.duplicate(true)

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var select := OptionButton.new()
	select.custom_minimum_size.y = 40
	for field in FIELDS:
		select.add_item("%s (%s)" % FIELDS[field])
	select.item_selected.connect(func(index: int):
		selected_field = FIELDS.keys()[index]
		chart.queue_redraw())
	add_child(select)
	chart = Control.new()
	chart.custom_minimum_size.y = 190
	chart.draw.connect(_draw_chart)
	chart.resized.connect(chart.queue_redraw)
	add_child(chart)
	# Every reserve at every milestone, with the change since the one before.
	var grid := GridContainer.new()
	grid.columns = 1 + FIELDS.size()
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 4)
	add_child(grid)
	grid.add_child(cell("Mission", 14, UI.MUTED))
	for field in FIELDS:
		grid.add_child(cell("%s (%s)" % FIELDS[field], 14, UI.MUTED))
	for index in points.size():
		var entry: Dictionary = points[index]
		grid.add_child(cell(short_label(str(entry.label)), 15))
		for field in FIELDS:
			var value := float(entry.get(field, 0.0))
			var text := "%.1f" % value
			if index > 0:
				var change := value - float(points[index - 1].get(field, 0.0))
				text += "  (%+.1f)" % change
			grid.add_child(cell(text, 15, UI.TEXT if index == 0 else (Color("72df9a") if value >= float(points[index - 1].get(field, 0.0)) else UI.AMBER)))

## A table cell that keeps its text on one line. Wrapping labels in a grid get no
## width of their own and collapse to one character per line.
static func cell(text: String, font_size: int, color: Color = UI.TEXT) -> Label:
	var label := UI.label(text, font_size, color)
	label.autowrap_mode = TextServer.AUTOWRAP_OFF
	return label

static func short_label(label: String) -> String:
	return label.trim_prefix("Operation ")

func _draw_chart() -> void:
	var font := ThemeDB.fallback_font
	if points.size() < 2:
		chart.draw_string(font, Vector2(8, 40), "Not enough milestones recorded yet.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, UI.MUTED)
		return
	var maximum := 0.001
	for entry in points: maximum = maxf(maximum, float(entry.get(selected_field, 0.0)))
	var area := Rect2(48, 12, maxf(1.0, chart.size.x - 96), 140)
	chart.draw_line(area.position, Vector2(area.position.x, area.end.y), UI.MUTED)
	chart.draw_line(Vector2(area.position.x, area.end.y), area.end, UI.MUTED)
	chart.draw_string(font, Vector2(0, 18), "%.0f" % maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	chart.draw_string(font, Vector2(30, area.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	var previous := Vector2.ZERO
	for index in points.size():
		var value := float(points[index].get(selected_field, 0.0))
		var point := Vector2(area.position.x + area.size.x * index / (points.size() - 1), area.end.y - value / maximum * area.size.y)
		if index > 0: chart.draw_line(previous, point, UI.BLUE, 2.0, true)
		chart.draw_circle(point, 4, UI.PURPLE)
		chart.draw_string(font, point + Vector2(-20, -10), "%.0f" % value, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.TEXT)
		# Milestone names along the bottom, centred under their points.
		var name := short_label(str(points[index].get("label", "")))
		chart.draw_string(font, Vector2(point.x - 50, area.end.y + 22), name, HORIZONTAL_ALIGNMENT_CENTER, 100, 12, UI.MUTED)
		previous = point

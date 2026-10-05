extends VBoxContainer

## One resource per chart avoids mixing unlike units. Text rows remain available.
const UI = preload("res://src/ui/ui_style.gd")
const FIELDS := {"power_kwh": ["Energy", "kWh"], "water_l": ["Water", "L"], "oxygen_kg": ["Oxygen", "kg"], "food_kg": ["Food", "kg"], "radiation_msv": ["Accumulated dose", "mSv"], "materials": ["Materials", "units"]}
var records: Array = []
var selected_field := "power_kwh"
var chart: Control
var summary: Label
var table: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(UI.label("RESOURCE HISTORY", 18))
	var select := OptionButton.new()
	select.custom_minimum_size.y = 44
	for field in FIELDS:
		select.add_item("%s (%s)" % FIELDS[field])
	select.item_selected.connect(func(index: int):
		selected_field = FIELDS.keys()[index]
		_refresh())
	add_child(select)
	summary = UI.label("", 14, UI.BLUE)
	add_child(summary)
	chart = Control.new()
	chart.custom_minimum_size.y = 160
	chart.draw.connect(_draw_chart)
	chart.resized.connect(func(): chart.queue_redraw())
	add_child(chart)
	table = UI.label("", 14)
	add_child(table)
	_refresh()

func set_history(history: Array) -> void:
	records = history.duplicate(true)
	if is_node_ready():
		_refresh()

func _refresh() -> void:
	var descriptor: Array = FIELDS[selected_field]
	var lines := PackedStringArray()
	for record in records:
		var value: Variant = record.get(selected_field)
		lines.append("Sol %s / %s %s" % [record.get("sol", "?"), "%.3f" % float(value) if value is float or value is int else "Unavailable", descriptor[1]])
	table.text = "\n".join(lines) if not lines.is_empty() else "No recorded history."
	summary.text = "%s (%s) · Each point is one recorded sol; scale starts at zero." % descriptor
	chart.visible = not records.is_empty()
	chart.queue_redraw()

func _draw_chart() -> void:
	var valid: Array = []
	var maximum := 0.0
	var last_sol := 1.0
	for record in records:
		var value: Variant = record.get(selected_field)
		if (value is float or value is int) and is_finite(float(value)) and record.has("sol"):
			maximum = maxf(maximum, float(value))
			last_sol = maxf(last_sol, float(record.sol))
			valid.append(record)
	var area := Rect2(44, 14, maxf(1, chart.size.x - 58), 118)
	chart.draw_line(area.position, Vector2(area.position.x, area.end.y), UI.MUTED)
	chart.draw_line(Vector2(area.position.x, area.end.y), area.end, UI.MUTED)
	var font := ThemeDB.fallback_font
	chart.draw_string(font, Vector2(0, 16), "%.1f" % maximum, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	chart.draw_string(font, Vector2(12, area.end.y), "0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	chart.draw_string(font, Vector2(44, 154), "Sol 0", HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	chart.draw_string(font, Vector2(area.end.x - 48, 154), "Sol %d" % int(last_sol), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, UI.MUTED)
	var previous := Vector2.ZERO
	for index in range(valid.size()):
		var record: Dictionary = valid[index]
		var point := Vector2(area.position.x + float(record.sol) / last_sol * area.size.x, area.end.y - float(record[selected_field]) / maxf(maximum, 0.001) * area.size.y)
		if index > 0:
			chart.draw_line(previous, point, UI.BLUE, 2.0, true)
		chart.draw_circle(point, 3, UI.PURPLE)
		previous = point

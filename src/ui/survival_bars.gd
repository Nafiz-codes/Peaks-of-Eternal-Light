extends Control
## Live campaign reserves in the upper-right HUD.
const RESOURCES := {
 "power_kwh": ["Power", Color("65869c")],
 "food_kg": ["Food", Color("637d96")],
 "oxygen_kg": ["Oxygen", Color("6e95a5")],
 "water_l": ["Water", Color("5d819f")]
}
const UNITS := {"power_kwh": "kWh", "food_kg": "kg", "oxygen_kg": "kg", "water_l": "L"}
var bars: Dictionary = {}
var captions: Dictionary = {}
var maxima: Dictionary = {}
var state_reference: RefCounted
func _ready() -> void:
 name = "SurvivalBars"
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
 offset_left = -372 # Wide enough for each one-line caption.
 offset_right = -22
 offset_top = 150
 offset_bottom = 390
 # Anything wider than the column grows leftwards, never off the right edge.
 grow_horizontal = Control.GROW_DIRECTION_BEGIN
 # Shrink the entire group around its upper-right corner.
 pivot_offset = Vector2(350, 0)
 scale = Vector2(0.8, 0.8)
 var column := VBoxContainer.new()
 column.mouse_filter = Control.MOUSE_FILTER_IGNORE
 column.add_theme_constant_override("separation", 6)
 add_child(column)
 column.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 for key in RESOURCES:
  var group := VBoxContainer.new()
  group.mouse_filter = Control.MOUSE_FILTER_IGNORE
  group.add_theme_constant_override("separation", -2)
  column.add_child(group)
  var caption := Label.new()
  caption.text = RESOURCES[key][0]
  caption.add_theme_font_size_override("font_size", 14)
  caption.add_theme_color_override("font_outline_color", Color.BLACK)
  caption.add_theme_constant_override("outline_size", 4)
  caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
  caption.add_theme_constant_override("indent", 40)
  group.add_child(caption)
  captions[key] = caption
  var bar := preload("res://src/ui/survival_meter.gd").new()
  bar.kind = key
  bar.tint = RESOURCES[key][1]
  bar.custom_minimum_size.y = 40
  group.add_child(bar)
  bars[key] = bar
func _process(_delta: float) -> void:
 var session := get_node("/root/MissionSession")
 var state: RefCounted = session.dashboard_state
 visible = state != null
 if state == null: return
 if state != state_reference:
  state_reference = state
  maxima.clear()
  var initial: Dictionary = state.history[0] if not state.history.is_empty() else state.snapshot()
  for key in RESOURCES:
   maxima[key] = maxf(1.0, float(initial.get(key, 1.0)))
 var goals: Dictionary = preload("res://src/simulation/mission_simulator.gd").MISSION_GOALS
 for key in RESOURCES:
  var amount := float(state.get(key))
  # A full bar is the outpost's storage (the battery for power): nothing is kept past it.
  var cap: float = session.dashboard_simulator.capacity(state, key) if session.dashboard_simulator != null else INF
  maxima[key] = cap if is_finite(cap) else maxf(maxf(float(maxima.get(key, 1.0)), amount), float(goals[key]) * 1.25)
  bars[key].max_value = maxima[key]
  bars[key].value = maxf(0.0, amount)
  bars[key].goal = float(goals[key])
  bars[key].queue_redraw()
  var rate: float = {"power_kwh": state.power_balance_kwh, "water_l": state.water_balance_l, "oxygen_kg": -state.oxygen_consumed_kg, "food_kg": -state.food_consumed_kg}[key]
  captions[key].text = "%s  %d/%d %s · goal %d · %+.1f/day" % [RESOURCES[key][0], int(amount), int(maxima[key]), UNITS[key], int(goals[key]), rate]

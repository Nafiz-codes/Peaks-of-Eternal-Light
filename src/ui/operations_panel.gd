extends AcceptDialog

## Read-only catalog and runtime inspection, shared by world and dashboard.
const UI = preload("res://src/ui/ui_style.gd")
signal placement_preview_requested(structure_id: String)
var content: VBoxContainer
var return_focus: WeakRef

func _ready() -> void:
	title = "Outpost operations"
	exclusive = true
	min_size = Vector2i(300, 300)
	get_ok_button().text = "Close"
	get_ok_button().custom_minimum_size.y = 44
	add_theme_stylebox_override("panel", UI.style(Color("171c2b"), UI.BLUE))
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 18
	scroll.offset_top = 14
	scroll.offset_right = -18
	scroll.offset_bottom = -64
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = UI.box()
	scroll.add_child(content)
	visibility_changed.connect(func():
		if not visible and return_focus != null and is_instance_valid(return_focus.get_ref()):
			return_focus.get_ref().grab_focus())

func open_operations(kind: String, state: Variant, contract: Dictionary, invoker: Control = null, allow_preview: bool = false) -> void:
	return_focus = weakref(invoker) if invoker != null else null
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	title = "Construction planning" if kind == "build" else "Rover operations"
	content.add_child(UI.label(title.to_upper(), 22, UI.BLUE))
	content.add_child(UI.label("Planning and inspection only. Operations are unavailable in this build.", 15, UI.AMBER))
	if kind == "build":
		var structures: Array = contract.get("structures", [])
		if structures.is_empty():
			content.add_child(UI.label("Construction catalog unavailable."))
		for structure in structures:
			var id := str(structure.get("structure_id", ""))
			var card := UI.panel(content)
			card.add_child(UI.label(str(structure.get("name", id)), 19))
			var cost: Dictionary = structure.get("build_cost", {})
			card.add_child(UI.label("Materials: %s units · Energy: %s kWh · Build time: %s sols" % [cost.get("materials", "Unavailable"), cost.get("power", "Unavailable"), structure.get("build_time_sols", "Unavailable")], 14, UI.BLUE))
			card.add_child(UI.label(str(structure.get("effect", "Effect description unavailable.")), 14))
			var built: bool = state != null and state.built_structures.has(id)
			card.add_child(UI.label("Completed / recorded by simulation" if built else "Not recorded as completed", 14, UI.PURPLE))
			card.add_child(UI.button("Build unavailable", Callable(), true))
			if allow_preview and not built:
				card.add_child(UI.button("Preview illustrative placement", func():
					placement_preview_requested.emit(id)
					hide()))
	else:
		var rover: Dictionary = contract.get("vehicles", {}).get("rover", {})
		content.add_child(UI.label("Travel energy: %s kWh/km\nDistance cap: %s km/sol\nDiscovery chance: %s%% per new km" % [rover.get("move_cost_power_per_km", "Unavailable"), rover.get("max_distance_per_sol_km", "Unavailable"), rover.get("discovery_chance_pct_per_km", "Unavailable")]))
		content.add_child(UI.label("Last recorded action: " + ("None" if state == null or str(state.last_rover_action).is_empty() else str(state.last_rover_action)), 16, UI.BLUE))
		content.add_child(UI.label("Prospect: " + ("No mission" if state == null else str(state.volatile_prospect_status)), 16))
		content.add_child(UI.label("No confirmed route is available. The rover remains parked.", 14, UI.AMBER))
		content.add_child(UI.button("Dispatch unavailable", Callable(), true))
		UI.disclosure(content, "Parameter sources and assumptions", str(rover.get("notes", "Source notes unavailable.")))
	popup_centered_clamped(Vector2i(740, 620), 0.9)
	get_ok_button().grab_focus()

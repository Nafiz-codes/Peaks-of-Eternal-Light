extends Control
const UI = preload("res://src/ui/ui_style.gd")
const Planner = preload("res://src/simulation/mission_planner.gd")
const STEPS := ["Construction zone", "Solar planning", "Battery planning", "Cargo transportation", "Cargo manifest", "Final mission approval"]
var planner := Planner.new()
var session: Node
var body: VBoxContainer
var notice := ""
var scroller: ScrollContainer

func _ready() -> void:
	session = get_node("/root/MissionSession")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	session.begin_planning()
	_render()

func _render() -> void:
	var old_scroll := scroller.scroll_vertical if is_instance_valid(scroller) else 0
	var focused := get_viewport().gui_get_focus_owner()
	var focus_text: String = focused.text + "|" + focused.tooltip_text if focused is Button and is_ancestor_of(focused) else ""
	for child in get_children():
		remove_child(child)
		child.queue_free()
	var background := ColorRect.new()
	background.color = Color("090f1c")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left","right","top","bottom"]: margin.add_theme_constant_override("margin_"+edge,20)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroller = scroll
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	body = UI.box()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	var p: Dictionary = session.planning_draft
	if not planner.shape_valid(p):
		body.add_child(UI.label("No valid planning draft. Select an outpost to begin."))
		body.add_child(UI.button("Outpost selection",func(): get_tree().change_scene_to_file("res://scenes/lunar_landing_selector.tscn")))
		return
	var result := planner.evaluate(p)
	var site := planner.site(p.site_id)
	body.add_child(UI.label("PRE-LANDING / " + site.name,28,UI.BLUE))
	body.add_child(UI.label("%d / 6 — %s" % [p.step+1,STEPS[p.step]],22))
	var focus := {"ridge_a":"Balance array capacity, cable length and reserves.","shadow_zone":"Balance infrastructure and rover transport; local ice is unconfirmed.","crater_rim_b":"Protect critical loads through low-sun periods with paid storage.","plateau_d":"Compare terrain slopes, compact layouts and handling costs."}
	body.add_child(UI.label(focus[p.site_id],16,UI.AMBER))
	body.add_child(UI.label("NASA-derived: LOLA terrain and site horizon; JPL Horizons geometry, epoch 19 Oct 2026 UTC. Gameplay-modeled: flattened zones, routes, hardware, cable losses and cargo units. No certified landing pads or confirmed recoverable ice. Site-level solar exposure applies to every placement.",14,UI.MUTED))
	var nav := HFlowContainer.new()
	body.add_child(nav)
	for i in range(STEPS.size()):
		var button := UI.button("Edit " + str(i+1),_step.bind(i),i==p.step)
		button.custom_minimum_size.x = 100
		button.tooltip_text = STEPS[i]
		nav.add_child(button)
	body.add_child(UI.label("%s · cargo %.0f / %.0f units · power reserve margin %+.1f kWh" % [result.status,result.cargo_units,planner.config.capacity_units,result.margin_kwh],18,UI.AMBER))
	match p.step:
		0:
			for zone in planner.zones(p.site_id):
				body.add_child(UI.button("%s%s — %.1f° max slope · %.0f m² · %.0f preparation materials\nLocal x/z (%d, %d), footprint %d × %d m; gameplay terrain" % ["Selected: " if p.zone_id==zone.id else "",zone.name,zone.slope_deg,zone.area_m2,zone.materials,zone.x,zone.z,zone.radius*2,zone.radius*2],_choose.bind("zone_id",zone.id)))
		1:
			body.add_child(UI.label("Sun-tracking baseline: 65 kWh/day potential. Each additional array adds 18 kWh/day before the shared site visibility and distance factor. Placement changes cable cost and electrical loss; distributed layout reduces reserved space per array at extra material cost. No invented local sunlight advantage."))
			for placement in ["near","extended"]: body.add_child(UI.button(("Selected: " if p.solar_placement==placement else "")+placement.capitalize()+" connection"+(" (+10 m cable; 8 materials; 4 m² per array)" if placement=="extended" else " (short connection; 6 m² per array)"),_choose.bind("solar_placement",placement)))
			_quantity("array")
			_quantity("cable")
			_quantity("materials")
		2:
			body.add_child(UI.label("Baseline storage: 300 kWh, initially 290 kWh. Each battery adds 100 kWh capacity and 90 kWh precharged energy. Finite storage only; no unlimited backup generator. Required reserve: 12 hours of full baseline load."))
			_quantity("battery")
			var interval := SpinBox.new()
			interval.min_value = 24
			interval.max_value = 336
			interval.step = 24
			interval.value = p.hours
			interval.suffix = " evaluation hours"
			interval.value_changed.connect(func(value: float): _choose("hours",int(value)))
			body.add_child(interval)
			for day in result.timeline: body.add_child(UI.label("Hour %d: %.1f kWh battery" % [day.hour,day.battery_kwh],14))
		3:
			body.add_child(UI.label("Routes sample the actual playable terrain at ≤1 m spacing. Energy = round-trip distance × trips × existing rover rate × (1 + maximum slope / 10°). Slope/load factors and deployment points are gameplay estimates. No cargo is moved."))
			for deployment in planner.config.deployments: body.add_child(UI.button(("Selected: " if p.deployment_id==deployment.id else "")+deployment.name+" (%d, %d)" % [deployment.x,deployment.z],_choose.bind("deployment_id",deployment.id)))
			for route in ["direct","east_detour"]:
				var trial := p.duplicate(true)
				trial.route_id = route
				var estimate := planner.route(trial,result.cargo_units)
				body.add_child(UI.button("%s%s: %.1f m · %.1f° · %.2f kWh · %s" % ["Selected: " if p.route_id==route else "",route,estimate.distance_m,estimate.max_slope_deg,estimate.energy_kwh,"feasible" if estimate.feasible else "infeasible"],_choose.bind("route_id",route)))
			_quantity("handling")
		4:
			body.add_child(UI.label("Capacity uses gameplay cargo units, not kilograms. Mandatory supplies retain simulator reserves: 500 L water, 56.25 kg oxygen and 37.5 kg dry food. Consumable mass units follow the existing resource model."))
			for item in planner.config.equipment: _quantity(item.id)
		5:
			body.add_child(UI.label("%s [%s]\nZone: %s · placement: %s · additional arrays: %d · additional batteries: %d\nDeployment: %s · route: %s · evaluation: %d hours" % [site.name,p.site_id,result.zone.name,p.solar_placement,p.cargo.array,p.cargo.battery,p.deployment_id,p.route_id,p.hours]))
			for item in planner.config.equipment: body.add_child(UI.label("%s × %d — %d cargo units%s" % [item.name,p.cargo[item.id],item.units*p.cargo[item.id]," (mandatory)" if item.mandatory else ""],14))
			body.add_child(UI.button("Confirm valid mission plan",_approve,not result.valid))
			if not session.approved_plan.is_empty():
				body.add_child(UI.label("An approved plan is saved; delivery remains pending. Save later draft edits before closing. Continuing opens the existing outpost stage without applying planned cargo or construction."))
				body.add_child(UI.button("Continue to existing outpost",_handoff,session.approved_plan.plan!=p))
	var summary := UI.panel(body)
	summary.add_child(UI.label("%s · Cargo %.0f / %.0f · %.0f units remaining" % [result.status,result.cargo_units,planner.config.capacity_units,result.remaining_units],20,UI.BLUE))
	summary.add_child(UI.label("Power: %.1f generated / %.1f consumed kWh over %d h · %.2f kW baseline\nBattery: %.1f capacity · %.1f minimum · %.1f required reserve · %+.1f margin kWh\nInfrastructure: %.1f m cable · %.0f materials required / %.0f remaining · %.1f kWh construction\nTransport: %.1f m one way · %d round trips · %.2f km total · %.2f kWh\nEnd supplies: %.1f L water · %.1f kg oxygen · %.1f kg food" % [result.generated_kwh,result.consumed_kwh,p.hours,result.demand_kw,result.capacity_kwh,result.minimum_kwh,result.reserve_kwh,result.margin_kwh,result.cable_m,result.materials_required,result.materials_remaining,result.construction_energy_kwh,result.transport.distance_m,result.transport.trips,result.transport.total_km,result.transport.energy_kwh,result.supplies.water_l,result.supplies.oxygen_kg,result.supplies.food_kg]))
	for error in result.errors: summary.add_child(UI.label(error,16,UI.AMBER))
	if not notice.is_empty(): body.add_child(UI.label(notice,16,UI.AMBER))
	var actions := HFlowContainer.new()
	body.add_child(actions)
	actions.add_child(UI.button("Back",_step.bind(p.step-1)))
	if p.step<5: actions.add_child(UI.button("Continue",_step.bind(p.step+1)))
	actions.add_child(UI.button("Save planning",_save))
	actions.add_child(UI.button("Load planning save",_load_save))
	for button in actions.get_children(): button.custom_minimum_size.x = 180
	_restore_view.call_deferred(old_scroll,focus_text)

func _restore_view(offset: int, focus_text: String) -> void:
	if not is_instance_valid(scroller): return
	scroller.scroll_vertical = offset
	for button in body.find_children("*","Button",true,false):
		if button.text + "|" + button.tooltip_text==focus_text and not button.disabled:
			button.grab_focus()
			break

func _quantity(id: String) -> void:
	var item := planner._entry(planner.config.equipment,id)
	var row := UI.box()
	body.add_child(row)
	row.add_child(UI.label("%s × %d · %d units each%s\n%s" % [item.name,session.planning_draft.cargo[id],item.units," — mandatory" if item.mandatory else "",item.benefit],15))
	if not item.mandatory:
		var controls := HBoxContainer.new()
		row.add_child(controls)
		for delta in [-1,1]:
			var button := UI.button("Remove one" if delta<0 else "Add one",_adjust.bind(id,delta))
			button.custom_minimum_size.x = 150
			button.tooltip_text = item.name
			controls.add_child(button)

func _adjust(id: String, delta: int) -> void:
	notice = "" if planner.set_quantity(session.planning_draft,id,session.planning_draft.cargo[id]+delta) else "Change rejected: quantity or cargo-capacity limit."
	_render()

func _choose(key: String, value: Variant) -> void:
	session.planning_draft[key] = value
	_render()

func _step(index: int) -> void:
	if index<0:
		get_tree().change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
		return
	if is_instance_valid(scroller): scroller.scroll_vertical = 0
	_choose("step",index)

func _approve() -> void:
	var result: Dictionary = session.approve_planning()
	notice = "Plan approved and saved; cargo is reserved on paper only." if result.valid else str(result.errors)
	_render()

func _save() -> void:
	var error: int = session.save_slot("user://mission-planning.save")
	notice = "Planning saved." if error==OK else "Save failed: " + error_string(error)
	_render()

func _load_save() -> void:
	var error: int = session.load_slot("user://mission-planning.save")
	notice = "Planning restored." if error==OK else "Could not restore planning: " + error_string(error)
	_render()

func _handoff() -> void:
	if session.approved_plan.get("plan",{}) != session.planning_draft: return
	var error := get_tree().change_scene_to_file("res://scenes/lunar_outpost_3d.tscn")
	if error != OK:
		notice = "Could not open the outpost: " + error_string(error)
		_render()

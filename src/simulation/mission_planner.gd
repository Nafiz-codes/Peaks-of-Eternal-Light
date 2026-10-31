extends RefCounted
## Planning only: never mutates inventory or constructs/delivers equipment.
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const Solar = preload("res://src/simulation/polar_solar.gd")
const Terrain = preload("res://src/world/polar_terrain.gd")
const MODEL_REVISION := "planning-1 / 2026-10-31-polar"
var simulator := Simulator.new()
var config: Dictionary
var yield_cache: Dictionary = {}

func _init() -> void:
	simulator.load_contracts()
	config = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/mission_planning.json"))

func site(id: String) -> Dictionary:
	for record in simulator.sites:
		if record.site_id == id: return record
	return {}

func data_signature(id: String) -> String:
	return var_to_bytes([site(id),config,simulator.bvad_constants,simulator.construction,FileAccess.get_sha256("res://Resources/polar/%s_terrain.json" % id),FileAccess.get_sha256("res://Resources/polar/ephemeris.json")]).hex_encode().sha256_text()

func default_plan(id: String) -> Dictionary:
	var cargo := {}
	for item in config.equipment: cargo[item.id] = 1 if item.mandatory else 0
	cargo.array = 3
	cargo.battery = 2
	cargo.materials = 4
	cargo.cable = 2
	return {"revision": 1, "site_id": id, "zone_id": "compact", "deployment_id": "north", "route_id": "direct", "solar_placement": "near", "hours": 168, "step": 0, "cargo": cargo}

func shape_valid(p: Variant) -> bool:
	if not p is Dictionary: return false
	for key in ["site_id", "zone_id", "deployment_id", "route_id", "solar_placement"]:
		if not p.get(key) is String: return false
	if site(p.site_id).is_empty() or p.get("revision") != 1: return false
	for key in ["hours", "step"]:
		if not p.get(key) is int: return false
	if p.hours < 24 or p.hours > 336 or p.hours % 24 != 0 or p.step < 0 or p.step > 5: return false
	if not p.get("cargo") is Dictionary or p.cargo.size() != config.equipment.size(): return false
	for item in config.equipment:
		var n: Variant = p.cargo.get(item.id)
		if not n is int or n < 0 or n > int(item.max): return false
		if item.mandatory and n != 1: return false
	return not _entry(config.zones, p.zone_id).is_empty() and not _entry(config.deployments, p.deployment_id).is_empty() and p.route_id in ["direct", "east_detour"] and p.solar_placement in ["near", "extended"]

func _entry(entries: Array, id: String) -> Dictionary:
	for entry in entries:
		if entry.id == id: return entry
	return {}

func _point(entry: Dictionary) -> Vector2:
	return Vector2(entry.x, entry.z)

func height(id: String, p: Vector2) -> float:
	# Same 2 m triangles as OutpostTerrain, including the departure clearing.
	var cell := Vector2(floor(p.x / 2.0), floor(p.y / 2.0)) * 2.0
	var uv := (p - cell) / 2.0
	var a := _vertex(id, cell)
	var b := _vertex(id, cell + Vector2(2, 0))
	var c := _vertex(id, cell + Vector2(0, 2))
	var d := _vertex(id, cell + Vector2(2, 2))
	return a + (b-a)*uv.x + (c-a)*uv.y if uv.x + uv.y <= 1 else d + (c-d)*(1-uv.x) + (b-d)*(1-uv.y)

func _vertex(id: String, p: Vector2) -> float:
	return lerpf(1.0, Terrain.height(id, p.x, p.y), smoothstep(8.0, 16.0, p.distance_to(Vector2(32,12))))

func zones(id: String) -> Array:
	var result := []
	for entry in config.zones:
		var zone: Dictionary = entry.duplicate(true)
		var slope := 0.0
		for x in range(-int(zone.radius), int(zone.radius) + 1, 2):
			for z in range(-int(zone.radius), int(zone.radius) + 1, 2):
				var p := _point(zone) + Vector2(x,z)
				var gradient := Vector2(height(id,p+Vector2(1,0))-height(id,p-Vector2(1,0)), height(id,p+Vector2(0,1))-height(id,p-Vector2(0,1))) / 2.0
				slope = maxf(slope, rad_to_deg(atan(gradient.length())))
		zone.slope_deg = slope
		zone.area_m2 = pow(2.0 * zone.radius, 2)
		zone.materials = ceil(10.0 + slope * 2.0)
		result.append(zone)
	return result

func route(p: Dictionary, units: float) -> Dictionary:
	var start := _point(_entry(config.deployments,p.deployment_id))
	var finish := _point(_entry(config.zones,p.zone_id))
	var points := [start, finish]
	if p.route_id == "east_detour": points = [start, Vector2(52,start.y), Vector2(52,finish.y),finish]
	var distance := 0.0
	var slope := 0.0
	for i in range(1,points.size()):
		var a: Vector2 = points[i-1]
		var b: Vector2 = points[i]
		var count := maxi(1,ceili(a.distance_to(b)))
		for j in range(count):
			var first := a.lerp(b,float(j)/count)
			var second := a.lerp(b,float(j+1)/count)
			var horizontal := first.distance_to(second)
			var rise := height(p.site_id,second)-height(p.site_id,first)
			distance += Vector2(horizontal,rise).length()
			if horizontal > 0.001: slope = maxf(slope,rad_to_deg(atan(absf(rise)/horizontal)))
	var trips := ceili(units / (float(config.cargo_units_per_trip) * (1 + p.cargo.handling)))
	var total_km := distance * 2.0 * trips / 1000.0
	var energy := total_km * float(simulator.construction.vehicles.rover.move_cost_power_per_km) * (1.0 + slope / 10.0)
	return {"points":points,"distance_m":distance,"max_slope_deg":slope,"trips":trips,"total_km":total_km,"energy_kwh":energy,"feasible":slope <= float(config.max_slope_deg) and total_km <= float(simulator.construction.vehicles.rover.max_distance_per_sol_km)}

func evaluate(p: Variant) -> Dictionary:
	var errors: Array[String] = []
	if not shape_valid(p): return {"valid":false,"errors":["Invalid plan data: restore a default draft; quantities, site, zone and route must be recognized."]}
	var zone := _entry(zones(p.site_id),p.zone_id)
	var units := 0.0
	for item in config.equipment: units += item.units * p.cargo[item.id]
	var transport := route(p,units)
	var cable_m := float(zone.radius) + 3.0 + (10.0 if p.solar_placement == "extended" else 0.0)
	var cable_efficiency := 1.0 - cable_m * float(config.cable_loss_per_m)
	var construction_materials: float = float(zone.materials) + p.cargo.array * float(simulator._find_structure("solar_array").build_cost.materials) + (8.0 if p.solar_placement == "extended" else 0.0)
	var construction_energy: float = p.cargo.array * float(simulator._find_structure("solar_array").build_cost.power)
	var state: Variant = simulator.begin_mission(p.site_id)
	var baseline: Dictionary = simulator._calculate_power(state,site(p.site_id))
	var demand := float(baseline.consumed_kwh) / 24.0
	var reserve := demand * float(config.reserve_hours)
	var capacity: float = Simulator.BATTERY_CAPACITY_KWH + p.cargo.battery * float(config.battery_kwh)
	var battery: float = Simulator.INITIAL_POWER_KWH + p.cargo.battery * float(config.battery_initial_kwh) - transport.energy_kwh - construction_energy
	var minimum: float = battery
	var generated := 0.0
	var shortfall := 0.0
	var timeline := []
	var yields := _yields(p.site_id,p.hours)
	for hour in range(p.hours):
		var generation: float = (Simulator.BASE_SOLAR_GENERATION_KWH_PER_SOL + p.cargo.array * Simulator.SOLAR_ARRAY_GENERATION_KWH_PER_SOL) * float(yields[hour]) * cable_efficiency / 24.0
		generated += generation
		var next: float = battery + generation - demand
		shortfall += maxf(0.0,-next)
		battery = clampf(next,0.0,capacity)
		minimum = minf(minimum,battery)
		if (hour+1)%24 == 0: timeline.append({"hour":hour+1,"battery_kwh":battery})
	var life: Dictionary = simulator._calculate_life_support(state)
	var days: float = p.hours / 24.0
	var supplies := {"water_l":state.water_l + days * life.water_balance_l,"oxygen_kg":state.oxygen_kg-days*life.oxygen_consumed_kg,"food_kg":state.food_kg-days*life.food_consumed_kg}
	if p.hours < state.mission_length_sols * 24: errors.append("Approval requires coverage of the full seven-day mission; increase the evaluation interval to at least 168 hours.")
	if units > float(config.capacity_units): errors.append("Cargo exceeds capacity: remove optional equipment.")
	if zone.slope_deg > float(config.max_slope_deg): errors.append("Construction slope exceeds 18 degrees: choose a gentler zone.")
	var array_space := 4 if p.solar_placement == "extended" else 6
	if 45 + p.cargo.array * array_space > zone.area_m2: errors.append("Insufficient construction space: use distributed solar layout, a larger zone or fewer arrays.")
	if not transport.feasible: errors.append("Route exceeds slope or daily range limits: change deployment or route.")
	if p.cargo.cable * float(config.cable_pack_m) < cable_m: errors.append("Add cable spools to connect the solar placement.")
	if p.cargo.materials * float(config.material_pack) < construction_materials: errors.append("Add material packs for zone preparation and solar construction.")
	if minimum < reserve or shortfall > 0: errors.append("Essential power reserve is insufficient: add batteries or solar arrays, or shorten the evaluation interval.")
	for key in supplies:
		if supplies[key] < 0: errors.append("Insufficient %s for this interval: shorten it while retaining at least seven days." % key)
	return {"valid":errors.is_empty(),"errors":errors,"zone":zone,"transport":transport,"cargo_units":units,"remaining_units":float(config.capacity_units)-units,"cable_m":cable_m,"materials_required":construction_materials,"materials_remaining":p.cargo.materials*float(config.material_pack)-construction_materials,"construction_energy_kwh":construction_energy,"capacity_kwh":capacity,"demand_kw":demand,"generated_kwh":generated,"consumed_kwh":demand*p.hours,"minimum_kwh":minimum,"final_kwh":battery,"reserve_kwh":reserve,"margin_kwh":minimum-reserve,"shortfall_kwh":shortfall,"timeline":timeline,"supplies":supplies,"status":"Invalid" if not errors.is_empty() else ("Limited margin" if minimum < reserve*1.5 else "Viable")}

func _yields(id: String, hours: int) -> Array:
	var key := "%s:%d" % [id,hours]
	if yield_cache.has(key): return yield_cache[key]
	var record := site(id)
	var values := []
	for hour in range(hours):
		var total := 0.0
		for quarter in range(4):
			var obs := Solar.observation_at(record,(hour+(quarter+0.5)/4.0)*3600.0)
			total += Solar.visibility(record,obs)*pow(Solar.Orbit.AU_KM/float(obs.sun_distance_km),2)
		values.append(total/4.0)
	yield_cache[key] = values
	return values

func set_quantity(p: Dictionary, id: String, quantity: int) -> bool:
	var item := _entry(config.equipment,id)
	if item.is_empty() or item.mandatory: return false
	var next := p.duplicate(true)
	next.cargo[id] = quantity
	if not shape_valid(next): return false
	var units := 0.0
	for equipment in config.equipment: units += equipment.units*next.cargo[equipment.id]
	if units > float(config.capacity_units): return false
	p.cargo[id] = quantity
	return true


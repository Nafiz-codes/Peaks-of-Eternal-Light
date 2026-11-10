extends SceneTree
## Radiation wave between Surface Survey and Frozen Horizon: stages, saves and exposure.
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const Rules = preload("res://src/simulation/rover_expedition.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var data := Rules.fresh()
	check(Rules.radiation(data) == "", "No wave before Surface Survey is complete")
	data.completed = [0]
	check(Rules.radiation(data) == "alert", "Maya's warning follows Surface Survey")
	data["radiation"] = "orders"
	data["radiation_told"] = ["water_recycler"]
	data["radiation_elapsed"] = 12.5
	check(Rules.valid_save(data), "An in-progress evacuation saves")
	check(Rules.sheltered(data) == ["water_recycler"], "Ordered crew are inside the habitat")
	data["radiation"] = "done"
	check(Rules.sheltered(data).is_empty(), "Everyone comes out after the wave")
	data["radiation_told"] = ["stranger"]
	check(not Rules.valid_save(data), "Unknown crew in the shelter list are rejected")
	data["radiation_told"] = []
	data.completed = [0, 1]
	check(Rules.radiation(data) == "", "No wave once Frozen Horizon is done")
	var old_save := Rules.fresh()
	old_save.completed = [0]
	check(Rules.valid_save(old_save), "Saves made before this event still load")

	var simulator := Simulator.new()
	check(simulator.load_contracts() == OK, "Contracts load")
	var safe: Variant = simulator.begin_mission("ridge_a")
	var before: Dictionary = safe.snapshot()
	simulator.apply_radiation_wave(safe, 0)
	check(safe.water_l == before.water_l and safe.active_events.is_empty(), "A fully sheltered crew needs no treatment")
	var exposed: Variant = simulator.begin_mission("ridge_a")
	simulator.apply_radiation_wave(exposed, 3)
	check(is_equal_approx(exposed.water_l, before.water_l - 45.0) and is_equal_approx(exposed.oxygen_kg, before.oxygen_kg - 6.0) and is_equal_approx(exposed.food_kg, before.food_kg - 4.5), "Treating three exposed crew uses water, oxygen and food")
	check(exposed.radiation_msv > before.radiation_msv, "Exposure raises the crew dose")
	check(exposed.active_events.size() == 1 and is_equal_approx(exposed.active_events[0].effects.output_multiplier, 0.55), "Exposed crew work slower while they recover")
	var site: Dictionary = simulator._find_site("ridge_a")
	var healthy_power: float = simulator._calculate_power(safe, site).generated_kwh
	var sick_power: float = simulator._calculate_power(exposed, site).generated_kwh
	check(is_equal_approx(sick_power, healthy_power * 0.55), "Three exposed crew cut base power to 55%, not lower")
	check(exposed.mission_outcome.status == "in_progress", "One exposure does not end the mission from a full start")

	print("RADIATION WAVE: %d failures" % failures)
	quit(failures)

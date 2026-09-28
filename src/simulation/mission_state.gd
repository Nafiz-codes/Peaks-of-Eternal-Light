class_name MissionState
extends RefCounted

## Runtime state owned by the simulation layer. UI code must read this object
## rather than calculating resource changes itself.

var sol: int = 0
var mission_length_sols: int = 10
var site_id: String = ""
var crew_size: int = 0
var power_kwh: float = 0.0
var power_generated_kwh: float = 0.0
var power_consumed_kwh: float = 0.0
var power_balance_kwh: float = 0.0
var water_l: float = 0.0
var water_consumed_l: float = 0.0
var water_recovered_l: float = 0.0
var water_balance_l: float = 0.0
var oxygen_kg: float = 0.0
var oxygen_consumed_kg: float = 0.0
var food_kg: float = 0.0
var food_consumed_kg: float = 0.0
var life_support_status: Dictionary = {}
var radiation_msv: float = 0.0
var radiation_this_sol_msv: float = 0.0
var terrain_shielding_factor: float = 0.0
var materials: float = 0.0
var active_events: Array[Dictionary] = []
var history: Array[Dictionary] = []
var consecutive_power_depleted_sols: int = 0
var mission_outcome: Dictionary = {}


func snapshot() -> Dictionary:
	return {
		"sol": sol,
		"mission_length_sols": mission_length_sols,
		"site_id": site_id,
		"crew_size": crew_size,
		"power_kwh": power_kwh,
		"power_generated_kwh": power_generated_kwh,
		"power_consumed_kwh": power_consumed_kwh,
		"power_balance_kwh": power_balance_kwh,
		"water_l": water_l,
		"water_consumed_l": water_consumed_l,
		"water_recovered_l": water_recovered_l,
		"water_balance_l": water_balance_l,
		"oxygen_kg": oxygen_kg,
		"oxygen_consumed_kg": oxygen_consumed_kg,
		"food_kg": food_kg,
		"food_consumed_kg": food_consumed_kg,
		"life_support_status": life_support_status.duplicate(true),
		"radiation_msv": radiation_msv,
		"radiation_this_sol_msv": radiation_this_sol_msv,
		"terrain_shielding_factor": terrain_shielding_factor,
		"materials": materials,
		"active_events": active_events.duplicate(true),
		"consecutive_power_depleted_sols": consecutive_power_depleted_sols,
		"mission_outcome": mission_outcome.duplicate(true)
	}

class_name MissionState
extends RefCounted

## Runtime state owned by the simulation layer. UI code must read this object
## rather than calculating resource changes itself.

var sol: int = 0
var mission_length_sols: int = 7
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
var shielding_wall_material_discount: float = 0.0
var active_events: Array[Dictionary] = []
var pending_events: Array[Dictionary] = []
var resolved_events: Array[Dictionary] = []
var triggered_event_ids: Array[String] = []
var built_structures: Dictionary = {}
var construction_queue: Array[Dictionary] = []
var damaged_structures: Dictionary = {}
## Extra copies of repeatable producers beyond the first: structure id -> count.
var structure_copies: Dictionary = {}
## Share of the current day already charged by continuous play (tick_time).
var day_progress: float = 0.0
## Paid shielding for the next radiation wave; spent when the wave hits.
var structures_shielded: bool = false
## Producers packed away for the dust storm (they make nothing until redeployed).
var producers_stowed: bool = false
## Why the mission failed once the zero-reserve countdown ran out or the final review fell
## short ("oxygen_depleted", "review_shortfall", ...); empty while it can still succeed.
var depletion_failure: String = ""
## Fixed daily output of the hand-placed solar panel, set from its placement.
var placed_panel_kwh_per_sol: float = 0.0
## World-clock seconds at mission start, so power uses the same days as the sky.
var clock_start_seconds: float = 0.0
var last_rover_action: String = ""
var rover_distance_this_sol_km: float = 0.0
var rover_total_distance_km: float = 0.0
var rover_pose: Dictionary = {}
var rover_health: float = 100.0
var fieldwork: Dictionary = {}
var easter_eggs: Dictionary = {}
var rover_training: Dictionary = {}
var rover_expedition: Dictionary = {}
var crew_stress_avg: float = 0.25
var crew_productivity: float = 1.0
var volatile_prospect_found: bool = false
var volatile_prospect_status: String = "none"
var event_warning_disabled: bool = false
var report_data: Dictionary = {}
var history: Array[Dictionary] = []
## Reserves at each mission milestone (landing, each rover operation, the review), for
## the ending's mission-by-mission statistics: [{label, power_kwh, water_l, oxygen_kg, food_kg}].
var milestones: Array[Dictionary] = []
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
		"shielding_wall_material_discount": shielding_wall_material_discount,
		"active_events": active_events.duplicate(true),
		"pending_events": pending_events.duplicate(true),
		"resolved_events": resolved_events.duplicate(true),
		"built_structures": built_structures.duplicate(true),
		"construction_queue": construction_queue.duplicate(true),
		"damaged_structures": damaged_structures.duplicate(true),
		"structure_copies": structure_copies.duplicate(true),
		"day_progress": day_progress,
		"structures_shielded": structures_shielded,
		"producers_stowed": producers_stowed,
		"depletion_failure": depletion_failure,
		"last_rover_action": last_rover_action,
		"rover_distance_this_sol_km": rover_distance_this_sol_km,
		"rover_total_distance_km": rover_total_distance_km,
		"rover_health": rover_health,
		"crew_stress_avg": crew_stress_avg,
		"crew_productivity": crew_productivity,
		"volatile_prospect_found": volatile_prospect_found,
		"volatile_prospect_status": volatile_prospect_status,
		"event_warning_disabled": event_warning_disabled,
		"consecutive_power_depleted_sols": consecutive_power_depleted_sols,
		"mission_outcome": mission_outcome.duplicate(true),
		"report_data": report_data.duplicate(true)
	}

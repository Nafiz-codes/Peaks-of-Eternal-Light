class_name MissionState
extends RefCounted

## Runtime state owned by the simulation layer. UI code must read this object
## rather than calculating resource changes itself.

var sol: int = 0
var mission_length_sols: int = 10
var site_id: String = ""
var crew_size: int = 0
var power_kwh: float = 0.0
var water_l: float = 0.0
var oxygen_kg: float = 0.0
var food_kg: float = 0.0
var radiation_msv: float = 0.0
var materials: float = 0.0
var active_events: Array[Dictionary] = []
var history: Array[Dictionary] = []


func snapshot() -> Dictionary:
	return {
		"sol": sol,
		"mission_length_sols": mission_length_sols,
		"site_id": site_id,
		"crew_size": crew_size,
		"power_kwh": power_kwh,
		"water_l": water_l,
		"oxygen_kg": oxygen_kg,
		"food_kg": food_kg,
		"radiation_msv": radiation_msv,
		"materials": materials,
		"active_events": active_events.duplicate(true)
	}

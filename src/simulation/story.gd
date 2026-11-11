extends RefCounted
## Progressive construction: which buildings the crew has asked for so far, and which
## crew member has something new to say. Dialogue flags live in
## MissionSession.crew_introductions; story progress lives in the rover expedition data.
## A save already past a stage counts that stage as done, so old saves never stall.
const Rules = preload("res://src/simulation/rover_expedition.gd")

## Dialogue flags in story order, each said once (all optional booleans in saves).
const FLAGS := ["water_recycler", "food_storage", "maya_closing", "rover_briefing", "maya_radiation_prep", "sam_engineering", "alex_science", "crew_habitation"]

## The buildings each story beat unlocks.
const UNLOCKS := {
	"maya_closing": ["solar_array", "maya_station"],
	"maya_radiation_prep": ["comms_relay", "shielding_wall"],
	"sam_engineering": ["sam_station"],
	"alex_science": ["alex_station", "water_extractor", "greenhouse"],
	"crew_habitation": ["habitat_module"],
}

## Display names for the "BUILDING UNLOCKED" notices.
const NAMES := {"solar_array": "Solar Panel", "maya_station": "Maya · Operations", "comms_relay": "Comms Relay", "shielding_wall": "Radiation Shielding Habitat", "sam_station": "Sam · Engineering", "alex_station": "Alex · Science", "water_extractor": "Water Extractor", "habitat_module": "Habitat Extension", "greenhouse": "Greenhouse Module"}


## True once the story beat has been heard, or the campaign has already moved past it.
static func reached(flag: String, intros: Dictionary, d: Dictionary) -> bool:
	if intros.get(flag, false): return true
	var completed: Array = d.get("completed", [])
	match flag:
		"maya_closing": return not completed.is_empty() or int(d.get("mission", -1)) >= 0
		"maya_radiation_prep": return completed.has(1) or str(d.get("radiation", "prep")) != "prep"
		"sam_engineering": return completed.has(1) or int(d.get("mission", -1)) >= 1
		"alex_science": return completed.has(2) or bool(d.get("dust_storm_complete", false))
		"crew_habitation": return str(d.get("debrief", "pending")) != "pending"
	return false


static func unlocked(id: String, intros: Dictionary, d: Dictionary) -> bool:
	for flag in UNLOCKS:
		if id in UNLOCKS[flag]: return reached(flag, intros, d)
	return true # Anything not in the story (none today) is always available.


## The story beat a crew member brings to the Commander now ("" when none).
static func pending_beat(speaker: String, intros: Dictionary, d: Dictionary) -> String:
	var completed: Array = d.get("completed", [])
	match speaker:
		"crew_briefing":
			if completed.has(0) and Rules.radiation(d) == "prep" and not reached("maya_radiation_prep", intros, d): return "maya_radiation_prep"
		"food_storage":
			if completed.has(0) and Rules.radiation(d) == "done" and not reached("sam_engineering", intros, d): return "sam_engineering"
			if completed.has(2) and not reached("crew_habitation", intros, d): return "crew_habitation"
		"water_recycler":
			if completed.has(1) and not reached("alex_science", intros, d): return "alex_science"
	return ""

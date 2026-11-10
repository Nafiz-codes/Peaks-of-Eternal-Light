extends RefCounted
## Campaign scheduling shares MissionState.sol. Overdue operations remain queued.
const SOLS := [2, 4, 6]
const TITLES := ["Operation Surface Survey", "Operation Frozen Horizon", "Operation Lifeline"]
const CREW := ["player", "water_recycler", "food_storage", "crew_briefing"]
static func fresh() -> Dictionary:
	return {"completed": [], "mission": -1, "location": "outpost", "phase": "available",
		"surveys": [], "samples": [], "discovered": false, "stabilized": false,
		"relay": false, "crew_position": Vector3.ZERO, "route": PackedVector3Array(), "missing": false}
static func assigned(d: Dictionary, _sol: int = 0) -> int:
	if d.mission >= 0: return d.mission
	for i in range(3):
		if not d.completed.has(i): return i
	# After the ending the Commander may keep playing: Surface Survey can be flown again.
	return 0 if d.get("free_play", false) else -1
## What follows the dust storm, before Lifeline opens: "briefing" (Maya reports the
## damage), "repairs" (the Commander fixes or leaves it), "alert" (Maya reports the lost
## astronaut), then "done". Empty when the storm is not the latest thing that happened.
static func aftermath(d: Dictionary) -> String:
	var completed: Array = d.get("completed", [])
	if not completed.has(1) or completed.has(2) or int(d.get("mission", -1)) == 2 or not bool(d.get("dust_storm_complete", false)):
		return ""
	return str(d.get("aftermath", "briefing"))
## The crew the Commander must order into the radiation habitat.
const RADIATION_CREW := ["crew_briefing", "water_recycler", "food_storage"]
## The solar radiation wave between Surface Survey and Frozen Horizon: "alert" (Maya
## warns the Commander), "orders" (order each crew member into the radiation habitat
## before the countdown ends), "wave" (it hits the base) and "done".
static func radiation(d: Dictionary) -> String:
	var completed: Array = d.get("completed", [])
	if not completed.has(0) or completed.has(1) or int(d.get("mission", -1)) == 1:
		return ""
	return str(d.get("radiation", "alert"))
## Crew inside the radiation habitat (hidden from the outpost) until the wave passes.
static func sheltered(d: Dictionary) -> Array:
	return d.get("radiation_told", []) if radiation(d) in ["orders", "wave"] else []
## After Lifeline Maya reviews the mission: "pending" (she comes to the Commander),
## "retry" (reserves fell short; ask her again) or "done" (confirmed, game finished).
static func debrief(d: Dictionary) -> String:
	if not d.get("completed", []).has(2): return ""
	return str(d.get("debrief", "pending"))
static func migrate(training: Dictionary) -> Dictionary:
	var d := fresh()
	if training.is_empty(): return d
	for i in range(training.mission): d.completed.append(i)
	if training.status == "success": d.completed.append(training.mission)
	elif training.mission == 0:
		for id in training.scans:
			if id in ["alpha","beta","gamma"]: d.surveys.append(id)
	elif training.mission == 1 and training.stage == "ice_upload": d.samples.append("ice_b")
	elif training.mission == 2:
		d.discovered = training.scans.has("astronaut")
		d.stabilized = training.stabilized
		d.relay = training.relay
	return d
static func ready_to_return(d: Dictionary) -> bool:
	match d.mission:
		0: return d.surveys.size() == 3
		1: return d.samples.size() == 3
		2: return d.discovered and d.stabilized and d.relay
	return false
static func valid_save(d: Variant) -> bool:
	if not d is Dictionary: return false
	if d.is_empty(): return true
	if d.has("damage_warning_acknowledged") and not d.damage_warning_acknowledged is bool: return false
	if d.has("dust_storm_complete") and not d.dust_storm_complete is bool: return false
	if d.has("aftermath") and d.aftermath not in ["briefing", "repairs", "alert", "done"]: return false
	if d.has("debrief") and d.debrief not in ["pending", "retry", "done"]: return false
	if d.has("free_play") and not d.free_play is bool: return false
	if d.has("radiation") and d.radiation not in ["alert", "orders", "wave", "done"]: return false
	if d.has("radiation_told"):
		if not d.radiation_told is Array: return false
		for id in d.radiation_told:
			if id not in RADIATION_CREW: return false
	if d.has("radiation_elapsed"):
		if not d.radiation_elapsed is float or not is_finite(d.radiation_elapsed) or d.radiation_elapsed < 0.0 or d.radiation_elapsed > 600.0: return false
	if d.has("dust_storm_elapsed"):
		if not d.dust_storm_elapsed is float or not is_finite(d.dust_storm_elapsed) or d.dust_storm_elapsed < 0.0 or d.dust_storm_elapsed > 15.0: return false
	var defaults := fresh()
	for key in defaults:
		if not d.has(key) or typeof(d[key]) != typeof(defaults[key]): return false
	if d.mission < -1 or d.mission > 2 or d.location not in ["outpost", "expedition"]: return false
	if d.phase not in ["available", "active", "returning", "completed", "failed"]: return false
	if d.phase == "failed" and d.location != "expedition": return false
	for pair in [[d.completed, [0, 1, 2]], [d.surveys, ["alpha", "beta", "gamma"]], [d.samples, ["ice_a", "ice_b", "ice_c"]]]:
		var seen := []
		for id in pair[0]:
			if id not in pair[1] or id in seen: return false
			seen.append(id)
	if not d.crew_position.is_finite() or d.route.size() > 2048: return false
	for point in d.route:
		if not point.is_finite(): return false
	if d.relay and not d.stabilized: return false
	if d.stabilized and not d.discovered: return false
	if d.location == "expedition" and d.mission < 0: return false
	if d.phase == "returning" and not ready_to_return(d): return false
	return true

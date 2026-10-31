extends RefCounted
## Campaign scheduling shares MissionState.sol. Overdue operations remain queued.
const SOLS := [2, 4, 6]
const TITLES := ["Operation Surface Survey", "Operation Frozen Horizon", "Operation Lifeline"]
const CREW := ["player", "water_recycler", "food_storage", "crew_briefing"]
static func fresh() -> Dictionary:
	return {"completed": [], "mission": -1, "location": "outpost", "phase": "available",
		"surveys": [], "samples": [], "discovered": false, "stabilized": false,
		"relay": false, "crew_position": Vector3.ZERO, "route": PackedVector3Array(), "missing": false}
static func assigned(d: Dictionary, sol: int) -> int:
	if d.mission >= 0: return d.mission if sol >= SOLS[d.mission] else -1
	for i in range(3):
		if sol >= SOLS[i] and not d.completed.has(i): return i
	return -1
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
	var defaults := fresh()
	for key in defaults:
		if not d.has(key) or typeof(d[key]) != typeof(defaults[key]): return false
	if d.mission < -1 or d.mission > 2 or d.location not in ["outpost", "expedition"]: return false
	if d.phase not in ["available", "active", "returning", "completed"]: return false
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

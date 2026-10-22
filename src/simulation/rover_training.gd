extends RefCounted
## Mission rules shared by the world controller, save validation and tests.
signal changed
const TITLES := ["Operation Surface Survey", "Operation Frozen Horizon", "Operation Lifeline"]
const SURVEY := ["alpha", "beta", "gamma"]
const READINGS := {"ice_a": 32.0, "ice_b": 78.0, "ice_c": 49.0}
var data: Dictionary = {}

func begin(index: int = 0, reserve: float = 480.0) -> void:
	data = {"mission": index, "status": "active", "stage": ["survey", "perimeter", "search"][index],
		"scans": {}, "battery": 100.0, "lights": false, "remaining": reserve,
		"clock_started": false, "stabilized": false, "kit": true, "relay": false,
		"best": "", "message": "", "elapsed": 0.0, "cold_exposure": 0.0}
	changed.emit()

func eligible(id: String) -> bool:
	if data.is_empty() or data.status != "active" or data.scans.has(id): return false
	return (data.stage == "survey" and id in SURVEY) or (data.stage == "ice_scan" and READINGS.has(id)) or (data.stage == "search" and id == "astronaut")

func record_scan(id: String) -> bool:
	if not eligible(id): return false
	data.scans[id] = READINGS.get(id, 1.0)
	if data.stage == "survey" and data.scans.size() == 3: data.stage = "survey_upload"
	elif data.stage == "ice_scan" and data.scans.size() == 3:
		data.best = "ice_b"
		data.stage = "sample"
	elif data.stage == "search": data.stage = "contact"
	changed.emit()
	return true

func action_target() -> String:
	if data.is_empty() or data.status != "active": return ""
	match data.stage:
		"perimeter": return "perimeter"
		"survey_upload", "ice_upload": return "uplink"
		"sample": return data.best
		"contact", "kit", "relay", "pickup": return "astronaut"
	return ""

func action_name() -> String:
	if data.is_empty(): return ""
	return {"perimeter": "Confirm crater training perimeter (headlights required)",
		"survey_upload": "Transmit survey data", "sample": "Drill sample and analyze",
		"ice_upload": "Transmit sample analysis", "contact": "Establish short-range contact",
		"kit": "Deploy emergency oxygen / power kit", "relay": "Deploy communications relay",
		"pickup": "Confirm separate rescue team pickup"}.get(data.stage, "")

func complete_action(id: String) -> bool:
	if id == "" or id != action_target(): return false
	match data.stage:
		"perimeter":
			if not data.lights: return false
			data.stage = "ice_scan"
		"survey_upload", "ice_upload": data.status = "success"
		"sample":
			data.stage = "ice_upload"
			data.message = "Sample analyzer: evidence of ice in this simulated sample. Hydrogen readings alone were not confirmation."
		"contact": data.stage = "kit"
		"kit":
			if not data.kit: return false
			data.kit = false
			data.stabilized = true
			data.stage = "relay"
		"relay":
			if not data.stabilized: return false
			data.relay = true
			data.stage = "pickup"
		"pickup":
			if not data.stabilized or not data.relay: return false
			data.status = "success"
			data.message = "Mission Control: independent rescue team confirms pickup. Rover remains at the worksite."
	changed.emit()
	return true

func fail(reason: String) -> void:
	if data.is_empty() or data.status != "active": return
	data.status = "failed"
	data.message = reason
	changed.emit()

func tick(delta: float, remote_ready: bool, moving: bool, tool_busy: bool, health: float, drain: float) -> void:
	if data.is_empty() or data.status != "active": return
	if remote_ready: data.clock_started = true
	if data.mission == 2 and data.clock_started and not data.stabilized:
		data.remaining = maxf(0.0, data.remaining - delta)
		if data.remaining <= 0.0: fail("Life-support reserve expired before stabilization.")
	if health <= 0.0: fail("Rover disabled. Retry the training mission or return to repair.")
	if remote_ready:
		data.elapsed += delta
		data.battery = maxf(0.0, data.battery - delta * drain * (1.0 + float(moving) * 2.0 + float(data.lights) + float(tool_busy) * 3.0))
		if data.battery <= 0.0: fail("Rover battery depleted.")

static func valid_save(value: Variant) -> bool:
	if not value is Dictionary: return false
	if value.is_empty(): return true
	var model := new()
	model.begin()
	for key in model.data:
		if not value.has(key) or typeof(value[key]) != typeof(model.data[key]): return false
	if value.mission < 0 or value.mission > 2 or value.status not in ["active", "success", "failed"]: return false
	if value.stage not in [["survey", "survey_upload"], ["perimeter", "ice_scan", "sample", "ice_upload"], ["search", "contact", "kit", "relay", "pickup"]][value.mission]: return false
	for key in ["battery", "remaining", "elapsed", "cold_exposure"]:
		if not is_finite(value[key]) or value[key] < 0.0: return false
	if value.battery > 100.0: return false
	for id in value.scans:
		if id not in [SURVEY, READINGS.keys(), ["astronaut"]][value.mission]: return false
		if not value.scans[id] is float or value.scans[id] != READINGS.get(id, 1.0): return false
	if value.stage == "survey_upload" and value.scans.size() != 3: return false
	if value.stage in ["sample", "ice_upload"] and (value.scans.size() != 3 or value.best != "ice_b"): return false
	if value.mission == 2:
		if value.stage != "search" and not value.scans.has("astronaut"): return false
		if value.stabilized != (value.stage in ["relay", "pickup"]): return false
		if value.kit == value.stabilized or value.relay != (value.stage == "pickup"): return false
	if value.status == "success" and value.stage not in ["survey_upload", "ice_upload", "pickup"]: return false
	return true

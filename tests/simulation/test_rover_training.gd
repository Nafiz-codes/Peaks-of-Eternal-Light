extends SceneTree
const Rules = preload("res://src/simulation/rover_training.gd")
const Scanner = preload("res://src/world/rover_scanner.gd")
var failures := 0
var assertions := 0
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var model := Rules.new()
	model.begin()
	check(not model.complete_action("uplink"), "Survey upload blocked before scans")
	check(not model.record_scan("ice_a"), "Wrong mission target rejected without marking")
	for id in Rules.SURVEY:
		check(model.record_scan(id), "Unique survey scan accepted")
		check(not model.record_scan(id), "Duplicate scan rejected")
	check(model.complete_action("uplink") and model.data.status == "success", "Survey transmitted")
	check(not model.complete_action("uplink"), "Late completion ignored")
	check(Rules.valid_save(model.data), "Survey result save validates")
	model.begin(1)
	check(not model.record_scan("ice_b"), "Science scans require perimeter")
	check(not model.complete_action("perimeter"), "Headlights required")
	model.data.lights = true
	check(model.complete_action("perimeter"), "Perimeter confirmed")
	for id in ["ice_b", "ice_a"]: check(model.record_scan(id), "Candidate accepted")
	check(model.data.best == "", "Strongest not exposed before all readings")
	check(model.record_scan("ice_c") and model.data.best == "ice_b", "Strongest selected after comparison")
	check(not model.complete_action("ice_a"), "Wrong drilling candidate rejected")
	check(not model.complete_action("uplink"), "Cannot upload before sampling")
	check(model.complete_action("ice_b") and model.data.stage == "ice_upload", "Sample analysis unlocks upload")
	check(model.complete_action("uplink"), "Science result transmitted")
	check(Rules.valid_save(model.data), "Science save validates")
	model.begin(2, 480.0)
	model.tick(12, false, false, false, 100, 0.012)
	check(model.data.remaining == 480, "No countdown before ready")
	model.tick(1, true, false, false, 100, 0.012)
	model.tick(1, false, false, false, 100, 0.012)
	check(model.data.remaining == 478, "Countdown starts when ready and survives control release")
	check(not model.complete_action("astronaut"), "Identification required")
	check(model.record_scan("astronaut"), "Astronaut pinpointed")
	check(model.complete_action("astronaut") and not model.data.stabilized, "Contact does not count as support")
	check(model.complete_action("astronaut") and model.data.stabilized and not model.data.kit, "Kit stabilizes without boarding")
	var remaining: float = model.data.remaining
	model.tick(100, true, false, false, 100, 0.012)
	check(model.data.remaining == remaining, "Stabilization stops reserve clock")
	check(model.complete_action("astronaut") and model.data.relay, "Relay restored before pickup")
	check(model.data.status == "active", "Relay alone is not mission success")
	check(model.complete_action("astronaut") and model.data.status == "success", "Separate pickup confirms success")
	check(Rules.valid_save(model.data), "Rescue save validates")
	model.begin(2, 1.0)
	model.tick(2, true, false, false, 100, 0.012)
	check(model.data.status == "failed" and not model.record_scan("astronaut"), "Expiry prevents late success")
	model.begin()
	model.data.battery = 0.001
	model.tick(1, true, true, true, 100, 0.012)
	check(model.data.status == "failed", "Battery failure")
	model.begin()
	check(model.data.scans.is_empty() and model.data.kit and model.data.battery == 100, "Retry resets mission state")
	var scanner := Scanner.new()
	for reason in ["too fast", "out of range", "occluded"]:
		check(not scanner.advance(4, true, "alpha", true, reason) and scanner.progress == 0, "Invalid scans interrupt: " + reason)
	check(not scanner.advance(4, true, "unrelated", false, ""), "Unrelated target rejected")
	check(not scanner.advance(2, true, "alpha", true, ""), "Hold must reach duration")
	check(not scanner.advance(2, true, "beta", true, ""), "Target change resets progress")
	check(scanner.advance(1.1, true, "beta", true, ""), "Continuous scan completes")
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	session.dashboard_state.rover_training = model.data
	var save := preload("res://src/runtime/mission_save.gd")
	var captured: Dictionary = save.capture(session)
	check(not save.decode(captured).is_empty(), "Training included in existing save contract")
	captured.state.rover_training.battery = -1.0
	check(save.decode(captured).is_empty(), "Corrupt telemetry rejected")
	captured.state.erase("rover_training")
	check(not save.decode(captured).is_empty(), "Older saves remain compatible")
	print("ROVER TRAINING RULES: %d failures / %d assertions" % [failures, assertions])
	quit(failures)

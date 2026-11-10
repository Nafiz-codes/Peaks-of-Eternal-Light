extends SceneTree
## Regression checks for the 10 Nov 2026 audit: bounded history, save size guard,
## one calendar for sky and power, and a world clock that survives save/load.
const Simulator = preload("res://src/simulation/mission_simulator.gd")
const PolarSolar = preload("res://src/simulation/polar_solar.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var simulator := Simulator.new()
	check(simulator.load_contracts() == OK, "Contracts load")

	# 1: an open-ended mission keeps a bounded history.
	var long_state: Variant = simulator.begin_mission("ridge_a")
	for day in range(200):
		long_state.pending_events.clear()
		simulator.advance_sol(long_state)
	check(long_state.history.size() == Simulator.HISTORY_DAYS + 1, "History keeps the first snapshot plus the latest 60 days")
	check(long_state.history[0].sol == 0 and long_state.history[-1].sol == 200, "History keeps day 0 and the newest day")

	# 1: a save too large to read back is refused instead of written.
	var path := "user://audit-oversize.save"
	var oversize := PackedByteArray()
	oversize.resize(Save.MAX_BYTES + 1024)
	check(Save.write_file(path, {"blob": oversize}) != OK, "Oversize saves are refused")
	check(not FileAccess.file_exists(path) and not FileAccess.file_exists(path + ".tmp"), "A refused save leaves no file behind")

	# 3: power uses the day the sky shows, counted from the mission's start.
	var site: Dictionary = simulator._find_site("ridge_a")
	var state: Variant = simulator.begin_mission("ridge_a")
	state.clock_start_seconds = 10.0 * 86400.0
	var tick: Dictionary = simulator.advance_sol(state)
	check(is_equal_approx(tick.power.illumination_fraction, PolarSolar.daily_fraction(site, 10.0)), "Day 1 power uses the mission's first sky day")
	state.pending_events.clear()
	tick = simulator.advance_sol(state)
	check(is_equal_approx(tick.power.illumination_fraction, PolarSolar.daily_fraction(site, 11.0)), "Each later day follows the sky")

	# 3: the mission starts on the sky's clock, and loading keeps that clock.
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	check(session.start_selected_mission() == OK, "Mission starts")
	var start: float = session.orbital_clock.elapsed_seconds
	check(is_equal_approx(start, PolarSolar.bright_start(site)) and is_equal_approx(session.dashboard_state.clock_start_seconds, start), "Mission start records the sky clock")
	session.orbital_clock.elapsed_seconds = start + 5000.0
	var data := Save.capture(session)
	session.orbital_clock.elapsed_seconds = 0.0
	check(Save.restore(session, data) == OK, "Save restores")
	check(is_equal_approx(session.orbital_clock.elapsed_seconds, start + 5000.0), "Loading keeps the saved world clock")
	check(is_equal_approx(session.dashboard_state.clock_start_seconds, start), "Loading keeps the mission's start day")

	print("AUDIT FIXES: %d failures" % failures)
	quit(failures)

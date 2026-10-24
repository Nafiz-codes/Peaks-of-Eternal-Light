extends SceneTree
const Model = preload("res://src/world/orbital_model.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0
var checks := 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	for mean in [-10.0, 0.0, 1.0, 3.0, 100.0]:
		var eccentric := Model.eccentric_anomaly(mean, 0.0554)
		check(absf(eccentric - 0.0554 * sin(eccentric) - wrapf(mean, -PI, PI)) < 1e-10, "Kepler residual")
	var start := Model.days_from_j2000(0)
	var initial := Model.bodies(start)
	var annual := Model.bodies(start + Model.EARTH_YEAR_DAYS)
	check(initial.earth_km.distance_to(annual.earth_km) < 15000.0, "Earth completes annual orbit")
	var half_year := Model.bodies(start + Model.EARTH_YEAR_DAYS / 2)
	check(initial.earth_km.normalized().dot(half_year.earth_km.normalized()) < -0.99, "Earth travels opposite side of Sun")
	var quarter := Model.bodies(start + Model.MOON_SIDEREAL_DAYS / 4)
	check(absf(wrapf(quarter.moon_spin_rad - initial.moon_spin_rad, -PI, PI) - PI / 2) < 1e-6, "Moon rotates at measured sidereal rate")
	var earth_quarter := Model.bodies(start + Model.EARTH_SPIN_SECONDS / Model.DAY / 4)
	check(absf(wrapf(earth_quarter.earth_spin_rad - initial.earth_spin_rad, -PI, PI) - PI / 2) < 1e-6, "Earth rotates at measured sidereal rate")
	for day in range(370):
		var state := Model.bodies(start + day)
		check(state.moon_relative_km.length() > 362000.0 and state.moon_relative_km.length() < 406000.0, "Elliptical lunar distance")
		check((state.moon_km - state.earth_km).distance_to(state.moon_relative_km) < 32.0, "Moon inherits Earth's solar orbit (float32 tolerance)")
		var earth_in_body: Vector3 = state.moon_basis.transposed() * -state.moon_relative_km.normalized()
		check(earth_in_body.x > 0.98, "Tidal locking keeps near face toward Earth with libration")
		check(absf(state.moon_basis.determinant() - 1.0) < 1e-5, "Moon orientation is orthonormal")
	var session := root.get_node("MissionSession")
	session.reset_current_mission()
	check(session.orbital_clock.time_scale == 3600.0, "Accelerated default")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	var motion := world.get_node("OrbitalMotion")
	motion.set_process(false)
	motion.advance(2.0)
	check(session.orbital_clock.elapsed_seconds == 7200.0, "Two seconds advances two hours")
	motion.set_paused(true)
	motion.advance(10.0)
	check(session.orbital_clock.elapsed_seconds == 7200.0, "Orbital pause")
	motion.set_paused(false)
	motion.set_speed(1.0)
	motion.advance(1.0)
	check(session.orbital_clock.elapsed_seconds == 7201.0, "Real time option")
	motion.set_speed(99.0)
	check(session.orbital_clock.time_scale == 1.0, "Reject unsupported speed")
	paused = true
	motion.advance(20.0)
	paused = false
	check(session.orbital_clock.elapsed_seconds == 7201.0, "Game pause also stops orbit")
	var saved := Save.capture(session)
	var decoded := Save.decode(saved)
	check(not decoded.is_empty() and decoded.orbital_clock == session.orbital_clock, "Save clock round trip")
	saved.erase("orbital_clock")
	decoded = Save.decode(saved)
	check(not decoded.is_empty() and decoded.orbital_clock == Model.default_clock(), "Legacy saves get defaults")
	saved.orbital_clock = {"elapsed_seconds": NAN, "time_scale": 3600.0, "paused": false}
	check(Save.decode(saved).is_empty(), "Reject nonfinite saved clock")
	var hud := world.get_node("MissionHUD")
	hud.orbital_panel.open_orbits(motion)
	check(hud._modal_visible() and world.get_node("Outpost/Astronaut").ui_blocked, "Orbital controls block player input")
	if "--capture" in OS.get_cmdline_user_args():
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/orbital-controls.png")
	hud.orbital_panel.hide()
	check(not world.get_node("Outpost/Astronaut").ui_blocked, "Closing restores controls")
	session.orbital_clock.elapsed_seconds = Model.MAX_ELAPSED - 1.0
	motion.advance(2.0)
	check(session.orbital_clock.paused and session.orbital_clock.elapsed_seconds == Model.MAX_ELAPSED, "Fit horizon stops clock")
	session.orbital_clock = Model.default_clock()
	session.start_selected_mission()
	check(session.dashboard_state.mission_length_sols == 7, "Campaign lasts seven Sols")
	motion.advance(100)
	check(session.orbital_clock.elapsed_seconds == 0, "Waiting does not advance manual campaign calendar")
	session.dashboard_state.sol = 3
	motion.advance(12)
	check(session.orbital_clock.elapsed_seconds == 3 * Model.DAY, "Sky follows mission Sol three")
	motion.advance(100)
	check(session.orbital_clock.elapsed_seconds == 3 * Model.DAY, "Sky stops at matching calendar time")
	session.dashboard_state.sol = 7
	motion.advance(16)
	check(session.orbital_clock.elapsed_seconds == 7 * Model.DAY, "Seven Sols equals seven modeled days")
	world.free()
	print("Orbital motion: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

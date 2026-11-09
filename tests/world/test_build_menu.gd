extends SceneTree
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func enabled_ids(placement: Node) -> Array:
	var ids := []
	for card in placement.grid.get_children():
		if not card.disabled: ids.append(card.get_child(0).get_child(1).text)
	return ids

func run() -> void:
	var session := root.get_node("MissionSession")
	session.select_landing_site("ridge_a")
	session.solar_placement = {}
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await physics_frame
	var placement: Node
	for child in world.get_children():
		if child.get_script() != null and child.get_script().resource_path.ends_with("solar_placement.gd"):
			placement = child
	var terminal := world.get_node("Outpost/power_console")
	check(not terminal.is_visible_in_tree() and not terminal.get_node("InteractionArea").monitoring, "Temporary energy console and its E prompt are removed.")
	var placeholders := world.get_node("CrewFieldwork/FieldworkPlaceholders")
	check(not placeholders.is_visible_in_tree(), "Temporary supply blocks, sample props and survey stakes are hidden.")
	placement._open_menu()
	check(placement.area_ring != null and placement.area_ring.visible and placement.area_ring.mesh.get_surface_count() == 1, "B shows the ground hologram immediately, before selecting a building.")
	check(placement.area_ring.material_override is ShaderMaterial, "Ground marking uses the faint blue grid shader.")
	placement._close_menu_and()
	check(not placement.area_ring.visible, "Closing B hides the ground hologram.")
	var lander: Vector3 = world.get_node("Outpost/Habitat").global_position
	var circle: Vector3 = world.get_node("RoverTraining").departure.global_position
	check(placement.overlaps_rover_circle(circle), "Hidden departure area rejects construction.")
	check(placement.overlaps_rover_circle(circle + Vector3(5, 0, 0)), "A footprint overlapping the circle is rejected even with its center outside.")
	check(not placement.overlaps_rover_circle(circle + Vector3(8, 0, 0)), "Clear ground outside the reserved disk remains available.")
	check(is_equal_approx(placement.build_radius(), Vector2(circle.x - lander.x, circle.z - lander.z).length() * 3.0), "Build radius is three times the lander-to-departure distance.")
	check(placement.in_build_area(lander + Vector3(3, 0, 0)) and not placement.in_build_area(lander + Vector3(placement.build_radius() + 1.0, 0, 0)), "Placement is limited to the build area.")
	check(is_equal_approx(placement.PANEL_RATED_KWH_PER_SOL, 1361.0 * 4.62 * 0.30 * 24.0 / 1000.0), "Panel rating comes from NASA irradiance and cell efficiency.")
	check(is_equal_approx(placement.panel_output_kwh(0.5, 1.0), 22.6) and is_equal_approx(placement.panel_output_kwh(0.5, 0.0), 0.0), "Panel output is rating × site sunlight × direct sun.")
	var near_spot := Transform3D(Basis.IDENTITY, lander + Vector3(6, 0, 6))
	var exposure: float = placement.mission_exposure(near_spot)
	check(exposure >= 0.0 and exposure <= 1.0, "Mission shade is a share of the panel's sunlight.")
	var far_spot := Transform3D(Basis.IDENTITY, lander + Vector3(placement.build_radius() * 0.9, 0, 0))
	var far_exposure: float = placement.mission_exposure(far_spot)
	check(far_exposure >= 0.0 and far_exposure <= 1.0, "Far edges of the build area use the same shade scoring.")
	# Crew stations need a walkable route; rolling ground past the old 30 m pad must not block it.
	var crew = world.get_node("CrewFieldwork")
	var far_dock: Vector3 = crew.actors.crew_briefing.global_position + Vector3(45, 0, 0)
	var started := Time.get_ticks_msec()
	check(not crew.station_route("crew_briefing", far_dock).is_empty(), "Crew can route to a station 45 m out.")
	check(Time.get_ticks_msec() - started < 1000, "Long crew routes stay fast enough to check while aiming.")
	check(placement.in_build_area(far_spot.origin), "The wider build area reaches far spots.")
	var mean_yield: float = placement.mean_site_yield()
	check(mean_yield > 0.0 and mean_yield <= 1.1, "Site sunlight comes from the polar solar model.")
	check(placement.face_normal.distance_to(Vector3(0.0, 0.7071, 0.7071)) < 0.15, "The model's cells face 45° up toward +Z.")
	check(is_zero_approx(placement.facing_yield(Vector3.DOWN)), "Cells facing the ground catch no sunlight.")
	var best_fixed := 0.0
	var worst_fixed := INF
	for step in range(24):
		var turned: Vector3 = Basis(Vector3.UP, TAU * step / 24.0) * placement.face_normal
		var turned_yield: float = placement.facing_yield(turned)
		best_fixed = maxf(best_fixed, turned_yield)
		worst_fixed = minf(worst_fixed, turned_yield)
	check(best_fixed <= mean_yield + 0.0001, "A fixed panel never beats a Sun-tracking one.")
	check(best_fixed > worst_fixed, "Turning the panel changes how much sunlight it catches.")
	placement.panel.global_transform = Transform3D(Basis.IDENTITY, lander + Vector3(6, 0, 6))
	placement._update_output_card()
	check(placement.output_card.visible and ("%.1f" % placement.preview_kwh) in placement.output_lines.energy.text, "The hover card shows the exact kWh that will be applied.")
	placement._refresh_menu()
	await process_frame
	check(placement.grid.get_child_count() == 9, "Every catalog structure has a grid card.")
	check(enabled_ids(placement) == ["Solar Array", "Maya · Operations", "Alex · Science", "Sam · Engineering"], "Paid buildings require a started mission.")
	check(placement.grid.get_child(0).get_child(0).get_child(0).get_child_count() == 1, "The solar panel card shows its model preview.")
	check(placement.grid.get_child(4).get_child(0).get_child(0).get_child_count() == 0, "Structures without a model keep a blank picture.")
	check(session.start_selected_mission() == OK, "Mission starts.")
	placement._refresh_menu()
	check(enabled_ids(placement) == ["Solar Array", "Maya · Operations", "Alex · Science", "Sam · Engineering", "Habitat Extension", "Comms Relay"], "NASA previews are accessible before solar placement in a started mission.")
	placement.placed = true
	placement._refresh_menu()
	await process_frame
	check(enabled_ids(placement).size() == 8 and not "Solar Array" in enabled_ids(placement), "Placing the panel unlocks the other structures.")
	var Save = preload("res://src/runtime/mission_save.gd")
	session.dashboard_state.placed_panel_kwh_per_sol = 12.3
	session.solar_placement = {"transform": Transform3D.IDENTITY, "kwh_per_sol": 12.3}
	var saved: Dictionary = Save.capture(session)
	var loaded: Dictionary = Save.decode(saved)
	check(not loaded.is_empty() and is_equal_approx(loaded.state.placed_panel_kwh_per_sol, 12.3) and is_equal_approx(loaded.solar_placement.kwh_per_sol, 12.3), "Panel output survives save and load.")
	var edited: Dictionary = saved.duplicate(true)
	edited.state.placed_panel_kwh_per_sol = 1.0e9
	check(Save.decode(edited).is_empty(), "Saves with impossible panel output are rejected.")
	edited = saved.duplicate(true)
	edited.solar_placement.kwh_per_sol = -1.0
	check(Save.decode(edited).is_empty(), "Saves with negative panel output are rejected.")
	session.dashboard_state.placed_panel_kwh_per_sol = 0.0
	session.solar_placement = {}
	session.dashboard_state.materials = 60.0
	placement._refresh_menu()
	await process_frame
	check(enabled_ids(placement) == ["Maya · Operations", "Alex · Science", "Sam · Engineering", "Radiation Shielding Wall", "Habitat Extension", "Comms Relay"], "NASA previews stay accessible even with insufficient materials.")
	check(placement.grid.get_child(5).modulate.a < 1.0, "Unaffordable cards are visibly grayed.")
	session.dashboard_state.built_structures["comms_relay"] = 0
	world.refresh_feedback()
	var relay: Node3D = world.find_child("Completed_comms_relay", true, false)
	placement._start_destroy()
	check(placement._structure_at(relay.find_children("*", "StaticBody3D", true, false)[0]) == relay, "Aiming at a built structure targets it.")
	placement._set_target(relay)
	check(relay.find_children("*", "MeshInstance3D", true, false)[0].material_overlay == placement.highlight, "The targeted structure glows red.")
	placement._destroy_target()
	check(not session.dashboard_state.built_structures.has("comms_relay") and is_equal_approx(session.dashboard_state.materials, 85.0), "Destroying refunds its materials.")
	placement._stop_destroy()
	world.queue_free()
	await physics_frame
	await process_frame
	print("BUILD MENU TEST: %d failures" % failures)
	quit(failures)

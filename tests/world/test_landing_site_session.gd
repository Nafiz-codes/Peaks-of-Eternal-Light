extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var session := root.get_node("MissionSession")
	var simulator := preload("res://src/simulation/mission_simulator.gd").new()
	assert(simulator.load_contracts() == OK)
	for site in simulator.sites:
		var id := str(site.site_id)
		session.select_landing_site(id)
		assert(session.dashboard_state == null)
		var state: Variant = simulator.begin_mission(id)
		session.dashboard_state = state
		session.dashboard_last_tick = {"sol": 0}
		session.select_landing_site(id)
		assert(session.dashboard_state == state, "Revisiting the same site preserves its mission.")
		var outpost := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(outpost)
		assert(str(site.name) in outpost.get_node("SelectedSiteReadout").text)
		outpost.queue_free()
		await process_frame
		session.select_landing_site("crater_rim_b" if id != "crater_rim_b" else "ridge_a")
		assert(session.dashboard_state == null and session.dashboard_last_tick.is_empty(), "Changing sites clears stale mission state.")
	print("Landing site session tests passed for all four sites.")
	quit()

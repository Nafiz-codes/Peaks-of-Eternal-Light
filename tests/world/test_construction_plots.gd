extends SceneTree
const Plots = preload("res://src/world/construction_plots.gd")
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/plots-" + label + ".png")
func run() -> void:
	var session := root.get_node("MissionSession")
	for site in ["ridge_a", "crater_rim_b", "shadow_zone", "plateau_d"]:
		session.select_landing_site(site)
		session.solar_placement = {}
		session.station_placements = {}
		session.building_placements = {}
		session.start_selected_mission()
		session.dashboard_state.materials = 1000
		session.dashboard_state.power_kwh = 1000
		var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await physics_frame
		await physics_frame
		var placement := world.get_node("SolarPlacement")
		for id in Plots.PLOTS:
			placement._select(id)
			await physics_frame
			placement._physics_process(0.0)
			check(placement.valid, site + " " + id + " center is buildable: " + placement.placement_reason)
			var center: Vector3 = placement.drag_position
			placement.yaw = PI / 4
			await create_timer(0.25).timeout
			placement._physics_process(0.0)
			check(placement._plot_fits(), site + " " + id + " has room for a rotated footprint and entrance")
			placement.drag_position.x += Plots.PLOTS[id].size.x * 0.5
			placement._physics_process(0.0)
			check(not placement.valid, id + " rejects footprint crossing border")
			var materials_before: float = session.dashboard_state.materials
			placement.confirm()
			check(placement.active and session.dashboard_state.materials == materials_before, "Invalid confirmation spends nothing")
			placement.drag_position = center
			placement.yaw = 0
			placement.route_checked_at = 0
			placement._physics_process(0.0)
			if site == "ridge_a": await capture(id)
			placement.confirm()
			await create_timer(0.45).timeout
			check(not placement.active, site + " " + id + " confirmed")
		# Reopening a built station must support cancel without losing its transform.
		var previous: Transform3D = session.station_placements.get("maya_station", Transform3D.IDENTITY)
		placement._select("maya_station")
		await physics_frame
		placement.drag_position += Vector3(2, 0, 0)
		placement._cancel()
		check(session.station_placements.get("maya_station") == previous, "Cancel relocation preserves saved station")
		check(placement.stations.has("maya_station") and placement.stations.maya_station.is_inside_tree(), "Cancel restores original station")
		world.queue_free()
		await process_frame
	print("CONSTRUCTION PLOTS: %d failures" % failures)
	quit(failures)

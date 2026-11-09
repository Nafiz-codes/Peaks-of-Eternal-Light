extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var session := root.get_node("MissionSession")
	for site in JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sites.json")).sites:
		session.select_landing_site(str(site.site_id))
		var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(world)
		current_scene = world
		await process_frame
		var controller := world.get_node("RoverTraining")
		check(not controller.landscape.visible, str(site.site_id) + ": no expedition platform in outpost view")
		controller.set_physics_process(false)
		controller.driver.set_physics_process(false)
		controller.data = {"location": "outpost"}
		controller.driver.active = true
		controller._update_landscape_visibility()
		check(not controller.landscape.visible, "Outpost rover view also hides distant platform")
		controller.data.location = "expedition"
		controller._update_landscape_visibility()
		check(controller.landscape.visible, "Expedition terrain remains available during rover missions")
		controller.driver.active = false
		controller._update_landscape_visibility()
		check(not controller.landscape.visible, "Returning to crew view hides expedition terrain")
		controller.data = {}
		world.queue_free()
		await process_frame
	root.get_node("GameAudio").click_player.stop()
	root.get_node("GameAudio").hover_player.stop()
	await create_timer(0.3).timeout
	print("Expedition visibility: %d failures across all four outposts." % failures)
	quit(1 if failures else 0)

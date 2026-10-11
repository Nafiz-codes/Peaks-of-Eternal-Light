extends SceneTree

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	root.get_node("MissionSession").select_landing_site("crater_rim_b")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	var player = world.get_node("Outpost/Astronaut")
	player.set_first_person(true)
	player.camera_pitch = 0.0
	player._sync_camera_rig()
	for frame in range(12):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("C:/Users/jawad/.codex/visualizations/2026/10/10/01a126ee-a0bf-7d80-a824-d59138505e7b/fpp_preview.png")
	quit()



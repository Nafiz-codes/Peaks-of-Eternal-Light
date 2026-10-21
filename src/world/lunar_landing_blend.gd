extends CanvasLayer

const OUTPOST_SCENE := preload("res://scenes/lunar_outpost_3d.tscn")

## Lives above both scenes so the last map frame bridges scene construction.
func begin(selector: Node) -> void:
	layer = 100
	var cover := TextureRect.new()
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_SCALE
	add_child(cover)
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		cover.texture = ImageTexture.create_from_image(get_viewport().get_texture().get_image())
	var error := get_tree().change_scene_to_packed(OUTPOST_SCENE)
	if error != OK:
		push_error("Unable to open lunar outpost: %s" % error_string(error))
		selector.landing_in_progress = false
		selector._update_camera()
		for marker in get_tree().get_nodes_in_group("lunar_site_marker"):
			marker.scale = Vector3.ONE
		for control in selector.menu_layer.get_children():
			if control is Control:
				control.modulate.a = 1.0
		for button in selector.menu_layer.find_children("*", "Button", true, false):
			button.disabled = false
		selector._update_zoom_controls()
		queue_free()
		return
	await get_tree().scene_changed
	var outpost := get_tree().current_scene
	reparent(outpost) # Interrupted scenes also dispose their transition/tween.
	var player := outpost.get_node("Outpost/Astronaut")
	if get_node("/root/MissionSession").reduce_motion:
		queue_free()
		return
	player.ui_blocked = true
	player.set_physics_process(false)
	# Keep the spring arm enabled while freezing only astronaut locomotion.
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().process_frame
	var gameplay_camera := get_viewport().get_camera_3d()
	var destination := gameplay_camera.global_transform
	var path := preload("res://src/world/safe_arrival_camera.gd").new()
	var safe: bool = not player.first_person and path.configure(player, destination)
	# Saved cockpit/first-person views use a dissolve, never a flight into the body.
	if not safe:
		var dissolve := create_tween()
		dissolve.tween_property(cover, "modulate:a", 0.0, 0.65)
		await dissolve.finished
		player.ui_blocked = false
		player.set_physics_process(true)
		queue_free()
		return
	var arrival := Camera3D.new()
	outpost.add_child(arrival)
	arrival.fov = gameplay_camera.fov
	arrival.global_transform = path.pose(0.0)
	arrival.make_current()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cover, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.tween_method(func(progress: float): arrival.global_transform = path.pose(progress), 0.0, 1.0, 1.6)
	await tween.finished
	gameplay_camera.make_current()
	arrival.queue_free()
	player.ui_blocked = false
	player.set_physics_process(true)
	queue_free()

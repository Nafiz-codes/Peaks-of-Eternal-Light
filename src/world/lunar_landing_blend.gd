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
	var player := outpost.get_node("Outpost/Astronaut")
	if get_node("/root/MissionSession").reduce_motion:
		queue_free()
		return
	player.process_mode = Node.PROCESS_MODE_DISABLED
	# Let the spring arm settle before capturing the final gameplay view.
	await get_tree().physics_frame
	await get_tree().process_frame
	var gameplay_camera := get_viewport().get_camera_3d()
	var destination := gameplay_camera.global_transform
	var arrival := Camera3D.new()
	outpost.add_child(arrival)
	arrival.fov = gameplay_camera.fov
	arrival.global_position = destination.origin + Vector3(0.0, 12.0, 5.0)
	arrival.look_at(player.global_position + Vector3.UP)
	arrival.make_current()
	var tween := create_tween().set_parallel(true)
	tween.tween_property(cover, "modulate:a", 0.0, 0.65).set_trans(Tween.TRANS_SINE)
	tween.tween_property(arrival, "global_transform", destination, 1.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	await tween.finished
	gameplay_camera.make_current()
	arrival.queue_free()
	player.process_mode = Node.PROCESS_MODE_INHERIT
	queue_free()

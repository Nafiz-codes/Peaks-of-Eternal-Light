extends SceneTree

const SELECTOR_SCENE := preload("res://scenes/lunar_landing_selector.tscn")


func _init() -> void:
	call_deferred("_run")


func _run() -> void:
	var selector := SELECTOR_SCENE.instantiate()
	selector.set("launch_outpost_on_selection", false)
	root.add_child(selector)
	await process_frame
	_assert(selector.get("site_records").size() == 4, "The selector loads all four sourced landing sites.")
	_assert(selector.get_node_or_null("ridge_a_ClickArea") != null, "Ridge A has a clickable map location.")
	_assert(selector.is_processing_unhandled_input(), "The selector listens for mouse input while its scene is active.")
	selector.call("_toggle_polar_view")
	await physics_frame
	await physics_frame
	var camera := selector.get_node("SelectorCamera") as Camera3D
	var marker := selector.get_node("ridge_a") as MeshInstance3D
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = camera.unproject_position(marker.global_position)
	selector.call("_unhandled_input", click)
	_assert(selector.get("selected_site_id") == "ridge_a", "Selecting a map marker preserves its site identifier.")
	var features: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/landing_features/coordinates.json"))
	for feature in features.features:
		for site in selector.get("site_records"):
			if site.name == feature.name:
				_assert(is_equal_approx(float(site.coordinates.latitude_deg), -absf(float(feature.latitude_deg))), "Site latitude uses the confirmed south-pole shapefile correction.")
				_assert(is_equal_approx(float(site.coordinates.longitude_deg), float(feature.longitude_deg)), "Site longitude is matched by shapefile name, not record order.")
	var moon := selector.get_node("SouthPoleMap") as MeshInstance3D
	_assert(moon.mesh is SphereMesh and is_equal_approx(moon.mesh.radius, 10.0), "The Moon becomes a sphere without changing its radius.")
	_assert(selector.call("_globe_position", 0.0, 0.0).is_equal_approx(Vector3(0, 0, 10)), "Prime meridian faces the photograph.")
	_assert(selector.call("_globe_position", 0.0, 90.0).is_equal_approx(Vector3(10, 0, 0)), "East longitude is on the right.")
	_assert(selector.call("_globe_position", -90.0, 0.0).is_equal_approx(Vector3(0, -10, 0)), "South pole is at the bottom of the globe.")
	for site in selector.get("site_records"):
		var pin := selector.get_node(str(site.site_id)) as MeshInstance3D
		var coordinates: Dictionary = site.coordinates
		var base: Vector3 = pin.position - pin.basis.y * pin.mesh.height * 0.5
		_assert(absf(base.length() - 10.0) < 0.003, "Each outpost base touches the Moon instead of floating beside it.")
		_assert(pin.basis.y.dot(pin.position.normalized()) > 0.9999, "Each post stands perpendicular to its local lunar surface.")
		var actual := pin.position.normalized()
		_assert(absf(rad_to_deg(asin(actual.y)) - float(coordinates.latitude_deg)) < 0.001, "Pin latitude matches its named site.")
		var longitude := fposmod(rad_to_deg(atan2(actual.x, actual.z)), 360.0)
		_assert(absf(longitude - float(coordinates.longitude_deg)) < 0.001, "Pin longitude matches its named site.")
		click.position = camera.unproject_position(pin.global_position)
		selector.call("_unhandled_input", click)
		_assert(selector.get("selected_site_id") == site.site_id, "Each polar marker is individually selectable.")
	selector.call("_toggle_polar_view")
	selector.set("orbit", Vector2.ZERO)
	selector.call("_update_camera")
	var motion := InputEventMouseMotion.new()
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	motion.relative = Vector2(400, 0)
	selector.call("_unhandled_input", motion)
	_assert(camera.position.z < 0.0, "Orbit reaches the far side, beyond the old near-side clamp.")
	motion.relative = Vector2(-400, 0)
	selector.call("_unhandled_input", motion)
	_assert(camera.position.is_equal_approx(Vector3(0, 0, 30)), "Orbit returns to the prime meridian.")
	var material := moon.material_override as ShaderMaterial
	_assert(material.get_shader_parameter("color_map").get_width() == 4096, "Default global albedo retains 4K resolution.")
	_assert(material.get_shader_parameter("legacy_color_map").get_width() == 4096, "Alternative global albedo retains 4K resolution.")
	_assert(material.get_shader_parameter("relief_map").get_width() == 1440, "LOLA relief retains source spatial resolution.")
	selector.call("_toggle_surface_map")
	_assert(material.get_shader_parameter("use_legacy_map") == true, "Alternative surface map can be selected.")
	selector.call("_toggle_surface_map")
	_assert(material.get_shader_parameter("use_legacy_map") == false, "Default surface map can be restored.")
	selector.set("orbit", Vector2(0, -PI * 0.5 + 0.001))
	selector.call("_update_camera")
	selector.call("_update_site_callouts")
	for callout in selector.get("site_callouts"):
		_assert(callout.button.visible, "Surface labels are visible from the landing hemisphere.")
		callout.button.pressed.emit()
		_assert(selector.get("selected_site_id") == callout.site_id, "On-Moon labels select their own outpost.")
		var site: Dictionary = selector.call("_site_by_id", callout.site_id)
		var anchor: Vector3 = selector.call("_globe_position", site.coordinates.latitude_deg, site.coordinates.longitude_deg)
		_assert(callout.dot.position.distance_to(camera.unproject_position(anchor)) < 0.1, "Leader endpoint stays at the geographic coordinate.")
	selector.set("orbit", Vector2(0, PI * 0.5 - 0.001))
	selector.call("_update_camera")
	selector.call("_update_site_callouts")
	for callout in selector.get("site_callouts"):
		_assert(not callout.button.visible, "Opposite-hemisphere sites cannot appear through the Moon.")
	print("LunarLandingSelector tests passed.")
	quit(0)


func _assert(condition: bool, message: String) -> void:
	if not condition:
		push_error(message)
		quit(1)

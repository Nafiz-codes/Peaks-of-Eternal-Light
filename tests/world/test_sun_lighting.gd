extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://Resources/sun_display.json"))
	for site_id in data.sites:
		root.get_node("MissionSession").select_landing_site(site_id)
		var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
		root.add_child(world)
		var light := world.get_node("LowPolarSun") as DirectionalLight3D
		var material: ShaderMaterial = world.get_node("LunarEnvironment").environment.sky.sky_material
		var direction: Vector3 = material.get_shader_parameter("display_sun_direction")
		var rays := -light.global_basis.z.normalized()
		check(rays.dot(direction.normalized()) < -0.99999, site_id + ": light rays travel away from the visible Sun")
		check(direction.is_equal_approx(world.get_node("OrbitalMotion").observation.sun_direction), site_id + ": shader shares orbital Sun")
		# Project a ray from the top of a one-meter pole to a flat ground plane.
		var shadow := Vector3.UP + rays / -rays.y
		var toward_sun := Vector3(direction.x, 0, direction.z).normalized()
		check(shadow.normalized().dot(toward_sun) * signf(direction.y) < -0.99999, site_id + ": shadow falls opposite the Sun")
		var expected_length := absf(1.0 / tan(asin(direction.y)))
		check(absf(shadow.length() - expected_length) < 0.001, site_id + ": shadow projection matches orbital solar elevation")
		check(light.light_energy == 0.0 if direction.y < -0.01 else light.light_energy > 0.0, site_id + ": direct light respects horizon")
		check(light.shadow_enabled, site_id + ": shadows remain enabled")
		check(world.find_children("*", "DirectionalLight3D", true, false).size() == 1, site_id + ": no additional directional light")
		world.free()
	print("Sun lighting: %d failures across all four outposts." % failures)
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

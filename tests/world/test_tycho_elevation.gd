extends SceneTree

const Elevation = preload("res://src/world/tycho_elevation.gd")
const Terrain = preload("res://src/world/outpost_terrain.gd")
var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _run() -> void:
	# Independently place every valid source pixel center in local coordinates.
	var expected := [[-1076.0, -1069.5, -1068.0], [-1063.5, -1054.0, -1050.5]]
	for row in range(2):
		for column in range(3):
			var x := (10573017.899764 + (column + 1.5) * 59.2252938 - 1737400.0 * deg_to_rad(348.68)) * cos(deg_to_rad(-43.37))
			var z := 1737400.0 * deg_to_rad(-43.37) - (-1315038.4235352 - (row + 0.5) * 59.2252938)
			check(absf(Elevation.elevation(x, z) - expected[row][column]) < 0.0001, "Source sample scale and orientation")
	check(Elevation.height(0, 0) == 0 and Elevation.height(10, 0) == 0, "Landing pad stays level")
	var site := {"site_id": "crater_rim_b"}
	var terrain := Terrain.build(site)
	var horizon := Terrain.build_surroundings(site, terrain.material_override)
	var vertices: PackedVector3Array = terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var outer: PackedVector3Array = horizon.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var edge_heights := {}
	for p in vertices:
		check(is_finite(p.y) and absf(p.y) < 30, "No invalid elevation spikes")
		if absf(p.x) == 60 or absf(p.z) == 60:
			edge_heights[Vector2(p.x, p.z)] = p.y
	for p in outer:
		if maxf(absf(p.x), absf(p.z)) == 60:
			check(absf(p.y - float(edge_heights[Vector2(p.x, p.z)])) < 0.0001, "Horizon joins terrain without cracks")
	root.add_child(terrain)
	terrain.create_trimesh_collision()
	await physics_frame
	await physics_frame
	for point in [Vector2(-40, -40), Vector2(40, 40), Vector2.ZERO]:
		var query := PhysicsRayQueryParameters3D.create(Vector3(point.x, 50, point.y), Vector3(point.x, -50, point.y))
		var hit := terrain.get_world_3d().direct_space_state.intersect_ray(query)
		check(not hit.is_empty(), "Reshaped terrain has collision")
		if not hit.is_empty():
			check(absf(hit.position.y - Elevation.height(point.x, point.y)) < 0.001, "Collision follows terrain height")
	horizon.free()
	terrain.free()
	root.get_node("MissionSession").select_landing_site("crater_rim_b")
	var world := preload("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var stones := world.get_node("SurfaceStones")
	check(stones.get_child_count() == 40, "Reduced stone count populates the terrain")
	var placed: Array[Vector3] = []
	var used_meshes := {}
	for stone in stones.get_children():
		for other in placed:
			check(Vector2(stone.position.x - other.x, stone.position.z - other.z).length() >= 8.0, "Stones have eight meters of spacing")
		placed.append(stone.position)
		check(Vector2(stone.position.x, stone.position.z).length() >= 34.0, "Stones keep the landing pad clear")
		check(maxf(absf(stone.position.x), absf(stone.position.z)) <= 56.0, "Stones stay inside the boundary")
		var visual: MeshInstance3D = stone.get_child(0)
		check(visual.material_override.albedo_color.r <= 0.48, "Stones use a darker material")
		used_meshes[visual.mesh.resource_path] = true
		var footprint := visual.mesh.get_aabb().size * visual.scale
		check(maxf(footprint.x, footprint.z) <= 2.01, "Imported units normalize to natural rock sizes")
	check(used_meshes.size() == 9, "All eight rock variants and the separate stone are used")
	for prop in ["Habitat", "SolarArray", "Rover", "power_console", "water_recycler", "food_storage", "crew_briefing"]:
		for mesh in world.get_node("Outpost/" + prop).find_children("*", "MeshInstance3D", true, false):
			var bounds: AABB = mesh.global_transform * mesh.get_aabb()
			for x in [bounds.position.x, bounds.end.x]:
				for z in [bounds.position.z, bounds.end.z]:
					check(Elevation.height(x, z) == 0.0, prop + " footprint stays on the level pad")
	var sky: ShaderMaterial = world.get_node("LunarEnvironment").environment.sky.sky_material
	var earth_position: Vector3 = sky.get_shader_parameter("earth_position_km")
	var modeled: Vector3 = world.get_node("OrbitalMotion").observation.earth_position_km
	check(earth_position.is_equal_approx(modeled * world.EARTH_DISTANCE_SCALE), "Earth follows the orbital observer geometry")
	check(absf(float(sky.get_shader_parameter("earth_radius_km")) - 6378.137) < 0.01, "Earth uses its physical radius")
	world.queue_free()
	await process_frame
	print("Tycho elevation tests: %d failures." % failures)
	quit(1 if failures else 0)

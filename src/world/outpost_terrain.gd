extends RefCounted

# Deterministic art direction per site, not a reconstruction of LOLA pixels.
static func build(site: Dictionary) -> MeshInstance3D:
	var seed_value := absi(str(site.get("site_id", "ridge_a")).hash())
	var noise := FastNoiseLite.new()
	noise.seed = seed_value % 2147483647
	noise.frequency = 0.055
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var amplitude := 2.0 + float(seed_value % 5)
	for z in range(-30, 30):
		for x in range(-30, 30):
			var points: Array[Vector3] = []
			for offset in [Vector2(0, 0), Vector2(1, 0), Vector2(0, 1), Vector2(1, 1)]:
				var px: float = (float(x) + offset.x) * 2.0
				var pz: float = (float(z) + offset.y) * 2.0
				var blend := smoothstep(12.0, 27.0, Vector2(px, pz).length())
				var height := blend * (1.5 + noise.get_noise_2d(px, pz) * amplitude)
				points.append(Vector3(px, height, pz))
			for index in [0, 1, 2, 1, 3, 2]:
				surface.set_uv(Vector2(points[index].x, points[index].z) * 0.12)
				surface.add_vertex(points[index])
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "LunarRegolith"
	terrain.mesh = surface.commit()
	var material := StandardMaterial3D.new()
	var tones := [Color("666774"), Color("77716c"), Color("626875"), Color("817b70")]
	material.albedo_color = tones[seed_value % tones.size()]
	material.roughness = 0.98
	var grain := NoiseTexture2D.new()
	var grain_noise := FastNoiseLite.new()
	grain_noise.seed = noise.seed
	grain_noise.frequency = 0.12
	grain.noise = grain_noise
	var ramp := Gradient.new()
	ramp.colors = PackedColorArray([Color(0.65, 0.65, 0.65), Color(0.9, 0.9, 0.9)])
	grain.color_ramp = ramp
	grain.width = 256
	grain.height = 256
	grain.seamless = true
	material.albedo_texture = grain
	terrain.material_override = material
	return terrain

# Visual-only rings share the playable mesh's exact 2 m edge samples, then
# become coarser with distance. The original surface and collision stay intact.
static func build_surroundings(site: Dictionary, material: Material) -> MeshInstance3D:
	var seed_value := absi(str(site.get("site_id", "ridge_a")).hash())
	var noise := FastNoiseLite.new()
	noise.seed = seed_value % 2147483647
	noise.frequency = 0.055
	var broad_noise := FastNoiseLite.new()
	broad_noise.seed = noise.seed
	broad_noise.frequency = 0.0018
	var amplitude := 2.0 + float(seed_value % 5)
	var perimeter: Array[Vector2] = []
	for index in range(60):
		perimeter.append(Vector2(-60 + index * 2, -60))
	for index in range(60):
		perimeter.append(Vector2(60, -60 + index * 2))
	for index in range(60):
		perimeter.append(Vector2(60 - index * 2, 60))
	for index in range(60):
		perimeter.append(Vector2(-60, 60 - index * 2))
	var rings: Array = []
	for radius in [60.0, 80.0, 100.0, 120.0, 145.0, 175.0, 210.0, 250.0, 300.0, 360.0, 440.0, 540.0, 660.0, 850.0, 1100.0, 1600.0, 2500.0]:
		var ring: Array[Vector3] = []
		for point in perimeter:
			var p: Vector2 = point * (radius / 60.0)
			var height := 1.5 + noise.get_noise_2d(p.x, p.y) * amplitude
			var distant_blend := smoothstep(60.0, 220.0, radius)
			var relief := 1.5 + broad_noise.get_noise_2d(p.x, p.y) * 2.5
			# Separate low ridges leave broad stretches of open plain between them.
			for ridge in [Vector4(-180, -150, 0.5, 8.0), Vector4(210, -230, -0.7, 10.0), Vector4(290, 180, 0.9, 7.0), Vector4(-260, 320, -0.3, 9.0), Vector4(60, 520, 0.2, 12.0)]:
				var local: Vector2 = (p - Vector2(ridge.x, ridge.y)).rotated(ridge.z)
				relief += ridge.w * exp(-pow(local.x / 30.0, 2.0) - pow(local.y / 95.0, 2.0))
			# Shallow worn crater bowls and low rims across a gently rolling plain.
			for crater in [Vector3(-310, 190, 120), Vector3(270, -400, 170), Vector3(680, 440, 240), Vector3(-850, -620, 300)]:
				var distance: float = p.distance_to(Vector2(crater.x, crater.y)) / crater.z
				relief += 0.8 * exp(-pow((distance - 1.0) / 0.25, 2.0)) - 3.0 * maxf(0.0, 1.0 - distance * distance)
			height = lerpf(height, relief, distant_blend)
			# A gentle horizon drop avoids a raised rim around the distant plain.
			height -= distant_blend * p.length_squared() * 0.0000003
			ring.append(Vector3(p.x, height, p.y))
		rings.append(ring)
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rock_sites: Array[Vector3] = []
	for ring_index in range(rings.size() - 1):
		for index in range(perimeter.size()):
			var next := (index + 1) % perimeter.size()
			var center: Vector3 = (rings[ring_index][index] + rings[ring_index + 1][index] + rings[ring_index][next]) / 3.0
			if Vector2(center.x, center.z).length() > 110.0 and Vector2(center.x, center.z).length() < 360.0:
				rock_sites.append(center)
			for point in [rings[ring_index][index], rings[ring_index + 1][index], rings[ring_index][next], rings[ring_index][next], rings[ring_index + 1][index], rings[ring_index + 1][next]]:
				surface.set_uv(Vector2(point.x, point.z) * 0.12)
				surface.add_vertex(point)
	surface.generate_normals()
	var terrain := MeshInstance3D.new()
	terrain.name = "LunarHorizon"
	terrain.mesh = surface.commit()
	terrain.material_override = material
	_add_rocky_hills(terrain, rock_sites, seed_value, material)
	return terrain

static func _add_rocky_hills(terrain: MeshInstance3D, sites: Array[Vector3], seed_value: int, material: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 731
	var stone_material := material.duplicate() as StandardMaterial3D
	stone_material.albedo_color = stone_material.albedo_color.darkened(0.18)
	var sphere := SphereMesh.new()
	sphere.radius = 1.0
	sphere.height = 2.0
	sphere.radial_segments = 9
	sphere.rings = 4
	var arrays := sphere.get_mesh_arrays()
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for index in range(vertices.size()):
		var p := vertices[index]
		vertices[index] *= 1.0 + 0.16 * sin(p.x * 7.0 + p.y * 4.0) * cos(p.z * 6.0 - p.y * 3.0)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	var rough_mesh := ArrayMesh.new()
	rough_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var surface := SurfaceTool.new()
	surface.create_from(rough_mesh, 0)
	surface.generate_normals()
	var stone_mesh := surface.commit()
	for hill_index in range(24):
		# Actual triangle centers anchor the clusters to the rendered ground.
		var center := sites[rng.randi_range(0, sites.size() - 1)]
		for rock_index in range(5):
			var rock := MeshInstance3D.new()
			rock.name = "StoneHill_%02d_Rock_%d" % [hill_index, rock_index]
			rock.mesh = stone_mesh
			rock.material_override = stone_material
			rock.scale = Vector3(rng.randf_range(3.0, 6.0), rng.randf_range(2.5, 5.0), rng.randf_range(3.0, 6.0))
			rock.rotation = Vector3(rng.randf_range(-0.2, 0.2), rng.randf_range(0.0, TAU), rng.randf_range(-0.2, 0.2))
			rock.position = center + Vector3(rng.randf_range(-3.0, 3.0), -1.0, rng.randf_range(-3.0, 3.0))
			terrain.add_child(rock)

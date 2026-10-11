extends RefCounted

const BURIAL_FRACTION := 0.28

static func build(ground: MeshInstance3D, site_id: String) -> Node3D:
	var result := Node3D.new()
	result.name = "SurfaceStones"
	var variants: Array[Mesh] = []
	for index in range(8):
		variants.append(load("res://Assets/rocks/variant_%02d.res" % index))
	variants.append(load("res://Assets/rocks/stone_mesh.res"))
	var materials: Array[Material] = []
	for mesh in variants:
		var material := mesh.surface_get_material(0).duplicate() as StandardMaterial3D
		material.albedo_color = material.albedo_color * Color(0.48, 0.48, 0.48, 1.0)
		material.roughness = 1.0
		materials.append(material)
	var vertices: PackedVector3Array = ground.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(site_id.hash()) + 8197
	var occupied: Array[Vector3] = []
	for attempt in range(1200):
		if occupied.size() >= 40:
			break
		var triangle := rng.randi_range(0, vertices.size() / 3 - 1) * 3
		var a := vertices[triangle]
		var b := vertices[triangle + 1]
		var c := vertices[triangle + 2]
		var u := sqrt(rng.randf())
		var v := rng.randf()
		var point := (1.0 - u) * a + u * (1.0 - v) * b + u * v * c
		# Keep the full base, construction slots, and boundary approaches open.
		if Vector2(point.x, point.z).length() < 34.0 or maxf(absf(point.x), absf(point.z)) > 56.0:
			continue
		var width := rng.randf_range(0.2, 0.65) if rng.randf() < 0.7 else rng.randf_range(0.8, 2.0)
		var crowded := false
		for other in occupied:
			if Vector2(point.x - other.x, point.z - other.z).length() < maxf(8.0, width + other.y):
				crowded = true
		if crowded:
			continue
		occupied.append(Vector3(point.x, width, point.z))
		var variant := rng.randi_range(0, variants.size() - 1)
		var mesh := variants[variant]
		var bounds := mesh.get_aabb()
		var scale_factor := width / maxf(bounds.size.x, bounds.size.z)
		var normal := (c - a).cross(b - a).normalized()
		if normal.y < 0:
			normal = -normal
		var anchor := StaticBody3D.new()
		anchor.name = "Stone_%03d" % occupied.size()
		anchor.position = point
		anchor.basis = Basis(Quaternion(Vector3.UP, normal)) * Basis(Vector3.UP, rng.randf_range(0, TAU))
		var visual := MeshInstance3D.new()
		visual.mesh = mesh
		visual.material_override = materials[variant]
		visual.scale = Vector3.ONE * scale_factor
		visual.position = -Vector3(bounds.get_center().x, bounds.position.y + bounds.size.y * BURIAL_FRACTION, bounds.get_center().z) * scale_factor
		visual.visibility_range_end = 180.0
		anchor.add_child(visual)
		if width >= 0.8:
			# Simple hull encloses the exposed stone, without expensive triangle collision.
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = bounds.size * scale_factor * Vector3(0.8, 1.0 - BURIAL_FRACTION, 0.8)
			collision.shape = shape
			collision.position.y = shape.size.y * 0.5
			anchor.add_child(collision)
		result.add_child(anchor)
	return result

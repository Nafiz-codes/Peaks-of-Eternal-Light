extends SceneTree

# The rock pack is a display grid of variants/LODs. Extract its eight rocks
# from the final material column instead of scattering the whole display.
func _init() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node3D = load("res://Assets/rocks/grey_white_rocks.glb").instantiate()
	root.add_child(scene)
	var meshes := scene.find_children("*", "MeshInstance3D", true, false)
	var source: MeshInstance3D = meshes[-1]
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
	# Find empty gaps along the original display's long axis.
	var bounds := source.mesh.get_aabb()
	var axis := bounds.size.max_axis_index()
	var coordinates: Array[float] = []
	for v in vertices:
		coordinates.append(v[axis])
	coordinates.sort()
	var breaks: Array[float] = []
	for i in range(1, coordinates.size()):
		if coordinates[i] - coordinates[i - 1] > 0.5:
			breaks.append((coordinates[i] + coordinates[i - 1]) * 0.5)
	var groups: Array[SurfaceTool] = []
	for i in range(breaks.size() + 1):
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		surface.set_material(source.get_active_material(0))
		groups.append(surface)
	for i in range(0, indices.size(), 3):
		var center := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
		var group := 0
		for cut in breaks:
			if center[axis] > cut:
				group += 1
		for j in range(3):
			var index := indices[i + j]
			groups[group].set_normal((source.global_transform.basis.inverse().transposed() * normals[index]).normalized())
			groups[group].set_uv(uvs[index])
			groups[group].add_vertex(source.global_transform * vertices[index])
	for i in range(groups.size()):
		groups[i].generate_tangents()
		var mesh := groups[i].commit()
		ResourceSaver.save(mesh, "res://Assets/rocks/variant_%02d.res" % i)
	print("Extracted rock variants: ", groups.size())
	scene.free()
	var stone: Node3D = load("res://Assets/rocks/stone.glb").instantiate()
	root.add_child(stone)
	var stone_source: MeshInstance3D = stone.find_children("*", "MeshInstance3D", true, false)[0]
	var stone_surface := SurfaceTool.new()
	stone_surface.append_from(stone_source.mesh, 0, stone_source.global_transform)
	stone_surface.set_material(stone_source.get_active_material(0))
	ResourceSaver.save(stone_surface.commit(), "res://Assets/rocks/stone_mesh.res")
	stone.free()
	quit()

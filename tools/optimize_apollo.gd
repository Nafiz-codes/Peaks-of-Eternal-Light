extends SceneTree
## Offline render-mesh simplification. Keep the source GLB untouched.
func _init() -> void:
	call_deferred("run")
func run() -> void:
	var model = load("res://Assets/apollo/command_module.glb").instantiate()
	var before := 0
	var after := 0
	for node in model.find_children("*", "MeshInstance3D", true, false):
		var source: ArrayMesh = node.mesh
		var importer := ImporterMesh.new()
		for surface in range(source.get_surface_count()):
			importer.add_surface(Mesh.PRIMITIVE_TRIANGLES, source.surface_get_arrays(surface), [], {}, source.surface_get_material(surface))
		importer.generate_lods(60.0, 25.0, [])
		var result := ArrayMesh.new()
		for surface in range(source.get_surface_count()):
			var arrays := importer.get_surface_arrays(surface)
			var original: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var selected := original
			# Preserve at least 12.5% of triangles and never simplify already small parts.
			for lod in range(importer.get_surface_lod_count(surface)):
				var candidate := importer.get_surface_lod_indices(surface, lod)
				if candidate.size() >= maxi(1200, int(original.size() * 0.125)) and candidate.size() < selected.size():
					selected = candidate
			arrays[Mesh.ARRAY_INDEX] = selected
			var distance_lods := {}
			for lod in range(importer.get_surface_lod_count(surface)):
				var candidate := importer.get_surface_lod_indices(surface, lod)
				if candidate.size() < selected.size():
					distance_lods[importer.get_surface_lod_size(surface, lod)] = candidate
			result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], distance_lods)
			result.surface_set_material(surface, source.surface_get_material(surface))
			before += original.size() / 3
			after += selected.size() / 3
		node.mesh = result
		# The close-range interior lights need no repeated shadow pass for every switch.
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if node.name == "Object_2" else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var scene := PackedScene.new()
	scene.pack(model)
	var error := ResourceSaver.save(scene, "res://Assets/apollo/command_module_optimized.scn", ResourceSaver.FLAG_COMPRESS)
	print("Apollo render triangles: %d -> %d; save=%d" % [before, after, error])
	model.free()
	quit(error)

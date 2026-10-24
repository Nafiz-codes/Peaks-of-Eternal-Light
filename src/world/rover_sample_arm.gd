extends Node3D
## Articulate the supplied, rigid front instrument assembly. No added tool mesh.
var rest := Transform3D.IDENTITY
var triangle_count := 0
func setup(model: Node3D) -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	# Authored coordinates: wheel batch is 8; the front hand lies below the deck.
	var source_transform: Transform3D = meshes[0].global_transform
	global_transform = source_transform * Transform3D(Basis.IDENTITY,Vector3(0,79,121))
	for index in range(meshes.size()):
		if index == 8: continue
		var source: MeshInstance3D = meshes[index]
		var fixed_mesh := ArrayMesh.new()
		var hand_mesh := ArrayMesh.new()
		for s in range(source.mesh.get_surface_count()):
			var arrays := source.mesh.surface_get_arrays(s)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			var fixed := PackedInt32Array()
			var moving := PackedInt32Array()
			for t in range(0,indices.size(),3):
				var center := (vertices[indices[t]]+vertices[indices[t+1]]+vertices[indices[t+2]])/3
				var selected := center.z > 122 and center.y < 82 and center.y > 30
				for j in range(3):
					if selected: moving.append(indices[t+j])
					else: fixed.append(indices[t+j])
			for pair in [[fixed,fixed_mesh],[moving,hand_mesh]]:
				if pair[0].is_empty(): continue
				var copy := arrays.duplicate()
				copy[Mesh.ARRAY_INDEX] = pair[0]
				pair[1].add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,copy)
				pair[1].surface_set_material(pair[1].get_surface_count()-1,source.get_active_material(s))
			triangle_count += moving.size()/3
		if hand_mesh.get_surface_count() == 0: continue
		var hand := MeshInstance3D.new()
		hand.mesh = hand_mesh
		add_child(hand)
		hand.global_transform = source.global_transform
		source.mesh = fixed_mesh
	rest = transform
func pose(progress: float) -> void:
	transform = rest * Transform3D(Basis(Vector3.RIGHT,deg_to_rad(22)*sin(PI*progress)),Vector3.ZERO)

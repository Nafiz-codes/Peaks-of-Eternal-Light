extends Node3D

## The supplied Curiosity asset batches all six tires into mesh 8.
## Split its triangles without changing their materials or vertex attributes.
var wheels: Array[Dictionary] = []

func setup(model: Node3D) -> void:
	var meshes := model.find_children("*", "MeshInstance3D", true, false)
	var source := meshes[8] as MeshInstance3D
	var arrays := source.mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var groups: Array[PackedInt32Array] = []
	for i in range(6):
		groups.append(PackedInt32Array())
	for i in range(0, indices.size(), 3):
		var center := (vertices[indices[i]] + vertices[indices[i + 1]] + vertices[indices[i + 2]]) / 3.0
		# Authored tire rows have clear gaps at z = -60 and +50.
		var row := 0 if center.z < -60.0 else (2 if center.z > 50.0 else 1)
		var group := row * 2 + (1 if center.x > 0.0 else 0)
		for j in range(3):
			groups[group].append(indices[i + j])
	var to_rover := global_transform.affine_inverse() * source.global_transform
	for group in groups:
		var bounds := AABB(vertices[group[0]], Vector3.ZERO)
		for index in group:
			bounds = bounds.expand(vertices[index])
		var center := to_rover * bounds.get_center()
		var pivot := Node3D.new()
		add_child(pivot)
		pivot.position = center
		var spin := Node3D.new()
		pivot.add_child(spin)
		var tire := MeshInstance3D.new()
		var mesh := ArrayMesh.new()
		var tire_arrays := arrays.duplicate()
		tire_arrays[Mesh.ARRAY_INDEX] = group
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, tire_arrays)
		mesh.surface_set_material(0, source.get_active_material(0))
		tire.mesh = mesh
		spin.add_child(tire)
		tire.transform = Transform3D(Basis.IDENTITY, -center) * to_rover
		wheels.append({"pivot": pivot, "spin": spin, "center": center,
			"radius": bounds.size.y * to_rover.basis.y.length() * 0.5, "angle": 0.0})
	source.hide()

func update_motion(distance: float, steering: float, wheelbase: float) -> void:
	var curvature := tan(steering) / wheelbase
	var rear_z: float = wheels[0].center.z
	for wheel in wheels:
		var center: Vector3 = wheel.center
		var longitudinal := 1.0 + curvature * center.x
		var lateral := -curvature * (center.z - rear_z)
		wheel.pivot.rotation.y = atan2(lateral, longitudinal)
		wheel.angle = wrapf(wheel.angle + distance * Vector2(lateral, longitudinal).length() / wheel.radius, -PI, PI)
		wheel.spin.rotation.x = wheel.angle

func reset() -> void:
	for wheel in wheels:
		wheel.angle = 0.0
		wheel.spin.rotation = Vector3.ZERO
		wheel.pivot.rotation = Vector3.ZERO

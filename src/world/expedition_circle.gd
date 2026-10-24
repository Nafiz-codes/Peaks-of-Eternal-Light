extends Node3D
## Non-solid gameplay marker inspired by the supplied translucent cylinder.
var cylinder: MeshInstance3D
var ring: MeshInstance3D
func _ready() -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = 4.5
	mesh.bottom_radius = 4.5
	mesh.height = 1.7
	mesh.cap_top = false
	mesh.cap_bottom = false
	cylinder = MeshInstance3D.new()
	cylinder.mesh = mesh
	cylinder.position.y = 0.85
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	material.albedo_color = Color(0.66,0.38,0.92,0.17)
	cylinder.material_override = material
	add_child(cylinder)
	ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 4.35
	torus.outer_radius = 4.5
	ring.mesh = torus
	ring.position.y = 0.12
	var glow := material.duplicate() as StandardMaterial3D
	glow.albedo_color.a = 0.8
	ring.material_override = glow
	add_child(ring)

func conform_to_ground(sample_height: Callable) -> void:
	var wall := SurfaceTool.new()
	var band := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	band.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in range(96):
		var a := TAU*i/96.0
		var b := TAU*(i+1)/96.0
		var points: Array[Vector3] = []
		for pair in [[a,4.35],[b,4.35],[a,4.5],[b,4.5]]:
			var p := Vector3(cos(pair[0])*pair[1],0,sin(pair[0])*pair[1])
			p.y = float(sample_height.call(global_position+p))-global_position.y+0.09
			points.append(p)
		for j in [0,1,2,1,3,2]: band.add_vertex(points[j])
		var base_a := points[2]
		var base_b := points[3]
		var corners := [base_a,base_b,base_a+Vector3.UP*1.7,base_b+Vector3.UP*1.7]
		for j in [0,1,2,1,3,2]:
			wall.set_color(Color(1,1,1,0.05 if j>1 else 1.0))
			wall.add_vertex(corners[j])
	wall.generate_normals()
	band.generate_normals()
	cylinder.mesh = wall.commit()
	cylinder.position = Vector3.ZERO
	cylinder.material_override.vertex_color_use_as_albedo = true
	ring.mesh = band.commit()
	ring.position = Vector3.ZERO

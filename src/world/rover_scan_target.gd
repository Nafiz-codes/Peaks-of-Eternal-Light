extends Area3D
## Layer 8 is reserved for non-solid training sensors; physics obstacles stay on 1.
var target_id := ""
var caption: Label3D
var marker: MeshInstance3D
var base_tint := Color.WHITE

func setup(id: String, title: String, tint: Color) -> void:
	target_id = id
	base_tint = tint
	name = "Target_" + id
	collision_layer = 128
	collision_mask = 0
	monitoring = false
	add_to_group("rover_training_targets")
	var collision := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.75
	collision.shape = sphere
	collision.position.y = 1.2
	add_child(collision)
	marker = MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.5
	mesh.bottom_radius = 0.5
	mesh.height = 0.08
	marker.mesh = mesh
	marker.position.y = 0.12
	var material := StandardMaterial3D.new()
	material.albedo_color = tint
	material.emission_enabled = true
	material.emission = tint * 0.45
	marker.material_override = material
	add_child(marker)
	caption = Label3D.new()
	caption.text = title
	caption.position.y = 2.7
	caption.font_size = 30
	caption.pixel_size = 0.008
	caption.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	caption.modulate = tint
	add_child(caption)

func aim_point() -> Vector3:
	return global_position + Vector3.UP * 1.2

extends RefCounted
## Station crew reuse the player's suit and idle clip; only armbands carry color.

static func populate(station: Node3D, astronaut_scene: PackedScene, color: Color) -> void:
	var visual := astronaut_scene.instantiate() as Node3D
	visual.name = "StationAstronaut"
	visual.position.y = -0.04
	visual.rotation_degrees.y = 180.0
	station.add_child(visual)
	for node in visual.find_children("*", "AnimationPlayer", true, false):
		var player := node as AnimationPlayer
		player.get_animation("idle").loop_mode = Animation.LOOP_LINEAR
		player.play("idle")
		player.advance(0.0)
	for node in visual.find_children("*", "Skeleton3D", true, false):
		var skeleton := node as Skeleton3D
		for side in ["L", "R"]:
			_add_armband(skeleton, side, color)
	var body := StaticBody3D.new()
	body.name = "CrewBody"
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.7
	collision.shape = capsule
	collision.position.y = 0.85
	body.add_child(collision)
	station.add_child(body)


static func _add_armband(skeleton: Skeleton3D, side: String, color: Color) -> void:
	var arm := -1
	var elbow := -1
	for index in range(skeleton.get_bone_count()):
		var bone_name := skeleton.get_bone_name(index)
		if bone_name.begins_with(side + "_Arm."):
			arm = index
		elif bone_name.begins_with(side + "_Elbow."):
			elbow = index
	if arm < 0 or elbow < 0:
		push_error("Station astronaut is missing its upper-arm bones.")
		return
	var attachment := BoneAttachment3D.new()
	attachment.name = side + "_ArmbandAttachment"
	attachment.bone_name = skeleton.get_bone_name(arm)
	skeleton.add_child(attachment)
	var arm_rest := skeleton.get_bone_global_rest(arm)
	var elbow_local := arm_rest.affine_inverse() * skeleton.get_bone_global_rest(elbow).origin
	# Imported skeleton uses centimeters; derive units from its world scale.
	var units_per_meter := 1.0 / skeleton.global_basis.get_scale().x
	var band := MeshInstance3D.new()
	band.name = "Armband"
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.12 * units_per_meter
	mesh.bottom_radius = mesh.top_radius
	mesh.height = 0.08 * units_per_meter
	mesh.radial_segments = 32
	mesh.cap_top = false
	mesh.cap_bottom = false
	band.mesh = mesh
	band.position = elbow_local * 0.45
	band.basis = Basis(Quaternion(Vector3.UP, elbow_local.normalized()))
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.85
	band.material_override = material
	attachment.add_child(band)

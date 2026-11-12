extends RefCounted
## Pose the existing skinned suit in the crew couch without removing any surfaces.
var original_visual_transform := Transform3D.IDENTITY
var saved_rotations: Dictionary = {}
var skeleton: Skeleton3D

func apply(visual: Node3D, player: Node3D) -> void:
	original_visual_transform = visual.transform
	# Recline against the couch: hips project ahead of the chest so the lap and
	# knees are visible while the eye remains in front of the helmet.
	visual.basis = Basis(Vector3.RIGHT, deg_to_rad(25.0)) * visual.basis
	visual.position = Vector3(0.0, -0.46, -0.32)
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if skeletons.is_empty():
		return
	skeleton = skeletons[0] as Skeleton3D
	saved_rotations.clear()
	var body_to_skeleton := (player.global_transform.affine_inverse() * skeleton.global_transform).basis.inverse()
	for side in ["L", "R"]:
		var spread := -1.0 if side == "L" else 1.0
		_aim(side + "_Thigh.", side + "_Knee.", body_to_skeleton * Vector3(spread * 0.035, -0.08, -0.47))
		_aim(side + "_Knee.", side + "_Ankle.", body_to_skeleton * Vector3(spread * 0.02, -0.40, 0.06))
		_aim(side + "_Arm.", side + "_Elbow.", body_to_skeleton * Vector3(-spread * 0.10, -0.32, -0.08))
		_aim(side + "_Elbow.", side + "_Wrist.", body_to_skeleton * Vector3(-spread * 0.02, -0.04, -0.40))

func apply_on_ground(visual: Node3D, player: Node3D, ground_height: Callable) -> void:
	apply(visual,player)
	if not is_instance_valid(skeleton): return
	# Ground sitting has extended legs, not the dangling shins of a couch pose.
	visual.basis = Basis(Vector3.RIGHT,deg_to_rad(10.0)) * original_visual_transform.basis
	visual.position = Vector3.ZERO
	var body_to_skeleton := (player.global_transform.affine_inverse()*skeleton.global_transform).basis.inverse()
	for side in ["L","R"]:
		var spread := -1.0 if side == "L" else 1.0
		_aim(side+"_Thigh.",side+"_Knee.",body_to_skeleton*Vector3(spread*0.09,-0.03,-0.47))
		_aim(side+"_Knee.",side+"_Ankle.",body_to_skeleton*Vector3(spread*0.04,-0.03,-0.40))
	skeleton.force_update_all_bone_transforms()
	# Fit the posed suit, including its boots, to the terrain beneath each vertex.
	# Move only the visual; the standing/escort physics origin stays on the floor.
	var lift := -INF
	for p in posed_vertices(visual):
		lift = maxf(lift,float(ground_height.call(p))+0.025-p.y)
	if is_finite(lift): visual.global_position.y += lift

func posed_vertices(visual: Node3D) -> PackedVector3Array:
	var points := PackedVector3Array()
	for node: MeshInstance3D in visual.find_children("*","MeshInstance3D",true,false):
		if node.skin == null: continue
		# Evaluate the current bones directly, including in headless builds and
		# before the renderer has uploaded this frame's skeleton transforms.
		var bones: Array[Transform3D] = []
		for bind in range(node.skin.get_bind_count()):
			var bone := skeleton.find_bone(node.skin.get_bind_name(bind))
			if bone < 0: bone = node.skin.get_bind_bone(bind)
			bones.append(skeleton.get_bone_global_pose(bone)*node.skin.get_bind_pose(bind))
		for surface in range(node.mesh.get_surface_count()):
			var arrays := node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_BONES]
			var weights: PackedFloat32Array = arrays[Mesh.ARRAY_WEIGHTS]
			var count: int = weights.size()/vertices.size()
			for i in range(vertices.size()):
				var vertex := vertices[i]
				for j in range(count):
					var k := i*count+j
					if weights[k] > 0:
						vertex += (bones[indices[k]]*vertices[i]-vertices[i])*weights[k]
				points.append(node.global_transform*vertex)
	return points

func restore(visual: Node3D) -> void:
	visual.transform = original_visual_transform
	if is_instance_valid(skeleton):
		for bone in saved_rotations:
			skeleton.set_bone_pose_rotation(bone, saved_rotations[bone])
		skeleton.force_update_all_bone_transforms()
	saved_rotations.clear()

func _bone(prefix: String) -> int:
	for index in range(skeleton.get_bone_count()):
		if str(skeleton.get_bone_name(index)).begins_with(prefix):
			return index
	return -1

func _aim(prefix: String, child_prefix: String, target: Vector3) -> void:
	var bone := _bone(prefix)
	var child := _bone(child_prefix)
	if bone < 0 or child < 0:
		return
	skeleton.force_update_all_bone_transforms()
	if not saved_rotations.has(bone): saved_rotations[bone] = skeleton.get_bone_pose_rotation(bone)
	var pose := skeleton.get_bone_global_pose(bone)
	var direction := skeleton.get_bone_global_pose(child).origin - pose.origin
	var turn := Basis(Quaternion(direction.normalized(), target.normalized()))
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone))
	var local_basis := parent.basis.inverse() * turn * pose.basis
	skeleton.set_bone_pose_rotation(bone, local_basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

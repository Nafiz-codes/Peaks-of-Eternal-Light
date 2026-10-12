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
	saved_rotations[bone] = skeleton.get_bone_pose_rotation(bone)
	var pose := skeleton.get_bone_global_pose(bone)
	var direction := skeleton.get_bone_global_pose(child).origin - pose.origin
	var turn := Basis(Quaternion(direction.normalized(), target.normalized()))
	var parent := skeleton.get_bone_global_pose(skeleton.get_bone_parent(bone))
	var local_basis := parent.basis.inverse() * turn * pose.basis
	skeleton.set_bone_pose_rotation(bone, local_basis.orthonormalized().get_rotation_quaternion())
	skeleton.force_update_all_bone_transforms()

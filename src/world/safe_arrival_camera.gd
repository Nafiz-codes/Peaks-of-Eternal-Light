extends RefCounted
## Preflight a short spherical arc, including swept camera volume between samples.
const CAMERA_RADIUS := 0.3
var center := Vector3.ZERO
var body_radius := 1.5
var destination := Transform3D.IDENTITY
var start_offset := Vector3.ZERO
var end_offset := Vector3.ZERO
var stationary := false

func configure(player: Node3D, target: Transform3D) -> bool:
	destination = target
	var bounds := AABB(player.global_position, Vector3(0, 1.7, 0))
	for mesh in player.get_node("AnimatedAstronaut").find_children("*", "MeshInstance3D", true, false):
		bounds = bounds.merge(mesh.global_transform * mesh.get_aabb())
	center = bounds.get_center()
	body_radius = bounds.size.length() * 0.5 + CAMERA_RADIUS
	end_offset = destination.origin - center
	if end_offset.length() <= body_radius: return false
	var space := player.get_world_3d().direct_space_state
	for angle in [0.3, -0.3, 0.0]:
		stationary = is_zero_approx(angle)
		start_offset = end_offset if stationary else end_offset.rotated(Vector3.UP, angle) + Vector3.UP * 0.7
		if _clear_path(space): return true
	return false

func pose(progress: float) -> Transform3D:
	if stationary: return destination
	var t := smoothstep(0.0, 1.0, progress)
	var direction := start_offset.normalized().slerp(end_offset.normalized(), t)
	var position := center + direction * lerpf(start_offset.length(), end_offset.length(), t)
	var facing := Basis.looking_at(center - position, Vector3.UP)
	return Transform3D(facing.slerp(destination.basis, t).orthonormalized(), position)

func _clear_path(space: PhysicsDirectSpaceState3D) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = CAMERA_RADIUS
	query.shape = sphere
	query.collision_mask = 1
	var previous := pose(0.0).origin
	for index in range(65):
		var point := pose(float(index) / 64.0).origin
		if point.distance_to(center) <= body_radius: return false
		query.transform = Transform3D(Basis.IDENTITY, point)
		query.motion = Vector3.ZERO
		if not space.intersect_shape(query, 1).is_empty(): return false
		query.transform.origin = previous
		query.motion = point - previous
		if space.cast_motion(query)[0] < 1.0: return false
		previous = point
	return true

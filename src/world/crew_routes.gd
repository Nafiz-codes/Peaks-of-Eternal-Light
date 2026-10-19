extends RefCounted
## Local surveyed-pad fallback: capsule sweeps and floor checks, never global GPS.
var world: Node3D
var excluded: Array[RID] = []
var radius := 14.0

func _init(scene: Node3D, survey_radius: float) -> void:
	world = scene
	radius = survey_radius
	for id in ["power_console", "water_recycler", "food_storage", "crew_briefing"]:
		excluded.append(world.get_node("Outpost/" + id + "/CrewBody").get_rid())
	excluded.append(world.get_node("Outpost/Astronaut").get_rid())

func ground(point: Vector3) -> Dictionary:
	if Vector2(point.x, point.z).length() > radius:
		return {}
	var query := PhysicsRayQueryParameters3D.create(point + Vector3(0, 4, 0), point - Vector3(0, 6, 0))
	query.exclude = excluded
	var hit := world.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or hit.normal.y < cos(deg_to_rad(25.0)):
		return {}
	# Only use the actual regolith surface, not roofs, rover decks or props.
	if not str(hit.collider.get_parent().name).contains("Regolith"):
		return {}
	return hit

func clear_segment(from: Vector3, to: Vector3) -> bool:
	if absf(to.y - from.y) > maxf(0.25, Vector2(to.x - from.x, to.z - from.z).length() * 0.45):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.6
	query.shape = capsule
	query.transform.origin = from + Vector3(0, 0.88, 0)
	query.motion = to - from
	query.exclude = excluded
	var space := world.get_world_3d().direct_space_state
	if not space.intersect_shape(query, 1).is_empty():
		return false
	var sweep := space.cast_motion(query)
	return sweep[0] >= 0.999

func route(from: Vector3, to: Vector3) -> PackedVector3Array:
	var start := ground(from)
	var end := ground(to)
	if start.is_empty() or end.is_empty():
		return PackedVector3Array()
	from = start.position
	to = end.position
	if clear_segment(from, to):
		return PackedVector3Array([to])
	var graph := AStar3D.new()
	graph.add_point(0, from)
	graph.add_point(1, to)
	for z in range(-10, 13, 2):
		for x in range(-10, 13, 2):
			var hit := ground(Vector3(x, 0, z))
			if not hit.is_empty() and clear_segment(hit.position, hit.position):
				graph.add_point(graph.get_available_point_id(), hit.position)
	var ids := graph.get_point_ids()
	for a in ids:
		for b in ids:
			if b <= a:
				continue
			var p := graph.get_point_position(a)
			var q := graph.get_point_position(b)
			if p.distance_to(q) <= 3.1 and clear_segment(p, q):
				graph.connect_points(a, b)
	var points := graph.get_point_path(0, 1)
	if not points.is_empty():
		points.remove_at(0)
	return points

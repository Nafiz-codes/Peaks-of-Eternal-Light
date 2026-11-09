extends RefCounted
## Local surveyed-pad fallback: capsule sweeps and floor checks, never global GPS.
var world: Node3D
var excluded: Array[RID] = []
var sweep_excluded: Array[RID] = []
var radius := 14.0
# Temporary preview obstacle: validate access before a new station becomes solid.
var preview_obstacle: Variant = null
var routing_crew: Array[Vector3] = []
var preview_half := Vector2(1.9, 1.9)

func _init(scene: Node3D, survey_radius: float) -> void:
	world = scene
	radius = survey_radius
	for id in ["water_recycler", "food_storage", "crew_briefing"]:
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

## Sweeps skip the regolith: rolling ground off the flat pad would otherwise block
## every straight walk. Ground and slope are already checked by ground() and the rise limit.
func _sweep_exclusions() -> Array[RID]:
	if sweep_excluded.is_empty():
		sweep_excluded = excluded.duplicate()
		var surface := world.find_child("LunarSurfaceCollision", true, false) as CollisionObject3D
		if surface != null: sweep_excluded.append(surface.get_rid())
	return sweep_excluded

func clear_segment(from: Vector3, to: Vector3) -> bool:
	for crew_position in routing_crew:
		if Geometry3D.get_closest_point_to_segment(crew_position, from, to).distance_to(crew_position) < 0.9: return false
	if preview_obstacle is Transform3D:
		var inverse: Transform3D = preview_obstacle.affine_inverse()
		var half := preview_half + Vector2(0.45, 0.45)
		var footprint := AABB(Vector3(-half.x, -1, -half.y), Vector3(half.x * 2.0, 8, half.y * 2.0))
		if footprint.intersects_segment(inverse * from, inverse * to) != null: return false
	if absf(to.y - from.y) > maxf(0.25, Vector2(to.x - from.x, to.z - from.z).length() * 0.45):
		return false
	var query := PhysicsShapeQueryParameters3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.42
	capsule.height = 1.6
	query.shape = capsule
	query.transform.origin = from + Vector3(0, 0.88, 0)
	query.motion = to - from
	query.exclude = _sweep_exclusions()
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
	var cells := {}
	for z in range(floori(minf(from.z, to.z) - 7.0), ceili(maxf(from.z, to.z) + 7.0), 2):
		for x in range(floori(minf(from.x, to.x) - 7.0), ceili(maxf(from.x, to.x) + 7.0), 2):
			var hit := ground(Vector3(x, 0, z))
			if not hit.is_empty() and clear_segment(hit.position, hit.position):
				var id := graph.get_available_point_id()
				graph.add_point(id, hit.position)
				cells[Vector2i(x, z)] = id
	# Link only grid neighbours (2 m and diagonal); all-pairs grew quadratically with distance.
	for cell in cells:
		for step in [Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2), Vector2i(2, -2)]:
			var other: Vector2i = cell + step
			if cells.has(other) and clear_segment(graph.get_point_position(cells[cell]), graph.get_point_position(cells[other])):
				graph.connect_points(cells[cell], cells[other])
	for endpoint in [0, 1]:
		var p := graph.get_point_position(endpoint)
		for cell in cells:
			var q := graph.get_point_position(cells[cell])
			if p.distance_to(q) <= 3.1 and clear_segment(p, q):
				graph.connect_points(endpoint, cells[cell])
	var points := graph.get_point_path(0, 1)
	if not points.is_empty():
		points.remove_at(0)
	return points

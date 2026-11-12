extends RefCounted
## Crew walking routes on the outpost's regolith: capsule sweeps and floor checks, never global GPS.
## Walkability is remembered until the outpost layout changes (anything built, moved or removed,
## or the rover parked elsewhere), and the A* search only tests the grid edges it explores, so
## repeated, long and failing searches stay cheap instead of stalling frames.
var world: Node3D
var excluded: Array[RID] = []
var sweep_excluded: Array[RID] = []
var radius := 14.0
# Temporary preview obstacle: validate access before a new station becomes solid.
var preview_obstacle: Variant = null
var routing_crew: Array[Vector3] = []
var preview_half := Vector2(1.9, 1.9)

const GRID := 2 # Metres between route grid cells.
const SAMPLE_SPACING := 0.5 # Floor samples along a segment.
const SEARCH_MARGIN := 15.0 # Room around the endpoints to walk round obstacles.
const LINK_RADIUS := 4.5 # Endpoints join cells this far away (reaches past hemmed-in cells).
const MAX_EXPANSIONS := 1200 # A route that needs more is treated as unreachable.
const CACHE_LIMIT := 40000

var _session: Node
var _layout := 0
var _ground_cache: Dictionary = {} # 5 cm cell -> ground hit ({} = none)
var _standing_cache: Dictionary = {} # 5 cm cell -> [ground position or null, free to stand]
var _segment_cache: Dictionary = {} # [from, to] at 5 cm -> static walkability
var _failed: Dictionary = {} # [from, to] at 1 m -> true: no route in this layout
var _capsule := CapsuleShape3D.new()

func _init(scene: Node3D, survey_radius: float) -> void:
	world = scene
	radius = survey_radius
	for id in ["water_recycler", "food_storage", "crew_briefing"]:
		excluded.append(world.get_node("Outpost/" + id + "/CrewBody").get_rid())
	excluded.append(world.get_node("Outpost/Astronaut").get_rid())
	_capsule.radius = 0.42
	_capsule.height = 1.6
	_session = scene.get_node_or_null("/root/MissionSession")

## Remembered walkability holds for one outpost layout; anything placed, moved or removed
## (or the rover parked elsewhere) starts afresh.
func refresh_layout() -> void:
	var key := 0
	if _session != null:
		key = hash([_session.solar_placement, _session.extra_panels, _session.station_placements, _session.building_placements, _session.get("extra_buildings")])
	var rover := world.get_node_or_null("RoverHull") as Node3D
	if rover != null: key = hash([key, Vector3i((rover.global_position / 2.0).floor())])
	key = hash([key, radius])
	if key != _layout or _segment_cache.size() > CACHE_LIMIT:
		_layout = key
		_ground_cache.clear()
		_standing_cache.clear()
		_segment_cache.clear()
		_failed.clear()

static func _cell_key(point: Vector3) -> Vector2i:
	return Vector2i(roundi(point.x * 20.0), roundi(point.z * 20.0))

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

func _ground_cached(point: Vector3) -> Dictionary:
	var key := _cell_key(point)
	if not _ground_cache.has(key): _ground_cache[key] = ground(point)
	return _ground_cache[key]

## Sweeps skip the regolith: rolling ground off the flat pad would otherwise block
## every straight walk. Ground and slope are already checked by ground() and the rise limit.
func _sweep_exclusions() -> Array[RID]:
	if sweep_excluded.is_empty():
		sweep_excluded = excluded.duplicate()
		var surface := world.find_child("LunarSurfaceCollision", true, false) as CollisionObject3D
		if surface != null: sweep_excluded.append(surface.get_rid())
	return sweep_excluded

func _capsule_query() -> PhysicsShapeQueryParameters3D:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = _capsule
	query.exclude = _sweep_exclusions()
	return query

## True when someone standing at `point` would be inside a structure, prop or vehicle.
func overlaps_structure(point: Vector3) -> bool:
	var query := _capsule_query()
	query.transform.origin = point + Vector3(0, 0.88, 0)
	return not world.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()

## [ground position or null, free to stand there] for a point, remembered per layout.
## Call refresh_layout() first in each new search or grid pass.
func standing(point: Vector3) -> Array:
	var key := _cell_key(point)
	if not _standing_cache.has(key):
		var hit := _ground_cached(point)
		if hit.is_empty(): _standing_cache[key] = [null, false]
		else: _standing_cache[key] = [hit.position, not overlaps_structure(hit.position)]
	return _standing_cache[key]

## Crew and preview obstacles change between searches, so they are never remembered.
func _dynamic_clear(from: Vector3, to: Vector3) -> bool:
	for crew_position in routing_crew:
		if Geometry3D.get_closest_point_to_segment(crew_position, from, to).distance_to(crew_position) < 0.9: return false
	if preview_obstacle is Transform3D:
		var inverse: Transform3D = preview_obstacle.affine_inverse()
		var half := preview_half + Vector2(0.45, 0.45)
		var footprint := AABB(Vector3(-half.x, -1, -half.y), Vector3(half.x * 2.0, 8, half.y * 2.0))
		if footprint.intersects_segment(inverse * from, inverse * to) != null: return false
	return true

## Floor, slope and capsule checks along a segment (no crew or previews).
func _static_clear(from: Vector3, to: Vector3, use_cache: bool) -> bool:
	var key: Array = []
	if use_cache:
		var a := Vector3i((from * 20.0).round())
		var b := Vector3i((to * 20.0).round())
		key = [a, b] if a < b else [b, a]
		if _segment_cache.has(key): return _segment_cache[key]
	var result := _static_clear_now(from, to, use_cache)
	if use_cache: _segment_cache[key] = result
	return result

func _static_clear_now(from: Vector3, to: Vector3, use_cache: bool) -> bool:
	# Check the terrain between waypoints as well as their endpoints.
	var steps := maxi(1, ceili(from.distance_to(to) / SAMPLE_SPACING))
	var previous := from
	var first := Vector3.ZERO
	var last := Vector3.ZERO
	for index in range(steps + 1):
		var point := from.lerp(to, float(index) / steps)
		var hit := _ground_cached(point) if use_cache else ground(point)
		if hit.is_empty(): return false
		var current: Vector3 = hit.position
		var horizontal := Vector2(current.x - previous.x, current.z - previous.z).length()
		if absf(current.y - previous.y) > maxf(0.12, horizontal * tan(deg_to_rad(25.0))): return false
		if index == 0: first = current
		last = current
		previous = current
	if absf(to.y - from.y) > maxf(0.25, Vector2(to.x - from.x, to.z - from.z).length() * 0.45):
		return false
	# One capsule overlap at the start and one sweep to the end: the regolith is excluded,
	# so following the ground's small rises adds nothing but cost.
	var query := _capsule_query()
	var space := world.get_world_3d().direct_space_state
	query.transform.origin = first + Vector3(0, 0.88, 0)
	if not space.intersect_shape(query, 1).is_empty(): return false
	if last.distance_to(first) > 0.001:
		query.motion = last - first
		if space.cast_motion(query)[0] < 0.999: return false
	return true

## Walkable straight segment. `cached` is for route searches (fixed grid points); per-frame
## movement checks pass false, since their tiny steps would only fill the memory.
func clear_segment(from: Vector3, to: Vector3, cached := false) -> bool:
	if cached: refresh_layout()
	return _dynamic_clear(from, to) and _static_clear(from, to, cached)

## `point` if it is free to stand on, otherwise the nearest open ground within 10 m that is
## (unchanged when nothing nearby is free). Used for spawns: loading and leaving the habitat.
func free_spot(point: Vector3) -> Vector3:
	if not overlaps_structure(point): return point
	for distance in [0.8, 1.6, 2.4, 3.2, 4.0, 5.0, 6.5, 8.0, 10.0]:
		for step in 12:
			var hit := ground(point + Vector3(distance, 0, 0).rotated(Vector3.UP, TAU * step / 12.0))
			if not hit.is_empty() and not overlaps_structure(hit.position): return hit.position
	return point

## Open regolith near `point` (within 6 m) when the point itself stands on a prop or
## equipment deck, so crew parked there can still step off and route. {} when none.
func open_ground_near(point: Vector3) -> Dictionary:
	refresh_layout()
	for distance in [0.0, 0.8, 1.6, 2.4, 3.2, 4.0, 5.0, 6.0]:
		for step in (1 if distance == 0.0 else 8):
			var offset := Vector3(distance, 0, 0).rotated(Vector3.UP, TAU * step / 8.0)
			var spot := standing(point + offset)
			if spot[1] and _dynamic_clear(spot[0], spot[0]):
				return {"position": spot[0]}
	return {}

## `near_end`: a destination on equipment (a default post by the lander) ends at the
## nearest open ground instead of failing. Station docks never use it: they must be reachable.
func route(from: Vector3, to: Vector3, near_end := false) -> PackedVector3Array:
	refresh_layout()
	var start := ground(from)
	# Standing on equipment (e.g. beside the lander): first step onto open ground.
	var stepped_off := start.is_empty() or not clear_segment(start.position, start.position, true)
	if stepped_off: start = open_ground_near(from)
	var end := ground(to)
	if near_end and (end.is_empty() or not clear_segment(end.position, end.position, true)): end = open_ground_near(to)
	if start.is_empty() or end.is_empty():
		return PackedVector3Array()
	var path := _route(start.position, end.position)
	if stepped_off and not path.is_empty(): path.insert(0, start.position)
	return path

## The route grid cell's standing point (null when it is not walkable).
func _cell(cell: Vector2i) -> Variant:
	var spot := standing(Vector3(cell.x, 0, cell.y))
	return spot[0] if spot[1] else null

func _route(from: Vector3, to: Vector3) -> PackedVector3Array:
	if clear_segment(from, to, true):
		return PackedVector3Array([to])
	# Crew stuck without a route retry every second or so: answer those repeats at once.
	# Only searches without crew or preview obstacles are remembered (those change).
	var memo_key: Array = [Vector3i(from.round()), Vector3i(to.round())]
	var memorable := routing_crew.is_empty() and preview_obstacle == null
	if memorable and _failed.has(memo_key): return PackedVector3Array()
	var path := _search(from, to)
	if path.is_empty() and memorable: _failed[memo_key] = true
	return path

func _search(from: Vector3, to: Vector3) -> PackedVector3Array:
	var lo := Vector2(minf(from.x, to.x), minf(from.z, to.z)) - Vector2.ONE * SEARCH_MARGIN
	var hi := Vector2(maxf(from.x, to.x), maxf(from.z, to.z)) + Vector2.ONE * SEARCH_MARGIN
	var start_key := Vector2i(1 << 30, 0)
	var goal_key := Vector2i(1 << 30, 1)
	var positions := {start_key: from, goal_key: to}
	var cost := {start_key: 0.0}
	var parent := {}
	var closed := {}
	var heap_keys: Array = []
	var heap_costs: Array[float] = []
	_heap_push(heap_keys, heap_costs, start_key, from.distance_to(to))
	var expansions := 0
	while not heap_keys.is_empty():
		var key: Vector2i = _heap_pop(heap_keys, heap_costs)
		if key == goal_key:
			var points := PackedVector3Array()
			while key != start_key:
				points.insert(0, positions[key])
				key = parent[key]
			return points
		if closed.has(key): continue
		closed[key] = true
		expansions += 1
		if expansions > MAX_EXPANSIONS: break
		var here: Vector3 = positions[key]
		var candidates: Array[Vector2i] = []
		if key == start_key:
			# The start joins every grid cell within reach, not just the nearest corner.
			var reach := ceili(LINK_RADIUS / GRID)
			var base := Vector2i(floori(from.x / GRID) * GRID, floori(from.z / GRID) * GRID)
			for dz in range(-reach, reach + 2):
				for dx in range(-reach, reach + 2):
					candidates.append(base + Vector2i(dx, dz) * GRID)
		else:
			for step in [Vector2i(GRID, 0), Vector2i(-GRID, 0), Vector2i(0, GRID), Vector2i(0, -GRID), Vector2i(GRID, GRID), Vector2i(GRID, -GRID), Vector2i(-GRID, GRID), Vector2i(-GRID, -GRID)]:
				candidates.append(key + step)
		if here.distance_to(to) <= LINK_RADIUS: candidates.append(goal_key)
		for next in candidates:
			if closed.has(next): continue
			var there: Vector3
			if next == goal_key:
				there = to
			else:
				if next.x < lo.x or next.x > hi.x or next.y < lo.y or next.y > hi.y: continue
				var spot: Variant = _cell(next)
				if spot == null: continue
				there = spot
				if key == start_key and here.distance_to(there) > LINK_RADIUS: continue
			var total: float = cost[key] + here.distance_to(there)
			if total >= float(cost.get(next, INF)): continue
			if not clear_segment(here, there, true): continue
			cost[next] = total
			parent[next] = key
			positions[next] = there
			_heap_push(heap_keys, heap_costs, next, total + there.distance_to(to))
	return PackedVector3Array()

static func _heap_push(keys: Array, costs: Array[float], key: Vector2i, priority: float) -> void:
	keys.append(key)
	costs.append(priority)
	var index := keys.size() - 1
	while index > 0:
		var up := (index - 1) >> 1
		if costs[up] <= costs[index]: break
		var swap_key: Variant = keys[up]
		keys[up] = keys[index]
		keys[index] = swap_key
		var swap_cost := costs[up]
		costs[up] = costs[index]
		costs[index] = swap_cost
		index = up

static func _heap_pop(keys: Array, costs: Array[float]) -> Variant:
	var top: Variant = keys[0]
	var last_key: Variant = keys.pop_back()
	var last_cost: float = costs.pop_back()
	if keys.is_empty(): return top
	keys[0] = last_key
	costs[0] = last_cost
	var index := 0
	while true:
		var smallest := index
		for child in [index * 2 + 1, index * 2 + 2]:
			if child < keys.size() and costs[child] < costs[smallest]: smallest = child
		if smallest == index: break
		var swap_key: Variant = keys[smallest]
		keys[smallest] = keys[index]
		keys[index] = swap_key
		var swap_cost := costs[smallest]
		costs[smallest] = costs[index]
		costs[index] = swap_cost
		index = smallest
	return top

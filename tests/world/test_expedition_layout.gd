extends SceneTree
const Terrain = preload("res://src/world/expedition_terrain.gd")
var failures := 0

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func _init() -> void:
	for ridge in Terrain.RIDGES:
		check(is_zero_approx(Terrain.added_relief(Vector2(ridge.x,ridge.y),ridge.z)), "Existing ridge remains unchanged")
	check(Terrain.height_at(-80,-190) > 8, "Open western plain has new relief")
	check(Terrain.height_at(55,-300) > 10, "Open southern plain has new relief")
	for id in ["alpha","beta","gamma"]:
		for ice in ["ice_a","ice_b","ice_c"]:
			check(Terrain.SITES[id].distance_to(Terrain.SITES[ice]) > 350, "Geology and ice require exploring different sectors")
		check(Terrain.SITES[id].distance_to(Terrain.RESCUE_SITE) > 350, "Rescue explores a separate sector")
	# Flood-fill drivable slopes at eight-metre spacing, with margin below the
	# rover's 32-degree limit. This catches objectives isolated by new relief.
	var heights := {}
	for z in range(-50,51):
		for x in range(-50,51):
			var cell := Vector2i(x,z)
			heights[cell] = Terrain.surface_height(Vector2(cell)*8)
	var reached := {Vector2i.ZERO: true}
	var queue: Array[Vector2i] = [Vector2i.ZERO]
	var cursor := 0
	while cursor < queue.size():
		var cell := queue[cursor]
		cursor += 1
		for offset in [Vector2i.LEFT,Vector2i.RIGHT,Vector2i.UP,Vector2i.DOWN]:
			var next: Vector2i = cell+offset
			if reached.has(next) or not heights.has(next): continue
			if absf(heights[next]-heights[cell]) > 4.0: continue
			reached[next] = true
			queue.append(next)
	for site in Terrain.SITES.values()+[Terrain.RESCUE_SITE]:
		check(reached.has(Vector2i((site/8).round())), "Objective reachable through drivable terrain: " + str(site))
	var previous := Terrain.point(Vector2.ZERO)
	for i in range(1,101):
		var p := Terrain.RESCUE_SITE * (float(i)/100)
		var current := Terrain.point(p)
		check(absf(current.y-previous.y) < p.distance_to(Vector2(previous.x-Terrain.ORIGIN.x,previous.z))*0.5, "Rescue corridor is walkable")
		check(Terrain.obstacle_clearance(p), "Rescue corridor excludes scattered rocks")
		previous = current
	print("EXPEDITION LAYOUT: %d failures" % failures)
	quit(1 if failures else 0)

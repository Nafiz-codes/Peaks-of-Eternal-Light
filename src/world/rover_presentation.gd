extends Node

## Handoff component: callers supply a confirmed presentation route in local metres.
## No current gameplay API emits this route. Never derive travel from button clicks.
var motion: Tween
var last_action_id := ""
var seen_action_ids: Dictionary = {}
var destination := Vector3.ZERO
var destination_heading := 0.0

func play_confirmed_route(rover: Node3D, hull: Node3D, result: Dictionary, reduce_motion: bool) -> bool:
	var id := str(result.get("action_id", ""))
	var route: Variant = result.get("presentation_route", [])
	if result.get("ok", false) != true or id.is_empty() or seen_action_ids.has(id) or not route is Array or route.size() < 2:
		return false
	for point in route:
		if not point is Vector3 or not point.is_finite():
			return false
	last_action_id = id
	seen_action_ids[id] = true
	if motion != null:
		motion.kill()
	destination = route[-1]
	destination_heading = rover.rotation.y
	for index in range(1, route.size()):
		var delta: Vector3 = route[index] - route[index - 1]
		if not Vector2(delta.x, delta.z).is_zero_approx():
			destination_heading = atan2(delta.x, delta.z)
	rover.position = route[0]
	hull.position = rover.position + Vector3(0, 0.65, 0)
	if reduce_motion:
		finish_immediately(rover, hull)
		return true
	motion = create_tween()
	for index in range(1, route.size()):
		var start: Vector3 = route[index - 1]
		var end: Vector3 = route[index]
		motion.tween_method(func(weight: float):
			rover.position = start.lerp(end, weight)
			hull.position = rover.position + Vector3(0, 0.65, 0)
			if not start.is_equal_approx(end):
				rover.rotation.y = atan2(end.x - start.x, end.z - start.z), 0.0, 1.0, 0.65)
	return true

func finish_immediately(rover: Node3D, hull: Node3D) -> void:
	if motion != null:
		motion.kill()
	if not last_action_id.is_empty():
		rover.position = destination
		rover.rotation.y = destination_heading
		hull.position = destination + Vector3(0, 0.65, 0)

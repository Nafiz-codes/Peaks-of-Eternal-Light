extends RefCounted
var progress := 0.0
var target_id := ""
var feedback := ""
var duration := 3.0
var max_range := 6.5
var max_speed := 0.12

func reset() -> void:
	progress = 0.0
	target_id = ""

func validate(driver: Node3D, target: Area3D, require_aim: bool = true) -> String:
	if not driver.active or driver.power_state != driver.Power.READY: return "Remote connection not ready"
	if absf(driver.speed) > max_speed: return "Brake to scan / operate tools"
	var origin := driver.global_position + Vector3.UP * 1.15
	var offset: Vector3 = target.aim_point() - origin
	if offset.length() > max_range: return "Approach within %.1f m" % max_range
	if target.target_id == "astronaut" and Vector2(offset.x, offset.z).length() < 2.5: return "Back away: keep 2.5 m safe clearance"
	if require_aim and offset.length() > 0.1:
		var forward := Vector3(sin(driver.heading), 0, cos(driver.heading))
		if forward.dot(Vector3(offset.x, 0, offset.z).normalized()) < cos(deg_to_rad(45.0)): return "Steer the rover nose toward the target"
	var ray := PhysicsRayQueryParameters3D.create(origin, target.aim_point(), 1, [driver.get_rid()])
	var hit := driver.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		var collider: Node = hit.collider
		if not target.is_ancestor_of(collider): return "Signal blocked by terrain or equipment"
	return ""

func advance(delta: float, held: bool, id: String, eligible: bool, rejection: String) -> bool:
	feedback = rejection
	if not held or not eligible or rejection != "":
		reset()
		return false
	if target_id != id:
		reset()
		target_id = id
	progress += delta
	if progress < duration: return false
	reset()
	return true

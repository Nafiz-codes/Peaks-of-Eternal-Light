extends SceneTree

var failures := 0

func _init() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func _walk(player: CharacterBody3D, direction: float, frames: int) -> void:
	for frame in range(frames):
		await physics_frame
		player._step_locomotion(1.0 / 60.0, Vector2(direction, 0.0), false)

func _run() -> void:
	var world: Node3D = load("res://scenes/lunar_outpost_3d.tscn").instantiate()
	root.add_child(world)
	await process_frame
	var player: CharacterBody3D = world.get_node("Outpost/Astronaut")
	player.set_physics_process(false)
	player.position = Vector3(5.4, 0.05, -12.0)
	await _walk(player, -1.0, 480)
	check(player.position.y > 2.8 and player.position.y < 3.1, "Walking reaches the upper stair landing without jumping.")
	check(player.position.x > 1.1 and player.position.x < 2.1, "The closed lander entrance still blocks the astronaut.")
	check(player.is_on_floor(), "The astronaut stands on the upper landing.")
	await _walk(player, 1.0, 300)
	check(player.position.x > 5.0 and player.position.y < 0.15, "Walking back down reaches the ground.")
	print("Lander stairs tests: %d failures. Final position: %s" % [failures, player.position])
	world.queue_free()
	await process_frame
	quit(1 if failures else 0)

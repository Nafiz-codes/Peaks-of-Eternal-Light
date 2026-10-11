extends SceneTree
const Player = preload("res://src/world/lunar_astronaut.gd")
var failures := 0
func _init():
	call_deferred("run")
func check(ok: bool, message: String):
	if not ok:
		failures += 1
		push_error(message)
func run():
	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	floor_shape.shape = BoxShape3D.new()
	floor_shape.shape.size = Vector3(100, 1, 100)
	floor_body.position.y = -0.5
	floor_body.add_child(floor_shape)
	root.add_child(floor_body)
	var player := Player.new()
	var collider := CollisionShape3D.new()
	collider.shape = CapsuleShape3D.new()
	collider.shape.radius = 0.3
	collider.shape.height = 1.7
	collider.position.y = 0.85
	player.add_child(collider)
	root.add_child(player)
	player.set_physics_process(false)
	await physics_frame
	for hz in [30, 60, 120]:
		Engine.physics_ticks_per_second = hz
		await physics_frame
		var dt: float = 1.0 / hz
		player.position = Vector3(0, 0.01, 0)
		player.velocity = Vector3.ZERO
		for i in range(10):
			await physics_frame
			player._step_locomotion(dt, Vector2.ZERO, false)
		check(player.is_on_floor(), "Settles on ground")
		await physics_frame
		player._step_locomotion(dt, Vector2(0, -1), false)
		check(-player.velocity.z > 0 and -player.velocity.z < 0.1, "Ground movement accelerates gradually")
		for i in range(hz * 2):
			await physics_frame
			player._step_locomotion(dt, Vector2(0, -1), false)
		check(abs(player.velocity.z + 1.6) < 0.001, "Walking speed is bounded")
		var start_y := player.position.y
		await physics_frame
		player._step_locomotion(dt, Vector2(0, -1), true)
		var takeoff_z := player.velocity.z
		var apex := player.position.y - start_y
		var ticks := 1
		while not player.is_on_floor() and ticks < hz * 4:
			await physics_frame
			player._step_locomotion(dt, Vector2(1, 1), true)
			apex = maxf(apex, player.position.y - start_y)
			check(abs(player.velocity.z - takeoff_z) < 0.001 and abs(player.velocity.x) < 0.001, "Air input cannot change momentum or double jump")
			ticks += 1
		check(abs(apex - 0.605) < 0.025, "Measured jump apex matches lunar ballistics")
		check(abs(ticks * dt - 1.728) < 0.06, "Measured airtime matches lunar ballistics")
		await physics_frame
		player._step_locomotion(dt, Vector2.ZERO, false)
		check(player.velocity.z < -1.4, "Landing does not stop momentum instantly")
		for i in range(hz * 2):
			await physics_frame
			player._step_locomotion(dt, Vector2.ZERO, false)
		check(abs(player.velocity.z) < 0.001, "Ground braking stops the astronaut")
		for i in range(hz * 3):
			await physics_frame
			player._step_locomotion(dt, Vector2(1, -1), false, true)
		check(abs(Vector2(player.velocity.x, player.velocity.z).length() - 3.0) < 0.001, "Forward diagonal sprint reaches 3 m/s without a diagonal boost")
		for i in range(hz * 2):
			await physics_frame
			player._step_locomotion(dt, Vector2(1, -1), false, false)
		check(abs(Vector2(player.velocity.x, player.velocity.z).length() - 1.6) < 0.001, "Releasing sprint returns to walking speed")
	player.position = Vector3(0, 10, 0)
	player.velocity = Vector3(1, 0, 0)
	player._step_locomotion(0.01, Vector2.ZERO, false)
	player.velocity = Vector3(1, 0, 0)
	player.ui_blocked = true
	Engine.physics_ticks_per_second = 60
	var before := player.position.y
	for i in range(60):
		await physics_frame
		player._physics_process(1.0 / 60.0)
	check(player.position.y < before - 0.7, "Opening UI does not suspend gravity")
	check(abs(player.velocity.x - 1.0) < 0.001, "Opening UI preserves airborne momentum")
	print("Lunar locomotion tests: %d failures." % failures)
	quit(1 if failures else 0)


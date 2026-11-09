extends SceneTree
## Clicking an outpost name before the startup handoff must not strand navigation.
var failures := 0

func _init() -> void:
	call_deferred("run")

func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)

func run() -> void:
	var holder := Node.new()
	root.add_child(holder)
	var world = load("res://scenes/lunar_landing_selector.tscn").instantiate()
	holder.add_child(world)
	world.menu_layer.hide()
	var planetary = world.enable_cinematic_navigation()
	planetary.begin_entrance()
	for i in range(600):
		if planetary.mode == planetary.Mode.OVERVIEW: break
		await process_frame
	check(planetary.mode == planetary.Mode.OVERVIEW, "Overview is reached.")
	planetary.enter_moon(str(world.site_records[0].site_id))
	await create_timer(0.3).timeout
	# Same move the startup scene makes when it hands the globe over.
	world.reparent(root)
	await create_timer(2.5).timeout
	check(planetary.mode != planetary.Mode.APPROACH, "Approach continues after the globe is reparented.")
	print("NAVIGATION HANDOFF TEST: %d failures" % failures)
	quit(failures)

extends SceneTree
const Dialogue = preload("res://src/ui/opening_dialogue.gd")
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func card(world: Node) -> Node:
	for child in world.get_children():
		if child.get_script() == Dialogue and not child.is_queued_for_deletion(): return child
	return null
func run() -> void:
	var session := root.get_node("MissionSession")
	session.confirm_new_commander("commander-02", "Alex")
	var selector := preload("res://scenes/lunar_landing_selector.tscn").instantiate()
	root.add_child(selector)
	current_scene = selector
	await process_frame
	check(card(selector).sequence == "landing_site", "Selector opens crew discussion")
	for i in 6: card(selector).advance()
	await process_frame
	selector.select_site("ridge_a")
	await scene_changed
	await create_timer(3.0).timeout
	var world := current_scene
	check(card(world) != null and card(world).sequence == "touchdown", "Arrival opens touchdown cards")
	var touchdown := card(world)
	for i in 4: touchdown.advance()
	await touchdown.finished
	await create_timer(0.9).timeout
	check(card(world).sequence == "invitation", "Invitation follows touchdown")
	card(world).advance()
	await process_frame
	check(not session.maya_intro_complete, "Invitation does not open briefing automatically")
	var player := world.get_node("Outpost/Astronaut")
	player.global_position = world.get_node("Outpost/crew_briefing").global_position + Vector3(1, 0, 0)
	world._on_player_interaction("crew_briefing")
	check(card(world).sequence == "solar", "Interaction opens solar briefing")
	for i in 4: card(world).advance()
	check(session.maya_intro_complete and world.get_node("SolarPlacement").active, "Briefing hands off to existing panel placement")
	check(not paused and not player.ui_blocked, "Gameplay control restored")
	world.queue_free()
	await process_frame
	print("Opening flow failures: ", failures)
	quit(failures)

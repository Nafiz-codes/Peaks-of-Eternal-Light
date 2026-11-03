extends SceneTree
const Dialogue = preload("res://src/ui/opening_dialogue.gd")
var failures := 0
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func run() -> void:
	var session := root.get_node("MissionSession")
	session.confirm_new_commander("commander-03", "আরহাম")
	check(Dialogue.npc_frame("CREW_04", "Relieved smile").frame_index == 0, "Subtle cue uses baseline")
	check(Dialogue.npc_frame("CREW_02", "Focused").frame_index == 4, "Maya uses reviewed focus")
	check(Dialogue.npc_frame("CREW_03", "Thoughtful").frame_index == 0, "Alex thoughtful stays baseline")
	for key in Dialogue.SEQUENCES:
		var overlay := Dialogue.new()
		overlay.sequence = key
		root.add_child(overlay)
		check(paused, "Dialogue pauses underlying controls")
		check(not overlay.commander.visible and overlay.npc.visible, "Only speaking NPC appears")
		overlay.show_speaker("CREW_01")
		check(overlay.commander.visible and not overlay.npc.visible and is_equal_approx(overlay.panel.anchor_left, 0.03), "Commander speech uses left layout")
		check(overlay.commander.anchor_top == overlay.npc.anchor_top and overlay.commander.anchor_bottom == overlay.npc.anchor_bottom, "Speakers share the same height")
		overlay._show_card()
		check(overlay.commander.texture.atlas.resource_path.contains("commander-03"), "Selected Commander persists")
		if key == "landing_site":
			check(overlay.dialogue.text.begins_with("Commander আরহাম,"), "Player name substituted")
		for i in Dialogue.SEQUENCES[key].size() - 1: overlay.advance()
		if key == "landing_site" and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/opening-dialogue.png")
			root.size = Vector2i(960, 640)
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://.tools/opening-dialogue-compact.png")
			root.size = Vector2i(1360, 820)
		overlay.advance()
		if key == "touchdown":
			check(paused, "Touchdown holds final card for a short pause")
			await overlay.finished
		check(not paused, "Sequence restores control")
		await process_frame
	print("Opening dialogue failures: ", failures)
	quit(failures)

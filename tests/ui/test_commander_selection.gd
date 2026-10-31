extends SceneTree
const Identity = preload("res://src/runtime/commander_identity.gd")
const Save = preload("res://src/runtime/mission_save.gd")
var failures := 0
var screen: Control
func _init() -> void: call_deferred("run")
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)
func capture(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/commander-" + label + ".png")
func run() -> void:
	var session := root.get_node("MissionSession")
	root.size = Vector2i(1360, 820)
	screen = preload("res://src/ui/commander_selection.gd").new()
	root.add_child(screen)
	await process_frame
	await process_frame
	check(screen.cards.size() == 4, "Exactly four Commander options")
	check(screen.selected_id.is_empty() and screen.confirm_button.disabled, "Explicit selection and name required")
	check(Identity.create("default", "Maya").is_empty(), "NPC appearance cannot be selected")
	check(not Identity.name_error("   ").is_empty(), "Whitespace name rejected")
	check(not Identity.name_error("A".repeat(33)).is_empty(), "Name length validated independently of UI")
	check(not Identity.name_error("A\nB").is_empty(), "Control characters rejected")
	screen.name_input.text = "  আরহাম Chen  "
	screen.name_input.text_changed.emit(screen.name_input.text)
	check(screen.confirm_button.disabled, "Name alone does not enable confirmation")
	for option in Identity.options():
		screen.select_appearance(option.variant_id)
		check(screen.name_input.text == "  আরহাম Chen  ", "Switching keeps Unicode name")
		check(not screen.confirm_button.disabled, "Valid identity enables confirmation")
		var portrait := Identity.portrait(Identity.create(option.variant_id, "Name"), "surprised")
		check(portrait.variant_id == option.variant_id and portrait.frame_index == 8, "Supported expression matches chosen appearance")
		check(Identity.frame(option.variant_id, "unavailable").variant_id == option.variant_id, "Fallback stays in same appearance")
		check(Identity.frame(option.variant_id, "serious").frame_index == 0, "Ambiguous emotions use baseline until reviewed")
	check(Identity.frame("invalid", "smiling").is_empty(), "Invalid appearance never substitutes another face")
	await create_timer(0.4).timeout
	check(screen.preview.texture == screen.textures["commander-04"] and screen.preview.modulate.a == 1, "Rapid switching settles on latest artwork")
	await capture("1360")
	for dimensions in [Vector2i(1920, 1080), Vector2i(960, 720), Vector2i(800, 600)]:
		root.size = dimensions
		await process_frame
		await process_frame
		var bounds := root.get_visible_rect()
		check(bounds.encloses(screen.confirm_button.get_global_rect()) and bounds.encloses(screen.name_input.get_global_rect()), "Input and confirmation fit " + str(dimensions))
		check(screen.cards[3].get_global_rect().end.y <= screen.name_input.get_global_rect().position.y, "Cards do not overlap name entry")
		await capture(str(dimensions.x))
	var old_identity := Identity.create("commander-01", "Previous")
	session.player_character = old_identity.duplicate(true)
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	var previous_state: Variant = session.dashboard_state
	screen._back()
	check(session.player_character == old_identity and session.dashboard_state == previous_state, "Back does not change active playthrough")
	check(session.commander_draft.appearance_id == "commander-04", "Back retains only draft")
	check(session.save_slot("user://commander-test.save") == OK, "Existing playthrough saved")
	screen._confirm()
	check(session.player_character.name == "আরহাম Chen" and session.player_character.crew_id == "CREW_01", "Confirm trims name and assigns CREW_01")
	check(session.dashboard_state == null and session.selected_site_id.is_empty(), "Confirmed new game resets old in-memory mission")
	check(Save.read_file("user://commander-test.save").player_character == old_identity, "New game does not overwrite previous disk slot")
	session.select_landing_site("ridge_a")
	session.start_selected_mission()
	check(session.dashboard_state.crew_size == 4, "Selection does not create extra crew")
	var snapshot := Save.capture(session)
	check(Save.decode(snapshot).player_character == session.player_character, "Identity survives save decoding")
	check(session.save_slot("user://commander-new.save") == OK, "New identity written through real save system")
	session.player_character = {}
	check(session.load_slot("user://commander-new.save") == OK and session.player_character.appearance_id == "commander-04", "Disk load restores selected appearance")
	check(session.restart_current_sol() == OK and session.commander_name() == "আরহাম Chen", "Sol checkpoints retain identity")
	var invalid := snapshot.duplicate(true)
	invalid.player_character.appearance_id = "Maya_Chen"
	check(Save.decode(invalid).is_empty(), "Wrong-character save data rejected")
	for version in [1, 2]:
		var legacy := snapshot.duplicate(true)
		legacy.version = version
		legacy.erase("player_character")
		check(Save.restore(session, legacy) == OK and session.player_character.is_empty(), "Legacy load clears stale identity")
		check(session.commander_name() == "Commander" and session.commander_portrait().is_empty(), "Legacy fallback invents no name or face")
	screen.queue_free()
	await process_frame
	await process_frame
	print("COMMANDER SELECTION: %d failures" % failures)
	quit(failures)

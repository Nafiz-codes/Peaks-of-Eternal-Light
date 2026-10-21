extends SceneTree
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	change_scene_to_file("res://scenes/startup.tscn")
	await scene_changed
	await process_frame
	var music := root.get_node("MenuMusic")
	var player: AudioStreamPlayer = music.player
	var ambient: AudioStreamPlayer = music.ambient_player
	var settings := root.get_node("GameSettings")
	var old_values: Dictionary = settings.values.duplicate()
	var old_path: String = settings.settings_path
	settings.settings_path = "res://.tools/test_ambient_settings.cfg"
	check(is_equal_approx(settings.DEFAULTS.mission_music, 0.2), "Mission defaults to quiet 20 percent")
	check(not ambient.playing, "No mission ambience in intro")
	check(player.playing and player.stream.loop, "Music loops during intro")
	check(player.bus == "Music" and player.stream.get_length() > 1.0, "Supplied MP3 uses saved Music volume bus")
	var boot = current_scene
	boot._enter_menu()
	await create_timer(1.5).timeout
	check(player.playing, "Main menu keeps playing")
	paused = true
	await create_timer(0.2).timeout
	check(player.playing and not player.stream_paused, "Pre-mission pause does not interrupt music")
	paused = false
	while not boot.ready_for_mission: await process_frame
	boot._start_mission()
	await create_timer(3.0).timeout
	check(player.playing and not music.mission_active, "Start Mission overview keeps music")
	var nav = current_scene.navigation_controller
	nav.enter_moon()
	await create_timer(2.1).timeout
	check(player.playing, "Free Moon exploration keeps music")
	check(not ambient.playing, "No mission ambience on Moon or outpost menu")
	current_scene.select_site("ridge_a")
	await create_timer(0.8).timeout
	check(player.playing, "Landing animation retains music until mission scene")
	await create_timer(3.2).timeout
	await create_timer(music.crossfade_seconds).timeout
	check(current_scene.name == "LunarOutpost" and not player.playing, "Music stops in actual mission")
	check(ambient.playing and ambient.stream.loop, "Mission ambience starts and loops exclusively")
	settings.change("music_enabled", false)
	check(AudioServer.is_bus_mute(AudioServer.get_bus_index("Music")), "Music toggle mutes both soundtracks")
	settings.change("mission_music", 0.12)
	check(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("MissionMusic"))), 0.12), "Mission slider changes live volume")
	var saved := ConfigFile.new()
	check(saved.load(settings.settings_path) == OK and saved.get_value("settings", "music_enabled") == false and is_equal_approx(saved.get_value("settings", "mission_music"), 0.12), "Music preferences are saved")
	settings.change("music_enabled", true)
	var menu := root.get_node("GameMenu")
	menu.open_menu()
	check(not player.playing, "Mission pause menu does not restart music")
	check(ambient.playing, "Mission ambience continues in pause settings")
	menu.show_page("settings")
	check(menu.body.find_children("*", "CheckButton", true, false)[0].text == "Music enabled", "Mission settings exposes music toggle")
	menu.close_menu()
	change_scene_to_file("res://scenes/lunar_landing_selector.tscn")
	await scene_changed
	await process_frame
	check(player.playing and not music.mission_active, "Returning to selection restores music")
	check(ambient.playing, "Mission ambience overlaps during reverse crossfade")
	await create_timer(music.crossfade_seconds + 0.1).timeout
	check(not ambient.playing, "Mission ambience stops after reverse fade")
	nav = current_scene.enable_cinematic_navigation()
	nav.begin_entrance()
	await create_timer(2.8).timeout
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	root.push_input(event)
	await scene_changed
	await create_timer(1.4).timeout
	check(current_scene.scene_file_path == "res://scenes/startup.tscn" and current_scene.state == current_scene.State.MENU_IDLE, "Escape returns to start without replaying intro")
	check(player.playing and not ambient.playing, "Return retains only menu soundtrack")
	while not current_scene.ready_for_mission: await process_frame
	current_scene._settings()
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/ambient-settings.png")
	current_scene._close_dialog()
	current_scene._start_mission()
	await create_timer(3.0).timeout
	nav = current_scene.navigation_controller
	if DisplayServer.get_name() != "headless":
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://.tools/outpost-back.png")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.position = nav.back_button.get_global_rect().get_center()
		click.pressed = pressed
		root.push_input(click)
	await scene_changed
	await create_timer(1.4).timeout
	check(current_scene.state == current_scene.State.MENU_IDLE, "Back button returns to start menu")
	settings.values = old_values
	settings.settings_path = old_path
	settings.apply()
	print("MENU MUSIC TEST: %d failures" % failures)
	quit(failures)

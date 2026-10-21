extends SceneTree
var failures := 0
var assertions := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error(message)
func capture(path: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.tools/" + path + ".png")
func r_key() -> void:
	var key := InputEventKey.new()
	key.keycode = KEY_R
	key.pressed = true
	root.push_input(key)
func run() -> void:
	change_scene_to_file("res://scenes/startup.tscn")
	await scene_changed
	await process_frame
	var music := root.get_node("MenuMusic")
	var audio := root.get_node("GameAudio")
	check(music.player.playing and not music.ambient_player.playing, "Initial menu theme")
	change_scene_to_file("res://scenes/lunar_outpost_3d.tscn")
	await scene_changed
	await create_timer(0.5).timeout
	check(music.player.playing and music.ambient_player.playing, "Both players overlap at mission entry")
	check(music.blend > 0 and music.blend < 1, "Crossfade is gradual")
	check(is_equal_approx(pow(music.player.volume_linear, 2) + pow(music.ambient_player.volume_linear, 2), 1.0), "Equal-power envelope before bus attenuation")
	var world := current_scene
	var player := world.get_node("Outpost/Astronaut")
	var driver := world.get_node("RoverHull")
	var access := world.get_node("LanderAccess")
	check(not driver.start_control() and not driver.takeover.running, "Invalid exterior R cannot launch video")
	var cam := player.get_node("CameraPivot/SpringArm/ThirdPersonCamera")
	for yaw in [0.0, PI * 0.5, PI, -PI * 0.5]:
		player.camera_yaw = yaw
		player._sync_camera_rig()
		await physics_frame
		await physics_frame
		await process_frame
		var path := preload("res://src/world/safe_arrival_camera.gd").new()
		check(path.configure(player, cam.global_transform), "Safe camera path for yaw %.2f" % yaw)
		for index in range(61):
			check(path.pose(float(index) / 60).origin.distance_to(path.center) > path.body_radius, "Camera remains outside visual clearance sphere")
	player.camera_yaw = 0
	player._sync_camera_rig()
	await physics_frame
	await physics_frame
	await capture("cinematic-safe-gameplay-camera")
	await create_timer(2.6).timeout
	check(not music.player.playing and music.ambient_player.playing, "Menu stops only after fade")
	player.global_position = access.landing
	await process_frame
	access.transfer()
	await create_timer(2.1).timeout
	check(access.inside and player.seated, "Takeover begins at seated cockpit")
	var before: Vector3 = driver.position
	var starts: int = audio.startup_count
	r_key()
	check(driver.takeover.running and driver.power_state == driver.Power.STARTING, "R starts cinematic immediately")
	check(audio.startup_count == starts + 1 and is_equal_approx(audio.rover_player.stream.get_length(), 10.0), "Processed ten-second sound starts once")
	check(driver.takeover.video.volume == 0, "Video player is also muted")
	r_key()
	check(audio.startup_count == starts + 1 and driver.takeover.running, "Repeated R does not restart or exit")
	await create_timer(0.7).timeout
	driver.step_drive(0.1, 1, 1, false)
	check(driver.position == before and is_zero_approx(driver.speed), "Input cannot move rover during video")
	await capture("rover-cutscene")
	var before_video: float = driver.takeover.video.stream_position
	root.get_node("GameMenu").open_menu()
	await create_timer(0.1).timeout
	var paused_video: float = driver.takeover.video.stream_position
	await create_timer(0.4).timeout
	check(absf(driver.takeover.video.stream_position - paused_video) < 0.05, "Pause freezes video clock")
	check(audio.rover_player.stream_paused, "Pause freezes separate startup audio")
	check(driver.power_state == driver.Power.STARTING, "Pause cannot unlock controls")
	root.get_node("GameMenu").close_menu()
	await create_timer(0.4).timeout
	check(driver.takeover.video.stream_position > before_video, "Video resumes")
	check(music.duck < 1, "Mission music smoothly ducks")
	var video_done_at := -1.0
	var audio_done_at := -1.0
	var started := Time.get_ticks_msec()
	while driver.takeover.running and Time.get_ticks_msec() - started < 13000:
		await process_frame
		if driver.takeover.video_done and video_done_at < 0: video_done_at = Time.get_ticks_msec() / 1000.0
		if driver.takeover.audio_done and audio_done_at < 0: audio_done_at = Time.get_ticks_msec() / 1000.0
	check(driver.power_state == driver.Power.READY and driver.camera.current, "Both media finish before rover control")
	check(video_done_at >= 0 and audio_done_at >= 0 and absf(video_done_at - audio_done_at) < 0.15, "Media finishes within 150ms")
	print("Media completion delta: ", absf(video_done_at - audio_done_at))
	check(driver.position == before and is_zero_approx(driver.speed), "Released throttle never causes movement")
	await capture("rover-cutscene-handoff")
	await create_timer(0.9).timeout
	check(is_equal_approx(music.duck, 1.0), "Mission mix recovers")
	driver.stop_control()
	check(not player.ui_blocked and player.first_person, "Exit restores cockpit")
	r_key()
	await create_timer(0.3).timeout
	check(audio.startup_count == starts + 2, "Reentry gets a fresh takeover")
	change_scene_to_file("res://scenes/startup.tscn")
	await scene_changed
	await process_frame
	check(not audio.rover_player.playing and audio.rover_owner_id == 0, "Scene interruption cancels startup")
	check(music.player.playing and music.ambient_player.playing, "Return uses reverse crossfade")
	await create_timer(0.5).timeout
	var reverse_blend: float = music.blend
	music.transition_to(true)
	check(is_equal_approx(music.blend, reverse_blend), "Interrupted crossfade preserves current gain")
	await create_timer(0.3).timeout
	check(music.blend > reverse_blend, "Interrupted crossfade reverses smoothly")
	music.transition_to(false)
	await create_timer(2.6).timeout
	check(music.player.playing and not music.ambient_player.playing, "Reverse fade settles")
	print("CINEMATIC TRANSITIONS: %d failures / %d assertions" % [failures, assertions])
	quit(failures)

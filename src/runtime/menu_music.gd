extends Node
## Persistent equal-power crossfades; saved bus levels remain independent.
const TRACK := preload("res://Assets/audio/peaks_of_eternal_lights.mp3")
const AMBIENCE := preload("res://Assets/audio/lunar_mission_ambient.mp3")
const OUTPOST := "res://scenes/lunar_outpost_3d.tscn"
const MENUS := ["res://scenes/startup.tscn", "res://scenes/lunar_landing_selector.tscn"]
var player: AudioStreamPlayer
var ambient_player: AudioStreamPlayer
var mission_active := false
var crossfade_seconds := 2.5
var blend := 0.0
var duck := 1.0
var initialized := false
var fade_tween: Tween
var duck_tween: Tween
var menu_position := 0.0
var mission_position := 0.0
var fade_target := -1.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.name = "Soundtrack"
	var track := TRACK.duplicate() as AudioStreamMP3
	track.loop = true
	player.stream = track
	player.bus = "Music"
	add_child(player)
	ambient_player = AudioStreamPlayer.new()
	ambient_player.name = "MissionAmbience"
	var ambient_track := AMBIENCE.duplicate() as AudioStreamMP3
	ambient_track.loop = true
	ambient_player.stream = ambient_track
	ambient_player.bus = "MissionMusic"
	add_child(ambient_player)
	get_tree().scene_changed.connect(_scene_changed)
	# Wait for the initial scene so a direct outpost launch never plays menu music.
	call_deferred("_scene_changed")

func _scene_changed() -> void:
	var scene := get_tree().current_scene
	if scene == null: return
	if scene.scene_file_path == OUTPOST:
		mission_active = true
	elif scene.scene_file_path in MENUS:
		mission_active = false
	# Mission dashboards and pause/settings overlays inherit their originating context.
	transition_to(mission_active)

func transition_to(mission: bool) -> void:
	mission_active = mission
	var target := 1.0 if mission else 0.0
	if initialized and is_equal_approx(target, fade_target): return
	fade_target = target
	if fade_tween != null: fade_tween.kill()
	if not initialized:
		initialized = true
		_set_blend(target)
		if mission: ambient_player.play(mission_position)
		else: player.play(menu_position)
		return
	if mission and not ambient_player.playing: ambient_player.play(mission_position)
	if not mission and not player.playing: player.play(menu_position)
	fade_tween = create_tween()
	fade_tween.tween_method(_set_blend, blend, target, crossfade_seconds)
	fade_tween.tween_callback(_finish_fade.bind(mission))

func _set_blend(value: float) -> void:
	blend = value
	_apply_mix()

func _apply_mix() -> void:
	player.volume_linear = maxf(0.0, cos(blend * PI * 0.5))
	ambient_player.volume_linear = maxf(0.0, sin(blend * PI * 0.5)) * duck

func _finish_fade(mission: bool) -> void:
	if mission:
		menu_position = player.get_playback_position()
		player.stop()
	else:
		mission_position = ambient_player.get_playback_position()
		ambient_player.stop()

func set_rover_duck(enabled: bool) -> void:
	if duck_tween != null: duck_tween.kill()
	duck_tween = create_tween()
	duck_tween.tween_method(func(value: float):
		duck = value
		_apply_mix(), duck, 0.5 if enabled else 1.0, 0.45 if enabled else 0.8)

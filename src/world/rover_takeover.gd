extends CanvasLayer
## Owns the visual/audio gate; the existing driver retains all movement logic.
signal completed
signal interrupted
const VIDEO := preload("res://Assets/video/rover_takeover.ogv")
const DURATION := 10.0
var driver: Node
var screen: Control
var video: VideoStreamPlayer
var running := false
var video_done := false
var audio_done := false
var elapsed := 0.0
var camera_handed_off := false

func _ready() -> void:
	driver = get_parent()
	layer = 110 # Pause menu (120) stays usable above the cinematic.
	process_mode = Node.PROCESS_MODE_ALWAYS
	screen = Control.new()
	add_child(screen)
	screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	screen.mouse_filter = Control.MOUSE_FILTER_STOP
	var bars := ColorRect.new()
	bars.color = Color.BLACK
	screen.add_child(bars)
	bars.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 16.0 / 9.0
	aspect.stretch_mode = AspectRatioContainer.STRETCH_FIT
	screen.add_child(aspect)
	aspect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	video = VideoStreamPlayer.new()
	video.expand = true
	video.stream = VIDEO
	video.volume = 0.0 # Asset also contains no audio track.
	aspect.add_child(video)
	video.finished.connect(_video_finished)
	get_node("/root/GameAudio").rover_startup_finished.connect(_audio_finished)
	screen.hide()
	# Open the decoder during scene setup, before a takeover is requested.
	video.play()
	video.paused = true

func begin() -> void:
	if running: return
	running = true
	video_done = false
	audio_done = false
	camera_handed_off = false
	elapsed = 0.0
	screen.modulate.a = 0.0
	screen.show()
	video.paused = false
	if not video.is_playing(): video.play()
	get_node("/root/GameAudio").play_rover_startup(driver, true)
	get_node("/root/MenuMusic").set_rover_duck(true)

func _process(delta: float) -> void:
	if not running: return
	video.paused = get_tree().paused
	if get_tree().paused: return
	elapsed += delta
	var position := video.stream_position
	# Switch the 3D camera under the opaque video before dissolving into it.
	if position >= DURATION - 0.65 and not camera_handed_off:
		camera_handed_off = true
		driver._update_camera()
		driver.camera.make_current()
	screen.modulate.a = smoothstep(0.0, 0.35, position) * (1.0 - smoothstep(DURATION - 0.55, DURATION, position))
	if elapsed > DURATION + 2.0:
		push_warning("Rover video did not complete; returning safely to cockpit.")
		cancel()
		interrupted.emit()

func _video_finished() -> void:
	if not running: return
	video_done = true
	_finish_if_ready()

func _audio_finished(owner_id: int) -> void:
	if not running or owner_id != driver.get_instance_id(): return
	audio_done = true
	_finish_if_ready()

func _finish_if_ready() -> void:
	if not video_done or not audio_done: return
	running = false
	screen.hide()
	get_node("/root/MenuMusic").set_rover_duck(false)
	completed.emit()
	_prepare_replay()

func _prepare_replay() -> void:
	video.stop()
	video.play()
	video.paused = true

func cancel() -> void:
	running = false
	screen.hide()
	get_node("/root/GameAudio").cancel_rover_startup(driver)
	get_node("/root/MenuMusic").set_rover_duck(false)
	_prepare_replay()

func _exit_tree() -> void:
	var audio := get_node_or_null("/root/GameAudio")
	if audio != null: audio.cancel_rover_startup(driver)
	var music := get_node_or_null("/root/MenuMusic")
	if music != null: music.set_rover_duck(false)

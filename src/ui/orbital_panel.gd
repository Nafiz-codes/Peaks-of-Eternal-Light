extends AcceptDialog
const Model = preload("res://src/world/orbital_model.gd")
var motion: Node
var timestamp: Label
var speed: OptionButton
var pause: CheckButton

func _ready() -> void:
	title = "Orbital motion"
	size = Vector2i(620, 300)
	var content := VBoxContainer.new()
	add_child(content)
	timestamp = Label.new()
	content.add_child(timestamp)
	speed = OptionButton.new()
	for label in ["1× — real time", "60× — 1 minute / second", "3,600× — 1 hour / second (default)", "86,400× — 1 day / second"]:
		speed.add_item(label)
	content.add_child(speed)
	speed.item_selected.connect(func(index: int): motion.set_speed(Model.SPEEDS[index]))
	pause = CheckButton.new()
	pause.text = "Pause orbital clock"
	pause.toggled.connect(func(value: bool): motion.set_paused(value))
	content.add_child(pause)
	var explanation := Label.new()
	explanation.text = "Moon rotation and orbit: 27.3217 Earth days\nEarth orbit: approximately 365.256 Earth days\nEarth rotation: 23 h 56 m 4 s\n\nThe Moon travels around the Sun with Earth. Tidal locking keeps\nEarth near the same place in the lunar sky. Watch the Sun and\nEarth’s phase change as time passes.\n\nSun/Earth positions use NASA/JPL Horizons DE441 samples with linear interpolation; lunar orientation uses an IAU model. Sizes are exaggerated for visibility.\nDuring missions the sky follows manual Sol progression.\nOne game Sol represents one modeled Earth day; physics is unchanged."
	content.add_child(explanation)

func open_orbits(controller: Node) -> void:
	motion = controller
	var campaign: bool = motion.session.dashboard_state != null
	speed.disabled = campaign
	pause.disabled = campaign
	speed.tooltip_text = "During a mission, the sky follows manual Sol progression (one modeled Earth day per Sol)."
	speed.select(Model.SPEEDS.find(motion.session.orbital_clock.time_scale))
	pause.set_pressed_no_signal(motion.session.orbital_clock.paused)
	popup_centered()

func _process(_delta: float) -> void:
	if visible and is_instance_valid(motion):
		timestamp.text = motion.timestamp() + ("\nSynchronized to mission Sol %d / %d" % [motion.session.dashboard_state.sol, motion.session.dashboard_state.mission_length_sols] if motion.session.dashboard_state != null else "")
		pause.set_pressed_no_signal(motion.session.orbital_clock.paused)

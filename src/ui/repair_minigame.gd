extends CanvasLayer
## Timing repair: stop the moving marker inside the green zone three times.
## Q stops without repairing. Esc still opens the pause menu, which freezes the marker.
signal finished(repaired: bool)
const UI = preload("res://src/ui/ui_style.gd")
const HITS_NEEDED := 3
const ZONE_WIDTH := 0.2 # Share of the bar that counts as a hit.
var title_text := "Structure"
var player: Node
var hits := 0
var marker := 0.0 # 0..1 along the bar
var direction := 1.0
var speed := 0.8 # Bar lengths per second; rises after each hit.
var zone := 0.4 # Left edge of the green zone, 0..1
var bar: Control
var caption: Label
var was_blocked := false

func _ready() -> void:
	name = "RepairMinigame"
	layer = 70
	if player != null:
		was_blocked = player.ui_blocked
		player.ui_blocked = true
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UI.style(Color(0.04, 0.05, 0.09, 0.94), UI.AMBER))
	add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -250
	panel.offset_right = 250
	panel.offset_top = -210
	panel.offset_bottom = -70
	var column := UI.box()
	panel.add_child(column)
	column.add_child(UI.label("Repair: " + title_text, 20, UI.AMBER))
	bar = Control.new()
	bar.custom_minimum_size = Vector2(460, 34)
	bar.draw.connect(_draw_bar)
	column.add_child(bar)
	caption = UI.label("", 15)
	column.add_child(caption)
	_update_caption("")

func _update_caption(note: String) -> void:
	caption.text = "%sPress E when the marker is in the green zone  ·  %d / %d  ·  Q to stop" % [note, hits, HITS_NEEDED]

func _process(delta: float) -> void:
	marker += direction * speed * delta
	if marker >= 1.0 or marker <= 0.0:
		marker = clampf(marker, 0.0, 1.0)
		direction = -direction
	bar.queue_redraw()

func _draw_bar() -> void:
	var width := bar.size.x
	var height := bar.size.y
	bar.draw_rect(Rect2(0, 0, width, height), Color("29384b"))
	bar.draw_rect(Rect2(zone * width, 0, ZONE_WIDTH * width, height), Color("3fae6a"))
	bar.draw_rect(Rect2(marker * width - 3.0, -4.0, 6.0, height + 8.0), Color("f1f3fa"))

func _input(event: InputEvent) -> void:
	if get_tree().paused: return
	var press: bool = event is InputEventKey and event.pressed and not event.echo and event.keycode in [KEY_E, KEY_SPACE]
	press = press or (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT)
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_Q:
		get_viewport().set_input_as_handled()
		_close(false)
	elif press:
		get_viewport().set_input_as_handled()
		if marker >= zone and marker <= zone + ZONE_WIDTH:
			hits += 1
			if hits >= HITS_NEEDED:
				_close(true)
				return
			# Each fix moves the zone and speeds the marker up a little.
			zone = randf_range(0.05, 0.95 - ZONE_WIDTH)
			speed += 0.25
			_update_caption("Good.  ")
		else:
			_update_caption("Missed.  ")

func _close(repaired: bool) -> void:
	set_process_input(false)
	finished.emit(repaired)
	queue_free()

func _exit_tree() -> void:
	if is_instance_valid(player): player.ui_blocked = was_blocked

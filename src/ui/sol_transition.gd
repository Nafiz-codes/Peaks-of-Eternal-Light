extends CanvasLayer
## Persistent full-screen Sol transition shared by all calendar controls.
var busy := false

func play(action: Callable) -> void:
	if busy:
		return
	busy = true
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	var cover := ColorRect.new()
	cover.color = Color.BLACK
	cover.mouse_filter = Control.MOUSE_FILTER_STOP
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cover.modulate.a = 0.0
	add_child(cover)
	var tree := get_tree()
	var was_paused := tree.paused
	tree.paused = true
	var fade := create_tween()
	fade.tween_property(cover, "modulate:a", 1.0, 0.4)
	await fade.finished
	tree.paused = was_paused
	action.call()
	fade = create_tween()
	fade.tween_interval(0.3)
	fade.tween_property(cover, "modulate:a", 0.0, 0.6)
	await fade.finished
	cover.queue_free()
	busy = false

extends Control
## Four stills, with a readable hold and a fade through black between each.
signal finished
const IMAGES := [
	preload("res://Assets/startup/mission/pk1.jpg"),
	preload("res://Assets/startup/mission/pk2.jpg"),
	preload("res://Assets/startup/mission/pk3.jpg"),
	preload("res://Assets/startup/mission/pk4.jpg"),
]
const CAPTIONS := [
	"In 1969, Humanity took its first step on the moon.",
	"“That’s one small step for man, one giant leap for mankind.”\n— Neil Armstrong · July 20, 1969",
	"Decades after we returned with a greater ambition.\nNot just to explore, But to establish a lasting presence.",
	"",
]
const HOLD_SECONDS := [5.0, 7.0, 7.0, 4.0]
var sequence: Tween
var slide: Control
var picture: TextureRect
var caption: RichTextLabel
var shade: TextureRect
var done := false
var slide_index := -1
var can_advance := false
var skip_hint: RichTextLabel
var hint_fade: Tween

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	slide = Control.new()
	add_child(slide)
	slide.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	picture = TextureRect.new()
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	slide.add_child(picture)
	picture.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0, 0, 0, 0), Color(0, 0, 0, 0.88)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill_from = Vector2(0, 0)
	texture.fill_to = Vector2(0, 1)
	shade = TextureRect.new()
	shade.texture = texture
	slide.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.anchor_top = 0.62
	var font := preload("res://Assets/fonts/PrevalentSansPro/PREVALENTSANSPRO-Bold.ttf")
	caption = RichTextLabel.new()
	caption.bbcode_enabled = true
	caption.scroll_active = false
	caption.add_theme_font_override("normal_font", font)
	caption.add_theme_color_override("default_color", Color("f3e8d5"))
	slide.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	caption.anchor_left = 0.07
	caption.anchor_right = 0.93
	caption.anchor_top = 0.78
	caption.anchor_bottom = 0.98
	skip_hint = RichTextLabel.new()
	skip_hint.bbcode_enabled = true
	skip_hint.text = "[right]SKIP / SPACE[/right]"
	skip_hint.scroll_active = false
	skip_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_hint.add_theme_font_override("normal_font", preload("res://Assets/fonts/corpta-demo.regular.otf"))
	skip_hint.add_theme_font_size_override("normal_font_size", 16)
	skip_hint.add_theme_color_override("default_color", Color("f3e8d5"))
	skip_hint.add_theme_color_override("font_shadow_color", Color.BLACK)
	skip_hint.add_theme_constant_override("shadow_offset_x", 1)
	skip_hint.add_theme_constant_override("shadow_offset_y", 1)
	slide.add_child(skip_hint)
	skip_hint.hide()
	resized.connect(_layout)
	_layout()

func _layout() -> void:
	caption.add_theme_font_size_override("normal_font_size", clampi(roundi(minf(size.x / 1360.0, size.y / 820.0) * 30.0), 16, 64))

func play() -> void:
	_play_slide(0)

func _play_slide(index: int) -> void:
	_show_slide(index)
	sequence = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_property(slide, "modulate:a", 1.0, 1.2)
	sequence.tween_interval(HOLD_SECONDS[index] * 0.5)
	sequence.tween_callback(func():
		can_advance = index < IMAGES.size() - 1
		if can_advance: _reveal_hint())
	sequence.tween_interval(HOLD_SECONDS[index] * 0.5)
	sequence.tween_callback(_advance)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_SPACE:
		get_viewport().set_input_as_handled()
		if can_advance and not done: _advance()

func _reveal_hint() -> void:
	skip_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	skip_hint.offset_left = -204
	skip_hint.offset_right = -24
	skip_hint.offset_top = -52
	skip_hint.offset_bottom = -24
	skip_hint.modulate.a = 0.0
	skip_hint.show()
	if hint_fade: hint_fade.kill()
	hint_fade = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	hint_fade.tween_property(skip_hint, "modulate:a", 1.0, 0.5)

func _advance() -> void:
	can_advance = false
	if sequence: sequence.kill()
	sequence = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_property(slide, "modulate:a", 0.0, 1.2)
	if slide_index < IMAGES.size() - 1:
		sequence.tween_callback(_play_slide.bind(slide_index + 1))
	else:
		sequence.tween_callback(_complete)

func _show_slide(index: int) -> void:
	if hint_fade: hint_fade.kill()
	can_advance = false
	skip_hint.hide()
	slide_index = index
	slide.modulate.a = 0.0
	picture.texture = IMAGES[index]
	caption.text = "[center]" + CAPTIONS[index] + "[/center]"
	shade.visible = not CAPTIONS[index].is_empty()

func skip() -> void:
	if done: return
	can_advance = false
	if sequence: sequence.kill()
	sequence = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	sequence.tween_property(slide, "modulate:a", 0.0, 0.6)
	sequence.tween_callback(_complete)

func _complete() -> void:
	if done: return
	done = true
	finished.emit()

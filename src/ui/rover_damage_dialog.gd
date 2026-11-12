extends ConfirmationDialog
## Custom warning presentation; ConfirmationDialog retains modal input and actions.
const UI = preload("res://src/ui/ui_style.gd")
var caption: Label
var heading: Label
var message: Label

func _ready() -> void:
	borderless = true
	exclusive = true
	unresizable = true
	min_size = Vector2i(740, 370)
	var panel := UI.style(Color("454b50"), Color("293137"))
	panel.set_border_width_all(3)
	panel.set_corner_radius_all(10)
	panel.content_margin_top = 12
	panel.content_margin_bottom = 20
	add_theme_stylebox_override("panel", panel)
	get_label().hide()
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 22)
	add_child(content)
	var bar := PanelContainer.new()
	bar.add_theme_stylebox_override("panel", UI.style(Color("293137"), Color("293137")))
	content.add_child(bar)
	var header := HBoxContainer.new()
	bar.add_child(header)
	caption = UI.label("ROVER DAMAGE WARNING", 16, Color.WHITE)
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(caption)
	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 26)
	content.add_child(body)
	var copy := VBoxContainer.new()
	copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	copy.add_theme_constant_override("separation", 12)
	body.add_child(copy)
	heading = UI.label("WARNING!", 46, Color("f4f1e8"))
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	copy.add_child(heading)
	message = UI.label("", 16, Color("e3e8eb"))
	message.custom_minimum_size = Vector2(430, 132)
	message.size = message.custom_minimum_size
	copy.add_child(message)
	var icon := TextureRect.new()
	icon.texture = preload("res://Assets/ui/rover-warning.svg")
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.custom_minimum_size = Vector2(210, 200)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(icon)
	for button in [get_ok_button(), get_cancel_button()]:
		button.custom_minimum_size = Vector2(240, 44)
		button.add_theme_font_size_override("font_size", 16)
		button.add_theme_color_override("font_focus_color", Color("f4f1e8"))
		for state in ["normal", "hover", "pressed"]:
			var fill := Color("59636b") if state == "normal" else Color("707d86")
			button.add_theme_stylebox_override(state, UI.style(fill, Color("7b8b92")))
			button.add_theme_color_override("font_" + ("color" if state == "normal" else state + "_color"), Color("f4f1e8"))
		var focus := UI.style(Color.TRANSPARENT, Color("f0cc73"))
		focus.set_border_width_all(3)
		button.add_theme_stylebox_override("focus", focus)

func show_damage(failed: bool, health: int) -> void:
	title = "MISSION FAILED" if failed else "ROVER DAMAGE WARNING"
	caption.text = title
	heading.text = "MISSION FAILED" if failed else "WARNING!"
	message.text = "The rover is fully damaged. Try again to return it to the outpost. Repair it on foot before sending it out again. Current mission objective progress will reset." if failed else "Commander, rover health is at %d%%. Total damage will disable the rover and fail this attempt.\n\nContinue at your own risk, or abort and call back the rover while it can still return." % health
	ok_button_text = "Try again" if failed else "Continue mission"
	cancel_button_text = "Abort & recall rover"
	get_cancel_button().visible = not failed
	popup_centered(Vector2i(760, 390))

func show_choice(window_title: String, body_text: String, yes_text: String, no_text: String) -> void:
	title = window_title
	caption.text = window_title
	heading.text = "RADIATION ALERT"
	message.text = body_text
	ok_button_text = yes_text
	cancel_button_text = no_text
	get_cancel_button().show()
	popup_centered(Vector2i(760, 390))
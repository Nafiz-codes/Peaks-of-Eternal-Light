extends ConfirmationDialog

## Presentation preview only. No simulation event is resolved by this dialog.
const UI = preload("res://src/ui/ui_style.gd")
signal preview_finished(choice_id: String)
signal decision_confirmed(event_id: String, choice_id: String)
var live_event_id := ""
var selected_choice := ""
var content: VBoxContainer
var return_focus: WeakRef
var selection_label: Label

func _ready() -> void:
	title = "Event layout preview"
	exclusive = true
	min_size = Vector2i(320, 360)
	add_theme_stylebox_override("panel", UI.style(Color("171c2b"), UI.PURPLE))
	for control in [get_ok_button(), get_cancel_button()]:
		control.custom_minimum_size.y = 44
		control.add_theme_stylebox_override("normal", UI.style(Color("101521"), UI.BLUE))
		var focus := UI.style(Color(0, 0, 0, 0), UI.AMBER)
		focus.set_border_width_all(3)
		control.add_theme_stylebox_override("focus", focus)
	get_cancel_button().text = "Close preview"
	confirmed.connect(_finish_preview)
	canceled.connect(_restore_focus)
	close_requested.connect(_restore_focus)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_top = 16
	scroll.offset_right = -20
	scroll.offset_bottom = -72
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	content = UI.box()
	scroll.add_child(content)

func open_preview(event: Dictionary, invoker: Control = null, live: bool = false) -> void:
	live_event_id = str(event.get("event_id", "")) if live else ""
	title = "Mission decision" if live else "Event layout preview"
	get_cancel_button().text = "Decide later" if live else "Close preview"
	return_focus = weakref(invoker) if invoker != null else null
	selected_choice = ""
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	content.add_child(UI.label("MISSION DECISION / Sol progression waits for your choice" if live else "LAYOUT PREVIEW / No mission effect will be applied", 14, UI.AMBER))
	content.add_child(UI.label(str(event.get("category", "notification")).to_upper(), 16, UI.PURPLE))
	content.add_child(UI.label(str(event.get("text", "No event text supplied.")), 20))
	var choices: Variant = event.get("choices")
	var has_choices: bool = choices is Array and not choices.is_empty()
	get_ok_button().text = "Confirm preview choice" if has_choices else "Acknowledge preview"
	if live:
		get_ok_button().text = "Apply decision" if has_choices else "Acknowledge"
	get_ok_button().disabled = has_choices
	selection_label = UI.label("No choice selected" if has_choices else "Notification / no choice required", 14, UI.AMBER)
	if has_choices:
		var group := ButtonGroup.new()
		for choice in choices:
			if not choice is Dictionary:
				continue
			var id := str(choice.get("choice_id", ""))
			var option := UI.button(str(choice.get("text", "Unnamed choice")), func():
				selected_choice = id
				selection_label.text = "Selected: " + str(choice.get("text", id))
				get_ok_button().disabled = id.is_empty())
			option.toggle_mode = true
			option.button_group = group
			content.add_child(option)
	content.add_child(selection_label)
	content.add_child(UI.label("The mission simulator applies the chosen outcome. Review updated readings after confirmation." if live else "Consequences will be supplied by the event system. This preview does not interpret authored effects.", 14, UI.MUTED))
	popup_centered_clamped(Vector2i(700, 560), 0.9)
	if has_choices and content.get_child_count() > 3:
		content.get_child(3).grab_focus()
	else:
		get_ok_button().grab_focus()

func _finish_preview() -> void:
	if live_event_id.is_empty():
		preview_finished.emit(selected_choice)
	else:
		decision_confirmed.emit(live_event_id, selected_choice)
	_restore_focus()

func _restore_focus() -> void:
	if return_focus != null and is_instance_valid(return_focus.get_ref()):
		return_focus.get_ref().grab_focus()

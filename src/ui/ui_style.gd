extends RefCounted

const TEXT := Color("f1f3fa")
const MUTED := Color("b6c1d8")
const BLUE := Color("91cfff")
const AMBER := Color("ffd18a")
const PURPLE := Color("b7a2ff")
## On-screen objective text: gold with a dark outline, no panel behind it.
const OBJECTIVE := Color("f2d58c")
const OBJECTIVE_OUTLINE := Color("101522")

static func objective_font() -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(["Segoe UI", "Noto Sans", "Arial"])
	font.font_weight = 500
	return font

static func objective_label(font: Font, font_size: int) -> Label:
	var result := Label.new()
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	result.add_theme_font_override("font", font)
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", OBJECTIVE)
	result.add_theme_color_override("font_outline_color", OBJECTIVE_OUTLINE)
	result.add_theme_constant_override("outline_size", 3)
	return result

static func label(value: String, font_size: int = 16, color: Color = TEXT) -> Label:
	var result := Label.new()
	result.text = value
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.add_theme_color_override("font_color", color)
	return result

static func box() -> VBoxContainer:
	var result := VBoxContainer.new()
	result.add_theme_constant_override("separation", 12)
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return result

static func style(background: Color, edge: Color) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = background
	result.border_color = edge
	result.set_border_width_all(1)
	result.set_corner_radius_all(4)
	result.content_margin_left = 16
	result.content_margin_right = 16
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result

static func panel(parent: Node) -> VBoxContainer:
	var result := PanelContainer.new()
	result.add_theme_stylebox_override("panel", style(Color("171c2b"), Color("66738f")))
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(result)
	var content := box()
	result.add_child(content)
	return content

static func button(title: String, action: Callable, disabled: bool = false) -> Button:
	var result := Button.new()
	result.text = title
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.custom_minimum_size.y = 44
	result.disabled = disabled
	result.add_theme_font_size_override("font_size", 16)
	result.add_theme_color_override("font_color", TEXT)
	result.add_theme_color_override("font_disabled_color", MUTED)
	result.add_theme_stylebox_override("normal", style(Color("171c2b"), Color("66738f")))
	result.add_theme_stylebox_override("hover", style(Color("242c42"), BLUE))
	result.add_theme_stylebox_override("pressed", style(Color("30364c"), PURPLE))
	result.add_theme_stylebox_override("disabled", style(Color("101521"), Color("66738f")))
	var focus := style(Color(0, 0, 0, 0), AMBER)
	focus.set_border_width_all(3)
	result.add_theme_stylebox_override("focus", focus)
	if action.is_valid():
		result.pressed.connect(action)
	return result

static func disclosure(parent: Node, title: String, text: String) -> void:
	var body := label(text, 14, MUTED)
	body.visible = false
	var toggle := button(title + " +", func(): body.visible = not body.visible)
	toggle.toggle_mode = true
	toggle.toggled.connect(func(open: bool): toggle.text = title + (" −" if open else " +"))
	parent.add_child(toggle)
	parent.add_child(body)

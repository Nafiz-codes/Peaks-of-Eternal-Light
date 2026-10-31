extends CanvasLayer
## Non-interactive preview: never intercepts landing clicks or globe dragging.
const UI = preload("res://src/ui/ui_style.gd")
var selector: Node
var panel: PanelContainer
var content: VBoxContainer
var shown_site := ""
var sunlight_bar: ProgressBar
var pointer_position := Vector2(-1, -1)

static func sunlight_rating(value: float) -> Dictionary:
	if value >= 80.0: return {"label": "Excellent", "color": Color("72df9a")}
	if value >= 60.0: return {"label": "Good", "color": Color("79c8df")}
	if value >= 40.0: return {"label": "Limited", "color": Color("ffd18a")}
	return {"label": "Poor", "color": Color("ff8e8e")}

static func terrain_rating(value: float) -> String:
	return "Gentle" if value < 5.0 else ("Moderate" if value < 10.0 else "Steep")

static func terrain_score(slope: float) -> float:
	return clampf(100.0 * (1.0 - slope / 30.0), 0.0, 100.0)

static func accessibility_score(sunlight: float, slope: float) -> float:
	return (clampf(sunlight, 0.0, 100.0) + terrain_score(slope)) * 0.5

func _ready() -> void:
	selector = get_parent()
	layer = 40
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel = PanelContainer.new()
	panel.name = "OutpostHoverCard"
	panel.add_theme_stylebox_override("panel", UI.style(Color("101a29"), UI.BLUE))
	add_child(panel)
	content = UI.box()
	content.add_theme_constant_override("separation", 7)
	panel.add_child(content)
	panel.hide()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_position = event.position

func _process(_delta: float) -> void:
	if get_tree().paused or selector.landing_in_progress or not selector.is_visible_in_tree():
		clear()
		return
	var nav: Node = selector.navigation_controller
	if nav != null and (nav.pointer_down or nav.mode not in [nav.Mode.OVERVIEW, nav.Mode.EXPLORE]):
		clear()
		return
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
		clear()
		return
	var point := pointer_position
	var candidates: Array = []
	if nav != null and nav.mode == nav.Mode.OVERVIEW:
		for i in range(nav.sidebar_buttons.size()):
			candidates.append({"button": nav.sidebar_buttons[i], "site_id": selector.site_records[i].site_id})
	else:
		candidates = selector.site_callouts.duplicate()
		# Match the topmost visible label when distant geographic labels overlap.
		candidates.reverse()
	for candidate in candidates:
		var button: Button = candidate.button
		if button.is_visible_in_tree() and not button.disabled and button.get_global_rect().has_point(point):
			show_site(selector._site_by_id(candidate.site_id), button.get_global_rect())
			return
	clear()

func clear() -> void:
	shown_site = ""
	panel.hide()

func show_site(site: Dictionary, anchor: Rect2) -> void:
	var bounds := get_viewport().get_visible_rect().size
	var width := minf(430.0, bounds.x - 24.0)
	if shown_site != str(site.site_id) or not is_equal_approx(panel.size.x, width):
		shown_site = str(site.site_id)
		populate(site, width)
	panel.show()
	panel.size = Vector2(width, panel.get_combined_minimum_size().y)
	var x := anchor.end.x + 14.0
	if x + width > bounds.x - 12.0:
		x = anchor.position.x - width - 14.0
	panel.position = Vector2(clampf(x, 12.0, maxf(12.0, bounds.x - width - 12.0)), clampf(anchor.position.y, 12.0, maxf(12.0, bounds.y - panel.size.y - 12.0)))

func populate(site: Dictionary, width: float) -> void:
	for child in content.get_children():
		content.remove_child(child)
		child.queue_free()
	panel.custom_minimum_size.x = width
	var coords: Dictionary = site.get("coordinates", {})
	add_line(str(site.get("name", "Outpost")), 20, UI.BLUE)
	add_line("%.2f°%s  ·  %.2f°E" % [absf(float(coords.get("latitude_deg", 0))), "S" if float(coords.get("latitude_deg", 0)) < 0 else "N", float(coords.get("longitude_deg", 0))], 15)
	var sunlight: Variant = site.get("illumination_pct", {}).get("value")
	var slope: Variant = site.get("slope_deg", {}).get("value")
	var elevation: Variant = site.get("elevation_m", {}).get("value")
	if sunlight is float or sunlight is int:
		sunlight_bar = add_metric("Sunlight", float(sunlight), "%.2f%%" % sunlight)
	else:
		sunlight_bar = add_metric("Sunlight", 0, "Unavailable", "", UI.MUTED)
	add_line("Modeled first 30 Earth days", 12, UI.MUTED)
	add_metric("Ice Prospecting Potential", 50, "Possible", "", Color("79c8df"))
	add_line("Study-area prospecting category · bar is not an ice quantity or probability", 12, UI.MUTED)
	if slope is float or slope is int:
		var score := terrain_score(float(slope))
		add_metric("Terrain Suitability", score, "%.0f/100" % score)
	else:
		add_metric("Terrain Suitability", 0, "Unavailable", "", UI.MUTED)
	add_line("Game score based on local slope", 12, UI.MUTED)
	if (sunlight is float or sunlight is int) and (slope is float or slope is int):
		var score := accessibility_score(float(sunlight), float(slope))
		add_metric("Resource Accessibility", score, "%.0f/100" % score)
	else:
		add_metric("Resource Accessibility", 0, "Unavailable", "", UI.MUTED)
	add_line("Game logistics proxy: sunlight + slope; deposit routes not surveyed", 12, UI.MUTED)
	add_line("Elevation: %.1f m · lunar reference sphere" % elevation if elevation is float or elevation is int else "Elevation: unavailable", 14)
	add_line("Local slope: %.2f° · %s terrain" % [slope, terrain_rating(float(slope))] if slope is float or slope is int else "Local slope: unavailable", 14)
	add_line("NASA study coordinates / LOLA terrain\nSuitability and accessibility are game scores, not NASA ratings.", 12, UI.MUTED)
	add_line("Click the outpost to continue", 13, UI.BLUE)
	ignore_mouse(panel)

func add_metric(title: String, value: float, display: String, rating_override: String = "auto", color_override: Color = Color.TRANSPARENT) -> ProgressBar:
	var rating := sunlight_rating(value)
	var label: String = rating.label if rating_override == "auto" else rating_override
	var color: Color = rating.color if color_override == Color.TRANSPARENT else color_override
	add_line(title + "  " + display + (" · " + label if not label.is_empty() else ""), 17, color)
	var bar := ProgressBar.new()
	bar.step = 0.0
	bar.name = title.replace(" ", "") + "Bar"
	bar.value = clampf(value, 0, 100)
	bar.show_percentage = false
	bar.custom_minimum_size.y = 8
	var fill := StyleBoxFlat.new()
	fill.bg_color = color
	fill.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("29384b")
	background.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", background)
	content.add_child(bar)
	return bar

func add_line(value: String, font_size: int, color: Color = UI.TEXT) -> void:
	content.add_child(UI.label(value, font_size, color))

func ignore_mouse(control: Control) -> void:
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in control.get_children():
		if child is Control:
			ignore_mouse(child)

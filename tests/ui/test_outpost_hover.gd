extends SceneTree
const Hover = preload("res://src/ui/outpost_hover.gd")
var failures := 0
func _init() -> void: call_deferred("run")
func check(ok: bool, message: String) -> void:
	if not ok:
		failures += 1
		push_error(message)
func run() -> void:
	root.size = Vector2i(1360, 820)
	var world := preload("res://scenes/lunar_landing_selector.tscn").instantiate()
	root.add_child(world)
	current_scene = world
	await process_frame
	var card: Node
	for child in world.get_children():
		if child.get_script() == Hover: card = child
	card.set_process(false)
	for entry in [[0, "Poor"], [39.99, "Poor"], [40, "Limited"], [59.61, "Limited"], [60, "Good"], [78.85, "Good"], [80, "Excellent"], [98.66, "Excellent"]]:
		check(Hover.sunlight_rating(entry[0]).label == entry[1], "Sunlight rating threshold is correct.")
	for site in world.site_records:
		card.show_site(site, Rect2(1200, 700, 100, 40))
		for i in range(4): await process_frame
		card.show_site(site, Rect2(1200, 700, 100, 40))
		check(root.get_visible_rect().encloses(card.panel.get_global_rect()), "Hover card stays within viewport.")
		check(is_equal_approx(card.sunlight_bar.value, site.illumination_pct.value), "Sunlight bar reads site data.")
		check(card.content.find_children("*", "ProgressBar", true, false).size() == 4, "Each outpost has exactly four metric bars.")
		check(card.content.get_node("IceProspectingPotentialBar").value == 50, "Possible uses the same categorical marker for every study site.")
		check(is_equal_approx(card.content.get_node("TerrainSuitabilityBar").value, Hover.terrain_score(site.slope_deg.value)), "Terrain score uses the site slope.")
		check(is_equal_approx(card.content.get_node("ResourceAccessibilityBar").value, Hover.accessibility_score(site.illumination_pct.value, site.slope_deg.value)), "Accessibility uses the documented logistics proxy.")
		check(card.panel.mouse_filter == Control.MOUSE_FILTER_IGNORE, "Card cannot intercept landing clicks.")
		if DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("/tmp/hover-" + str(site.site_id) + ".png")
	var nav: Node = world.enable_cinematic_navigation()
	check(Hover.terrain_score(0) == 100 and Hover.terrain_score(30) == 0 and Hover.terrain_score(45) == 0, "Terrain scores are bounded.")
	check(Hover.accessibility_score(90, 3) > Hover.accessibility_score(40, 15), "More sunlight and gentler slope improve the logistics score.")
	nav._show_overview()
	nav.canvas.show()
	nav.sidebar.show()
	await process_frame
	var point: Vector2 = nav.sidebar_buttons[0].get_global_rect().get_center()
	var motion := InputEventMouseMotion.new()
	motion.position = point
	root.push_input(motion)
	card._process(0.0)
	check(card.panel.visible and card.shown_site == world.site_records[0].site_id, "Hovering the overview entry shows its card.")
	if DisplayServer.get_name() != "headless":
		for i in range(4):
			await process_frame
			card._process(0.0)
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("/tmp/hover-overview.png")
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.position = point
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		root.push_input(click)
	check(nav.mode == nav.Mode.APPROACH, "Hovering does not block clicking the outpost.")
	card._process(0.0)
	check(not card.panel.visible, "Card hides during camera transitions.")
	nav.mode = nav.Mode.OVERVIEW
	paused = true
	card._process(0.0)
	check(not card.panel.visible, "Card stays hidden while paused.")
	paused = false
	if nav.sequence: nav.sequence.kill()
	world.queue_free()
	await process_frame
	print("Outpost hover: %d failures." % failures)
	quit(1 if failures else 0)

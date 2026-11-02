extends Node3D
## One camera-aimed panel; confirmation retains the preview's exact transform.
var panel: Node3D
var player: Node3D
var session: Node
var build_menu: PanelContainer
var placed := false
var settling := false
var active := false
var valid := false
var yaw := 0.0
var label: Label
var hud: CanvasLayer
var material: StandardMaterial3D
var pose: RefCounted
var meshes: Array[MeshInstance3D] = []

func _ready() -> void:
	session = get_node("/root/MissionSession")
	player = get_parent().get_node("Outpost/Astronaut")
	panel = Node3D.new()
	panel.name = "PlacedSolarPanel"
	add_child(panel)
	var model := preload("res://Assets/expedition/solar_panel.glb").instantiate() as Node3D
	panel.add_child(model)
	preload("res://src/world/imported_asset_fit.gd").fit(model, 3.0)
	for node in panel.find_children("*", "MeshInstance3D", true, false):
		meshes.append(node)
	# Use actual mesh vertices to put the feet at local y=0, not padded bounds.
	var lowest := INF
	for mesh in meshes:
		for vertex in mesh.mesh.get_faces():
			var point: Vector3 = panel.global_transform.affine_inverse() * mesh.global_transform * vertex
			lowest = minf(lowest, point.y)
	if is_finite(lowest): model.position.y -= lowest
	placed = session.solar_placement.has("transform")
	if placed:
		panel.transform = session.solar_placement.transform
		_add_collision()
	material = StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = Color(0.0, 0.7, 1.0)
	if not placed:
		for mesh in meshes:
			mesh.material_override = material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	hud = CanvasLayer.new()
	hud.layer = 60
	add_child(hud)
	label = Label.new()
	label.position = Vector2(32, 100)
	label.add_theme_font_size_override("font_size", 20)
	hud.add_child(label)
	label.text = "B · Build"
	panel.visible = placed
	build_menu = PanelContainer.new()
	build_menu.position = Vector2(32, 145)
	hud.add_child(build_menu)
	var options := VBoxContainer.new()
	build_menu.add_child(options)
	var button := Button.new()
	button.text = "Solar panel placed" if placed else "Place solar panel"
	button.disabled = placed
	button.pressed.connect(func():
		build_menu.hide()
		player.ui_blocked = false
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		_start())
	options.add_child(button)
	build_menu.hide()

func _start() -> void:
	active = true
	player.placing_solar = true
	player.set_first_person(false)
	player.camera_pitch = -0.5
	player._sync_camera_rig()
	if player.animation_player != null:
		player.animation_player.play("idle")
		player.animation_player.advance(0.0)
		player.animation_player.pause()
	pose = preload("res://src/world/astronaut_seated_pose.gd").new()
	var visual: Node3D = player.get_node("AnimatedAstronaut")
	pose.original_visual_transform = visual.transform
	var skeletons := visual.find_children("*", "Skeleton3D", true, false)
	if not skeletons.is_empty():
		pose.skeleton = skeletons[0]
		var basis: Basis = (player.global_transform.affine_inverse() * pose.skeleton.global_transform).basis.inverse()
		pose._aim("R_Arm.", "R_Elbow.", basis * Vector3(0.1, 0.0, -0.5))
		pose._aim("R_Elbow.", "R_Wrist.", basis * Vector3(0.0, 0.0, -0.4))

func _physics_process(_delta: float) -> void:
	if not active: return
	if player.seated or player.ui_blocked: return
	var camera := get_viewport().get_camera_3d()
	if camera == null: return
	var origin := camera.project_ray_origin(get_viewport().get_visible_rect().size * 0.5)
	var direction := camera.project_ray_normal(get_viewport().get_visible_rect().size * 0.5)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + direction * 25.0)
	query.exclude = [player.get_rid()]
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	valid = not hit.is_empty() and hit.collider.name == "LunarSurfaceCollision"
	panel.visible = valid
	if valid:
		valid = hit.normal.y > 0.94 and hit.position.distance_to(player.global_position) > 2.0 and hit.position.distance_to(player.global_position) < 15.0
		var ground_basis := Basis(Quaternion(Vector3.UP, hit.normal)) * Basis(Vector3.UP, yaw)
		panel.global_transform = Transform3D(ground_basis, hit.position - hit.normal * 0.01)
		# All corners must rest on the same level surface; reject rocks and edges.
		for corner in [Vector3(-1.5, 0, -1.5), Vector3(1.5, 0, -1.5), Vector3(-1.5, 0, 1.5), Vector3(1.5, 0, 1.5)]:
			var point: Vector3 = panel.global_transform * corner
			var support_query := PhysicsRayQueryParameters3D.create(point + Vector3.UP * 2.0, point - Vector3.UP * 0.3)
			support_query.exclude = [player.get_rid()]
			var support := get_world_3d().direct_space_state.intersect_ray(support_query)
			if support.is_empty() or support.collider.name != "LunarSurfaceCollision" or absf((support.position - point).dot(hit.normal)) > 0.03 or support.normal.y < 0.94:
				valid = false
		var space := PhysicsShapeQueryParameters3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(3.0, 1.5, 3.0)
		space.shape = box
		space.transform = Transform3D(panel.global_basis, hit.position + Vector3.UP * 0.9)
		space.exclude = [player.get_rid()]
		if not get_world_3d().direct_space_state.intersect_shape(space, 1).is_empty(): valid = false
	material.albedo_color = Color(0.05, 0.75, 1.0, 0.4) if valid else Color(1.0, 0.15, 0.1, 0.4)
	label.text = "PLACE SOLAR PANEL  ·  Move mouse to aim  ·  Q / R rotate  ·  Left click confirm\n" + ("Ready to place" if valid else "Aim at nearby level ground")

func _input(event: InputEvent) -> void:
	if get_tree().paused or player.seated or settling: return
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_B:
		if player.ui_blocked and not build_menu.visible: return
		get_viewport().set_input_as_handled()
		if active:
			_cancel()
		else:
			build_menu.visible = not build_menu.visible
			player.ui_blocked = build_menu.visible
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if build_menu.visible else Input.MOUSE_MODE_CAPTURED
		return
	if not active or player.ui_blocked: return
	if event is InputEventKey and event.pressed:
		if event.keycode in [KEY_Q, KEY_R]:
			yaw += deg_to_rad(-15.0 if event.keycode == KEY_Q else 15.0)
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_E, KEY_I, KEY_V, KEY_C, KEY_SPACE]:
			get_viewport().set_input_as_handled()
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		get_viewport().set_input_as_handled()
		if valid: confirm()

func confirm() -> void:
	if not active or not valid: return
	active = false
	session.solar_placement = {"transform": panel.transform}
	for mesh in meshes:
		mesh.material_override = null
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	player.placing_solar = false
	pose.restore(player.get_node("AnimatedAstronaut"))
	if player.animation_player != null: player.animation_player.play("idle")
	placed = true
	settling = true
	label.text = "Deploying solar panel..."
	var button := build_menu.get_child(0).get_child(0) as Button
	button.text = "Solar panel placed"
	button.disabled = true
	# Preserve the approved ground transform; only the presentation falls.
	var landing := panel.transform
	panel.position = landing.origin + landing.basis.y.normalized() * 0.12
	var drop := create_tween()
	drop.tween_property(panel, "position", landing.origin, 0.385).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await drop.finished
	panel.transform = landing
	_add_collision()
	_dust_ring()
	settling = false
	label.text = "Solar panel placed"

func _dust_ring() -> void:
	var dust := Node3D.new()
	dust.name = "LandingDust"
	add_child(dust)
	dust.transform = panel.transform
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.65, 0.62, 0.57, 0.24), Color(0.65, 0.62, 0.57, 0.0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	var dust_material := StandardMaterial3D.new()
	dust_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dust_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dust_material.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_material.albedo_texture = texture
	dust_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var animation := create_tween().set_parallel(true)
	for index in range(20):
		var angle := TAU * float(index) / 20.0
		var outward := Vector3(cos(angle), 0.0, sin(angle))
		var puff := MeshInstance3D.new()
		var quad := QuadMesh.new()
		quad.size = Vector2(0.65, 0.25)
		puff.mesh = quad
		puff.material_override = dust_material
		puff.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dust.add_child(puff)
		puff.position = outward * 1.0 + Vector3.UP * 0.08
		puff.scale = Vector3.ONE * 0.6
		animation.tween_property(puff, "position", outward * 1.7 + Vector3.UP * 0.14, 0.85).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		animation.tween_property(puff, "scale", Vector3(1.3, 1.0, 1.0), 0.85)
		animation.tween_property(puff, "transparency", 1.0, 0.65).set_delay(0.2)
	animation.chain().tween_callback(dust.queue_free)

func _add_collision() -> void:
	for mesh in meshes:
		mesh.create_trimesh_collision()

func _cancel() -> void:
	active = false
	valid = false
	panel.hide()
	player.placing_solar = false
	pose.restore(player.get_node("AnimatedAstronaut"))
	if player.animation_player != null: player.animation_player.play("idle")
	label.text = "B · Build"

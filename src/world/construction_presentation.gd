extends Node3D

const NASABuildings = preload("res://src/world/nasa_buildings.gd")

## Fixed illustrative slots, not gameplay placement or surveyed coordinates.
const SLOTS := {
	"solar_array": Vector3(-5, 0, 5.5),
	"water_extractor": Vector3(7, 0, 1),
	"greenhouse": Vector3(-7, 0, 0),
	"shielding_wall": Vector3(-1, 0, -7),
	"habitat_module": Vector3(-1, 0, 12),
	"comms_relay": Vector3(5, 0, -7),
}
var completed: Dictionary = {}
var editing_id := ""
var preview: Node3D

func sync_completed(built: Dictionary, catalog: Array, placements: Dictionary = {}, queue: Array = []) -> void:
	var desired := built.duplicate()
	for job in queue:
		var id := str(job.structure_id)
		if placements.has(id): desired[id] = 0
	for id in completed.keys():
		var pending := not built.has(id)
		if not desired.has(id) or id == editing_id or bool(completed[id].get_meta("pending", false)) != pending:
			remove_child(completed[id])
			completed[id].queue_free()
			completed.erase(id)
	for entry in catalog:
		var id := str(entry.get("structure_id", ""))
		if not desired.has(id) or not SLOTS.has(id) or id == editing_id: continue
		if not completed.has(id):
			var pending := not built.has(id)
			var visual := _make_structure(id, str(entry.get("name", id)), pending)
			visual.set_meta("pending", pending)
			if pending:
				visual.name = "Building_" + id
				for caption in visual.find_children("*", "Label3D", true, false): caption.text = str(entry.name) + "\nUNDER CONSTRUCTION"
				var body := StaticBody3D.new()
				var shape := CollisionShape3D.new()
				var hull := BoxShape3D.new()
				hull.size = visual.get_node("NASAModel").get_meta("hull_size")
				shape.shape = hull
				shape.position.y = hull.size.y * 0.5
				body.add_child(shape)
				visual.add_child(body)
			add_child(visual)
			completed[id] = visual
			if is_instance_valid(preview) and preview.get_meta("structure_id") == id: clear_preview()
		if placements.has(id): completed[id].global_transform = placements[id]

func show_preview(id: String, catalog: Array) -> bool:
	if not SLOTS.has(id) or completed.has(id):
		return false
	for entry in catalog:
		if str(entry.get("structure_id", "")) == id:
			clear_preview()
			preview = _make_structure(id, str(entry.get("name", id)), true)
			add_child(preview)
			return true
	return false

func clear_preview() -> void:
	if is_instance_valid(preview):
		remove_child(preview)
		preview.queue_free()
	preview = null

func _make_structure(id: String, title: String, ghost: bool) -> Node3D:
	var visual := Node3D.new()
	visual.name = ("Preview_" if ghost else "Completed_") + id
	visual.set_meta("structure_id", id)
	visual.position = SLOTS[id]
	var size := Vector3(2.0, 2.0, 2.0)
	match id:
		"solar_array": size = Vector3(3, 0.9, 2)
		"greenhouse", "habitat_module": size = Vector3(3, 2, 2.5)
		"shielding_wall": size = Vector3(5, 1.7, 0.6)
		"comms_relay": size = Vector3(0.5, 3, 0.5)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.57, 0.81, 1, 0.3) if ghost else (Color("74727d") if id == "shielding_wall" else Color("b7c8db"))
	if ghost:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if NASABuildings.MODELS.has(id):
		var model := NASABuildings.make(id, ghost)
		visual.add_child(model)
		size = model.get_meta("hull_size")
	else:
		# Small silhouettes distinguish structures without claiming final production art.
		match id:
			"solar_array":
				for x in [-0.8, 0.8]:
					_add_box(visual, Vector3(1.45, 0.12, 2), Vector3(x, 0.8, 0), material)
					_add_box(visual, Vector3(0.15, 0.8, 0.15), Vector3(x, 0.4, 0), material)
			"shielding_wall":
				for row in range(3):
					for brick in range(5):
						_add_box(visual, Vector3(0.96, 0.53, 0.6), Vector3(-2 + brick, 0.28 + row * 0.56, 0), material)
			"comms_relay":
				_add_box(visual, Vector3(0.2, 2.5, 0.2), Vector3(0, 1.25, 0), material)
				_add_box(visual, Vector3(1.5, 0.12, 0.5), Vector3(0, 2.7, 0), material)
				_add_box(visual, Vector3(0.5, 0.2, 0.5), Vector3(0, 0.1, 0), material)
				size.x = 1.5
			"water_extractor":
				_add_box(visual, Vector3(1.8, 0.45, 1.8), Vector3(0, 0.225, 0), material)
				var tank := MeshInstance3D.new()
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.6
				cylinder.bottom_radius = 0.6
				cylinder.height = 1.5
				tank.mesh = cylinder
				tank.position.y = 1.2
				tank.material_override = material
				visual.add_child(tank)
			_:
				_add_box(visual, size, Vector3(0, size.y * 0.5, 0), material)
				var window_material := material.duplicate() as StandardMaterial3D
				if not ghost:
					window_material.albedo_color = Color("314b64") if id == "habitat_module" else Color("426b62")
				for x in [-0.9, 0.0, 0.9]:
					_add_box(visual, Vector3(0.6, 0.7, 0.05), Vector3(x, 1.25, size.z * 0.5 + 0.03), window_material)
	if not ghost:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var hull := BoxShape3D.new()
		hull.size = size
		shape.shape = hull
		shape.position.y = size.y * 0.5
		body.add_child(shape)
		visual.add_child(body)
	var label := Label3D.new()
	label.text = title + ("\nPLACEMENT PREVIEW / NOT BUILT" if ghost else "\nCOMPLETED / ILLUSTRATIVE PLACEMENT")
	if NASABuildings.MODELS.has(id): label.text = title + ("\nPLACEMENT PREVIEW / NOT BUILT" if ghost else "")
	label.position.y = size.y + 0.5
	label.font_size = 24
	label.pixel_size = 0.006
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	visual.add_child(label)
	return visual

func _add_box(parent: Node3D, size: Vector3, position_: Vector3, material: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = material
	mesh.position = position_
	parent.add_child(mesh)

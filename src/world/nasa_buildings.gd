extends RefCounted
## NASA source assemblies, normalized in local space before entering the scene tree.
const MODELS := {
 "habitat_module": preload("res://Assets/stations/hdu_1.glb"),
 "comms_relay": preload("res://Assets/structures/comms_relay.tscn"),
 # Game-authored models (Assets/structures/*.gd), not NASA assets.
 "water_extractor": preload("res://Assets/structures/water_extractor.tscn"),
 "greenhouse": preload("res://Assets/structures/greenhouse.tscn"),
 "shielding_wall": preload("res://Assets/structures/radiation_shelter.tscn")
}
# Gameplay dimensions in metres, not certified dimensions of NASA hardware.
const BUILDING_SCALE := 1.3
const EXTENTS := {"habitat_module": 9.6, "comms_relay": 5.0, "water_extractor": 5.0, "greenhouse": 8.7, "shielding_wall": 13.0}

static func mesh_bounds(node: Node3D, accumulated := Transform3D.IDENTITY) -> AABB:
 var result := AABB()
 var initialized := false
 for child in node.get_children():
  if not child is Node3D: continue
  var transform_: Transform3D = accumulated * child.transform
  if child is MeshInstance3D and child.mesh != null:
   var box: AABB = transform_ * child.get_aabb()
   result = result.merge(box) if initialized else box
   initialized = true
  var nested := mesh_bounds(child, transform_)
  if nested.size != Vector3.ZERO:
   result = result.merge(nested) if initialized else nested
   initialized = true
 return result

static func make(id: String, ghost: bool) -> Node3D:
 var root := Node3D.new()
 root.name = "NASAModel"
 var model: Node3D = MODELS[id].instantiate()
 root.add_child(model)
 var bounds := mesh_bounds(root)
 var factor: float = EXTENTS[id] / maxf(bounds.size.x, maxf(bounds.size.y, bounds.size.z))
 model.scale *= factor
 model.position += Vector3(-bounds.get_center().x, -bounds.position.y, -bounds.get_center().z) * factor
 if id == "habitat_module": _finish_habitat(root, model)
 elif id == "comms_relay": _finish_relay(root, model)
 # Buildings share the crew stations' 1.3x scale; the radiation habitat is the
 # ~13 m reference those were matched to, so it keeps its own size.
 if id != "shielding_wall":
  for child in root.get_children():
   child.scale *= BUILDING_SCALE
   child.position *= BUILDING_SCALE
 bounds = mesh_bounds(root)
 for child in root.get_children():
  child.position -= Vector3(bounds.get_center().x, bounds.position.y, bounds.get_center().z)
 root.set_meta("hull_size", bounds.size)
 if ghost:
  var material := StandardMaterial3D.new()
  material.albedo_color = Color(0.36, 0.72, 1.0, 0.28)
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  for mesh in root.find_children("*", "MeshInstance3D", true, false):
   mesh.material_override = material
   mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return root

# Game-authored installation hardware in metres; imported meshes stay untouched.
static func _material(color: String) -> StandardMaterial3D:
 var mat := StandardMaterial3D.new()
 mat.albedo_color = Color(color)
 mat.metallic = 0.5
 mat.roughness = 0.65
 return mat

static func _box(root: Node3D, title: String, size: Vector3, at: Vector3, mat: Material) -> void:
 var mesh := MeshInstance3D.new()
 mesh.name = title
 var box := BoxMesh.new()
 box.size = size
 mesh.mesh = box
 mesh.position = at
 mesh.material_override = mat
 root.add_child(mesh)

static func _bar(root: Node3D, title: String, from: Vector3, to: Vector3, radius: float, mat: Material) -> void:
 var mesh := MeshInstance3D.new()
 mesh.name = title
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = radius
 cylinder.bottom_radius = radius
 cylinder.height = from.distance_to(to)
 mesh.mesh = cylinder
 mesh.position = (from + to) * 0.5
 mesh.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
 mesh.material_override = mat
 root.add_child(mesh)

static func _finish_habitat(root: Node3D, model: Node3D) -> void:
 var metal := _material("65717a")
 var deck := _material("39434c")
 var trim := _material("d5af55")
 model.position.y += 0.36
 _box(root, "Foundation", Vector3(9.8, 0.36, 4.6), Vector3(0, 0.18, 0), deck)
 for x in [-3.7, 3.7]:
  _box(root, "ModuleSaddle", Vector3(1.2, 0.55, 1.8), Vector3(x, 0.635, 0), metal)
 _box(root, "AccessStep", Vector3(1.5, 0.18, 0.4), Vector3(0, 0.09, 2.9), deck)
 _box(root, "AccessLanding", Vector3(1.5, 0.36, 0.6), Vector3(0, 0.18, 2.4), deck)
 for x in [-0.72, 0.72]:
  _bar(root, "HandrailPost", Vector3(x, 0.36, 2.15), Vector3(x, 1.36, 2.15), 0.035, trim)
  _bar(root, "HandrailPost", Vector3(x, 0.18, 2.95), Vector3(x, 1.18, 2.95), 0.035, trim)
  _bar(root, "Handrail", Vector3(x, 1.36, 2.15), Vector3(x, 1.18, 2.95), 0.035, trim)

static func _finish_relay(root: Node3D, model: Node3D) -> void:
 var metal := _material("707e8b")
 var dark := _material("303e4d")
 var white := _material("cbd3d8")
 model.position.y += 0.2
 _box(root, "Foundation", Vector3(2.8, 0.2, 2.8), Vector3(0, 0.1, 0), dark)
 _box(root, "MastFlange", Vector3(0.75, 0.15, 0.75), Vector3(0, 0.275, 0), metal)
 for x in [-1.05, 1.05]:
  for z in [-1.05, 1.05]:
   _box(root, "AnchorPlate", Vector3(0.3, 0.08, 0.3), Vector3(x, 0.24, z), metal)
   _bar(root, "MastBrace", Vector3(x, 0.28, z), Vector3(0, 1.5, 0), 0.045, metal)
 _box(root, "RadioCabinet", Vector3(0.65, 1.1, 0.45), Vector3(0.85, 0.75, 0.55), white)
 _box(root, "CabinetDoor", Vector3(0.53, 0.94, 0.025), Vector3(0.85, 0.75, 0.79), dark)
 for y in [0.48, 0.55, 0.62]:
  _box(root, "Vent", Vector3(0.4, 0.025, 0.03), Vector3(0.85, y, 0.81), metal)
 _bar(root, "CableConduit", Vector3(0, 0.4, 0), Vector3(0.85, 0.4, 0.55), 0.035, dark)

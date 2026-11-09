extends RefCounted
## NASA source assemblies, normalized in local space before entering the scene tree.
const MODELS := {
 "habitat_module": preload("res://Assets/stations/hdu_1.glb"),
 "comms_relay": preload("res://Assets/structures/comms_relay.tscn")
}
# Gameplay dimensions in metres, not certified dimensions of NASA hardware.
const EXTENTS := {"habitat_module": 9.6, "comms_relay": 5.0}

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
 root.set_meta("hull_size", bounds.size * factor)
 if ghost:
  var material := StandardMaterial3D.new()
  material.albedo_color = Color(0.36, 0.72, 1.0, 0.28)
  material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  for mesh in root.find_children("*", "MeshInstance3D", true, false):
   mesh.material_override = material
   mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
 return root

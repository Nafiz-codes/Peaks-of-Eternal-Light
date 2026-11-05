extends Node3D
## Walk-up workstations using NASA's HDU shell and game-authored work equipment.
@export var station_id := "maya_station"
const DEFINITIONS := {
 "maya_station": {"name": "Maya · Operations", "npc": "crew_briefing", "color": Color("42d9e2")},
 "alex_station": {"name": "Alex · Science", "npc": "water_recycler", "color": Color("7fbdff")},
 "sam_station": {"name": "Sam · Engineering", "npc": "food_storage", "color": Color("ffb653")}
}
const DOCK := Vector3(0, 0, 4.4)
# Metres: full-height crew outpost shells, with human-sized outdoor equipment.
static func footprint(_id: String) -> Vector2:
 return Vector2(5.1, 3.8)
static func dock(_id: String) -> Vector3:
 return DOCK
static func clearance_height(_id: String) -> float:
 return 5.7
func _ready() -> void:
 var accent: Color = DEFINITIONS[station_id].color
 var shell := preload("res://Assets/stations/hdu_1.glb").instantiate() as Node3D
 add_child(shell)
 preload("res://src/world/imported_asset_fit.gd").fit(shell, 9.6)
 shell.name = "HabitatShell"
 shell.position.z -= 0.7
 _box(Vector3(10.0,0.08,7.4),Vector3(0,0.04,0),Color("4b5260"))
 for x in [-4.9,4.9]:
  _box(Vector3(0.04,0.025,7.2),Vector3(x,0.095,0),accent,true)
 var equipment_start := get_child_count()
 # Shared walk-up desk on the front edge; the crew stand on regolith in front.
 _box(Vector3(1.8,0.12,0.65),Vector3(0,1.05,1.35),Color("bec8d2"))
 for x in [-0.73,0.73]:
  _box(Vector3(0.15,0.94,0.48),Vector3(x,0.55,1.35),Color("596270"))
 _box(Vector3(1.7,0.05,0.03),Vector3(0,1.03,1.69),accent,true)
 match station_id:
  "maya_station":
   var screen := _box(Vector3(1.35,0.58,0.08),Vector3(0,1.45,1.2),Color("0d2335"))
   screen.rotation_degrees.x = -12
   for i in range(4):
    _box(Vector3(0.95-i*0.15,0.025,0.02),Vector3(-0.1,1.3+i*0.1,1.28),accent,true)
   _box(Vector3(0.06,1.25,0.06),Vector3(1.5,2.0,-0.5),Color("b9c8d5"))
   _box(Vector3(0.65,0.045,0.045),Vector3(1.5,2.55,-0.5),accent)
  "alex_station":
   for i in range(3):
    _box(Vector3(0.29,0.25,0.3),Vector3(-0.58+i*0.38,1.24,1.4),Color("d7e3e4"))
    _box(Vector3(0.23,0.025,0.24),Vector3(-0.58+i*0.38,1.38,1.4),accent,true)
   _box(Vector3(0.12,0.55,0.12),Vector3(0.66,1.39,1.18),Color("a0aeba"))
   _box(Vector3(0.38,0.12,0.18),Vector3(0.55,1.65,1.26),Color("eef2f6"))
  "sam_station":
   _box(Vector3(0.9,0.4,0.35),Vector3(-0.3,1.32,1.35),Color("d28b3e"))
   _box(Vector3(0.38,0.045,0.06),Vector3(-0.3,1.55,1.35),Color("263443"))
   for i in range(3):
    _box(Vector3(0.06,0.04,0.32),Vector3(0.33+i*0.16,1.14,1.4),Color("b9c8d5"))
 # Move the equipment forward; keep consoles and tools human-sized.
 for index in range(equipment_start, get_child_count()):
  (get_child(index) as Node3D).position.z += 1.65
 var sign := Label3D.new()
 sign.name = "StationSign"
 sign.text = DEFINITIONS[station_id].name.to_upper()
 sign.font = preload("res://Assets/fonts/PublicSans-Variable.ttf")
 sign.font_size = 40
 sign.pixel_size = 0.003
 sign.position = Vector3(0,2.85,3.0)
 sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
 sign.modulate = accent
 add_child(sign)
func _box(size_: Vector3, at: Vector3, color: Color, glow := false) -> MeshInstance3D:
 var visual := MeshInstance3D.new()
 var box := BoxMesh.new()
 box.size = size_
 visual.mesh = box
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.metallic = 0.4
 mat.roughness = 0.65
 mat.emission_enabled = glow
 mat.emission = color
 mat.emission_energy_multiplier = 0.6
 visual.material_override = null
 visual.mesh.material = mat
 add_child(visual)
 visual.position = at
 return visual

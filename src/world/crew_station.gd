extends Node3D
## Walk-up workstations using NASA's HDU shell and game-authored work equipment.
@export var station_id := "maya_station"
const DEFINITIONS := {
 "maya_station": {"name": "Maya · Operations", "npc": "crew_briefing", "color": Color("42d9e2")},
 "alex_station": {"name": "Alex · Science", "npc": "water_recycler", "color": Color("7fbdff")},
 "sam_station": {"name": "Sam · Engineering", "npc": "food_storage", "color": Color("ffb653")}
}
const DOCK := Vector3(0, 0, 4.4)
# Every station building is scaled 1.3x to match the radiation habitat (~13 m);
# desks and consoles stay human-sized.
const SCALE := 1.3
# Metres: full-height crew outpost shells, with human-sized outdoor equipment.
static func _scale(_id: String) -> float:
 return SCALE
static func footprint(id: String) -> Vector2:
 return Vector2(5.1, 3.8) * _scale(id)
## The desk moves forward with the platform edge so crew still stand on regolith.
static func dock(id: String) -> Vector3:
 return DOCK + Vector3(0, 0, (_scale(id) - 1.0) * 3.7)
static func clearance_height(id: String) -> float:
 return 5.7 * _scale(id) + 0.1
func _ready() -> void:
 var accent: Color = DEFINITIONS[station_id].color
 var grow := (_scale(station_id) - 1.0) * 3.7
 var building := Node3D.new()
 building.name = "StationBuilding"
 add_child(building)
 if station_id == "maya_station":
  _operations(building, accent)
 else:
  var shell := preload("res://Assets/stations/hdu_1.glb").instantiate() as Node3D
  building.add_child(shell)
  preload("res://src/world/imported_asset_fit.gd").fit(shell, 9.6)
  shell.name = "HabitatShell"
  shell.position.z -= 0.7
  _part(building, _box_mesh(Vector3(10.0,0.08,7.4)), Vector3(0,0.04,0), Color("4b5260"))
  for x in [-4.9,4.9]:
   _part(building, _box_mesh(Vector3(0.04,0.025,7.2)), Vector3(x,0.095,0), accent, true)
 building.scale = Vector3.ONE * _scale(station_id)
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
  (get_child(index) as Node3D).position.z += 1.65 + grow
 var sign := Label3D.new()
 sign.name = "StationSign"
 sign.text = DEFINITIONS[station_id].name.to_upper()
 sign.font = preload("res://Assets/fonts/PublicSans-Variable.ttf")
 sign.font_size = 40
 sign.pixel_size = 0.003
 sign.position = Vector3(0,2.85,3.0 + grow)
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

## Lunar operations control tower in an agency-style livery (local metres; the whole
## building is scaled by SCALE). Octagonal parts turn PI/8 so a flat face points at
## the desk. Markings are the game's own: no NASA insignia or logotype is used,
## because NASA's emblems need agency permission and would imply endorsement.
func _operations(into: Node3D, accent: Color) -> void:
 var hull := Color("e6eaee")
 var trim := Color("5a6573")
 var navy := Color("0b3d91")
 var red := Color("c8102e")
 var centre := Vector3(0, 0, -1.2)
 _part(into, _box_mesh(Vector3(10.0,0.08,7.4)), Vector3(0,0.04,0), Color("4b5260"))
 for x in [-4.9, 4.9]:
  _part(into, _box_mesh(Vector3(0.04,0.025,7.2)), Vector3(x,0.095,0), accent, true)
 _octagon(into, 2.65, 2.4, centre + Vector3(0,1.28,0), hull)
 for k in 8:
  var angle := TAU * k / 8.0 + PI / 8.0
  _part(into, _box_mesh(Vector3(0.14,2.4,0.14)), centre + Vector3(sin(angle),0,cos(angle)) * 2.66 + Vector3(0,1.28,0), trim)
 # Classic blue-and-red livery bands below the control room.
 _octagon(into, 2.68, 0.22, centre + Vector3(0,2.22,0), navy)
 _octagon(into, 2.68, 0.07, centre + Vector3(0,2.06,0), red)
 _octagon(into, 2.69, 0.05, centre + Vector3(0,2.5,0), accent, true)
 # Control room glazing flares outward like an airport tower cab.
 var cab := _part(into, _cylinder_mesh(2.9,2.55,0.95,8), centre + Vector3(0,3.0,0), Color("16384f"), true)
 cab.rotation.y = PI / 8.0
 for k in 8:
  var angle := TAU * k / 8.0 + PI / 8.0
  var out := Vector3(sin(angle), 0, cos(angle))
  var mullion := _part(into, _box_mesh(Vector3(0.08,1.0,0.08)), centre + out * 2.72 + Vector3(0,3.0,0), trim)
  mullion.basis = Basis(Quaternion(Vector3.UP, (Vector3.UP + out * 0.37).normalized()))
 _octagon(into, 3.05, 0.2, centre + Vector3(0,3.58,0), trim)
 var roof := _part(into, _cylinder_mesh(1.4,2.2,0.35,8), centre + Vector3(0,3.85,0), hull)
 roof.rotation.y = PI / 8.0
 # Front airlock: 1.15 m local door, about 1.5 m at the tower's scale.
 var airlock := _part(into, _cylinder_mesh(0.9,0.9,1.4), Vector3(0,1.0,1.5), hull)
 airlock.rotation_degrees.x = 90
 var collar := _part(into, _cylinder_mesh(0.95,0.95,0.12), Vector3(0,1.0,2.16), navy)
 collar.rotation_degrees.x = 90
 _part(into, _box_mesh(Vector3(0.7,1.15,0.06)), Vector3(0,0.66,2.22), Color("39424f"))
 _part(into, _box_mesh(Vector3(0.4,0.22,0.04)), Vector3(0,1.0,2.26), accent, true)
 for x in [-0.42, 0.42]:
  _part(into, _box_mesh(Vector3(0.06,1.15,0.04)), Vector3(x,0.66,2.24), Color("e8a33d"))
 # Facade markings: name plate, mission emblem, flag and station number.
 var front := _face(into, centre, 0.0, 2.22)
 # White lettering on the navy band.
 _stencil(front, "LUNAR OPERATIONS CENTER", 0.12, Color("f2f4f6"))
 _emblem(_face(into, centre, -PI / 4.0, 1.25), navy)
 _flag(_face(into, centre, PI / 4.0, 1.3), navy, red)
 for angle in [PI / 2.0, -PI / 2.0, PI]:
  _stencil(_face(into, centre, angle, 1.2), "OPS-1", 0.35, navy)
 # Roof uplink and antenna.
 _part(into, _cylinder_mesh(0.12,0.2,0.6), centre + Vector3(-0.9,4.3,0.3), trim)
 var dish := _part(into, _dish_mesh(0.95), centre + Vector3(-0.9,4.75,0.3), Color("eef2f6"))
 # Flipped hemisphere so the bowl opens upward, tilted toward Earth.
 dish.rotation_degrees = Vector3(140, 0, -15)
 _part(into, _cylinder_mesh(0.06,0.06,1.6), centre + Vector3(1.0,4.8,-0.4), Color("b9c8d5"))
 for i in 3:
  _part(into, _box_mesh(Vector3(0.7-i*0.18,0.04,0.04)), centre + Vector3(1.0,4.4+i*0.4,-0.4), Color("b9c8d5"))
 _part(into, _sphere_mesh(0.11), centre + Vector3(1.0,5.55,-0.4), red, true)

func _octagon(into: Node3D, radius: float, height: float, at: Vector3, color: Color, glow := false) -> void:
 var ring := _part(into, _cylinder_mesh(radius,radius,height,8), at, color, glow)
 ring.rotation.y = PI / 8.0

## A frame lying on the octagon face at `angle`, just proud of the wall; +z faces out.
func _face(into: Node3D, centre: Vector3, angle: float, height: float) -> Node3D:
 var face := Node3D.new()
 face.basis = Basis(Vector3.UP, angle)
 face.position = centre + Vector3(sin(angle), 0, cos(angle)) * (2.65 * cos(PI / 8.0) + 0.02) + Vector3(0, height, 0)
 into.add_child(face)
 return face

func _stencil(face: Node3D, text: String, height: float, color: Color) -> void:
 var label := Label3D.new()
 label.text = text
 label.font = preload("res://Assets/fonts/PublicSans-Variable.ttf")
 label.font_size = 64
 label.pixel_size = height / 64.0
 label.modulate = color
 label.outline_size = 0
 label.position.z = 0.01
 face.add_child(label)

## The game's own mission patch: navy disc, gold ring, a white peak and a low Sun.
func _emblem(face: Node3D, navy: Color) -> void:
 var disc := _part(face, _cylinder_mesh(0.6,0.6,0.03), Vector3.ZERO, navy)
 disc.rotation.x = PI / 2.0
 var ring := _part(face, _torus_mesh(0.52,0.58), Vector3(0,0,0.02), Color("d6a730"))
 ring.rotation.x = PI / 2.0
 var peak := _part(face, _cylinder_mesh(0.0,0.34,0.03,3), Vector3(-0.05,-0.08,0.03), Color("f2f4f6"))
 peak.rotation.x = -PI / 2.0
 _part(face, _sphere_mesh(0.09), Vector3(0.24,0.16,0.04), Color("ffd35a"), true)
 _part(face, _box_mesh(Vector3(0.7,0.03,0.02)), Vector3(0,-0.3,0.04), Color("f2f4f6"))

## Simplified flag: seven red and white stripes with a navy canton.
func _flag(face: Node3D, navy: Color, red: Color) -> void:
 for i in 7:
  _part(face, _box_mesh(Vector3(1.2,0.1,0.02)), Vector3(0,0.3 - i * 0.1,0), red if i % 2 == 0 else Color("f2f4f6"))
 _part(face, _box_mesh(Vector3(0.5,0.4,0.03)), Vector3(-0.35,0.15,0.01), navy)

func _part(into: Node3D, mesh: PrimitiveMesh, at: Vector3, color: Color, glow := false) -> MeshInstance3D:
 var visual := MeshInstance3D.new()
 visual.mesh = mesh
 # Surface material, not override: placement swaps material_override for its ghost.
 var mat := StandardMaterial3D.new()
 mat.albedo_color = color
 mat.metallic = 0.35
 mat.roughness = 0.55
 mat.emission_enabled = glow
 mat.emission = color
 mat.emission_energy_multiplier = 0.8
 mesh.material = mat
 visual.position = at
 into.add_child(visual)
 return visual

func _box_mesh(size_: Vector3) -> BoxMesh:
 var box := BoxMesh.new()
 box.size = size_
 return box

func _cylinder_mesh(top: float, bottom: float, height: float, segments := 32) -> CylinderMesh:
 var cylinder := CylinderMesh.new()
 cylinder.top_radius = top
 cylinder.bottom_radius = bottom
 cylinder.height = height
 cylinder.radial_segments = segments
 return cylinder

func _sphere_mesh(radius: float) -> SphereMesh:
 var sphere := SphereMesh.new()
 sphere.radius = radius
 sphere.height = radius * 2.0
 return sphere

func _torus_mesh(inner: float, outer: float) -> TorusMesh:
 var torus := TorusMesh.new()
 torus.inner_radius = inner
 torus.outer_radius = outer
 return torus

## Shallow dish: a flattened hemisphere bowl.
func _dish_mesh(radius: float) -> SphereMesh:
 var bowl := SphereMesh.new()
 bowl.radius = radius
 bowl.height = radius * 0.5
 bowl.is_hemisphere = true
 return bowl

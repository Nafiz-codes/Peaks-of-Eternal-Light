extends Node3D
## Game-authored regolith radiation shelter (metres): habitat modules half-buried in a
## mound of bulldozed regolith, with a hatch ring on the crown and a utility culvert.
## Regolith overburden is the shielding; the modules are where the crew shelters.
## Built in _init because NASABuildings.make measures it before it enters the tree.

const MOUND_RADIUS := 3.6
const MOUND_HEIGHT := 2.3
# Module bearings (radians) and length; each is centred where it meets the mound wall.
const MODULES := [0.45, 2.55, 4.55]
const MODULE_LENGTH := 2.8
## Regolith skirt below y=0 that sinks into uneven ground so the mound never floats.
const SKIRT := 0.5

func _init() -> void:
	# y=0 here is ground level. Bounding boxes of the rotated modules dip below it,
	# so NASABuildings.make must not rest the model on its measured bottom.
	set_meta("ground_at_origin", true)
	var regolith := _mat("6d6a66", 0.0, 1.0)
	var disturbed := _mat("55524f", 0.0, 1.0)
	var shell := _mat("d6d9d6", 0.25, 0.5)
	var rib := _mat("9aa0a6", 0.5, 0.45)
	var gold := _mat("c9a24a", 0.8, 0.35)
	var dark := _mat("2c3138", 0.5, 0.6)
	var window := _mat("ffd9a0", 0.0, 0.3)
	window.emission_enabled = true
	window.emission = Color("ffc878")
	window.emission_energy_multiplier = 1.2

	_cylinder("Foundation", MOUND_RADIUS + 0.7, MOUND_RADIUS + 0.9, 0.06 + SKIRT, Vector3(0, 0.06 - (0.06 + SKIRT) * 0.5, 0), disturbed)
	_add("RegolithMound", _mound_mesh(), Vector3.ZERO, regolith)

	# Crown hatch: the access ring set into the top of the mound.
	var crown := MOUND_HEIGHT - 0.1
	_add("HatchRing", _torus_mesh(1.0, 1.3), Vector3(0, crown, 0), shell)
	_add("HatchTrim", _torus_mesh(0.95, 1.02), Vector3(0, crown + 0.1, 0), gold)
	_cylinder("Hatch", 1.0, 1.0, 0.1, Vector3(0, crown + 0.02, 0), dark)

	for bearing in MODULES:
		_module(bearing, shell, rib, gold, dark, window)

	# Utility culvert running out of the mound at ground level.
	var out := Vector3(sin(3.6), 0, cos(3.6))
	var culvert := _cylinder("Culvert", 0.38, 0.38, 1.4, out * 3.3 + Vector3(0, 0.38, 0), rib)
	culvert.basis = Basis(Quaternion(Vector3.UP, out))
	var mouth := _cylinder("CulvertMouth", 0.3, 0.3, 0.02, out * 4.01 + Vector3(0, 0.38, 0), dark)
	mouth.basis = Basis(Quaternion(Vector3.UP, out))

	# Loose regolith clods left by the excavators.
	for i in 7:
		var angle := 0.9 * i + 0.3
		var clod := _sphere("RegolithClod", 0.22 + 0.06 * (i % 3), Vector3(sin(angle), 0, cos(angle)) * (MOUND_RADIUS + 0.4 + 0.15 * (i % 2)) + Vector3(0, 0.08, 0), regolith)
		clod.scale = Vector3(1.2, 0.6, 1.0)

## One cylindrical module: buried inner half, ribbed shell, domed end cap, lit door and pad.
func _module(bearing: float, shell: Material, rib: Material, gold: Material, dark: Material, window: Material) -> void:
	var out := Vector3(sin(bearing), 0, cos(bearing))
	var across := Vector3(cos(bearing), 0, -sin(bearing))
	var axis := Basis(Quaternion(Vector3.UP, out))
	var centre := out * 3.4 + Vector3(0, 0.95, 0)
	var body := _cylinder("ShelterModule", 0.9, 0.9, MODULE_LENGTH, centre, shell)
	body.basis = axis
	for step in [0.25, 0.75, 1.25]:
		var ring := _add("ModuleRib", _torus_mesh(0.88, 0.97), centre + out * step, rib)
		ring.basis = axis
	var band := _box("TrimBand", Vector3(0.08, 0.1, 1.1), centre + out * 0.5 + Vector3(0, 0.86, 0), gold)
	band.basis = Basis(Vector3.UP, bearing)
	var end := centre + out * MODULE_LENGTH * 0.5
	var cap := _sphere("EndCap", 0.9, end, shell)
	cap.basis = axis * Basis.from_scale(Vector3(1, 0.28, 1))
	# Door faces outward on the end cap, with a warm-lit window above the handle.
	var door := _box("Door", Vector3(0.9, 1.4, 0.08), end + out * 0.22 + Vector3(0, -0.08, 0), dark)
	door.basis = Basis(Vector3.UP, bearing)
	var pane := _box("DoorWindow", Vector3(0.6, 0.45, 0.04), end + out * 0.27 + Vector3(0, 0.25, 0), window)
	pane.basis = Basis(Vector3.UP, bearing)
	for side in [-1, 1]:
		var light := _box("SideWindow", Vector3(0.05, 0.22, 0.22), centre + out * 0.6 + across * side * 0.9 + Vector3(0, 0.25, 0), window)
		light.basis = Basis(Vector3.UP, bearing)
	var ramp := _box("AccessRamp", Vector3(1.1, 0.06, 1.0), end + out * 0.75 + Vector3(0, -0.92, 0), rib)
	ramp.basis = Basis(Vector3.UP, bearing) * Basis(Vector3.RIGHT, 0.12)

## Squashed hemisphere with gentle noise lumps; the lower half becomes a shallow skirt
## below ground, so the mound meets sloping terrain without a gap.
func _mound_mesh() -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radial_segments = 48
	sphere.rings = 24
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 2.5
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var unit := points[index] / 0.5
		var swell := 1.0 + 0.07 * noise.get_noise_3dv(unit)
		var point := Vector3(unit.x * MOUND_RADIUS, unit.y * (MOUND_HEIGHT if unit.y > 0.0 else SKIRT), unit.z * MOUND_RADIUS) * swell
		# Bulldozed flat on top so the hatch ring seats on it.
		point.y = minf(point.y, MOUND_HEIGHT - 0.1)
		surface.add_vertex(point)
	# Positions only, so index() welds the UV seam and normals come out smooth.
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _mat(color: String, metallic: float, roughness: float) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(color)
	material.metallic = metallic
	material.roughness = roughness
	return material

func _add(title: String, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.name = title
	instance.mesh = mesh
	instance.position = at
	instance.material_override = material
	add_child(instance)
	return instance

func _box(title: String, size: Vector3, at: Vector3, material: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _add(title, box, at, material)

func _cylinder(title: String, top: float, bottom: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	cylinder.radial_segments = 32
	return _add(title, cylinder, at, material)

func _sphere(title: String, radius: float, at: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	return _add(title, sphere, at, material)

func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 48
	return torus

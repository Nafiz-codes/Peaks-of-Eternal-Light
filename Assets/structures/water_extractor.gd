extends Node3D
## Game-authored thermal ice extractor (metres): a block of ice is heated in the
## upper cradle and its condensate drips into the glass reservoir below.
## Built in _init because NASABuildings.make measures it before it enters the tree.

const DROP_TOP := 2.16
const WATER_Y := 1.42
const DROPS := 3
const FORM_S := 0.55
# Fall time for 0.74 m under lunar gravity (1.62 m/s²): sqrt(2 * 0.74 / 1.62).
const FALL_S := 0.96
const CYCLE_S := FORM_S + FALL_S

var _drops: Array[MeshInstance3D] = []
var _ripples: Array[MeshInstance3D] = []
var _ripple_materials: Array[StandardMaterial3D] = []
var _clock := 0.0

func _init() -> void:
	var hull := _mat("8796a8", 0.55, 0.5)
	var dark := _mat("39424f", 0.6, 0.6)
	var orange := _mat("d8962c", 0.3, 0.55)
	var copper := _mat("a8673f", 0.7, 0.4)
	var ice := _mat("9fd6f5", 0.0, 0.2)
	ice.emission_enabled = true
	ice.emission = Color("4aa8e8")
	ice.emission_energy_multiplier = 0.45
	var ice_shell := _mat("c7ebff", 0.0, 0.04)
	ice_shell.albedo_color.a = 0.55
	ice_shell.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ice_shell.specular = 0.9
	ice_shell.rim_enabled = true
	ice_shell.rim = 0.5
	ice_shell.emission_enabled = true
	ice_shell.emission = Color("6cc0f0")
	ice_shell.emission_energy_multiplier = 0.15
	var glass := _mat("cfe6f5", 0.0, 0.05)
	glass.albedo_color.a = 0.22
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var water := _mat("2f7fd0", 0.0, 0.05)
	water.albedo_color.a = 0.8
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.emission_enabled = true
	water.emission = Color("1d5d9c")
	water.emission_energy_multiplier = 0.25

	# Base: armoured ring, deck, splayed anchor feet and orange cross bracing.
	_cylinder("Foundation", 2.0, 2.05, 0.32, Vector3(0, 0.16, 0), hull)
	_cylinder("Deck", 1.62, 1.62, 0.38, Vector3(0, 0.19, 0), dark)
	for i in 8:
		var angle := TAU * i / 8.0
		var out := Vector3(sin(angle), 0, cos(angle))
		var foot := _box("AnchorFoot", Vector3(0.55, 0.22, 0.8), out * 2.1 + Vector3(0, 0.11, 0), hull)
		foot.rotation.y = angle
		var vent := _box("Vent", Vector3(0.4, 0.06, 0.04), out * 2.06 + Vector3(0, 0.22, 0), orange)
		vent.rotation.y = angle
	for i in 4:
		var brace := _box("Bracing", Vector3(3.1, 0.04, 0.08), Vector3(0, 0.4, 0), orange)
		brace.rotation.y = PI * i / 4.0
	for x in [-0.18, 0.18]:
		_bar("Hose", Vector3(x, 0.55, 0.9), Vector3(x * 1.6, 0.3, 1.8), 0.08, copper)

	# Pedestal and reservoir. Transparent parts use the mesh's own material so
	# confirmed buildings keep an opaque material_override everywhere.
	_cylinder("Pedestal", 0.95, 1.05, 0.45, Vector3(0, 0.605, 0), hull)
	var tank := _cylinder("Reservoir", 0.72, 0.72, 1.0, Vector3(0, 1.33, 0), null)
	(tank.mesh as CylinderMesh).cap_top = false
	(tank.mesh as PrimitiveMesh).material = glass
	var level := _cylinder("Water", 0.69, 0.69, 0.58, Vector3(0, WATER_Y - 0.29, 0), null)
	(level.mesh as PrimitiveMesh).material = water
	for y in [0.86, 1.83]:
		_torus("ReservoirRim", 0.7, 0.8, Vector3(0, y, 0), dark)
	for i in 4:
		var angle := TAU * (i + 0.5) / 4.0
		_box("ReservoirRib", Vector3(0.06, 0.97, 0.06), Vector3(sin(angle), 0, cos(angle)) * 0.76 + Vector3(0, 1.345, 0), dark)

	# Four struts carry the heated cradle, as on a drill-rig tripod.
	for i in 4:
		var angle := TAU * (i + 0.5) / 4.0
		var out := Vector3(sin(angle), 0, cos(angle))
		var side := Vector3(cos(angle), 0, -sin(angle)) * 0.11
		var low := out * 1.65 + Vector3(0, 0.38, 0)
		var high := out * 1.05 + Vector3(0, 2.55, 0)
		for offset in [side, -side]:
			_bar("Strut", low + offset, high + offset, 0.05, hull)
		for k in range(1, 5):
			var at := low.lerp(high, k / 5.0)
			_bar("StrutRung", at + side, at - side, 0.025, dark)
		for joint_at in [low, high]:
			var joint := _cylinder("StrutJoint", 0.1, 0.1, 0.3, joint_at, copper)
			joint.rotation = Vector3(0, angle, PI / 2)

	# Cradle, condensate funnel and the nozzle the drops form on.
	_torus("Cradle", 0.95, 1.18, Vector3(0, 2.6, 0), hull)
	_cylinder("HeaterPlate", 1.0, 1.0, 0.1, Vector3(0, 2.52, 0), copper)
	_cylinder("Funnel", 0.7, 0.08, 0.32, Vector3(0, 2.31, 0), dark)
	_cylinder("Nozzle", 0.035, 0.035, 0.08, Vector3(0, DROP_TOP + 0.04, 0), copper)

	# One smooth, uneven lump of ice: a clear shell around a glowing blue core.
	var centre := Vector3(0, 3.0, 0)
	var shell := _add("Ice", _ice_mesh(0.9, 1.2, 7), centre, null)
	shell.rotation.y = 0.6
	(shell.mesh as ArrayMesh).surface_set_material(0, ice_shell)
	var core := _add("IceCore", _ice_mesh(0.62, 0.8, 11), centre + Vector3(0, -0.04, 0), ice)
	core.rotation.y = -0.4

	# Drops and the ripples they leave on the reservoir surface.
	for i in DROPS:
		var drop := _sphere("Drip", 0.035, 0.1, Vector3(0, DROP_TOP, 0), null)
		(drop.mesh as PrimitiveMesh).material = water
		_drops.append(drop)
		var ripple_material := water.duplicate() as StandardMaterial3D
		var ripple := _torus("DripRipple", 0.04, 0.06, Vector3(0, WATER_Y + 0.005, 0), null)
		(ripple.mesh as PrimitiveMesh).material = ripple_material
		_ripples.append(ripple)
		_ripple_materials.append(ripple_material)
	_animate()

func _process(delta: float) -> void:
	_clock += delta
	_animate()

func _animate() -> void:
	for i in DROPS:
		var age := fposmod(_clock - CYCLE_S * i / DROPS, CYCLE_S)
		var drop := _drops[i]
		if age < FORM_S:
			# The bead swells on the nozzle before it lets go.
			drop.position.y = DROP_TOP
			drop.scale = Vector3.ONE * lerpf(0.3, 1.0, age / FORM_S)
		else:
			var t := (age - FORM_S) / FALL_S
			drop.position.y = lerpf(DROP_TOP, WATER_Y, t * t)
			drop.scale = Vector3(0.85, 1.25, 0.85)
		# The ripple belongs to the previous drop of this slot, which landed at age 0.
		var spread := clampf(age / 0.8, 0.0, 1.0)
		_ripples[i].scale = Vector3.ONE * lerpf(1.0, 9.0, spread)
		_ripples[i].visible = spread < 1.0
		_ripple_materials[i].albedo_color.a = 0.7 * (1.0 - spread)

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
	if material != null: instance.material_override = material
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
	return _add(title, cylinder, at, material)

func _sphere(title: String, radius: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 8
	sphere.rings = 4
	return _add(title, sphere, at, material)

## Smooth sphere pushed out of round by noise, with the base flattened where it rests.
func _ice_mesh(radius: float, height: float, seed_: int) -> ArrayMesh:
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = height
	sphere.radial_segments = 32
	sphere.rings = 16
	var arrays := sphere.get_mesh_arrays()
	var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var noise := FastNoiseLite.new()
	noise.seed = seed_
	noise.frequency = 1.4
	var floor_y := -0.25 * height
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in indices:
		var point := points[index] * (1.0 + 0.3 * noise.get_noise_3dv(points[index]))
		if point.y < floor_y: point.y = lerpf(point.y, floor_y, 0.6)
		surface.add_vertex(point)
	# Positions only, so index() welds the UV seam and normals come out smooth.
	surface.index()
	surface.generate_normals()
	return surface.commit()

func _torus(title: String, inner: float, outer: float, at: Vector3, material: Material) -> MeshInstance3D:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	return _add(title, torus, at, material)

func _bar(title: String, from: Vector3, to: Vector3, radius: float, material: Material) -> void:
	var instance := _cylinder(title, radius, radius, from.distance_to(to), (from + to) * 0.5, material)
	instance.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))

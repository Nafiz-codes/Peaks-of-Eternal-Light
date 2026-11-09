extends Node3D
## Game-authored geodesic greenhouse (metres): a glass dome on a ring foundation over
## four rows of tiered grow racks. Built in _init because NASABuildings.make measures
## it before it enters the tree. Repeated parts are merged into single meshes.

const RADIUS := 4.0
const BASE_H := 0.3
const TIERS := [0.45, 1.15, 1.85, 2.55]
const ROWS := [-2.2, -0.8, 0.8, 2.2]
const SHELF_DEPTH := 0.6

func _init() -> void:
	var hull := _mat("8796a8", 0.55, 0.5)
	var dark := _mat("39424f", 0.6, 0.6)
	var white := _mat("dfe6ea", 0.2, 0.45)
	var frame := _mat("2b323b", 0.7, 0.35)
	var grass := _mat("ffffff", 0.0, 0.85)
	grass.vertex_color_use_as_albedo = true
	grass.cull_mode = BaseMaterial3D.CULL_DISABLED
	grass.emission_enabled = true
	grass.emission = Color("2f7a22")
	grass.emission_energy_multiplier = 0.15
	var soil := _mat("4a3a2c", 0.0, 1.0)
	var lamp := _mat("f4fbff", 0.0, 0.3)
	lamp.emission_enabled = true
	lamp.emission = Color("eaf6ff")
	lamp.emission_energy_multiplier = 2.0
	var glass := _mat("d8eef8", 0.0, 0.03)
	glass.albedo_color.a = 0.16
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	glass.specular = 0.9

	_cylinder("Foundation", RADIUS + 0.25, RADIUS + 0.35, BASE_H, Vector3(0, BASE_H * 0.5, 0), hull)
	_cylinder("Floor", RADIUS - 0.05, RADIUS - 0.05, 0.04, Vector3(0, BASE_H + 0.02, 0), white)
	_add("BaseRing", _torus_mesh(RADIUS - 0.04, RADIUS + 0.12), Vector3(0, BASE_H, 0), dark)

	# Geodesic dome: frequency-4 icosphere, upper hemisphere only.
	var dome := _geodesic(2)
	var points: PackedVector3Array = dome[0]
	var faces: Array = dome[1]
	var panes := SurfaceTool.new()
	panes.begin(Mesh.PRIMITIVE_TRIANGLES)
	var struts := SurfaceTool.new()
	struts.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edges := {}
	var hubs := {}
	var lift := Vector3(0, BASE_H, 0)
	for face in faces:
		for corner in face:
			panes.set_normal(points[corner])
			panes.add_vertex(points[corner] * RADIUS + lift)
			hubs[corner] = true
		for k in 3:
			var a: int = face[k]
			var b: int = face[(k + 1) % 3]
			edges[Vector2i(mini(a, b), maxi(a, b))] = true
	var bar := CylinderMesh.new()
	bar.top_radius = 0.045
	bar.bottom_radius = 0.045
	bar.height = 1.0
	bar.radial_segments = 6
	bar.rings = 1
	for edge in edges:
		var from: Vector3 = points[edge.x] * RADIUS + lift
		var to: Vector3 = points[edge.y] * RADIUS + lift
		var basis_ := Basis(Quaternion(Vector3.UP, (to - from).normalized())).scaled(Vector3(1, from.distance_to(to), 1))
		struts.append_from(bar, 0, Transform3D(basis_, (from + to) * 0.5))
	var hub := SphereMesh.new()
	hub.radius = 0.1
	hub.height = 0.2
	hub.radial_segments = 8
	hub.rings = 4
	for corner in hubs:
		struts.append_from(hub, 0, Transform3D(Basis(), points[corner] * RADIUS + lift))
	var shell := _add("Dome", panes.commit(), Vector3.ZERO, null)
	(shell.mesh as ArrayMesh).surface_set_material(0, glass)
	_add("DomeFrame", struts.commit(), Vector3.ZERO, frame)

	# Tiered grow racks: shelves, a planted tray per shelf and an LED bar above it.
	var racks := SurfaceTool.new()
	racks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var plants := SurfaceTool.new()
	plants.begin(Mesh.PRIMITIVE_TRIANGLES)
	var beds := SurfaceTool.new()
	beds.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var lights := SurfaceTool.new()
	lights.begin(Mesh.PRIMITIVE_TRIANGLES)
	var post := BoxMesh.new()
	post.size = Vector3(0.06, 1.0, 0.06)
	var shelf := BoxMesh.new()
	shelf.size = Vector3(1.0, 0.04, SHELF_DEPTH)
	var tray := BoxMesh.new()
	tray.size = Vector3(1.0, 0.08, SHELF_DEPTH * 0.9)
	var led := BoxMesh.new()
	led.size = Vector3(1.0, 0.03, 0.12)
	for z in ROWS:
		for y in TIERS:
			# Shelf length follows the dome wall at that height and row.
			var half := sqrt(maxf(0.0, RADIUS * RADIUS - z * z - (y + 0.55) * (y + 0.55))) - 0.45
			if half < 0.4: continue
			var at := Vector3(0, BASE_H + y, z)
			racks.append_from(shelf, 0, Transform3D(Basis().scaled(Vector3(half * 2.0, 1, 1)), at))
			beds.append_from(tray, 0, Transform3D(Basis().scaled(Vector3(half * 2.0 - 0.1, 1, 1)), at + Vector3(0, 0.06, 0)))
			lights.append_from(led, 0, Transform3D(Basis().scaled(Vector3(half * 2.0 - 0.2, 1, 1)), at + Vector3(0, 0.6, 0)))
			# Dense grass: four staggered rows of blades across the tray.
			var x := -half + 0.1
			while x < half - 0.1:
				for row in 4:
					var jitter := Vector3(rng.randf_range(-0.03, 0.03), 0.1, (row - 1.5) * 0.12 + rng.randf_range(-0.03, 0.03))
					_blade(plants, at + Vector3(x, 0, 0) + jitter, rng)
				x += 0.07
			for end in [-half, half]:
				racks.append_from(post, 0, Transform3D(Basis().scaled(Vector3(1, 0.7, 1)), at + Vector3(end, 0.35, 0)))
	_add("Racks", racks.commit(), Vector3.ZERO, white)
	_add("Soil", beds.commit(), Vector3.ZERO, soil)
	_add("Plants", plants.commit(), Vector3.ZERO, grass)
	_add("GrowLights", lights.commit(), Vector3.ZERO, lamp)
	# Central service column reaching the dome crown, as in a vertical farm.
	_cylinder("ServiceColumn", 0.18, 0.18, RADIUS - 0.3, Vector3(0, BASE_H + (RADIUS - 0.3) * 0.5, 0), white)

## Frequency 2^subdivisions icosphere with a vertex at the top; returns the unit
## points and the faces wholly in the upper hemisphere (even frequency puts an
## edge ring exactly on the equator).
func _geodesic(subdivisions: int) -> Array:
	var t := (1.0 + sqrt(5.0)) / 2.0
	var raw := [Vector3(-1, t, 0), Vector3(1, t, 0), Vector3(-1, -t, 0), Vector3(1, -t, 0), Vector3(0, -1, t), Vector3(0, 1, t), Vector3(0, -1, -t), Vector3(0, 1, -t), Vector3(t, 0, -1), Vector3(t, 0, 1), Vector3(-t, 0, -1), Vector3(-t, 0, 1)]
	var up := Basis(Quaternion(raw[0].normalized(), Vector3.UP))
	var points := PackedVector3Array()
	for point in raw: points.append(up * point.normalized())
	var faces := [[0, 11, 5], [0, 5, 1], [0, 1, 7], [0, 7, 10], [0, 10, 11], [1, 5, 9], [5, 11, 4], [11, 10, 2], [10, 7, 6], [7, 1, 8], [3, 9, 4], [3, 4, 2], [3, 2, 6], [3, 6, 8], [3, 8, 9], [4, 9, 5], [2, 4, 11], [6, 2, 10], [8, 6, 7], [9, 8, 1]]
	for pass_ in subdivisions:
		var midpoints := {}
		var next := []
		for face in faces:
			var mid := []
			for k in 3:
				var a: int = face[k]
				var b: int = face[(k + 1) % 3]
				var key := Vector2i(mini(a, b), maxi(a, b))
				if not midpoints.has(key):
					midpoints[key] = points.size()
					points.append((points[a] + points[b]).normalized())
				mid.append(midpoints[key])
			next.append([face[0], mid[0], mid[2]])
			next.append([face[1], mid[1], mid[0]])
			next.append([face[2], mid[2], mid[1]])
			next.append([mid[0], mid[1], mid[2]])
		faces = next
	var upper := []
	for face in faces:
		if points[face[0]].y > -0.001 and points[face[1]].y > -0.001 and points[face[2]].y > -0.001:
			upper.append(face)
	return [points, upper]

## One tapered, leaning blade: dark at the root, bright at the tip.
func _blade(surface: SurfaceTool, base: Vector3, rng: RandomNumberGenerator) -> void:
	var height := rng.randf_range(0.14, 0.3)
	var yaw := rng.randf() * TAU
	var side := Vector3(cos(yaw), 0, sin(yaw)) * 0.014
	var lean := Vector3(sin(yaw), 0, -cos(yaw)) * rng.randf_range(0.02, 0.1)
	var mid := base + Vector3(0, height * 0.55, 0) + lean * 0.35
	var tip := base + Vector3(0, height, 0) + lean
	var root := Color("2f6b1f")
	var middle := Color("4f9a32")
	var top := Color(0.56, 0.82, 0.31).lerp(Color("c4e46a"), rng.randf() * 0.4)
	for vertex in [[base - side, root], [base + side, root], [mid + side * 0.6, middle], [base - side, root], [mid + side * 0.6, middle], [mid - side * 0.6, middle], [mid - side * 0.6, middle], [mid + side * 0.6, middle], [tip, top]]:
		surface.set_color(vertex[1])
		surface.set_normal(Vector3.UP)
		surface.add_vertex(vertex[0])

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

func _cylinder(title: String, top: float, bottom: float, height: float, at: Vector3, material: Material) -> MeshInstance3D:
	var cylinder := CylinderMesh.new()
	cylinder.top_radius = top
	cylinder.bottom_radius = bottom
	cylinder.height = height
	return _add(title, cylinder, at, material)

func _torus_mesh(inner: float, outer: float) -> TorusMesh:
	var torus := TorusMesh.new()
	torus.inner_radius = inner
	torus.outer_radius = outer
	torus.rings = 48
	return torus

extends Node3D
## Authored, navigable geological terrain, not a NASA elevation reconstruction.
const ORIGIN := Vector3(4000, 0, 0)
const LIMIT := 420.0
const SITES := {"alpha": Vector2(-100, 80), "beta": Vector2(-185, 205), "gamma": Vector2(-20, 260),
	"ice_a": Vector2(100, 100), "ice_b": Vector2(225, 165), "ice_c": Vector2(135, 285)}
static func height_at(x: float, z: float) -> float:
	var p := Vector2(x,z)
	var h := 1.8 * sin(x * 0.017) * sin(z * 0.014)
	for ridge in [Vector4(-210,170,26,65),Vector4(260,230,35,60),Vector4(20,350,38,65)]:
		h += ridge.z * exp(-pow((x-ridge.x)/ridge.w,2) - pow((z-ridge.y)/125.0,2))
	for crater in [Vector3(-20,300,38),Vector3(130,310,48),Vector3(70,150,22)]:
		var r: float = p.distance_to(Vector2(crater.x,crater.y))/crater.z
		h += 3.0*exp(-pow((r-1.0)/0.23,2))-4.0*exp(-pow(r/0.7,2))
	return h * smoothstep(12,45,p.length())
static func point(p: Vector2) -> Vector3:
	return ORIGIN + Vector3(p.x,height_at(p.x,p.y),p.y)
func _ready() -> void:
	position = ORIGIN
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(-105,105):
		for x in range(-105,105):
			for offset in [Vector2(0,0),Vector2(1,0),Vector2(0,1),Vector2(1,0),Vector2(1,1),Vector2(0,1)]:
				var p: Vector2 = (Vector2(x,z)+offset)*4
				surface.set_uv(p*0.12)
				surface.add_vertex(Vector3(p.x,height_at(p.x,p.y),p.y))
	surface.generate_normals()
	var ground := MeshInstance3D.new()
	ground.mesh = surface.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://src/world/regolith.gdshader")
	ground.material_override = material
	add_child(ground)
	ground.create_trimesh_collision()
	_add_horizon(material)
	# Solid perimeter below the visual horizon; never warp a moving rover.
	for edge in [Vector3(-415,40,0),Vector3(415,40,0),Vector3(0,40,-415),Vector3(0,40,415)]:
		var body := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(2,100,840) if edge.x != 0 else Vector3(840,100,2)
		shape.shape = box
		body.add_child(shape)
		body.position = edge
		add_child(body)
	# Sparse geology away from objective approach areas; shared mesh and material.
	var fallback := SphereMesh.new()
	fallback.radial_segments = 8
	fallback.rings = 4
	var mesh: Mesh = fallback
	var source := get_parent().get_parent().get_node_or_null("LunarHorizon/StoneHill_00_Rock_0")
	if source != null: mesh = source.mesh
	var rock_material := StandardMaterial3D.new()
	rock_material.albedo_color = Color("48474a")
	rock_material.roughness = 1
	var shelter := MeshInstance3D.new()
	shelter.name = "RescueShelterRock"
	shelter.mesh = mesh
	shelter.material_override = rock_material
	shelter.scale = Vector3(1.2,0.85,0.8)
	shelter.position = Vector3(65,height_at(65,256.2)+0.55,256.2)
	add_child(shelter)
	shelter.create_convex_collision()
	var rng := RandomNumberGenerator.new()
	rng.seed = 73129
	for i in range(130):
		var p := Vector2(rng.randf_range(-350,350),rng.randf_range(30,380))
		var safe := p.length() < 25
		for site in SITES.values(): safe = safe or p.distance_to(site) < 14
		# Keep a broad rescue corridor open; the escort records the driven route.
		if safe or (p.x > 0 and p.x < 95): continue
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = rock_material
		var size := rng.randf_range(0.5,4)
		rock.scale = Vector3(size*1.5,size,size*1.1)
		rock.position = Vector3(p.x,height_at(p.x,p.y)+size*0.3,p.y)
		add_child(rock)
		if size > 1.5: rock.create_convex_collision()

func _add_horizon(material: Material) -> void:
	var edge: Array[Vector2] = []
	for i in range(210): edge.append(Vector2(-420+i*4,-420))
	for i in range(210): edge.append(Vector2(420,-420+i*4))
	for i in range(210): edge.append(Vector2(420-i*4,420))
	for i in range(210): edge.append(Vector2(-420,420-i*4))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii := [420.0,520.0,750.0,1100.0,1800.0,2500.0]
	for r in range(radii.size()-1):
		for i in range(edge.size()):
			var corners: Array[Vector3] = []
			for pair in [[i,r],[(i+1)%edge.size(),r],[i,r+1],[(i+1)%edge.size(),r+1]]:
				var p: Vector2 = edge[pair[0]]*radii[pair[1]]/420.0
				var blend := smoothstep(420,900,p.length())
				var height := height_at(p.x,p.y)*(1-blend) - blend*p.length_squared()*0.0000008
				# Inner ring must meet the playable edge exactly.
				if pair[1] == 0: height = height_at(p.x,p.y)
				corners.append(Vector3(p.x,height,p.y))
			for j in [0,2,1,1,2,3]:
				surface.set_uv(Vector2(corners[j].x,corners[j].z)*0.12)
				surface.add_vertex(corners[j])
	surface.generate_normals()
	var horizon := MeshInstance3D.new()
	horizon.mesh = surface.commit()
	horizon.material_override = material
	add_child(horizon)

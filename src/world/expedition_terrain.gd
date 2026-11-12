extends Node3D
## Authored, navigable geological terrain, not a NASA elevation reconstruction.
const ORIGIN := Vector3(4000, 0, 0)
const LIMIT := 420.0
const SITES := {"alpha": Vector2(-300, -220), "beta": Vector2(-340, -30), "gamma": Vector2(-150, -310),
	"ice_a": Vector2(170, 220), "ice_b": Vector2(310, 170), "ice_c": Vector2(200, 340)}
const RESCUE_SITE := Vector2(290, -290)
const PHOTO_SITES := [Vector2(-296,-222), Vector2(-146,-312), Vector2(174,218), Vector2(294,-292)]
const RIDGES := [Vector4(-210,170,26,65),Vector4(260,230,35,60),Vector4(20,350,38,65),Vector4(-285,-120,19,70),Vector4(230,-145,22,80),Vector4(-315,320,16,65),Vector4(330,40,4,65)]

static func added_relief(p: Vector2, ridge_height: float) -> float:
	# Fade out before existing ridge shoulders; their geometry stays intact.
	var mask := 1.0 - smoothstep(1.0, 3.0, ridge_height)
	if mask == 0.0: return 0.0
	var relief := 0.0
	for ridge in [Vector4(-80,-190,11,60),Vector4(55,-300,14,65),Vector4(-230,-330,8,50),Vector4(-100,60,8,45),Vector4(100,280,9,40)]:
		var q := (p - Vector2(ridge.x,ridge.y)) / Vector2(ridge.w,90)
		relief += ridge.z * pow(maxf(0.0,1.0-q.length_squared()),3)
	for crater in [Vector3(-220,-240,24),Vector3(-70,-320,28),Vector3(90,-190,26),Vector3(330,-310,22),Vector3(-340,150,24),Vector3(340,350,20)]:
		var r: float = p.distance_to(Vector2(crater.x,crater.y)) / crater.z
		relief += (2.2*exp(-pow((r-1.0)/0.24,2))-3.0*exp(-pow(r/0.7,2))) * (1.0-smoothstep(1.4,1.8,r))
	return relief * mask

static func obstacle_clearance(p: Vector2) -> bool:
	if p.length() < 28: return true
	for site in SITES.values():
		if p.distance_to(site) < 16: return true
	for photo in PHOTO_SITES:
		if p.distance_to(photo) < 8: return true
	# Keep a continuous corridor open for the walking escort.
	var along := clampf(p.dot(RESCUE_SITE)/RESCUE_SITE.length_squared(),0.0,1.0)
	return p.distance_to(RESCUE_SITE*along) < 14

static func height_at(x: float, z: float) -> float:
	var p := Vector2(x,z)
	var h := 1.8 * sin(x * 0.017) * sin(z * 0.014)
	# Low eastern saddle leaves the polar Sun visible from the arrival basin.
	# Other ridges retain sheltered sampling terrain and route obstacles.
	var ridge_height := 0.0
	for ridge in RIDGES:
		ridge_height += ridge.z * exp(-pow((x-ridge.x)/ridge.w,2) - pow((z-ridge.y)/125.0,2))
	h += ridge_height + added_relief(p,ridge_height)
	for crater in [Vector3(-20,300,38),Vector3(130,310,48),Vector3(70,150,22),Vector3(-150,-100,35),Vector3(180,-80,40),Vector3(-290,60,30),Vector3(310,310,32),Vector3(-110,350,28)]:
		var r: float = p.distance_to(Vector2(crater.x,crater.y))/crater.z
		h += 3.0*exp(-pow((r-1.0)/0.23,2))-4.0*exp(-pow(r/0.7,2))
	return h * smoothstep(12,45,p.length())
static func point(p: Vector2) -> Vector3:
	return ORIGIN + Vector3(p.x,surface_height(p),p.y)

static func surface_height(p: Vector2) -> float:
	# Match the actual four-metre mesh triangles, not the smooth source curve.
	var cell := (p / 4.0).floor() * 4.0
	var uv := (p-cell) / 4.0
	var b := height_at(cell.x+4,cell.y)
	var c := height_at(cell.x,cell.y+4)
	if uv.x+uv.y <= 1.0:
		return height_at(cell.x,cell.y)*(1.0-uv.x-uv.y)+b*uv.x+c*uv.y
	return height_at(cell.x+4,cell.y+4)*(uv.x+uv.y-1.0)+b*(1.0-uv.y)+c*(1.0-uv.x)
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
	ground.name = "MissionGround"
	ground.set_meta("rover_safe_terrain", true)
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
	shelter.position = point(RESCUE_SITE+Vector2(0,2.5))-ORIGIN+Vector3.UP*0.55
	add_child(shelter)
	shelter.create_convex_collision()
	var rng := RandomNumberGenerator.new()
	rng.seed = 73129
	for i in range(320):
		var p := Vector2(rng.randf_range(-370,370),rng.randf_range(-370,370))
		if obstacle_clearance(p): continue
		var rock := MeshInstance3D.new()
		rock.mesh = mesh
		rock.material_override = rock_material
		var size := rng.randf_range(0.5,4)
		rock.scale = Vector3(size*1.5,size,size*1.1)
		rock.position = Vector3(p.x,surface_height(p)-mesh.get_aabb().position.y*size-size*0.15,p.y)
		add_child(rock)
		# Even small rocks must obstruct the remote camera.
		rock.create_convex_collision()

static func horizon_height(p: Vector2) -> float:
	# Square rings need a square-distance blend. Radial distance faded corner
	# ridges abruptly immediately outside the playable mesh.
	var blend := smoothstep(LIMIT, 900.0, maxf(absf(p.x), absf(p.y)))
	return lerpf(height_at(p.x, p.y), -p.length_squared() * 0.0000008, blend)

func _add_horizon(material: Material) -> void:
	var edge: Array[Vector2] = []
	for i in range(210): edge.append(Vector2(-420+i*4,-420))
	for i in range(210): edge.append(Vector2(420,-420+i*4))
	for i in range(210): edge.append(Vector2(420-i*4,420))
	for i in range(210): edge.append(Vector2(-420,420-i*4))
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var radii: Array[float] = []
	for radius in range(420, 901, 20): radii.append(float(radius))
	for radius in range(1000, 2501, 100): radii.append(float(radius))
	for r in range(radii.size()-1):
		for i in range(edge.size()):
			var corners: Array[Vector3] = []
			for pair in [[i,r],[(i+1)%edge.size(),r],[i,r+1],[(i+1)%edge.size(),r+1]]:
				var p: Vector2 = edge[pair[0]]*radii[pair[1]]/420.0
				var height := horizon_height(p)
				# Inner ring must meet the playable edge exactly.
				if pair[1] == 0: height = height_at(p.x,p.y)
				corners.append(Vector3(p.x,height,p.y))
			for j in [0,2,1,1,2,3]:
				surface.set_uv(Vector2(corners[j].x,corners[j].z)*0.12)
				surface.add_vertex(corners[j])
	surface.generate_normals()
	var horizon := MeshInstance3D.new()
	horizon.name = "MissionHorizon"
	horizon.mesh = surface.commit()
	horizon.material_override = material
	add_child(horizon)
	horizon.create_trimesh_collision()

extends SceneTree
func _init(): call_deferred("run")
func run():
 var stage = Node3D.new()
 root.add_child(stage)
 var factory = load("res://src/world/nasa_buildings.gd")
 for id in factory.MODELS:
  var model = factory.make(id, false)
  stage.add_child(model)
  model.position.x = -5 if id == "habitat_module" else 5
  print(id, " ", factory.mesh_bounds(model))
 var astronaut = load("res://Assets/animated_astronaut/source/Walking astronaut.glb").instantiate()
 stage.add_child(astronaut)
 astronaut.position = Vector3(1, 0, 2)
 for animation in astronaut.find_children("*", "AnimationPlayer", true, false):
  animation.play("idle")
  animation.advance(0)
  animation.pause()
 var camera = Camera3D.new()
 stage.add_child(camera)
 camera.position = Vector3(15, 10, 22)
 camera.look_at(Vector3(0,2,0))
 camera.projection = Camera3D.PROJECTION_ORTHOGONAL
 camera.size = 22
 var light = DirectionalLight3D.new()
 stage.add_child(light)
 light.rotation_degrees = Vector3(-40,-30,0)
 var env = WorldEnvironment.new()
 env.environment = Environment.new()
 env.environment.background_mode = Environment.BG_COLOR
 env.environment.background_color = Color(0.18,0.2,0.24)
 env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
 env.environment.ambient_light_color = Color.WHITE
 env.environment.ambient_light_energy = 0.6
 stage.add_child(env)
 await create_timer(2).timeout
 root.get_texture().get_image().save_png("res://tmp/buildings-after.png")
 quit()


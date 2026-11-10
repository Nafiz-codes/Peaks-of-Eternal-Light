extends Node3D
## Four persistent, randomly placed expedition photographs.
const Terrain = preload("res://src/world/expedition_terrain.gd")
const TEXTS := ["RIP Margaret Hamilton", "RIP Margaret Hamilton(2)", "Hill Climb Racing to the Moon!", "Wait this is a game? Always has been."]
const PATHS := ["res://Assets/easter_eggs/hamilton_1.png", "res://Assets/easter_eggs/hamilton_2.png", "res://Assets/easter_eggs/hill_climb.png", "res://Assets/easter_eggs/always_has_been.png"]
var state: RefCounted
var session: Node
var driver: Node3D
var astronaut: Node3D
var expedition: Node3D
var cards: Array[Node3D] = []
var nearest := -1
var revealing := false
var overlay: CanvasLayer
var prompt: Label
var reveal: Control
var artwork: TextureRect
var quote: Label
var banner: Label
var animation: Tween
var previous_mouse := Input.MOUSE_MODE_CAPTURED
var opened_at := 0

func _ready() -> void:
 name = "EasterEggs"
 process_mode = Node.PROCESS_MODE_ALWAYS
 session = get_node("/root/MissionSession")
 driver = get_parent().get_node("RoverHull")
 astronaut = get_parent().get_node("Outpost/Astronaut")
 expedition = get_parent().get_node("RoverTraining")
 _make_ui()

func _make_ui() -> void:
 overlay = CanvasLayer.new()
 overlay.layer = 150
 add_child(overlay)
 prompt = Label.new()
 prompt.text = "E · Inspect picture"
 prompt.add_theme_font_size_override("font_size", 22)
 prompt.add_theme_constant_override("outline_size", 6)
 prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 prompt.offset_left = -130
 prompt.offset_top = -120
 prompt.offset_right = 180
 prompt.offset_bottom = -70
 prompt.hide()
 overlay.add_child(prompt)
 reveal = Control.new()
 overlay.add_child(reveal)
 reveal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var dim := ColorRect.new()
 dim.color = Color(0.015, 0.025, 0.06, 0.88)
 reveal.add_child(dim)
 dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 var glow := ColorRect.new()
 glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
 var shader := Shader.new()
 shader.code = "shader_type canvas_item; void fragment(){ vec2 p=UV-vec2(0.32,0.5); float glow=exp(-dot(p,p)*12.0); COLOR=vec4(0.2,0.65,1.0,glow*0.6); }"
 var material := ShaderMaterial.new()
 material.shader = shader
 glow.material = material
 reveal.add_child(glow)
 glow.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
 banner = Label.new()
 banner.text = "RARE I ITEM FOUND"
 banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
 banner.add_theme_font_size_override("font_size", 30)
 banner.add_theme_color_override("font_color", Color("91cfff"))
 reveal.add_child(banner)
 banner.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
 banner.offset_top = 38
 banner.offset_bottom = 90
 artwork = TextureRect.new()
 artwork.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
 artwork.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
 reveal.add_child(artwork)
 artwork.anchor_left = 0.08
 artwork.anchor_right = 0.55
 artwork.anchor_top = 0.18
 artwork.anchor_bottom = 0.82
 quote = Label.new()
 quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
 quote.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
 quote.add_theme_font_size_override("font_size", 26)
 reveal.add_child(quote)
 quote.anchor_left = 0.61
 quote.anchor_right = 0.93
 quote.anchor_top = 0.25
 quote.anchor_bottom = 0.72
 var close := Button.new()
 close.text = "Continue · E / Esc"
 close.pressed.connect(close_reveal)
 reveal.add_child(close)
 close.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
 close.offset_left = -125
 close.offset_right = 125
 close.offset_top = -65
 close.offset_bottom = -20
 reveal.hide()

func _process(_delta: float) -> void:
 if revealing: return
 if state != session.dashboard_state:
  state = session.dashboard_state
  for card in cards: card.queue_free()
  cards.clear()
  if state != null: call_deferred("_spawn")
 nearest = -1
 prompt.hide()
 if state == null or get_tree().paused or expedition.transitioning: return
 var exploring: bool = expedition.data.get("location", "outpost") == "expedition"
 visible = exploring
 if not exploring or not expedition.busy_id.is_empty() or expedition.dialogue > 0: return
 var observer: Vector3 = driver.global_position if driver.active else astronaut.global_position
 if not driver.active and astronaut.ui_blocked: return
 var best := 5.0 if driver.active else 2.5
 for index in range(cards.size()):
  if not cards[index].visible: continue
  var distance := observer.distance_to(cards[index].global_position)
  if distance < best:
   best = distance
   nearest = index
 prompt.visible = nearest >= 0

func _spawn() -> void:
 await get_tree().physics_frame
 if state == null or not cards.is_empty(): return
 var record: Dictionary = state.easter_eggs
 if record.is_empty():
  var rng := RandomNumberGenerator.new()
  rng.randomize()
  var positions: Array[Vector3] = []
  # Distribute photos around four different stretches of the driving routes.
  for center in [Vector2(-45,55),Vector2(65,95),Vector2(-115,180),Vector2(160,240)]:
   for attempt in range(80):
    var point: Vector3 = Terrain.point(center + Vector2(rng.randf_range(-22,22),rng.randf_range(-22,22)))
    var hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(point+Vector3.UP*30,point-Vector3.UP*30))
    if hit.is_empty() or hit.normal.y < 0.97 or hit.collider.get_parent().name != "MissionGround": continue
    positions.append(hit.position)
    break
  if positions.size() != 4:
   call_deferred("_spawn")
   return
  record = {"positions": positions, "collected": []}
  state.easter_eggs = record
 for index in range(4):
  var card := MeshInstance3D.new()
  card.name = "Picture" + str(index+1)
  var plane := PlaneMesh.new()
  var texture: Texture2D = load(PATHS[index])
  plane.size = Vector2(0.65, 0.65 * float(texture.get_height()) / texture.get_width())
  card.mesh = plane
  var material := StandardMaterial3D.new()
  material.albedo_texture = texture
  material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
  material.cull_mode = BaseMaterial3D.CULL_DISABLED
  card.material_override = material
  add_child(card)
  card.global_position = record.positions[index] + Vector3.UP * 0.035
  var floor_hit := get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(card.global_position+Vector3.UP,card.global_position-Vector3.UP))
  if not floor_hit.is_empty():
   card.global_basis = Basis(Quaternion(Vector3.UP,floor_hit.normal)) * Basis(Vector3.UP,float(index)*1.7)
  card.visible = not index in record.collected
  cards.append(card)
 session.capture_sol_checkpoint()

func handle_event(event: InputEvent) -> bool:
 if not event is InputEventKey or not event.pressed or event.echo: return false
 if revealing:
  if event.keycode in [KEY_E, KEY_ESCAPE] and Time.get_ticks_msec()-opened_at > 500: close_reveal()
  return true
 if get_tree().paused or event.keycode != KEY_E or nearest < 0: return false
 collect(nearest)
 return true

func _input(event: InputEvent) -> void:
 if handle_event(event): get_viewport().set_input_as_handled()

func collect(index: int) -> void:
 if revealing or state == null or index < 0 or index >= cards.size() or index in state.easter_eggs.collected: return
 revealing = true
 opened_at = Time.get_ticks_msec()
 previous_mouse = Input.mouse_mode
 var camera := get_viewport().get_camera_3d()
 var origin := get_viewport().get_visible_rect().size * 0.5
 if camera != null: origin = camera.unproject_position(cards[index].global_position)
 cards[index].hide()
 state.easter_eggs.collected.append(index)
 session.capture_sol_checkpoint()
 prompt.hide()
 nearest = -1
 artwork.texture = load(PATHS[index])
 quote.text = '"' + TEXTS[index] + '"'
 reveal.show()
 reveal.modulate.a = 0.0
 quote.modulate.a = 0.0
 artwork.pivot_offset = artwork.size * 0.5
 var destination := artwork.position
 artwork.position = origin - artwork.size * 0.5
 artwork.scale = Vector2(0.12, 0.035)
 artwork.rotation = -0.16
 get_tree().paused = true
 Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
 animation = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
 animation.set_parallel(true)
 animation.tween_property(reveal,"modulate:a",1.0,0.2)
 animation.tween_property(artwork,"position",destination,0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 animation.tween_property(artwork,"scale",Vector2.ONE,0.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
 animation.tween_property(artwork,"rotation",0.0,0.55)
 animation.tween_property(quote,"modulate:a",1.0,0.25).set_delay(0.35)

func close_reveal() -> void:
 if not revealing: return
 if animation != null: animation.kill()
 # Restore the anchor-derived image rectangle for the next pickup.
 artwork.offset_left = 0
 artwork.offset_top = 0
 artwork.offset_right = 0
 artwork.offset_bottom = 0
 reveal.hide()
 revealing = false
 get_tree().paused = false
 Input.mouse_mode = previous_mouse

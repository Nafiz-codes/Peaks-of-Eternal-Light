extends SceneTree
## Render the production sky shader with neutral textures to isolate lighting.
## Requires a renderer: --rendering-method gl_compatibility (not --headless).
var failures := 0
var material: ShaderMaterial

func _init() -> void:
	call_deferred("run")

func check(condition: bool, message: String) -> void:
	if not condition:
		failures += 1
		push_error(message)

func texture_color(color: Color) -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.fill(color)
	return ImageTexture.create_from_image(img)

func render_sun(direction: Vector3, name_: String) -> Image:
	material.set_shader_parameter("display_sun_direction", direction)
	await process_frame
	await RenderingServer.frame_post_draw
	var img := root.get_texture().get_image()
	if "--capture" in OS.get_cmdline_user_args():
		img.save_png("res://.tools/earth-lighting-" + name_ + ".png")
	return img

func run() -> void:
	root.size = Vector2i(512, 512)
	var world := Node3D.new()
	root.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	material = ShaderMaterial.new()
	material.shader = preload("res://src/world/lunar_starfield.gdshader")
	material.set_shader_parameter("earth_surface", texture_color(Color(0.5, 0.5, 0.5)))
	for key in ["earth_clouds", "earth_night", "earth_gloss"]:
		material.set_shader_parameter(key, texture_color(Color.BLACK))
	material.set_shader_parameter("earth_position_km", Vector3(0, 0, -10))
	material.set_shader_parameter("earth_radius_km", 4.0)
	sky.sky_material = material
	environment.environment.sky = sky
	world.add_child(environment)
	var camera := Camera3D.new()
	camera.fov = 60.0
	world.add_child(camera)
	camera.make_current()
	var right := await render_sun(Vector3.RIGHT, "right")
	var left := await render_sun(Vector3.LEFT, "left")
	check(right.get_pixel(320, 256).r > right.get_pixel(192, 256).r + 0.1, "Sun to the right lights Earth's right hemisphere.")
	check(left.get_pixel(192, 256).r > left.get_pixel(320, 256).r + 0.1, "Moving the same Sun left reverses Earth's illuminated hemisphere.")
	var full := await render_sun(Vector3.BACK, "full")
	var dark := await render_sun(Vector3.FORWARD, "dark")
	check(full.get_pixel(256, 256).r > dark.get_pixel(256, 256).r + 0.25, "Earth faces daylight when the Sun is behind the observer and night when behind Earth.")
	check(absf(right.get_pixel(320, 256).r - left.get_pixel(192, 256).r) < 0.03, "Opposite Sun positions produce symmetric lighting without a stale Earth light direction.")
	print("Earth lighting render: %d failures / 4 checks." % failures)
	quit(1 if failures else 0)

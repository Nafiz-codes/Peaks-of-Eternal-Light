extends Range
## Vector-drawn reserve meter; the icon and frame stay crisp at any resolution.
var kind := "power_kwh"
const HUD_ACCENT = preload("res://src/ui/ui_style.gd").BLUE
var tint := Color("65869c")
var icon: ImageTexture

const ICONS := {
 "power_kwh": '<path fill="#eaa000" d="M24 1L6 23l8 1-5 17 26-27-13 1z"/><path fill="#ffe32b" d="M24 1L3 22h13L9 37l21-22H20z"/><path fill="#fff67b" d="M24 1L11 20h8z"/>',
 "food_kg": '<path fill="#a71e23" d="M20 37C14 33 2 25 2 15C2 3 16 2 20 11C25 2 38 3 38 15C38 25 26 34 20 37z"/><path fill="#ff3038" d="M20 32C13 28 2 21 2 12C2 2 16 2 20 10C25 2 37 3 37 12C37 22 26 29 20 32z"/>',
 "oxygen_kg": '<circle cx="20" cy="20" r="19" fill="#56bfd1" stroke="#c6f5fc" stroke-width="1.2"/><circle cx="20" cy="20" r="16.7" fill="none" stroke="white" stroke-width="0.7"/><circle cx="18" cy="18" r="8" fill="none" stroke="white" stroke-width="2.8"/><path d="M27 24C27 20 33 21 32 24L27 29h6" fill="none" stroke="white" stroke-width="1.6"/>',
 "water_l": '<ellipse cx="20" cy="36" rx="17" ry="3" fill="none" stroke="#a6dbff" stroke-width="1.2"/><path d="M20 2C17 13 7 20 7 26a13 13 0 0026 0C33 20 23 12 20 2z" fill="#247de4"/><path d="M12 26q1 6 6 8" fill="none" stroke="white" stroke-width="2" stroke-linecap="round"/>'
}

func _ready() -> void:
 mouse_filter = Control.MOUSE_FILTER_IGNORE
 step = 0.0
 var artwork: String = ICONS[kind]
 var colors := RegEx.new()
 colors.compile("#[0-9a-fA-F]{6}")
 artwork = colors.sub(artwork, "#" + HUD_ACCENT.to_html(false), true)
 # Cutouts stay dark so the monochrome oxygen and droplet symbols read clearly.
 artwork = artwork.replace('"white"', '"#171c2b"')
 var source := '<svg xmlns="http://www.w3.org/2000/svg" width="40" height="42" viewBox="0 0 40 42">' + artwork + '</svg>'
 var picture := Image.new()
 if picture.load_svg_from_string(source, 2.0) == OK:
  icon = ImageTexture.create_from_image(picture)
 value_changed.connect(func(_value: float): queue_redraw())
 resized.connect(queue_redraw)

func polygon(points: Array, color: Color) -> void:
 draw_colored_polygon(PackedVector2Array(points), color)

func capsule(rect: Rect2, color: Color) -> void:
 var style := StyleBoxFlat.new()
 style.bg_color = color
 style.set_corner_radius_all(int(rect.size.y / 2))
 draw_style_box(style, rect)

func _draw() -> void:
 var x := 34.0
 var right := size.x - 2.0
 var ratio := clampf(value / maxf(max_value, 0.001), 0.0, 1.0)
 var end := lerpf(x + 9, right - 10, ratio)
 if kind == "oxygen_kg":
  capsule(Rect2(x, 13, right-x, 18), HUD_ACCENT)
  capsule(Rect2(x+3, 16, right-x-6, 12), Color("171c2b"))
  if ratio > 0:
   capsule(Rect2(x+4, 17, (right-x-8)*ratio, 10), tint)
   draw_line(Vector2(x+9,18),Vector2(maxf(x+9,end-3),18),tint.lightened(0.10),2,true)
 elif kind == "power_kwh":
  polygon([Vector2(x,12),Vector2(right,12),Vector2(right-5,31),Vector2(x-5,31)],HUD_ACCENT)
  polygon([Vector2(x+3,16),Vector2(right-6,16),Vector2(right-9,27),Vector2(x,27)],Color("171c2b"))
  if ratio > 0:
   polygon([Vector2(x+4,17),Vector2(end+3,17),Vector2(end,26),Vector2(x+1,26)],tint)
   draw_line(Vector2(x+5,18),Vector2(end+1,18),tint.lightened(0.10),2,true)
 else:
  var bevel := 8.0 if kind == "water_l" else 0.0
  polygon([Vector2(x+bevel,13),Vector2(right-9,13),Vector2(right,22 if kind == "water_l" else 30),Vector2(right-9 if kind == "water_l" else right,30),Vector2(x+bevel,30),Vector2(x,22)],HUD_ACCENT)
  polygon([Vector2(x+8,16),Vector2(right-10,16),Vector2(right-5,27),Vector2(x+8,27),Vector2(x+4,22)],Color("171c2b"))
  if ratio > 0:
   polygon([Vector2(x+9,17),Vector2(end-3,17),Vector2(end+3,25),Vector2(x+9,25),Vector2(x+5,21)],tint)
   draw_line(Vector2(x+10,18),Vector2(maxf(x+10,end-3),18),tint.lightened(0.10),2,true)
 if icon != null:
  draw_texture_rect(icon,Rect2(0,0,38,40),false)

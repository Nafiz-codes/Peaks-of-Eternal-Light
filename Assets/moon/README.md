# Lunar globe assets

Source: user-provided NASA Scientific Visualization Studio CGI Moon Kit files.
Documentation and credit: https://svs.gsfc.nasa.gov/4720/ (NASA's Scientific Visualization Studio).

- `lroc_2025_4k.png`: default global albedo from `lroc_color_16bit_srgb_4k.tif`.
- `lroc_2019_4k.png`: alternative global albedo from `lroc_color_poles_4k.tif`.
  Both maps already include polar coverage. They are alternative editions, not separate hemispheres.
- `lola_relief.png`: east/north/radial tangent normals calculated from `ldem_4.tif`,
  whose float elevations are kilometers relative to a 1737.4 km sphere.

Regenerate with `python tools/prepare_moon_maps.py E:/` (Pillow and NumPy).
Source TIFFs remain untouched. Runtime color PNGs retain the 4096 x 2048 resolution
and sRGB encoding, with 8-bit channels converted from the 2025 source's 16-bit channels.
The relief texture is linear data, not color. Use lossless imports; do not convert it
into Godot's two-channel tangent-normal format.

The shader maps longitude -180..180 to U 0..1 and latitude +90..-90 to V 0..1.
It repeats longitude and clamps latitude to avoid north/south texture bleed. Relief
changes shading only: the original 10-unit radius, collision sphere, and site
coordinates remain unchanged. Light follows the inspection camera; this is not a
physical simulation of lunar illumination. Polar albedo is lower-resolution LOLA
infill, so the magnified site view is not a detailed landing terrain survey.

The previous `quickmap-lroc.png` and `near_side.gdshader` are retained but no longer
used by the selector.

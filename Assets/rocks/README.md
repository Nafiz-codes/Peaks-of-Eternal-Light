# Imported surface stones

User-supplied sources: `rock_00__8_grey-white_rock_models_-_with_lods.glb`
(stored as `grey_white_rocks.glb`) and `stone.glb`.

`tools/prepare_rocks.gd` extracts the eight individual rocks from the final
material column of the pack's presentation grid, preserving its materials,
UVs, normals, and scene orientation. It also bakes the separate stone mesh.
Regenerate using Godot's `--headless --path . --script tools/prepare_rocks.gd`
after importing the source GLBs. The other display columns are not scattered.

`rock_scatter.gd` places 40 shared-mesh instances at least 8 m apart with seeded positions,
random heading and 0.2–2 m widths. Positions are sampled directly from terrain
triangles and aligned with the surface normal, with 28% of their height buried. The central
34 m radius and boundary margin remain clear. Larger stones have simple hulls;
small pebbles are decorative. Source models and textures remain unmodified.

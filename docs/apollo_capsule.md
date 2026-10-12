# Apollo capsule

`Assets/outpost/habitat.tscn` wraps an optimized copy of the user-supplied `Assets/apollo/command_module.glb`, including both exterior and cockpit. The original GLB is preserved. The model is approximately 5.33 metres across and 3.73 metres high, enlarged by one third from its previous game scale to provide more room relative to the 1.7-metre astronaut. This is a gameplay scale adjustment, not a claim of historical capsule dimensions. `HatchApproach` and `SeatedEye` follow the larger capsule and define entry and the crew-couch viewpoint.

Approach the front hatch and press E, or release the cursor with Esc and click **Get inside**. The screen fades to black before transfer into the seated view and fades back in afterward. The cockpit uses the outdoor camera's 90-degree field of view, starting pitch, sensitivity, and look limits, with its eye position fixed at the seat. Walking and jumping are disabled until **Get outside** returns the astronaut to the hatch. The full suit remains visible in a reclined seated pose, with bent knees and arms positioned toward the lap. The camera stays ahead of the helmet/chest, and the body stays aligned with the couch when looking around. No suit surfaces are cut away. Exiting restores the original model transform, joint rotations, and locomotion animation.

`tools/optimize_apollo.gd` reproducibly generates `Assets/apollo/command_module_optimized.scn` from the source GLB. It reduces the maximum render mesh from 721,398 to approximately 171,256 triangles, preserves textures and additional distance LODs, and limits shadow casting to the exterior shell. A 48-point convex hull replaces the 90,000-triangle physics shell. Rebuild the optimized scene with Godot's `--headless --path . --script tools/optimize_apollo.gd` after changing the source asset.

The procedural cockpit and Blue Moon stair entry have been removed. The previous Blue Moon asset remains in the repository but is no longer instanced by the habitat scene.

Run `tests/world/test_lander_interior.gd` with Godot to verify proximity, the fade, seating, and exit. Add `-- --capture` with rendering enabled for a cockpit screenshot.

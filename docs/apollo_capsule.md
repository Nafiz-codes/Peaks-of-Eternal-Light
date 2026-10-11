# Apollo capsule

`Assets/outpost/habitat.tscn` wraps the user-supplied `Assets/apollo/command_module.glb`, including both exterior and cockpit. The model is scaled to approximately four metres across and grounded at the heat shield. `HatchApproach` and `SeatedEye` define entry and the crew-couch viewpoint.

Approach the front hatch and press E, or release the cursor with Esc and click **Get inside**. The screen fades to black before transfer into the seated view and fades back in afterward. Mouse look remains available within the seat; walking and jumping are disabled until **Get outside** returns the astronaut to the hatch. The standing avatar is hidden in the first-person seated view to prevent suit clipping.

The procedural cockpit and Blue Moon stair entry have been removed. The previous Blue Moon asset remains in the repository but is no longer instanced by the habitat scene.

Run `tests/world/test_lander_interior.gd` with Godot to verify proximity, the fade, seating, and exit. Add `-- --capture` with rendering enabled for a cockpit screenshot.

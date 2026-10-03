# Outpost presentation assets

`habitat.tscn` and `solar_array.tscn` are locally authored, reusable Godot scenes built from the project's existing geometric designs, with added ground supports. No separate habitat or solar-array model was supplied. These are illustrative game assets, not surveyed lunar infrastructure or engineering specifications.

The outpost also instantiates the existing `Assets/mars_rover.glb` and `Assets/animated_astronaut/source/Walking astronaut.glb`. The rover is a supplied Mars-rover visual reused as an illustrative lunar vehicle; its runtime mesh bounds are centered, grounded, and scaled to a 3 m footprint. Original asset files remain unchanged. Godot imports their textures through the normal project import process.

These assets represent the initial scene only. Placement does not imply simulation construction completion, rover operation, or resource production. Those require authoritative runtime actions in later tasks.

The Day 11 pass adds habitat windows and identification, solar cell divisions, and collision hulls in the world. `src/world/outpost_terrain.gd` supplies deterministic site-seeded terrain, regolith texture and peripheral rocks, with a flat playable pad. Its mesh is illustrative art, not a local LOLA reconstruction. Solar indicator light intensity is a visual cue; only the HUD and station kWh readings report the simulator's numeric output.

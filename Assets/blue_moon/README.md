# Blue Moon lander

Model: BlueMoon_AndyModel_v01.fbx, supplied by the user with Textures.zip.
Model/rig credit: creator of the supplied BlueMoon_AndyModel_v01 asset (full name not provided in the accompanying license).
Original license text is preserved in LICENSE.txt; no affiliation with Blue Origin is implied.

Godot imports the FBX directly. import_materials.gd matches the supplied base color,
normal and ORM textures to the authored material names. ORM uses red for ambient
occlusion, green for roughness and blue for metallic. Materials without supplied
maps retain their authored values.

The outpost scales the authored 2.033674 m crew door to the astronaut's 1.7 m
height plus 0.4 m clearance. This yields a 2.1 m door, approximately 17.1 m
vehicle height and an 11.24 m footprint. It rests on the terrain, with static
mesh collisions, and is set back to clear the rover and operating stations.
An invisible convex walking surface joins the bottom tread to the upper landing;
the visible staircase and railing collisions remain intact. The astronaut can
walk up its approximately 48-degree slope and descend using floor snapping.
This is a character-relative art scale, not a claim about the real vehicle's
dimensions. Maya and Unreal project archives are not runtime dependencies.


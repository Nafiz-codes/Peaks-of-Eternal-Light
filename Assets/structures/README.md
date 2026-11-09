# NASA construction models

All buildings except the Radiation Shielding Habitat are scaled 1.3x after assembly
(BUILDING_SCALE in src/world/nasa_buildings.gd) to match it; sizes below are before
that scale. The radiation habitat is the ~13 m reference and keeps its size.

## Comms relay
Source: https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Tall%20Dish
Original GLBs, assembled in their source coordinate system:
- tall_dish_dish.glb: e6aa9170cdf3e77dc933c4ef2a1046379a5588f5
- tall_dish_post.glb: e2c77192ea7dcf395339034c4d23d9b4e5a33c0c
- tall_dish_turntable.glb: 7920780d50d07222c9bfd5cb635cea382ad9060e

## Water extractor (game-authored)
Built in code by water_extractor.gd (no NASA source asset). A thermal ice extractor:
a smooth, uneven lump of ice (clear shell, glowing core) sits in a heated cradle on four struts; its
condensate forms on a nozzle and drips into an open glass reservoir, leaving ripples.
Drops fall 0.74 m in 0.96 s, the free-fall time under lunar gravity (1.62 m/s²).
Fitted to a 5 m footprint (about 3.9 m tall); thumbnail, ghost and completed site share it.

## Greenhouse (game-authored)
Built in code by greenhouse.gd (no NASA source asset): a frequency-4 geodesic glass dome
(4 m radius) on a ring foundation, over four rows of tiered grow racks with grass-filled
trays and LED bars, plus a central service column. About 8.7 m wide and 4.4 m tall.

## Radiation Shielding Habitat (game-authored)
Built in code by radiation_shelter.gd (no NASA source asset): a bulldozed regolith mound
(regolith overburden is the shielding) with three half-buried cylindrical modules, lit
doors and ramps, a crown hatch ring and a utility culvert. Fitted to 13 m across (scale ~1.07): doors about 1.5 m tall, mound about 2.5 m high, modules about 1.9 m in diameter.

## Habitat extension
Reuses Assets/stations/hdu_1.glb (NASA Habitat Demonstration Unit part 1).
Source and conversion details: ../stations/README.md.

The imported comms assembly is fitted to 5 m height (approximately 2.66 m dish width).
Its foundation, mast flange, anchor plates, braces, conduit and 1.1 m radio cabinet
complete a 2.8 x 2.8 m footprint and 5.2 m overall height.
The imported habitat is fitted to 9.6 m width (approximately 5.49 m height).
A supporting deck, module saddles, 18 cm access steps and metre-high handrails
complete a 9.8 x 5.4 m footprint and 5.85 m overall height.
These installations are checked against the game's 1.7 m astronaut: roughly
three astronaut heights for the relay and two habitable levels for the habitat.
Installation hardware is game-authored, not part of the original NASA assets.
Build-menu thumbnails, placement ghosts and completed buildings share this assembly.
These are gameplay dimensions, not certified NASA hardware measurements.
Models are ground-centered; completed structures have matching bounding-box
collisions, while previews use a non-colliding blue hologram material.
B-menu cards open mouse-aimed placement with Q/R rotation. Like the solar panel,
confirmation pays the existing cost and the building stands at once (no build timer);
built models relocate for free and C destroys them for a full refund. Output does not
depend on position (only the solar panel's does).
Only unconfirmed placement previews use the blue hologram material.
Positions and rotations are stored in the optional building_placements save field;
sites left under construction by older saves finish when next confirmed.

NASA usage guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/
No NASA endorsement is implied.

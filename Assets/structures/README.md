# NASA construction models

## Comms relay
Source: https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Tall%20Dish
Original GLBs, assembled in their source coordinate system:
- tall_dish_dish.glb: e6aa9170cdf3e77dc933c4ef2a1046379a5588f5
- tall_dish_post.glb: e2c77192ea7dcf395339034c4d23d9b4e5a33c0c
- tall_dish_turntable.glb: 7920780d50d07222c9bfd5cb635cea382ad9060e

## Habitat extension
Reuses Assets/stations/hdu_1.glb (NASA Habitat Demonstration Unit part 1).
Source and conversion details: ../stations/README.md.

The comms assembly is fitted to 5 m height (approximately 2.66 m dish width).
The habitat is fitted to 9.6 m width (approximately 5.49 m height).
These are gameplay dimensions, not certified NASA hardware measurements.
Models are ground-centered; completed structures have matching bounding-box
collisions, while previews use a non-colliding blue hologram material.
B-menu cards open mouse-aimed placement with Q/R rotation. Confirmation queues
new construction at the existing cost; already queued/built models can relocate
without a second charge. Pending sites show a blue blueprint with collision.
Positions and rotations are stored in the optional building_placements save field;
older saves remain supported. Construction times and gameplay effects are unchanged.

NASA usage guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/
No NASA endorsement is implied.

# NASA HDU station assets

Source: NASA, Habitat Demonstration Unit (part 1)
https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Habitat%20Demonstration%20Unit
https://science.nasa.gov/3d-resources/habitat-demonstration-unit/
NASA media usage guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/

hdu_1.glb is the NASA model decoded from KHR_draco_mesh_compression using
@gltf-transform/cli copy, retaining its mesh and embedded textures. Original Git
blob SHA: 3a16e21105438b4fc7be2717698d570fc9100b9f.

Sam's engineering workshop uses a 9.6 m wide shell (approximately 5.5 m tall),
on a 10 x 7.4 m platform. Its workbench stays 1.05 m high; the NPC access point
and placement/collision footprint use the enlarged dimensions. This is
astronaut-scale gameplay sizing, not a certified dimensional HDU reconstruction.
Maya and Alex retain their compact 3 m shell models.
Platforms, consoles, sample containers, tools, accent lights and crew labels are
game-authored additions in src/world/crew_station.gd. These are fictional outdoor
workstations, not a reconstruction or simulation of the HDU's interior. No NASA
endorsement is implied. Station duties use the game's existing crew routines.

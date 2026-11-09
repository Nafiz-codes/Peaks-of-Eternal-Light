# NASA HDU station assets

Source: NASA, Habitat Demonstration Unit (part 1)
https://github.com/nasa/NASA-3D-Resources/tree/master/3D%20Models/Habitat%20Demonstration%20Unit
https://science.nasa.gov/3d-resources/habitat-demonstration-unit/
NASA media usage guidance: https://www.nasa.gov/nasa-brand-center/images-and-media/

hdu_1.glb is the NASA model decoded from KHR_draco_mesh_compression using
@gltf-transform/cli copy, retaining its mesh and embedded textures. Original Git
blob SHA: 3a16e21105438b4fc7be2717698d570fc9100b9f.

All three crew outposts use a 9.6 m wide shell (approximately 5.5 m tall),
on a 10 x 7.4 m platform. Its workbench stays 1.05 m high; the NPC access point
and placement/collision footprint use the enlarged dimensions. This is
astronaut-scale gameplay sizing, not a certified dimensional HDU reconstruction.
Maya, Alex and Sam share the same full-size shell and footprint; their consoles,
sample instruments and engineering tools remain distinct and human-sized.
Platforms, consoles, sample containers, tools, accent lights and crew labels are
game-authored additions in src/world/crew_station.gd. These are fictional outdoor
workstations, not a reconstruction or simulation of the HDU's interior. No NASA
endorsement is implied. Station duties use the game's existing crew routines.

Maya · Operations does not use the HDU shell: it is a game-authored lunar operations
control tower (octagonal drum, flared glazed control room, front airlock, roof dish,
antenna and beacon) on a 13 x 9.6 m platform, scaled 1.3x to match the radiation
habitat; its door is about 1.5 m and its clearance 7.5 m. The walk-up desk and dock
move forward with the platform edge. Its agency-style livery (navy and red bands,
"LUNAR OPERATIONS CENTER" lettering, "OPS-1" numbers, a simplified flag and the game's
own mission emblem) deliberately uses no NASA insignia or logotype, which require
NASA permission and would imply endorsement.

Scale: every crew station (shell, platform and tower) is scaled 1.3x to match the
radiation habitat, e.g. the HDU shell is 12.48 m wide (~7.15 m tall) on a 13 x 9.6 m
platform with 7.5 m clearance. Desks, consoles and tools stay human-sized and move
forward with the platform edge, as does each crew dock.

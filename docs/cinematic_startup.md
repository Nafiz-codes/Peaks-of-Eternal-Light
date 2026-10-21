# Cinematic startup

The project now boots into `scenes/startup.tscn`. `src/ui/startup.gd` owns the flow:
`INTRO → MENU_ENTERING → MENU_IDLE → STARTING_MISSION → GAMEPLAY`.

The three credits overlap by 0.2 seconds; their combined sequence takes 6.35 seconds. Escape and the skip button smoothly reveal the menu. The navigation becomes interactive after its entrance. START MISSION additionally waits for the original selector resource to finish loading.

## Existing Moon integration

The controller requests `scenes/lunar_landing_selector.tscn` through Godot's threaded resource loader, then instantiates it once on the main thread while the intro covers it. The existing selector constructs its own SouthPoleMap, shader, textures, environment, markers, and SelectorCamera. Its input and UI remain disabled during presentation. No Moon transforms or materials change.

START MISSION coordinates the astronaut's leftward movement and an orthographic Camera3D.h_offset animation. The Moon enters from the right, reaches the center, then eases to the selector's original camera offset. The exact same selector instance is reparented to the scene-tree root and made current_scene, preserving the existing scene_file_path and subsequent landing/dashboard flows. The startup scene is freed. No viewport copy, duplicate Moon, or scene reload is used at handoff.

## Artwork and controls

`Assets/startup/astronaut.jpg` is the supplied astronaut reference. The canvas shader suppresses lettering in the background and blends its dark edges. The source image remains unchanged. UI bars use restrained blue-white edge brackets and keyboard focus. Briefing describes the actual existing selector-to-outpost workflow. Settings use the existing GameSettings persistence and audio/display/antialiasing controls. No audio tracks were supplied or added. Reduced idle motion disables breathing/parallax; the core mission exchange remains cinematic.

## Verification

Run with the bundled Godot 4.7.2:

```
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/ui/test_startup.gd
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_lunar_landing_selector.gd
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_lunar_landing_transition.gd
```

The startup test covers automatic credits/menu, Escape skipping without opening the pause menu, modal input gating, repeated starts, overlapping animation progress, identical Moon instance/material/transform, restored camera framing, and gameplay activation. It also renders captures at 1360×820 and 960×720 under `.tools/startup-*.png`. Visual inspection caught and corrected an initial empty interval in the exchange.

Resource loading is threaded; Godot node construction still happens on the main thread. A cold-start frame-time budget and performance on lower-end GPUs have not been certified. The original rover resource emits an existing invalid-UID fallback warning during loading.

The startup test also reports 17 RefCounted instances at engine shutdown (zero reference counts in verbose output). This shutdown warning remains unresolved; runtime assertions pass. No 60 FPS guarantee is made.

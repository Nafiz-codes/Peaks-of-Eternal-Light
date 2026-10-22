# Rover mission training — implementation and review

## Review against the existing game

The supplied mission prompt fits the current uncrewed rover, but its suggested new autoloads would duplicate existing ownership. Godot 4.7.2 is installed in `.tools/godot`; `project.godot` targets Godot 4.7 with the Compatibility renderer.

Reused systems:

- `src/runtime/mission_session.gd` owns the current `MissionState`, save checkpoints, site changes and resource simulation. Training progress is a new dictionary on that same state, not a second global mission session.
- `src/world/rover_drive.gd` retains its steering, wheel motion, camera, actual-distance energy use, collision health and repair behavior. The astronaut still controls it from the lander's seat with R.
- `src/world/rover_takeover.gd` already gates controls on completion of both the silent video and dedicated audio. Its existing visual cut is approximately 5.875 seconds, followed by the live parked rover; the complete startup sequence lasts ten seconds. That structure is preserved.
- `Assets/audio/sfx/rover_takeover.wav` is already approximately ten seconds. No pitch shifting, destructive sound editing or replacement startup video was needed. The original longer `rover_start.mp3` is untouched.
- `src/runtime/menu_music.gd` already provides equal-power crossfades and saved music buses. The fade duration is now 1.5 seconds. Startup ducking and user volume settings are retained.
- `Assets/animated_astronaut/source/Walking astronaut.glb` supplies the stranded astronaut's existing idle animation. The rover's imported rig and wheel pivots are untouched.

The four existing landing sites do not establish a physically simulated permanently shadowed crater. Frozen Horizon therefore uses an explicitly labeled **simulated shadow region**, with a local terrain overlay lit by the rover headlights. Neither this region nor the fictional 32/78/49 signal readings are presented as NASA measurements or real ice concentrations.

## Integration plan implemented

1. Add ordered survey, science and rescue rules to the existing saved mission state.
2. Share sensor targets, range/aim/speed/occlusion checks and interrupted hold-to-scan progress.
3. Complete terrain mapping and gated upload, then reuse that foundation for candidate comparison, sampling and rescue.
4. Connect contextual actions to the existing remote-control gate, with timed tools and no movement during interactions.
5. Add a signal-driven telemetry HUD, battery draw, world markers, headlights, tool visuals and onboard audio cues.
6. Preserve save compatibility, retry and checkpoints; validate rules, world interactions, startup, driving and audio.

## Playing the missions

Enter the existing lander with E. From its seat, press R or click **Rover mission training**. Wait for the existing startup sequence to finish. W/S drive, A/D steer, Space brakes, and R returns to the cockpit. Esc uses the existing pause menu.

For a scan, stop within 6.5 metres, point the rover nose toward the marker (within 45 degrees), and hold F for three seconds. Motion above 0.12 m/s, leaving range, releasing F, changing targets or an intervening obstacle resets progress. Each eligible target counts once. E begins the currently relevant interaction; L toggles headlights. Existing astronaut controls remain in effect outside remote control. No new rover camera mode or mission map was added because the existing driver has neither.

1. **Operation Surface Survey:** scan Alpha, Beta and Gamma in any order. Their colors distinguish them, and completed sectors turn green. Return to the outpost data uplink and press E for a three-second transmission. Upload remains unavailable until all three unique scans exist.
2. **Operation Frozen Horizon:** reach the training perimeter, turn on headlights and press E. Scan all three deposits. Only then is candidate B highlighted as the strongest simulated hydrogen-proxy signal. Face B and press E for three seconds of drilling followed by three seconds of analysis/retraction. The fictional sample analyzer reports evidence of ice; hydrogen detection itself does not confirm ice. Return to the uplink and transmit the analysis.
3. **Operation Lifeline:** follow the approximate search waypoint and proximity beacon. The default eight-minute reserve starts only when remote driving is ready. Identify the astronaut with F, then use separate E interactions to establish contact, deliver the support kit, deploy the relay and confirm independent-team pickup. Every action takes three seconds and revalidates position and visibility throughout. Kit completion stabilizes the astronaut and stops the reserve timer. Mission Control confirms pickup by a separate team; the rover never carries the astronaut.

Enter advances from a successful mission to the next training exercise. This resupplies the rover and returns it to its deployment pad. Enter after failure retries the same exercise, resetting equipment, battery, health, timers, progress and rover pose. Outpost resource/sol simulation is not reset. After the final mission, R returns to the lander; the existing pause-menu mission reset starts a fresh campaign.

Battery depletion, zero rover health, rescue reserve expiry before stabilization, or escaping the existing training boundary fails the current attempt. Normal collisions remain repairable under the existing health system. Near-edge and low-battery warnings are displayed. Cold-region exposure produces a warning after 60 seconds; it does not invent an instant thermal-death condition. Exiting remote control does not stop an already-started rescue reserve while the outpost is running, but pause and the startup cinematic do. Scene unload/save freezes elapsed simulation time; there is no offline countdown.

## Files and configuration

All paths below are relative to `E:\Peaks-of-Eternal-Light`.

| File | Purpose |
| --- | --- |
| `scenes/rover_training.tscn` | Editable mission configuration and world controller root. |
| `src/simulation/rover_training.gd` | Ordered lifecycle, scan sets, readings, rescue state, battery, failure and save validation. |
| `src/simulation/mission_state.gd` | Adds the saved `rover_training` dictionary. |
| `src/runtime/mission_save.gd` | Validates training saves and permits older saves without the new field. |
| `src/runtime/menu_music.gd` | Adjusts existing crossfade duration to 1.5 seconds. |
| `src/world/rover_scan_target.gd` | Reusable non-solid Area3D markers, aim points and identity. |
| `src/world/rover_scanner.gd` | Shared hold progress, stationary threshold, range, aim and physics-ray checks. |
| `src/world/rover_training_controller.gd` | Connects rules to the existing world, rover controls, targets, tools, headlights, telemetry, audio and checkpoints. |
| `src/world/rover_training_shadow.gdshader` | Local simulated low-light region that preserves the underlying terrain mesh and collisions. |
| `src/world/rover_drive.gd` | Routes training keys and brakes while tools/results own control. |
| `src/world/lunar_outpost.gd` | Instantiates the training scene after the existing rover and lander setup. |
| `src/world/lander_access.gd` | Labels the existing remote-control button and explains the training sequence. |
| `src/ui/rover_training_hud.gd` | Scaled, signal-updated objective, telemetry, progress and debrief panel. |
| `tests/simulation/test_rover_training.gd` | Rules, sequencing, rejection, retry, timer, battery and save-contract checks. |
| `tests/world/test_rover_training.gd` | Actual world targets, startup gate, physics occlusion, interactions, pause, tools, retry and rendered captures. |
| `tests/world/test_rover_training_sites.gd` | Ground placement and unobstructed sensor approach checks at all four landing sites. |
| `tests/world/test_live_operations.gd` | Existing driving regression, extended to require explicit retry after its deliberate critical-damage test. |
| `docs/rover_training.md` | Review, plan, integration details, play instructions and verification notes. |

Godot-generated `.uid` companions retain script/shader identities. Earlier startup/menu wording edits are separate from this mission implementation.

No new autoload or audio bus is required. On creation, the controller registers `rover_scan` on physical F if that action does not already exist. E, L and Enter are routed by the existing driver only while remote control is active. Target Areas use physics layer 8 (bitmask 128), with mask 0; world occlusion checks use layer 1 and exclude the rover hull. Target geometry does not obstruct driving. The stranded astronaut's capsule is enabled only during the rescue mission.

Open `scenes/rover_training.tscn` in Godot and select its root to tune `life_support_seconds` (480), `battery_drain_per_second` (0.012 percentage points per second before activity multipliers) and `scan_seconds` (3). The outpost instantiates this scene automatically; no manual node attachment or signal wiring is needed. Scanner range and speed tolerance are shared properties in `rover_scanner.gd`.

HUD nodes are built once. The controller publishes a view at 10 Hz and on objective transitions, using `hud_changed`; it does not rebuild UI each frame. Rules emit `changed`. Timed interactions are canceled on disconnection, invalid position or scene restoration, while completed objectives remain saved. Successful scans/interactions capture the existing sol checkpoint. Loading a save during a partial scan/drill starts that uncommitted interaction again, without awarding its result twice.

## Asset choices and limits

The telescoping drill arm, emergency package, relay and low-gravity dust are procedural training props, not newly imported production rigs. Electronic scan, contact, transmission and mechanism cues are synthesized through the existing `Gameplay_SFX` → `Effects` route. Radio acknowledgments are text plus tones; there are no recorded voice lines or rescue-vehicle assets. Independent pickup is a radio-confirmed handoff that removes the stranded astronaut from the worksite. None of these choices requires an editor fix to play.

## Verification

- Rules/save suite: 50 assertions passed.
- Rendered world integration suite: 45 assertions passed, including all three mission completions, real startup duration/mute checks, movement/aim/range/occlusion rejection, interaction interruption, pause, retry and rescue handoff.
- Existing driving regression: 54 assertions passed, including normal movement, damage, energy, repair, camera return and explicit mission retry.
- Existing game-audio suite: passed with rendering enabled. Its synthetic mouse tests fail in headless mode, so the rendered run is the relevant result.
- Existing menu-music/crossfade suite and game-menu/persistence suite: both passed with rendering enabled.
- Four-site terrain/target suite: 80 assertions passed across all four outposts.
- Rendered HUD inspected at 1360×820 and 960×540. The shadow-region shader compiled in the actual OpenGL Compatibility renderer; screenshots are under `.tools/rover_training_*.png`.

The sandbox reports pre-existing `user://` log/cache write errors and an imported rover texture UID fallback to its valid path. Some test exits also report ObjectDB cleanup warnings. These do not prevent the above tests from completing. This is focused automated verification plus screenshot inspection, not a claim of an exhaustive manual driving playthrough or hardware performance benchmark.

Reproduce the rule, world, site and driving suites with the bundled executable, for example:

```powershell
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/simulation/test_rover_training.gd
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_rover_training.gd
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_rover_training_sites.gd
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_live_operations.gd
```

Omit `--headless` for the synthetic GUI tests (`tests/ui/test_game_audio.gd`, `tests/ui/test_game_menu.gd`, and `tests/ui/test_menu_music.gd`) and for the world suite's screenshot captures.

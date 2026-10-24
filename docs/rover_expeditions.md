# Lunar rover expedition campaign

The campaign replaces the sequential outpost training flow with scheduled operations. It runs on Godot 4.7.2, using the existing Compatibility renderer. The original training rules/scene remain in the repository for historical compatibility; normal gameplay instantiates `rover_expedition_controller.gd` under the existing `RoverTraining` node name so the driver's input integration remains intact.

## Playing

Enter the lander with E, then use R or **Rover expeditions**. The original startup video/audio still gates driving. Drive into the violet departure circle east of the outpost, center the rover, and brake. A stationary dwell of 0.8 seconds starts the fade. The rover remains remotely controlled; the player stays seated at the outpost.

| Unlock | Operation | Controls and completion |
| --- | --- | --- |
| Sol 2 | Operation Surface Survey | Visit Fractured Plain, West Ridge, and Crater Rim. Stop within 6.5 m, face the target, and hold F for three seconds. Return through extraction after all three scans. |
| Sol 4 | Operation Frozen Horizon | Find the three supplied, gently bobbing droplet models. Stop facing each within 2.5 m and press E. The original rover's front instrument assembly moves through a six-second sampling/retraction cycle. Each completed marker disappears. Return after all three samples. |
| Sol 6 | Operation Lifeline | Search beyond the eastern saddle. No exact astronaut marker or coordinates are displayed. Approach with line of sight, stop, and press E to deliver oxygen and restore communications immediately. Radio text precedes the walking escort. Bring the astronaut within 9 m of extraction, then return through the circle for the arrival cinematic. |

W/S, A/D, Space, R, Esc and the existing startup behavior remain unchanged. L toggles headlights. Move the mouse to orbit the rover camera; the existing sensitivity and invert-Y settings apply. Forward/reverse limits are 2.4/1.0 m/s, with proportionally increased acceleration and braking. The hull can clear supported ledges up to 0.3 m; larger obstacles remain solid. The HUD supplies science-site bearings, the rover's heading, and an extraction bearing after objectives are ready. No new instruments, passenger seat, or rescue delivery animation are added.

Escort preferred separation is approximately 5 m. Above 12 m the rover is limited to 0.35 m/s; at 18 m it stops until the astronaut catches up. The astronaut follows saved breadcrumbs from the actual driven path, with a CharacterBody3D capsule, lunar gravity, slope limits, and collision. If blocked, it checks the next nearby breadcrumb for a clear route; the player can reverse along the approach to regroup. Recovery never teleports the astronaut in view.

Enter suspends an expedition and recovers the rover to the outpost under a fade without awarding completion. This provides a repair/range-budget escape. Objectives and rescued-crew position persist. Re-enter to resume; after suspending an escort, rejoin the astronaut to engage the escort speed limits again. R only disconnects remote control. Sol advancement is blocked while the rover is away; suspend or complete the expedition first.

## Architecture and persistence

`scenes/rover_expedition.tscn` supplies an 840 m square operational landscape with a coarse visual horizon. It is instanced as a physically separate location 4 km from the outpost in the same world. Keeping the original world loaded preserves the seated player, lander access, existing rover instance, cameras, audio autoloads, and NPC identities. Location transitions move that one rover under a fade; they do not spawn replacement rovers or transport the player.

The terrain shares `regolith.gdshader`, the outpost's generated rock mesh, lighting and sky. Three broad ridges, crater rims/bowls, a rescue shelter rock, sparse collidable boulders and open corridors distinguish the zones. It is authored gameplay terrain, not a georeferenced lunar survey or a scientifically established permanently shadowed region. No atmosphere, liquid-water surface, vegetation, or wind effects are introduced. The droplet model is a navigation symbol.

`MissionState.rover_expedition` stores completion IDs, the active operation, location, phase, survey/sample sets, rescue flags, astronaut position and escort route. The existing `MissionSession`, `MissionSave` and checkpoint machinery own persistence. Sols come only from `MissionState.sol`. The earliest unlocked incomplete mission remains assigned, including when overdue; completed missions never automatically restart.

The save validator checks types, unique objective/completion IDs, finite coordinates/routes, and return prerequisites. Legacy training saves retain completed earlier operations, survey scans, the previously collected B sample, and rescue assistance flags. Loading during a sampling action restarts the uncommitted action. Loading a return/cinematic snapshot resumes safely at expedition extraction, still requiring arrival at the outpost before completion. A generation token invalidates interrupted transition callbacks after a session replacement. Pause freezes tools, dialogue, escort, fades, audio and cinematics. There is no offline oxygen countdown; the emergency remains critical until assistance and stable afterward.

The four existing station NPCs plus the player are the five unique astronauts. The navigation station's commander is the missing person. Its existing node/model moves to the expedition location, its outpost interaction is disabled, and fieldwork stops reserving or updating it. After the cinematic it rejoins the outpost; no additional NPC model is spawned. Stable `crew_id` metadata maps the five existing actors to the crew resource.

The old resource model counted only four people despite displaying five. `crew.json` now includes the player and BVAD crew size is five. Per-person consumption constants are unchanged. Starting consumables increase 25%; starting battery/capacity increase by 120 kWh to cover the fifth person's extra 12 kWh/sol over the existing ten-sol campaign. Older four-person saves receive the corresponding remaining-sol energy provision and consumable scaling once on load, then save as five-person states. The four-site, first-choice ten-sol simulator baseline remains tested.

## Assets, animation, sound and integration

- `Assets/expedition/solar_panel.glb` and `water_droplet.glb` are copies of the supplied files, retaining embedded geometry/materials/textures. `transition_reference.png` records the supplied marker reference; the screenshot is not pasted into the game world.
- The original `Outpost/SolarArray` scene root, placement, simulation, output indicator and references are retained. Its visual children are two copies of the supplied solar asset, each uniformly fitted to a 3 m maximum dimension and spaced 3.6 m apart. The lowest actual frame vertices sit 1.5 cm inside the level landing pad, avoiding the empty space beneath the rotated mesh bounding box. Each panel has its own fitted collision hull. Constructed arrays elsewhere are unchanged.
- The Curiosity GLB has ten material-batched meshes and no arm bones or animation tracks. `rover_sample_arm.gd` partitions the original low front instrument triangles, preserving vertex attributes/materials, and articulates them around a limited 22-degree pivot. It restores the exact rest transform after sampling, interruption, or load. This is a conservative rigid-assembly animation, not a newly invented drill or a full inverse-kinematics rig.
- Rescue uses `astronaut_seated_pose.gd` on the existing suit rig and the existing `idle`/`moon_walk` clips. The return camera moves from wide to closer framing along the existing eastern raised terrain. Wheels use `rover_wheels.gd`; no new wheel animation asset is needed.
- Startup and background music are preserved. Existing rover motor audio is reused at low volume with smooth fades through `Gameplay_SFX`; scanner/confirmation telemetry uses the existing synthesized cue convention. Audio represents onboard/chassis/radio presentation.
- `hud_changed` drives the existing rover HUD. Scanner range/aim/speed/occlusion logic remains in `rover_scanner.gd`. Save/state refresh uses existing session signals. No new autoload, plugin, renderer setting, or second calendar is introduced. Physical F is registered as `rover_scan` if absent, as in the earlier training controller.

## Changed implementation files

| File | Responsibility |
| --- | --- |
| `src/simulation/rover_expedition.gd` | Scheduling, prerequisites, legacy progress migration and save validation. |
| `src/world/rover_expedition_controller.gd` | Mission integration, targets, transitions, crew rescue/escort, cinematic, HUD and sound. |
| `src/world/expedition_terrain.gd`, `scenes/rover_expedition.tscn` | Terrain, horizon, geology and collision. |
| `src/world/expedition_circle.gd` | Ground-conforming translucent circular markers. |
| `src/world/rover_sample_arm.gd` | Original front instrument geometry articulation. |
| `src/world/imported_asset_fit.gd` | Uniform scale/ground fitting for supplied models. |
| `src/world/lunar_outpost.gd` | Instantiates expedition integration and replaces the one requested solar visual. |
| `src/world/rover_drive.gd`, `rover_scanner.gd` | Escort speed limit, transition input lock, existing-crew sensor identity. |
| `src/world/crew_fieldwork.gd`, `lander_access.gd` | Missing-crew exclusion and expedition entry wording. |
| `src/simulation/mission_state.gd`, `mission_simulator.gd`, `src/runtime/mission_session.gd`, `mission_save.gd` | Saved expedition data, five-person provisioning and Sol guard. |
| `Resources/crew.json`, `Resources/bvad_constants.json` | Five-person roster/count. |

## Verification

Temporary developer control: open mission/details with Alt, set the Sol count, and click **DEV: Skip Sols**. This starts the selected mission if needed and jumps the calendar without simulating consumption or completing objectives. Existing decisions remain pending, and the per-Sol rover range resets. Stop rover control and return/recall the rover to the outpost first. Jumps stop at Sol 6; use normal simulation for the final outcome. The control and API are disabled in release builds. To disable during development, set `DEV_SOL_SKIP_ENABLED = false` in `src/runtime/mission_session.gd`; the HUD automatically hides its controls. Remove that method/constant and the matching conditional UI block in `src/ui/outpost_hud.gd` for final cleanup.

Driving follow-up: the rendered live-driving suite passed 61 assertions, including a 20 cm ledge without damage, doubled forward/reverse speeds, mouse orbit input, pause gating, and reversing away from a solid wall. The expedition integration suite also passed all 92 assertions after these changes.

Verified on 2026-10-24 with Godot 4.7.2: all 21 suites passed across the broad regression run and targeted reruns after fixes. The four expedition suites passed 186 assertions (16 rules, 68 site checks, 92 campaign integration checks, and 10 lifecycle checks). Lifecycle checks cover interrupted fades, stale callbacks, transient action/audio state, one-time legacy provisioning, and interrupted returns. Rendered inspection covered circles, the supplied solar model, original arm motion, seated rescue, and arrival cinematic. Environment/cache and existing asset UID warnings may still appear in logs.

Run the dedicated rules, four-site geometry, and world integration suites:

```powershell
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/simulation/test_rover_expedition.gd
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/world/test_expedition_sites.gd
& ./.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/world/test_rover_expedition.gd
& ./tools/test_member3.ps1
```

The world suite drives the real startup, circle dwell, scanner/actions, sampling animation, rescue assistance, escort/extraction gates, cinematic and save restoration. It deliberately positions the rover at test sites rather than manually driving every kilometre. Rendered captures are written to `.tools/expedition_*.png`. The existing live-driving suite separately checks acceleration, steering, collisions, energy, damage, repair and return to the lander. The old sequential-training world suite is superseded for normal campaign behavior; its isolated rules remain useful for legacy-save compatibility.

Visual inspection and automated tests do not establish a full manual playthrough, performance on lower-end GPUs, or arbitrary off-route escort recovery. A seated pose and conservative rigid arm motion are constrained by the supplied existing rigs. The terrain and route parameters are explicit gameplay tuning values and can be adjusted without changing the calendar or save ownership.

## Seven-Sol campaign and navigation update

New campaigns last seven Sols; legacy ten-Sol saves migrate to seven (later saved dates clamp to Sol 7, preserving recorded history). Manual Sol progression remains authoritative. During a mission, one Sol maps to one modeled Earth day, with sky movement interpolated over four seconds per advanced Sol. Waiting does not advance the sky past the mission date. Loads restore the matching sky date. Free orbital speed controls remain available outside an active mission.

The departure marker is now centered at (32, 12), about 34 m from the outpost origin. Science and extraction waypoints display a screen marker, distance, and edge arrow. Rescue provides only a broad search-area marker until escort return. The terrain has seven broad ridges and eight crater bowls, with existing objective access checks preserved.

The two ground-mounted solar panels face the average above-horizon Sun direction sampled hourly over the seven-day campaign at the selected site. This is a fixed mounting adjustment; resource production remains owned by the simulation.

Rover health only falls for horizontal obstacle impacts of at least 0.65 m/s. Crew and terrain contacts never cause damage, vertical settling is ignored, and repeated impacts have a one-second cooldown. Rocks, structures, and boundary walls remain solid and can cause bounded impact damage (maximum 30 per impact).
Verified 2026-10-25: the regression suites passed across the main run and targeted reruns after updating legacy ten-Sol fixtures. Checks include 62 driving assertions, 68 site-access assertions, 92 expedition assertions, 1,506 orbital checks, six impact-rule checks, 15 developer-skip checks, dashboard outcomes, and save/restart behavior. Solar placement and mission navigation were also inspected in rendered captures.

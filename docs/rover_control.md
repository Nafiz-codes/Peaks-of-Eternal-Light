# Lander-only rover driving

Current behavior, October 17, 2026. This supersedes the earlier automatic dispatch/loop presentation.

1. Approach the lander hatch and press **E** to enter the crew seat.
2. Press **R** or use **Control rover**. A mission starts at the selected site if needed. Resolve pending decisions before entering control mode.
3. The view switches to a trailing remote camera. The astronaut remains seated inside the lander.
4. **W/S** accelerates forward/reverses, **A/D** steers, **Space** brakes. **R** parks the rover and returns to the lander camera. **Esc** pauses. Press **E** to exit the lander after leaving rover mode.

Exterior and dashboard rover panels are inspection-only. There is no rover-side control interaction and no 3 km dispatch button. The session rejects movement requests unless the active world controller has an astronaut seated in the lander.

## Movement and mission integration

`src/world/rover_drive.gd` uses a colliding CharacterBody3D, gradual acceleration/braking, slower reverse, speed-dependent bicycle steering, gravity, floor snapping and terrain-normal chassis alignment. Steering does not rotate a stationary rover. Default forward/reverse limits are 1.2/0.5 m/s with 0.35 m/s² acceleration and 0.9 m/s² braking. These are gameplay tuning values, not measured Curiosity performance. The six original tires roll by accepted travel divided by their radius, reverse with travel, and steer along the bicycle turning circle with different inner/outer angles and speeds. Wheel animation stops when parked or movement is rejected. Suspension is not independently simulated.

Actual horizontal travel in metres is converted to kilometres and submitted to the existing simulator's traverse action. Existing energy, range and pending-event rules remain authoritative. Rejected travel is rolled back, stops the rover and displays its reason. UI state publishes at 4 Hz; stopping control captures a checkpoint. Rover position and heading persist in mission saves; old saves without that field load at the original parking position. Mission reset restores parking. Reduced motion does not skip player-controlled travel.

## Validation

Rover health starts at 100 and persists in saves; older saves default to full health.
The remote camera shows a health bar, and a label above the rover displays its score.
Impacts against collidable obstacles reduce health according to impact speed (minimum
5 points for impacts above 0.1 m/s). Walkable ground and sustained contact do not
cause repeated damage. At zero health, driving is disabled. Press R to leave remote
control, exit the lander, approach the rover and press E to repair it to full health.
Repairs require the astronaut to be on foot beside the rover and consume one finite
replacement kit plus mission material. Away from base, carry a kit from the field
supplies locker. See [crew fieldwork](crew_fieldwork.md) for NPC maintenance,
equipment priorities and supply delivery.

The combined runner passes 13 suites including lander entry/exit and remote driving. The driving suite passes 29 assertions and covers exterior denial, real hatch entry, R and W input, acceleration, curved steering, braking, reverse, collision, energy accounting/rejection, pause, camera/input restoration, save compatibility and reset. The separate game-menu/persistence test also passes; its temporary files now use the writable `.tools` folder. The rendered camera view was inspected after hiding the overlapping exploration hints. Rendered remote-camera capture is available using:

```powershell
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tests/world/test_live_operations.gd -- --capture
```

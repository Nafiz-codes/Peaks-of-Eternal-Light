# Game menu

The Controls page includes lander-only rover driving: R enters/leaves the remote camera, WASD drives/steers and Space brakes. Esc pauses driving. Saves also preserve the rover's position and heading; saves made before this addition remain compatible.

Press **Esc** to pause. Esc returns from a submenu to the main menu, then resumes
play. Existing decision dialogs handle Esc before the pause menu. Tab moves focus;
Enter activates buttons. Movement, camera motion, and NPC animation stop while paused.

The menu provides mission status, objectives, dashboard/report access, controls,
mission help, and the project's science sources. Restarting a sol or mission,
loading a save, returning to landing selection, and quitting require confirmation.

Three local save slots preserve mission state, decisions, event history, astronaut
pose, and the current sol checkpoint. Restart sol restores the checkpoint captured
at the start of that sol. Settings persist separately in `user://settings.cfg`;
saves use `user://mission_slot_1.save` through `user://mission_slot_3.save`.

**Esc → Outposts** lists all four locations and marks the current one. Click
**Travel here** and confirm to enter another outpost without restarting the game.
Save first to retain the current mission's progress; switching clears the current
mission and spawn pose, while existing save slots remain available. The same page
also provides access to the landing globe.

Settings include mouse sensitivity, inverted look, reduced motion, fullscreen,
brightness, anti-aliasing quality, and audio bus volumes. Music and effects volumes
are ready for tracks routed to those buses; this change adds no audio tracks.
Brightness changes the display without changing the Sun or scene lighting.

Construction and rover operations retain their existing preview-only behavior.

Run the menu and persistence integration test with:

```sh
godot --headless --path . --script tests/ui/test_game_menu.gd
```

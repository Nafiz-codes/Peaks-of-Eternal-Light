# Earth–Moon outpost navigation

## User-request precedence

The follow-up message explicitly asks for names at exact outpost locations. This supersedes the attached prompt's no-name-label rule. Exploration therefore shows the two top-right zoom controls **and geographically anchored outpost names**, with no sidebar, heading, or other navigation panel. Names on the far hemisphere and offscreen anchors are hidden; labels are never clamped to a false coordinate.

## Flow and ownership

`startup.gd` retains the credits, astronaut menu and departure. It loads the existing `lunar_landing_selector.tscn` once, enables `lunar_navigation.gd`, and starts the planetary entrance alongside the astronaut's departure. The same selector becomes the current scene. No Moon asset, geometry, material, texture, coordinate data or environment is replaced.

`lunar_navigation.gd` is a child of that selector and owns its camera during:

`DORMANT → ENTRANCE → OVERVIEW → APPROACH → [FOCUS] → EXPLORE → RETURNING → OVERVIEW`

Surface selection enters `LANDING` and releases camera ownership to the existing landing animation. A single replaceable camera tween prevents zoom/orbit/focus conflicts. Sidebar selection focuses the chosen coordinate, then automatically runs the existing landing transition into that outpost scene. No second surface click is needed. Clicking the Moon itself still enters free exploration, where clicking a surface name invokes the same mission entry. Direct Moon selection never chooses an arbitrary outpost. Escape returns exploration to the overview through the existing GameMenu input router.

The original selector's standalone entry point retains its previous interface for existing direct scene consumers. The new flow is enabled by the startup scene.

## Independent planets

The Moon remains at its original world transform. Orthographic camera offsets and size control its screen position and apparent scale: it descends from above, approaches center, then becomes freely interactive. Earth is a separate presentation sphere using the project's existing diffuse, cloud and night textures, with a lightweight local shader. Its screen-relative position rises from below and later retreats below the frame. The reference image is composition guidance, not a single animated image or a replacement Moon.

Moon clicks use ray/sphere intersections with a foreground Earth depth test. GUI event propagation blocks sidebar and zoom controls. Left-drag input has a movement threshold and release checks so dragging from a name cannot initiate landing. Right-drag and wheel zoom remain available.

## Coordinates, typography and fullscreen

Names and IDs come directly from `Resources/sites.json`. The existing planetocentric coordinate conversion feeds both geographic name projection and the shared site camera target used by focus/landing. Text is centered on each projected surface coordinate; outline and a restrained translucent backing keep it readable. The scaled sidebar uses an MSDF font. Surface font size adapts to viewport height.

All overview layout, planet screen positions and zoom controls use the current viewport dimensions and are recomputed on resize/fullscreen changes. Camera transition progress is normalized rather than storing old pixel destinations. The live Moon's world coordinates remain unchanged.

## Tests

`tests/ui/test_lunar_navigation.gd` exercises the real startup handoff, independent entrance progress, all four sidebar entries, direct Moon clicks, background/Earth rejection, foreground occlusion, repeated-click locking, zoom, orbit, exact projected label positions, Escape return, drag-versus-click handling, and surface selection through to the original outpost scene. The rendered run switches the window into actual fullscreen and restores the previous mode. Captures at 1366×768, 1600×900 and 1920×1080 are stored under `.tools/navigation-*.png`.

The startup regression was updated for the new overview destination. The legacy selector and landing-transition tests remain applicable.

Run, for example:

```
.tools/godot/Godot_v4.7.2-stable_win64_console.exe --path . --script tests/ui/test_lunar_navigation.gd
```

The project still emits the existing rover invalid-UID fallback warning and a shutdown RefCounted warning. These do not fail the functional checks but remain unresolved. No sustained 60 FPS or cross-device performance certification is claimed.

Verified on Godot 4.7.2 / OpenGL (RTX 2050): the rendered navigation test, rendered startup test, legacy selector regression, landing-transition regression, and game-menu/persistence regression all passed. The startup regression additionally checks centered credits at 1920×1080. Actual fullscreen switching was exercised in the navigation run.

Both menus support mouse hover/click, wrapping arrow-key navigation, Tab/Shift+Tab, and Enter/Space activation. Explicit focus paths in menu_navigation.gd keep this independent of the animated positions. The updated navigation test uses real key and mouse events and verifies automatic gameplay arrival for all four sidebar choices, plus the alternative direct-Moon/surface-name route.

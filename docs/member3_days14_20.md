# Member 3: Days 14–20 implementation and handoff

Implemented and checked October 5, 2026. The user explicitly retained Member 3 scope: presentation, UI, animation and integration. No simulation formulas, resource costs, event effects, balance values or authored content were changed.

## Schedule status

| Day | Member 3 work delivered | Remaining dependency |
| --- | --- | --- |
| 14 | Re-ran all existing simulation/UI/world regressions, including four real-site missions and ten authored decisions. Added a repeatable test runner that checks runtime errors as well as process exit codes. | Joint team acceptance and standard-mission balance remain open. |
| 15 | Shared construction/rover panels in the outpost and dashboard, real catalog bindings, mission-state inspection, modal input guards and focus restoration. | Live actions and additional report/crew data require their owning members. |
| 16 | Rover parameters, last action and prospect status UI; reusable confirmed-route animation component with moving collision hull, duplicate rejection, input validation and reduced motion. | No gameplay API supplies a confirmed route. The production rover remains parked. Component behavior is fixture-tested, not a playable rover mechanic. |
| 17 | Six illustrative structure silhouettes; explicitly labeled, noncolliding placement ghosts; completed structures and shielding read existing `built_structures` state and receive collision hulls. | No build action or queue API exists. There is no fabricated build progress or shielding benefit. Completion rendering is fixture-tested. |
| 18 | Regression fixes for null-choice notification content, background input during modals, and switching reduced motion on during animation. | Physical keyboard/controller playtesting is still a human follow-up; automated controls and rendered layouts were checked. |
| 19 | Responsive report resource chart, selectable resource with units, exact text history, decision descriptions and outpost record. | Authored outcome guidance and independence/advanced metrics remain unavailable. |
| 20 | Integrated planning, previews, available construction state, event activity and reporting across world/HUD/dashboard. Nine suites pass. | Full live rover/construction feedback cannot be certified before the missing action systems arrive. |

Days 16, 17 and 20 are presentation implementation plus a documented handoff, not completed end-to-end gameplay. No all-member sign-off is claimed.

## Every implementation change

### `src/ui/operations_panel.gd` — new shared modal

- Both views use the same scrollable, responsive planning dialog.
- Construction cards read all six entries from `construction.json`: name, material/energy cost, build time and authored effect description. No effect text is executed or parsed into gameplay formulas.
- Completed/not-completed labels read the existing mission `built_structures` dictionary.
- Build and dispatch commands stay disabled and carry an explicit availability explanation.
- The outpost offers an illustrative placement-preview button. The dashboard only offers inspection because it has no visible 3D world to preview.
- Rover inspection shows authored energy/km, distance cap, discovery chance and provenance, plus current last action and prospect status.
- Opening focuses Close; closing restores the invoking control. Exclusive modal behavior prevents interaction with controls underneath.

### `src/world/construction_presentation.gd` — new world presentation

- Fixed slots within the flat outpost pad give each supported structure a deterministic illustrative location.
- Solar arrays have panels/supports, water extractors have a tank/base, shielding uses stacked blocks, relays have a mast/antenna, and greenhouse/habitat modules have contrasting windows.
- Preview meshes are translucent and labeled `PLACEMENT PREVIEW / NOT BUILT`. They have no physical collision and never debit resources or write mission state.
- Only keys actually present in `built_structures` produce completed visuals. Repeated refreshes do not duplicate them; removed keys remove visuals. Completion of a previewed structure clears its ghost.
- Completed visuals have collision hulls. Shielding is visual only: no dose reduction is computed in presentation.
- These are small illustrative silhouettes, not final imported models or authoritative geographic placements.

### `src/world/rover_presentation.gd` — new animation handoff component

- `play_confirmed_route(rover, hull, result, reduce_motion)` takes a successful result containing a nonempty unique `action_id` and a `presentation_route` array of at least two finite `Vector3` points.
- Valid segments interpolate the model and turn its heading toward movement. The collision hull follows the same position.
- Rejected actions, malformed points, missing identifiers and duplicate action IDs do not start animation.
- A newer valid action cancels the previous tween. Reduced motion snaps to the confirmed endpoint; switching reduced motion on also finishes an already-running route.
- Animation timing is visual and does not imply sol duration, travel distance in kilometres, power consumption or discovery.
- There is deliberately no production dispatch caller. This is a provisional Member 3 adapter, not an agreed or implemented Member 1 action API.

### `src/ui/mission_activity.gd` — new common activity formatter

- Shows pending decision count, active effect IDs/durations and resolved decisions with their recorded sol.
- Uses Member 2's authored choice text when an event/choice ID matches, otherwise uses readable identifiers.
- Supports notification events whose `choices` value is null. That real content case was caught and corrected in the initial integration test.
- Reads state only; it never predicts or recalculates consequences.

### `src/ui/resource_history.gd` — new report chart

- Offers Energy, Water, Oxygen, Food, Accumulated dose and Materials.
- Displays one resource/unit at a time, with a zero-based vertical scale, sol axis, points and connecting lines.
- Copies history for presentation and exposes matching text rows with three decimal places so the chart is not the only way to read values.
- Resizes with the report. Empty history hides the graph; missing values are labeled unavailable; zero-valued single-point history is supported.

### `src/ui/outpost_hud.gd` — world integration and input fixes

- Adds Construction planning and Rover operations controls and a Clear placement preview control.
- Reads catalog data from the loaded simulator, or the construction file before a mission exists.
- Connects preview requests to the world presentation and explicitly reports that no build/resources changed.
- Shows common event activity below the action row.
- Treats event and operations dialogs as modal owners: Alt cannot toggle the HUD underneath them, walking is blocked, and advance/report actions cannot execute through them.
- Closing operations restores focus and releases the walking block. Cursor remains available until the existing exploration controls recapture it.
- Keeps a handle to the reserve-reading tween so reduced motion immediately restores its normal color instead of leaving an animation running.

### `src/world/lunar_outpost.gd` — world bindings

- Instantiates the construction and rover presentation components after the base assets/collision hulls exist.
- Refreshes completed structure visuals from authoritative state and the catalog on the existing `state_changed` signal.
- Reduced motion finishes an in-flight rover tween and an in-flight overview camera transition at their intended endpoints.
- Existing scenery, terrain boundaries, source data and base asset layout remain intact.

### `src/ui/mission_dashboard.gd` — shared controls and report polish

- Replaces the two dead-end Build/Rover buttons with the shared inspection dialogs.
- Prevents background sol advancement while operations/restart dialogs are open, and prevents returning to the world through any open dialog.
- Adds common active-effect/decision details to mission activity.
- Replaces the dense slash-separated history block with the resource selector, chart and matching text history.
- Decision history now includes authored choice descriptions when available.
- Adds an outpost record with completed-structure count and last recorded rover action.
- Keeps existing authoritative outcome, failure cause/sol, reserves, completion metric and provenance. It does not invent missing report guidance.

### Tests, tooling and records

- `tests/world/test_member3_days14_20.gd`: 56 headless assertions cover the new UI, disabled actions, actual preview-button signal, no state mutation, completion fixtures, collision presence, duplicate refresh, clearing/reset, focus/input ownership, rover interpolation/endpoints/validation, reduced motion, real terminal-report history, empty/missing values and dashboard modal guards.
- Its optional `--capture` mode runs the same checks with OpenGL and writes seven screenshots; those save checks bring the total to 63 assertions.
- `tools/test_member3.ps1`: runs all nine suites, saves per-suite logs and fails on unexpected Godot errors even if a test exits with code zero. Only the two known environment diagnostics for user-log access and Windows certificates are allowed in headless mode.
- Godot-generated `.gd.uid` sidecars identify the five new production scripts.
- This document, `logs.md`, `docs/UI_UX.md`, `docs/day14_integration.md` and `TRIARCHY_Workflow_Split.md` record actual scope and test status without rewriting historical entries.

## Validation results

Godot 4.7.2:

- **9/9 suites passed**: simulator, dashboard, landing selector, landing transition, lunar outpost, landing-site session, four-site integration, scene navigation, and the new Days 14–20 presentation suite.
- New suite: **0 failures / 56 assertions headless**; **0 failures / 63 assertions with OpenGL captures**.
- Inspected construction panels and report charts at **1360×820** and **520×900**, plus placement preview, all-completed structure fixture and rover panel renders.
- The four-site test still reports the first-choice route failing on Sol 10 at ridge_a and Sol 9 at the other three sites. Presentation changes do not resolve balance. Ten authored decisions were exercised, not all 19 events or all branches.
- **Superseded by Member 1's Oct 8 balance pass:** the starting reserve is now 170 kWh and all four sites complete the current 10-sol first-choice route in the updated Godot 4.7.2 integration checks. The original result above remains valid for the Oct 5 build. Rover/build actions and unexercised event branches remain open.
- Expected restricted-environment diagnostics remain: user-log write access and Windows certificate store; rendered checks also cannot create the shader cache. No GDScript errors remained in passing runs.
- This is automated interaction and rendered inspection, not physical keyboard/controller playtesting or teammate acceptance.

Run from the repository in PowerShell:

```powershell
.\tools\test_member3.ps1
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tests/world/test_member3_days14_20.gd -- --capture
```

Logs and screenshots are under `.tools/day20/` (local, ignored by Git). The screenshots whose names include `fixture` contain test-injected completion state, not gameplay-produced builds.

## Handoff still required from Members 1/2

1. **Rover:** an authoritative action API, accepted/rejected outcomes, unique action IDs, position/route state and persistence across scene visits. The presentation adapter currently expects world-local metre positions; it must be mapped to the final agreed contract rather than assuming km equal world metres. Costs/discoveries remain simulation decisions.
2. **Construction:** an authoritative build request, rejection reasons, construction queue/progress and completed-state updates. The existing `built_structures` dictionary is consumed read-only. No arbitrary placement or in-progress contract is assumed.
3. **Shielding:** simulation-owned dose effects and combination rules. The visible wall alone conveys no quantitative reduction.
4. **Content/report:** remaining supported effect keys, action-gated event coverage and per-crew status. Authored outcome guidance is now present in `mission_copy.json` and is read by the dashboard. Catalog descriptions are planning information, not evidence those effects run.
5. **Integration acceptance:** the normal-length route now succeeds on all four sites after Member 1's Oct 8 energy-balance adjustment. Shared team sign-off and review of all event branches still remain prerequisites for the later vertical slice.

## Try the changes

Run the project, choose a landing site, press **Alt**, then open **Construction planning** or **Rover operations**. A construction card's preview button places a labeled ghost; **Clear placement preview** removes it. Start/advance the mission and resolve decisions to see activity records. Open the terminal report and select a resource to inspect its graph and sol-by-sol values.

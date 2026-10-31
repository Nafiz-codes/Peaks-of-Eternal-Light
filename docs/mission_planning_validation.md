# Executed validation — 1 November 2026

Engine: bundled Godot 4.7.2 stable, Windows. Test user data was isolated under
`.tools/planning-*`, keeping normal user saves separate.

## New feature checks

`tests/simulation/test_mission_planner.gd`: **0 failures** on the final calculation
and persistence code. Covers three zones per site; viable defaults at all four
outposts; site-correct solar integration; cable/material layout tradeoffs;
battery reserve/limited-margin/darkness behavior; route/load/handling changes;
infeasible routes; immutable mandatory cargo; capacity/quantity/NaN rejection;
unknown identifiers; actual disk save/load; legacy saves; tampered approvals;
duplicate event suppression; isolated handoff records; and unchanged established
mission inventory.

`tests/ui/test_mission_planning.gd`: **0 failures**, headless and with the OpenGL
renderer. Uses the actual startup, existing video-finished callback, Commander
confirmation, selector and planning scene. Visits all four sites and six screens;
tests back navigation through the selector, edits, save/load, approval, pause-menu
access, pre-mission music state, and final surface handoff with delivery pending.
This is a programmatically driven integration test, not a claim that a human
played the entire sequence.

Rendered images at 960×720 were visually inspected. This caught and corrected
zero-width wrapped controls that the headless tests could not detect. Inspected
captures include `.tools/planning-review.png`, `planning-cargo.png`, and
`planning-review-bottom.png`.

Additional passing targeted runs:

- Existing selector and updated selector→planning→approval→surface transition.
- Outpost navigation, scene return and mission reset.
- Arrival camera: **1,387 clearance samples**, no failures, exercising the
  established-mission path that retains the original arrival transition.
- Polar ephemeris: **260 checks**, no failures.
- Rover expedition: **92 assertions**, no failures, with a longer time allowance
  than the broad sweep's initial 60-second per-script limit.
- Earth lighting: **4 checks**, no failures with its required renderer.
- Sun lighting: no assertion failures across all four outposts.
- `git diff --check`: no whitespace errors.

## Broad regression run

All **43** current `test_*.gd` scripts were attempted, including the two new tests.
The initial headless sweep had **31 passing scripts, four failing scripts and
eight timeouts**. A timeout is not a passing result. Raw results are in
`.tools/planning-regression/results.json`; stdout/stderr and engine logs are
alongside it. Several follow-up runs above supersede this initial sweep:
arrival-camera expectations were updated for the new intermediate screen,
Earth lighting needed a renderer, and the expedition needed a longer allowance.

Known legacy failures and limitations identified during the run:

- `test_member2_systems`: four assertions about authored productivity/resource
  effects fail. The same failures appeared in the initial baseline run.
- `test_game_audio`: headless synthetic hover/click assertions fail; these also
  failed in the initial baseline run. See follow-up results below.
- `test_lunar_navigation`: existing animation/input expectations fail in the
  headless baseline. Its expected destination was updated to planning; the
  obsolete arrival-camera assertion was replaced. See follow-up results below.
- `test_menu_music` and `test_startup`: old tests access Commander selection
  immediately after Start, although the existing startup now plays its opening
  movie first. They report errors and do not complete within the initial limit.
  The new integration test explicitly follows the existing video-finished path.
- `test_member3_days14_20`: its fixed parked-rover-position assertion fails.
- `test_rover_training`: accesses a missing `rules` property on the existing
  expedition controller and then times out. The simulation-level training and
  training-site tests pass.
- `test_tycho_elevation`: two collision-height assertions compare a procedural
  terrain fixture (no `terrain_model`) against the legacy Tycho height function.
  This change does not reintroduce Tycho as an outpost. A rock-variant coverage
  failure observed after planning clearance was fixed; all nine authored rock
  variants remain represented.

Some Godot runs report ObjectDB cleanup leaks at exit; the rendered sun-lighting
run also reported two GL texture cleanup leaks. These are recorded separately
from test assertions and are not claimed to be resolved.

Final follow-up outcomes are recorded below once the remaining long/rendered runs
finish. The repository-wide suite must not be described as fully green.

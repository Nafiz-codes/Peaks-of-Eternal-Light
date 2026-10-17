# Day 1–20 completion audit — October 17, 2026

**Subsequent user-requested change:** Lander-only WASD rover driving replaces automatic dispatch and its loop animation. See [current rover controls and validation](rover_control.md). The earlier dispatch counts and behavior below are historical.

Scope: the outstanding work through Day 20 for all three members. This is the current status; dated earlier logs describe earlier builds.

**Rover follow-up:** The loop now lasts 7.5 seconds. Fresh-landed players can start a mission inside the operations dialog; rejected commands keep that dialog open with a visible reason and recovery instruction. The strengthened live test passes 219 assertions with mouse input, including fresh starts and rejection feedback while the HUD is hidden. Earlier assertion counts below record the initial completion pass.

| Owner | Current result | Remaining item |
| --- | --- | --- |
| Member 1 — simulation/data | Scheduled runtime work and regression checks complete. Live construction, rover, event effects, resource/report publication and shielding are implemented. | Global site-data refresh remains blocked on retrieval and sampling of the preferred hydrogen grid. Illumination remains a disclosed model, as permitted by the revised Day 11 snapshot contract. |
| Member 2 — systems/content | Day 1–20 implementation and automated integration complete. The old Day 7 runtime-interface partial is closed by the combined regression run. Briefing/tutorial now correctly describe the identified but unsampled global map. | Human solo-playtest acceptance is not inferred from automated routes. |
| Member 3 — presentation/integration | Days 16/17/20 now have live action-to-world verification, alongside the earlier screens, event feedback and reports. | Human keyboard/controller playtest and team acceptance remain unrecorded. |

## Completed in this pass

- Connected authoritative rover-distance changes to a short illustrative world excursion and return. Rejected actions and unchanged refreshes cannot trigger it; successive surveys have distinct identities. Moving collision follows the rover; reduced motion finishes immediately. Restart clears presentation state. Re-entering a scene initializes from current mission state without replaying old dispatches.
- Added a proximity interaction to the rover that opens its operations panel. Actions continue to use the existing simulator/session APIs and authored costs; this is dispatch-based movement, not player steering or a kilometre-scale terrain map.
- Verified live construction from the visible queue button through simulation progress, completed world structures, shielding-wall collision and mission restart. Existing previews remain non-mutating, and queued structures do not appear completed early.
- Corrected the default Godot path in `tools/test_member3.ps1` and expanded it from nine to twelve suites, including Member 2 event/system tests and the new live-operations test.
- Corrected briefing/onboarding hydrogen wording and updated source-access evidence.

## Verification

`./tools/test_member3.ps1`: **12/12 suites passed** on Godot 4.7.2. The new `tests/world/test_live_operations.gd` passed **207 assertions**, including four ten-sol success routes with real build/rover operations and authored event decisions. It checks energy spending, movement/collision, repeat/rejection handling, reduced motion, actual completed structures and reset. Existing simulator tests separately verify shielding-dose effects and event handlers.

The presentation suite also passed with OpenGL capture (**60 assertions**). Inspected the current narrow construction layout, rover panel and narrow report: controls and text fit within scrollable panels. Images are generated under `.tools/day20/`. Automated input/scene checks are evidence for software behavior, not a claim that the teammates physically playtested or signed off.

Known environment diagnostics: Godot cannot write its `user://logs/godot.log` or create its shader cache in this sandbox. They are distinct from test assertion/script failures.

Additional verification: lunar locomotion passed at its tested physics rates; the dashboard suite passed again after the science-copy change. Both edited JSON contracts parse, and `git diff --check` passes. Historical HTML wireframes are superseded for runtime acceptance by the rendered Godot screens; no browser review of that old design artifact is claimed.

Reproduce:

```powershell
.\tools\test_member3.ps1
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --path . --rendering-method gl_compatibility --script tests/world/test_member3_days14_20.gd -- --capture
```

## External data blocker

On October 17 the public archive API for `figure6.txt` (file 16635) returned **HTTP 403**, including a download attempt outside the restricted network environment. Web retrieval also failed. The [repository metadata](https://archive.data.jhu.edu/file.xhtml?fileId=16635&toolType=PREVIEW&version=1.0) still identifies the public 10.6 MB file and MD5 `ed174cc5b25857e6c88f6d9d815922c5`. No valid data bytes were acquired.

To close this item, obtain that public source file, verify its checksum and coordinate/grid conventions, sample the four site footprints with the documented resolution/uncertainty, and update provenance and active site fields. Existing negative/quality-limited legacy values are not a substitute. No site hydrogen value was fabricated. Human playtest/team acceptance and this external data item prevent an unconditional “everything complete” sign-off.

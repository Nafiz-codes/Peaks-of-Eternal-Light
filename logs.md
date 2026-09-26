# Triarchy — Daily Logs

Reference: `TRIARCHY_Workflow_Split.md` for what each day's task is.

**How this works:** after you finish your task for a given day, add one entry under your own section below, using the template. If you're using an AI assistant (Codex, Claude, etc.) to help you build, have it write the entry for you once the day's task is actually done — not before. On 🔗 Test & Integration days, all three members log, since the outcome affects everyone.

**Note on Day 1:** the five data-file scaffolds (`sites.json`, `bvad_constants.json`, `crew.json`, `construction.json`, `events.json`) already existed going into kickoff — Day 1's log entries should say "reviewed scaffold," not "created," so the history stays accurate.

```
### Day N — [Date] — [Task from Workflow Split]
- Status: ✅ Done / ⚠️ Partial / ❌ Blocked
- What was completed:
- Issues / blockers:
- Notes for teammates:
```

---

## Member 1 — Simulation & Data Log

*(entries go here, oldest first)*

### Day 1 — Sep 26 — Kickoff: review the five existing data-file scaffolds
- Status: ✅ Done
- What was completed: Reviewed the locked `sites.json`, `bvad_constants.json`, `crew.json`, `construction.json`, and `events.json` schemas. Added `Resources/data_sources.json` as a source registry and `Resources/README.md` with the refresh/provenance process; the five contracts were not changed.
- Issues / blockers: Site coordinates and field-level NASA product readings have not yet been selected or recorded, so all current site and BVAD values remain explicitly unverified.
- Notes for teammates: Use only `verified:true` scientific values in the simulation. Game-balance values in crew, construction, and events remain distinct from NASA source measurements.

### Day 2 — Sep 27 — Project/sim skeleton reading from the scaffold files
- Status: ✅ Done
- What was completed: Created the Godot 4.7 project configuration, deterministic `MissionState`, and `MissionSimulator`. The simulator reads all five locked resource contracts, initializes a selected-site mission, advances one sol at a time, and records snapshots. Added a headless contract/state-transition test.
- Issues / blockers: Resource formulas are intentionally deferred to the next scheduled tasks; site and BVAD source fields remain unverified and therefore are loaded without being treated as validated science inputs.
- Notes for teammates: UI integration can import `res://src/simulation/mission_simulator.gd`, call `load_contracts()`, then render the `MissionState` returned by `begin_mission()` and `advance_sol()`.

---

## Member 2 — Systems & Content Log

*(entries go here, oldest first)*

---

## Member 3 — Presentation & Integration Log

*(entries go here, oldest first)*

---

## Shared Test & Integration Notes

*(one combined entry per 🔗 day — what was tested, what passed, what needs fixing before the next block of days starts)*

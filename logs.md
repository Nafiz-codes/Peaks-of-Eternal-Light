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

### Day 3 — Sep 28 — Core tick loop: power and radiation formulas
- Status: ✅ Done
- What was completed: Added deterministic solar generation from each site's illumination field, crew baseline power consumption from `bvad_constants.json`, battery-reserve updates, active-event generation multipliers, and cumulative radiation. Terrain shielding is derived from each site's elevation and slope fields. The tick returns power and radiation detail for presentation consumers; tests cover the Ridge A resource calculation and radiation update.
- Issues / blockers: The site fields remain unverified placeholders and the radiation baseline is explicitly a provisional gameplay calibration until the scheduled CRaTER source pass. Neither is presented as a NASA measurement.
- Notes for teammates: `advance_sol()` now returns `power` and `radiation` dictionaries alongside the state. The UI can safely display `power_generated_kwh`, `power_consumed_kwh`, `power_balance_kwh`, `radiation_this_sol_msv`, and `terrain_shielding_factor` from `MissionState` when live binding begins.

### Day 4 — Sep 29 — Core tick loop: water, food, and O2 threshold logic
- Status: ✅ Done ahead of schedule on Sep 28
- What was completed: Added per-sol water consumption and recovery, oxygen consumption, food consumption, and life-support resource statuses (`nominal`, `warning`, `critical`, `depleted`). The state and tick result now expose consumption/recovery details for UI integration. Tests cover ordinary resource flow and a critical oxygen reserve.
- Issues / blockers: The BVAD fields are still `verified:false`; this logic is structurally complete but must be recalibrated when Member 1 records exact NASA BVAD table/page sources.
- Notes for teammates: Read `life_support_status` from `MissionState` or the `life_support` result returned by `advance_sol()`. No construction production or event effects are included yet; those belong to later scheduled integration work.

### Day 5 — Sep 30 — NASA site data for sites 1 and 2
- Status: ✅ Done
- What was completed: Replaced fictional coordinates, illumination, elevation, slope, and hydrogen placeholders for Ridge A and Shadow Zone with reproducible NASA values. Illumination comes from NASA PDS LRO/LROC WAC's percentage-based south-pole product; terrain comes from NASA GSFC PGDA 5 m LOLA Connecting Ridge and Shackleton Rim datasets. Sampled NASA PDS LEND's south-polar averaged-count product (`LEND_RDR_ALDS_20090915`) at the two corresponding 0.5° cells, and recorded the CSETN rate/error in each field's provenance. Filled `hydrogen_ppm` with NASA's LEND regional estimate of approximately 140 ppmw H for terrain above 88° latitude.
- Issues / blockers: LEND's archived product stores neutron count rates rather than direct ppm values. The 140 ppmw estimate is a cited regional LEND model result and does not resolve differences between the two map cells; it must not be described as a direct landing-point assay or confirmed ice.
- Notes for teammates: Ridge A has verified light and terrain values at Connecting Ridge; Shadow Zone has verified light and terrain values inside the Shackleton Rim dataset. Their current hydrogen entries are scientifically sourced regional resource-potential estimates, so game systems must not create artificial site differences from the identical 140 ppmw value.

---

## Member 2 — Systems & Content Log

*(entries go here, oldest first)*

### Day 1 — Sep 26 — Kickoff: review the five existing data-file scaffolds
- Status: ✅ Done
- What was completed: Reviewed the locked `sites.json`, `bvad_constants.json`, `crew.json`, `construction.json`, and `events.json` scaffolds from the Systems & Content perspective. Confirmed that the construction/rover, crew, and event-content contracts contain the fields required for the scheduled content work; no Day 1 scaffold was created or structurally changed.
- Issues / blockers: NASA-derived site and life-support values remain explicitly unverified, so content balance must continue to treat them as provisional until Member 1 validates them.
- Notes for teammates: `events.json` remains at its eight-event starter set and the existing field names should be preserved when expanding it. Member 2 will use the current rover fields for discovery-oriented content.

### Day 2 — Sep 27 — Review + retune `construction.json`'s `vehicles.rover` block
- Status: ✅ Done
- What was completed: Reviewed the rover balance fields in `Resources/construction.json`. Replaced the movement cost with a NASA-VIPER-derived 0.55 kWh/km value (397 W typical direct-drive load divided by 0.72 km/h top speed). Retained the 6 km per-sol round-trip cap and 7% independent discovery roll as explicitly labeled gameplay assumptions; at full range, the discovery chance is roughly 35%.
- Issues / blockers: Rover actions are content data only at this stage; Member 1's current Day 2 simulator intentionally does not yet execute rover actions or deduct rover power. The values are ready for that future integration and should be balance-tested once the full sol loop exists.
- Notes for teammates: The NASA provenance and derivation are recorded in the rover `notes` field. Treat `max_distance_per_sol_km` as the total round-trip budget, charge `move_cost_power_per_km` against the actual selected distance, and roll once per previously unexplored kilometre. Do not present the 6 km cap or 7% value as NASA data.

### Day 2 — Sep 27 — NASA-data safety follow-up for content contracts
- Status: ✅ Done
- What was completed: Corrected the content contracts so lunar dust is represented as solar-array dust accumulation rather than an atmospheric dust storm, and rover discoveries produce an unverified volatile prospect instead of immediately adding water. Updated water-extractor wording to require investigated prospects and marked all site readings as placeholders pending reproducible coordinates and LRO/PDS provenance.
- Issues / blockers: The four candidate sites are still fictional labels with no coordinates. Their illumination, terrain, and hydrogen values must remain `verified:false` until Member 1 sources real location-specific data.
- Notes for teammates: New event effects (`volatile_prospect_found`, `requires_follow_up`, and rover task/status values) are data-only hooks for the later event/action integration. They must not be treated as implemented simulation behavior yet.

### Day 3 — Sep 28 — Review + retune `construction.json` structures
- Status: ✅ Done
- What was completed: Retuned all six structure blocks while preserving the locked schema. Defined editable material costs, one-time construction-power costs, build times, and explicit intended gameplay effects: solar generation, prospect-gated water recovery, greenhouse food/power/water trade-off, radiation shielding, habitat resilience, and communications warning. The starting 180 materials now forces an early strategy choice rather than allowing every high-value structure at once.
- Issues / blockers: The current simulator loads construction data but does not yet execute build costs, timers, or effects. Output figures are balance assumptions, not NASA measurements, and require integration and Day 16 playtest tuning.
- Notes for teammates: Treat `build_cost.power` as a one-time construction energy demand. Parse or map the stated effect values only when the build-system action contract is introduced; do not add calculations to the UI. The effects intentionally state their pending interaction rules where simulation ownership is required.

### Day 4 — Sep 29 — Fill crew names/roles and tune stress/productivity modifiers
- Status: ✅ Done
- What was completed: Finalized the four-person fictional crew roster: Leila Navarro (Mission Commander), Devon Okoye (Systems Engineer), Dr. Jia Chen (Life Support Botanist), and Dr. Amara Sethi (Medical Officer). Retuned base stress/productivity values and clarified each specialty as an aggregate modifier hook for later repair, construction, greenhouse, health, and radiation-event integration.
- Issues / blockers: The simulation currently loads the crew contract but does not yet apply these modifiers. Exact modifier strengths require playtesting once event and action systems exist.
- Notes for teammates: Keep one authoritative aggregate crew-health/stress state. `base_stress` and `base_productivity` are editable gameplay values; interpret role notes as contextual modifiers, never as per-person health bars or passive life-support-consumption changes.

### Day 5 — Sep 30 — Expand `events.json` toward 15–20 events (batch 1, completed early Sep 29)
- Status: ✅ Done
- What was completed: Expanded the event table from 8 to 14 events. Batch 1 adds water-recycler maintenance, rover mobility, battery thermal, regolith-shielding, favorable illumination, and crew-process events. Retuned the resupply window to the scoped 7–10-sol mission by removing its unreachable Sol 15 condition.
- Issues / blockers: Effects and trigger strings remain data contracts; the simulator does not yet parse or resolve them. All chances, multipliers, and material rewards are editable gameplay-balance values that need tuning after integration.
- Notes for teammates: Batch 2 on Day 6 should add roughly 2–6 further events to reach the 15–20 target. Member 1 should map the new effect keys to deterministic behavior during the scheduled event-system handoff; no UI should infer an effect from event text.

---

## Member 3 — Presentation & Integration Log

*(entries go here, oldest first)*

### Day 1 — Sep 27, 2026 (scheduled Sep 26) — Kickoff review + first visual direction
- Status: ✅ Done
- What was completed: Reviewed scaffold contracts for all five existing JSON files, the runtime state/simulator and all four existing Markdown documents. Recorded feasibility, interface gaps, provisional palette, typography, mood references and team/title treatment in `docs/UI_UX.md`.
- Issues / blockers: None for Day 1–2 design. Scientific values remain unverified; crew status, action APIs and outcome/report data are later integration dependencies. Day 3 style lock remains pending.
- Notes for teammates: No locked schema, balance value or simulation code changed. This records Member 3's review only; it does not claim teammate sign-off or a joint meeting.

### Day 2 — Sep 27, 2026 — Wireframe the four core screens
- Status: ✅ Done (design deliverables; rendered visual QA pending)
- What was completed: Created `docs/wireframes.html` with site selection, mission dashboard, event modal and mission report layouts. Added screen bindings, navigation, accessibility behavior, empty/error states and future integration requirements to `docs/UI_UX.md`; linked progress from the workflow. Source checks passed for markup nesting, unique IDs, navigation/document links, local-only dependencies, and parsing/counts of all five JSON contracts. `git diff --check` passed.
- Issues / blockers: Browser URL policy blocked the local-file preview, so rendered layout, narrow-screen and keyboard checks remain unverified. This does not block producing the wireframes; perform those checks before Day 3 style lock. No gameplay or Godot shell implementation is claimed.
- Notes for teammates: The board uses scaffold balance examples and schematic terrain; scientific values stay unverified and outcome metrics unavailable. Day 3 styling and Day 4–6 Godot shells remain future tasks. No simulation tests were rerun because runtime code and data were unchanged.

### Day 3 — Sep 28, 2026 — Lock presentation style
- Status: ✅ Done for the Godot visual system; HTML wireframe browser QA remains open
- What was completed: Locked the nine-color mission-control palette, Godot typography scale, panel treatment, spacing, labeled geometric icon approach, and schematic outpost direction in `docs/UI_UX.md`. Implemented these choices in the actual Godot dashboard and inspected rendered screenshots at 1360×820, 720×900, and 520×900. The resource cards and panels reflow at narrow widths without horizontal clipping.
- Issues / blockers: The browser URL policy again refused the local HTML wireframe, so its rendered and keyboard behavior could not be verified. The style decision uses direct review of the Godot implementation; the archived wireframe board's browser check is still pending.
- Notes for teammates: This locks Member 3's first-pass presentation system, not the game title or team-wide branding approval. Continue to label unverified NASA measurements and unavailable gameplay state.

### Day 4 — Sep 28, 2026 (scheduled Sep 29) — Static mission dashboard shell
- Status: ✅ Done ahead of schedule
- What was completed: Added `scenes/mission_dashboard.tscn` as the Godot main scene, `src/ui/mission_dashboard.gd` for the dashboard panels and responsive layout, and `src/ui/outpost_preview.gd` for drawn schematic terrain/habitat/solar/rover art. Six resource cards use the simulator's initial setup values as clearly labeled examples. Crew, mission activity, warning, and science-copy regions are present; build, rover and run controls are disabled. Added `tests/ui/test_mission_dashboard.gd`.
- Issues / blockers: No live simulation binding is included in this scheduled static shell. Godot reported `user://` cache/log and certificate-store warnings in the restricted test environment; the scene still rendered and tests passed.
- Notes for teammates: Godot 4.7.2 loaded the project, the main scene ran for five headless frames, and the UI shell and existing simulator tests passed. Desktop and narrow OpenGL captures were inspected. Day 8 should bind the dashboard to `MissionState` and authoritative action results; do not infer live health, thresholds, or science verification from this example.

### Title decision — Sep 28, 2026 — Peaks of Eternal Light
- Status: ✅ Done
- What was completed: Applied the user-selected game title **Peaks of Eternal Light** to the Godot project/window name, dashboard heading, four wireframe headers, project specification, workflow, and design handoff. Kept **TRIARCHY** as the team credit and updated the dashboard shell test to assert the title.
- Issues / blockers: None for the title change.
- Notes for teammates: Use **Peaks of Eternal Light** in future game and demo materials; use **TRIARCHY** for team attribution. “Lunar outpost” remains a description of the mission setting, not the product name.

---

## Shared Test & Integration Notes

*(one combined entry per 🔗 day — what was tested, what passed, what needs fixing before the next block of days starts)*

### Day 1 — Kickoff contract review (Member 3 contribution, Sep 27, 2026)
- Reviewed all five existing scaffolds against the four planned screens; sufficient for wireframing. Existing runtime fields cover the clock and reserve readouts.
- Later integration needs: live crew health, event resolution, rover/build state, mission outcome and report metrics. Scientific values and coordinates are not ready for a factual site map. See `docs/UI_UX.md` for details and content concerns.
- Member 1's kickoff review is recorded above. Member 2's review and any joint acceptance remain unrecorded; this is not a shared integration-test pass.

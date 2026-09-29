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

### Day 6 — Oct 1 — NASA site data for sites 3 and 4; CRaTER baseline and terrain-shielding derivation
- Status: ✅ Done ahead of schedule on Sep 29
- What was completed: Replaced all remaining site placeholders with reproducible NASA samples. Crater Rim B maps to a Site07 Peak near Shackleton point and Plateau D maps to a Site11 de Gerlache Rim point; both now have coordinates, WAC illumination, LOLA elevation/slope, and the documented LEND regional hydrogen estimate. Replaced the provisional 0.25 mSv/sol radiation calibration with NASA's 0.90 mSv/day unshielded lunar-surface solar-minimum GCR model. Documented the bounded LOLA elevation/slope terrain proxy in `docs/radiation_model.md`.
- Issues / blockers: CRaTER characterizes the lunar radiation environment but does not yield a location-level surface dose for these points. The 0.90 mSv/sol baseline is therefore a NASA lunar-surface model, and terrain shielding remains an explicit gameplay derivation rather than a measured radiation map.
- Notes for teammates: All four site records are now `verified:true` for their locked fields. The three non-Ridge-A sites produce substantially less solar power from their observed illumination; water-resource systems must not treat the shared 140 ppmw regional estimate as a site-specific extraction yield.

### Day 7 — Oct 2 — Test & Integration #1 (Member 1 result)
- Status: ✅ Done ahead of schedule on Sep 29
- What was completed: Extended the headless simulation test into four end-to-end ten-sol runs, one per verified site. Each run confirms the selected-site identity, one-sol clock advance, authoritative returned state, stable `power`/`radiation`/`life_support` tick interface, snapshot history, non-negative reserves, positive radiation accumulation, documented radiation model status, and completion exactly on Sol 10. The test passed in Godot 4.7.2.
- Issues / blockers: Construction, rover, crew-modifier, and event-effect contracts are loaded but not yet executed by the simulation. They cannot be included in this Member 1 runtime result until their scheduled integration work.
- Notes for teammates: The shared Day 7 entry remains pending Member 2 and Member 3 checks. Presentation code can continue to consume the existing tick/state fields; event and action interfaces still need to be defined before live controls are enabled.

### Day 8 — Oct 3 — BVAD life-support data
- Status: ✅ Done ahead of schedule on Sep 29
- What was completed: Replaced provisional O₂, CO₂, potable-water, and dry-food values with documented NASA BVAD values and recorded exact table/page references. Added NASA's ISS ECLSS 90% water-recovery figure as an explicitly labeled whole-loop proxy. Updated life-support tick metadata and expectations in the Godot test.
- Issues / blockers: BVAD states that hygiene loads are mission dependent, so the separate hygiene field remains zero and `verified:false` rather than adding an unsupported draw. The per-person power baseline remains a separate gameplay model choice pending a selected lunar architecture; it is not represented as NASA data.
- Notes for teammates: UI should display the life-support tick model status when explaining values. Do not describe the ISS water-recovery proxy as a prediction for a lunar-outpost system.

### Day 9 — Oct 4 — Win/lose evaluation logic
- Status: ✅ Done ahead of schedule on Sep 29
- What was completed: Added an authoritative `mission_outcome` to `MissionState` and every sol result. The mission succeeds only when it reaches its final sol without a prior failure. Oxygen, water, and food depletion produce named failures immediately; an empty battery becomes a failure only after two consecutive depleted sols, preserving a one-sol recovery window. Tests cover success, depleted water, sustained power depletion, and every verified site's ten-sol baseline.
- Issues / blockers: Current actions cannot build power or change reserves, so three low-illumination sites correctly end in sustained-power failure in the baseline run. That is a useful simulation result, but later construction, rover, and event effects must supply recovery choices before those sites are player-ready.
- Notes for teammates: Consume `tick.outcome` or `state.mission_outcome`, including `status`, `failure_reason`, `failure_sol`, and `primary_objective`. These are the authoritative inputs for Member 2's report branches and Member 3's report screen; do not infer victory from the sol counter alone.

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

### Day 6 — Oct 1 — Continue expanding `events.json` (batch 2, completed early Sep 29)
- Status: ✅ Done
- What was completed: Added five events to complete the table at 19 events: communications blackout, greenhouse nutrient imbalance, radiation-shelter drill, prospect confirmation, and solar-array alignment. These give the comms relay, greenhouse, rover prospecting, radiation response, and solar-array systems authored choices to support later integration.
- Issues / blockers: Event trigger/effect strings are not yet parsed by the simulator. Their values are deliberately editable content balance, not scientific measurements or implemented behavior.
- Notes for teammates: The prospect-confirmation event preserves the NASA-data distinction between a hydrogen signal and a confirmed extraction candidate. Member 1 should determine authoritative state names and effect application when wiring triggers.

### Day 7 — Oct 2 — Test & Integration #1
- Status: ⚠️ Partial
- What was completed: Member 2's event and content contracts are prepared for the shared test: `events.json` contains 19 validated events, while crew and construction content remains in the agreed JSON contracts.
- Issues / blockers: The shared headless multi-sol integration test has not been run or recorded by all members. Construction, rover, crew-modifier, and event-effect behavior is not yet wired into the simulator, so Member 2 cannot independently verify the intended end-to-end content interfaces.
- Notes for teammates: Complete this entry only after Member 1 runs the headless multi-sol test and the team confirms the current runtime state/event interfaces. Do not mark this shared integration day as passed from JSON validation alone.

### Day 8 — Oct 3 — Finish `events.json` expansion (completed early Sep 29)
- Status: ✅ Done
- What was completed: Completed the 15–20-event target at 19 unique events and reviewed timing against the 7–10-sol mission scope. Retuned the equipment-malfunction trigger to structures aged at least three sols and the greenhouse bloom trigger to two sols after construction, so both can occur during a normal mission. Updated the headless simulator contract test to expect 19 events; it passes in Godot 4.7.2.
- Issues / blockers: The event system remains content-complete but not simulator-integrated. Trigger probabilities and reward/penalty values require playtest tuning after deterministic effects exist.
- Notes for teammates: All events retain the locked fields: `event_id`, `category`, `trigger_condition`, `effects`, `text`, and `choices`. Do not parse narrative text for mechanics; consume only the data fields.

### Day 9 — Oct 4 — Write mission briefing and tutorial/onboarding copy (completed early Sep 29)
- Status: ✅ Done
- What was completed: Added `Resources/mission_copy.json` with static mission briefing, NASA-data caveat text, six tutorial steps, and reusable HUD labels. Copy uses presentation-layer tokens such as `[MISSION_LENGTH]` and leaves resource values/outcomes to the authoritative simulation.
- Issues / blockers: Mission report language remains correctly deferred to Day 10, after Member 1 defines win/lose outcomes. UI loading and display of this new content file is also a later integration task.
- Notes for teammates: Keep the briefing's verified-data and resource-potential wording intact when presenting NASA-derived site information. Replace bracketed tokens only with simulation-provided values; do not hard-code mission length or invent outcome data.

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

### Day 5 — Sep 29, 2026 (scheduled Sep 30) — Site-selection UI shell
- Status: ✅ Done ahead of schedule
- What was completed: Added a Godot site-selection screen using the locked visual system, four site cards, selected-state text, measurement details, source disclosure, keyboard focus, and an explicit start action. It is now the first screen in the existing main scene.
- Issues / blockers: No accurate geographic map is claimed; the UI uses a selectable list and coordinates from the data contract.
- Notes for teammates: Final binding was completed with Day 9 below. The HTML wireframe remains a historical design artifact; Godot screens received direct rendered review.

### Day 6 — Sep 29, 2026 (scheduled Oct 1) — Event and report screen shells
- Status: ✅ Done ahead of schedule
- What was completed: Added the reusable event-preview scene with choice/confirmation and acknowledgement variants, independently scrolling body, explicit selection text, modal keyboard focus and restoration. Added report layouts for no attached mission, success and failure; existing authoritative outcomes, reserves and history populate the report when available. Restart requires confirmation.
- Issues / blockers: Event previews never execute effects. Member 1's resolver and Member 2's report guidance are later handoffs; independence, objective and survival percentages remain unavailable.
- Notes for teammates: The preview uses the existing solar-particle and greenhouse-notification content. It does not change event contracts or claim that triggers are implemented.

### Day 7 — Sep 29, 2026 (scheduled Oct 2) — Test & Integration #1 (Member 3 result)
- Status: ✅ Member 3 checks passed; all-member sign-off remains unrecorded
- What was completed: Ran Member 1's existing simulator suite and expanded the UI integration suite. All four site flows matched a separate simulator after every tick, including each displayed reserve, history, successful completion and early failure. Tested invalid IDs, incomplete/unverified fields, missing-data retry, duplicate action guards, new-mission state, event preview isolation, active-event blocking, modal Tab focus and focus restoration. Inspected desktop/narrow Godot renders and long event text.
- Issues / blockers: The environment prints a Windows certificate-store warning, but the offline tests and OpenGL rendering pass. Construction/rover/event-resolution actions remain later runtime work. This entry does not replace Member 2's partial log or claim teammate approval.
- Notes for teammates: See the shared Day 7 note below and the current contract mapping in `docs/UI_UX.md`. No simulator or Resources data file was changed by Member 3.

### Day 8 — Sep 29, 2026 (scheduled Oct 3) — Bind dashboard to authoritative state
- Status: ✅ Done ahead of schedule
- What was completed: Replaced fixed examples with `begin_mission()` and `advance_sol()` results. The UI displays six live reserves, named crew, life-support statuses and last-sol details. Run-the-sol guards prevent duplicate updates, turns after outcomes, and progression during active events or an event preview. The report reads `mission_outcome` rather than inferring success from the sol counter.
- Issues / blockers: Live crew health, build/rover actions, and event resolution remain unavailable. Low-illumination sites have no recovery actions in the current baseline and correctly fail before Sol 10.
- Notes for teammates: All formulas, thresholds and outcome decisions remain in Member 1's simulation. Member 2's authored briefing and science notice are read from `mission_copy.json`; optional copy failures use fallback text.

### Day 9 — Sep 29, 2026 (scheduled Oct 4) — Bind site selection to current site data
- Status: ✅ Done ahead of schedule
- What was completed: Bound the four site cards and details to `sites.json`, including names, coordinates, measurements, individual verification flags, source strings and reading dates. Selected IDs are passed to mission initialization. Removed the blanket unverified-site and unnamed-crew assumptions from live presentation, and documented the regional hydrogen estimate and modeled radiation distinction.
- Issues / blockers: Source verification is not a claim of mission safety or balanced gameplay. Unverified model choices remain labeled separately.
- Notes for teammates: The JSON schemas, verified values, crew roster and event table are consumed unchanged. Workflow progress and the UI handoff now reflect the current implementation; earlier dated log entries remain historical.

---

## Shared Test & Integration Notes

*(one combined entry per 🔗 day — what was tested, what passed, what needs fixing before the next block of days starts)*

### Day 1 — Kickoff contract review (Member 3 contribution, Sep 27, 2026)
- Reviewed all five existing scaffolds against the four planned screens; sufficient for wireframing. Existing runtime fields cover the clock and reserve readouts.
- Later integration needs: live crew health, event resolution, rover/build state, mission outcome and report metrics. Scientific values and coordinates are not ready for a factual site map. See `docs/UI_UX.md` for details and content concerns.
- Member 1's kickoff review is recorded above. Member 2's review and any joint acceptance remain unrecorded; this is not a shared integration-test pass.

### Day 7 — Test & Integration #1 (Member 3 contribution, Sep 29, 2026)
- Member 1's existing regression test passed again. Member 3's UI integration test passed with zero failures across all four sites and the current 19-event/named-crew contracts.
- The UI stops on `mission_outcome.status == failure` even if the tick's `completed` flag is false. Ridge A reaches success on Sol 10; the other baseline sites fail on sustained power depletion. No UI balance adjustment was made to conceal that result.
- Site selection → mission initialization → live reserves → terminal report → confirmed restart works. Event previews apply no effects and leave state unchanged; any future active event blocks turns until a resolver exists.
- Member 2's partial Day 7 entry predates this presentation check. It remains their entry to confirm; no all-member meeting or sign-off is claimed. Outstanding later interfaces are deterministic event resolution, build/rover actions and runtime state, live crew status, and advanced report metrics/authored guidance.

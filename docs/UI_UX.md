# Member 3 — Presentation design handoff

**Update — Oct 5, 2026:** Days 14–20 presentation work and nine-suite validation are recorded in [member3_days14_20.md](member3_days14_20.md). Added shared operations panels, non-mutating placement previews, completed-state visuals, a fixture-tested rover animation adapter, activity history and responsive report charts. Live rover/construction actions remain Member 1/2 dependencies; Days 16/17/20 are not certified end to end. The user reconfirmed Member 3-only scope.

**Current status — Oct 4, 2026:** Member 3 Days 10–13 and Day 14 presentation checks are complete. Live world HUD, event decisions, state feedback, illustrative terrain, animation, and report navigation are integrated. Earlier sections are historical snapshots. See `docs/day14_integration.md` for verification and remaining team dependencies.

## Current working scope and outpost controls — 2026-10-04

Per the user's instruction, follow only Member 3's presentation, UI and integration work. Member 1/2 systems remain dependencies.

The bottom mission/detail bar starts hidden on every outpost visit. Press Alt to show it and release the cursor; press Alt again to hide it and resume exploration. Holding Alt does not repeatedly toggle it. A visible event dialog retains input until dismissed. Station inspections update details without automatically opening the bar; use Alt to read them.

The outpost perimeter uses invisible collision walls aligned to the rendered terrain bounds. They keep the astronaut's full collision capsule inside the surface, including at corners and during jumps.

The visible landscape extends to 2.5 km from the outpost along each axis, using progressively coarser terrain rings with gently rolling plains, shallow crater bowls and low worn rims. Five isolated low ridges and 24 clusters of irregular dark stone outcrops add variety to the expanded area while leaving broad open plains. The expanded area has no large mountain backdrop; its fine relief fades smoothly from the original surface into the distant plain. The original 120 m square playable surface and its collision boundary remain unchanged. The extension has no gameplay collision. A fixed procedural starfield provides subtle brightness and color variation against black space; it is artistic presentation, not a measured star chart or exposure simulation.

## Days 10–14 world integration — 2026-10-04

- The responsive outpost HUD starts and advances the shared mission, shows exact reserves/statuses and opens the event modal in live mode. Preview mode remains isolated. Canceling leaves decisions pending; only the simulator applies choices.
- MissionSession bridges world actions and guards duplicate turns. Station inspection, solar output, life-support warning labels and the decision beacon consume authoritative state. Dashboard returns restore player location/camera heading; dashboard-originated missions update the selected world site.
- Terrain is deterministic site-seeded artwork with a flat pad, collidable surrounding relief and regolith texture. Habitat/solar details, labeled stations and prop collision hulls complete the pass. Terrain and lighting are illustrative, not local surveys or forecasts.
- Solar-light transitions, a decision cue, updated-reading tint and overview camera animate presentation only. Reduce motion disables these and landing animations. Esc releases the pointer and pauses walking; clicking terrain resumes. Live modals block astronaut input and restore focus.
- The report exposes decision history and labels the backend survival_pct as mission-duration completion, not crew survival. Simulator choice resolution refreshes statuses, outcome, report and the current-sol history snapshot.
- Desktop (1360×820), narrow (520×900), live modal and overview OpenGL renders were inspected. Tests cover four missions, ten authored choices, cancel/confirm, duplicate guards, exact feedback, failure/success reports, restart and real scene switching. Construction/rover actions, unsupported effect keys and standard-mission balance remain dependencies.

## Day 9 3D handoff — 2026-10-04

The walkable outpost now uses the supplied animated astronaut and imported rover, plus reusable locally authored habitat and solar-array scenes in `Assets/outpost/`. Rover mesh bounds set its scale and ground alignment. Habitat and array supports are included; later terrain/material polish remains Day 11 work. Layout and vehicle representation are illustrative.

The existing selector zoom and arrival animation are preserved. The outpost displays the selected site's authored name. `MissionSession.select_landing_site()` preserves a same-site mission and clears stale mission/tick state when the destination changes, so the dashboard cannot resume the previous site's mission after a new landing. Outpost, selector, transition, four-site session, and dashboard tests passed; an OpenGL capture was inspected. Day 10 still owns authoritative state/event feedback in the world.

## Feasibility review — 2026-09-27

Day 1 and Day 2 are feasible now. Their deliverables are a review of the existing contracts, provisional art direction, and four core-screen wireframes. They do not require finished simulation formulas, verified NASA measurements, or a playable UI. All four existing Markdown files were reviewed: the project specification, workflow split, daily logs, and resource README. The workflow's daily schedule governs this work.

At the time of this Day 1–2 review, the repository already had a Godot 4.7 project, `MissionSimulator`, `MissionState`, five JSON scaffolds under `Resources/` (the workflow's reference to the repo root is stale), and a supplied astronaut GLB. No main scene or presentation layer existed then. The GLB was not needed for these design tasks; its suitability and provenance were not established by this review.

### Day 1 — Reviewed scaffold contracts

| Existing contract | Presentation use | Finding / later dependency |
|---|---|---|
| `Resources/sites.json` | Four selectable sites, names, illumination, elevation, slope, hydrogen and field provenance | All scientific fields are unverified; no coordinates, radiation score, or construction difficulty score exists. Use schematic markers and unavailable labels, not a geographic map or invented scores. Site descriptions are draft content, not verified observations. |
| `Resources/bvad_constants.json` | Crew count; contextual life-support explanations | O₂, CO₂, potable water, dry food, and the ISS water-recovery proxy are NASA sourced. Hygiene water and baseline power remain explicitly unverified model choices. UI must not calculate consumption or turn reserves into “days remaining.” |
| `Resources/crew.json` | Roles and eventual names | Four roles; names are `TBD`. Display roles as fallback. Base stress/productivity are balance inputs, not live health. |
| `Resources/construction.json` | Future structure cards and rover information | Six structures with costs, effect text and build times; rover parameters exist. No runtime queue, placement, rover position or action API yet. |
| `Resources/events.json` | Event body, category, choices, no-choice notification | Eight events; `choices` can be null. Effects are mixed types and trigger conditions are strings. Presentation must never execute or parse them into simulation rules. |
| Runtime `MissionState` | Mission clock, reserves, dose, materials, crew count, active events and history | Available fields are listed below. Live crew health, event resolution, outcomes and report metrics still need Member 1/2 integration. |

Reviewed existing scaffolds; no schema or balance changes were made. This is Member 3's independent review, not a claim that a joint kickoff meeting or teammate sign-off occurred.

### Provisional visual direction (Day 1)

Mood references are design cues from the specification, not copied external imagery: mission-control instrument panels for information hierarchy; lunar contour lines and hard shadows for spatial context; a three-part mission crest for team identity; restrained metallic edges for equipment framing. No remote assets, AI-generated imagery, NASA seals or final logo are needed for wireframes.

| Role | Candidate color | Use |
|---|---|---|
| Space | `#0B0D16` | Canvas |
| Instrument panel | `#171C2B` | Grouped controls |
| Titanium edge | `#66738F` | Separators and boundaries |
| Primary text | `#F1F3FA` | Readings and body copy |
| Secondary text | `#B6C1D8` | Labels, units and help |
| Purple | `#B7A2FF` | Selection and primary actions |
| Blue | `#91CFFF` | Spatial markers and informational cues |
| Amber | `#FFD18A` | Caution, paired with words and symbols |

Use a readable system sans-serif for body copy and monospace for telemetry. Candidate scale: 16px body, 14px secondary labels, 24–32px readings and headings; 8px spacing rhythm; controls at least 44px tall. These are exploration choices; Day 3 locks colors, typography and icons after review. No font download dependency.

The team credit is **“by TRIARCHY.”** At the time of this Day 1 review, **“Lunar Outpost”** was a working title. The player later selected **“Peaks of Eternal Light”** as the game title; the directory name did not decide it. Prefer a terrain/outpost focal area with supporting instruments over an all-chart dashboard. Avoid neon glow, decorative data, unlabeled icons and fabricated percentages.

### Known discrepancies and future handoff

- The specification's explicit hackathon scope and workflow take precedence over older 30-sol examples. Wireframes use a 10-sol mission and a sol-zero setup state; “sol” is the game's turn label, with physical time conversion left to Member 1.
- The current skeleton increments time without resource formulas or outcome evaluation. Its `completed` result means the time limit was reached, not that the crew survived or won.
- Member 1: expose authoritative crew status, warning thresholds, event instance/resolution semantics, construction/rover runtime state, outcome/reason and report metrics at their scheduled integration points. UI must not invent these fields or outcomes.
- Member 2: review lunar plausibility of `dust_storm`, unqualified water-discovery/site copy, and the sol-15 / structure-age-over-10 triggers against the 7–10-sol scope. Keep the existing contracts intact during this presentation task.
- The specification's explicit no-AI-runtime rule governs this design. Its contradictory optional-AI checklist item was removed during the Day 3–4 documentation update.

No issue blocks Day 1–2 design work. These items remain dependencies for later gameplay integration, not completed features.

## Day 2 — Four core wireframes

Open [the local wireframe board](wireframes.html) in a browser. It is a self-contained HTML/CSS design artifact with inline schematic SVGs, no scripts, downloads, external fonts or runtime dependencies. Navigation links move between four layouts; gameplay controls are explicitly static placeholders. It does not replace the Godot project or implement the Day 4–6 UI shells.

### Screen bindings and behavior

| Screen region | Existing source | Presentation behavior |
|---|---|---|
| Dashboard clock / selected site | `MissionState.sol`, `mission_length_sols`, `site_id`; join `sites[].site_id` | Display setup at sol 0; show the configured mission length, not a hardcoded 30. |
| Dashboard readings | `power_kwh`, `water_l`, `oxygen_kg`, `food_kg`, `radiation_msv`, `materials` | Show units and absolute values. `power_kwh` is energy reserve, not instantaneous kW. Oxygen threshold status is unavailable until provided by the sim. |
| Crew panel | `crew_size`; `crew[].role`, `name` | Role fallback for `TBD` names. No live health, stress or productivity inferred from base modifiers. |
| Outpost and activity | `active_events`; future infrastructure/rover state | Diagram is a composition study, not proof of built structures. Empty activity state when there are no events. |
| Site selection | `sites[].name`, `site_id`, `illumination_pct`, `elevation_m`, `slope_deg`, `hydrogen_ppm` | Selectable list equivalent to schematic markers. Inspect `verified` per field; unverified or missing values receive explicit labels. Source details use `source` and `date_read`. |
| Event modal | `events[].event_id`, `category`, `text`, `choices[].choice_id`, `text`, `effects` | Sample uses `solar_particle_event`. Qualitative low/high dose labels mirror authored effects; they are not computed radiation readings. Mixed effect keys need an agreed display mapping; unknown effects must not become invented forecasts. |
| Report | `history` snapshots and final state; future outcome/report contract | Resource history can use existing snapshots. Survival, independence, objectives, decisions and failure cause remain unavailable. No “NASA data used” checkmarks without actual verified input use. |

The intended gameplay path is site selection → dashboard → event decision → dashboard → report → new mission. The wireframe board links demonstrate navigation only. Later integration calls `load_contracts()` and checks its error before `begin_mission(site_id, mission_length)`. `advance_sol(state)` returns a dictionary containing `state`, `completed` and `active_events`; render its state rather than treating that dictionary as `MissionState`. Reading `history` requires the state object; `snapshot()` does not include history. Resource formulas and event effects stay in the simulation.

### Required 3D world handoff

The dashboard is a `CanvasLayer` HUD over a Godot 3D lunar-outpost scene, not the entire game world. Member 3 owns a `Node3D` scene with lunar terrain, directional lighting, an inspectable camera, and placed astronaut, rover, habitat, and solar-array models.

| World element | Authoritative input | 3D behavior |
|---|---|---|
| Terrain and site marker | Selected `site_id` and `sites.json` coordinates/terrain fields | Load the matching site composition and label it with verified-data status; terrain remains a visual interpretation of the sourced data. |
| Solar array | `power_generated_kwh`, `power_balance_kwh`, active event effects | Change panel orientation, emissive/readout state, or alert treatment only after a simulation tick reports the value. |
| Rover | Future authoritative rover action/state contract | Keep the rover visibly parked until the simulation exposes a route/action result; do not animate progress from UI input alone. |
| Habitat, shielding, and construction | Future authoritative construction state contract | Show construction or shielding only after the simulation exposes its completed state. Use clear placeholders before then. |
| Astronaut | NASA lunar gravity plus future crew/event state supplied by the simulation and content contracts | The `CharacterBody3D` controller walks and jumps using 1.62 m/s² lunar gravity. The Golden Visor model remains static until an animated character asset is selected; do not imply health or an EVA outcome without authoritative runtime state. |
| Hazards and opportunities | `active_events` and resolved event outcome | Use environmental cues and markers after the event is active; choices and effects remain simulation-owned. |

The HUD reads the same authoritative values and never performs world or resource calculations. The minimum visual loop is select site → inspect 3D outpost → run a sol → see the HUD and world update from the returned tick.

The first player loop is GTA-style third-person exploration: move with `W`/`A`/`S`/`D` relative to the orbit camera, rotate the camera freely with the mouse, and let the astronaut turn toward travel. Press `C` to swing the camera to a front view and see the astronaut's face. Space jumps, `E` interacts at labeled energy, water, food, and crew stations, and Esc releases the mouse. An interaction currently records only its stable identifier; Member 1 connects that identifier to an authoritative simulation action before it can alter any reserve.

`lunar_landing_selector.tscn` projects the four geographically separated, NASA-referenced latitude/longitude records into a local selection map and lets the player click a marker. It represents the selected locations, while the terrain mesh remains a visual placeholder until a LOLA elevation tile is prepared for runtime use.

### Interaction and fallback specifications

- Site selection: one selected item at a time, detail panel updates before explicit confirmation. A load failure offers retry and blocks start; a missing source field shows “Unavailable.” A clearly labeled dummy-data development flow is separate from a validated release mission.
- Dashboard: keep all six readings visible; one “Run the sol” action. Disable it during transitions and unresolved required events; warnings include text/symbols and come from sim thresholds. Build and rover controls remain unavailable until their scheduled systems arrive.
- Event: explicitly select then confirm once; prevent duplicate submission. `choices: null` or an empty choice list uses an acknowledgement action. Multiple events queue in order supplied by the sim. A modal takes keyboard focus, keeps focus inside while open and restores it to its invoking control after resolution. Escape must not silently choose or discard a required decision. On resolution failure retain the selection and allow retry. Focus trapping and confirmation are future Godot behaviors, not implemented in the static board.
- Report: success and failure variants require an authoritative outcome; failure includes cause and sol, then authored guidance. An absent outcome shows a neutral pending state. Empty history shows no chart; future charts need a table equivalent. Retry starts a fresh mission after confirmation rather than mutating the completed state.
- Accessibility: readable text, labeled units, visible keyboard focus and selected-state text as well as color. No motion in these wireframes; later transitions respect reduced motion. Long event copy can scroll without hiding the confirmation row in the final UI.
- Layout: two-column landscape composition with a terrain focal area. The board stacks columns below 900px and reduces the six-reading row to three, then two columns below 520px. These are design review fallbacks, not a promise of mobile game support.

### Day 2 acceptance and handoff

- All four core screen layouts are present, with hierarchy, primary actions, navigation and missing-data states.
- Current reserve examples match `MissionSimulator.INITIAL_*` constants; site science is shown as unverified and report metrics as unavailable. Schematic markers have no geographic claim.
- Reviewed bindings against the five JSON files and runtime source; no shared schemas or sim logic changed.
- Automated source checks cover unique IDs, internal navigation targets, balanced markup, local-only dependencies and contract counts. Browser rendering was attempted but the browser URL policy blocked the local file; visual rendering, narrow-layout and keyboard QA remain unverified. Source checks do not substitute for those checks.
- Day 3: review the board and lock the visual system after rendered review. Day 4–6: implement Godot screen shells. Day 8–10 and later integration work: connect the agreed state/action boundaries; do not invent missing sim behavior.

## Day 3 — Visual system decision (Sep 28, 2026)

The dashboard's visual system is locked for the first playable UI pass. It preserves the Day 1 palette, uses a dark mission-control canvas, quiet instrument borders, and a schematic lunar outpost as the focal area. The finalized game title is **Peaks of Eternal Light**, with **by TRIARCHY** as the team credit.

| Token | Hex | Use |
|---|---|---|
| Space | `#0B0D16` | Main canvas |
| Panel | `#171C2B` | Grouped instruments |
| Terrain | `#101521` | Outpost schematic field and disabled controls |
| Titanium edge | `#66738F` | Panel borders, rules, contour lines |
| Primary text | `#F1F3FA` | Titles and current readings |
| Secondary text | `#B6C1D8` | Labels, units, explanations |
| Purple | `#B7A2FF` | Identity and selection |
| Blue | `#91CFFF` | Spatial diagrams and informational readings |
| Amber | `#FFD18A` | Cautions, always with explanatory text |

Typography uses Godot's built-in sans-serif for this shell, with 34 px page title, 25–28 px clock/readings, 14–16 px body/section text, and 12–13 px telemetry labels and units. Readings always include units; `power_kwh` is labeled **energy reserve**, not instantaneous power. Spacing follows an 8 px rhythm with 10–20 px local gaps and 28 px page margins. Planned action controls are at least 44 px high. Iconography is simple outlined geometry: a provisional three-triangle crest, contour lines, and diagrammatic habitat/solar/rover shapes. Text labels carry meaning independently of color or symbols. No external font, remote art, NASA seal, or fabricated measurement is used.

The HTML wireframe board remains the Day 2 design artifact. Its local-file URL was blocked again by browser security policy, so its rendered desktop, narrow, and keyboard behavior is still **unverified**. The style decision was reviewed against screenshots of the actual Godot shell at 1360×820, 720×900, and 520×900 instead. The Godot screenshots show a six-card desktop row, three-card intermediate rows, two-card narrow rows, and vertically stacked content without horizontal clipping. HTML wireframe browser QA remains an open design-artifact check; it does not imply the Godot layout is untested.

## Day 4 — Static Godot mission dashboard (completed Sep 28, ahead of Sep 29 schedule)

`scenes/mission_dashboard.tscn` is the project's main scene. `src/ui/mission_dashboard.gd` builds the presentation hierarchy: mission header and clock, six resource cards, outpost composition panel, crew roles, mission activity, model warning, science-copy placeholder, and planned build/rover/run controls. `src/ui/outpost_preview.gd` draws a schematic habitat, solar array, rover, and contour field in Godot without loading external imagery. The scene scrolls vertically and rearranges resource cards at 1220 px and 700 px viewport widths.

At the original Day 4 shell, the static setup examples matched `MissionSimulator.INITIAL_*`: 120 kWh energy, 400 L water, 45 kg oxygen, 30 kg food, 0 mSv accumulated dose, and 180 game units of materials. Member 1's Oct 8 balance pass later raised the runtime starting energy to 170 kWh. This dated section is a historical shell snapshot, not a live `MissionState`; the current UI uses simulator state. Construction/rover actions and live per-crew health remain unavailable, and site science preserves its sourced/modelled/unavailable labels.

Validation: Godot 4.7.2 loaded the project and main scene; a five-frame headless run reported no scene/script failures. `tests/ui/test_mission_dashboard.gd` passed its shell assertions (six readings, labels, and disabled controls), and the existing `tests/simulation/test_mission_simulator.gd` passed. OpenGL screenshots of the scene were inspected at the three viewport sizes above. Godot printed local `user://` log/cache and certificate-store warnings in the restricted test environment; they did not prevent the project from rendering or tests from passing.

Run locally with Godot 4.7 by opening `project.godot` and pressing **F6** on the scene or **F5** for the project. The launch scene is `scenes/mission_dashboard.tscn`. Day 8 dashboard integration should replace static examples with fields from `MissionState` after `load_contracts()` and `begin_mission()` succeed, then enable the turn action only when Member 1's rules provide an authoritative result. Keep reserve calculations, warning thresholds, event effects, and outcomes in the simulation layer.

## Title update — Sep 28, 2026

The player selected **Peaks of Eternal Light** as the game title. Godot's project/window name, dashboard heading, and all four wireframe headers use that title. **TRIARCHY** remains the team name and credit. The previous “Lunar Outpost” heading was a working title only; ordinary references to a lunar outpost as the mission setting remain descriptive.

## Days 5–9 — Integrated presentation (Sep 29, 2026)

### What now runs

The existing `scenes/mission_dashboard.tscn` entry scene now hosts site selection → live dashboard → report. `src/ui/mission_dashboard.gd` owns navigation and rendering; shared labels, focus outlines, buttons and panels are in `src/ui/ui_style.gd`. `scenes/event_preview.tscn` and `src/ui/event_preview.gd` provide a separate modal shell. All screens use the approved **Peaks of Eternal Light / by TRIARCHY** identity. The original HTML board remains historical and has not been browser-verified.

- **Day 5:** Four selectable site cards, explicit selected text, site detail panel, source disclosures, missing/unverified field labels, and confirmation through “Establish outpost.” A list of sites is used instead of an unsupported geographic map.
- **Day 6:** Choice-event and no-choice notification previews, scrollable text, a fixed confirmation row, an explicit selected-choice label, exclusive modal focus and focus restoration. Previews never change mission state. The report supports no attached mission, success, and early failure; actual outcomes and history are shown when available. Advanced report metrics and authored outcome guidance remain pending their later handoffs.
- **Day 7:** Presentation-side integration tests and Member 1's existing headless regression suite passed. Shared sign-off is not inferred from this result; Member 2's recorded partial entry is preserved.
- **Day 8:** Six live reserve readings, crew roster, authoritative life-support statuses, last-sol energy/water/radiation details, and a working “Run the sol” action. Duplicate callbacks during a turn are blocked. Active events pause turns pending a resolver. Failure or success opens the report and further turns are refused.
- **Day 9:** Site cards/details read the current four `sites.json` records. Confirming a site passes its `site_id` into `begin_mission()`. The UI displays each field's verification, source and reading date, plus coordinates where present. Invalid IDs and missing/non-numeric required values cannot start a mission.

### Synchronization with the other members

| Owner/source | Current presentation use | Boundary |
|---|---|---|
| Member 1: `load_contracts()` | Checked before offering mission start; load errors show a retry screen | No simulator method runs on an invalid selection |
| Member 1: `begin_mission(site_id, 10)` | Initial state, selected site, clock and crew count | The ten-sol configuration is passed once; subsequent displays use state fields |
| Member 1: `advance_sol(state)` | Render `tick.state`; retain `tick.life_support.model_status` for explanations | No resource calculations in UI |
| Member 1: `life_support_status` | Nominal/warning/critical/depleted labels | No presentation-owned thresholds |
| Member 1: `mission_outcome` | Status, reason and failure sol; stop immediately on failure even when `completed` is false | `completed` alone is never treated as success |
| Member 1: `history` | Labeled textual resource-history table | No invented percentages, independence, objectives or survival metrics |
| Member 1: site provenance and radiation model | Per-field source disclosures and model notes | Elevation/slope are global LOLA source pixels; illumination is modeled; polar LEND hydrogen is unavailable at these sites. Terrain shielding is a gameplay proxy, not a local CRaTER measurement |
| Member 2: `crew.json` | Names and roles, with role fallback | Stress/productivity inputs are not live health |
| Member 2: `mission_copy.json` | Opening, objective token substitution, science notice | The six-step tutorial flow remains later work; absent/malformed optional copy uses fallback text |
| Member 2: `events.json` | Two representative modal previews, one choice event and one notification | No trigger parsing, effect execution, or claim that a live event resolved |
| Member 2: construction/rover content | Controls remain visibly unavailable | Await authoritative action and runtime-state contracts |

The current four sites share a disclosed 50% ideal-horizon illumination model, so baseline solar generation is the same at each site; the screen explains this model and its lack of local horizon sampling. Sourced fields retain their source labels, while unverified power/hygiene choices and the ISS water-recovery proxy are explained separately. Do not describe source verification as proof of a safe or balanced mission.

### Interaction and test results

At 1360×900 the site cards and dashboard body use two columns, with six resource cards in one row. At 520×900 the content stacks and resources use two columns. The intermediate resource layout uses three columns below 1220 px. Screens scroll vertically; event text scrolls independently of the confirmation controls. Buttons have visible amber keyboard-focus borders. Restart from a completed report requires confirmation and clears the previous state/history before a new selection.

Verified in Godot 4.7.2:

- Existing simulation regression suite passed.
- UI integration suite passed with zero failures: all four selection-to-outcome flows; every displayed reserve matched a separate reference simulator after every tick; duplicate start/turn guards; stopping at early failure/final success; missing/unverified data; disabled start for incomplete records; load-error recovery; restart confirmation; no-mission report; event preview isolation and acknowledgement; active-event blocking; keyboard Tab staying in the modal and return focus.
- OpenGL screenshots inspected for site selection, dashboard, event modal, success report and early-failure report at desktop and narrow widths. Long event text scrolls while confirmation stays visible. No horizontal clipping was seen in the inspected layouts.
- The sandbox emitted a Windows certificate-store warning. It did not prevent the offline tests or rendering; no network is required by these screens.

Repeat the automated checks from the repository root with Godot 4.7:

```powershell
godot --headless --path . --script res://tests/simulation/test_mission_simulator.gd
godot --headless --path . --script res://tests/ui/test_mission_dashboard.gd
```

Open `project.godot` and press F5 to review the flow. Choose a site, scroll to its detail panel, select **Establish outpost**, then use **Run the sol**. **Interface previews** at the bottom open event shells and an empty report without simulating event effects. Live event decisions, construction/rover actions, report narrative/advanced metrics, final art and animation remain later scheduled work.

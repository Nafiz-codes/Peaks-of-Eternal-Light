# Triarchy — Workflow Split (3 Teammates)

**Game title:** Peaks of Eternal Light · **Team:** TRIARCHY

**Timeline:** Sept 26 – Oct 31 (~5 weeks) · Local qualifier the day before the main Nov 14–15 event

Each teammate owns a **distinct domain end-to-end**, not a slice of the same task. Work meets at defined interfaces (below), so nobody is blocked waiting on someone else's half of the same feature.

---

## Member 1 — Simulation & Data (the engine room)

Owns everything that decides *what happens*, with no UI attached.

- Build the core sim loop: sol-by-sol resource tick (power generation/consumption, water, food, radiation dose accumulation, O2 as a derived/threshold resource per the scope-cut discussion)
- Source and hard-code the site dataset (`sites.json`): pull real values from LRO QuickMap (illumination %, elevation/slope, LEND hydrogen) for the 4 candidate sites, document the layer + date read for each value
- Derive the radiation model: baseline dose rate from CRaTER data, modulated by a terrain-shielding factor computed from LOLA slope/elevation — not a raw geographic CRaTER reading
- Pull BVAD life-support constants (O2/water/food per crew member per sol) and wire them into the resource math
- Define and own the **win/lose evaluation logic** and the end-of-mission report's underlying numbers (what failed, when, why)
- Write the event system's *trigger conditions and resource effects* (not the narrative text — that's Member 2)
- Deliverable: a headless, testable simulation module with a clear input/output contract (see Interfaces)

## Member 2 — Systems & Content (the game design layer)

Owns everything that gives the sim texture, meaning, and stakes.

- Rover mechanics: movement, distance/time cost, what it can discover or unlock (e.g. water deposits)
- Construction/build system: what structures exist, their cost, what they unlock or improve
- Crew: names, roles, and how individual stress/productivity modifiers feed into (not duplicate) Member 1's aggregate crew health number
- Author the full event table: text, flavor, choices, and which trigger conditions/effects from Member 1's system each event hooks into
- Write all narrative copy: mission briefing, event text, end-of-mission report language, tutorial/onboarding copy
- Own the difficulty curve: which events fire when, tuned against Member 1's sim once it's testable
- Deliverable: an event/content data file (JSON or similar) that plugs into Member 1's trigger system, plus all in-game text

## Member 3 — Presentation, UI & Integration (the face of the build)

Owns everything the player sees and the final assembled product.

- Visual direction and asset production: mission control dashboard, site selection screen, event modals, report screen — per the crest/no-generic-AI-look direction already set for branding
- Build and maintain the Godot 3D lunar-outpost world: terrain, lighting, camera, imported models, and simulation-driven visual feedback
- Implement the UI layer consuming Member 1's sim state and Member 2's content, via the shared data contract
- Animation/juice: resource meters, rover movement, transitions — polish pass once core screens work
- Own final integration: wiring sim + content + UI into one running build, catching interface mismatches early rather than at the end
- Own the demo: the 2–3 minute pitch video/live-demo script, screenshots, and slide deck for judging
- Deliverable: the playable build itself, plus all pitch/demo materials

---

## Interfaces (what connects the three tracks)

The five shared contracts live under `Resources/`. Their fields are established; current content and runtime additions are recorded in `logs.md` and `docs/UI_UX.md`:

1. **Sim state contract** (Member 1 → Member 3): a single object/struct representing "current mission state" (resources, sol number, crew status, active events) that the UI reads every tick — this is generated at runtime by Member 1's code, not a file anyone hand-authors
2. **Event/content contract** (Member 2 → Member 1 & 3): `events.json` — now 19 events using the agreed fields; runtime trigger/effect resolution remains pending
3. **Site data contract** (Member 1 → Member 2 & 3): `sites.json` — four sourced sites with coordinates and per-field verification/provenance; hydrogen is a regional estimate, not extraction yield
4. **Life-support constants** (Member 1 internal): `bvad_constants.json` — sourced consumption values and an ISS recovery proxy, with remaining unverified model choices labeled individually
5. **Crew & construction contracts** (Member 2 → Member 1 & 3): `crew.json` and `construction.json` — named crew and retuned balance data; runtime modifiers/actions remain pending

Member 2 also supplies `Resources/mission_copy.json`. Member 3 reads its briefing and science notice; it does not change simulation rules. The live dashboard reads Member 1's `life_support_status` and `mission_outcome` rather than deriving warnings or success.

6. **3D presentation contract** (Member 1 & 2 → Member 3): Member 3 owns the 3D world and imported assets. Member 1 remains authoritative for mission state and action outcomes; Member 2 supplies authored event/content identifiers. The world may visually represent only state and actions that these contracts expose. It must not calculate resources, invent construction completion, or imply an event outcome before the simulation returns one.

## Daily Logging

### Member 3 progress — Sep 29, 2026

- Day 1 complete: reviewed the five existing scaffolds and recorded provisional visual direction, feasibility and integration gaps in [docs/UI_UX.md](docs/UI_UX.md).
- Day 2 complete: [four core-screen wireframes](docs/wireframes.html), with bindings and interaction notes in the design handoff. These are design artifacts, not playable Godot UI. Browser visual QA remains pending because the local-file preview was blocked by browser URL policy.
- Day 3 visual system is implemented and documented in [docs/UI_UX.md](docs/UI_UX.md). The actual Godot dashboard was rendered at desktop and narrow widths; the older HTML wireframe still could not be opened in the browser because of URL policy.
- Day 4 delivered the static dashboard shell at `scenes/mission_dashboard.tscn`; Days 8–9 have since extended that entry scene into the live site-selection/dashboard/report flow. Test results and actual completion dates are in [logs.md](logs.md).
- Title decision: the game is **Peaks of Eternal Light**, with **TRIARCHY** retained as the team credit. The Godot window, dashboard, wireframes, and project specification use this title.
- Days 5–6 complete: site-selection, event-preview and report interfaces now run in Godot with shared styling, keyboard focus and scrolling. The original HTML board remains a historical design artifact with its browser QA still open.
- Day 7 Member 3 checks passed: UI and headless simulator tests verify all four site flows, authoritative values, early failure/final success, restart, modal focus, and load recovery. This is Member 3's recorded result, not a claim of all-member sign-off.
- Days 8–9 complete: the dashboard advances the real simulator; site selection loads current data, verification and provenance. The main scene now opens on site selection. Outcomes open a report with actual reserves/history; advanced report metrics and event effects remain later work.

After finishing each day's task below, log it in **`logs.md`** under your own section before moving to the next day. This is what lets the team (and each person's own AI assistant) see progress at a glance without a meeting. See `logs.md` for the exact format.

## Day-by-Day Schedule (Sept 26 – Oct 31)

Legend: 🎨 = design work happens this day · 🔗 = shared Test & Integration day (all three, logged by all three)

| Day | Date | Member 1 — Simulation & Data | Member 2 — Systems & Content | Member 3 — Presentation & Integration |
|---|---|---|---|---|
| 1 | Sep 26 (Sat) | 🔗 Kickoff: review the 5 existing data-file scaffolds (sites/bvad/crew/construction/events) as the locked contracts | 🔗 Kickoff: same session — confirm the scaffolded schemas cover what content needs | 🔗🎨 Kickoff: same session + first pass on visual direction (palette, mood refs) |
| 2 | Sep 27 | Project/sim skeleton reading from the scaffold files (still placeholder values) | Review + retune `construction.json`'s `vehicles.rover` block (movement cost, distance, discovery chance) | 🎨 Wireframe the 4 core screens (dashboard, site select, event modal, report) |
| 3 | Sep 28 | Core tick loop: power + radiation formulas | Review + retune `construction.json`'s structures (costs, effects, build times) | 🎨 Finalize visual direction from kickoff refs; lock UI style (colors, type, iconography) |
| 4 | Sep 29 | Core tick loop: water + food + O2 threshold logic | Fill in real names/roles in `crew.json`; tune stress/productivity modifiers | Build static UI shell for the mission dashboard (no live data yet) |
| 5 | Sep 30 | Fill in real values for sites 1 & 2 in `sites.json` (replace `verified:false` placeholders) | 🎨 Expand `events.json` from 8 starter events toward ~15–20 (batch 1) | Build static UI shell for site-selection screen |
| 6 | Oct 1 | Fill in sites 3 & 4 in `sites.json` + CRaTER baseline + terrain-shielding derivation | 🎨 Continue expanding `events.json` (batch 2) | Build static UI shell for event modal + report screen |
| **7** | **Oct 2** | 🔗 **Test & Integration #1** — headless sim runs multiple sols on dummy data without crashing; confirm interfaces still match what was agreed Day 1 |
| 8 | Oct 3 | Fill in real values in `bvad_constants.json`; wire into resource math | Finish `events.json` expansion (~15–20 events total) | Build the 3D world foundation: lunar terrain, lighting, orbit camera, and HUD-to-world scene boundary |
| 9 | Oct 4 | Win/lose evaluation logic | Write mission briefing + tutorial/onboarding copy | Import and place the astronaut, rover, habitat, and solar-array assets; wire site selection to the 3D scene |
| 10 | Oct 5 | Event trigger/effect hooks (schema only, no content) | Write end-of-mission report language (all outcome branches) | Wire event modal and authoritative sim state to 3D world feedback; use placeholders for runtime systems not yet exposed |
| 11 | Oct 6 | Finalize and freeze `sites.json` with real Day 5–6 data; flip `verified` to `true` | Review own event text against Member 1's real radiation/resource numbers for plausibility | 🎨 3D terrain/material/asset pass: site-specific terrain, rover, habitat, solar arrays, and readable world markers |
| 12 | Oct 7 | Mission report backend (real numbers feeding the report screen) | Start slotting real events into Member 1's trigger system | 🎨 Animate world feedback: solar output, alerts, camera transitions, and event cues |
| 13 | Oct 8 | Buffer/bug-fix; unit-test sim edge cases (zero power, zero food, etc.) | Finish slotting all events into trigger system | Polish the playable 3D outpost scene with real assets and HUD integration |
| **14** | **Oct 9** | 🔗 **Test & Integration #2** — full sim runs on real site data + real BVAD numbers + real (not dummy) events, end to end |
| 15 | Oct 10 | Support Member 2 on event/trigger integration issues from Day 14 | Fix event/trigger issues found Day 14; content tuning pass | Fix UI issues found Day 14; wire remaining screens to real data |
| 16 | Oct 11 | Resource-balance tuning from first playtest feedback | Difficulty-curve pass: which events fire when | Rover movement and animation in the 3D outpost world |
| 17 | Oct 12 | Radiation/shielding edge-case tuning | Crew stress/productivity tuning against real sim | Construction placement and shielding visuals in the 3D outpost world |
| 18 | Oct 13 | Buffer/bug-fix | Buffer/content polish | Buffer/bug-fix |
| 19 | Oct 14 | Support Member 3 on sim-state contract questions | Review all in-game text for consistency/tone | 🎨 Report screen visual polish |
| 20 | Oct 15 | Buffer — own module regression testing | Buffer — playtest own content solo | Complete rover, construction, and event feedback in the 3D outpost world and HUD |
| **21** | **Oct 16** | 🔗 **Test & Integration #3 — Vertical Slice**: full playthrough, start to finish, on the real build |
| 22 | Oct 17 | Balance pass from vertical-slice feedback | Event/difficulty pass from vertical-slice feedback | UI/UX fixes from vertical-slice feedback |
| 23 | Oct 18 | Add difficulty scaling if time allows | Add 1–2 more events if time allows | 🎨 Polish pass: consistent spacing/typography across all screens |
| 24 | Oct 19 | Bug-fixing from Day 22–23 changes | Bug-fixing from Day 22–23 changes | Bug-fixing from Day 22–23 changes |
| 25 | Oct 20 | Buffer | Buffer | 🎨 Start demo video storyboard/script |
| 26 | Oct 21 | Buffer | Buffer | Record/assemble demo footage |
| 27 | Oct 22 | Buffer | Buffer | 🎨 Build pitch slide deck |
| **28** | **Oct 23** | 🔗 **Test & Integration #4** — confirm build is stable enough that remaining days are polish only, not fixing |
| 29 | Oct 24 | On-call for integration bugs only | On-call for content/balance bugs only | Finish demo video |
| 30 | Oct 25 | On-call | On-call | Finish pitch deck |
| 31 | Oct 26 | On-call | On-call | 🎨 Final visual polish pass |
| 32 | Oct 27 | Buffer | Buffer | Buffer |
| 33 | Oct 28 | Buffer | Buffer | Buffer |
| 34 | Oct 29 | Buffer | Buffer | Rehearse live demo / backup video |
| **35** | **Oct 30** | 🔗 **Test & Integration #5 — Dress Rehearsal**: run the exact submission build + demo as if it were qualifier day |
| **36** | **Oct 31** | 🔗 **Submission day** — final fixes only if something breaks in rehearsal; submit |

**Why it's shaped this way:**
- Every 7th day is a shared test day, so nobody goes more than a week building on an untested assumption about someone else's part.
- Data (Member 1) and content (Member 2) are frozen by Day 11, before UI (Member 3) needs to wire real values instead of dummies — this avoids Member 3 building against a moving target.
- Day 21's vertical slice lands with 10 days of runway left specifically so problems found there can still be fixed, not just noted.
- The last 8 days are deliberately buffer/polish/demo-prep heavy, since hackathon risk concentrates at the end and you're building this around coursework, not full-time.

---

*Fill in names against Member 1/2/3 once roles are assigned — the split is designed to be assignable either way based on who's strongest where (sim/data math vs. game design/writing vs. visual/UI work).*

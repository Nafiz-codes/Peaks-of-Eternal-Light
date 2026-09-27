# Triarchy — Workflow Split (3 Teammates)

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
- Implement the UI layer consuming Member 1's sim state and Member 2's content, via the shared data contract
- Animation/juice: resource meters, rover movement, transitions — polish pass once core screens work
- Own final integration: wiring sim + content + UI into one running build, catching interface mismatches early rather than at the end
- Own the demo: the 2–3 minute pitch video/live-demo script, screenshots, and slide deck for judging
- Deliverable: the playable build itself, plus all pitch/demo materials

---

## Interfaces (what connects the three tracks)

Five data files already exist as scaffolds (see repo root) with placeholder values and the agreed schema — the contracts below are locked in, not still to be designed:

1. **Sim state contract** (Member 1 → Member 3): a single object/struct representing "current mission state" (resources, sol number, crew status, active events) that the UI reads every tick — this is generated at runtime by Member 1's code, not a file anyone hand-authors
2. **Event/content contract** (Member 2 → Member 1 & 3): `events.json` — schema is set (8 starter events), Member 2 expands it to ~15–20 following the same fields
3. **Site data contract** (Member 1 → Member 2 & 3): `sites.json` — schema is set, values are placeholders (`verified: false`) until Member 1 fills them in from real QuickMap readings
4. **Life-support constants** (Member 1 internal): `bvad_constants.json` — same placeholder status, to be filled from the real BVAD document
5. **Crew & construction contracts** (Member 2 → Member 1 & 3): `crew.json` and `construction.json` — starter content exists, Member 2 tunes names/costs/balance

## Daily Logging

### Member 3 progress — Sep 27, 2026

- Day 1 complete: reviewed the five existing scaffolds and recorded provisional visual direction, feasibility and integration gaps in [docs/UI_UX.md](docs/UI_UX.md).
- Day 2 complete: [four core-screen wireframes](docs/wireframes.html), with bindings and interaction notes in the design handoff. These are design artifacts, not playable Godot UI. Browser visual QA remains pending because the local-file preview was blocked by browser URL policy.
- Next: Day 3 visual-system review and style lock. Detailed completion entries are in [logs.md](logs.md); later gameplay/integration tasks remain scheduled below.

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
| 8 | Oct 3 | Fill in real values in `bvad_constants.json`; wire into resource math | Finish `events.json` expansion (~15–20 events total) | Wire dashboard UI to Member 1's dummy sim-state contract |
| 9 | Oct 4 | Win/lose evaluation logic | Write mission briefing + tutorial/onboarding copy | Wire site-selection screen to `sites.json` schema (dummy values OK for now) |
| 10 | Oct 5 | Event trigger/effect hooks (schema only, no content) | Write end-of-mission report language (all outcome branches) | Wire event modal to event schema (dummy event OK for now) |
| 11 | Oct 6 | Finalize and freeze `sites.json` with real Day 5–6 data; flip `verified` to `true` | Review own event text against Member 1's real radiation/resource numbers for plausibility | 🎨 Icon/asset pass: resource meters, rover icon, site markers |
| 12 | Oct 7 | Mission report backend (real numbers feeding the report screen) | Start slotting real events into Member 1's trigger system | 🎨 Animation pass: meter fills, screen transitions |
| 13 | Oct 8 | Buffer/bug-fix; unit-test sim edge cases (zero power, zero food, etc.) | Finish slotting all events into trigger system | Polish static screens with real assets from Day 11–12 |
| **14** | **Oct 9** | 🔗 **Test & Integration #2** — full sim runs on real site data + real BVAD numbers + real (not dummy) events, end to end |
| 15 | Oct 10 | Support Member 2 on event/trigger integration issues from Day 14 | Fix event/trigger issues found Day 14; content tuning pass | Fix UI issues found Day 14; wire remaining screens to real data |
| 16 | Oct 11 | Resource-balance tuning from first playtest feedback | Difficulty-curve pass: which events fire when | Rover movement UI/animation |
| 17 | Oct 12 | Radiation/shielding edge-case tuning | Crew stress/productivity tuning against real sim | Construction system UI |
| 18 | Oct 13 | Buffer/bug-fix | Buffer/content polish | Buffer/bug-fix |
| 19 | Oct 14 | Support Member 3 on sim-state contract questions | Review all in-game text for consistency/tone | 🎨 Report screen visual polish |
| 20 | Oct 15 | Buffer — own module regression testing | Buffer — playtest own content solo | Integrate rover + construction UI into main dashboard |
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

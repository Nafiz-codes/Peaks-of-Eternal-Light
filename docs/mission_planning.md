# Pre-landing mission planning

## Audit and integration

The existing startup owns Commander selection and hands the original globe to
`LunarLandingSelector`. Its selected-site transition previously opened the outpost
through `lunar_landing_blend.gd`. New missions now open `mission_planning.tscn` at
that transition. Established missions retain their existing surface return path.
The original Commander, selector, construction, rover, dashboard and live mission
inventory remain authoritative for their respective stages.

Existing reusable systems were `MissionSimulator` (power, life support,
construction costs and rover energy), `PolarSolar` (Horizons geometry and local
horizon), `PolarTerrain` / `OutpostTerrain` (playable relief), and
`MissionSession` / `MissionSave` (state and persistence). The missing components
were candidate-zone/route evaluation, planning inventory, validation, a six-step
UI, draft/approved records and a delivery-independent handoff.

## Implemented behavior

1. Select any of the four authoritative `Resources/sites.json` outposts.
2. Compare three construction footprints, with local coordinates, slope, area,
   preparation materials and calculated transport consequences.
3. Configure solar quantity and compact/distributed wiring layouts, with required
   cable, material, footprint and energy costs.
4. Add finite battery storage and inspect daily charge checkpoints over a
   configurable 24–336-hour interval. Approval requires at least 168 hours.
5. Compare two deployment points and direct/east-detour routes. Cargo handling
   equipment reduces the number of trips.
6. Allocate optional cargo within 1,000 gameplay capacity units. Essential habitat,
   supplies, recycler, baseline power/storage, communications, robotics, medical
   and maintenance equipment cannot be removed.
7. Review and approve a valid plan. Approval automatically writes a durable local
   save before emitting the handoff signal. Continue explicitly opens the existing
   outpost; no planned equipment is delivered, built, charged to or granted to the
   live inventory.

Back/Continue/Edit preserve the draft. Returning through the globe and selecting
the same site preserves it too. Changing sites starts a distinct draft. Save/Load
planning controls and the existing menu slots retain drafts and approvals.
Opening planning does not initialize or overwrite an established mission.

## Calculations and NASA provenance

Source data remain in the existing contracts; no new scientific measurements were
invented or downloaded into them. Relevant primary documentation:

- [NASA GSFC LOLA product 78](https://pgda.gsfc.nasa.gov/products/78): source regional
  topography. The published 5 m products have substantial interpolation and
  uncertainty; the game's compact patches are sampled at 20 m. Sub-meter sampling
  of the playable mesh does **not** increase scientific resolution.
- [NASA/JPL Horizons manual](https://ssd.jpl.nasa.gov/horizons/manual.html): the
  repository's existing solar geometry pipeline.
- Study coordinates, extraction dates and original sources remain authoritative
  in `Resources/sites.json` and `Resources/data_sources.json`.

Construction samples the same 2 m triangle interpolation as the playable mesh,
including the authored central flattening and departure clearing. Candidate
footprints are authored gameplay layouts, not NASA-surveyed construction zones.
Maximum sampled local gradient controls suitability; preparation costs are
`ceil(10 + 2 × slope_degrees)`. Footprints reserve 45 m² for essential systems and
6 m² per extra array, or 4 m² per array in a distributed layout. Distributed wiring
costs eight additional material units and ten additional cable metres. These are
configurable gameplay design allowances, not engineering hardware specifications.
Procedural stone scattering excludes candidate footprints and route corridors.
The east-side layouts avoid existing central outpost structures.

Solar integrates the existing `PolarSolar.observation_at` and `visibility` at the
same 15-minute midpoints used by its daily calculation, including Sun distance and
Earth occultation. Four samples form each hourly yield. Potential daily output is
the simulator's 65 kWh baseline plus its shared 18 kWh constant per extra array.
Connection efficiency is `1 − cable_metres × 0.0005`. All placements use the **same
selected-site horizon**, because separate local array horizons are unavailable.
This is the existing 19 October 2026 epoch, not a forecast for a fictional year or
a promise of perpetual sunlight.

Demand uses the simulator's four-person baseline. Storage starts at its existing
290 kWh in 300 kWh capacity, plus 90 kWh charge / 100 kWh capacity per optional
battery. Construction energy and all planned transport energy are conservatively
reserved before the hourly projection. Charge is clamped to finite capacity;
unserved energy and minimum charge are tracked. Minimum charge must cover twelve
hours of baseline load, not just the final day's balance. A valid margin below
half that reserve is labeled **Limited margin**. Otherwise the plan is **Viable**;
specific conflicts make it **Invalid**. Supplies use the existing initial
water/oxygen/food reserves and BVAD/ECLSS consumption/recycling calculations.
Prospective ice contributes no water.

Transport samples route elevation at no more than 1 m spacing. Three-dimensional
length, maximum longitudinal grade, round trips and energy are recomputed as
cargo changes. Trips are `ceil(cargo_units / (100 × (1 + handling_kit)))`.
Energy is `round_trip_km × trips × existing_rover_kWh_per_km × (1 + grade/10)`.
The base rover rate is the existing construction contract's NASA-derived proxy;
load capacity, grade factor, 18° limit and daily range rule are gameplay estimates.
This is not a NASA-validated route or a dynamic vehicle stability simulation.

The manifest reserves construction materials and cable spools once. It does not
subtract them from live resources. No hardware mass is invented: equipment uses
explicit gameplay cargo units. Existing consumable quantities retain their
original litres/kilograms. Additional storage is the available backup option;
there is no unlimited generator, fuel source or new prospecting gameplay.

## Persistence and future delivery contract

`MissionSession.planning_draft` and `.approved_plan` are separate dictionaries.
Approval stores the normalized inputs, recomputed evaluation (including route
waypoints, budget and timeline), model revision, completion flag,
`delivery_status = "pending"` and a deterministic `plan_id`.
The approval also records a data signature covering site/horizon, terrain patch,
ephemeris, BVAD, construction and planning contracts. Changed source contracts
require a fresh approval rather than silently changing an approved forecast.

`mission_plan_approved(record)` emits a deep copy once for identical inputs.
`pending_mission_plan()` exposes a deep copy for later consumers. Reapproval,
reload and surface handoff never grant or spend inventory. Future Chapter 2 must
atomically record consumption of `plan_id` and deduct each reserved cost once
before granting/building cargo. There is intentionally no delivery/consumption
implementation in this change. Do not treat the approval event itself as delivery.

Save version 4 accepts legacy versions 1–3 without planning fields. New planning
fields are strictly checked for known identifiers, integer bounded quantities,
mandatory equipment, site consistency and a matching approval identifier/revision.
Approved calculations are reproduced from inputs on load, rather than trusting
saved totals. Corrupt data is rejected without replacing the current session.
`user://mission-planning.save` is the automatic approval/manual planning slot;
normal menu slots also serialize both records. A failed automatic write rolls back
the new approval and reports the error. Draft edits require Save to survive exit.

## Files

New: `Resources/mission_planning.json`, `src/simulation/mission_planner.gd`,
`src/ui/mission_planning.gd`, `scenes/mission_planning.tscn`,
`tests/simulation/test_mission_planner.gd`, `tests/ui/test_mission_planning.gd`,
this document and Godot-generated script UIDs.

Modified: `mission_session.gd`, `mission_save.gd`, `mission_simulator.gd`
(shared array-output constant), `lunar_landing_selector.gd`, `game_menu.gd`
(load routing), `rock_scatter.gd` (planning clearance), and the existing
landing-transition/navigation tests (new expected intermediate scene); the arrival
camera test now explicitly initializes an established mission to exercise the
preserved surface-return path.

## Validation

See `mission_planning_validation.md` for executed runs and outstanding failures.
The new calculation tests cover all sites, cargo locks/capacity, invalid and
nonfinite inputs, darkness shortfalls, route/load effects, solar quadrature
agreement, disk save/load, legacy compatibility, corrupt approval rejection,
idempotence and unchanged live inventory. The UI test traverses the actual startup
and Commander flow, invokes the existing video-finished handler to skip waiting
for the opening movie, selects all four sites, navigates/edit/saves/reloads,
approves and opens the existing surface. No new cinematic is added.

## Commit summary

Suggested title: `Add NASA-backed pre-landing mission planning`

Add a shared deterministic planning model and six-step interface after outpost
selection. Reuse LOLA/Horizons and existing resource constants; distinguish authored
layout and cargo assumptions. Persist validated drafts and approvals with an
idempotent pending-delivery handoff; add calculation, persistence and startup-flow
tests. No Git commit is created automatically.

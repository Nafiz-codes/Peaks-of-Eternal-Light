# Member 2 — Day 12 event slotting

Day 12 starts the authored-event handoff into the existing simulator. The event table remains the source for IDs, text, choices, and effect values; the simulator remains authoritative for trigger timing, state changes, and outcomes.

## Verified current paths

`tests/simulation/test_member2_event_slotting.gd` resolves the following authored outcomes through `MissionSimulator.resolve_event_choice()`:

- Solar-particle shelter and keep-working: radiation dose and stress.
- Volatile-prospect deferral and confirmation: prospect-status changes.
- Water-recycler service and radiation-shelter drill: crew-stress costs.
- Extended-illumination choices: battery charge, materials, and crew stress.
- Greenhouse nutrient recalibration: one-time power cost.
- Resupply window: automatic materials grant.

These are real `events.json` entries, not UI fixtures. The test also confirms that all 19 authored entries load.

## Deferred paths for Day 13 and later

The remaining authored events stay loaded, but cannot yet be certified end to end because the current runtime lacks one or more needed action APIs or effect handlers:

| Events | Missing or partial runtime support |
| --- | --- |
| Solar-array dust, equipment malfunction, greenhouse bloom, micrometeorite strike | Structure state, damage/output, food-production, and repair behavior |
| Rover mobility hazard, regolith stockpile, prospect discovery/confirmation triggers | Authoritative rover action, route, and prospecting state |
| Crew conflict, crew-process improvement, shelter drill follow-up | Productivity, shelter-response, and per-crew behavior |
| Battery thermal alert, comms blackout, solar-array alignment | Battery-capacity, warning, relay, and build-state behavior |

The existing resolver still supports a subset of immediate choice effects within some of those entries. This document does not claim their unsupported base effects or triggers are implemented.

## Run

```powershell
& 'E:\CS\Godot_v4.7.2-stable_win64.exe' --headless --path . --script tests/simulation/test_member2_event_slotting.gd
```

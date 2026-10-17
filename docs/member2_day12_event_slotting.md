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

These are real `events.json` entries, not UI fixtures. The current table has 21 authored entries after the later content additions. On October 17, the combined 12-suite run passed, including this test, Member 2 systems and live four-site action/choice integration. See [current audit](day20_completion.md).

## Day 13–20 implementation result

The remaining authored paths are now supported by the shared runtime. Construction queues spend the authored material and power costs, progress over sols using aggregate crew productivity, and publish completed structures. Rover dispatch spends authored travel energy, enforces the per-sol distance cap, and updates prospect state. The available construction outputs, damage/output modifiers, battery capacity, communications warning state, shelter-response bonus, and productivity modifiers are applied by the simulator.

| Events | Runtime support |
| --- | --- |
| Solar-array dust, equipment malfunction, greenhouse bloom, micrometeorite strike | Structure state, damage/output, and food-production behavior are runtime-owned. |
| Rover mobility hazard, regolith stockpile, prospect discovery/confirmation triggers | Authoritative rover dispatch, range/cost, and prospecting state are runtime-owned. |
| Crew conflict, crew-process improvement, shelter drill follow-up | Aggregate productivity and shelter-response state are runtime-owned; the crew remains deliberately aggregate, not per-person health. |
| Battery thermal alert, comms blackout, solar-array alignment | Battery-capacity, warning, relay, and build-state behavior are runtime-owned. |

Timed effects use `remaining_sols` and `started_sol`; their full configured duration is preserved, and the counter is consumed after each affected sol. The focused systems test verifies construction, rover, crew, and event-handler integration.

## Run

```powershell
& .\.tools\godot\Godot_v4.7.2-stable_win64_console.exe --headless --path . --script tests/simulation/test_member2_event_slotting.gd
```

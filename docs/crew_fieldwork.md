# Existing crew fieldwork

The player Commander and three NPCs reuse the existing 3D astronaut models and
animations. Stable node IDs retain interaction routing; names and identification
colors now match the canonical crew. The power console is an unstaffed terminal.
See [active roster and save migration](canonical_crew.md).

| Existing identity / node | Added specialty | Complete playable task |
| --- | --- | --- |
| Dr. Alex Rivera / `water_recycler` | Geology, samples and scientific instruments | Collect, photograph, label and store samples; deploy and service the seismometer with Sam. Alex handles these jobs sequentially. |
| Sam Okafor / `food_storage` | Robotics, habitat engineering and cross-trained medical support | Inspect and repair the rover with finite supplies; assist instrument deployment; report on power and life support. |
| Dr. Maya Chen / `crew_briefing` | Flight engineering, training and safety | Review local routes, communications, return oxygen and crew status; advise the Commander. |

## Play

Start a mission, approach a crew member and press **E**. Their existing crew radio
window now includes field status and task controls above the unchanged resource
report. **Talk / status**, **Assist current step**, **Pause**, **Resume / retry**,
**Follow**, **Return to base**, and **Regroup crew** use that window. Close the
conversation to walk alongside them. Assist requires physical proximity; it helps
prepare tools, carry equipment, photograph/collect, position or verify equipment.

The geologist needs you within 6 m. Choose sample A, approve the optional sample B
detour, or decline optional work. If you leave the team, work stops at its current
checkpoint. Resume after rejoining. A sample is first a carried item; it only
becomes stored after the astronaut walks to the field supplies/sample locker.
Returning before labeling requires a visible labeling step at the locker.

Choose either instrument marker for deployment. The equipment specialist joins
automatically if available. If they are busy, return or finish their task and retry.
The instrument specialist can receive player help for verification too. The visible
instrument changes from positioned to verified to operational. Its status records
uptime, battery reserve and self-test results. Battery depletion stops operation;
assign instrument service again to charge and verify the existing installation.
There is no modeled seismic waveform, and no invented moonquake measurements.

For maintenance, park the rover, ask the equipment specialist for an inspection,
then request repair if needed. Choose maintenance or science power priority.
An NPC repair consumes one replacement kit and one mission material, restoring
40 health by default. Verification follows replacement. The original player **E**
rover repair remains available but now also consumes a finite kit and material.
Outside the local base area, the player must carry the kit. When parts are exhausted,
accept reduced rover capability, return to base, or change the excursion plan.
No free parts are generated.

The marked locker at local `(0, 0, 6)` starts with four containers and three kits.
While near it, use a crew conversation's **Pick up … at locker** button. The player
can carry one of each. Approach the appropriate specialist and choose **Deliver …**,
then resume. Automatically prepared supplies and delivered items come from the same
finite inventory. Unused NPC supplies return to stock on arrival at base.

Ask the crew lead to assess any marked destination, inspect the activity log, request
accompaniment or regroup everyone. Following stays inside the surveyed local area.
Blocked crews stop with an explanation. **Assess alternate approach** checks a route;
**Approve assessed alternative** retries it. If no path exists, clear the obstruction
or change plans. Return orders also use collision-checked routes and never teleport.

## State, persistence and cooperation

`CrewFieldwork` owns the world-side tasks, using `MissionState.fieldwork` for crew
checkpoints/positions, shared reservations, supplies, carried samples, instrument
state, readiness, route records and the latest 100 meaningful activity entries.
Save/load retains in-progress work. Old saves initialize empty fieldwork safely.

The normal sequence is Available → Preparing → Traveling → Working → Recording
results → Returning → Available. Waiting for assistance, Blocked, Paused and
Responding to a hazard retain a checkpoint. Resume reacquires tools and rechecks
travel. Tools and work locations are reserved atomically. Sample IDs prevent repeat
collection; an existing instrument is serviced in place instead of duplicated.

After the configurable startup delay, each specialist attempts useful work. The
geologist waits for the player if necessary; the instrument specialist requests
the existing equipment specialist as a buddy. A shared field-team reservation
prevents simultaneous unrelated science excursions. Navigation stays at its base
station. Nearby rover inspections can proceed separately. Automatic task attempts
are finite, avoiding repeated orders and chatter; further work is player-directed.

Mission decisions, low oxygen or an active solar particle event stop optional work.
The player may order a checked return even during that interruption. Resume requires
resolving the blocker. Communications blackouts suppress live crew-position reports.
Crew outside the configured local radio range are reported as unconfirmed.

## Compatible fallbacks and limits

- There was no NPC navigation mesh. `crew_routes.gd` uses a bounded A* graph over
  the established local landing area, floor/slope checks and capsule sweeps against
  actual colliders. Moving obstacles are rechecked during travel. It does not assess
  unexplored terrain or provide Earth GPS. Routes are local scene coordinates.
- The original `idle` and `moon_walk` clips are reused. Primitive carried cases,
  camera lenses, moving tongs, sample rocks and the seismometer provide visible
  task actions. There are no authored hand/IK geology animations; tools are approximate
  props rather than exact historical replicas. Existing suits are unchanged.
- Photography produces persistent documentation metadata (purpose, position, sol)
  with a visible camera action, not screenshot image files or scientific image analysis.
- The new finite field inventory supplements the mission's existing power, oxygen,
  materials and rover-health state. No separate spacesuit physiology simulation is
  claimed. NPC movement uses the configured compressed oxygen-per-metre rule.
- Maintenance currently acts on the actual rover. Existing water, food, energy and
  crew reports remain accessible. Dust checks are visual observations; no dust fault,
  habitat repair or diagnostic sensor is fabricated.
- The science instrument is an ALSEP-inspired **game adaptation** powered by its own
  finite battery and recording locally. It does not require a base communications
  cable. It is not a reconstruction of an Apollo seismometer's power system.

All durations, speeds, local-range/slope assumptions, oxygen thresholds, battery
lifetime and supply/repair costs are game tuning, **not NASA-certified values**.
Most tuning lives in `Resources/fieldwork.json`; navigation clearance and the bounded
2 m graph are in `crew_routes.gd`. The crew specialties are a gameplay arrangement,
not a historical NASA crew structure.

## Scientific grounding

- [NASA Apollo Lunar Surface Journal and Flight Journal](https://www.nasa.gov/history/alsj-and-afj/)
  describes the transcript/photo/mission-document record used to understand real
  surface activities. This implementation uses documented activity patterns, not
  a claim of replaying or analyzing mission datasets.
- [NASA Apollo experiment archive](https://nssdc.gsfc.nasa.gov/planetary/lunar/apollo.html)
  identifies seismic and other lunar experiments and returned sample collections.
  This supports a sample chain and seismic-instrument task, not simulated NASA data.
- [NASA Apollo 12 surface activities](https://www.nasa.gov/missions/apollo/apollo-12-the-pinpoint-mission/)
  describes paired EVA work, experiment deployment, photography, sample collection
  and return to the lunar module. These motivate the game's paired deployment and
  physical sample-return sequence; distances and task durations are compressed.
- [NASA spacewalking tools](https://www.nasa.gov/suits-and-rovers/spacewalking-tools/)
  describes geology tools including tongs used to retrieve rocks and place them in
  bags. This motivates inspect/photo/tongs/container/label actions. The game's
  primitive models are illustrative.

No NASA datasets were downloaded or analyzed for this feature. There is no added
wind, Earth weather or wind-driven dust-storm behavior.

## Validation

Run `tests/world/test_crew_fieldwork.gd` with the bundled Godot console executable.
It exercises the real outpost, three reused NPC models, assignment, walking, assistance,
pause/resume, shared-camera contention, sample transport, save/restore, deployment,
finite maintenance, local navigation, communications blackout, blocked-path recovery,
delivery, hazard interruption, follow/return, autonomous startup and old-save decoding.
Use `--rendering-method gl_compatibility -- --capture` without `--headless` for a
rendered conversation capture at `.tools/crew-fieldwork-dialogue.png`.

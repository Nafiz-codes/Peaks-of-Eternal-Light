# Active four-person crew

The game now contains the player Commander (CREW_01) plus Dr. Maya Chen (CREW_02),
Dr. Alex Rivera (CREW_03), and Sam Okafor (CREW_04). All use the already implemented
3D astronaut model and animations. Supplied 2D artwork remains reference material;
the future player appearance selector is not implemented by this change.

Maya occupies `crew_briefing`, with teal identification, training/safety guidance,
mission decisions and navigation. Alex occupies `water_recycler`, with amber
identification, and handles both samples and scientific instruments. Sam occupies
`food_storage`, with orange identification, and handles maintenance, instrument
assistance, habitat/power/life-support reports and cross-trained medical support.
Role assignment does not introduce new habitat construction or medical mechanics.

The extra astronaut at `power_console` is removed; an unstaffed terminal preserves
energy telemetry. The three NPCs retain existing station node IDs so interactions,
navigation and saved tasks can be migrated without inventing new models. Labels,
conversation titles, canonical actor metadata, live crew JSON, simulation count
and rescue text agree on four people. Maya is the rescue subject, not an NPC
Commander. The existing rescue staging and model are retained.

## Save compatibility and resource behavior

Save version 2 accepts version 1. Both legacy four- and five-person saves become
the canonical four-person crew without increasing or deleting accumulated supplies.
New missions retain existing starting stock and battery capacity; per-person power,
water, oxygen and food use now accounts for four astronauts. Historical readings
are retained. Existing missions therefore benefit from the reduced future demand.

The removed power specialist's locks are released. If they had an unfinished
instrument assignment, its site is queued for Alex after Alex's current work.
Recorded instrument placement/verification and samples are retained; pre-placement
packing/movement progress restarts with Alex. An existing equipment buddy becomes
available at their saved position for reassignment. Existing carried sample work
is not overwritten. Maya's rescue state stays attached to the same actor node.

## Validation

Regression coverage includes four-person simulation consumption; three reused NPC
models and canonical identities; all resource conversations; Alex's sample and
instrument workflows with Sam; finite repair supplies; save migration with pending
deployment; repeated loads without reserve inflation; rescue and reunion; and
expedition staging across all four landing sites.

Passed: mission simulator, crew dialogue, fieldwork (62 assertions), expedition
lifecycle and legacy migration (23), expedition sites (132), full expedition and
rescue (92), and legacy event/save compatibility. Rendered fieldwork also passed;
the Maya crew-radio screenshot was inspected for readable role labels and controls.

The preparation reports under `docs/characters` describe the earlier asset-only
task. This document supersedes their deferred-runtime notes; the original brief
and artwork metadata remain preserved.

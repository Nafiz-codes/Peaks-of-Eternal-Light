# Canonical crew preparation

Historical preparation record. The subsequent [active crew integration](../canonical_crew.md) now implements the four-person roster with existing 3D models. The artwork and expression catalogs remain preparation-only. The audit below records the earlier state, not the current runtime. The supplied brief is preserved in `source_brief.md`.

| ID | Character | Responsibility |
|---|---|---|
| CREW_01 | The Commander (player) | Surface mission command and exploration decisions |
| CREW_02 | Dr. Maya Chen, 41 | Senior flight engineer, instructor, mentor and safety adviser |
| CREW_03 | Dr. Alex Rivera, 36 | Planetary geology and lunar resources |
| CREW_04 | Sam Okafor, 38 | Robotics, habitat operations and cross-trained medical support |

The intended crew has exactly four people: one player and three NPCs. Commander 01–04 are four appearance choices for CREW_01, never four astronauts or a separate NPC commander. No appearance is selected by default. Callsign, background and personality remain player-defined. These are complete appearance presets, not evidence that their hair, skin or other features can be independently mixed. Glasses and modular customization assets are not supplied.

## Data and artwork

`Resources/characters/preparation/registry.json` holds character biographies, responsibilities, dialogue guidance and catalog references. It follows the project's JSON resource convention but is separate from the live `Resources/crew.json` contract. `assets.json` pairs each full-body image with the correct expression sheet and preserves original path, SHA-256, dimensions and alpha-channel information. `expressions.json` records every existing frame by stable identity.

Images live under `Assets/characters/<asset identifier>/<variant>/`, retaining supplied filenames and bytes. See [the complete inventory and exact file list](asset_inventory.md). There are seven appearance sets, 14 images and 84 expression frames. No images were generated, resized, cropped or recompressed. Full-body images have alpha channels; expression sheets do not. Alpha-channel presence alone does not certify clean cutout edges. Source files remain untouched.

## Expression availability matrix

Cells below contain zero-based frame indices. V means visually supported; A means an ambiguous suggested interpretation requiring review. All cells exist, including ambiguous ones. C1–C4 correspond to the four Commander appearances, not separate speakers. These sheets have no authored emotion labels.

| Suggested context | C1 | C2 | C3 | C4 | Maya | Alex | Sam |
|---|---|---|---|---|---|---|---|
| Neutral / baseline | 00 A | 00 A | 00 A | 00 A | 00 A | 00 A | 00 A |
| Smiling | 01 V | 01 V | 01 V | 01 V | 01 V | 01 V | 01 V |
| Excited / broad smile | 02 V | 02 V | 02 V | 02 V | 02 V | 02 V | 02 V |
| Questioning / skeptical | 03 A | 03 A | 03 A | 03 A | 03 A | 03 A | 03 A |
| Thinking / focused | 04 A | 04 A | 04 A | 04 A | 04 V | 04 A | 04 A |
| Concerned / worried | 05 A | 05 A | 05 A | 05 A | 05 A | 05 A | 05 A |
| Angry / frustrated | 06 V | 06 V | 06 V | 06 V | 06 V | 06 V | 06 V |
| Sad / downcast | 07 V | 07 V | 07 V | 07 V | 07 V | 07 V | 07 V |
| Surprised | 08 V | 08 V | 08 V | 08 V | 08 V | 08 V | 08 V |
| Afraid / alarmed | 09 V | 09 V | 09 V | 09 V | 09 V | 09 V | 09 V |
| Serious / determined | 10 A | 10 A | 10 A | 10 A | 10 A | 10 A | 10 A |
| Confident / reassuring smile | 11 A | 11 A | 11 A | 11 A | 11 A | 11 A | 11 A |

No separate head-portrait files were supplied. Baseline portrait references point to frame 00, which can itself have a slight smile or serious expression. Happy can be a context alias for a reviewed smile; worried can use a reviewed concerned frame. Neither is registered as an extra illustration. The exact neutral/serious/confident/thinking distinctions remain unconfirmed where marked A.

The 3-column, 4-row sheets use top-left-origin pixel rectangles and row-major indices 0–11. Rectangles partition the original image and include separators. Separators and slightly uneven panel edges need crop review when producing future UI portraits; these metadata rectangles are not claimed to be final UI crops.

## Existing system audit and deferred changes

| Existing location | Evidence and eventual work |
|---|---|
| `Resources/crew.json` | Five entries: player, commander (Leila Navarro), engineer (Devon Okoye), botanist (Dr. Jia Chen), medic (Dr. Amara Sethi). Replace through an explicit migration; merge player/commander identity, assign canonical roles, keep medical responsibility with Sam. No automatic one-to-one legacy-name mapping is established. |
| `Resources/bvad_constants.json:6` | `crew_size` is 5. Future four-person balancing must review starting reserves and per-person consumption together. Preserve sourced per-person constants. |
| `src/simulation/mission_simulator.gd:75` | Crew count comes from BVAD; power/water/oxygen/food consumption uses it at lines 501–523. Changing the registry alone has no effect. |
| `src/runtime/mission_save.gd:71` | Legacy four-person saves receive resource increases and every loaded state is forced to five. Future canonical four-person saves need a versioned migration that distinguishes them from historical four-person saves. Do not reuse the old count-only test. |
| `src/world/lunar_outpost.gd:278` | Four interaction stations each populate an astronaut (line 438), in addition to the player. Future three-NPC staging must preserve access to energy, water, food and crew reports without requiring four NPC bodies. |
| `src/ui/crew_report.gd:3`, `src/ui/crew_dialogue.gd`, `src/ui/mission_dashboard.gd:283` | Resource-specialist identities, names, colors, report routing and displayed count need coordinated future mapping. Maya teaches, Alex advises on science, Sam covers engineering/medical support; Commander remains the decision-maker. |
| `src/world/crew_fieldwork.gd`, `Resources/fieldwork.json` | Existing tasks and saved checkpoints use station IDs; instrument deployment also requires an equipment buddy. Reassign responsibilities, task concurrency, reservations and actor ownership across three NPCs without losing science/maintenance coverage. |
| `src/simulation/rover_expedition.gd:5` | Explicit five-identity CREW array. Rescue/reunion and actor identity assumptions need redesign for four canonical people. |
| `src/world/rover_expedition_controller.gd:515` | “All five astronauts accounted for” and legacy NPC rescue staging conflict with the new roster. The player Commander cannot also be an independent missing NPC commander. Defer narrative assignment until the storyline is supplied. |
| `tests/simulation/test_mission_simulator.gd:10`, `:20`; `tests/world/test_expedition_lifecycle.gd:36` | Tests explicitly expect five members and conversion of older four-person saves to five. Replace expectations only with the eventual runtime migration and updated balancing. |
| `tests/world/test_crew_fieldwork.gd`, `tests/ui/test_crew_dialogue.gd` | Station-specific behaviors and saved identities require future regression coverage after remapping. |
| `Resources/construction.json:24` | Food-output description assumes five-person consumption; review balance and wording later. |
| `docs/crew_fieldwork.md`, `docs/crew_dialogue.md`, `docs/rover_expeditions.md:31` | Document four NPCs plus player, old specialties, rescue identity and five-person provisioning. Update alongside implementation, not during preparation. |

The two current naming systems (named resource crew and station specialist IDs) must be reconciled explicitly. No legacy code, art, scene or save was removed or renamed. References to “five resource contracts” are not crew-count defects.

## Future narrative integration specification

1. Resolve `speaker_id` against the four-person registry. Reject unknown speakers instead of inventing astronauts.
2. For CREW_01, obtain callsign and `selected_variant_id` from future player configuration. For NPCs, use their fixed display name and `default` variant. Never infer a selection from the first registry entry.
3. Resolve the emotion to an existing, reviewed frame for that exact character and variant. Stable frame IDs separate visual identity from uncertain emotion interpretation.
4. If the requested expression is missing, use that appearance's frame 00 as the documented baseline fallback. If the appearance/baseline is absent, return unresolved for authoring review. Never silently fall back to commander-01 or another character.
5. Resolve the frame's asset ID and rectangle through the catalogs; future dialogue should not hardcode image paths. Keep full-body reference art separate from conversation portrait frames.
6. Review characterization and topic ownership against registry guidance. Preserve scientific uncertainty; suggested lunar resources are not confirmed discoveries. Respect resource limitations and Sam's medical training scope.
7. Implement only after receiving the actual storyline. Signature quotes are reference material, not newly activated dialogue. No dialogue engine, scene, UI, character creator, expression switching or runtime loader is included here.

## Verification

All 14 source/destination SHA-256 pairs match. JSON parses; four unique character IDs, seven variants, 14 unique assets and 84 unique frames are present. Asset paths exist, references resolve, frames are in bounds and every sheet has all 12 indices. Commander frames and portraits stay within their paired appearance. Complete source biographies are retained in the source brief as well as extracted registry fields.

Preparation adds only the paths listed in the inventory. No gameplay or scene files were edited, no runtime integration was added, and no game behavior change was intended. Full gameplay tests and a running-game visual review were not performed because this change adds unreferenced data and original art only. Existing unrelated edits to `src/world/orbital_model.gd` and `tests/world/test_orbital_motion.gd` were left untouched.

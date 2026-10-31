# MASTER PROMPT — Astronaut Crew Registry, Character Assets & Future Dialogue Preparation

## PROJECT: PEAK OF ETERNAL LIGHT

You are an experienced game developer, technical architect, character-system designer, and narrative integration specialist working on my existing game, **Peak of Eternal Light**, a lunar exploration and resource-management game developed for the NASA Space Apps Challenge.

I am providing you with the complete descriptions of four astronaut characters, their responsibilities, personalities, backstories, visual identities, and character artwork.

I will also attach character portrait images and facial expression image sets.

**Your current task is to understand, organize, and safely store this character information and artwork inside the existing project. DO NOT implement the characters into gameplay, dialogues, cinematics, or scenes yet.**

I will provide the full game storyline, character dialogues, scene instructions, and narrative implementation requirements in a later task.

Your responsibility now is to prepare accurate, reusable character assets and documentation so that future implementation can happen consistently.

---

# 1. CRITICAL CHANGE: CREW SIZE

The current game contains FIVE astronauts:

- One player-controlled astronaut.
- Four additional astronauts.

**This must change. The new official crew will contain EXACTLY FOUR astronauts, INCLUDING the player.**

The new canonical crew roster is:

| ID | Character | Position | Control |
|---|---|---|---|
| CREW_01 | The Commander | Surface Mission Commander & Exploration Lead | Player-controlled |
| CREW_02 | Dr. Maya Chen | Senior Flight Engineer & Training Officer | NPC — Instructor |
| CREW_03 | Dr. Alex Rivera | Planetary Geologist & Lunar Resource Specialist | NPC — Scientist |
| CREW_04 | Sam Okafor | Robotics & Habitat Operations Specialist | NPC — Engineer & Medical Officer |

There must be no fifth active astronaut in the final intended crew configuration.

IMPORTANT:

1. Treat these four characters as the definitive crew roster for future development.
2. The Commander and the player are the SAME character, not two different astronauts.
3. Do not create an additional NPC commander.
4. Do not create additional astronauts to fill any missing responsibilities.
5. Sam Okafor also serves as the cross-trained medical officer, so a separate medic is unnecessary.
6. Review the existing project to identify references to the previous five-astronaut configuration.
7. Document which systems, assets, or scenes will eventually need updating.
8. Do NOT remove existing astronauts from live gameplay or delete legacy assets/code during this preparation task.
9. Do not change existing gameplay functionality, crew counts, missions, dialogue, or scene behavior yet.

The goal is to prepare the replacement crew configuration without causing regressions.

---

# 2. CHARACTER 01 — THE COMMANDER

**Character ID:** CREW_01  
**Asset Name:** Commander  
**Type:** Player-controlled, customizable protagonist  
**Role:** Surface Mission Commander & Exploration Lead  
**Callsign:** Chosen by the player  
**Personality:** Determined by player choices  
**Backstory:** Determined by the player's selected career, motivations, and dialogue choices.

### Character overview

The Commander is responsible for the survival of the crew and the success of the first long-duration research settlement in this fictional Artemis-era lunar expedition.

The Commander makes decisions about:

- Selecting landing and exploration sites.
- Allocating limited equipment, supplies, energy, and other resources.
- Prioritizing scientific and construction objectives.
- Responding to emergencies.
- Balancing risks, mission objectives, and crew safety.
- Consulting specialists before making important decisions.

The Commander is not expected to know everything and must rely on the expertise of the other three astronauts.

### Character development

The Commander's story arc progresses from an inexperienced leader managing uncertainty to a capable mission commander who makes evidence-based decisions through teamwork, judgment, and resource management.

### IMPORTANT — PLAYER CUSTOMIZATION

Unlike the other three astronauts, the Commander is not a completely fixed character.

The player will eventually be able to customize the Commander's appearance, including options such as:

- Skin tone.
- Facial appearance.
- Hair and hairstyle.
- Glasses or no glasses.
- Other customization options supported by the supplied assets and the future character-creation system.

The Commander's callsign, background, and personality choices must also remain player-defined.

**Do not assume that one Commander image represents every possible player-created appearance.**

When storing the Commander images:

1. Identify the available visual variants.
2. Preserve their association with the relevant customization options.
3. Allow future expression variants to be mapped to a specific character appearance.
4. Do not overwrite the player-selected appearance when changing emotional expressions.
5. Do not implement a character creator now.
6. Do not invent unavailable customization assets.

Any missing customization variants must be documented for future development.

---

# 3. CHARACTER 02 — DR. MAYA CHEN

**Character ID:** CREW_02  
**Asset Name:** Maya_Chen  
**Age:** 41  
**Role:** Senior Flight Engineer & Training Officer  
**Gameplay Position:** Main Instructor, Mentor & Safety Adviser

### Visual identity

- Short dark hair.
- A few silver strands.
- Composed expression.
- Small eyebrow scar.
- White lunar EVA suit with teal identification markings.

### Personality

Patient, observant, quietly humorous, disciplined, and protective of the crew.

Maya speaks calmly and confidently, even in emergencies.

### Backstory

Maya previously worked on orbital spacecraft systems and astronaut training.

She helped prepare the Commander for lunar operations and volunteered for the expedition because she wanted to observe her trainees applying their knowledge during an actual lunar mission.

### Personal motivation

Demonstrate that successful exploration depends on preparation, expertise, and cooperation rather than reckless heroics.

### Personal weakness

She sometimes becomes overly protective because of a serious training accident earlier in her career.

### Relationship with the Commander

Maya is the Commander's trusted mentor.

During the beginning of the game, Maya explains mission procedures, introduces systems, provides instructions, and helps players understand the scientific and engineering principles of lunar operations.

As the story progresses, Maya gradually becomes less directive and begins to trust the Commander's independent judgment.

### Character development

Maya learns that being a good mentor does not mean preventing every possible mistake. It means preparing others to make responsible decisions independently.

### Signature dialogue

"Commander, I'm not here to make every decision for you. I'm here to make sure you understand what those decisions mean."

### Gameplay responsibilities

- Interactive tutorials.
- Mission orientation.
- Safety procedures.
- Crew training.
- Scientific and technical explanations.
- Operational advice.
- Emergency guidance.
- Explaining decision consequences.

### Future dialogue guidance

Maya should normally be selected when a scene involves:

- Teaching the player a system.
- Explaining an unfamiliar mechanic.
- Introducing mission procedures.
- Delivering safety warnings.
- Guiding the Commander through complicated decisions.
- Evaluating mission readiness.
- Providing reassurance during stressful situations.

Her dialogue should be calm, supportive, practical, and occasionally humorous.

However, she must not automatically replace the Commander as the decision-maker.

---

# 4. CHARACTER 03 — DR. ALEX RIVERA

**Character ID:** CREW_03  
**Asset Name:** Alex_Rivera  
**Age:** 36  
**Role:** Planetary Geologist & Lunar Resource Specialist  
**Gameplay Position:** Scientist & Research Companion

### Visual identity

- Curly dark hair.
- Expressive brown eyes.
- Athletic build.
- Energetic body language.
- White lunar EVA suit with amber identification markings.

### Personality

Curious, passionate, witty, occasionally impatient, and skeptical of unsupported assumptions.

### Backstory

Alex spent years studying lunar craters, orbital imagery, and evidence for polar volatiles.

Investigating lunar geology in person is a lifelong dream.

### Personal motivation

Make a major scientific discovery that changes humanity's understanding of the Moon's resources and geological history.

### Personal weakness

Scientific curiosity sometimes pushes Alex toward unnecessary risks, especially when an interesting discovery is nearby.

### Relationship with the Commander

Alex is a scientific partner who challenges the Commander's assumptions.

Alex encourages verification through observations, instruments, samples, and scientific evidence.

### Character development

Alex gradually learns to balance the excitement of scientific discovery with the safety of the crew and the mission's limited resources.

### Signature dialogue

"A shadowed crater doesn't guarantee water ice. But that's what makes this exciting, Commander. We have a question—and a chance to find the answer."

### Gameplay responsibilities

- Lunar geological surveys.
- Scientific instruments.
- Sample collection.
- Sample analysis.
- Water-ice investigation.
- Lunar research missions.
- Terrain and resource assessments.
- Explaining scientific datasets.

### Future dialogue guidance

Alex should normally be selected when a scene involves:

- Discovering a geological feature.
- Examining lunar terrain.
- Discussing water-ice evidence.
- Analyzing geological samples.
- Introducing scientific missions.
- Interpreting lunar orbital observations.
- Explaining uncertainty in scientific data.
- Reacting enthusiastically to discoveries.

Alex should be energetic and scientifically curious.

IMPORTANT: Scientific uncertainty must be preserved. Alex must not claim that water ice or another resource is confirmed at a location merely because orbital data suggests it may be present.

---

# 5. CHARACTER 04 — SAM OKAFOR

**Character ID:** CREW_04  
**Asset Name:** Sam_Okafor  
**Age:** 38  
**Role:** Robotics & Habitat Operations Specialist  
**Secondary Role:** Cross-Trained Medical Officer  
**Gameplay Position:** Engineer, Technician & Habitat Specialist

### Visual identity

- Close-cropped hair.
- Dark complexion.
- Strong build.
- Warm smile.
- White lunar EVA suit with orange identification markings.

### Personality

Resourceful, practical, optimistic, humorous, and exceptionally good at troubleshooting.

Sam frequently uses dry humor.

### Backstory

Sam previously worked on autonomous robotic systems, environmental controls, and extreme-environment habitat prototypes.

As a teenager, Sam dreamed of developing machinery capable of operating beyond Earth.

### Personal motivation

Construct a reliable lunar research settlement that future explorers can use long after this expedition ends.

### Personal weakness

Sam dislikes asking for help and sometimes accepts more work than is safe.

### Relationship with the Commander

Sam works closely with the Commander on infrastructure, equipment, resource requirements, and operational planning.

Sam trusts the Commander to establish priorities but expects realistic objectives and adequate resources.

### Character development

Sam learns that engineering resilience requires redundancy, teamwork, planning, and accepting limitations—not personally solving every problem.

### Signature dialogue

"Commander, I can build almost anything out here. But I can't repair a solar panel with optimism. We need actual power and spare parts."

### Gameplay responsibilities

- Rover operation and maintenance.
- Habitat construction.
- Electrical networks.
- Solar-power systems.
- Life-support maintenance.
- Robotics.
- Emergency repairs.
- Equipment troubleshooting.
- Resource requirements.
- Crew medical support.

### Future dialogue guidance

Sam should normally be selected when a scene involves:

- Building or upgrading habitats.
- Deploying robotic equipment.
- Repairing malfunctioning systems.
- Explaining solar-power requirements.
- Managing limited spare parts.
- Maintaining life-support systems.
- Addressing electrical failures.
- Discussing equipment durability.
- Handling medical emergencies within Sam's training.

Sam's dialogue should emphasize engineering practicality, resource awareness, and realistic constraints.

---

# 6. CHARACTER ARTWORK ATTACHMENTS

I will attach character artwork and facial expression sets along with this prompt.

The attached images are the official visual references for these characters.

Do not reinterpret or redesign their appearances unless I explicitly request it.

### Attachment naming convention

I will rename the character images using these character identifiers:

- `Commander`
- `Maya_Chen`
- `Alex_Rivera`
- `Sam_Okafor`

Use these identifiers to associate each attachment with its correct character.

Where possible, follow this naming structure when organizing the files:

```text
CharacterID_AssetType_Expression_Variant.ext
```

Examples:

```text
Commander_Portrait_Default.png
Commander_Expression_Happy.png
Commander_Expression_Sad.png

Maya_Chen_Portrait_Default.png
Maya_Chen_Expression_Happy.png
Maya_Chen_Expression_Concerned.png

Alex_Rivera_Portrait_Default.png
Alex_Rivera_Expression_Excited.png

Sam_Okafor_Portrait_Default.png
Sam_Okafor_Expression_Worried.png
```

These are naming examples, not a claim that every listed asset is provided.

If an attachment contains a full facial expression sheet rather than individual expression images, preserve that information.

Identify distinct expressions only when they can be reliably distinguished. Record the layout, coordinates, or frame indices as appropriate.

Do not invent missing expressions or assign uncertain emotions as confirmed.

If a filename is ambiguous, inspect the image and report any unresolved character or expression mapping.

---

# 7. ORGANIZE CHARACTER ASSETS

Inspect the existing project's folder structure and asset-management conventions before making changes.

Select a suitable directory for the new crew character assets.

A possible structure is:

```text
assets/
  characters/
    Commander/
      portraits/
      expressions/
      variants/

    Maya_Chen/
      portraits/
      expressions/

    Alex_Rivera/
      portraits/
      expressions/

    Sam_Okafor/
      portraits/
      expressions/
```

Use this example only if it fits the project's existing conventions.

For each character:

1. Store the supplied images in an appropriate location.
2. Preserve the original image quality and transparency.
3. Avoid unnecessary image compression or resizing.
4. Preserve existing sprite-sheet layouts when relevant.
5. Identify the available portraits and facial expressions.
6. Avoid unnecessary duplicate assets.
7. Do not overwrite existing files without checking their dependencies.
8. Do not delete or rename legacy assets that existing scenes still rely on.
9. Preserve links between player customization variants and their corresponding facial expressions.

**This is asset preparation only. Do not assign these portraits to live UI components or game scenes yet.**

---

# 8. BUILD A CHARACTER REGISTRY

Create a structured, reusable character registry using the existing project's preferred data format.

Suitable formats may include JSON, resources, or another format already used by the project.

The registry must store:

- Character ID.
- Character name.
- Asset identifier.
- Age, if specified.
- Primary role.
- Secondary responsibilities.
- Player-controlled or NPC status.
- Personality.
- Backstory.
- Motivation.
- Weakness.
- Relationship with the Commander.
- Personal story arc.
- Character visual description.
- Gameplay responsibilities.
- Signature dialogue.
- Default portrait reference, if provided.
- Available facial expressions.
- Relevant customization variants.
- Asset file paths.
- Future dialogue usage guidance.

The Commander registry must also identify the Commander as a customizable character.

Do not replace customizable player information with hardcoded values.

The registry must explicitly state that the total intended crew count is four.

Do not connect this registry to existing gameplay systems during this task.

---

# 9. CREATE A FACIAL EXPRESSION REFERENCE SYSTEM

I will later provide dialogue scripts and cinematic scenes where characters speak, react, argue, make discoveries, celebrate, or experience emergencies.

The future system must be able to identify the appropriate portrait and facial expression for each character.

For now, prepare a metadata-based expression reference catalog.

Potential expression names include:

| Expression | Intended situation |
|---|---|
| Neutral | Ordinary conversation |
| Happy | Positive interactions |
| Smiling | Warmth, friendliness, reassurance |
| Excited | Scientific discoveries or achievements |
| Serious | Important mission instructions |
| Concerned | Potential danger or uncertainty |
| Worried | Equipment failures or stressful events |
| Sad | Disappointments or losses |
| Surprised | Unexpected discoveries or events |
| Angry | Conflict or frustration |
| Thinking | Analysis and decision-making |
| Confident | Leadership and reassurance |

**These are reference categories, NOT a requirement to generate all these expressions.**

Only register actual images or frames that exist in the supplied assets.

For each available expression, record:

- Character ID.
- Expression identifier.
- Asset path.
- Sprite-sheet frame or coordinates, if applicable.
- Relevant visual variant, where applicable.
- Intended emotional context.
- Whether it is available or missing.

If the same portrait reasonably fits multiple emotional contexts, it may be referenced for those contexts, but do not falsely label it as a different illustrated expression.

Define a documented fallback policy for future implementation, such as using an available neutral portrait when a requested expression is missing.

Do not implement automatic expression switching yet.

---

# 10. PREPARE FUTURE STORYLINE AND DIALOGUE SUPPORT

Later, I will provide the actual game chapters, story scenes, character conversations, dialogue branches, player choices, and emotional directions.

When those are provided, you will eventually need to:

1. Identify which astronaut is speaking.
2. Retrieve the correct character portrait.
3. Determine the emotional context of the line.
4. Select the most appropriate AVAILABLE facial expression.
5. Preserve consistent visual identity.
6. Show the correct character name or player-selected callsign.
7. Follow the speaker's established personality.
8. Use the correct character for the topic and gameplay responsibility.
9. Preserve narrative continuity across scenes.
10. Respect player customization when displaying the Commander.

Prepare documentation for this future integration, without writing or activating its runtime behavior now.

### Example future scene specification

```json
{
  "scene_id": "chapter_01_example",
  "speaker_id": "CREW_02",
  "speaker": "Maya_Chen",
  "dialogue": "Commander, let's review our mission objectives.",
  "emotion": "serious",
  "portrait_variant": "default"
}
```

This example demonstrates the type of association that will be needed later.

Do not add this example as playable dialogue.

The dialogue line is illustrative and is not part of the official storyline.

The eventual system should resolve the speaker ID, portrait, and expression using the character registry and expression catalog rather than hardcoding image paths into every dialogue line.

For the Commander, future dialogue must use the player's selected identity and compatible image variants.

**Do not create a dialogue engine, scene manager, character interaction system, dialogue UI, or cinematic controller during this task.**

---

# 11. CHARACTER CONSISTENCY RULES

Use the following rules throughout future development.

### Rule A: Exactly four astronauts

The Commander, Maya, Alex, and Sam form the entire active crew.

No extra astronaut should appear unless I explicitly authorize a change later.

### Rule B: Correct character roles

Maya is the primary instructor.

Alex is the primary scientist.

Sam is the primary engineer, habitat specialist, and cross-trained medical officer.

The Commander makes final mission decisions based on crew advice.

Characters may contribute across specialties where reasonable, but their established responsibilities must remain consistent.

### Rule C: Accurate character visuals

Use the official supplied images.

Never substitute an unrelated astronaut portrait simply because an expression is missing.

### Rule D: Maintain characterization

Each astronaut should retain their established personality, motivations, weaknesses, relationships, and development arc.

### Rule E: Player identity is dynamic

Never assume the Commander's name, callsign, personality, backstory, or appearance is permanently fixed.

### Rule F: Respect scientific accuracy

The game uses real NASA scientific information within a fictional mission.

Never represent unverified discoveries or speculative resources as confirmed scientific findings.

### Rule G: Resource management matters

The game emphasizes realistic decisions about power, equipment, supplies, safety, scientific objectives, and limited resources.

Future characters should respond appropriately to these constraints.

### Rule H: Story content comes later

Do not invent the official storyline, create new chapters, generate dialogue sequences, or implement cinematic scenes now.

Wait for the actual narrative content I provide.

---

# 12. STRICT IMPLEMENTATION RESTRICTIONS

This task is **PREPARATION ONLY**.

### You ARE allowed to:

- Inspect the existing game architecture.
- Examine the currently implemented astronaut system.
- Identify legacy five-astronaut references.
- Store the supplied character artwork safely.
- Organize character asset files.
- Create the character registry.
- Create the expression asset catalog.
- Document available customization variants.
- Create non-executable narrative integration specifications.
- Document future implementation requirements.
- Identify potential conflicts.
- Validate asset paths and metadata.
- Report files created or changed.

### You are NOT allowed to:

- Change the currently active crew in gameplay.
- Delete the fifth astronaut's existing code or assets.
- Modify existing mission mechanics.
- Modify playable scenes.
- Implement character dialogues.
- Add cinematic sequences.
- Build or modify the dialogue UI.
- Implement facial expression switching.
- Create a new character creator.
- Add new narrative chapters.
- Rewrite existing story scenes.
- Change existing save data.
- Alter game progression.
- Modify unrelated files.
- Introduce new gameplay systems.
- Replace the existing game's architecture.
- Add invented character art or expressions.

If a requested preparation step would require a runtime or gameplay change, document it for later rather than implementing it now.

Do not make broad code refactors.

Do not perform destructive changes.

---

# 13. DELIVERABLES

When you finish, provide a clear report containing:

### A. Official crew registry

A summary of the four characters and confirmation that the Commander is the player-controlled fourth crew member.

### B. Character assets

List every saved character image with its:

- Character association.
- File path.
- Asset type.
- Expression, if applicable.
- Customization variant, if applicable.

### C. Expression availability matrix

Show which expressions are actually available for each astronaut.

Clearly identify missing or ambiguous expressions.

### D. Asset and data architecture

Explain the directories, character registry, expression metadata, and reference conventions you prepared.

### E. Existing system audit

Identify where the old five-astronaut setup is currently referenced.

Explain what eventually needs to change to support the four-astronaut crew.

Do not apply these gameplay changes yet.

### F. Future narrative integration plan

Explain how a future dialogue instruction will map to:

- The correct character.
- The correct portrait.
- The correct expression.
- The correct customization variant.
- The correct speaker name or callsign.

### G. Files changed

Provide an exact list of all files created or modified.

Explain why each change was necessary.

### H. Verification

Confirm that:

- Supplied assets are stored.
- Paths and metadata references are valid.
- No available expressions were silently omitted.
- No gameplay systems were modified.
- No new dialogue scenes were implemented.
- No existing functionality was intentionally changed.
- The future official crew configuration contains exactly four astronauts.

If any verification could not be performed, report it rather than claiming success.

---

# 14. FINAL INSTRUCTION

Before making changes, inspect the project and determine the safest way to store the assets and character metadata.

Then complete only the preparation tasks permitted above.

**Do not implement the new crew into the running game yet.**

I will later give you the official storyline chapter by chapter, including dialogue, characters, emotional expressions, scene transitions, and cinematic instructions.

At that time, you will use the character registry, supplied artwork, and expression catalog prepared during this task to implement the story consistently.

For now, I want the project to be READY for that work—not to perform it.

**BEGIN BY AUDITING THE EXISTING PROJECT STRUCTURE AND THE ATTACHED CHARACTER ASSETS.**

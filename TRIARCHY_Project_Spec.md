# Junior Astronaut Mission Trainer — Project Specification

## 1. Project Overview

**TRIARCHY** is an interactive space-themed STEM simulation/game built for the NASA Space Apps Challenge challenge **“Build a Junior Astronaut Mission Trainer.”**

**Peaks of Eternal Light** is the game title. **TRIARCHY** is the team name.

The player becomes the commander of a lunar outpost and must keep a crew alive while expanding the settlement. The game turns real mission-engineering trade-offs into an accessible, visually compelling experience.

The core idea is:

> **Turn NASA lunar science into a game where every engineering decision has a consequence.**

The project should feel like a polished mission-control experience rather than a childish educational game or a spreadsheet simulator.


### Hackathon Scope

This is a roughly **one-month hackathon build**, so scope discipline is critical. The intended playable mission is **7–10 sols**, not 30 sols. The shorter mission should still contain enough resource pressure, events, construction decisions, and consequences to demonstrate the core engineering trade-offs.


### Primary experience

The player must:

1. Select a lunar landing/base location.
2. Establish essential infrastructure.
3. Balance power, water, oxygen, food, radiation protection, crew health, and other resources.
4. Respond to unexpected mission events.
5. Expand the outpost.
6. Survive a fixed number of lunar days (“sols”).
7. Complete optional science/engineering objectives.
8. Receive a final mission report explaining how their decisions affected mission success.

---

# 2. Target Audience

The primary audience is **students and young learners** who are interested in:

- Space
- NASA
- Engineering
- STEM
- Games
- Robotics
- Science exploration

The simulation should be understandable without requiring advanced physics or aerospace knowledge.

The design principle is:

> **Simple to understand, difficult to optimize.**

Players should understand what each system does within seconds, while the interactions between systems create meaningful strategic decisions.

---

# 3. Design Goals

## 3.1 Educational

Players should learn that real space missions involve competing constraints.

Examples:

- More solar panels provide more power but require resources and construction time.
- More radiation shielding improves crew safety but consumes mass/resources.
- Water extraction increases independence but requires energy and rover/infrastructure capacity.
- Hydroponics produces food but consumes power and water.
- Sending astronauts outside can accomplish objectives but increases exposure and consumes crew time.
- Choosing a site with better sunlight may mean compromising access to other resources.

The game should teach through consequences rather than lectures.

---

## 3.2 Fun

The player should always have meaningful choices.

The game should include:

- Missions
- Random/triggered events
- Resource crises
- Exploration
- Construction
- Upgrades
- Optional objectives
- Risk/reward decisions
- Visible consequences

---

## 3.3 Visually Appealing

The visual direction should be:

**NASA mission control + cinematic sci-fi + modern game UI.**

Avoid:

- Generic AI-generated space aesthetics
- Childish cartoon styling
- Generic neon cyberpunk
- A plain dashboard with charts
- A static landing page pretending to be a game

The interface should communicate that the player is operating an actual lunar mission.

Suggested visual elements:

- Dark space/lunar environment
- Purple/blue primary palette with restrained accent colors
- Metallic UI elements
- Lunar terrain
- Animated rover
- Habitat modules
- Solar arrays
- Resource indicators
- Mission alerts
- Cinematic transitions
- Starfield/background environment
- Subtle particle effects
- Mission-control typography
- Clear data visualization

---

# 4. Core Game Concept

## Mission: Establish and Operate a Lunar Outpost

The initial version should focus on the **Moon**, preferably the **lunar south-pole region**, because the region provides a compelling combination of:

- Extreme illumination differences
- Permanently shadowed regions
- Potential water-ice/hydrogen resources
- Terrain challenges
- Radiation considerations
- Solar-power opportunities

The initial playable mission runs for **7–10 sols**, as set by the hackathon scope and the day-by-day workflow.

The exact duration can be tuned during playtesting.

### Primary objective

Keep the crew alive and operational for the full mission duration.

### Secondary objectives

Examples:

- Establish water extraction.
- Produce a percentage of food locally.
- Maintain acceptable radiation exposure.
- Deploy scientific instruments.
- Reach a target level of power independence.
- Explore a high-value region.
- Complete a rover mission.
- Build sufficient shielding.

---

# 5. NASA/Open Data Requirement

The project must use open data from NASA or an approved space-agency partner.

NASA data should be part of the actual game logic wherever practical, not merely displayed as decorative references.

Potential NASA datasets/sources include:

## 5.1 Lunar Reconnaissance Orbiter — LOLA

**Use:**

- Lunar elevation
- Terrain difficulty
- Slope/roughness
- Landing-site evaluation
- Rover navigation/construction difficulty

LOLA data can support a terrain model or derived site scores.

---

## 5.2 LRO Illumination Data

**Use:**

- Solar power availability
- Landing-site selection
- Day/night/illumination simulation
- Energy-generation differences between locations

This is especially useful for the lunar south pole, where illumination varies dramatically across short distances.

---

## 5.3 LRO — LEND

**Use:**

- Hydrogen distribution
- Water-resource potential
- Site-selection/resource-prospecting mechanics

Important: hydrogen presence should not automatically be presented as confirmed extractable water. The game should distinguish between **resource potential** and guaranteed resource availability.

---

## 5.4 LRO — CRaTER

**Use:**

- Radiation environment
- Radiation-risk mechanics
- Shielding decisions
- Solar/radiation event modeling

The game should use scientifically defensible simplifications rather than pretending to be a mission-grade radiation simulator.

---

## 5.5 LRO — LROC

**Use:**

- Lunar surface imagery
- Terrain context
- Landing-site visuals
- Hazard/resource context
- Exploration visuals

---

# 6. NASA Data Philosophy

The project should explicitly communicate:

> **NASA data → game mechanics → player decision → consequence**

Examples:

### Illumination data

NASA illumination information affects solar generation.

### Terrain data

NASA elevation/terrain information affects construction and rover difficulty.

### Hydrogen/resource data

NASA resource information affects water-prospecting potential.

### Radiation data

NASA radiation measurements inform the risk model.

This makes the project more than a fictional space game.

---

# 7. Landing-Site Selection

The first major gameplay decision should be:

# WHERE DO YOU ESTABLISH THE OUTPOST?

The player should be shown a lunar map with several candidate sites.

Each site has different characteristics.

Example:

| Site | Sunlight | Terrain | Resource Potential | Radiation Risk | Construction |
|---|---|---|---|---|---|
| Ridge A | Very High | Difficult | Low | High | Difficult |
| Ridge B | High | Moderate | Medium | High | Moderate |
| Crater Edge | Medium | Moderate | High | Lower | Moderate |
| Shadow Zone | Very Low | Difficult | Very High | Lower | Very Difficult |

These values should be derived from real data where possible.

The game should avoid presenting invented numbers as if they were direct NASA measurements.

Instead, distinguish:

- **Observed/source data**
- **Derived game values**
- **Game balancing modifiers**

---

# 8. Core Simulation Systems

The simulation should be built around a central `MissionState`.

Example conceptual structure:

```text
MissionState
├── sol
├── crew
├── power
├── batteries
├── water
├── oxygen
├── food
├── radiation
├── rover
├── infrastructure
├── science
├── budget/resources
├── location
├── events
└── objectives
```

The simulation advances one time step at a time.

Conceptually:

```text
advanceSol()
    ↓
calculate_environment()
    ↓
generate_power()
    ↓
consume_resources()
    ↓
apply_production()
    ↓
apply_radiation()
    ↓
update_crew()
    ↓
process_events()
    ↓
check_objectives()
    ↓
check_failure_conditions()
```

---

# 9. Power System

Power is one of the primary constraints.

Potential power sources:

- Solar arrays
- Battery storage
- Optional advanced/nuclear power system depending on scope

Power consumers:

- Habitat
- Life support
- Water extraction
- Water recycling
- Food production
- Science equipment
- Rover charging
- Construction
- Resource processing

Conceptual model:

```text
Net Power =
    Solar Generation
  + Other Generation
  + Battery Discharge
  - Habitat Consumption
  - Life Support Consumption
  - Food Production
  - Mining
  - Rover
  - Science
  - Other Systems
```

The player should sometimes face a power deficit.

---

# 10. Water System

Water is both a survival resource and an infrastructure resource.

Sources:

- Initial supplies
- Recycling
- Resource extraction
- Potential resupply

Uses:

- Crew consumption
- Agriculture
- Processing
- Other mission operations

Conceptual model:

```text
Water Remaining =
    Starting Water
  + Extracted Water
  + Recycled Water
  - Crew Consumption
  - Agriculture
  - Processing
```

Water extraction should require:

- Energy
- Rover/infrastructure
- Time
- Suitable resource location

---

# 11. Oxygen System

Oxygen is a life-support resource.

Potential sources:

- Initial reserves
- Life-support regeneration/recycling
- Resource-processing systems

Uses:

- Crew respiration
- EVA operations
- Habitat leakage/emergency events if implemented

The system should remain understandable.

Avoid building an overly complex atmospheric model.

---

# 12. Food System

The game should include:

## Hydroponics / Controlled Agriculture

Benefits:

- Produces food
- Reduces dependence on stored supplies

Costs:

- Power
- Water
- Infrastructure
- Crew maintenance

Emergency food reserves can provide a buffer.

This creates a strategic choice:

> Invest resources into long-term food independence or preserve resources for immediate survival.

---

# 13. Radiation System

Radiation should be a strategic risk rather than simply another percentage bar.

Possible protection methods:

### Light Habitat

- Cheap
- Fast
- Weak shielding

### Regolith Shielding

- Resource-intensive
- Better protection
- Requires construction

### Naturally Shielded Location

- More difficult to establish
- Better protection potential
- May sacrifice sunlight/accessibility

Radiation should also affect EVA decisions.

---

# 14. Crew System

The crew should be represented as actual people rather than a single health number.

Example crew:

```text
Commander Maya
Role: Engineering

Dr. Chen
Role: Biology

Alex
Role: Robotics

Sam
Role: Geology
```

Each crew member may have:

- Health
- Energy
- Stress
- Productivity
- Specialization

Not every individual metric needs to be visible to the player.

The purpose is to give the simulation human stakes.

---

# 15. Rover System

The rover is a limited operational resource.

It can:

- Scout sites
- Search for resources
- Carry materials
- Repair infrastructure
- Clean solar arrays
- Perform exploration objectives

Constraints:

- Battery
- Distance
- Time
- Wear/damage
- Availability during emergencies

The rover should force choices.

Example:

> A water-rich region is detected 7 km away, but the rover may be needed later for an emergency solar-array repair.

---

# 16. Construction System

The player should be able to construct or upgrade modules.

Potential buildings:

- Habitat
- Solar array
- Battery
- Water recycler
- Water extraction plant
- Hydroponics module
- Science lab
- Rover garage
- Regolith shielding
- Communications system
- Emergency shelter

Each construction item should have:

- Cost
- Construction time
- Power consumption
- Resource impact
- Benefits
- Potential dependencies

Do not implement dozens of buildings. A smaller set with meaningful interactions is better.

---

# 17. Mission Events

Events are essential for turning the simulator into a game.

Examples:

## Solar Array Degradation

Dust or operational issues reduce solar output.

Player choices:

- Send rover
- Send astronaut
- Ignore

Each choice has different consequences.

---

## Radiation Event

An elevated radiation event occurs.

Player choices:

- Shelter crew
- Cancel EVA
- Continue operations

---

## Water Deposit Discovery

The rover detects promising resource data.

Player chooses whether to investigate.

---

## Equipment Failure

A critical system becomes less efficient.

Player chooses:

- Repair
- Reroute power
- Accept reduced performance

---

## Food Production Problem

Hydroponics efficiency drops.

Player must decide whether to spend power/resources fixing it.

Events should create decisions, not simply punish the player randomly.

---

# 18. Educational Explanation Layer

After important decisions, the game can explain the engineering trade-off.

Example:

> **MISSION SCIENCE**
>
> Regolith can be used as shielding material. Increasing shielding improves radiation protection but requires additional construction resources and time.
>
> **Trade-off**
>
> Protection ↑  
> Material Cost ↑  
> Construction Time ↑

This should be short and optional.

The player should learn naturally through gameplay.

---

# 19. AI/API Scope

## No AI or external AI API will be implemented in the game.

The final hackathon build should be fully self-contained and should not depend on OpenAI or another AI service for gameplay, explanations, recommendations, or mission progression.

Educational explanations should be **pre-authored and deterministic**.

For example, after building regolith shielding, the game can display:

> **MISSION SCIENCE**
>
> Regolith can be used as shielding material. More shielding improves radiation protection, but requires additional construction resources and time.

This keeps the educational experience reliable, fast, offline-friendly where practical, and within the project's one-month scope.

AI may be used by the development team as a coding/design/research tool, but **AI is not a gameplay feature and must not be presented as one.**

---

# 20. Game Loop

The core loop:

```text
PLAN
  ↓
BUILD
  ↓
RUN THE SOL
  ↓
OBSERVE NASA-DERIVED ENVIRONMENT
  ↓
EVENT / CONSEQUENCE
  ↓
ADAPT
  ↓
EXPAND
  ↓
SURVIVE
```

The player should always know:

1. What is happening?
2. Why is it happening?
3. What choices do I have?
4. What are the consequences?

---

# 21. Win/Lose Conditions

## Mission Success

Example:

- Survive all 7–10 sols.
- Keep required crew alive.
- Maintain critical resources above failure thresholds.
- Complete the primary mission.

## Mission Failure

Possible causes:

- Oxygen reaches critical failure
- Water reaches critical failure
- Food reaches critical failure
- Crew health reaches critical state
- Catastrophic infrastructure failure
- Sustained power failure

Avoid instant unexplained game-over states.

Whenever possible, provide warnings and opportunities to recover.

---

# 22. Final Mission Report

At the end of the 7–10-sol mission, show a cinematic report.

Example:

```text
LUNAR OUTPOST ALPHA

MISSION COMPLETE

7–10 / 7–10 SOLS

Crew Survival       100%
Power Independence   82%
Water Independence   67%
Food Production      43%
Radiation Protection 91%

NASA DATA USED
✓ LRO / LOLA
✓ LRO / LEND
✓ LRO / CRaTER
✓ LRO / LROC
```

Also show:

- Major decisions
- Critical events
- Resource history
- Infrastructure built
- Mission objectives
- Final strengths/weaknesses
- NASA data sources

The final report should help the learner understand *why* the mission succeeded or failed.

---

# 23. Technical Architecture

The exact stack can be decided during implementation, but the architecture should separate:

## Data Layer

NASA datasets/API/static processed data.

```text
NASA Open Data
      ↓
Data Processing
      ↓
Normalized Game Data
```

## Simulation Layer

Pure deterministic game logic.

```text
MissionState
    ↓
Simulation Engine
    ↓
Updated MissionState
```

The simulation engine should ideally be independent of the UI.

## Presentation Layer

The playable presentation is a Godot 4.7 3D lunar-outpost world with a mission-control HUD. The HUD supports the world; it does not replace it with a static dashboard.

```text
MissionState
    ↓
Godot presentation
    ├── Node3D lunar terrain, lighting, and orbit camera
    ├── 3D outpost: habitat, solar array, rover, and astronaut
    ├── State-driven world feedback: power, events, construction, rover, and shelter
    └── CanvasLayer HUD: dashboard, site selection, event dialog, and mission report
```

The minimum 3D scene must let the player inspect the selected site and see the outpost change as the mission advances. Imported models may remain static when no verified animation is available; the game does not require a full character controller or physics simulation.

## No AI Layer

There is no AI/API runtime dependency.

Educational explanations are authored as static game content and triggered by deterministic game events.

```text
MissionState
    ↓
Game Rule / Event
    ↓
Pre-authored Explanation
    ↓
Player
```

---

# 24. Data Integrity Rules

This is critical.

Do NOT claim:

> “NASA says Site A is exactly 83% better.”

unless the source actually supports that statement.

Instead:

```text
NASA Source Data
      ↓
Derived Metric
      ↓
Game Balancing
```

Clearly document the transformation.

For example:

> Illumination values are derived from NASA lunar illumination data and normalized into a gameplay power-generation modifier.

This distinction improves scientific credibility.

---

# 25. Visual/UX Structure

Suggested major screens:

## 1. Title Screen

Peaks of Eternal Light

Subtitle:

**Junior Astronaut Mission Trainer · by TRIARCHY**

Button:

**START MISSION**

---

## 2. Mission Briefing

Introduce:

- Mission objective
- Crew
- Available resources
- Mission duration

---

## 3. Landing Site Selection

Interactive lunar map.

Show:

- Illumination
- Terrain
- Resource potential
- Radiation
- Construction difficulty

---

## 4. Mission Control

Primary gameplay screen.

Major regions:

```text
┌─────────────────────────────────────────────┐
│ TRIARCHY             SOL 03 / 10            │
├─────────────────────────────────────────────┤
│                                             │
│           LUNAR OUTPOST VIEW                │
│                                             │
│       HABITAT       SOLAR ARRAY             │
│           │              │                  │
│         ROVER          CRATER               │
│                                             │
├────────────┬────────────┬───────────────────┤
│ POWER      │ WATER      │ OXYGEN            │
│ 82%        │ 71%        │ 94%               │
├────────────┴────────────┴───────────────────┤
│ ALERT: SOLAR ARRAY 2 UNDERPERFORMING        │
│ [INVESTIGATE] [IGNORE]                     │
└─────────────────────────────────────────────┘
```

---

## 5. Build/Upgrade Interface

Players construct infrastructure and see:

- Cost
- Resource impact
- Expected benefit
- Power requirement
- Construction time

---

## 6. Event Interface

Present decisions clearly.

Do not overload the user with text.

---

## 7. Mission Report

Show the complete outcome.

---

# 26. Accessibility and Junior-Learner Principles

The game should:

- Use readable typography.
- Avoid relying only on color to communicate danger.
- Provide short explanations.
- Use icons with labels.
- Avoid unnecessary technical jargon.
- Allow players to inspect unfamiliar systems.
- Provide warnings before severe consequences.
- Make failure educational rather than frustrating.
- Keep important numbers visible.
- Avoid requiring advanced mathematical knowledge.

---

# 27. Scope Control

The biggest risk is building too much.

The MVP should include:

### Must Have

- Lunar site selection
- NASA-derived data integration
- Power
- Water
- Oxygen
- Food
- Radiation
- Crew
- Rover
- Construction
- Events
- 7–10-sol simulation
- Win/lose conditions
- Mission report
- 3D lunar terrain, lighting, and player-controlled camera
- 3D habitat, solar array, rover, and astronaut representation
- 3D world feedback driven by authoritative simulation state
- Strong visual presentation

### Nice to Have

- Animated rover
- Advanced crew personalities
- Sound effects
- More event types
- More buildings
- Multiple difficulty levels

### Cut if necessary

- Multiplayer
- Full physics simulation
- Complex orbital mechanics
- Real-time multiplayer
- Dozens of buildings
- Detailed biological models
- Full 3D astronaut simulation
- Overly complex AI

A polished smaller game is preferable to a huge unfinished one.

---

# 28. Development Timeline

Assuming development begins around **September 25, 2026** and the internal target is **October 31, 2026**:

## Sept 25–30 — Research & Design

Deliverables:

- Game Design Document
- NASA source inventory
- Data transformation plan
- Simulation rules
- UI wireframes
- Technical architecture
- Art direction

Do not spend excessive time polishing visuals yet.

---

## Oct 1–7 — Simulation Engine

Build:

- MissionState
- Resource systems
- Time/sol progression
- Power calculations
- Water calculations
- Oxygen calculations
- Food calculations
- Radiation calculations
- Crew state
- Rover state
- Failure/success conditions

At the end of this phase, the simulation should work even with a basic UI.

---

## Oct 8–14 — NASA Data + Lunar Environment

Implement:

- Lunar map
- Candidate landing sites
- Terrain data
- Illumination data
- Resource potential
- Radiation data
- Data provenance

---

## Oct 15–21 — Gameplay

Implement:

- Construction
- Upgrades
- Events
- Rover missions
- Objectives
- Mission progression
- Educational explanations

Target:

> **Playable Alpha**

---

## Oct 22–27 — Visual Polish

Implement:

- Cinematic title screen
- Lunar environment
- Mission-control interface
- Animations
- Alerts
- Transitions
- Resource visualization
- Rover/habitat visuals
- Sound design if time permits

Target:

> **Visually impressive playable build**

---

## Oct 28–29 — Playtesting

Test with people who did not build the game.

Observe:

- Confusion
- Boredom
- Difficulty
- UI problems
- Unclear mechanics
- Broken strategies
- Scientific misunderstandings

Fix the highest-impact problems.

---

## Oct 30 — Presentation

Prepare:

- Demo
- Trailer/video
- Screenshots
- Architecture diagram
- NASA data explanation
- Project README
- Pitch

---

## Oct 31 — Submission Build

Freeze the major feature set.

Only fix:

- Critical bugs
- Broken flows
- Submission issues
- Major UX problems

---

# 29. Recommended Repository Structure

A possible structure:

```text
triarchy/
├── README.md
├── docs/
│   ├── PROJECT.md
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── NASA_DATA.md
│   ├── SIMULATION.md
│   └── UI_UX.md
│
├── data/
│   ├── raw/
│   ├── processed/
│   └── metadata/
│
├── src/
│   ├── simulation/
│   │   ├── MissionState
│   │   ├── power
│   │   ├── water
│   │   ├── oxygen
│   │   ├── food
│   │   ├── radiation
│   │   ├── crew
│   │   ├── rover
│   │   └── events
│   │
│   ├── data/
│   ├── components/
│   ├── screens/
│   ├── assets/
│   └── app/
│
├── tests/
│   ├── simulation/
│   └── data/
│
└── public/
```

The exact framework may change, but the separation between simulation logic, data, and presentation should remain.

---

# 30. Rules for AI Coding Agents

Any AI coding agent working on TRIARCHY must follow these principles.

## Rule 1 — Understand before modifying

Before changing architecture or major functionality:

1. Inspect the repository.
2. Read the relevant documentation.
3. Identify existing systems.
4. Avoid rebuilding functionality that already exists.

---

## Rule 2 — Do not invent NASA facts

If a scientific value is required:

- Find the documented source.
- Record the source.
- Explain how it is transformed.
- Distinguish source data from gameplay balancing.

Never fabricate NASA statistics.

---

## Rule 3 — Simulation logic must be deterministic

Given the same:

```text
MissionState
+
PlayerAction
+
Environment
```

the simulation should produce the same result unless an explicitly seeded/random event is being used.

Randomness should be controllable for testing.

---

## Rule 4 — Keep simulation separate from UI

The UI should not contain core resource calculations.

Prefer:

```text
UI
 ↓
Game Action
 ↓
Simulation Engine
 ↓
New MissionState
 ↓
UI Render
```

not:

```text
React Component
 ↓
randomly modifies five resources
```

---

## Rule 5 — Do not over-engineer

This is a hackathon project.

Prioritize:

1. Playability
2. Scientific credibility
3. Visual quality
4. Educational value
5. Reliability

over unnecessary enterprise architecture.

---

## Rule 6 — Preserve existing functionality

Before modifying a working feature:

- Understand it.
- Test it.
- Make the smallest appropriate change.
- Run relevant tests.

---

## Rule 7 — Every major feature needs a test

At minimum, test:

- Resource calculations
- Power deficits
- Water depletion
- Oxygen depletion
- Radiation effects
- Construction costs
- Event outcomes
- Sol progression
- Win conditions
- Failure conditions

---

# 31. Project Identity

## Team Name

# TRIARCHY

**TRIARCHY is the team name, not the name of the game.** The selected game title is **Peaks of Eternal Light**.

The game logo/title should feel like a sophisticated space-mission experience rather than a generic AI-generated startup.

Visual identity:

- Deep space/black backgrounds
- Purple as a major brand color
- Blue and warm amber accents
- Metallic/sci-fi typography
- Three-part emblem/geometry
- Orbital/astronomical motifs
- Premium mission-control feeling

The logo should be usable in:

- Game title
- Website
- GitHub README
- Poster
- Presentation
- Video
- Social media

---

# 32. Project Positioning

The project should be presented as:

> **Peaks of Eternal Light is a NASA-data-driven lunar mission simulator by TRIARCHY, designed to help young learners experience the engineering trade-offs behind sustaining a human outpost beyond Earth.**

Short pitch:

> **Build the base. Balance the systems. Keep humanity alive.**

Alternative tagline:

> **Every decision has a consequence.**

Core pitch:

> **We turned NASA lunar science into a playable mission where students experience firsthand how power, water, food, oxygen, radiation, terrain, and human decisions interact to determine whether an outpost survives.**

---

# 33. What Makes TRIARCHY Different

The project should emphasize four differentiators:

## 1. Real NASA Data

The Moon is not fictional.

## 2. Consequence-Based Learning

Players learn through decisions and outcomes.

## 3. Mission-Level Trade-offs

Systems interact instead of being isolated mini-games.

## 4. Cinematic Presentation

The experience should feel like mission control, not homework.

---

# 34. Definition of Done

The project is ready for submission when:

- [ ] Player can start a mission.
- [ ] Player can select a lunar site.
- [ ] NASA-derived data influences gameplay.
- [ ] Player can construct infrastructure.
- [ ] Power is simulated.
- [ ] Water is simulated.
- [ ] Oxygen is simulated.
- [ ] Food is simulated.
- [ ] Radiation is simulated.
- [ ] Crew state is simulated.
- [ ] Rover is functional.
- [ ] Events create meaningful decisions.
- [ ] Mission advances by sols.
- [ ] Player can win.
- [ ] Player can fail.
- [ ] Game explains important trade-offs.
- [ ] Final mission report is generated.
- [ ] NASA data sources are documented.
- [ ] Scientific assumptions are documented.
- [ ] Core simulation has tests.
- [ ] UI is polished.
- [ ] Game is playable without AI.
- [ ] README explains the project.
- [ ] Demo/presentation is ready.
- [ ] No major known bugs remain.

---

# 35. Final Product Vision

The finished TRIARCHY experience should make a student think:

> “I thought running a Moon base would be easy.”

Then:

> “Oh. If I use more power for food, my batteries drain.”

Then:

> “If I don't build shielding, radiation becomes a problem.”

Then:

> “The best place for sunlight isn't necessarily the best place for resources.”

And finally:

> **“I actually understand why space missions are so difficult.”**

That is the purpose of TRIARCHY.

It is not trying to turn students into aerospace engineers in a single short play session.

It is trying to give them the **intuition of an engineer**.

---

# 36. Guiding Principle

Whenever a feature is proposed, ask:

### Does this create a meaningful decision?

### Does it teach something about real mission engineering?

### Does NASA/open space-agency data meaningfully support it?

### Does it make the game more fun or understandable?

### Can we build and polish it before the deadline?

If the answer is no to most of these questions, the feature should probably be cut.

---

# 37. One-Sentence North Star

> **The game is a cinematic, NASA-data-driven lunar outpost simulation where young learners discover that keeping humans alive on another world is a constant balancing act between science, engineering, resources, and risk.**

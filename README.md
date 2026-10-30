# Peaks of Eternal Light

**Explore the Moon. Command an outpost. Keep your crew alive.**

Peaks of Eternal Light is a 3D lunar exploration and mission-management game built with Godot by **Team TRIARCHY** for the NASA Space Apps Challenge, **“Build a Junior Astronaut Mission Trainer.”**

Take command of a lunar outpost, explore the surface, manage essential resources, and guide a five-person crew through a seven-sol campaign. Every decision introduces an engineering trade-off: power generation, life support, exploration, and crew safety all compete for limited resources.

## Features

- **Lunar landing selection:** Explore an interactive globe and choose between four outpost locations.
- **Surface exploration:** Walk across lunar terrain with first-person and third-person views.
- **Mission management:** Monitor power, water, oxygen, food, radiation exposure, and crew health.
- **Construction planning:** Plan infrastructure as part of your outpost’s development.
- **Crew interactions:** Talk with station crew and follow their activities around the outpost.
- **Remote rover control:** Operate the rover from inside the lander, with headlights, scanning, and sampling tools.
- **Scheduled expeditions:** Complete surface surveys, search for ice evidence, and assist a stranded astronaut.
- **Mission decisions:** Resolve events and review the consequences of your choices.
- **Save and load:** Continue missions using three local save slots.
- **Customizable settings:** Adjust audio, display, mouse sensitivity, and reduced-motion options.

## Rover Expeditions

Operations unlock as the mission progresses:

| Unlock | Operation | Objective |
| --- | --- | --- |
| Sol 2 | Surface Survey | Scan three geological targets and return to the outpost. |
| Sol 4 | Frozen Horizon | Collect three samples and return for analysis. |
| Sol 6 | Lifeline | Locate a stranded astronaut, deliver oxygen, and escort them to extraction. |

Enter the lander and connect to the rover. Drive into the departure circle, stop, and begin the assigned expedition.

## Getting Started

### Requirements

- **Godot 4.7.2**, the version documented for the current expedition campaign.
- A system capable of running Godot’s Compatibility renderer.

### Run the Game

1. Clone or download this repository.
2. Open Godot and select **Import**.
3. Select the repository’s `project.godot` file.
4. Allow Godot to finish importing the assets.
5. Press **F6** to run the currently open scene, or **F5** to launch the full game.

The main entry point is `scenes/startup.tscn`. Use **F5** for the complete startup and landing-selection experience.

## Controls

### Astronaut and Interface

| Input | Action |
| --- | --- |
| W / A / S / D | Move |
| Shift + W | Sprint forward |
| Mouse | Look or orbit the camera |
| Space | Jump |
| E | Talk to crew or enter and exit the lander |
| V | Switch between first-person and third-person views |
| C | Switch front and rear orbit views |
| I | Open the mission dashboard or return |
| Alt | Toggle mission details and cursor access |
| Esc | Pause, go back, or resume |

### Rover

| Input | Action |
| --- | --- |
| R | Connect to or disconnect from remote control |
| W / S | Drive forward or reverse |
| A / D | Steer |
| Space | Brake |
| Mouse | Orbit the rover camera |
| L | Toggle headlights |
| Hold F | Scan a survey target |
| E | Perform a contextual sampling or rescue action |
| Enter | Suspend an expedition and recover the rover to the outpost |

Rover remote control is accessed from inside the lander. Follow the HUD prompts for objective-specific requirements.

### Landing Globe

| Input | Action |
| --- | --- |
| Right-click and drag | Orbit |
| Mouse wheel | Zoom |
| Click a site | Select a landing location |

## Science and Learning

Peaks of Eternal Light teaches mission engineering through decisions and consequences.

Players explore questions such as:

- How should limited power be divided between life support and exploration?
- When is an expedition worth its resource cost?
- How do terrain, sunlight, and resource availability affect site selection?
- How can an outpost balance expansion with crew safety?

The project combines source-backed lunar data with simplified simulation rules and authored gameplay environments. Resource metadata distinguishes measurements, estimates, and game-design values.

Expedition terrain is authored for gameplay. Construction costs, event effects, and other balancing values should not be interpreted as NASA measurements.

See [`Resources/README.md`](Resources/README.md) for data provenance and limitations.

## Project Structure

```text
Peaks-of-Eternal-Light/
├── Assets/                # Models, textures, audio, and visual assets
├── Resources/             # Game data, source metadata, and terrain resources
├── scenes/                # Godot scenes and gameplay entry points
├── src/
│   ├── runtime/           # Mission sessions, saves, settings, and audio
│   ├── simulation/        # Mission and rover simulation logic
│   ├── ui/                # Menus, dashboards, dialogue, and HUDs
│   └── world/             # Terrain, astronauts, rover, and world interactions
├── tests/                 # Simulation, world, UI, and asset checks
├── tools/                 # Asset preparation and development utilities
├── docs/                  # System documentation and gameplay guides
└── project.godot          # Godot project configuration
```

## Development Checks

With the Godot executable available as `godot`, run individual checks from the repository root:

```sh
godot --headless --path . --script tests/simulation/test_mission_simulator.gd
godot --headless --path . --script tests/simulation/test_rover_expedition.gd
godot --headless --path . --script tests/ui/test_game_menu.gd
```

Additional checks are available in `tests/`.

## Documentation

- [Project specification](TRIARCHY_Project_Spec.md)
- [Rover expedition campaign](docs/rover_expeditions.md)
- [Menus, settings, and saves](docs/game_menu.md)
- [Lunar navigation](docs/lunar_navigation.md)
- [Crew dialogue](docs/crew_dialogue.md)
- [Radiation model](docs/radiation_model.md)
- [Resource provenance](Resources/README.md)

The project is under active development. Some older documents describe earlier gameplay iterations; the expedition campaign documentation describes the current rover mission flow.

## Team

Created by **TRIARCHY** for the NASA Space Apps Challenge.

**Game:** Peaks of Eternal Light  
**Challenge:** Build a Junior Astronaut Mission Trainer  
**Engine:** Godot  
**Language:** GDScript  
**Renderer:** Compatibility  

## License

This repository includes the [Apache License 2.0](LICENSE).

Consult asset-specific documentation and source metadata for third-party attribution and licensing.

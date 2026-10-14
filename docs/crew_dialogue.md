# Crew conversations

Approach a station astronaut and press **E**. Click the dialogue's buttons to open
the dashboard or review a relevant pending decision. **Esc**, the close button,
or **End conversation** returns to the outpost. Movement and camera controls are
blocked while a conversation or decision is open.

- Blue: energy specialist, generation/consumption, stored power, depletion risk.
- Cyan: water specialist, reserve, consumption, recovery, water status.
- Green: food specialist, reserve, consumption, food status.
- Purple: crew lead, oxygen, stress, modeled radiation, and all pending decisions.

Reports read the existing mission state. Before mission start, each specialist
introduces their task and offers Start mission. Sol 0 distinguishes initial
inventory from completed-sol readings. Finished missions show their outcome and
offer the report, with no decision actions.

Relevant active effects appear with their remaining duration. Specialist decision
matching uses the event's authored description/effects; the crew lead always lists
all pending decisions. Review decision opens the existing confirmation interface,
which applies choices through the simulator. Conversations themselves spend no
resources and advance no time.

NEW UPDATE appears above a specialist when their displayed report differs from
the last read version. Opening the conversation acknowledges it. New sols and
changed conditions can create another update. Read markers survive save/load and
dashboard visits, and reset when changing sites or restarting the mission. Older
saves without markers remain supported.

These are contextual text conversations; voice audio and free-form chat are not
included. No new task rewards or resource systems are introduced.

Validation: `godot --headless --path . --script tests/ui/test_crew_dialogue.gd`.

# Outpost hover cards

Hover over an outpost in the cinematic selection list or over its visible Moon
label to preview its coordinates and four bars: Sunlight, Ice Prospecting
Potential, Terrain Suitability, and Resource Accessibility. Elevation and slope
remain below the bars. Moving away closes the card. It hides while dragging,
pausing, or transitioning to an outpost and never intercepts clicks.

Values come from `Resources/sites.json`. Sunlight is the modeled first-30-Earth-day
illumination percentage, not a permanent or measured sunlight guarantee. Ratings
use unrounded values: Excellent ≥80%, Good ≥60%, Limited ≥40%, Poor <40%.
Colors are accompanied by text and a percentage.

Terrain guidance is Gentle <5°, Moderate 5–<10°, Steep ≥10°. These are game
categories, not NASA landing-safety classifications. Elevation uses the lunar
reference sphere and slope is derived from LOLA.

Ice Prospecting Potential uses **Possible** for these four study areas, displayed
at the midpoint of the bar. This is a categorical game assessment, not 50% chance,
ice abundance, or evidence of a deposit at the exact landing coordinate.

Terrain Suitability is a game score: `clamp(100 × (1 − slope / 30), 0, 100)`.
Resource Accessibility is the equally weighted average of that terrain score and
modeled sunlight. It estimates favorable operating conditions only; deposit
distance, surveyed travel routes, and extraction feasibility are not available.
Both display `/100`, not percentages, and explicitly say they are game scores.
All scored bars use the same Excellent/Good/Limited/Poor bands. NASA source
records and methodology remain in the source data.

Run `godot --headless --path . --script tests/ui/test_outpost_hover.gd` for rating,
layout, pointer navigation, and transition checks. Run without `--headless` for
visual captures in `/tmp/hover-*.png`.

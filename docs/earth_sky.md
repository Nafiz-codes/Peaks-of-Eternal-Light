# Orbital motion and the lunar sky

Open **Alt → Orbital motion** in an outpost. The default is **3,600×**:
one real second advances one simulated hour. Choose 1×, 60×, 3,600× or
86,400×, or pause the orbital clock. The dialog shows the model date/time.
The game pause menu also freezes orbital motion. The orbital clock is saved
with the mission, persists across scene changes, and resets for a new mission.
Older saves start with the default clock. Time advances while the outpost is
running, not while the game is closed or on the dashboard.

The clock starts at 2026-10-19 00:00:00 UTC. It is separate from mission sols,
resource simulation, astronaut routines and rover physics. Accelerating the
sky does not accelerate those systems. It stops after 20 model years to stay
within the supported planetary element interval.

## Physical model

`src/world/orbital_model.gd` interpolates frozen NASA/JPL Horizons DE441
Sun/Earth vectors sampled every six hours from October 19, 2026 for twenty
years. The table is reconstructed in a lunar body-fixed frame from apparent
azimuth, elevation, and range at 0°N, 0°E; each outpost transforms those vectors
to its local east/up/south sky. Linear interpolation supplies display positions
and directions. Sun range is interpolated separately so six-hour vector chords
do not shorten the range used by the solar model. Lunar orientation and Earth
texture orientation still use analytic models.

| Quantity | Value used |
| --- | --- |
| Moon sidereal rotation / mean orbital longitude period | 27.3217 Earth days |
| Lunar semimajor axis | 384,400 km |
| Lunar eccentricity / orbital inclination | 0.0554 / 5.16° (JPL mean elements) |
| Earth sidereal rotation | 86,164.09054 seconds |
| Earth sidereal year (reference) | 365.25636 days |
| Astronomical unit | 149,597,870.7 km |
| Earth's obliquity | 23.43928° |

The lunar spin axis uses the IAU_MOON orientation series with physical
libration terms. Earth texture orientation remains approximate. Earth stays
near the same place in the sky rather than orbiting the player's horizon every
month. The lunar solar day is approximately 29.53 Earth days, longer than its
spin period because the Earth–Moon system is also moving around the Sun.

The surface scene rides with the Moon in a local east/up/south frame using the
selected site's latitude, longitude and elevation. This avoids moving physics
objects astronomical distances. The sky, Sun disk, Earth's illuminated
hemisphere and terrain shadows update from this frame. Direct sunlight uses the
sampled LOLA horizon, partial solar-disk visibility, geometric Earth occultation,
and date-dependent Sun distance. Array capacity and panel motion are gameplay
adaptations; no claim of mission-grade forecasting is made.

## Sources and limits

- NASA/JPL Horizons DE441 queries: frozen vectors and range values are preserved with request URLs and response headers in `Resources/polar/sources.json`.
- [NAIF generic kernels](https://naif.jpl.nasa.gov/pub/naif/generic_kernels/pck/): IAU lunar orientation model; see `lunar_orientation()` for the series used.
- [NASA LOLA / PGDA product 78](https://pgda.gsfc.nasa.gov/products/78): regional polar DEMs used for local terrain and the derived horizon.

The Sun/Earth positions are sampled numerical ephemerides with linear
interpolation, not a live SPICE integration. Six-hour interpolation is suitable
for this visual and daily-energy use but is not a mission navigation product.
The ephemeris's apparent positions, Earth occultation, and lunar horizon use
different simplified local transforms; leap seconds and UTC-to-TDB conversion
are not modeled. Stars are procedural, not a catalog.

Earth's existing visual distance scale of 0.525 remains: its rendered disk is
about 1.9 times its physical angular size. Physical orbital calculations are
unscaled. The former fixed Tycho elevation and extra radius override have
been removed so its direction follows the same model as every other site.
Ambient fill, the Sun's glare, terrain and cloud textures remain artistic.
The older files in `Resources/earth_ephemeris/`, `earth_ephemeris.json` and
`sun_display.json` remain historical references; they no longer set the live
sky. The active table is `Resources/polar/ephemeris.json`.

## Verification

`tests/world/test_orbital_motion.gd` checks clock speed/pause, save
compatibility, invalid saves, UI input blocking and the model time limit.
`test_polar_ephemeris.gd` compares off-grid local Sun/Earth directions and Sun
ranges to independent direct Horizons queries at all four study sites.
`test_sun_lighting.gd` checks shared direction, shadows and horizon lighting;
`test_earth_lighting.gd` renders the production shader to check Earth phases.

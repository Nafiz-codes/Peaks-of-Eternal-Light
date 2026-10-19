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

`src/world/orbital_model.gd` solves Kepler's equation for elliptical orbits.
Positions are in kilometers, time in Earth days, and angles in the J2000
ecliptic frame. The Earth–Moon barycenter follows the JPL Earth/EM barycenter
orbit around the Sun. Earth's position includes its motion around that
barycenter. The Moon's heliocentric position is Earth's position plus the
Earth-to-Moon vector; it therefore travels around both Earth and the Sun.

| Quantity | Value used |
| --- | --- |
| Moon sidereal rotation / mean orbital longitude period | 27.3217 Earth days |
| Lunar semimajor axis | 384,400 km |
| Lunar eccentricity / orbital inclination | 0.0554 / 5.16° (JPL mean elements) |
| Earth sidereal rotation | 86,164.09054 seconds |
| Earth sidereal year (reference) | 365.25636 days |
| Astronomical unit | 149,597,870.7 km |
| Earth's obliquity | 23.43928° |

The actual solar orbit uses JPL's time-varying mean elements rather than
forcing a circle with the reference year. Lunar node and periapsis precession
use the JPL mean periods. The lunar spin axis uses an approximate Cassini-state
orientation, tilted 1.54° from the ecliptic normal. Mean synchronous spin and
nonuniform orbital speed produce optical libration. Earth stays near the same
place in the sky rather than orbiting the player's horizon every month.
The lunar solar day is approximately 29.53 Earth days, longer than its spin
period because the Earth–Moon system is also moving around the Sun.

The surface scene rides with the Moon in a local east/up/south frame using the
selected site's latitude, longitude and elevation. This avoids moving physics
objects astronomical distances. The sky, Earth texture orientation, Sun disk,
Earth's illuminated hemisphere and terrain shadows update from this frame.
Direct sunlight fades at sunrise/sunset and switches off below the horizon.
Earth's texture uses an approximate J2000 sidereal phase and rotates with Earth.

## Sources and limits

- [JPL approximate planetary positions](https://ssd.jpl.nasa.gov/planets/approx_pos.html): Earth/EM barycenter elements, 1800–2050 fit, and Kepler method.
- [JPL satellite mean elements](https://ssd.jpl.nasa.gov/sats/elem/sep.html): Moon J2000 elements and precession periods.
- [JPL astronomical parameters](https://ssd.jpl.nasa.gov/astro_par.html): AU, rotation/year periods and Earth/Moon gravitational parameters.
- [NASA Moon fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/moonfact.html): synchronous spin period, radius and obliquity.
- [NASA Earth fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/earthfact.html) and [Sun fact sheet](https://nssdc.gsfc.nasa.gov/planetary/factsheet/sunfact.html): radii and rotational properties.

These are real physical rates in an **approximate analytic model**, not a
precision numerical ephemeris. No new NASA datasets were analyzed. Lunar
perturbations, physical libration, nutation, light travel time, detailed
orientation models, eclipses and relativistic time conversions are omitted.
UTC labels provide a gameplay clock; leap seconds and UTC-to-TDB conversion
are not modeled. Stars are procedural, not a catalog.

Earth's existing visual distance scale of 0.525 remains: its rendered disk is
about 1.9 times its physical angular size. Physical orbital calculations are
unscaled. The former fixed Tycho elevation and extra radius override have
been removed so its direction follows the same model as every other site.
Ambient fill, the Sun's glare, terrain and cloud textures remain artistic.
The frozen files in `Resources/earth_ephemeris/`, `earth_ephemeris.json` and
`sun_display.json` remain historical references; they no longer set the live
sky. Their dates must not be interpreted as the current orbital clock.

## Verification

`tests/world/test_orbital_motion.gd` checks Kepler residuals, annual motion,
spin rates, lunar distances, inherited heliocentric motion, tidal locking,
clock speed/pause, save compatibility, invalid saves, UI input blocking and
the model time limit. `test_sun_lighting.gd` checks shared direction, shadows
and horizon lighting at all four outposts. `test_earth_lighting.gd` renders
the production shader to check left/right/full/dark Earth illumination.

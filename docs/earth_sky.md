# Earth from the lunar surface

The outpost uses a frozen NASA/JPL Horizons DE441 observer ephemeris for
2026-10-05 00:00 UTC (06:00 Asia/Dhaka). It is not a live ephemeris and does not
advance with mission sols. The date is explicit because there is no single
constant, exact Earth–Moon distance.

`Resources/earth_ephemeris.json` contains the distance from each surface observer
to Earth's center, apparent azimuth/elevation, and apparent equatorial angular
diameter. Each observer uses the selected site's sourced latitude, east-positive
longitude, and LOLA elevation above the 1737.4 km lunar reference sphere.
Horizons' lunar reference sphere makes geodetic and planetocentric latitude
equivalent here. Original responses and their precision/model notes are in
`Resources/earth_ephemeris/`. Reproduce with
`python3 tools/prepare_earth_ephemeris.py` (requires network access).

The shader ray-intersects a sphere of equatorial radius 6378.137 km at the
site-specific distance multiplied by 0.525, a requested visual adjustment that
brings Earth 25% closer, then another 30% closer. Its diameter is about 90% larger
than the physical view, and about 43% larger than the previous adjustment. The original
NASA data stays intact. Its rendered apparent diameter is calculated by geometry,
`2 * asin(radius / distance)`, rather than an artistic size control. Calculations
are normalized by distance to retain float precision. The sky pass avoids
extending the terrain camera's far plane to hundreds of millions of meters;
this represents the physical distance and size without a far-away scene mesh.
Camera position is converted from scene meters to kilometers for parallax.
Godot +X is east, +Y is local zenith, and -Z is north.

At Tranquility Base the apparent center distance is 370344.6032 km, azimuth and
elevation come from Horizons, and the physical diameter is about 1.97361 degrees.
The visual adjustment renders it at about 194431 km with a diameter of about 3.76 degrees. At
Tsiolkovskiy the center is below the local horizon, so ground occludes Earth.
Terrain may also obscure Earth at other locations.

Surface, cloud, gloss, and night textures come from the uploaded ZIP. Sun
direction is taken from the same observer/date. Earth is represented as a sphere
rather than an oblate ellipsoid. Continent orientation, cloud pattern, atmosphere,
and detailed lighting remain visual approximations; they are not satellite
imagery for the chosen date. Site coordinate and terrain sampling precision also
limit accuracy. The lunar terrain lighting retains its existing gameplay setup.

Sources:
- https://ssd-api.jpl.nasa.gov/doc/horizons.html
- https://ssd.jpl.nasa.gov/horizons/manual.html (quantities 4, 13, 20)
- https://science.nasa.gov/moon/facts/ (384400 km is an average, not this epoch)

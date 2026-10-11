# Tycho elevation

`tycho_sldem2015_source.zip` is the original user-supplied USGS Map-a-Planet
export, job 7ea45731cccbb0bffecc7027a1f9cce9 (2026-10-10).
It contains the SLDEM2015 LOLA/Kaguya elevation GeoTIFF and processing metadata.

The TIFF is 4 columns by 2 rows, signed Int16, scale 0.5 meters and offset 0.
Raw rows are `[-32768, -2152, -2139, -2136]` and
`[-32768, -2127, -2108, -2101]`. The first column is invalid and excluded.
The remaining six heights are decoded in `src/world/tycho_elevation.gd`.
Pixel spacing is 59.2252938 projected meters, with upper-left pixel edge
(10573017.899764, -1315038.4235352), in lunar equirectangular coordinates
with center latitude/longitude 0 and radius 1737400 meters.

Runtime sampling uses pixel centers, bilinear interpolation, and clamps to
valid sample centers outside their coverage. Local +X points east, -Z north.
Height is relative to the interpolated outpost center. The original 12 m
level pad is expanded to 32 m and blends into the DEM by 48 m radius so the landing
assets and spawn remain grounded. This is a gameplay adaptation, not an
unaltered scientific reconstruction. Beyond the 120 m square, measured edge
heights blend into the existing illustrative horizon by 220 m.

The elevation raster supplies broad relief only, not photographic color or fine ground
detail. The collision mesh is
built from the resulting terrain. Other outposts retain procedural terrain.

## Surface imagery

`tycho_wac_source.zip` preserves user-supplied MAP2 job
1d5243d4f6877fbb2bac0e7cabf3f4fa. `tycho_wac.png` is its unmodified 2 x 2
LROC-WAC morphology mosaic crop (100 m projected pixel spacing). Only the
bottom-right pixel is valid: opaque RGB (174,174,174). The other three pixels
are transparent NoData. This crop is retained as a source artifact but is no
longer applied. The reference-inspired `src/world/regolith.gdshader` now supplies
gray-brown dust, multiscale grit, embedded gravel shading and irregular shallow
crater rims. It uses world-space meters so ground and horizon join continuously.
Surface-gradient normals respond to scene lighting; detail fades with distance.
These small features are shading, not additional collision geometry or surveyed
elevations. The level equipment pad and elevation terrain are unchanged.

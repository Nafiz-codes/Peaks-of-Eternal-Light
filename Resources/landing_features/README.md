# Supplied landing coordinates

The four original shapefile components are preserved unchanged here. Their PRJ
uses angular degrees and a spherical lunar radius of 1,737,400 meters. SHP X is
east-positive longitude; SHP Y contains **positive** latitudes.

The user explicitly confirmed that these points belong to the named south-pole
sites and that the latitude values are missing minus signs. Accordingly,
`Resources/sites.json` uses `-abs(source latitude)` and the supplied longitude.
Features are matched by DBF `label`, never file order. The original positive
values are retained in `coordinates.json` for auditability.

Re-extract: `python tools/inspect_landing_features.py`
Reapply confirmed correction: `python tools/inspect_landing_features.py --apply-south`
No third-party Python dependencies are needed. All four components are read:
SHX offsets identify SHP records, DBF supplies site labels, and PRJ supplies units.

The globe uses these angular coordinates on its unchanged 10-unit sphere.
Post bases are embedded 0.002 units to meet the tessellated surface. On-screen
labels are spread apart for readability; their leader endpoints use the exact
projected geographic coordinates and hide on the opposite hemisphere. The
initial camera faces the south pole so the cluster appears on the Moon's disc.
Existing environmental samples are retained; this import only updates locations.

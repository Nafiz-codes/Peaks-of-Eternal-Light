# Radiation model

## Baseline

The simulation starts from **0.90 mSv per sol**. This is NASA's modeled effective dose for an unshielded lunar surface during the 2009 solar-minimum environment: Table 8.4-2 of NASA/TM-20220002905.

CRaTER measures galactic and solar cosmic radiation behind tissue-equivalent plastic and provides the mission's observational radiation context. It does not provide a site-level surface-dose raster for these four locations. The baseline is therefore site independent and is not labeled as a geographic CRaTER reading.

## Terrain factor

LOLA elevation and slope are source measurements. The resulting terrain factor is a transparent gameplay proxy, bounded to 0–20%, rather than a claim that LOLA measures radiation shielding:

```text
depth = clamp(-elevation_m / 2500, 0, 1)
slope = clamp(slope_deg / 30, 0, 1)
terrain_shielding = clamp(depth * 0.12 + slope * 0.08, 0, 0.20)
radiation_this_sol = 0.90 * (1 - terrain_shielding)
```

Depressions and steep terrain can lower visible sky in this simplified model. Built regolith shielding and solar-particle events are separate systems and will be integrated later.

## Sources

- NASA NESC, [NASA/TM-20220002905](https://ntrs.nasa.gov/api/citations/20220002905/downloads/NESC-RP-20-01589_NASA-TM-20220002905final.pdf), Table 8.4-2.
- NASA LRO, [Science and Data](https://science.nasa.gov/mission/lro/science-and-data/), CRaTER description.
- NASA GSFC PGDA, [High-Resolution LOLA Topography for Lunar South Pole Sites](https://pgda.gsfc.nasa.gov/products/78).

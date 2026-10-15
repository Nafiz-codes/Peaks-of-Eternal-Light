# TRIARCHY resource data

The JSON contracts in this folder drive the game. Each field carries its own provenance status. In `sites.json` revision `2026-10-15`, coordinates and NASA LOLA elevation/slope samples are source-backed; illumination is an ideal-horizon gameplay estimate; a global Lunar Prospector-derived bulk-hydrogen map is identified, but its grid has not yet been sampled at the four site coordinates. `bvad_constants.json` also labels remaining model choices individually.

## Updating source-backed values

1. Find the record in `data_sources.json` and open the linked NASA or NASA PDS source.
2. Record the exact product/version, coordinates or table/page reference, units, and retrieval date in the field's `source` and `date_read` metadata.
3. Replace only that field’s value and set `verified` to `true` only when it is a source-backed measurement with complete provenance. Mark derived estimates and unavailable coverage explicitly; do not turn those into source measurements.
4. Keep the source measurement separate from any normalized or balanced gameplay value. For the global hydrogen map, preserve its roughly 50 km effective spatial footprint and approximately 10 ppm systematic uncertainty; it does not support landing-pad-scale claims.

## Global hydrogen map import (pending)

The cited JHU/APL repository's Version 1 data file is `figure6.txt` (file ID `16635`, reported 10.6 MB, MD5 `ed174cc5b25857e6c88f6d9d815922c5`): <https://archive.data.jhu.edu/api/access/datafile/16635>. The repository metadata lists the file as public under CC BY 4.0. The repository is based on NASA Lunar Prospector observations but contains a published derived map, not a direct NASA archive product. On 2026-10-15 the metadata was readable, but the local direct API request returned a Cloudflare access-block page and browser capture timed out; no data bytes were retrieved and the file is not present in this checkout. Do not enter site estimates until a complete file is obtained and its MD5 verified. Then preserve the original under `Resources/source_data/figure6.txt`, document its grid layout and units, and sample the cells/footprints covering each site in `sites.json`, retaining the map's effective spatial scale and systematic uncertainty. The archive page says download via URL is preferred; if the API keeps blocking the local route, obtain an approved copy through an ordinary authorized transfer and verify its MD5. Do not treat a challenge page as data.

An older NASA PDS Geosciences special-product grid is now present at `Resources/source_data/hydrogenhd.txt` (14,256,401 bytes; MD5 `7e747df203c320828c644408bb6112ec`). Its 259,200 rows contain 0.5° × 0.5° cells and hydrogen estimates in ppm by weight. The site-bin samples are in `Resources/source_data/lunar_prospector_legacy_samples.json`. The PDS documentation says the product is not a peer-reviewed PDS archive, warns values may be unreliable in high-thorium/rare-earth regions, and supplies no per-cell standard deviations. Two of these four raw samples are negative. They are kept only as a historical comparison; `sites.json` continues to leave current site hydrogen unavailable until the newer global map is sampled and the science team limitations are resolved.

`construction.json`, `crew.json`, and most event effects contain game-design values. They must remain labeled as gameplay content rather than NASA measurements.

The source registry is a refreshable snapshot: source products may be revised, so check their landing pages before a release and commit every data refresh with its provenance.

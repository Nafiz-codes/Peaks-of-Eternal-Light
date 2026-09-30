# TRIARCHY resource data

The JSON contracts in this folder drive the game. Each field carries its own provenance status. In `sites.json`, elevation and slope are sampled from NASA LOLA global products, illumination is an ideal-horizon gameplay estimate, and LEND hydrogen is unavailable at the selected nonpolar coordinates. `bvad_constants.json` also labels remaining model choices individually.

## Updating source-backed values

1. Find the record in `data_sources.json` and open the linked NASA or NASA PDS source.
2. Record the exact product/version, coordinates or table/page reference, units, and retrieval date in the field's `source` and `date_read` metadata.
3. Replace only that field’s value and set `verified` to `true` only when it is a source-backed measurement with complete provenance. Mark derived estimates and unavailable coverage explicitly; do not turn those into source measurements.
4. Keep the source measurement separate from any normalized or balanced gameplay value.

`construction.json`, `crew.json`, and most event effects contain game-design values. They must remain labeled as gameplay content rather than NASA measurements.

The source registry is a refreshable snapshot: source products may be revised, so check their landing pages before a release and commit every data refresh with its provenance.

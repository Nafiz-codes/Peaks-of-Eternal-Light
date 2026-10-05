"""Freeze NASA/JPL Horizons apparent Earth geometry at every landing site."""
import csv
import json
from pathlib import Path
import urllib.parse
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
EPOCH = "2026-10-05 00:00"
API = "https://ssd.jpl.nasa.gov/api/horizons.api"
AU_KM = 149597870.700


def query(site, target, quantities):
    coords = site["coordinates"]
    altitude = site["elevation_m"]["value"] / 1000.0
    parameters = dict(
        format="json", COMMAND=f"'{target}'", CENTER="'coord@301'",
        COORD_TYPE="'GEODETIC'",
        SITE_COORD=f"'{coords['longitude_deg']},{coords['latitude_deg']},{altitude}'",
        START_TIME=f"'{EPOCH}'", STOP_TIME="'2026-10-05 00:01'",
        STEP_SIZE="'1 m'", QUANTITIES=f"'{quantities}'",
        CSV_FORMAT="'YES'", EXTRA_PREC="'YES'",
    )
    url = API + "?" + urllib.parse.urlencode(parameters)
    with urllib.request.urlopen(url, timeout=60) as response:
        result = json.load(response)
    if "error" in result or "$$SOE" not in result.get("result", ""):
        raise RuntimeError(result)
    raw = result["result"]
    row = next(csv.reader(raw.split("$$SOE")[1].split("$$EOE")[0].strip().splitlines()))
    return url, raw, row


def main():
    output = ROOT / "Resources" / "earth_ephemeris"
    output.mkdir(exist_ok=True)
    data = dict(epoch_utc="2026-10-05T00:00:00Z", source="NASA/JPL Horizons, DE441",
                source_url=API, earth_equatorial_radius_km=6378.137,
                world_axes="+X east, +Y zenith, -Z north", sites={})
    for site in json.loads((ROOT / "Resources/sites.json").read_text())["sites"]:
        url, raw, row = query(site, 399, "4,13,20")
        (output / (site["site_id"] + "_earth.txt")).write_text(raw)
        sun_url, sun_raw, sun = query(site, 10, "4")
        (output / (site["site_id"] + "_sun.txt")).write_text(sun_raw)
        entry = dict(azimuth_deg=float(row[3]), elevation_deg=float(row[4]),
                     angular_diameter_deg=float(row[5]) / 3600.0,
                     observer_to_earth_center_km=float(row[6]) * AU_KM,
                     sun_azimuth_deg=float(sun[3]), sun_elevation_deg=float(sun[4]),
                     observer_coordinates=site["coordinates"], observer_altitude_km=site["elevation_m"]["value"] / 1000.0,
                     request_url=url, sun_request_url=sun_url)
        data["sites"][site["site_id"]] = entry
        print(site["site_id"], entry["observer_to_earth_center_km"], entry["elevation_deg"], entry["angular_diameter_deg"])
    (ROOT / "Resources/earth_ephemeris.json").write_text(json.dumps(data, indent=2) + "\n")


if __name__ == "__main__":
    main()

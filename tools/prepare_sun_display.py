"""Select real NASA daylight Sun snapshots for decorative outpost skies."""
import csv
import json
from datetime import datetime
from pathlib import Path
from urllib.parse import urlencode
from urllib.request import urlopen

ROOT = Path(__file__).resolve().parents[1]
API = 'https://ssd.jpl.nasa.gov/api/horizons.api'


def main():
    output = ROOT / 'Resources/sun_display'
    output.mkdir(exist_ok=True)
    document = dict(source='NASA/JPL Horizons', target_id=10,
                    purpose='Decorative daylight snapshots, independent of Earth epoch and mission time',
                    selection='First hourly sample on or after 2026-10-05 with elevation >= 20 degrees',
                    sites={})
    for site in json.loads((ROOT / 'Resources/sites.json').read_text())['sites']:
        coordinates = site['coordinates']
        parameters = dict(format='json', COMMAND="'10'", CENTER="'coord@301'",
                          COORD_TYPE="'GEODETIC'",
                          SITE_COORD=f"'{coordinates['longitude_deg']},{coordinates['latitude_deg']},{site['elevation_m']['value'] / 1000}'",
                          START_TIME="'2026-10-05 00:00'", STOP_TIME="'2026-11-05 00:00'",
                          STEP_SIZE="'1 h'", QUANTITIES="'4,13,20'", CSV_FORMAT="'YES'", EXTRA_PREC="'YES'")
        url = API + '?' + urlencode(parameters)
        with urlopen(url, timeout=60) as response:
            result = json.load(response)
        raw = result.get('result', '')
        if 'error' in result or '$$SOE' not in raw:
            raise RuntimeError(result)
        rows = csv.reader(raw.split('$$SOE')[1].split('$$EOE')[0].strip().splitlines())
        row = next(row for row in rows if float(row[4]) >= 20.0)
        epoch = datetime.strptime(row[0].strip(), '%Y-%b-%d %H:%M').isoformat() + 'Z'
        document['sites'][site['site_id']] = dict(
            epoch_utc=epoch, azimuth_deg=float(row[3]), elevation_deg=float(row[4]),
            angular_diameter_deg=float(row[5]) / 3600,
            observer_to_sun_center_km=float(row[6]) * 149597870.7,
            request_url=url, observer_coordinates=coordinates,
            observer_altitude_km=site['elevation_m']['value'] / 1000)
        (output / (site['site_id'] + '.txt')).write_text(raw)
        print(site['site_id'], epoch, row[3:6], flush=True)
    (ROOT / 'Resources/sun_display.json').write_text(json.dumps(document, indent=2) + '\n')


if __name__ == '__main__':
    main()

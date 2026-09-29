"""Inspect the supplied point shapefile without assuming a latitude-sign correction.
Uses SHX record offsets, SHP point geometry, DBF names, and the lunar PRJ.
"""
import json
import struct
from pathlib import Path

root = Path(__file__).resolve().parents[1]
folder = root / 'Resources' / 'landing_features'
shp = (folder / 'my-features.shp').read_bytes()
shx = (folder / 'my-features.shx').read_bytes()
dbf = (folder / 'my-features.dbf').read_bytes()
prj = (folder / 'my-features.prj').read_text(encoding='utf-8').strip()
assert '1737400' in prj and 'UNIT["degree"' in prj
assert struct.unpack_from('<i', shp, 32)[0] == 1
count, header, row_size = struct.unpack_from('<IHH', dbf, 4)
assert count == (len(shx) - 100) // 8
fields = []
for offset in range(32, header - 1, 32):
    fields.append((dbf[offset:offset+11].split(b'\0')[0].decode('ascii'), dbf[offset+16]))
features = []
for index in range(count):
    offset, length = struct.unpack_from('>ii', shx, 100 + index * 8)
    number, shp_length = struct.unpack_from('>ii', shp, offset * 2)
    assert length == shp_length and number == index + 1
    shape_type, longitude, latitude = struct.unpack_from('<idd', shp, offset * 2 + 8)
    assert shape_type == 1 and -90 <= latitude <= 90
    row = dbf[header + index * row_size:header + (index + 1) * row_size]
    assert row[0:1] == b' '
    attributes = {}
    start = 1
    for name, size in fields:
        attributes[name] = row[start:start + size].decode('ascii').strip(' \0')
        start += size
    features.append({'name': attributes['label'], 'latitude_deg': latitude,
                     'longitude_deg': longitude, 'source_feature_id': attributes['FID']})
result = {'projection_wkt': prj, 'latitude_convention': 'Positive means north; no sign correction applied.', 'features': features}
(folder / 'coordinates.json').write_text(json.dumps(result, indent=2) + '\n', encoding='utf-8')
print(json.dumps(result, indent=2))

# Applying the south-pole correction requires an explicit command-line choice.
import argparse
import re
parser = argparse.ArgumentParser()
parser.add_argument('--apply-south', action='store_true', help='Apply the user-confirmed missing-minus-sign correction.')
args = parser.parse_args()
if args.apply_south:
    sites_path = root / 'Resources' / 'sites.json'
    source_text = sites_path.read_text(encoding='utf-8')
    sites = json.loads(source_text)['sites']
    by_name = {feature['name']: feature for feature in features}
    assert set(by_name) == {site['name'] for site in sites}
    for site in sites:
        feature = by_name[site['name']]
        coordinates = {
            'latitude_deg': -abs(feature['latitude_deg']),
            'longitude_deg': feature['longitude_deg'] % 360,
            'source': 'User-provided my-features.shp/.shx/.dbf/.prj, feature ' + feature['source_feature_id'] +
                      '; lunar sphere radius 1737400 m; X=east longitude, Y=latitude in degrees. '
                      'User confirmed that positive source latitudes are missing minus signs; interpreted as south.'
        }
        pattern = r'("site_id":\s*"' + re.escape(site['site_id']) + r'"[\s\S]*?"coordinates":\s*)\{[^}]*\}'
        source_text, count = re.subn(pattern, lambda match: match.group(1) + json.dumps(coordinates), source_text, count=1)
        assert count == 1
    sites_path.write_text(source_text, encoding='utf-8', newline='\n')
    print('Applied all four named points with the user-confirmed south-pole latitude sign.')

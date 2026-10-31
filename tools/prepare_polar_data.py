"""Reproducible NASA south-pole inputs. Run with Python, NumPy and Pillow.

Downloads public NASA products into .tools/polar_sources, preserves request URLs
and hashes, and writes compact runtime data. Never labels modeled values as
observations. Coordinates are notional study sites, not approved landing pads.
"""
import csv
import hashlib
import json
import math
from pathlib import Path
import urllib.parse
import urllib.request
import subprocess
from concurrent.futures import ThreadPoolExecutor

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / '.tools/polar_sources'
OUT = ROOT / 'Resources/polar'
RADIUS = 1737400.0
START = '2026-10-19'
STOP = '2046-10-19'
COORD_SOURCE = 'https://ntrs.nasa.gov/api/citations/20205008303/downloads/AIAA_ASCEND2020_Kleinhenz_presentation_final.pdf'
SITES = [
    ('ridge_a', 'Connecting Ridge (Study Site 001)', -89.45, 222.69, 'Artemis 001'),
    ('shadow_zone', 'ISRU Ridge 1', -89.56, 214.73, 'ISRU Ridge 1'),
    ('crater_rim_b', 'Shackleton Rim (Study Site 004)', -89.78, 204.27, 'Artemis 004'),
    ('plateau_d', 'ISRU Ridge 4', -89.69, 197.05, 'ISRU Ridge 4'),
]

def download(url, name):
    CACHE.mkdir(parents=True, exist_ok=True)
    path = CACHE / name
    if not path.exists():
        print('Downloading', name, flush=True)
        partial = path.with_suffix(path.suffix + '.part')
        # Windows curl uses the system trust store, including the local network
        # proxy's CA. Keep certificate verification enabled.
        subprocess.run(['curl.exe', '--fail', '--location', '--max-time', '180',
                        '--silent', '--show-error', '--output', str(partial), url], check=True)
        partial.replace(path)
        print('Downloaded', name, path.stat().st_size, flush=True)
    return path

def ephemeris(target):
    params = dict(format='json', COMMAND=f"'{target}'", CENTER="'coord@301'",
                  COORD_TYPE="'GEODETIC'", SITE_COORD="'0,0,0'",
                  START_TIME=f"'{START}'", STOP_TIME=f"'{STOP}'", STEP_SIZE="'6 h'",
                  QUANTITIES="'4,20'", RANGE_UNITS="'KM'", SUPPRESS_RANGE_RATE="'YES'",
                  CSV_FORMAT="'YES'", EXTRA_PREC="'YES'", APPARENT="'AIRLESS'")
    url = 'https://ssd.jpl.nasa.gov/api/horizons.api?' + urllib.parse.urlencode(params)
    path = download(url, f'horizons_{target}.json')
    raw = json.loads(path.read_text())['result']
    if '$$SOE' not in raw:
        raise ValueError(raw)
    rows = list(csv.reader(raw.split('$$SOE')[1].split('$$EOE')[0].strip().splitlines()))
    vectors, distances = [], []
    for row in rows:
        az, el, distance = math.radians(float(row[3])), math.radians(float(row[4])), float(row[5])
        # At 0N,0E: zenith=body X, east=body Y, north=body Z.
        vectors.append([round(distance * math.sin(el) + RADIUS / 1000, 6),
                        round(distance * math.cos(el) * math.sin(az), 6),
                        round(distance * math.cos(el) * math.cos(az), 6)])
        distances.append(float(row[5]))
    assert len(vectors) == 29221, len(vectors)
    print('Horizons', target, len(vectors), flush=True)
    return vectors, distances, dict(url=url, sha256=hashlib.sha256(path.read_bytes()).hexdigest(),
                         header=raw.split('$$SOE')[0])

def prepare_sites():
    rasters = []
    for name in ['Site01', 'Site04']:
        with Image.open(CACHE / (name + '.tif')) as im:
            rasters.append((name, np.array(im), im.tag_v2[33922][3], im.tag_v2[33922][4]))

    def sample(x, y):
        x, y = np.broadcast_arrays(x, y)
        result = np.full(x.shape, np.nan)
        for name, grid, left, top in rasters:
            col, row = (x-left)/5-0.5, (top-y)/5-0.5
            valid = (col >= 0) & (row >= 0) & (col < grid.shape[1]-1) & (row < grid.shape[0]-1)
            c, r = np.clip(col.astype(int), 0, grid.shape[1]-2), np.clip(row.astype(int), 0, grid.shape[0]-2)
            u, v = col-c, row-r
            z = grid[r,c]*(1-u)*(1-v)+grid[r,c+1]*u*(1-v)+grid[r+1,c]*(1-u)*v+grid[r+1,c+1]*u*v
            result = np.where(valid & np.isfinite(z), z, result)
        return result

    doc = json.loads((ROOT/'Resources/sites.json').read_text())
    doc['_meta'] = dict(description='Four south-polar notional sites from NASA 2020 ISRU study, slide 6. NASA LOLA elevation, derived slope/local horizon, JPL Horizons sunlight. No guaranteed ice deposit.', dataset_revision='2026-10-31-polar', frozen_on='2026-10-31', freeze_scope='Preserve coordinates and provenance; regenerate with tools/prepare_polar_data.py.')
    for site, (site_id, name, lat, lon, table_name) in zip(doc['sites'], SITES):
        assert site['site_id'] == site_id
        la, lo = np.radians(lat), np.radians(lon)
        rho = 2 * RADIUS * np.tan(np.pi/4 + la/2)
        x0, y0 = rho*np.sin(lo), rho*np.cos(lo)
        height = float(sample(x0,y0))
        assert np.isfinite(height), name
        dx = float(sample(x0+5,y0)-sample(x0-5,y0))/10
        dy = float(sample(x0,y0+5)-sample(x0,y0-5))/10
        slope = math.degrees(math.atan(math.hypot(dx,dy)))
        # Body-fixed local frame. All horizon angles are derived from NASA DEM
        # pixels, accounting for curvature and a 1.5-m observer height.
        up = np.array([np.cos(la)*np.cos(lo), np.cos(la)*np.sin(lo), np.sin(la)])
        east = np.array([-np.sin(lo), np.cos(lo), 0])
        north = np.cross(up, east)
        origin = up*(RADIUS+height+1.5)
        horizon = np.full(720, -90.0)
        reach = np.zeros(720)
        for _, grid, left, top in rasters:
            # 10-m terrain sampling, 0.5-degree azimuth bins; small-scale shadows
            # from equipment/rocks are left to the renderer, not this site model.
            z = grid[::2,::2].astype(float)
            xx, yy = np.meshgrid(left+(np.arange(z.shape[1])*2+0.5)*5,
                                 top-(np.arange(z.shape[0])*2+0.5)*5)
            rr = np.hypot(xx,yy)
            latitude = 2*np.arctan(rr/(2*RADIUS))-np.pi/2
            longitude = np.arctan2(xx,yy)
            xyz = np.stack([(RADIUS+z)*np.cos(latitude)*np.cos(longitude),
                            (RADIUS+z)*np.cos(latitude)*np.sin(longitude),
                            (RADIUS+z)*np.sin(latitude)],axis=-1)-origin
            e, n, u = xyz@east, xyz@north, xyz@up
            distance = np.hypot(e,n)
            valid = np.isfinite(z) & (distance >= 30)
            az = (np.degrees(np.arctan2(e,n))%360/0.5).astype(int)%720
            elev = np.degrees(np.arctan2(u,distance))
            np.maximum.at(horizon,az[valid],elev[valid])
            np.maximum.at(reach,az[valid],distance[valid])
        assert np.all(reach > 2000), (name, reach.min())
        # Unknown terrain beyond the DEM is not claimed to be clear. A level
        # horizon floor is the explicit fallback; ridge maxima remain intact.
        horizon = np.maximum(0,horizon)
        site.update(name=name, description=f'{table_name}: notional south-polar location in NASA’s 2020 ISRU case study. Not an approved landing pad. Nearby shadowed terrain motivates prospecting; recoverable ice is unconfirmed.', terrain_model='polar_lola', solar_model_revision='2026-10-31-polar')
        site['coordinates'] = dict(latitude_deg=lat, longitude_deg=lon, coordinate_frame='Planetocentric latitude; east-positive longitude 0–360 degrees', verified=True, source_id='nasa_isru_polar_sites_2020', source=f'NASA GRC/JSC Kleinhenz & Paz (2020), Case Study for Lunar ISRU Systems Utilizing Polar Water, slide 6, {table_name}. {COORD_SOURCE}', date_read='2026-10-31')
        base = dict(source_id='nasa_lola_polar_pgda78', source='NASA LRO LOLA / Barker et al. 2021, PGDA product 78; Site01 and Site04 5-m DEMs, USGS COG distribution. https://pgda.gsfc.nasa.gov/products/78', date_read='2026-10-31', resolution_m=5, vertical_datum='1737400 m reference sphere', sample_projected_xy_m=[round(x0,3),round(y0,3)])
        site['elevation_m'] = dict(base, value=round(height,3), verified=True, status_label='NASA LOLA interpolated elevation', sample_method='Bilinear interpolation at published study coordinate; south polar stereographic, lon_0=0, lat_0=-90, R=1737400 m')
        site['slope_deg'] = dict(base, value=round(slope,3), verified=False, status_label='Derived from NASA LOLA', sample_method='Central elevation differences over 10-m baseline; derived slope, not a sampled slope product')
        site['horizon'] = dict(elevation_deg=np.round(horizon,4).tolist(), azimuth_step_deg=0.5, observer_height_m=1.5, minimum_coverage_m=round(float(reach.min()),1), maximum_coverage_m=round(float(reach.max()),1), source_id='nasa_lola_polar_pgda78', method='Derived local horizon from 10-m sampled DEM, curvature included; maximum per 0.5-degree azimuth bin. Zero-degree floor. Distant terrain beyond regional coverage and DEM uncertainties omitted; not a mission-grade illumination forecast.')
        site['hydrogen_ppm'] = dict(available=False, verified=False, availability_note='No measured local ice abundance', source='A notional ISRU study site is not evidence of an extractable deposit. Local sampling and confirmation are required.', date_read='2026-10-31')
        site['illumination_pct'] = dict(value=0.0, verified=False, status_label='Modeled first 30 Earth days', source='Computed from NASA/JPL Horizons geometry and a local NASA LOLA-derived terrain horizon, starting 2026-10-19 UTC. Regenerated by tools/update_polar_illumination.gd. Not constant sunlight or a measured NASA illumination percentage.', date_read='2026-10-31')
        # Compact terrain patch in the gameplay east/south frame. Local landing
        # pad flattening occurs at runtime, leaving the source heights untouched.
        axis = np.arange(-2500,2501,20,dtype=float)
        ee, ss = np.meshgrid(axis,axis)
        xyz = origin + ee[...,None]*east - ss[...,None]*north
        norms = np.linalg.norm(xyz,axis=-1)
        lat_grid = np.arcsin(xyz[...,2]/norms)
        lon_grid = np.arctan2(xyz[...,1],xyz[...,0])
        rr = 2*RADIUS*np.tan(np.pi/4+lat_grid/2)
        zz = sample(rr*np.sin(lon_grid),rr*np.cos(lon_grid))-height
        assert np.isfinite(zz).all(), name
        (OUT/(site_id+'_terrain.json')).write_text(json.dumps(dict(size=len(axis),step_m=20,origin_m=-2500,height_m=np.round(zz,3).ravel().tolist()),separators=(',',':'))+'\n')
        print(name, lat, lon, 'elevation',round(height,2),'slope',round(slope,2),'horizon',round(float(horizon.min()),2),round(float(horizon.max()),2),flush=True)
    (ROOT/'Resources/sites.json').write_text(json.dumps(doc,indent=2,ensure_ascii=False)+'\n',encoding='utf-8')

def main():
    OUT.mkdir(parents=True, exist_ok=True)
    with ThreadPoolExecutor(max_workers=3) as pool:
        sun = pool.submit(ephemeris, 10)
        earth = pool.submit(ephemeris, 399)
        dems = []
        for site in ['Site01', 'Site04']:
            url = f'https://astrogeo-ard.s3.us-west-2.amazonaws.com/moon/lro/lola/barker_south_pole_dems/{site}/{site}.tif'
            dems.append((site, url, pool.submit(download, url, site + '.tif')))
        sun_vectors, sun_distances, sun_source = sun.result()
        earth_vectors, earth_distances, earth_source = earth.result()
        (OUT / 'ephemeris.json').write_text(json.dumps(dict(
            start_utc=START+'T00:00:00', step_seconds=21600, duration_seconds=7305*86400,
            frame='Lunar body-fixed, reconstructed from airless Horizons observer azimuth/elevation/range at 0N 0E; apparent positions; linear interpolation',
            sun=sun_vectors, earth=earth_vectors, sun_distance_km=sun_distances,
            earth_distance_km=earth_distances), separators=(',', ':'))+'\n')
        sources = dict(coordinates=dict(url=COORD_SOURCE, page=6, note='Notional 2020 ISRU study coordinates; not approved landing pads'), sun=sun_source, earth=earth_source, dems=[])
        for site, url, future in dems:
            path = future.result()
            sources['dems'].append(dict(site=site, url=url, sha256=hashlib.sha256(path.read_bytes()).hexdigest()))
        (OUT / 'sources.json').write_text(json.dumps(sources, indent=2)+'\n')
    prepare_sites()

if __name__ == '__main__':
    main()

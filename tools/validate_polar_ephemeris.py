"""Fetch independent topocentric Horizons checks at the actual polar sites.
Off-grid times test the six-hour table interpolation and local-frame conversion.
"""
import csv
import json
import urllib.parse
from concurrent.futures import ThreadPoolExecutor
from datetime import datetime
from prepare_polar_data import ROOT, OUT, download

def check_site(site):
    c = site['coordinates']
    result = dict(site_id=site['site_id'], coordinates=c, samples=[])
    for target in [10,399]:
        params = dict(format='json',COMMAND=f"'{target}'",CENTER="'coord@301'",COORD_TYPE="'GEODETIC'",
            SITE_COORD=f"'{c['longitude_deg']},{c['latitude_deg']},{site['elevation_m']['value']/1000}'",
            START_TIME="'2026-10-19 03:00'",STOP_TIME="'2027-10-19 03:00'",STEP_SIZE="'30 d'",
            QUANTITIES="'4,20'",RANGE_UNITS="'KM'",SUPPRESS_RANGE_RATE="'YES'",CSV_FORMAT="'YES'",EXTRA_PREC="'YES'")
        url='https://ssd.jpl.nasa.gov/api/horizons.api?'+urllib.parse.urlencode(params)
        path=download(url,f"validation_{site['site_id']}_{target}.json")
        raw=json.loads(path.read_text())['result']
        for row in csv.reader(raw.split('$$SOE')[1].split('$$EOE')[0].strip().splitlines()):
            time=datetime.strptime(row[0].strip(),'%Y-%b-%d %H:%M')
            result['samples'].append(dict(target=target,elapsed_seconds=(time-datetime(2026,10,19)).total_seconds(),azimuth_deg=float(row[3]),elevation_deg=float(row[4]),distance_km=float(row[5])))
        result[str(target)+'_url']=url
    return result

if __name__=='__main__':
    sites=json.loads((ROOT/'Resources/sites.json').read_text())['sites']
    with ThreadPoolExecutor(max_workers=2) as pool:
        values=list(pool.map(check_site,sites))
    (OUT/'validation.json').write_text(json.dumps(dict(source='NASA/JPL Horizons DE441; independent direct queries at each polar site, off table grid',sites=values),indent=2)+'\n')
    print('Wrote independent polar ephemeris validation fixtures.')

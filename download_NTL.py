import ee, requests
from pathlib import Path
from datetime import date,timedelta

ee.Initialize(project='ee-hannahlaihiuwan821')

cities = {
    'Shanghai': (120.9,30.9,122.1,31.7),
    'Guangzhou': (112.9,22.9,113.8,23.6),
    'Shenzhen': (113.7,22.4,114.7,22.9),
    'Chengdu': (103.7,30.3,104.6,31.0),
    'Hangzhou': (119.8,29.9,120.7,30.6),
    'Los_Angeles': (-118.95,33.7,-117.6,34.5),
    'Phoenix': (-112.5,33.1,-111.8,33.8),
    'Houston': (-95.9,29.4,-94.9,30.2),
    'Miami': (-80.5,25.5,-80.0,26.0),
    'Las_Vegas': (-115.4,35.9,-114.9,36.4)
}

root = Path('/Users/hannahlai821/Desktop/geoprog_submit/black_marble')
collection = ee.ImageCollection('NASA/VIIRS/002/VNP46A2')
band = 'Gap_Filled_DNB_BRDF_Corrected_NTL'

d = date(2019,12,1)
end = date(2019,12,31)

while d <= end:
    d1 = d.strftime('%Y-%m-%d')
    d2 = (d + timedelta(days=1)).strftime('%Y-%m-%d')
    ymd = d.strftime('%Y%m%d')

    daycol = collection.filterDate(d1,d2)

    if daycol.size().getInfo() == 0:
        print(f'No collection image for {ymd}')
        d += timedelta(days=1)
        continue

    base_img = daycol.first().select(band)

    for city, (xmin,ymin,xmax,ymax) in cities.items():
        folder = root / city
        folder.mkdir(parents=True,exist_ok=True)

        region = ee.Geometry.Rectangle([xmin,ymin,xmax,ymax])
        img = base_img.clip(region)

        url = img.getDownloadURL({
            'region': region,
            'scale': 500,
            'crs': 'EPSG:4326',
            'format': 'GEO_TIFF'
        })

        r = requests.get(url, timeout=120)
        r.raise_for_status()

        out = folder / f'{city}_{ymd}.tif'
        out.write_bytes(r.content)
        print(f'Saved: {out}')

    d += timedelta(days=1)
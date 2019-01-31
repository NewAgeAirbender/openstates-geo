#! /usr/bin/env python3

import requests
import us


# The Census download URLs are case-sensitive
URL = 'https://www2.census.gov/geo/tiger/TIGER2018/SLD{chamber_uppercase}/tl_2018_{fips}_sld{chamber}.zip'

for state in us.STATES + [us.states.PR]:
    print("Fetching shapefiles for {}".format(state.name))
    for chamber in ['l', 'u']:
        fips = state.fips
        download_url = URL.format(fips=fips, chamber=chamber, chamber_uppercase=chamber.upper())
        data = requests.get(download_url).content
        with open('./data/tl_2018_{fips}_sld{chamber}.zip'.format(fips=fips, chamber=chamber), 'wb') as f:
            f.write(data)

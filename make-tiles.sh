#!/usr/bin/env bash

set -e

mkdir -p data

echo "Download and unzip TIGER/Line shapefiles"
./get-all-sld-shapefiles.py

echo "Additional shapefiles, such as New Hampshire floterials and DC at-large, should be downloaded here in the future"

# Occasionally, the TIGER/Line website may not have properly
# served all the files, in which case the process should error
# out noisily and be re-tried
total="$(find ./data/tl_*.shp | wc -l | xargs)"
if (( total != 102 )); then
	echo "Found an incorrect number of shapefiles (${total} instead of 102)" 1>&2
	exit 1
fi

echo "Download the national boundary for clipping, and the OCD IDs"
curl --silent --output ./data/cb_2017_us_nation_5m.zip https://www2.census.gov/geo/tiger/GENZ2017/shp/cb_2017_us_nation_5m.zip
unzip -q -o -d ./data ./data/cb_2017_us_nation_5m.zip
curl --silent --output ./data/sldu-ocdid.csv https://raw.githubusercontent.com/opencivicdata/ocd-division-ids/master/identifiers/country-us/census_autogenerated_14/us_sldu.csv
curl --silent --output ./data/sldl-ocdid.csv https://raw.githubusercontent.com/opencivicdata/ocd-division-ids/master/identifiers/country-us/census_autogenerated_14/us_sldl.csv

echo "Convert to GeoJSON, clip boundaries to shoreline, and join OCD jurisdiction IDs"
count=0
for f in ./data/tl_*.shp; do
	# OGR's GeoJSON driver cannot overwrite files, so make sure
	# to clear the output GeoJSONs from previous runs
	# The `{f%.*}` syntax removes the extension of the filename
	rm -f "${f%.*}.geojson"

	# Water-only placeholder "districts" end in `ZZZ`
	# Also, convert to the spatial projection (CRS:84, equivalent
	# to EPSG:4326) that is expected by tippecanoe
	ogr2ogr \
		-clipsrc ./data/cb_2017_us_nation_5m.shp \
		-where "GEOID NOT LIKE '%ZZZ'" \
		-t_srs crs:84 \
		-f GeoJSON \
		"${f%.*}.geojson" \
		"$f"

	./join-ocd-division-ids.py "${f%.*}.geojson"

	((++count))
	echo -e "${count} of ${total} shapefiles processed"
done

echo "Combine all GeoJSON files into a MBTiles file for serving"
tippecanoe \
	--layer sld \
	--minimum-zoom 2 --maximum-zoom 13 \
	--detect-shared-borders \
	--simplification 10 \
	--force --output ./data/sld.mbtiles \
	./data/*-with-ocdids.geojson

if [ -z ${MAPBOX_ACCOUNT+x} ] || [ -z ${MAPBOX_ACCESS_TOKEN+x} ] ; then
	echo "Skipping upload step; MAPBOX_ACCOUNT and/or MAPBOX_ACCESS_TOKEN not set in environment"
else
	echo "Upload the MBTiles to Mapbox, for serving"
	mapbox upload "${MAPBOX_ACCOUNT}.sld" ./data/sld.mbtiles
fi

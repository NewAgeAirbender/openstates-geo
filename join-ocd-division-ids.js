#! /usr/bin/env node

const fs = require('fs')
const geojsonStream = require('geojson-stream')
const parse = require('d3-dsv').csvParse
const us = require('us')

const GEOJSON = './data/sld.geojson'
const SLDU_CSV = './data/sldu-ocdid.csv'
const SLDL_CSV = './data/sldl-ocdid.csv'
const OUTPUT = './data/sld-with-ocdid.geojson'

const sldu = parse(fs.readFileSync(SLDU_CSV, 'utf-8'))
const sldl = parse(fs.readFileSync(SLDL_CSV, 'utf-8'))

const parser = geojsonStream.parse()

const writer = fs.createWriteStream(OUTPUT)
writer.write('{ "type": "FeatureCollection", "features": [\n')

// Need to stream, since the filesize of the combined
// SLDs is too large for Node's maximum memory
let first = true
fs.createReadStream(GEOJSON)
  .pipe(parser)
  .on('data', f => {
    const type = f.properties.MTFCC === 'G5210' ? 'sldu' : 'sldl'
    const geoid = `${type}-${f.properties.GEOID}`

    const slduId = sldu.find(d => d.census_geoid_14 === geoid)
    const sldlId = sldl.find(d => d.census_geoid_14 === geoid)
    const ocdid = slduId
      ? slduId.id
      : sldlId ? sldlId.id : null

    // Parsing an OCD ID to determine structured data is bad practice,
    // so add a standalone state postal abbreviation
    const state = us.STATES_AND_TERRITORIES.find(
      s => s.fips === f.properties.STATEFP
    ).abbr.toLowerCase()

    f.properties = { ocdid, type, state }

    if (first) {
      first = false
    } else {
      writer.write('\n,\n')
    }
    writer.write(JSON.stringify(f))
  })
  .on('end', () => {
    writer.end(']}')
  })

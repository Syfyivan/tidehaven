"""Import pinned TMX data without altering source pixels; standard library only."""
import concurrent.futures
import argparse
import hashlib
import json
import time
from pathlib import Path
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET

COMMIT = '0c31854d40fcc1f6b60b35ac07b7c9686b82b226'
ROOT = Path(__file__).resolve().parents[1] / 'assets/vendor/stardew-island'
BASE = f'https://raw.githubusercontent.com/ffffhx/stardew-valley-assets/{COMMIT}/'
MAPS = ['Town', 'Farm', 'Beach', 'Mountain', 'BusStop']


def fetch(source, destination):
    if not destination.exists():
        destination.parent.mkdir(parents=True, exist_ok=True)
        request = urllib.request.Request(BASE + urllib.parse.quote(source), headers={'User-Agent': 'Tidehaven-asset-import'})
        for attempt in range(3):
            try:
                with urllib.request.urlopen(request, timeout=35) as response:
                    payload = response.read()
                destination.write_bytes(payload)
                break
            except (OSError, TimeoutError):
                if attempt == 2:
                    raise
                time.sleep(1)
    return {'source': source, 'file': destination.relative_to(ROOT).as_posix(),
            'sha256': hashlib.sha256(destination.read_bytes()).hexdigest()}


def properties(node):
    return {p.attrib['name']: p.attrib.get('value', p.text or '') for p in node.findall('./properties/property')}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--interiors', action='store_true')
    args = parser.parse_args()
    selected = ['Hospital', 'SeedShop', 'ScienceHouse', 'BathHouse_Pool', 'Blacksmith', 'FishShop', 'ManorHouse', 'AnimalShop', 'Saloon', 'Greenhouse', 'SamHouse', 'Trailer', 'Mines/1', 'Mines/2', 'Mines/3'] if args.interiors else MAPS
    manifest = []
    maps = {}
    images = set()
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        list(pool.map(lambda name: fetch(f'assets/Maps/{name}.tmx', ROOT / 'maps' / f'{name}.tmx'), selected))
    for name in selected:
        path = ROOT / 'maps' / f'{name}.tmx'
        manifest.append(fetch(f'assets/Maps/{name}.tmx', path))
        xml = ET.parse(path).getroot()
        tilesets = []
        for sheet in xml.findall('tileset'):
            image = sheet.find('image')
            source = image.attrib['source'].removesuffix('.png')
            if name.startswith('Mines/') and source == 'mine':
                source = 'Mines/mine'
            images.add(source)
            if source.startswith('spring_'):
                images.update(source.replace('spring_', season + '_', 1) for season in ['summer', 'fall', 'winter'])
            tilesets.append({'first': int(sheet.attrib['firstgid']), 'source': source,
                             'columns': int(image.attrib['width']) // 16,
                             'properties': {tile.attrib['id']: properties(tile) for tile in sheet.findall('tile')},
                             'animations': {tile.attrib['id']: [dict(frame.attrib) for frame in tile.findall('animation/frame')]
                                            for tile in sheet.findall('tile') if tile.find('animation') is not None}})
        layers = []
        for layer in xml.findall('layer'):
            data = layer.find('data')
            if data.attrib.get('encoding') != 'csv':
                raise ValueError('Unsupported TMX encoding')
            cells = [int(value) for value in data.text.replace('\n', '').split(',') if value.strip()]
            if len(cells) != int(xml.attrib['width']) * int(xml.attrib['height']):
                raise ValueError('Incomplete map layer')
            layers.append({'name': layer.attrib['name'], 'cells': cells})
        maps[name] = {'width': int(xml.attrib['width']), 'height': int(xml.attrib['height']),
                      'tilesets': tilesets, 'layers': layers, 'properties': properties(xml)}
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures = [pool.submit(fetch, 'assets/Maps/' + name + '.png', ROOT / (name + '.png')) for name in sorted(images)]
        for future in futures:
            manifest.append(future.result())
    output = 'interiors' if args.interiors else 'maps'
    (ROOT / f'maps/{output}.json').write_text(json.dumps(maps, separators=(',', ':')), encoding='utf-8')
    (ROOT / ('maps/interiors-manifest.json' if args.interiors else 'maps/manifest.json')).write_text(json.dumps({'commit': COMMIT, 'files': manifest}, indent=2), encoding='utf-8')
    print(f'IMPORTED {len(maps)} maps, {len(images)} atlas images; source hashes preserved')


if __name__ == '__main__':
    main()

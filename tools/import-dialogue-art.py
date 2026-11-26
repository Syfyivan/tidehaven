"""Restore pinned native menu and matching resident portraits; no pixel edits."""
import concurrent.futures
import importlib.util
import json
import struct
from pathlib import Path

spec = importlib.util.spec_from_file_location('island_import', Path(__file__).with_name('import-island-maps.py'))
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
NAMES = ['Alex', 'Leah', 'Maru', 'Emily', 'Elliott', 'Penny', 'Sam', 'Linus', 'Kent',
         'Lewis', 'Caroline', 'Harvey', 'Gus', 'Robin', 'Clint', 'Willy', 'Marnie', 'Evelyn']
jobs = [(f'assets/Portraits/{name}.png', source.ROOT / 'portraits' / f'{name}.png') for name in NAMES]
jobs += [('assets/Maps/MenuTiles.png', source.ROOT / 'ui/MenuTiles.png'),
         ('assets/LooseSprites/Cursors.png', source.ROOT / 'ui/Cursors.png')]

def fetch(job):
    entry = source.fetch(*job)
    payload = job[1].read_bytes()
    if payload[:8] != b'\x89PNG\r\n\x1a\n':
        raise ValueError(f'Not a PNG: {job[0]}')
    entry.update(bytes=len(payload), canvas=list(struct.unpack('>II', payload[16:24])))
    return entry

with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
    files = list(pool.map(fetch, jobs))
(source.ROOT / 'dialogue-manifest.json').write_text(
    json.dumps({'commit': source.COMMIT, 'files': files}, indent=2), encoding='utf-8')
print(f'Verified {len(files)} untouched native menu/portrait PNGs')

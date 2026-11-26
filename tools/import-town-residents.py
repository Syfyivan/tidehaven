"""Fetch complete pinned character sheets and greenhouse exterior; no image edits."""
import importlib.util
import json
import struct
from pathlib import Path
spec = importlib.util.spec_from_file_location('island_import', Path(__file__).with_name('import-island-maps.py'))
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
files = []
for name in ['Elliott', 'Penny', 'Sam', 'Linus', 'Kent', 'Alex', 'Leah', 'Maru', 'Emily']:
    destination = source.ROOT / 'characters' / f'{name}.png'
    entry = source.fetch(f'assets/Characters/{name}.png', destination)
    payload = destination.read_bytes()
    entry.update(bytes=len(payload), canvas=list(struct.unpack('>II', payload[16:24])))
    files.append(entry)
files.append(source.fetch('assets/Buildings/Greenhouse.png', source.ROOT / 'Greenhouse.png'))
(source.ROOT / 'residents-manifest.json').write_text(json.dumps({'commit':source.COMMIT,'files':files},indent=2),encoding='utf-8')
print('Verified nine complete resident sources and greenhouse exterior')

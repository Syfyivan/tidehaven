"""Import pinned original ocean/forest NPC sheets, unchanged; no new dependencies."""
import importlib.util
import json
from pathlib import Path

spec = importlib.util.spec_from_file_location("island_import", Path(__file__).with_name("import-island-maps.py"))
source = importlib.util.module_from_spec(spec)
spec.loader.exec_module(source)
files = []
for remote, local in [
    ("assets/Animals/turtle.png", "turtle.png"),
    ("assets/Characters/Junimo.png", "Junimo.png"),
    ("assets/Characters/SeaMonsterKrobus.png", "SeaMonsterKrobus.png"),
    ("assets/Maps/mermaid_house_tiles.png", "mermaid_house_tiles.png"),
    ("assets/Maps/pirates_tilesheet.png", "pirates_tilesheet.png"),
]:
    files.append(source.fetch(remote, source.ROOT / "ocean-residents" / local))
(source.ROOT / "ocean-residents" / "manifest.json").write_text(
    json.dumps({"commit": source.COMMIT, "files": files}, indent=2), encoding="utf-8"
)
print("Imported five pinned original NPC/environment sheets")

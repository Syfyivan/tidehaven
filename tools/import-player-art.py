"""Restore original, pinned farmer layers; Python standard library only.

The runtime composes the original layers. This importer never paints or rescales PNGs.
"""
import hashlib
import json
from pathlib import Path
import urllib.request

ROOT = Path(__file__).resolve().parents[1]
COMMIT = "0c31854d40fcc1f6b60b35ac07b7c9686b82b226"
REPOSITORY = "ffffhx/stardew-valley-assets"
FILES = ["farmer_base.png", "farmer_girl_base.png", "hairstyles.png",
         "shirts.png", "pants.png", "skinColors.png", "shoeColors.png"]


def main():
    tree_file = ROOT / "artifacts/p1-source-tree.json"
    if tree_file.exists():
        tree = json.loads(tree_file.read_text(encoding="utf-8"))
    else:
        url = f"https://api.github.com/repos/{REPOSITORY}/git/trees/{COMMIT}?recursive=1"
        with urllib.request.urlopen(url, timeout=45) as response:
            tree = json.load(response)
    if tree.get("sha") != COMMIT or tree.get("truncated"):
        raise ValueError("Expected the complete pinned repository tree")
    entries = {entry["path"]: entry for entry in tree["tree"]}
    destination = ROOT / "assets/vendor/stardew-island/player"
    destination.mkdir(parents=True, exist_ok=True)
    manifest = {"repository": REPOSITORY, "commit": COMMIT, "files": {}}
    for name in FILES:
        source = f"assets/Characters/Farmer/{name}"
        entry = entries[source]
        path = destination / name
        data = path.read_bytes() if path.exists() else b""
        blob = lambda value: hashlib.sha1(b"blob " + str(len(value)).encode() + b"\0" + value).hexdigest()
        if blob(data) != entry["sha"]:
            url = f"https://raw.githubusercontent.com/{REPOSITORY}/{COMMIT}/{source}"
            with urllib.request.urlopen(url, timeout=45) as response:
                data = response.read()
            if blob(data) != entry["sha"]:
                raise ValueError(f"Pinned Git blob mismatch: {source}")
            path.write_bytes(data)
        manifest["files"][name] = {"source": source, "git_blob": entry["sha"],
            "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)}
        print(f"verified {name}: {len(data)} bytes")
    (destination / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()

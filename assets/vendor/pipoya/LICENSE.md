# PIPOYA character sprites — source and usage notice

Creator: Pipoya. Official pack: [PIPOYA FREE RPG Character Sprites 32x32](https://pipoya.itch.io/pipoya-free-rpg-character-sprites-32x32).

Downloaded from the creator's free itch.io download on 2026-10-04. The official page permits personal and commercial production, including modifications, but prohibits redistributing or reselling the assets themselves. These are not CC0 assets. Keep this notice with project source; distribute the characters as part of the game, not as an asset pack. The original download contains PNG files without a separate license document; this file records the official page's terms in summary, not a replacement license.

Only two unchanged files are used locally; their raw PNGs are excluded from Git:

- `Male-02-1.png` = `Male/Male 02-1.png`
- `Female-02-1.png` = `Female/Female 02-1.png`

Archive: `PIPOYA FREE RPG Character Sprites 32x32.zip`, upload dated 2021-08-04.
Archive SHA256: `902DD6F9022DA851AF8510C0A7A19FA9A06C38D1201C23D86723D8D5A1F75C33`.

After cloning, obtain this archive directly from the official page and run `tools/setup-characters.ps1 -ArchivePath <downloaded-zip>` from the project root. The importer verifies both reviewed images before writing and refuses to overwrite modified local files. Do not commit the restored PNGs or original archive.

All original PNG pixels are preserved. Atlas frame selection, scale, and diving equipment are runtime composition in Tidehaven. No image-generation or bitmap-editing service was used on these assets.

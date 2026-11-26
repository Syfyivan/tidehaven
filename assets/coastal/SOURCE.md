# Coastal props · 0.10.3

Generated for Tidehaven using the built-in image_gen tool on 2026-10-12. These are newly generated project assets, not Stardew Valley / Raft extracted sprites, not vendor PNG edits, and not claimed to be hand-painted artwork. No purchase, new dependency or external asset license was introduced.

The eleven source PNGs are retained unmodified, including generated transparency. [PROMPTS.md](PROMPTS.md) records every selected prompt and the rejected long sleeping-bag draft; [SHA256SUMS.txt](SHA256SUMS.txt) identifies the copied sources. The final sleeping-bag revision and framed-bed edit share the cream pillow / ochre fold / teal quilt design. The open chest was generated as an edit of the closed chest.

Production display uses fixed source regions in scripts/coastal_art.gd, nearest-neighbour resampling to a 24–36 pixel wide logical grid, binary display alpha and the existing material-edge treatment. This avoids scaling a large semi-transparent draft directly into each scene. These operations never write over a source PNG. ArtCatalog supplies one cached presented texture to the world, bag, recipe and placement preview.

| File | Logical display grid | World use / state |
|---|---|---|
| bedroll.png | 32×46 | Flat sleeping bag on raft and island camp |
| bed.png | 32×58 | Framed single bed |
| chest.png | 32×20 | Closed storage chest and treasure chest |
| chest_open.png | 32×27 | Open storage chest and searched seabed chest |
| barrel.png | 28×36 | Salvage barrel, return buoy |
| purifier.png | 36×37 | Idle purifier; timer, steam and collected water remain real scene state |
| grill.png | 36×24 | Grill and existing kitchen; flames/output remain real scene state |
| wood.png | 32×24 | Plank material on water/land, bag and recipes |
| leaf.png | 24×33 | Fallen frond material, bag and recipes |
| plastic.png | 24×29 | Plastic bottle salvage, bag and recipes |
| scrap.png | 28×23 | Scrap sheet material, bag and recipes |

Style / view review: warm cedar, muted teal metal/fabric, cream highlights, top-down/front-facing RPG props. Sleeping bag and bed extend north/south, with separate world-size budgets. Chest states preserve base width and ground contact. Generated details are evaluated at actual game scale; user acceptance of the earlier UI does not imply acceptance of this new artwork.

Known scope limits: tools/food/fish, furnace, planting-box growth art, trees, terrain and most underwater/environment artwork still use previous sources. Kitchen still shares grill artwork. A dedicated side-view seabed chest and complete swimmer animations are not delivered by this prop batch. See the authoritative art checklist and TODO.

# Shared prop palette, 0.7

## Scope and cause

Inspected the actual packed Tiny Town, Tiny Dungeon and Tiny Farm PNGs, all eleven selected Yapi icons, the atlas rectangles selected in `art_catalog.gd`, and their world/inventory/crafting callers. The thick dark rims are opaque near-black pixels baked into these assets, magnified by nearest-neighbour drawing. A UI-panel colour change cannot remove them.

`ArtCatalog.texture(key)` is the single cached presentation exit; `item_icon(key)` calls it. It extracts each atlas region before processing, never samples adjacent sprites, never changes opacity or sprite dimensions, and never writes an edited asset to disk. Dark outer contours become material-coloured edges, borrowing local lit colours rather than painting all objects grey. Enclosed furnace chambers and open-chest interiors retain a darker tone. Highlights remain unchanged. Yapi's creator-supplied 32px icons are sampled at their native two-pixel pitch, preserving the original 16px design blocks.

The palette anchors are wood `#987958`, linen `#9c9981`, metal `#81928b`, stone `#939489`, foliage `#7f9461`, ceramic `#aa9980`, water `#709d9f`, food `#aa8663`. These are fallbacks blended with actual neighbouring colours; they are not flat tints. The catalogue treatment guarantees an unmodulated opaque outer-edge luma floor of 0.40 and an internal dark-pixel floor of 0.31. Scene tints may deliberately lower final displayed brightness; actual underwater and processing scenes still need visual inspection.

Characters use `CharacterArt.texture()` directly and are excluded. All vendor files and original license documents are unchanged. The sources and redistribution conditions are recorded in [sources.md](sources.md).

## Complete catalog

`ArtCatalog.keys() -> Array[String]` returns these 47 unique keys in sorted order. `ArtCatalog.source_texture(key)` exposes the current source before palette treatment for a side-by-side gallery. Source access is for inspection; world and UI should continue using `texture` or `item_icon`.

| Source | Keys |
|---|---|
| Yapi original PNGs, 32×32 | `wood`, `plastic`, `scrap`, `rope`, `stone`, `ingot`, `fish`, `seed`, `veg`, `meal`, `hammer` |
| Kenney Tiny Dungeon atlas | `bed`, `chest`, `chest_open`, `treasure`, `grill`, `kitchen`, `fire` |
| Kenney Tiny Town atlas | `purifier`, `hatch`, `orders`, `coin`, `tree` |
| Kenney Tiny Farm atlas | `barrel`, `garden`, `garden_empty`, `garden_growing`, `plant`, `seaweed`, `rock` |
| Existing original project pixel grids | `leaf`, `paddle`, `anchor`, `ore`, `fins`, `reinforced_hook`, `furnace`, `cup`, `saltwater`, `freshwater`, `rod`, `cooked_fish` |
| Existing hook grid, basic rope/metal palette | `hook` |
| New original runtime wood-board illustration, 32×32 | `floor`, `floor_alt`, `foundation` |
| New original runtime linen/green sleeping-bag grid, 16×24 | `bedroll` |

Historical region entries shadowed by a current PNG or code texture do not add a second runtime source. Unknown keys still return `null`. Every valid key, including aliases, goes through the same treatment.

## State coverage and integration

| Visible state | Catalog artwork / composition |
|---|---|
| Drifting supplies, hooked cargo, bag slots, recipe costs | Shared `wood`, `leaf`, `plastic`, `scrap`, `barrel` |
| Shared storage / open storage | `chest` / `chest_open` |
| Unopened treasure and underwater salvage / depleted wreck | `treasure` / `chest_open`; underwater scene adds substrate and tint |
| Initial sleeping bag / crafted bed | Distinct `bedroll` / `bed` |
| Empty planter / sprout / harvest-ready plant | `garden_empty` / `garden_growing` / `garden` |
| Empty / seawater / freshwater cup | `cup` / `saltwater` / `freshwater` share one vessel silhouette |
| Idle purifier / working / finished | `purifier`; existing runtime steam/progress; `freshwater` only when complete |
| Idle grill or old kitchen / working / finished | `grill` or `kitchen`; `fire`; `cooked_fish` or `meal` only when complete |
| Idle furnace / working / finished | `furnace`; `fire`; `ingot` only when complete |
| Old migrated facilities | `bed`, `kitchen`, `orders`, `hatch` |
| Underwater stone / ore / fish / equipment | `stone`, `ore`, `fish`, `fins`, `reinforced_hook` |
| Boat steering / deployed anchor / rod / flying hook | `paddle`, `anchor`, `rod`, `hook` |
| Floor recipe / foundation preview | `floor`, `floor_alt`, `foundation`; actual scene remains original staggered planks |
| Scenery plants, rocks, seaweed, return buoy | `plant`, `rock`, `seaweed`, `barrel` |

The world view now preserves the separate bed and bedroll keys, with 30x52 and 30x45 sizes. Depleted underwater chests use a lighter desaturated tint. The HUD hook uses Art.item_icon, and the island's whole tree uses Tiny Town Rect2(64,0,16,32) through the same catalog and foliage treatment. Original vendor PNGs and accepted character files remain unchanged.

Validation: 421 texture/alpha/edge/cache/source checks, the full catalog render, and 43 real scene/UI fixture screenshots. See docs/verification.md for the final input, normal progression, networking and release evidence; visual fixtures are not evidence of earned player progress.
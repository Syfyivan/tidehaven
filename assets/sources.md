# Tidehaven artwork sources

## Source repository distribution

The Git repository retains the Kenney and Yapi runtime images and their license records. Original download archives remain local and are Git-ignored. The two PIPOYA character PNGs also remain local because their author prohibits redistribution of raw assets; obtain the pack from its official page and restore them using `tools/setup-characters.ps1` as described in the README. No accepted in-game artwork is replaced by this source packaging step.

## 0.7 shared prop presentation

All 46 keys exposed by `ArtCatalog.keys()` now pass through one cached runtime treatment in `scripts/prop_art.gd`. The three Kenney atlases and all eleven Yapi PNGs were visually inspected. Their near-black contour pixels caused the dark rims, especially when enlarged in the world. The treatment preserves the original alpha and dimensions, draws contour colour from nearby lit pixels and the object's wood, linen, metal, stone, foliage, ceramic, water or food palette, and keeps enclosed recesses darker than outer edges. Both `texture()` and `item_icon()` return this same result. Vendor PNGs remain unchanged; no derived PNG, dependency, image-generation service or offline image editor is introduced.

Two small original code-native illustrations replace unrelated atlas crops: `floor`, `floor_alt` and the `foundation` alias show warm staggered wooden boards matching the actual raft; `bedroll` shows an unframed linen pillow and green sleeping bag, distinct from the existing `bed` sprite. The basic `hook` now reuses the project's existing hook grid with a simpler rope/metal palette rather than the old representational Tiny Town tool. The accepted PIPOYA character entry point remains separate and receives no palette treatment.

The complete key/source/state checklist, colours and rendering contract are in [prop-palette.md](prop-palette.md). This describes the implemented catalog, not a claim of completed screenshot or player acceptance. Later source sections record the historical introduction of the reused assets; their statements about original display colours and the barn-wall recipe illustration are superseded by this section.

## 0.6 materials — Yapi and project pixel grids

On 2026-10-04, selected 11 unchanged PNGs from [100 assorted items (16x16 pixel)](https://yapilol.itch.io/100-assorted-items-16x16-pixel) by Yapi / yapilol. The official page explicitly lists **Creative Commons Zero v1.0 Universal** and declares **No generative AI was used**. [CC0 1.0](https://creativecommons.org/publicdomain/zero/1.0/) permits commercial use and redistribution; attribution is retained voluntarily. This permission does not replace the separate Pipoya character license below.

The official free download was `100 assorted items - yapilol.itch.io.7z`, upload `8370029`, 49,583 bytes. Its SHA256 is `d3ddc97685b5766c964ddecd8086a57110f07f1a300535acd5802d7898949367`. [Source and retrieval record](vendor/material-pack-yapi/SOURCE.md), [full CC0 legal text](vendor/material-pack-yapi/CC0-1.0.txt), [archive and individual hashes](vendor/material-pack-yapi/SHA256SUMS.txt) are preserved with the original archive. The 11 runtime files come from the archive's `32x32/` directory; they are the creator-provided 32-pixel versions of 16-pixel designs, copied without image editing. They are individual PNGs rather than an atlas sheet.

| Game key | Original PNG in `material-pack-yapi/icons/` | Depiction |
|---|---|---|
| wood | wood.png | Cut wooden plank |
| plastic | plastic.png | Blue plastic sheet |
| scrap | junk parts.png | Metal gear/fastener parts |
| rope | rope.png | Rope loop |
| stone | rock.png | Gray rock |
| ingot | steel.png | Metal bar |
| fish | fish.png | Raw fish |
| seed | seed.png | Planting seeds |
| veg | carrot.png | Carrot |
| meal | stew.png | Prepared food bowl |
| hammer | hammer.png | Hand hammer |

Both `Art.texture()` and `Art.item_icon()` use this same mapping, including world salvage and underwater fish. The original source colors are retained, and display scaling remains a runtime operation. World and UI now also share the existing code-defined reusable cups and fishing rod. Older sections below describe their introduction and are not the current material mapping.

The pack has no matching palm frond, paddle or improvised anchor. These three are original **code-defined 16×16 pixel grids** in `scripts/art_catalog.gd`, using the existing image helper and a muted coastal palette. They are separate project artwork, not vendor-image edits or human-hand-drawn claims. Existing ore, fins, reinforced hook, furnace and cooked-fish code art remain in use. No image-generation service, new library or editor installation was used. Character art is unchanged. Mana Seed and LimeZu files remain excluded.

## 0.5.1 characters — PIPOYA

On 2026-10-04, two original 96×128 PNG sheets from [PIPOYA FREE RPG Character Sprites 32x32](https://pipoya.itch.io/pipoya-free-rpg-character-sprites-32x32) by Pipoya replace the Tiny Farm player icons. The official page labels this pack as made without generative AI. The source sheet has three 32×32 frames across and four facing rows (down, left, right, up). `scripts/character_art.gd` selects atlas frames; original PNG pixels are unchanged. The selected characters are blue-clothed `Male 02-1` and red-clothed `Female 02-1`.

The original archive SHA256 and official license summary are preserved in [vendor/pipoya/LICENSE.md](vendor/pipoya/LICENSE.md). These files are allowed in personal/commercial games but cannot be redistributed as raw assets. This is a separate license from Kenney's CC0. No purchase, new library or editor installation was needed. Keep raw files out of public source distributions; third parties should download them from Pipoya.

Runtime diving equipment is original scene code. This pack has walking frames, not a swimming animation set; 0.5.1 only supplies a simplified underwater pose. Mana Seed was evaluated but excluded because its current license forbids AI-assisted code in the containing project; Modern Interiors' free sample was excluded due its noncommercial limitation. No files from either pack are included.

## Existing environment and item art

Verified and downloaded from the creator's official asset pages on 2026-10-03 (Asia/Shanghai).

| Included pack | Creator / source page | License | Files retained |
|---|---|---|---|
| Tiny Town 1.1 | [Kenney](https://kenney.nl/assets/tiny-town) | CC0 1.0 | Original packed PNG atlas and original License.txt |
| Tiny Dungeon 1.0 | [Kenney](https://kenney.nl/assets/tiny-dungeon) | CC0 1.0 | Original packed PNG atlas and original License.txt |
| Tiny Farm 1.0 | [Kenney](https://kenney.nl/assets/tiny-farm) | CC0 1.0 | Original packed PNG atlas and original License.txt |

Each official page explicitly identifies the asset license as Creative Commons CC0. Each included, unmodified License.txt explicitly permits personal, educational and commercial use. Kenney's [support page](https://kenney.nl/support) also confirms that attribution is optional. No Kenney logo is included.

Direct official archives used:

- Tiny Town: https://kenney.nl/media/pages/assets/tiny-town/a415fbeb49-1735736916/kenney_tiny-town.zip
- Tiny Dungeon: https://kenney.nl/media/pages/assets/tiny-dungeon/f8422efb44-1674742415/kenney_tiny-dungeon.zip
- Tiny Farm: https://kenney.nl/media/pages/assets/tiny-farm/dfded1ae3e-1782913588/kenney_tiny-farm.zip

Only one packed atlas from each archive is retained, named `Tilemap_tilemap_packed.png` to preserve its original archive path in a flat filename. These are all 192 by 176 pixels, with 12 columns and 11 rows of 16-pixel tiles and no spacing. The runtime region mapping is in `scripts/art_catalog.gd`. PNG artwork has not been edited; optional scene tint, scaling and composition happen at runtime.

Roguelike Characters and Roguelike/RPG were inspected as alternatives, then rejected for this build to keep the Tiny palette and proportions consistent. Their artwork is not distributed with this project.

The Tiny atlases do not include a fish. The small raw/cooked fish silhouettes in `art_catalog.gd`, the hook line/float, processing steam and water ripples are original project artwork. Fish silhouette generation is a fixed, code-defined pixel grid; no image-generation service was used. Item labels carry the exact gameplay meaning where a Tiny prop is reused as a representational icon. Version 0.3 used an empty bucket for a cup; 0.3.1 replaces that item icon as described below.

Raft floor uses only the internal wooden-board region of Tiny Farm (112,146,16,12), with scene tint and a thin seam. The barn frame is excluded to avoid bright borders between raft cells.

Version 0.3.1 adds original code-defined SVG pixel frames and HUD symbols in `assets/ui/`. The nine-slice style and palette are centralized in `scripts/ui_style.gd`; no third-party UI pack or image-generation service was used. Their colors and stepped outlines are part of this project's UI source.

The 2026-10-03 UI pass adds original 16-by-16, code-defined pixel-grid icons for a rope loop, an empty handled cup, seawater and freshwater cups, and a fishing rod with a reel and line. `art_catalog.gd` renders these code-native grids through the same image helper as the fish; no image-generation service, edited vendor image, or new dependency is involved. `item_icon()` supplies them consistently to the inventory, hotbar and crafting UI. Dark blue seawater and light turquoise freshwater share the reusable cup silhouette; existing item-name tooltips distinguish them. This replaces the earlier representational bucket specifically in item UI while leaving world facility atlas mappings unchanged.

Version 0.4 adds six original 16-by-16 code-defined pixel grids in `art_catalog.gd`: a gray-brown stone, rust-veined metal ore, a blue-gray metal ingot, paired turquoise fins, a reinforced metal hook with rope, and a chimney furnace with a dark firing chamber. The existing fixed-grid image helper supplies the same cached artwork through both `texture()` and `item_icon()`, so underwater objects and inventory icons match. Furnace fire remains a separate scene effect. These additions do not modify vendor atlases or existing artwork mappings and use no image-generation service or new dependency.

Version 0.5 replaces the runtime raft floor with original code-defined staggered planks, grain, edge timber and rope ties in `world_view.gd`; the old atlas floor remains an inventory/recipe illustration. Original scene code also supplies moving wavelets, contact shadows, continuous reef silhouettes, seagrass and a salvage chest assembled with the existing licensed chest textures. The motion is a bounded visual transform shared by the raft and its contents, with a fixed camera. `ui_style.gd` now draws restrained canvas/ink surfaces using native Godot StyleBoxFlat; the thick nine-slice HUD frames are no longer used. Existing SVG symbols and item atlases remain unchanged. No third-party files, image edits or image-generation service were added in this version.


## 0.8 新增工具

鱼叉、石斧、石镐和罗盘沿用 ArtCatalog 固定16×16像素网格定义，并通过统一材质适配显示；为项目代码定义图标，没有新增下载位图或使用图片生成服务。人物与原授权素材不改。


### 0.9 原创代码图标

`art_catalog.gd` 的 FARM_PIXELS 添加锄头、镰刀、水壶、单格暖棚、纤维与三种季节种子包装。它们是16×16代码定义像素网格，复用原工具色板与PropArt统一材质边缘；没有下载/编辑新的位图，不称为星露谷原素材。岛地、池塘、小径、耕地、作物阶段与简易暖棚均由现有世界绘图代码绘制。


0.10：居民复用现有许可的Pipoya两张人物原图并在绘制时调色/添加帽子；建筑、桥梁、水系为项目代码绘制，无新外部图片下载。八名角色是独立身份/职业，并非八套独立角色美术。

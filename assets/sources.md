# Tidehaven artwork sources

## 0.18 对话与菜单

沿用用户确认的ffffhx/stardew-valley-assets授权；固定提交0c31854d40fcc1f6b60b35ac07b7c9686b82b226。新增18张未改像素Portraits、MenuTiles与Cursors，哈希/画布见vendor/stardew-island/dialogue-manifest.json，复原tools/import-dialogue-art.py，裁切来源见该目录SOURCE.md。镇民肖像与身体同源，5位海上伙伴肖像仍需补画。广场仅运行时去原生石沿烘焙草背景，掩码与四季原像素验证见terrain-seams-0.18；不改原PNG，不扩大授权声明。


## 0.17：四名独立居民（2026-10-24）

陆舟/Alex、沐桐/Leah复用已授权的完整原图；顾星/Maru、许棉/Emily从同一固定提交补充，原文件未改画。下载过程、尺寸、源路径与哈希见vendor/stardew-island/residents-manifest.json、SOURCE.md和tools/import-town-residents.py。继续16×32原帧、32×64世界比例、四方向完整动作；风格/比例接入与验收状态见art-direction.md v1.11，不声明为独立原创人物美术。

## 0.16：换装、泳姿、住房与新岛（2026-10-24）

继续使用同一用户确认授权、固定提交0c31854d40fcc1f6b60b35ac07b7c9686b82b226。陆地换装复用player原生图层；院屋/船屋复用Town建筑和SamHouse/Trailer原TMX，三座新岛复用Mountain/Beach/Farm。新增海龟、精灵、海灵、海盗原图及来源哈希在vendor/stardew-island/ocean-residents；海商沿用配套玩家图层。美人鱼环境图不冒充美人鱼角色。

水下新增内置image_gen生成的专用潜水头套角色，原图保留、运行时统一逻辑网格；生成提示与状态见characters/swimming/SOURCE.md。它是新生成素材，不是归档原作泳姿。未使用短发草稿和8/9帧不能算当前已验证资产。所有比例及实际画面证据见art-direction.md v1.10和implementation-0.16.md；技术通过不等于用户已认可。

## 0.15.1配套玩家动作（2026-10-23，验收中）

同一用户确认授权与固定提交新增Characters/Farmer下7份原图：男女身体、发型、上衣、裤子、皮肤和鞋色表。来源、Git blob与SHA256见vendor/stardew-island/player/manifest.json；tools/import-player-art.py可重复恢复，原PNG不改画、不缩放，无新增依赖。PlayerArt按原生衣发/手臂分层合成固定外观，站立、走路与五阶段挥斧共用；原NPC素材保留。

工具复用原tools.png，依据同归档FarmerSprite/FarmerRenderer/Game1的帧号、分层与方向变换适配，正侧向按可见手部校准握柄；背向保留原生遮挡。ChoppingArt不再引用characters/actions下的生成候选图；那些文件仅保留历史来源，不能算当前已通过的动作。实际接触、尺寸与验收范围见art-direction.md和implementation-0.15.1.md。

## 0.15新增授权归档内容（2026-10-23）

来源：用户确认授权的ffffhx/stardew-valley-assets，固定提交0c31854d40fcc1f6b60b35ac07b7c9686b82b226。此记录依据用户确认其朋友允许使用全部资料，不声称独立审阅合同或仓库对公众授权。

- 15张TMX：Hospital、SeedShop、ScienceHouse、BathHouse_Pool、Blacksmith、FishShop、ManorHouse、AnimalShop、Saloon、Greenhouse、SamHouse、Trailer、Mines/1～3；原分层和对应5张图集由tools/import-island-maps.py --interiors转换，原始文件/逐文件SHA256保留在maps/interiors-manifest.json。
- Elliott、Penny、Sam、Linus、Kent完整人物图和Buildings/Greenhouse：tools/import-town-residents.py；逐文件SHA256在residents-manifest.json。
- 原Objects图集继续复用六项食材/料理索引；海洞沿用既有海岸材质，岛矿梯取原Mines/mine切片；没有新增第三方依赖或另行生成替代图。
- 具体像素/比例/池水遮挡例外见docs/art-direction.md v1.8；原源图未改，TMX门扇仅在运行时打开。矿洞外入口复用既有Mountain原TMX(51,2)7×4分层，未新增下载。

## 0.14 水下敌人（2026-10-22）

内置image_gen生成横版鲨鱼、海鳗原PNG，每种3游动帧及蓄势/冲刺/退避姿态，文件在sea-creatures；来源说明、精确提示和原文件哈希见[SOURCE](sea-creatures/SOURCE.md)、[PROMPTS](sea-creatures/PROMPTS.md)、[manifest](sea-creatures/manifest.json)。源图未经改画，运行时裁切/最近邻/透明阈值在SeaCreatureArt，接入遵守比例v1.7。没有下载商业游戏敌人，也没有新增依赖；生成来源不代替真实场景观感验收，专用人物泳姿仍缺。

## 0.13.1 补齐当前P0素材（2026-10-16）

SurvivalArt适配同一授权固定提交的tools、weapons、AquariumFish三张新增原图，以及原有Craftables、springobjects和crops；来源路径/原图哈希见vendor/stardew-island/manifest.json。工具/种子/食材使用真实菜单索引；水下鱼使用侧视图，熔炉有闲置/加工两帧，筏上种植盆三阶段共用底座。冬季作物使用原冬种行，不再改色春萝卜。

内置imagegen补充双角色四向挥斧、潜水梯、暖棚和侧视沉箱。生成原图未修改，原文件、提示约束、哈希及运行时量化见characters/actions/SOURCE.md、coastal/PROMPTS-0.13.md与各自manifest。岛上水岸/桥仍复用原生土水木纹，几何来自IslandMap。没有新增依赖。技术检查和用户视觉认可分别登记在art-direction.md。

## 0.12.1 复用说明（2026-10-13）

无新增或改写PNG。地板预览复用已登记Beach→MaritimeArt→ArtCatalog的floor纹理；加工与物资提示复用现有图标。SceneFeedback/WorldView的小水花、落尘及微光为代码绘制，不作为完整人物动作或独立美术素材。现有来源授权及原图哈希保持，比例v1.5未变。


## 0.12 工作台（2026-10-13）

新增同一固定归档0c31854d40fcc1f6b60b35ac07b7c9686b82b226的assets/TileSheets/Craftables.png，下载为vendor/stardew-island/Craftables.png。原图SHA256：c799b887cbccd07fe518120788606c439f5d902a515210e18e31274bbf7ff2bb；128×1472，清单已登记。来源数据assets/Data/BigCraftables.json中Workbench.SpriteIndex=208，使用对应16×32格，顶部透明行裁掉后16×27。授权依据继续为用户对朋友仓库全部资料的明确许可，不新增公开许可证推断。原像素/哈希保留，运行时沿用项目材质边缘处理与2倍比例。场景、图标、建造预览共用同一切片。

## 0.11.4 海洋场景适配（2026-10-12）

继续使用固定提交0c31854d40fcc1f6b60b35ac07b7c9686b82b226及此前用户明确的授权，无新增下载/依赖。MaritimeArt登记spring_beach的码头木板(192,272,32,16)、沙(240,272,32,32)、岩石(192,160,48,48)、岩纹(208,176,16,16)、碎石(48,160,32,32)、植株(208,128,32,32)、破船木(0,128,48,48)。海面复用原岛图四帧水纹，缩景复用既有树、Log Cabin、Fence1与Beach地图码头片段。原PNG/TMX与manifest不变；仅运行时重复木板、日照提亮与浸水光照，裁切后缓存，未把顶视岛屿整张背景塞入横版潜水。缩景是示意构图，不宣称逐格复刻可玩岛。原有设施和鱼类图仍沿用既有来源；专用泳姿、原创NPC形象后续处理。


## 0.11.3 — native map combinations (current)

Pinned source remains0c31854d40fcc1f6b60b35ac07b7c9686b82b226, with the existing user-confirmed permission. Added five original TMX maps plus29 referenced/seasonal images; source hashes are in assets/vendor/stardew-island/maps/manifest.json. IslandTiles uses Town/Beach layer combinations and native building regions; IslandSurface uses native seasonal edges and water. No original gameplay events or interiors were ported. Full scope, original-pixel preservation and reference/runtime distinction are recorded in vendor/SOURCE.md and docs/reuse.md.

## 0.11.2 — complete characters and harvestable grass (historical)

Added 11 original character PNGs from the same pinned commit: Alex/Leah for the two players and Lewis/Caroline/Harvey/Gus/Robin/Clint/Willy/Marnie/Evelyn for nine resident identities. The manifest now lists 29 unchanged originals. CharacterArt crops complete 16×32 bodies at 2× scale with direction mapping 0/3/1/2. Harvestable fiber now uses 16×20 tufts from grass.png (season rows 0/1/2/4); winter uses an existing cool-coloured grass variant. User-confirmed permission is unchanged. Historical PIPOYA files are retained, no longer used for these people; dedicated side-view swimming remains missing.

## 0.11.1 — island atlas integration (historical)

The user authorized actual integration after the earlier documentation-only review. Eighteen original PNGs from fixed commit `0c31854d40fcc1f6b60b35ac07b7c9686b82b226` are now recorded under [vendor/stardew-island/SOURCE.md](vendor/stardew-island/SOURCE.md), with original paths, canvas dimensions and SHA256 in its manifest. Runtime island ground, trees/resources, courtyard fence/sign, three exteriors, soil and crop states now use this family; `grass.png` remains an inspected candidate. The original files are unchanged. The archive permission basis remains the user's explicit confirmation.

Characters retain the two existing PIPOYA sheets. Four-direction walking now advances every 14 world units instead of 6; horizontal swimming still lacks dedicated frames. Map colours now follow seasons and show the yard ground. Old shops, bridges/coastline geometry, greenhouse overlays and underwater environments are outside this replacement batch. Earlier “not imported” paragraphs below describe the preceding documentation-only step, not the current build.

## Stardew reference archive: updated permission information, not imported

On 2026-10-12, the user stated that the owner of `ffffhx/stardew-valley-assets` is their friend and has granted them permission. This is recorded as user-reported separate permission, not as an inspected license text. Live GitHub API and raw-file reads resolved main to `0c31854d40fcc1f6b60b35ac07b7c9686b82b226`. Its [archive.json](https://github.com/ffffhx/stardew-valley-assets/blob/0c31854d40fcc1f6b60b35ac07b7c9686b82b226/archive.json) removes the earlier no-redistribution-license sentence and retains attribution of original game content to its respective copyright holders. No license or permission document was found at the repository root.

The previous sentence at commit `00c1810` is historical, not the current main declaration. After the scope discussion, the user explicitly confirmed having that authorization and their friend's agreement to use all their materials. Proceed with asset selection and adaptation on that user-confirmed basis; do not repeatedly request the same confirmation. This records the user's statement, not an independently reviewed contract or a public license for everyone. The archive inventory has now been inspected for the first island scene; candidate paths and reported dimensions are in docs/art-direction.md. No Stardew asset is imported into Tidehaven by this documentation update. See docs/reuse.md for the decision record.

## 0.11 abandoned courtyard and town extension

No external asset or new dependency was added. Fence sections, the yard sign and additional building exteriors extend the existing project-authored Godot drawing code in world_view.gd, with shared IslandMap geometry. Existing PIPOYA player art is unchanged; the mayor temporarily reuses that licensed adult source and does not constitute a finished original NPC design. Trees, weeds and crop art remain on the earlier source mappings. See art-direction.md for exact world units and the pending art gaps.

## 0.10.3 coastal props

Eleven new original generated PNGs replace the sleeping bag/bed, closed/open chest, barrel, purifier, grill and four common salvage materials. See [coastal/SOURCE.md](coastal/SOURCE.md) for unchanged originals, prompts, hashes, logical pixel grids and remaining gaps. Built-in image_gen was used; these are not commercial-game extractions or hand-painted claims. Existing vendor PNGs and accepted characters remain intact.

World display metadata now lives in ArtCatalog.WORLD_PROPS; a shared aspect-preserving path feeds facilities, camp and previews. CharacterArt holds the existing 48-unit adult ruler, now also used by villagers. Raft boards and ocean colours are adjusted through their existing code renderer, without changing motion or gameplay coordinates. These entries supersede the older runtime mappings below for the listed objects only.

## 0.10.2 shared UI skin

The existing twelve SVG surfaces in `assets/ui/` were redrawn as original code-native pixel UI: warm paper, restrained timber edges, inset item slots and sea-green selection. Each remains a 32×32 SVG source, rasterized by Godot with nearest-neighbour display; StyleBoxTexture preserves fixed corners rather than stretching a complete menu image. The shared source margins are 10 UI units for paper and 8 for other surfaces. All readable text, numbers, material counts and control states remain live UI controls.

These are project-authored SVG edits by the coding assistant, not Stardew Valley asset extracts, purchased art, image-generator output or claimed human hand drawing. Existing item icons and the accepted PIPOYA characters are reused unchanged. No new external artwork or dependency was added. The player-approved direction and the separate pending visual acceptance are tracked in `docs/art-direction.md`.

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

# Island atlas provenance — 0.11.3

## 0.18 native conversation and menu art

The same user-authorized pinned commit 0c31854d40fcc1f6b60b35ac07b7c9686b82b226 supplies 18 untouched Portraits PNGs, assets/Maps/MenuTiles.png and assets/LooseSprites/Cursors.png. dialogue-manifest.json records every original SHA256, size and canvas. Restore with tools/import-dialogue-art.py. Authorization is the user's confirmed permission, not a newly asserted public license.

PortraitArt derives each portrait filename from the matching complete CharacterArt world sprite; 64×64 neutral frame at2× UI scale. Ocean residents have no matching portrait and retain a text layout. UIStyle uses MenuTiles paper rect(0,256,60,60), inventory tile10 (128,128,64,64), selected56 (0,896,64,64). DialogueFrame uses Cursors native border pieces near(261,311), portrait frame(583,411,115,97), reply highlight(375,357,3,3), each recorded in runtime code. Source IClickableMenu, DialogueBox, Toolbar and InventoryMenu were read for coordinates/layout; GDScript continues to use Godot controls. Original source files are read-only research artifacts, not a new runtime dependency.


## 0.17 resident cast (2026-10-24)

Four additional complete, distinct resident sources use the same fixed commit and user-confirmed authorization below. Alex and Leah were already present in manifest.json; Maru and Emily are downloaded unchanged. The regenerated residents-manifest.json retains the five earlier residents and greenhouse and records all nine character originals with SHA256, byte size and PNG canvas. No pixels were repainted or recolored, and no new dependency was added.

Tidehaven identities: Alex → 陆舟 / harbor rescue worker; Leah → 沐桐 / botanical artist; Maru → 顾星 / tide-instrument maker; Emily → 许棉 / tailor. Their stories and dialogue are Tidehaven-authored. CharacterArt reads only the normal four-direction walking block: 16×32 source cells, four columns, direction rows [0,3,1,2]. Each complete adult retains 2× nearest-neighbor world scale, 32×64 rectangle and foot offset (16,62); later source rows are unused. Distinct complete originals avoid mismatched body/head layers or recolor-only residents.

ResidentRoutes uses explicit workplace points on existing connected interior floors, separate from the original shopkeepers; the shared home/walking/interaction/map route still comes from one source. Initial source-sheet inspection confirms four directions and full bodies. Game-scene, input and route validation are recorded by the 0.17 implementation report; this source record does not assert user visual acceptance.

## 0.13.1 tools, food, facilities and fish

Added original tools.png, weapons.png and AquariumFish.png from assets/TileSheets at the same pinned commit. Their hashes and canvas sizes are in manifest.json. SurvivalArt references Tools menu indices215/131/47/296, weapon47, object IDs390/378/335/142/198/228/24/472/487/490/498/771, Craftables13/14/37/62. These were checked against Tools/Weapons/Objects/BigCraftables/AquariumFish data. The swimming carp uses side-view index11, rect(264,0,24,24), following TankFish's24×48 row layout. Winter_seed now uses native winter-seed crop row23, without spring-crop color substitution. Tidehaven's crop names and days remain its own game rules.

The pot is composed at runtime on a16×48 canvas with the same base in empty/growing/ready states, using native parsnip stages. Original PNGs are unchanged. Generated sea chests, ladder, cold frame and chopping characters have separate source records; they are not attributed to this repository. Notes below describe their historical versions.

## 0.12 workbench (2026-10-13)

Craftables.png was fetched unchanged from assets/TileSheets at the same pinned commit. Its Workbench entry has SpriteIndex 208, verified against BigCraftables.json and the image. ArtCatalog uses region (0,837,16,27), with 2x world scale and existing warm material-edge treatment; metadata, original hash, byte count and dimensions are recorded in manifest.json. No source pixels or other island placements were changed.

## 0.11.4 海洋场景适配（2026-10-12）

继续使用固定提交0c31854d40fcc1f6b60b35ac07b7c9686b82b226及此前用户明确的授权，无新增下载/依赖。MaritimeArt登记spring_beach的码头木板(192,272,32,16)、沙(240,272,32,32)、岩石(192,160,48,48)、岩纹(208,176,16,16)、碎石(48,160,32,32)、植株(208,128,32,32)、破船木(0,128,48,48)。海面复用原岛图四帧水纹，缩景复用既有树、Log Cabin、Fence1与Beach地图码头片段。原PNG/TMX与manifest不变；仅运行时重复木板、日照提亮与浸水光照，裁切后缓存，未把顶视岛屿整张背景塞入横版潜水。缩景是示意构图，不宣称逐格复刻可玩岛。原有设施和鱼类图仍沿用既有来源；专用泳姿、原创NPC形象后续处理。


Source: [ffffhx/stardew-valley-assets](https://github.com/ffffhx/stardew-valley-assets), fixed commit `0c31854d40fcc1f6b60b35ac07b7c9686b82b226`. The 30 original PNGs are byte-for-byte downloads from the paths recorded in `manifest.json`; that manifest records SHA256, file length and PNG canvas size. Original game content remains attributed to its respective copyright holders.

Permission basis: on 2026-10-12 the user explicitly confirmed their friend's authorization to use all their materials, then requested this integration. This is the recorded user-confirmed permission, not a claim that the repository grants a public open-source license or that a separate contract was independently inspected.

Runtime metadata lives in IslandArt (single regions), IslandTiles (TMX layer combinations), IslandSurface (terrain edges) and IslandMap (gameplay positions and collision). Original PNGs and TMX files are unchanged; no source pixel editing or new dependency is involved.

0.11.3 adds five pinned source maps (Town, Farm, Beach, Mountain, BusStop) and their 29 referenced/seasonal PNGs. `maps/manifest.json` records each source path and SHA256; some sheets overlap the earlier atlas set, so counts must not be added as unique assets. `tools/import-island-maps.py` uses Python's standard library to extract read-only tile/layer/animation metadata into maps.json. Preserve both the original atlas manifest and map manifest.

Actual use: Town/Beach layered facades, Town stone plaza, Beach wooden dock, seasonal outdoors terrain transitions, complete smith/clinic/market/fishery/farmhouse/carpenter/bathhouse exteriors. The original Town/Beach/Mountain reference renders are distinct from Tidehaven's authored settlement layout. Original map warps, event logic, interiors and player saves are not imported. Farm/Mountain/BusStop are reference data, not newly unlocked play areas.

Trees now use 2× native pixels with source contact(24,84); the smaller24×24 stump remains a documented exception. Dry/wet soil selects connected four-neighbour cells. Crop rows0/15/18 remain mapped to Tidehaven's4/7/10/6-day rules; fictional winter snow-root still needs bespoke art. Eleven complete character originals and nine NPC identities are retained; swimming still needs dedicated frames.

See docs/art-direction.md and docs/verification.md for current sizes, actual-game evidence, test boundaries and incomplete work. Source availability is not visual acceptance.

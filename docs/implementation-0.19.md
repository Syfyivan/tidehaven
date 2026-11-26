# 0.19 海港人物样板、海上伙伴肖像、基础音效与《候潮院》

2026-11-26。用户确认锁定 **Godot 4.7.1 独立游戏路线** 作为唯一主开发线（`experiments/stardew-spike` 作为已完成的技术对照样板封存保留，不双线维护），并授权将源码与公开可分发资产推送至 GitHub。`0.19.0` 最终 Windows 包已完成本地规则、两尺寸实景 UI、内嵌 PCK、本机双人 ENet、旧档只读副本迁移与正常空背包开局保存继续验证；`tools/launch.ps1`、`开始游戏.cmd` 与 `tools/playthrough.ps1` 默认入口已切至 `0.19.0`，旧包与个人原档完整保留。

## 交付范围与设计边界

1. **5 位海上伙伴对话肖像补齐（关闭 0.18 肖像缺口）**
   - 新增白帆（海商）、赤绳（海盗）、潮甲（老海龟）、苔露（林地精灵）、澜影（潮洞海灵）配套 `64×64` 原生像素肖像（UI 最近邻 `2×` 显示为 `128×128`），统一接入 `PortraitArt` 与底部 `TownDialogue` 木框姓名/职业区。23 位已接入居民现全部具备配套对话肖像；仍保留未来无肖像角色的全宽文本回退。

2. **游戏基础音效与环境声系统（`GameAudio`）**
   - 由 `tools/generate-audio.py` 生成 15 份原创确定性 16-bit 22,050Hz PCM `.wav` 音频资产（12 项交互/动作音效：`ui_click`、`dialogue_open`、`hook_cast`、`splash`、`pickup`、`build`、`chop_hit`、`tree_fall`、`mine_hit`、`spear`、`alert`、`craft_ready`；3 项无缝循环环境声：`sea_ambient`、`underwater_ambient`、`island_ambient`）。
   - `scripts/game_audio.gd` 只读观察已确认状态跃迁与 `SceneFeedback`，不修改 `WorldState`、世界存档或网络消息；首次载入快照静默，重复快照不重播，满包/取消不误报收获音。暂停菜单新增 `静音 / 开音` 切换（独立保存于 `user://audio_settings.json`，自动化测试不改写用户音频偏好）。

3. **`P2-08a` 架空近代中国海港人物首组样板**
   - 范围严格限定为用户确认的首组样板：**玩家男女海港基础像与配套衣发（8 款海港发型 + 8 款盘扣/斜襟/马甲劳动短衫）+ 严砧（较年长铁匠，炭灰盘扣短褂配赭色皮围裙）+ 沐桐（年轻植物画师，浅苔绿斜襟短衫配斜挎画具袋与木簪）**。
   - 保持 `16×32 → 32×64` 世界尺寸、固定脚点 `(16,62)`、`Appearance` 原 `2×8×6×8×4×6` 严格索引兼容及 `PlayerArt` 五阶段挥斧握柄/斧刃落点（与 `ToolMotion.BLADE_OFFSETS` 误差 `< 1` 世界像素）。开局与暂停换装面板同步展示配套海港半身肖像与四向行走预览。其余 16 名镇民保留现有素材，待用户确认首组样板观感后再扩展。

4. **`P2-09《候潮院》` 完整可玩长篇故事与 `world_v17.json`**
   - 先完成完整节点脚本 [docs/narrative/hou-chao-yuan.md](narrative/hou-chao-yuan.md)，再由 `scripts/long_stories.gd` 实现主机权威推进与严格校验。
   - 存档升级至 `world_v17.json`，顶层新增版本化 `chronicles` 字段（与 0.17 三段个人短篇 `stories` 分离）；`v1～v16` 旧档只读迁移并保留原文件。
   - 完整闭环：承租荒院后走近西门发现旧潮痕与半个“候”字（右键查看）→ 东街镇长许岸追问《候潮院》来历 → 找木匠贺木加固门廊取出桐油木匣（需木板 ×6；**已委托修屋或完工的旧档自动免材料直接衔接**）→ 带植物纤维 ×2 找广场邮差乔信寄信给岑婆 → 真实过一夜后回访乔信拆读回信并选择院门新木牌（`候潮农庄` 门牌+歇脚竹篮 / `候潮驿院` 门牌+傍晚 18:00 自动亮起的暖光门灯）→ 原子结算共享金币 `+35`、个人背包海港热汤 `meal × 2`（满包无损拦截）及相关居民好感。完工后可在院门右键菜单随时切换两种门牌布置，不占用任何可耕农田格；`J` 手记实时显示阶段指引与完成记录，`ResidentDialogue` 接入后续日常回声。

## 主要新增与修改文件

| 文件 | 说明 |
|---|---|
| `assets/audio/*.wav`、`tools/generate-audio.py`、`scripts/game_audio.gd` | 15 份原创 PCM 音效/环境循环生成、RIFF WAV 加载、8 通道播放池、只读状态观察与暂停静音控制。 |
| `assets/portraits/ocean/*`、`assets/portraits/harbor/*`、`assets/characters/harbor/*`、`tools/build-019-art.py` | 5 海上伙伴肖像、玩家男女与严砧/沐桐海港肖像、严砧/沐桐 `64×128` 世界行走表、8 款海港发型与 8 款盘扣/斜襟上衣图层及 SHA256 清单。 |
| `scripts/portrait_art.gd`、`scripts/character_art.gd`、`scripts/player_art.gd`、`scripts/appearance.gd`、`scripts/appearance_panel.gd` | 海上与海港肖像路由、玩家肤色/发色/衣色动态映射、海港世界精灵表接入、换装面板半身像与四向预览排版。 |
| `docs/narrative/hou-chao-yuan.md`、`scripts/long_stories.gd` | 《候潮院》完整五阶段节点脚本、主机权威校验、修屋旧档免材衔接、跨夜等信、原子发奖与院门样式切换。 |
| `scripts/world_state.gd`、`scripts/island_town.gd`、`scripts/resident_dialogue.gd`、`scripts/journal_panel.gd`、`scripts/world_view.gd`、`scripts/main.gd` | `v17` 存档 `chronicles` 恢复与迁移、院门查看/切换动作、NPC 长篇话题分发、手记进度摘要、院门木牌/暖灯/竹篮实景绘制与音频挂载。 |
| `tests/audio_checks.gd`、`tests/harbor_art_checks.gd`、`tests/chronicle_checks.gd`、`tests/release_019_ui_checks.gd`、`tests/stories_network_probe.gd` | 音频规则、海港像素与挥斧落点、长线状态机与异常拦截、两尺寸实景全链路 UI、双人 ENet 长线同步验证。 |

## 验证与问题修正记录

1. **过程中的真实发现与修正**
   - 初版海港 `16×32` 世界精灵头部偏方、发型层偏高 2px：通过联系表目视检查发现，改为圆润收颌轮廓、双像素眼部与匹配 `farmer_base` 的 `y=3..12` 头顶锚点，`harbor_art_checks` 308 项二值透明/尺寸/挥斧落点全部通过。
   - `GameAudio` 初版用效果数组长度判断新增反馈，同帧旧特效过期时漏播 `tree_fall`：改为跟踪活跃特效字典引用，`audio_checks` 32 项全部通过。
   - 实景截图检查发现 `AppearancePanel` 左下说明文字未折行越过右列“肤色”行，且院门地面提示文字与竖向院栏轻微重叠：修正标签折行、补齐肖像框卷轴名牌“海港旅人”，并将院门地面提示移至门内黄土路面，复验截图无任何重叠。
   - 自动化界面测试在未传 CLI 参数而事后设 `main.automated = true` 时曾触发 `audio_settings.json` 写入：为 `GameAudio` 增加父节点 `automated` 守卫，隔离测试不再触碰用户目录配置。

2. **最终交付包与完整证据**
   - 最终可执行包：`build/Tidehaven-0.19.0.exe`，**129,224,736 字节**，SHA256：**`8F70487CDE5BBA43A6FE3AC99C0FFA48D419C42A2583F2FBE61AE6C4F54B920E`**（原 `build/Tidehaven-0.18.0.exe` 保持 `366F9565940C9B362E6BF17DF089BA86BB1446C60DFA373DE7B0E285F48D6FB0` 未变）。
   - 源码全量规则与素材回归：`audio_checks` 32、`chronicle_checks` 20、`harbor_art_checks` 308、`appearance_checks` 419、`character_test` 116、`chopping_checks` 104、`chopping_contact_checks` 447、`resident_dialogue_checks` 284、`resident_stories_checks` 1527、`story_world_checks` 423、`prop_art_checks` 757、`terrain_seam_checks` 2092、`restaurant_checks` 2364 等 50 余组测试全部 0 失败。
   - 最终包内嵌 PCK 图形界面验证（`--main-pack build/Tidehaven-0.19.0.exe`）：`release_019_ui_checks` 两尺寸（`1280×800`、`960×600`）**91 项、0 失败**（`artifacts/release-019-ui-1795664340`）；`dialogue_skin_ui_checks` 全 23 名居民肖像与对话 **427 项、0 失败**（`artifacts/ui-018/skin-3076347`）；另有 `ui_review_checks` 128 项、`interaction_ui_checks` 23 项、`map_overlay_checks` 7 项全部通过。
   - 最终包本机双进程 ENet 与独立续档：主机 **11 项**、客机 **8 项**、独立进程 `resume` **3 项**全部通过（`artifacts/progression-network-20261126-114025-945-c14cd3ba`），覆盖客机独立海港换装、个人短篇、共享《候潮院》院门查看与对话推进、重复 RPC 拦截及重连恢复。
   - 历史真档只读副本迁移：个人 `world_v11.json` 副本与 `0.18.0` 实机 `v16` 存档副本经最终包迁移写入 `v17` 并重读完全一致，原文件 SHA256 前后逐字节不变（`7A0C8699...` 与 `EC270ABB...`）。
   - 最终包空背包正常开局生存流程（默认真实音频驱动，未启用 `DummyAudio`）：**132.82 秒**完成 9 格木筏开局→13 次抛钩打捞→手工造绳/杯/钓竿/桨/锚→操船抛收锚→放置净水器/烤架/木箱→净水饮用→3 次垂钓获鱼烹饪食用→扩建甲板→木箱存取→正常保存并 `Continue` 精确恢复（`artifacts/playthrough-20261126-114043-267/report.json`，`passed=true`，`stderr` 为空）。

## 仍需外部验收的边界

- 本轮海港人物样板、5 位海上伙伴肖像与《候潮院》实景截图已完成本地技术与助手目视核验，**不代替用户的真实审美、操作手感与实际扬声器听感验收**。
- 本机双进程 ENet 验证不代表跨电脑局域网/虚拟局域网验收。
- 其余 16 名镇民的近代中国海港化外观及 `P2-10～P2-48` 其余长线故事仍保持 `docs/TODO.md` 待办，待本组样板与首条长线获试玩反馈后按序推进。

# 0.20 全镇近代中国海港人物与三条核心长篇故事

2026-11-26。延续 **Godot 4.7.1 独立游戏唯一主线**，本轮完成 `P2-08a` 潮芽镇全部 **18 名居民**（含 0.19 已交付的严砧、沐桐与本轮新增 16 名镇民）的架空近代中国海港世界像素与对话肖像统一替换，并按先写节点脚本后实装的规范交付剩余三条核心可交错长篇故事：`P2-10《今晚留一碗》`、`P2-11《重新有人靠岸》`、`P2-12《海里也有邻居》`（存档升级为 `world_v18.json`，`v1～v17` 旧档只读迁移保留原文件）。`tools/launch.ps1`、`开始游戏.cmd` 与 `tools/playthrough.ps1` 默认入口已切至 `0.20.0`，旧包与个人存档完整保留。

## 交付范围与设计边界

1. **`P2-08a` 全镇 18 位居民近代中国海港化完成（消除镇民对第三方角色图依赖）**
   - 在 `0.19` 玩家男女、严砧（铁匠）、沐桐（植物画师）样板基础上，补齐其余 **16 位潮芽镇居民**（许岸、贺木、林穗、苏芩、汤禾、周潮、田青、陆遥、陈鱼、温知、乔信、石寻、森柯、陆舟、顾星、许棉）的原创 `64×64 → 128×128` 二值透明半身肖像（`assets/portraits/harbor/<id>.png`）与配套 `64×128` 四方向行走精灵表（`assets/characters/harbor/<id>.png`，单帧 `16×32 → 32×64`，固定脚点 `(16,62)`）。
   - 每位角色均按职业、年龄层与性格单独设计五官发型与民国海港劳动服饰（如许岸藏蓝中山装与胸袋钢笔、周潮竹编斗笠与靛蓝无袖渔马甲、苏芩圆框眼镜与海风诊所白大褂、陈鱼藏蓝厨师头巾与双排扣白厨衣、乔信绿邮差圆顶帽与斜挎邮包带、顾星护目镜与多袋工装背心等），严禁单套长袍或染色复用；所有 18 位镇民现完全从 `res://assets/{characters,portraits}/harbor/` 加载，不再读取不可公开再分发的 `vendor/stardew-island/{characters,portraits}` 原始角色图。

2. **`P2-10《今晚留一碗》` 餐厅长线（[脚本](narrative/jin-wan-liu-yi-wan.md)）**
   - 承租北街旧店（`restaurant.rented == true`）后，在潮间寿司屋收银台旁右键执行“查看收银台抽屉里的旧水牌”（`shop_inspect`）开启 → 与厨师陈鱼商议收工晚饭食单 → 找田青选时令蔬菜（需 `veg × 2`；**曾实际开店结算过的旧档自动免材料衔接**）→ 带 `fish × 2` 找诊所医师苏芩约定清汤鲜鱼与收工时间 → 真实过一夜后回访陈鱼，三选一确定店内常设席面牌（`家常暖锅席` / `时令鲜蔬席` / `海港鲜鱼席`），原子结算共享金币 `+40`、个人背包紫菜卷 `maki × 2`（满包无损拦截）与陈鱼/田青/苏芩好感。
   - 完成后收银台前木吧台挂起对应三色席面牌，收银台右键菜单可随时切换（`shop_style`），不强制改变日常晚间营业菜单。

3. **`P2-11《重新有人靠岸》` 航路与码头长线（[脚本](narrative/chong-xin-you-ren-kao-an.md)）**
   - 点亮西岸引航灯（`journal.story_step >= 1`）后，在潮芽岛西岸码头右键查看系船柱旧航线铜牌（`dock_inspect`）→ 找镇长许岸核实旧停航记录 → 找广场引路员陆遥比对两份礁石水深图 → 实际驾筏前往雾岬岛，携 `wood × 4`、`rope × 1` 与海商白帆校正暗礁浮标并立下复航约定（新增海上居民长线协议 `ocean_chronicle_open` / `ocean_chronicle_reply`）→ 真实过一夜后回潮芽镇找邮差乔信验收首班试靠，二选一定下西岸码头布置（`远航补给港` 补给货箱与橙旗 / `定期客船港` 候船长凳与蓝旗），原子结算共享金币 `+45`、个人背包烤鱼 `cooked_fish × 2` 与许岸/陆遥/乔信/白帆好感。
   - 完成后西岸码头呈现对应实景，码头右键菜单可随时切换（`dock_style`），保持四岛自由航行与原有海图规则不变。

4. **`P2-12《海里也有邻居》` 海岸与海灵长线（[脚本](narrative/hai-li-ye-you-lin-ju.md)）**
   - 在潮芽岛西岸北侧干爽浅滩（`Vector2(184, 244)`）右键查看弧形白石与轻敲水痕（`coast_inspect`）→ 找镇公所教师温知讨论潮间记号 → 理解潮声（`journal.tide_speech == true`，旧档已解锁潮语与法术完整保留）后前往珊湾岛向老海龟潮甲问清夜里借道的缘由 → 潜入海底洞穴三层（`sea_cave_3`）携 `stone × 2` 与海灵澜影补稳回声石界 → 真实过一夜后回访温知，二选一在西岸浅滩立起友好信物（`白石安澜界` 叠石界标 / `听潮海螺架` 悬垂青螺木架），原子结算共享金币 `+45`、个人背包田园沙拉 `salad × 2` 与温知/潮甲/澜影好感。
   - 完成后西岸浅滩呈现对应实景，浅滩旁右键菜单可随时切换（`coast_style`）；`J` 手记实时汇总全部四条长线阶段指引与完成状态，`ResidentDialogue` 同步接入相关居民回访对白。

## 主要新增与修改文件

| 文件 | 说明 |
|---|---|
| `docs/narrative/jin-wan-liu-yi-wan.md`、`chong-xin-you-ren-kao-an.md`、`hai-li-ye-you-lin-ju.md` | `P2-10`、`P2-11`、`P2-12` 完整五阶段节点脚本、对白、回应、旧档条件与并发契约。 |
| `assets/portraits/harbor/*.png`、`assets/characters/harbor/*.png`、`tools/build-020-art.py` | 新增 16 位潮芽镇居民 `64×64` 原创海港肖像与 `64×128` 四向行走精灵表，更新 `manifest.json` 与 `SOURCE.md`。 |
| `scripts/character_art.gd`、`scripts/portrait_art.gd` | 全镇 18 位居民统一路由至 `harbor` 原创资产目录。 |
| `scripts/long_stories.gd`、`scripts/ocean_residents.gd`、`scripts/restaurant.gd` | 四条长线完整状态机、`v16/v17 -> v18` 严格恢复、海上居民长线对话动作、餐厅水牌查看与席面切换。 |
| `scripts/world_state.gd`、`scripts/main.gd`、`scripts/resident_dialogue.gd`、`scripts/world_view.gd` | `world_v18.json` 升级、码头/浅滩查看与切换动作、多长线与海上长线对话分发、餐厅席面牌与西岸双地标实景绘制。 |
| `tests/harbor_art_checks.gd`、`tests/chronicle_checks.gd`、`tests/release_020_ui_checks.gd`、`tests/stories_network_probe.gd` | 全 18 镇民海港像素/二值透明断言（1124 项）、四条长线原子校验（37 项）、两分辨率全链路实景 UI（147 项）与含海上长线的双进程 ENet 验证。 |

## 验证与问题修正记录

1. **过程中的真实发现与修正**
   - 联系表目视检查初版 16 镇民世界帧时发现部分刘海底边偏平直、裤腿偏细：在 `tools/build-020-art.py` 中调整为不对称自然发梢、3px 裤管与千层底白边布鞋，`harbor_art_checks` **1,124 项**检查全部 0 失败。
   - 首轮实景截图检查发现西岸浅滩原坐标 `(272,448)` 偏近营地睡袋、`(188,496)` 易与左下通知浮层重合，且餐厅席面牌偏近备餐案板提示：将 `COAST_SITE` 移至西岸北侧开阔干沙滩 `Vector2(184, 244)`，并将餐厅席面牌移至前吧台左侧木饰面，复验截图无任何文字或控件互压。

2. **最终交付包与完整证据**
   - 最终可执行包：`build/Tidehaven-0.20.0.exe`，**129,377,224 字节**，SHA256：**`AB5E5A1FA9CC0F5460D908E78702A121D7EEE45B11E0D3F73A42E32E3CA0553C`**（原 `0.19.0` 包 `8F70487C...` 与 `0.18.0` 包 `366F9565...` 完整保留未变）。
   - 源码规则与素材回归（20 组全过）：`harbor_art_checks` 1124、`chronicle_checks` 37、`audio_checks` 32、`resident_dialogue_checks` 284、`resident_stories_checks` 1527、`story_world_checks` 423、`restaurant_checks` 2364、`ocean_progression_checks` 92、`appearance_checks` 419、`prop_art_checks` 757、`character_test` 116、`new_residents_checks` 162 及基础 `state/inventory/survival/progression/ocean/navigation/island/persistence` 全部 0 失败（`artifacts/rules-020-20261126-162835`）。
   - 最终包内嵌 PCK 图形界面验证（`--main-pack build/Tidehaven-0.20.0.exe`）：`release_020_ui_checks` 两尺寸（`1280×800`、`960×600`）**147 项、0 失败**（`artifacts/release-020-ui-1795681793`）；`dialogue_skin_ui_checks` 全 23 名角色对话与肖像 **427 项、0 失败**（`artifacts/ui-018/skin-2045174`）；`ui_review_checks` **128 项**、`map_overlay_checks` **7 项**全部 0 失败。
   - 历史真档只读副本迁移：个人 `world_v11.json`、`0.18` 实机 `v16`、`0.19` 实机 `v17` 三份副本经最终包迁移写入 `v18` 并重读完全一致，原文件 SHA256 前后逐字节不变（`7A0C8699...`、`EC270ABB...`、`C2716A84...`）。
   - 最终包本机双进程 ENet 与独立续档：主机 **12 项**、客机 **8 项**、独立进程 `resume` **3 项**全部通过（`artifacts/progression-network-20261126-163157-576-ad797f75`），覆盖客机独立海港换装、个人故事、城镇长线《候潮院》与雾岬岛白帆海上长线《重新有人靠岸》同步推进、重复 RPC 拦截及重连恢复。
   - 最终包空背包正常开局生存流程（默认真实音频驱动）：**131.99 秒**完成 9 格木筏开局→15 次抛钩打捞→手工造工具与三设施→操船抛收锚→净水饮用→垂钓获鱼烹饪食用→扩建甲板→木箱存取→正常保存并 `Continue` 精确恢复（`artifacts/playthrough-20261126-163212-029/report.json`，`passed=true`，`stderr` 为空）。

## 仍需外部验收的边界

- 全镇 18 位近代海港角色、5 位海上伙伴肖像与四条长线实景已完成本地技术与助手目视核验，**不代替用户的真实审美、操作手感与实际扬声器听感验收**。
- 本机双进程 ENet 验证不代表跨电脑局域网/虚拟局域网验收。
- `P2-13～P2-48`（其余 NPC 个人连续故事、四位候选新角色亲自登岛入场、跨角色支线与小店商业路线）仍保持 `docs/TODO.md` 待办。

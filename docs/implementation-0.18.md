# 0.18 界面、地形接边与居民日常

2026-10-29。0.18最终Windows包本地验收完成，原开始菜单/开始游戏.cmd与默认回放入口已切0.18.0。保存退出旧窗口后重开；旧包和个人原档保留。按用户要求先打磨已有体验，之后设计长线；本轮未观察到额度重置，后续仍遵守重置即停改。

## 范围和回退

保留16×32成人→32×64世界比例、32岛格、64筏格和v16存档。沿用Godot、UIStyle、CharacterArt、IslandSurface、Journal、个人Stories，不加依赖/新剧情框架。备份在artifacts/ui-018/baseline，旧0.17包与个人存档保留；没有全库清理或提交推送。

- UIStyle改为授权原生MenuTiles/Cursors图集：菜单、背包/制作、工具栏、纸框、悬停/选中、暗底提示复用同一套。氧气使用同源纸框及危急红字；雪地浮字补统一深色描边。
- DialogueFrame用原生边框切片；TownDialogue下置，18镇民用与完整身体同源的64×64肖像、2倍显示，姓名/职业分区。5位海上角色缺配套肖像，使用全宽文本，不冒用镇民肖像。
- 故事标题从正文拆出；短回应按真实最小高度安排，正文/回应独立滚动，至少保留三行故事情境。现有租院/赠品/交易与关闭时取消迟到回包保留。
- 全角色点击发现森柯与陆遥白天同点重叠：森柯用明确且合法的广场工作点，主点击按鼠标距离选择；日程、交互和地图仍共用ResidentRoutes。
- IslandSurface土路/草地用八邻接四分格，补对角内凹和道路/水岸断开；广场原生石沿保留中央TMX，池岸去高频尖齿、冬季用雪片。绘制不改物理水面、农田、道路或保存数据，详见terrain-seams-0.18.md。
- ResidentDialogue写入23人各两句基础闲聊、按本人结局/现有世界进展回访；首次保留介绍、按游戏日轮换，每日好感仍只加一次。复用已有journal.talked，不新增听过记忆或长线状态。
- docs/narrative四份Markdown先写人设、关系、9个早期节点与四条未来路线。39条长线仍待开发，完整超市/商业竞争单列低优先级提案。

## 主要文件与复用

| 文件 | 用途 |
|---|---|
| scripts/ui_style.gd、dialogue_frame.gd、portrait_art.gd、town_dialogue.gd、game_hud.gd | 公共材质、同源肖像、对话布局和海陆HUD；删除被替代的通用对话布局，不另建UI框架。 |
| scripts/island_surface.gd、world_view.gd | 复用现有地表出口与原图，补邻接和收口；不迁移地图。 |
| scripts/resident_dialogue.gd、journal.gd、island_town.gd、ocean_residents.gd | 小型条件台词表和原交谈分发；去掉所有人共用的高好感套话。 |
| scripts/resident_routes.gd、main.gd | 修复居民同点/鼠标选择及对话期间工具栏显示。 |
| tools/import-dialogue-art.py、assets/vendor/stardew-island/dialogue-manifest.json | 固定来源、20张原PNG和哈希；复用已有下载工具。 |
| tests/resident_dialogue_checks.gd、dialogue_skin_ui_checks.gd、terrain_seam_checks.gd、terrain_detail_checks.gd、terrain_seam_ui_checks.gd | 条件对白、真实点击与绘制不改变玩法的回归。 |
| docs/narrative、art-direction.md、TODO.md、design.md、verification.md、AGENTS.md | 人物/剧情脚本、比例v1.12、唯一排期、实装和证据边界。 |

## 验证记录（源码阶段）

规则：terrain_seam_checks 2092、island_surface_checks 45、terrain_detail_checks 446、resident_routes_checks 309、resident_dialogue_checks 284、island_town_checks 190、remaining_checks 24、homestead_checks 33、resident_stories_checks 1527、story_world_checks 423，均0失败；日志artifacts/ui-018/同名文件。

初版故事UI423、综合UI128通过。新增全角色界面285项首两次各6失败，定位森柯/陆遥同点；分开工作点后285项通过，artifacts/ui-018/skin-4139150。这些是源码阶段夹具；最终包和新增实际日常断言结果另记在下方。

地形原4场景97项通过。扩展48图时145项有8失败：plaza-south测试站点在铁匠铺内；只修测试站点到合法主路，不动碰撞。最终包修正后145项、0失败，48张两尺寸四季实景在artifacts/terrain-018/ui-2749085；助手查看广场春/冬两边与冬季池岸，原失败记录仍保留。

## 明确的后续边界

同源肖像不会改变NPC世界身高，5位海上伙伴肖像待补。完整新NPC、长篇事件、四条路线的新经营/职业系统、听过对白的专门记忆仍是文字设计；本轮没有新增这些玩法。美术验收范围是本次页面与指定地形，不代表全岛及全部海岸完成；用户观感、两台电脑联机和完整音效仍需另验。

首打包候选：128965560字节，SHA256 A5F0771927DB8CDE69DF375FDC5F4A3D6C345329FEC6052618C0AD2C67D27C0C。其379项全角色/实际日常和128项综合UI通过（skin-3401270、ui-review-1793287772）；随后实景发现对话下沿露出工具栏，新增交谈隐藏/关闭恢复，并补未来缺肖像时的空图回退。该候选未作为最终交付，下方记录最终哈希与验证。

最终交付：build/Tidehaven-0.18.0.exe，128965944字节，SHA256 **366F9565940C9B362E6BF17DF089BA86BB1446C60DFA373DE7B0E285F48D6FB0**。415项对话/实际日常/工具栏检查、145项地形检查通过；前者证据artifacts/ui-018/skin-2655410，覆盖两尺寸23人实际点击、配套肖像、日常条件、每日好感、关闭恢复工具栏、海面/水下/暂停。助手已查看最终包陆舟和海上苔露对话、海面/水下及仓储，工具栏没有残留。

同一最终包另通过：故事UI423项（artifacts/npc-017/ui-3108570）、综合UI128项（artifacts/ui-review-1793288179）、地图遮罩7项（artifacts/map-overlay-1793288245）。本机ENet主9/客8/独立续档3（artifacts/progression-network-20261029-233737-111-599f6566）；v11/v16仅用副本加载/保存/重进，原文件字节不变（artifacts/ui-018/migration-20261029-233811）。

正常空背包入口141.539秒通过：14次打捞、5次钓鱼尝试，实际自制工具与三设施、操船收放锚、净水/烹饪、扩建、杯子入箱取回、保存继续后精确背包/设施保持。证据artifacts/playthrough-20261029-233825-736/report.json，passed=true；这条流程未注入库存、跳过计时或关闭敌人。没有以受控剧情夹具冒充自然长篇通关。UI专项使用Dummy音频；普通流程使用默认设备无初始化报错，但游戏尚缺完整音效，不宣称听感通过。

启动：tools/launch.ps1与tools/playthrough.ps1默认0.18.0，开始菜单快捷方式和开始游戏.cmd仍调用同一launch.ps1。project/export版本0.18.0；保存格式仍v16。旧0.17包与原档保留。原生20张PNG哈希一致，git diff --check无错误（仅CRLF提示）；无新增依赖、提交、推送或远端发布。

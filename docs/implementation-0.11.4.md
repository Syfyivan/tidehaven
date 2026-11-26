# 0.11.4 海陆视觉衔接

用户当前要求：岛上玩法暂可；NPC形象变化记低优先级，先统一木筏、海上小岛缩景、海面、海底。

实施/精简计划（先于删除旧绘制记录于TODO）：先用既有物件比例与运动测试保护行为，再从原图集选择材质；海上縮景与海图复用同一构图。删除被替代的程序木纹、粗树和纯多边形礁石绘制，保留存档、真实坐标、既有漂摆/交互、现有HUD。不新增框架或依赖。

当前实现：MaritimeArt集中来源裁切/世界2倍倍率/地图缩景倍率/纹理缓存；甲板与扩建/制作共用原码头木料；岛影换成沙岸、林地、屋顶、港口及院栏；海面低对比水纹和海底冷色沙石形成同一材质家族。背景降对比保留可采物清晰度。水下仍为横版，植物与石形是本轮已有素材适配，完整珊瑚生态和专用泳姿没有冒充完成。

实景迭代：首轮发现原沙块裁切含邻格水面、旧通用黑边提亮抹平木纹，已改为完整沙块与保留木纹的日照处理。草/木/建筑原图保持字节不变。来源、比例v1.5、AGENTS和唯一TODO同步。验收日志与交付版本见verification.md，视觉仍等用户体验。

旧UI驱动修正：商店/澡堂/岛图分页改读IslandMap当前门位，荒草夹具从已经扩展成镇区的旧页移到真实林地。仍经正常鼠标/按键清草和农事，不改变生产规则、授物资流程或缩短计时。

打包自然回放首次在采矿遇到随机额外奖励填满背包：物资按规则留在原处。驱动现于下潜前步行到已造箱子，经实际背包/箱格存入钓竿、桨、种子、宝箱，并检查整叠保留；后续杯子搬箱验证也寻找空格，保留先前存物。未修改生产背包容量/奖励规则。失败证据保留，最终结果另记验证记录。

交付：0.11.4，369.58秒自然完整回放、60张夹具/13项入口存读、879项规则、215项图形输入、本机双人34/24/6通过。开始菜单所用启动脚本已切新版。旧游戏窗口与玩家存档保留，无提交/推送。

主要改动文件：
- scripts/maritime_art.gd：同源材质、浸水光照和缩景的共用出口。
- scripts/world_view.gd、scripts/prop_art.gd、scripts/art_catalog.gd、scripts/chart_panel.gd：删除旧重复绘制，接入实际场景、海图、配方和扩建预览。
- AGENTS.md、docs/art-direction.md、docs/TODO.md、assets/sources.md、assets/vendor/stardew-island/SOURCE.md、docs/reuse.md：比例v1.5、来源及优先级。
- tests/maritime_art_checks.gd、tests/maritime_palette.gd、tests/prop_art_checks.gd、tests/island_ui_checks.gd、tests/playthrough.gd、tests/ui_gallery.gd：裁切/比例、原图预览、真实输入及小窗口检查。
- project.godot、export_presets.cfg、scripts/main.gd、tools/launch.ps1、tools/playthrough.ps1、tools/check.ps1、README.md、docs/verification.md：交付版本、正常入口与证据。

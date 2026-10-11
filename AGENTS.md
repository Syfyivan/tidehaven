# Tidehaven / 潮间小屋

One Godot 4.7 project, GDScript, Windows-native preview. Design and code share this repository.

- Preserve single-player and two-player free movement between deck, water and the unlocked island.
- Reuse Godot's input, rendering, UI, ENet networking and serialization; add no external dependencies without user authorization.
- Host owns world mutations; clients submit input and action names, never rewards or state.
- Rest, readiness to end the day, and persistence are separate concepts.
- Personal menus pause only solo mode. Membership changes cancel sleep readiness.
- Keep resources and artwork original or explicitly licensed. Log reuse decisions in docs/reuse.md.
- Keep PIPOYA raw PNGs, source archives, local saves, build outputs and validation artifacts out of Git. Restore the reviewed character images with tools/setup-characters.ps1; preserve the upstream license notices and clone setup instructions.
- Prove the complete normal-entry loop. Rule tests, same-machine networking, remote networking and human playtesting are separate evidence.
- No game infrastructure or broad framework work before the current playable loop is verified.
- At most two subagents; only one intensive validator at a time. Do not stop unrelated processes.

## 美术接入与验收

- 接入新素材前，按 [docs/art-direction.md](docs/art-direction.md) 检查风格、像素密度与人物/物件比例、视角、所需动作及状态、授权五项。先用实际素材在目标游戏场景验证，再决定接入；单看素材包预览或尺寸匹配不算通过。
- 占位素材、旋转站姿代替游泳、改色代替独立角色、相似图标代替关键物品，都必须明确登记缺口，不能算美术完成。程序绘制与下载素材遵守同一标准，来源方式不代替质量验收。
- 不能为了复用素材牺牲玩法：保留俯视陆地/甲板与横版水下、逐格开荒、方向打捞、工具动作及自由分工。缺适配素材时补画或换素材；不要删动作、改视角、缩减交互来迁就素材包。
- docs/art-direction.md 保存参考画面、比例/像素标准及各类素材的“已验证／待调整／需补画”清单。只有验证范围、实际画面证据与验收人明确时才能标已验证；局部认可不扩展为整套认可。
- 每次新增/替换素材、发现缺口或收到视觉反馈，都在同一轮同步该清单与 [docs/TODO.md](docs/TODO.md) 的对应条目；来源与授权变化同步 assets/sources.md，复用取舍同步 docs/reuse.md。记录日期、证据、缺口和下一步，不另建重复排期。

## 待办与优先级维护

- 0.10.1交互约定：岛上选中实际背包中的锄头/具体种子/水壶/暖棚后点击地块，不能恢复独立农事标签排或空手自动浇水。物品选择不穿透为世界操作；用完/移出背包清除选择，整理后仍指向原物品类型，种子不能悄悄换品种。

- 0.10 用户澄清优先：岛上必须是大量待自行清理/锄地的荒地，禁止预制赠送田代替开荒。岛屿内容包括小镇/职业居民/森林/矿洞/湖河溪流/水泊/澡堂超市诊所；地图标记、门前服务、完整室内、日程剧情和洞内层级分别记录状态，不可相互冒充完成。每次扩展地形必须保护既有农田并检验旧档迁移。

- 当前0.10已交付自行开荒、八名职业居民及门前服务、真实湖河溪流与桥；室内、通勤剧情、洞内仍按TODO保留。正常入口、本机联机和v9迁移已验证，真人手感与跨电脑网络仍待验证。继续保留0.9基础：岛上工具耗时采集、逐格开荒农耕、水壶、四季/按天成熟/暖棚、大岛分页与二级地图。不得用瞬时采集、共享单块田、按秒成熟冒充此循环；保留0.8.1沿途多物打捞。实际面积、生成地貌和独特内容密度分别报告。

- 项目唯一待办清单是 [docs/TODO.md](docs/TODO.md)。每次项目工作开始前先阅读它；当前用户指示优先于清单和历史设计，发现变化立即同步清单。
- 持续保留的 0.8.1 打捞约定：钩子朝方向抛出，不锁定物资；抛出、漂浮、收回均持续碰撞并可携带多件，首件不能截停钩子。保留真实飞行与收绳、鱼叉捕鱼、耗时采集及工具加速；船锚 G 与岸边系泊绳分开，个人罗盘解锁全海图。变更这些机制时同步实际输入、主机裁决与存读回归。
- 当前先做 P0：完善打捞/钓鱼、下潜、扩建和搭建、手工制作与工作台、UI、物资素材、漂流/手工操船工具和简单交互动效。人物 0.5.1 已获用户认可，保留。海图、首岛可达与登岛已由用户提升到当前P0；岛上完整饭店和木匠入住分后续阶段。P1 的鲨鱼/怪物与洞穴、P2 的完整人物动画/魔法/任务故事暂不实施，除非用户明确调整优先级。
- 在接收反馈、开始实际实现、调整范围、发现问题或完成验证后，同一轮及时更新对应条目的状态、下一步、阻碍与顶部日期；补一条简短变更记录。不要只在聊天里报告而不更新项目清单。
- 区分已有基础、尚未实现、待验证和已完成；开始实际开发才标进行中，完成必须附交付版本、相关验证证据和剩余限制。规则测试通过不等于真人手感验收。
- 保留条目 ID、完成记录和被推迟的想法；不要静默删除待办，不在其他文档复制维护另一份列表。具体设计与验证分别同步 docs/design.md、docs/verification.md。


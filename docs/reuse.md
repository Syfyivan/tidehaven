# 复用记录

0.10.1：移除农事标签排与空手自动浇水入口，直接复用实际个人背包格、现有物品图标和UIStyle选中样式；选择物品映射到原Farming主机规则。没有新增素材、依赖、存档格式或另一套种田逻辑。

0.10：沿用工具耗时、逐格农耕、Inventory原子试装、共享金币、ENet主机裁决与固定分页。小镇服务是一个轻量规则模块，交谈面板和服务菜单复用ui_style；复用现有两张Pipoya角色图，通过服色/帽子区分居民(尚非八套独立素材)。建筑和桥为项目程序绘制，无外部新资产或依赖；原授权文件与玩家人物不改。水域/门口/地图复用island_map定义。

0.8.1：多物打捞继续复用现有钩尖扫掠碰撞、风流模拟、Inventory容量试装、主机RPC及原素材目录。删除首件截停和单件限制，用cargo列表贯穿显示与结算；不引入新依赖，不另造背包/联机/碰撞系统。

本轮使用本机现有 Godot 4.7.1，不安装新依赖。实际复用的是 Godot 的 ENet 联机、RPC、输入分发、Control UI、字体回退、CanvasItem 绘图、JSON、文件访问和导出能力。

文档依据：
- https://docs.godotengine.org/en/stable/tutorials/networking/high_level_multiplayer.html
- https://docs.godotengine.org/en/stable/tutorials/editor/command_line_tutorial.html
- https://docs.godotengine.org/en/stable/about/complying_with_licenses.html

候选取舍（研究核验不等于运行通过）：

| 候选 | 决定 | 原因 |
|---|---|---|
| https://github.com/gadget-hq/2d-farming-game | 暂不引入 | 教学作物依赖场景 WorldClock，背包没有完整容量处理；统一跨地图、多人、存档仍需改造。其 Sprout Lands 素材另有授权。 |
| https://github.com/rapidvectors/tutorial-components-and-scripts/tree/main/tutorials/croptails | 只作思路参考 | 未确认完整工程和直接复用授权。 |
| https://github.com/peter-kish/gloot | 延后进行接入验证 | MIT、容量和堆叠能力适合后续背包，但当前只有四类聚合计数，整套插件尚不能减少这轮的权威状态衔接工作。版本需固定。 |
| Dave Mod / 3D 海洋插件 | 不引入本原型 | 分别依赖商业原游戏或与已确认的 2D 方向不匹配。 |

新写的代码集中在本游戏自己的时间、资源、合作、存档衔接，以及原创像素画面。没有复制商业游戏源码、角色、地图、贴图、音效，也没有把教学代码宣称为成熟框架。

0.2 增加格子背包后，仍未引入 GLoot：现有系统没有插件资源模型，权威联机、两版存档迁移及原子交换仍需适配；当前六类可堆叠物由一个共享格子模块统一处理，UI 和网络不各自复制物品逻辑。此决定基于本轮功能边界，没有宣称对 GLoot 做过新的接入或性能验证。装备属性、容器嵌套等需求出现时再进行固定版本的接入试验。

分发包附带运行中 Godot 引擎生成的许可证与第三方声明；系统字体不随包重新分发。


## 0.3 实际复用

- [Kenney Tiny Town](https://kenney.nl/assets/tiny-town)、[Tiny Dungeon](https://kenney.nl/assets/tiny-dungeon)、[Tiny Farm](https://kenney.nl/assets/tiny-farm)：官方原包核验 CC0。保留三张小型图集和原 License.txt，由 ArtCatalog 统一裁切；未复制商业游戏美术。详见 assets/sources.md。
- [Raft 官方介绍](https://store.steampowered.com/app/648800/Raft/)：借鉴小筏打捞、制作生存设施、扩建和合作探索的进程。
- [Stacklands 官方页面](https://sokpop.itch.io/stacklands)：借鉴材料组合和用途清楚的配方结构；不引入卡牌拖叠交互，也没有照搬其配方数值。
- 继续复用现有 Inventory 原子交换、Godot UI / ENet / 存档，配方集中定义、视图只读。没有新增依赖，没有另搭工作流框架。

旧版本的原创图形说明只适用于 0.1 / 0.2。0.3 人物和多数物件使用上述 CC0 素材，鱼、海面与场景效果是项目补画。没有使用生成式图片。

## 0.4 实际复用

水下矿点沿用现有实体、距离检查和共同过夜刷新；熔炉使用原净水器/烤架的 `remaining/output` 加工状态与领取规则。脚蹼、强化钩采用钓竿已经使用的个人背包携带规则，不新建装备框架。搬移复用建造的占格和通路检查，只在校验通过后改原对象坐标，不销毁重建箱子或加工设施。

石料、矿石、金属锭、脚蹼、强化钩、熔炉由现有 `art_catalog.gd` 的像素网格 helper 生成，物品与场景共用同一图像缓存。UI 继续使用 0.3.1 的纸面/木框和格子组件。没有新增第三方代码或依赖。

## 0.5 实际复用

沉箱直接使用现有 `treasure` 物品、格子背包容量、开箱兑换和共同过夜刷新；复用实体与房主动作入口，不为海底另建一套掉落或库存系统。漂流仍是原十六个对象的有限循环，新增个体运动参数；渲染读取主机位置，不在客户端随机生成奖励。

原生 `Transform2D` 同时驱动筏体绘制与放置指针逆变换；原生 `StyleBoxFlat` 替代厚重纹理边框。复用已有 CC0 人物、物品、箱体和原创图标，海面、木板、海草及礁体用小范围场景绘制补充。本次没有新增依赖，也没有下载或修改外部位图。

## 0.5.1 实际复用

人物替换为 Pipoya 官方免费角色包中的两张原始 PNG，使用既有 Godot AtlasTexture 和只读场景绘制接入四方向步态。只保留两张图和授权记录，移除 Tiny 人物映射，不另建角色装备/动画框架。素材许可、下载哈希与选图见 assets/sources.md；公开源码时需让使用者从作者页面另行获取原图。

窗口使用原生 canvas_items / expand、size_changed、Transform2D；场景按逻辑范围等比居中，扩展海面直接沿用 world_view 的同一渐变和波纹，界面在独立设计坐标内等比缩放。指针先转视图局部，再逆变换筏体。没有新增依赖，存档仍为 v5。参考 [Godot 多分辨率文档](https://docs.godotengine.org/en/stable/tutorials/rendering/multiple_resolutions.html)。

## 0.6 实际复用

从作者 [Yapi 的官方页面](https://yapilol.itch.io/100-assorted-items-16x16-pixel) 免费取得 `100 assorted items (16x16 pixel)`，官方许可字段明确为 **Creative Commons Zero v1.0 Universal**。选用 11 张作者提供的 32×32 原 PNG：木板、塑料片、废零件、绳圈、石料、金属锭、鱼、种子、胡萝卜、炖菜和锤。CC0 允许商业使用和再分发；保留作者署名作为来源记录，不把它与 Pipoya 的独立许可混为一谈。原图没有重绘、拼图、改色或缩放导出，运行时仍使用 Godot 纹理绘制。

原包 SHA256 为 `d3ddc97685b5766c964ddecd8086a57110f07f1a300535acd5802d7898949367`，49,583 字节；原包、11 张使用中的原图、完整 CC0 文本及各文件 SHA256 保存在 `assets/vendor/material-pack-yapi/`，具体映射与来源见 [素材记录](../assets/sources.md)。原包不包含合适的棕榈叶、船桨与简易锚，因此复用现有固定像素网格 helper 补三张项目原创图标，不拿草、药草或不相关物件冒充。它们是 code-defined pixel grids，不声称真人手绘，也没有使用图像生成或编辑服务。

ArtCatalog 的 `texture()` 与 `item_icon()` 现在统一读取同一个物品缓存，让世界、箱包、工具栏和制作页使用同源图；已有杯子与钓竿的代码图标也通过此路径统一。人物保持 0.5.1 已采用的 Pipoya 原图。

船桨/锚沿用配方、有限背包、主机动作校验和 JSON 存档机制，只新增本游戏的轻量航行状态。3 木板 + 2 塑料 + 1 绳的船桨、3 木板 + 2 废金属 + 1 绳的简易锚均是本游戏配方，不是对 Raft 配方数值或代码的复制。未引入海洋模拟插件、新的库存框架或依赖。素材接入与规则实现不等于运行/真人验收，相关验证单独记录。

## 0.7 海图复用（接入中）

`chart_panel.gd` 复用项目现有 `ui_style.gd` 的面板、文字、按钮和低饱和配色；海面格线、岛屿轮廓、树冠、船标、航标与罗盘由原生 CanvasItem 绘图补充，是项目代码定义的二维图形。没有下载新位图、修改 vendor 素材、使用图像生成服务或引入地图/UI 插件。人物与 0.6 物资素材保持不变。

`archipelago.gd` 集中首岛位置、停泊半径、岛体偏移、步行多边形、码头矩形和地点坐标；同一份数据供规则、世界视图与海图读取。点在岛内的判断使用 Godot 原生 `Geometry2D.is_point_in_polygon`，不自建碰撞或导航框架。海图坐标继续使用原 `navigation` 的实际航行坐标，只添加固定原点与目的地等最小状态；面板只发出选航标意图，不移动世界。

潮芽岛是本轮唯一可到达目标。三座远岛的轮廓是明确锁定的规划标记，未导入或假称已有额外岛屿、餐馆或任务系统。主机仍负责登岛条件、资源和联机动作；面板与几何文件本身不证明上述游戏循环通过，正常入口与多人验证由主程统一执行。


## 0.8 方向打捞与工具

沿用现有 Inventory、Recipes、ArtCatalog、UI、Navigation、ENet/RPC 和存档校验，只把原来的 ID 自动锁定换成项目的小型方向/碰撞状态。线段最近点复用 Godot Geometry2D，不添加物理框架或依赖。四个工具图标是现有固定像素网格方式补充的项目代码定义图标，人物/vendor 图片不改。并未获取或复制 Raft、星露谷或 Stacklands 的私有游戏代码。


## 0.9 岛屿与耕作

继续复用 Godot 原生二维绘制、输入、ENet、Inventory 原子背包操作、配方及既有存档入口。IslandMap统一规则/世界/岛图坐标；Farming集中种植、日结及恢复校验，IslandActivity只处理岛上工具作业。删除岛上瞬时领奖和单一按秒作物分支，没有引入依赖或搬运商业游戏源码。新农具、纤维及季节种子图标由现有16像素网格生成，沿用全部材质边缘处理；人物和vendor原图未改。面积以当前网格衡量，生成地貌不代表独特内容已全部完成。

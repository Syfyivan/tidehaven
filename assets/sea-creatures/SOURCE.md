# 水下敌人素材 0.14

2026-10-22，使用内置 image_gen 生成原创横版鲨鱼、海鳗六状态源图，原PNG完整复制到本目录；完整提示见PROMPTS.md。没有从其他商业游戏提取怪物图，也没有新增素材依赖。

显示裁切、固定逻辑画布、锚点、左右镜像及透明边缘规则集中在scripts/sea_creature_art.gd。大图中的半透明背景光晕不用于游戏：同已有CoastalArt规则，运行时只保留alpha≥0.96的实色像素。动作帧必须在真实水下、同尺寸窗口查看后才标适配；生成原图不等于用户认可。

原始生成文件：
- shark-0.14.png：exec-d9480c38-56ad-46f6-ae80-3a8bc9077c14.png
- moray-0.14.png：exec-61601e56-a471-47c4-8a4f-690c8b207c33.png

两者来源目录均为本线程的.codex/generated_images/01a0fcd0-a34e-7fc0-b53e-e7b3264c689a，入项目后不依赖外部缓存。当前规范与真实场景证据以docs/art-direction.md为准。

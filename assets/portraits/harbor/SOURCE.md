# 近代中国海港人物肖像来源记录（P2-08a + P2-32/33，0.22版，2026-11-26）

对应待办 `P2-08a` 与 `P2-32`、`P2-33`（架空近代中国海港，参考民国简洁劳动服饰）。全套覆盖 2 位玩家形象与全部 20 位潮芽镇居民：
- **玩家基础半身像（0.19）**：`player_male.png`、`player_female.png`
- **首组镇民样板（0.19）**：`yan_zhen.png`（铁匠严砧）、`mu_tong.png`（植物画师沐桐）
- **其余16位既有镇民（0.20）**：`xu_an.png`、`he_mu.png`、`lin_sui.png`、`su_qin.png`、`tang_he.png`、`zhou_chao.png`、`tian_qing.png`、`lu_yao.png`、`chen_yu.png`、`wen_zhi.png`、`qiao_xin.png`、`shi_xun.png`、`sen_ke.png`、`lu_zhou.png`、`gu_xing.png`、`xu_mian.png`
- **0.22新增两位海港居民（P2-32 / P2-33）**：
  - `cen_po.png`（退休领航员岑婆：银发低挽船髻配铜针簪、灰蓝领航翻领外衣、赭橙海风围巾与黄铜引航哨）
  - `a_yuan.png`（招牌画师阿沅：双画笔盘丸子头、颊边一点朱砂颜料印、海魂横纹内衫配暖赭画师背带围裙与帆布画笔带）

原稿由内置 `image-generator` 生成后经 `tools/build-019-art.py`、`tools/build-020-art.py` 与 `tools/build-022-art.py` 去底、边缘净化与 `64×64` 像素网格采样，严格保持二值透明（`alpha == 0` 或 `alpha == 255`，无半透明光晕），逐文件哈希见 `manifest.json`。与 `assets/characters/harbor/` 世界精灵一一配套，不依赖第三方人物肖像文件。

# 近代中国海港世界人物来源记录（P2-08a，0.20完整版，2026-11-26）

对应唯一待办 `P2-08a` 及 `docs/art-direction.md` 比例规范 v1.14。全部文件由项目脚本 `tools/build-019-art.py` 与 `tools/build-020-art.py` 以原生像素网格确定性生成，严格遵循：
- 成人单帧画布 `16×32` → 世界最近邻 2 倍显示 `32×64`，固定脚点 `(8, 31)` → 世界 `(16, 62)`；
- 严格二值透明（`alpha == 0` 或 `alpha == 255`，`partial == 0`），无半透明雾边；
- 全 18 位潮芽镇居民（`xu_an`、`he_mu`、`yan_zhen`、`lin_sui`、`su_qin`、`tang_he`、`zhou_chao`、`tian_qing`、`lu_yao`、`chen_yu`、`wen_zhi`、`qiao_xin`、`shi_xun`、`sen_ke`、`lu_zhou`、`mu_tong`、`gu_xing`、`xu_mian`）各有独立 `64×128` 四向四帧行走图集，体型、发型/帽饰、衣领、围裙/坎肩/搭肩巾/绳盘/软尺与 `assets/portraits/harbor/` 肖像一一对应；
- 玩家海港图层 `harbor_hairstyles.png`（8 款近代海港发型）与 `harbor_shirts.png`（8 款对襟盘扣／斜襟／坎肩／束腰海港短衫）接入 `PlayerArt`，确保四向行走、五阶段挥斧接触、泡澡浸水与换装索引 `2×8×6×8×4×6` 完全兼容。

逐文件尺寸与 SHA256 见 `manifest.json`。全 18 位镇民世界形象与肖像现均为项目内原创可分发资产，克隆源码无需额外导入第三方 NPC 图片。

"""Build 0.21 Tidehaven original ocean resident world sprites (assets/characters/ocean/*.png):
Replaces the last 5 vendor character sprite dependencies in OceanResidentArt with original binary-alpha
pixel art matched 1:1 to the 0.19 ocean portraits (assets/portraits/ocean/*.png):
- bai_fan.png   : 32x32 (2 frames of 16x32 -> 32x64 world), silver-haired sea merchant in high-collar teal coat
- chi_sheng.png : 32x32 (2 frames of 16x32 -> 32x64 world), crimson-bandana eyepatch pirate in red sea coat
- chao_jia.png  : 64x32 (2 frames of 32x32 -> 64x64 world), golden-ochre elder sea turtle with moss carapace
- tai_lu.png    : 32x16 (2 frames of 16x16 -> 32x32 world), celadon-mint dew spirit with sprout leaf & rosy cheeks
- lan_ying.png  : 64x32 (2 frames of 32x32 -> 64x64 world), abyssal-teal tide spirit with twin kelp-fin crests
"""
import hashlib
import json
from pathlib import Path
from PIL import Image


def c(hex_str: str) -> tuple[int, int, int, int]:
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def put(im: Image.Image, x: int, y: int, col: tuple[int, int, int, int]) -> None:
    if 0 <= x < im.width and 0 <= y < im.height:
        im.putpixel((x, y), col)


def rect(im: Image.Image, x0: int, y0: int, w: int, h: int, col: tuple[int, int, int, int]) -> None:
    for yy in range(y0, y0 + h):
        for xx in range(x0, x0 + w):
            put(im, xx, yy, col)


def build_bai_fan() -> Image.Image:
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out = c("1f1917")
    sk_s, sk_m, sk_l = c("b57145"), c("d68f5e"), c("eba97a")
    hr_d, hr_m, hr_l = c("565e69"), c("8a939e"), c("c2cbd6")
    ct_d, ct_m, ct_l = c("16333d"), c("234d5c"), c("346a7d")
    sh_m, sh_l = c("cfc5ab"), c("eae2cc")
    frog = c("6e4628")
    pt_d, pt_m = c("1f2830"), c("2e3b47")
    bt_d, bt_m = c("3d281a"), c("593c28")

    for f in range(2):
        ox = f * 16
        sway = f  # subtle sea-breeze coat & hair motion
        # Boots & trousers (grounded at y=31)
        for lx in (4, 9):
            rect(im, ox + lx, 24, 3, 5, pt_m)
            put(im, ox + lx, 24, pt_d)
            put(im, ox + lx, 28, pt_d)
            put(im, ox + lx - 1, 25, out)
            put(im, ox + lx + 3, 25, out)
            rect(im, ox + lx, 29, 3, 2, bt_m)
            rect(im, ox + lx - 1, 30, 4 if lx == 4 else 4, 2, out)
            rect(im, ox + lx, 30, 3, 1, bt_d)
            rect(im, ox + lx, 31, 3, 1, out)
        # Coat torso & high standing collar (y=13..24)
        rect(im, ox + 2, 14, 12, 10, out)
        rect(im, ox + 3, 14, 10, 9, ct_m)
        rect(im, ox + 4, 14, 2, 8, ct_l)
        rect(im, ox + 10, 14, 2, 8, ct_d)
        # Cream undershirt + wooden toggle clasp
        rect(im, ox + 7, 14, 2, 6, sh_m)
        put(im, ox + 7, 14, sh_l)
        rect(im, ox + 6, 17, 4, 1, frog)
        # Flared coat hem (breeze sway on frame 1)
        rect(im, ox + 3, 23, 4, 2, ct_d)
        rect(im, ox + 9, 23, 4 + sway, 2, ct_m)
        if sway:
            put(im, ox + 13, 24, out)
        # High collar flanking neck
        rect(im, ox + 4, 12, 2, 3, ct_d)
        rect(im, ox + 10, 12, 2, 3, ct_d)
        # Arms & weathered hands
        rect(im, ox + 2, 15, 2, 6, ct_d)
        rect(im, ox + 12, 15, 2, 6, ct_m)
        put(im, ox + 2, 21, sk_s)
        put(im, ox + 13, 21, sk_m)
        # Head (y=3..13)
        spans = [(5, 10), (4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11), (4, 11), (5, 10)]
        for dy, (x0, x1) in enumerate(spans):
            yy = 4 + dy
            for xx in range(x0, x1 + 1):
                if dy in (0, 9) or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy >= 7:
                    put(im, ox + xx, yy, sk_s)
                elif dy <= 4:
                    put(im, ox + xx, yy, sk_l)
                else:
                    put(im, ox + xx, yy, sk_m)
        # Neck
        rect(im, ox + 6, 13, 4, 1, sk_s)
        # Eyes & silver brows
        rect(im, ox + 5, 8, 2, 1, hr_d)
        rect(im, ox + 9, 8, 2, 1, hr_d)
        put(im, ox + 5, 9, c("244e66"))
        put(im, ox + 10, 9, c("244e66"))
        rect(im, ox + 7, 11, 2, 1, sk_s)
        # Tousled silver hair (y=2..8, asymmetric organic bangs)
        for xx in range(4, 12):
            put(im, ox + xx, 2, out)
        rect(im, ox + 4, 3, 8, 3, hr_m)
        rect(im, ox + 5, 3, 5, 2, hr_l)
        put(im, ox + 3, 4, out)
        put(im, ox + 12, 4, out)
        put(im, ox + 3, 5, hr_d)
        put(im, ox + 12, 5, hr_d)
        put(im, ox + 4, 6, hr_l)
        put(im, ox + 6, 6, sk_l)  # organic forehead gap
        put(im, ox + 8 + sway, 6, hr_m)
        put(im, ox + 11, 6, hr_d)
        put(im, ox + 3, 7, hr_d)
        put(im, ox + 12, 7, hr_d)
    return im


def build_chi_sheng() -> Image.Image:
    im = Image.new("RGBA", (32, 32), (0, 0, 0, 0))
    out = c("1f1616")
    sk_s, sk_m, sk_l = c("ba7849"), c("de9966"), c("f0b484")
    stubble = c("8f6245")
    rd_d, rd_m, rd_l = c("6b1616"), c("9c2321"), c("c43835")
    vs_d, vs_m = c("1f1f24"), c("32323a")
    belt, buckle = c("4a301d"), c("d6a449")
    pt_d, pt_m = c("222026"), c("34313b")
    bt_m = c("452b1e")

    for f in range(2):
        ox = f * 16
        # Boots & trousers (grounded y=31)
        for lx in (4, 9):
            rect(im, ox + lx, 24, 3, 5, pt_m)
            put(im, ox + lx, 24, pt_d)
            rect(im, ox + lx, 29, 3, 2, bt_m)
            rect(im, ox + lx, 31, 3, 1, out)
            put(im, ox + lx - 1, 30, out)
            put(im, ox + lx + 3, 30, out)
        # Red pirate coat & dark inner tunic (y=14..24)
        rect(im, ox + 2, 14, 12, 10, out)
        rect(im, ox + 3, 14, 10, 9, rd_m)
        rect(im, ox + 3, 14, 2, 8, rd_l)
        rect(im, ox + 11, 14, 2, 8, rd_d)
        rect(im, ox + 6, 14, 4, 7, vs_m)
        put(im, ox + 7, 14, sk_s)
        put(im, ox + 8, 14, sk_m)
        rect(im, ox + 5, 21, 6, 2, belt)
        rect(im, ox + 7, 21, 2, 2, buckle)
        rect(im, ox + 3, 23, 3, 2, rd_d)
        rect(im, ox + 10, 23, 3, 2, rd_m)
        # Arms & hands
        rect(im, ox + 2, 15, 2, 6, rd_d)
        rect(im, ox + 12, 15, 2, 6, rd_m)
        put(im, ox + 2, 21, sk_s)
        put(im, ox + 13, 21, sk_m)
        # Head (y=3..13)
        spans = [(5, 10), (4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11), (4, 11), (5, 10)]
        for dy, (x0, x1) in enumerate(spans):
            yy = 4 + dy
            for xx in range(x0, x1 + 1):
                if dy in (0, 9) or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy >= 7:
                    put(im, ox + xx, yy, stubble if dy == 8 and 5 <= xx <= 10 else sk_s)
                else:
                    put(im, ox + xx, yy, sk_m if dy >= 5 else sk_l)
        rect(im, ox + 6, 13, 4, 1, sk_s)
        # Keen cyan-teal eye on left + black eyepatch on right
        put(im, ox + 5, 9, c("249e98"))
        put(im, ox + 5, 8, out)
        put(im, ox + 6, 7, out)
        put(im, ox + 7, 8, out)
        put(im, ox + 8, 8, out)
        rect(im, ox + 9, 8, 3, 2, out)
        put(im, ox + 10, 9, vs_m)
        # Crimson pirate bandana + fluttering knot tail on left!
        for xx in range(4, 12):
            put(im, ox + xx, 2, out)
        rect(im, ox + 4, 3, 8, 4, rd_m)
        rect(im, ox + 5, 3, 5, 2, rd_l)
        rect(im, ox + 4, 6, 8, 1, rd_d)
        put(im, ox + 3, 4, out)
        put(im, ox + 12, 4, out)
        put(im, ox + 3, 5, rd_d)
        put(im, ox + 12, 5, rd_d)
        # Side knot tail (flutters 1px between f=0 and f=1)
        ty = 6 + f
        rect(im, ox + 1, ty, 2, 2, out)
        put(im, ox + 1, ty, rd_l)
        put(im, ox + 2, ty, rd_m)
        put(im, ox + 0, ty + 1, out)
        put(im, ox + 1, ty + 1, rd_d)
    return im


def build_chao_jia() -> Image.Image:
    # 64x32 (two 32x32 frames). World rect is at - (32, 48) size (64, 64), so ground y=24..26.
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out = c("291c14")
    sh_d, sh_m, sh_l, sh_hi = c("2f471c"), c("496b2c"), c("658f3f"), c("82ad58")
    rim_m, rim_l = c("6e522b"), c("9c7840")
    pl_m, pl_l = c("b8913d"), c("dbb55e")
    sk_d, sk_m, sk_l = c("a87228"), c("d69d42"), c("f0be65")

    for f in range(2):
        ox = f * 32
        hy = f  # gentle 1px head breathing nod
        # Domed carapace (x=9..29, y=8..22)
        shell_rows = [
            (14, 24), (12, 26), (11, 27), (10, 28), (9, 28),
            (9, 29), (9, 29), (9, 29), (9, 29), (9, 29),
            (10, 29), (10, 28), (11, 27),
        ]
        for idx, (x0, x1) in enumerate(shell_rows):
            yy = 9 + idx
            for xx in range(x0, x1 + 1):
                if idx == 0 or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif idx >= 11:
                    put(im, ox + xx, yy, rim_l if idx == 11 else out)
                else:
                    # Hexagonal scute pattern
                    scute_edge = (idx in (4, 8)) or ((xx + (idx // 4) * 3) % 6 == 0)
                    if scute_edge:
                        put(im, ox + xx, yy, sh_d)
                    elif idx <= 3 and 14 <= xx <= 22:
                        put(im, ox + xx, yy, sh_hi)
                    elif xx <= 23 and idx <= 7:
                        put(im, ox + xx, yy, sh_l)
                    else:
                        put(im, ox + xx, yy, sh_m)
        # Golden plastron under-rim (y=21..24)
        for xx in range(11, 27):
            put(im, ox + xx, 21, rim_m)
            put(im, ox + xx, 22, pl_l if xx % 4 != 0 else pl_m)
            put(im, ox + xx, 23, pl_m)
            put(im, ox + xx, 24, out)
        # Hind flipper (right, x=22..28, y=22..26) & tail
        rect(im, ox + 28, 20, 3, 2, out)
        put(im, ox + 29, 20, sk_d)
        for yy in range(22, 26):
            for xx in range(22, 28):
                put(im, ox + xx, yy, out if (yy == 25 or xx in (22, 27)) else sk_d)
        # Front flipper (left-center, x=9..15, y=21..27)
        for yy in range(21, 27):
            for xx in range(9, 15):
                if yy == 26 or xx in (9, 14):
                    put(im, ox + xx, yy, out)
                else:
                    put(im, ox + xx, yy, sk_m if xx <= 12 and yy <= 24 else sk_d)
        # Raised elder turtle neck & head on left (x=2..11, y=6+hy..20)
        # Neck connecting to shell
        for yy in range(13 + hy, 22):
            for xx in range(6, 12):
                if xx == 6 or (yy == 21 and xx <= 9):
                    put(im, ox + xx, yy, out)
                elif yy % 3 == 0:
                    put(im, ox + xx, yy, sk_d)
                else:
                    put(im, ox + xx, yy, sk_m)
        # Head oval (x=2..11, y=6+hy..14+hy)
        head_rows = [(4, 9), (3, 10), (2, 11), (2, 11), (2, 11), (2, 11), (3, 10), (4, 10)]
        for dy, (x0, x1) in enumerate(head_rows):
            yy = 6 + hy + dy
            for xx in range(x0, x1 + 1):
                if dy in (0, 7) or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy <= 2:
                    put(im, ox + xx, yy, sk_l)
                elif dy == 5 and 3 <= xx <= 7:
                    put(im, ox + xx, yy, out if xx in (4, 5, 6) else sk_d)  # gentle smile line
                else:
                    put(im, ox + xx, yy, sk_m)
        # Wise dark eye + glint + nostril
        rect(im, ox + 6, 9 + hy, 2, 2, out)
        put(im, ox + 6, 9 + hy, c("fff6dc"))
        put(im, ox + 3, 9 + hy, sk_d)
    return im


def build_tai_lu() -> Image.Image:
    # 32x16 (two 16x16 frames). World rect at - (16, 30) size (32, 32), foot at y=15.
    im = Image.new("RGBA", (32, 16), (0, 0, 0, 0))
    out = c("243628")
    bd_d, bd_m, bd_l, dew = c("7ca395"), c("a8cfc1"), c("cce8de"), c("f2fcf8")
    lf_d, lf_m, lf_l = c("386120"), c("5c8f36"), c("82b856")
    blush = c("e68a83")

    for f in range(2):
        ox = f * 16
        bob = f  # gentle 1px bounce
        # Round dew-apple body (y=4+bob..13)
        rows = [(5, 10), (4, 11), (3, 12), (3, 12), (2, 13), (2, 13), (2, 13), (3, 12), (4, 11), (5, 10)]
        for dy, (x0, x1) in enumerate(rows):
            yy = 4 + bob + dy
            if yy >= 15:
                continue
            for xx in range(x0, x1 + 1):
                if dy in (0, 9) or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy >= 7 or xx >= x1 - 1:
                    put(im, ox + xx, yy, bd_d)
                elif dy <= 3 and xx <= 9:
                    put(im, ox + xx, yy, bd_l)
                else:
                    put(im, ox + xx, yy, bd_m)
        # Dewdrop highlight
        put(im, ox + 9, 6 + bob, dew)
        put(im, ox + 10, 7 + bob, dew)
        # Cute dark button eyes & rosy cheeks
        put(im, ox + 5, 9 + bob, out)
        put(im, ox + 10, 9 + bob, out)
        put(im, ox + 4, 10 + bob, blush)
        put(im, ox + 11, 10 + bob, blush)
        rect(im, ox + 7, 10 + bob, 2, 1, bd_d)
        # Sprout stem & leaf on top
        put(im, ox + 7, 2 + bob, out)
        put(im, ox + 7, 3 + bob, lf_m)
        put(im, ox + 8, 3 + bob, out)
        lx = 8 + (0 if f == 0 else 1)
        rect(im, ox + lx, 0 + bob, 4, 3, out)
        rect(im, ox + lx + 1, 1 + bob, 2, 1, lf_l)
        put(im, ox + lx, 2 + bob, lf_m)
        put(im, ox + lx + 3, 0 + bob, lf_d)
        # Leafy feet grounded at y=14..15
        for fx in (4, 9):
            rect(im, ox + fx, 14, 3, 2, out)
            put(im, ox + fx + 1, 14, lf_m)
    return im


def build_lan_ying() -> Image.Image:
    # 64x32 (two 32x32 frames). World rect at - (32, 36) size (64, 64).
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out = c("0b2429")
    tl_d, tl_m, tl_l = c("114042"), c("1b615f"), c("29827c")
    fn_d, fn_m, fn_l = c("164b57"), c("24856e"), c("45bf8c")
    eye_m, eye_l = c("87f0b2"), c("d9ffe8")
    barn_d, barn_l = c("8f5132"), c("cf875f")
    fm_d, fm_m, fm_l = c("5ea6b8"), c("a8dce8"), c("e8f9fc")

    for f in range(2):
        ox = f * 32
        wave = f
        # Twin sweeping bioluminescent kelp-fin wings (curved frond tips!)
        for side in (-1, 1):
            for yy in range(4, 22):
                wing_w = 2 if yy <= 5 else (4 if 8 <= yy <= 16 else 3)
                curve = 2 if yy == 4 else (1 if yy in (5, 6, 19, 20, 21) else 0)
                edge_x = (16 + side * (12 - curve)) - (1 if side == -1 else 0)
                if yy <= 6 and wave:
                    edge_x += side
                for k in range(wing_w):
                    xx = edge_x - side * k
                    if yy in (4, 21) or k in (0, wing_w - 1):
                        put(im, ox + xx, yy, out)
                    elif k == 1:
                        put(im, ox + xx, yy, fn_l if yy % 3 != 0 else fn_m)
                    else:
                        put(im, ox + xx, yy, fn_d)
        # Central abyssal-teal head & mantle (x=10..21, y=5..22)
        head_rows = [
            (13, 18), (11, 20), (10, 21), (10, 21), (10, 21), (10, 21),
            (10, 21), (10, 21), (10, 21), (11, 20), (11, 20), (10, 21),
            (9, 22), (9, 22), (8, 23), (8, 23), (8, 23),
        ]
        for dy, (x0, x1) in enumerate(head_rows):
            yy = 5 + dy
            for xx in range(x0, x1 + 1):
                if dy == 0 or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy <= 3:
                    put(im, ox + xx, yy, tl_l)
                elif dy >= 12:
                    put(im, ox + xx, yy, tl_d if (xx + dy) % 3 == 0 else tl_m)
                else:
                    put(im, ox + xx, yy, tl_m)
        # Coral barnacles on brow
        rect(im, ox + 11, 7, 2, 2, barn_d)
        put(im, ox + 11, 7, barn_l)
        rect(im, ox + 18, 6, 2, 2, barn_d)
        put(im, ox + 19, 6, barn_l)
        # Glowing mint-jade eyes & gentle smile
        for ex in (12, 17):
            rect(im, ox + ex, 11, 3, 3, out)
            rect(im, ox + ex + 1, 11, 2, 2, eye_m)
            put(im, ox + ex + 1, 11, eye_l)
        rect(im, ox + 15, 15, 2, 1, out)
        # Rippling sea-foam lower veil (y=22..28)
        for yy in range(22, 28):
            span = 9 - (yy - 22)
            for xx in range(16 - span, 16 + span):
                ripple = (xx + yy + wave * 2) % 4
                if yy == 27 or xx in (16 - span, 16 + span - 1):
                    if ripple != 0:
                        put(im, ox + xx, yy, out)
                elif yy >= 25:
                    put(im, ox + xx, yy, fm_l if ripple in (0, 1) else fm_m)
                else:
                    put(im, ox + xx, yy, fm_m if ripple != 2 else fm_d)
    return im


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    out_dir = root / "assets" / "characters" / "ocean"
    out_dir.mkdir(parents=True, exist_ok=True)
    builders = {
        "bai_fan": build_bai_fan,
        "chi_sheng": build_chi_sheng,
        "chao_jia": build_chao_jia,
        "tai_lu": build_tai_lu,
        "lan_ying": build_lan_ying,
    }
    manifest = {"version": "0.21.0", "license": "Original project pixel art (redistributable)", "files": {}}
    sprites: dict[str, Image.Image] = {}
    for name, fn in builders.items():
        img = fn()
        # Enforce strict binary alpha assertion
        for y in range(img.height):
            for x in range(img.width):
                a = img.getpixel((x, y))[3]
                assert a in (0, 255), f"Non-binary alpha in {name} at ({x},{y}): {a}"
        dest = out_dir / f"{name}.png"
        img.save(dest, "PNG")
        digest = hashlib.sha256(dest.read_bytes()).hexdigest()
        manifest["files"][f"{name}.png"] = {
            "width": img.width,
            "height": img.height,
            "sha256": digest,
        }
        sprites[name] = img

    (out_dir / "manifest.json").write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    source_md = """# Ocean Resident World Sprites (0.21.0)

Original binary-alpha pixel art world sprites created by `tools/build-021-art.py` to match the 0.19 ocean portraits (`assets/portraits/ocean/*.png`).
Replaces all remaining `assets/vendor/stardew-island/ocean-residents/*` character sprite dependencies so all 23 characters in Tidehaven use original redistributable character & portrait artwork.

- `bai_fan.png` (`32x32`, 2 frames of `16x32` -> `32x64` world): Sea merchant Bai Fan on Mist Island.
- `chi_sheng.png` (`32x32`, 2 frames of `16x32` -> `32x64` world): Pirate Chi Sheng on Reef Island.
- `chao_jia.png` (`64x32`, 2 frames of `32x32` -> `64x64` world): Elder sea turtle Chao Jia on Reef Island.
- `tai_lu.png` (`32x16`, 2 frames of `16x16` -> `32x32` world): Woodland sprite Tai Lu on Wind Island.
- `lan_ying.png` (`64x32`, 2 frames of `32x32` -> `64x64` world): Tide-cave spirit Lan Ying in Echo Sea Cave Floor 3.
"""
    (out_dir / "SOURCE.md").write_text(source_md, encoding="utf-8")

    # Build visual contact sheet comparing 0.19 portrait + 0.21 world frames at 4x zoom
    contact = Image.new("RGBA", (620, 420), c("2b3a3d"))
    for idx, name in enumerate(["bai_fan", "chi_sheng", "chao_jia", "tai_lu", "lan_ying"]):
        cx = 16 + idx * 120
        p_path = root / "assets" / "portraits" / "ocean" / f"{name}.png"
        if p_path.exists():
            p_img = Image.open(p_path).convert("RGBA").resize((96, 96), Image.Resampling.NEAREST)
            contact.alpha_composite(p_img, (cx + 8, 20))
        sp = sprites[name]
        fw = sp.width // 2
        fh = sp.height
        for f in range(2):
            crop = sp.crop((f * fw, 0, (f + 1) * fw, fh))
            zoomed = crop.resize((fw * 3, fh * 3), Image.Resampling.NEAREST)
            contact.alpha_composite(zoomed, (cx + 12, 140 + f * 130))
    scratch_out = Path(r"C:\Users\s_f15\.gemini\antigravity-cli\brain\eafec623-ae74-4c72-b32d-3a1807222f04\scratch\contact_021_ocean.png")
    scratch_out.parent.mkdir(parents=True, exist_ok=True)
    contact.save(scratch_out, "PNG")
    print("Built 5 original ocean resident sprites ->", out_dir)


if __name__ == "__main__":
    main()

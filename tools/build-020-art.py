"""Build 0.20 Tidehaven early-modern Chinese harbor character set (remaining 16 town residents):
1. Extract & binary-alpha quantize 16 64x64 pixel-art portraits from parchment-bg master renders.
2. Author 16 distinct 64x128 (4x4 16x32) 4-direction walking sprite sheets matching each portrait.
3. Update harbor portrait & character manifests + render visual verification contact sheet.
"""
import argparse
import collections
import hashlib
import json
from pathlib import Path
from PIL import Image


PORTRAIT_SOURCES = {
    "xu_an": "xu_an_1795676710475.jpg",
    "he_mu": "he_mu_1795676718708.jpg",
    "lin_sui": "lin_sui_1795676726749.jpg",
    "su_qin": "su_qin_1795676735072.jpg",
    "tang_he": "tang_he_1795676760103.jpg",
    "zhou_chao": "zhou_chao_1795676768578.jpg",
    "tian_qing": "tian_qing_1795676774160.jpg",
    "lu_yao": "lu_yao_1795676801832.jpg",
    "chen_yu": "chen_yu_1795676714118.jpg",
    "wen_zhi": "wen_zhi_1795676722534.jpg",
    "qiao_xin": "qiao_xin_1795676738057.jpg",
    "shi_xun": "shi_xun_1795676744335.jpg",
    "sen_ke": "sen_ke_1795676749891.jpg",
    "lu_zhou": "lu_zhou_1795676757360.jpg",
    "gu_xing": "gu_xing_1795676765737.jpg",
    "xu_mian": "xu_mian_1795676776130.jpg",
}


def c(hex_str: str) -> tuple[int, int, int, int]:
    h = hex_str.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), 255)


def put(img: Image.Image, x: int, y: int, col: tuple[int, int, int, int]) -> None:
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), col)


def rect(img: Image.Image, x0: int, y0: int, w: int, h: int, col: tuple[int, int, int, int]) -> None:
    for yy in range(y0, y0 + h):
        for xx in range(x0, x0 + w):
            put(img, xx, yy, col)


def extract_parchment_64_portrait(src_path: Path) -> Image.Image:
    src = Image.open(src_path).convert("RGBA")
    w, h = src.size
    px = src.load()

    # Sample reference parchment background from top corners
    samples = [px[4, 4][:3], px[w - 5, 4][:3], px[4, 20][:3], px[w - 5, 20][:3]]
    br = sum(s[0] for s in samples) // len(samples)
    bg_g = sum(s[1] for s in samples) // len(samples)
    bb = sum(s[2] for s in samples) // len(samples)

    def is_parchment(r: int, g: int, b: int, tol: int = 28) -> bool:
        return abs(r - br) <= tol and abs(g - bg_g) <= tol and abs(b - bb) <= tol

    bg = [[False] * w for _ in range(h)]
    q: collections.deque[tuple[int, int]] = collections.deque()

    # Seed flood-fill from top, left, and right edges (character torso touches bottom edge inside dark outline)
    for x in range(w):
        r, g, b, _ = px[x, 0]
        if is_parchment(r, g, b, 32):
            bg[0][x] = True
            q.append((x, 0))
    for y in range(h):
        for x in (0, w - 1):
            if not bg[y][x]:
                r, g, b, _ = px[x, y]
                if is_parchment(r, g, b, 32):
                    bg[y][x] = True
                    q.append((x, y))

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                r, g, b, _ = px[nx, ny]
                # Stop firmly at dark ink outlines (luminance < 120)
                if (r + g + b) >= 360 and is_parchment(r, g, b, 26):
                    bg[ny][nx] = True
                    q.append((nx, ny))

    out = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    opx = out.load()
    cell_x = w / 64.0
    cell_y = h / 64.0
    for gy in range(64):
        y0 = int(round(gy * cell_y))
        y1 = min(h, max(y0 + 1, int(round((gy + 1) * cell_y))))
        cy = (y0 + y1) // 2
        for gx in range(64):
            x0 = int(round(gx * cell_x))
            x1 = min(w, max(x0 + 1, int(round((gx + 1) * cell_x))))
            cx = (x0 + x1) // 2
            fg = []
            probes = 0
            for sy in range(y0 + 2, max(y0 + 3, y1 - 2), 2):
                for sx in range(x0 + 2, max(x0 + 3, x1 - 2), 2):
                    probes += 1
                    if not bg[sy][sx]:
                        r, g, b, _ = px[sx, sy]
                        fg.append((r, g, b))
            if len(fg) * 2 >= max(1, probes):
                if not bg[cy][cx]:
                    cr, cg, cb, _ = px[cx, cy]
                    opx[gx, gy] = (cr, cg, cb, 255)
                else:
                    mid = fg[len(fg) // 2]
                    opx[gx, gy] = (mid[0], mid[1], mid[2], 255)

    # Clean any JPEG halo on outer transparent boundary to crisp dark outline
    OUT_INK = (44, 31, 26, 255)
    for gy in range(64):
        for gx in range(64):
            r, g, b, a = opx[gx, gy]
            if a == 0:
                continue
            touches_air = any(
                (0 <= nx < 64 and 0 <= ny < 64 and opx[nx, ny][3] == 0)
                for nx, ny in ((gx - 1, gy), (gx + 1, gy), (gx, gy - 1), (gx, gy + 1))
            )
            if touches_air and is_parchment(r, g, b, 24):
                opx[gx, gy] = OUT_INK

    bbox = out.getbbox()
    if bbox and bbox[3] < 64:
        dy = 64 - bbox[3]
        shifted = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
        shifted.paste(out, (0, dy))
        out = shifted
    return out


def draw_oval_head(im: Image.Image, hy: int, out: tuple, skin_s: tuple, skin_m: tuple, skin_l: tuple, slim: bool) -> None:
    spans = [
        (5, 10),
        (4, 11),
        (3, 12),
        (3, 12),
        (3, 12),
        (3, 12),
        (3, 12),
        (4, 11),
        (5, 10) if slim else (4, 11),
        (5, 10),
    ]
    for dy, (x0, x1) in enumerate(spans):
        yy = hy + dy
        for xx in range(x0, x1 + 1):
            if dy == 0 or dy == len(spans) - 1 or xx == x0 or xx == x1:
                put(im, xx, yy, out)
            elif dy >= len(spans) - 2 or xx in (x0 + 1, x1 - 1):
                put(im, xx, yy, skin_s if dy >= 6 else skin_m)
            elif dy <= 4:
                put(im, xx, yy, skin_l)
            else:
                put(im, xx, yy, skin_m)


NPC_SPECS = {
    "xu_an": {
        "slim": False, "broad": False, "skin": ("c9885b", "eab082", "f7caa2"),
        "hair": ("1e2229", "323842", "505866", "8e96a3"), "hair_style": "parted_silver",
        "top": ("2f3b4d", "43536b", "5a6e8c"), "collar": "zhongshan", "prop": "pen_ledger",
        "pants": ("232b38", "323d4f"),
    },
    "he_mu": {
        "slim": False, "broad": True, "skin": ("c48052", "e5a173", "f3be96"),
        "hair": ("1f1815", "382b24", "544137", "6e5649"), "hair_style": "short_crop",
        "top": ("8c562b", "b5743f", "cf8e57"), "collar": "frog_rolled", "prop": "wood_ruler",
        "pants": ("3b2d23", "524033"),
    },
    "lin_sui": {
        "slim": True, "broad": False, "skin": ("cf8f65", "f0b489", "fcd2b1"),
        "hair": ("171417", "292329", "403740", "594d59"), "hair_style": "bob",
        "top": ("b57428", "de963e", "f0b15e"), "collar": "slanted", "prop": "indigo_apron",
        "pants": ("262d42", "37415e"),
    },
    "su_qin": {
        "slim": True, "broad": False, "skin": ("cf9067", "f0b68e", "fce3cf"),
        "hair": ("14161c", "232733", "373d4f", "4e566e"), "hair_style": "low_bun",
        "top": ("bdb5a2", "dfd8c5", "f2ece0"), "collar": "clinic_coat", "prop": "glasses",
        "pants": ("2b3638", "3d4c4f"),
    },
    "tang_he": {
        "slim": False, "broad": True, "skin": ("bf7c4e", "e09d6e", "f0b98e"),
        "hair": ("121317", "20232b", "343945", "4a5061"), "hair_style": "buzz_stubble",
        "top": ("22344f", "324b70", "466591"), "collar": "open_tunic", "prop": "shoulder_towel",
        "pants": ("1f2838", "2d3a52"),
    },
    "zhou_chao": {
        "slim": False, "broad": True, "skin": ("ad683b", "cf8757", "e3a174"),
        "hair": ("242221", "423e3c", "635e5b", "87817d"), "hair_style": "bamboo_hat",
        "top": ("364c61", "4b6882", "6586a3"), "collar": "hemp_vest", "prop": "beard_stubble",
        "pants": ("2b3540", "3c4a59"),
    },
    "tian_qing": {
        "slim": False, "broad": False, "skin": ("b87346", "db9465", "edb187"),
        "hair": ("171414", "2b2524", "423938", "5c504e"), "hair_style": "headscarf",
        "top": ("546346", "71855f", "8ea37a"), "collar": "open_rolled", "prop": "none",
        "pants": ("3b3328", "524738"),
    },
    "lu_yao": {
        "slim": True, "broad": False, "skin": ("c7865c", "e8aa80", "f5c6a2"),
        "hair": ("4f565e", "7b848f", "a5aeb8", "cfd6de"), "hair_style": "elder_bun_pins",
        "top": ("523e49", "6e5563", "8a6d7d"), "collar": "cream_vest", "prop": "map_strap",
        "pants": ("302930", "453b45"),
    },
    "chen_yu": {
        "slim": False, "broad": False, "skin": ("c78458", "e8a679", "f5c29d"),
        "hair": ("14171f", "242936", "384052", "4f5970"), "hair_style": "chef_band",
        "top": ("bfb8a6", "e3dccb", "f5efe1"), "collar": "chef_double", "prop": "navy_apron",
        "pants": ("212b3d", "303e57"),
    },
    "wen_zhi": {
        "slim": True, "broad": False, "skin": ("cf9067", "f0b58b", "fcd4b6"),
        "hair": ("141821", "222938", "354054", "4b5973"), "hair_style": "half_long",
        "top": ("bfb59b", "e3d8bd", "f5ecd6"), "collar": "stand_bow", "prop": "map_strap",
        "pants": ("232d42", "33415e"),
    },
    "qiao_xin": {
        "slim": False, "broad": False, "skin": ("c9875b", "eab082", "f7cba6"),
        "hair": ("1c1614", "332824", "4d3d37", "66524a"), "hair_style": "postal_cap",
        "top": ("34593d", "497a55", "629970"), "collar": "frog", "prop": "mail_strap",
        "pants": ("26382b", "364f3d"),
    },
    "shi_xun": {
        "slim": False, "broad": True, "skin": ("ba7649", "dc9768", "edb287"),
        "hair": ("171210", "2b221e", "42352f", "594840"), "hair_style": "miner_cap",
        "top": ("784d20", "9e682e", "bd8142"), "collar": "charcoal_vest", "prop": "full_beard",
        "pants": ("292b30", "3b3e45"),
    },
    "sen_ke": {
        "slim": False, "broad": False, "skin": ("c48256", "e6a577", "f5c29b"),
        "hair": ("171c21", "283038", "3d4954", "556573"), "hair_style": "windswept",
        "top": ("274732", "386347", "4d825f"), "collar": "zhongshan", "prop": "cross_strap",
        "pants": ("262e28", "364239"),
    },
    "lu_zhou": {
        "slim": False, "broad": True, "skin": ("bf7a4b", "e39c6b", "f2b98d"),
        "hair": ("14161a", "242830", "383e4a", "4f5766"), "hair_style": "short_crop",
        "top": ("873520", "ad482e", "c96044"), "collar": "navy_vest", "prop": "rescue_rope",
        "pants": ("1f2b3d", "2e3f59"),
    },
    "gu_xing": {
        "slim": True, "broad": False, "skin": ("cf8f65", "f0b489", "fcd3b3"),
        "hair": ("14171c", "242933", "38404f", "4e586b"), "hair_style": "goggle_bob",
        "top": ("8a724d", "ad9166", "c7ab80"), "collar": "teal_vest", "prop": "none",
        "pants": ("2b3b3d", "3d5254"),
    },
    "xu_mian": {
        "slim": True, "broad": False, "skin": ("cf9067", "f0b58b", "fcd4b6"),
        "hair": ("1c1615", "332826", "4d3d3a", "69534f"), "hair_style": "braid_bun",
        "top": ("3d7874", "569c97", "73bab5"), "collar": "slanted", "prop": "tape_measure",
        "pants": ("26383b", "364f54"),
    },
}


def draw_npc_frame(spec: dict, direction: int, step: int) -> Image.Image:
    if direction == 3:
        return draw_npc_frame(spec, 1, step).transpose(Image.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    bob = 1 if step in (1, 3) else 0
    OUT = c("261c19")
    SKIN_S, SKIN_M, SKIN_L = (c(x) for x in spec["skin"])
    HAIR_O, HAIR_D, HAIR_M, HAIR_L = (c(x) for x in spec["hair"])
    TOP_D, TOP_M, TOP_L = (c(x) for x in spec["top"])
    PANT_D, PANT_M = (c(x) for x in spec["pants"])
    WHITE_EYE, EYE = c("f5efe6"), c("211614")
    SHOE_D, SHOE_L = c("211b18"), c("4a3d35")

    slim = spec["slim"]
    broad = spec["broad"]
    hstyle = spec["hair_style"]
    prop = spec["prop"]
    hy = 3 + bob
    draw_oval_head(im, hy, OUT, SKIN_S, SKIN_M, SKIN_L, slim=slim)

    # Hair & Headwear by facing
    if direction == 0:  # Down
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for xx in range(4, 12):
            put(im, xx, hy, HAIR_M if 4 < xx < 11 else HAIR_O)
        for xx in range(3, 13):
            put(im, xx, hy + 1, HAIR_L if xx in (6, 9) else HAIR_M if 3 < xx < 12 else HAIR_O)
        for xx in (3, 4, 11, 12):
            put(im, xx, hy + 2, HAIR_O if xx in (3, 12) else HAIR_D)
            put(im, xx, hy + 3, HAIR_O if xx in (3, 12) else HAIR_D)
        put(im, 3, hy + 4, HAIR_O); put(im, 12, hy + 4, HAIR_O)
        if hstyle == "parted_silver":
            for xx in (5, 6, 7, 10):
                put(im, xx, hy + 2, HAIR_M)
            put(im, 4, hy + 3, HAIR_L); put(im, 11, hy + 3, HAIR_L)
        elif hstyle == "short_crop":
            for xx in (5, 7, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
        elif hstyle == "windswept":
            for xx in (5, 6, 8, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
            put(im, 6, hy + 3, HAIR_D); put(im, 6, hy - 2, HAIR_O); put(im, 7, hy - 2, HAIR_D)
        elif hstyle == "buzz_stubble":
            for xx in (5, 6, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
        elif hstyle in ("bob", "goggle_bob"):
            for xx in (5, 6, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
            rect(im, 2, hy + 2, 2, 6, HAIR_D); rect(im, 12, hy + 2, 2, 6, HAIR_D)
            put(im, 2, hy + 7, HAIR_O); put(im, 13, hy + 7, HAIR_O)
            if hstyle == "goggle_bob":
                rect(im, 4, hy, 8, 2, c("b88b3b"))
                put(im, 5, hy + 1, c("62848f")); put(im, 10, hy + 1, c("62848f"))
        elif hstyle == "half_long":
            for xx in (5, 6, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
            rect(im, 2, hy + 2, 2, 8, HAIR_D); rect(im, 12, hy + 2, 2, 8, HAIR_D)
            put(im, 2, hy + 9, HAIR_O); put(im, 13, hy + 9, HAIR_O)
        elif hstyle in ("low_bun", "braid_bun"):
            for xx in (5, 6, 9, 10):
                put(im, xx, hy + 2, HAIR_D)
            if hstyle == "braid_bun":
                rect(im, 12, hy + 5, 2, 3, HAIR_M)
        elif hstyle == "elder_bun_pins":
            for xx in (5, 6, 9, 10):
                put(im, xx, hy + 2, HAIR_L)
            rect(im, 6, hy - 2, 4, 2, HAIR_M)
            put(im, 4, hy - 1, c("8c5327")); put(im, 11, hy - 1, c("8c5327"))
            put(im, 12, hy, c("8c5327"))
        elif hstyle == "headscarf":
            rect(im, 4, hy - 1, 8, 2, c("d9d2a7"))
            rect(im, 3, hy + 1, 10, 1, c("c4bc8f"))
        elif hstyle == "chef_band":
            rect(im, 6, hy - 2, 4, 1, HAIR_D)
            rect(im, 3, hy + 1, 10, 2, c("273e6b"))
        elif hstyle == "postal_cap":
            rect(im, 4, hy - 2, 8, 2, c("497a55"))
            rect(im, 3, hy, 10, 2, c("34593d"))
            put(im, 7, hy, c("e6be58")); put(im, 8, hy, c("e6be58"))
            rect(im, 3, hy + 2, 10, 1, c("1e3323"))
        elif hstyle == "miner_cap":
            rect(im, 4, hy - 2, 8, 2, c("85775c"))
            rect(im, 3, hy, 10, 2, c("695d47"))
            put(im, 7, hy, c("f5dc7a")); put(im, 8, hy, c("c4973b"))
            rect(im, 3, hy + 2, 10, 1, c("3b3326"))
        elif hstyle == "bamboo_hat":
            rect(im, 6, hy - 3, 4, 1, OUT)
            rect(im, 4, hy - 2, 8, 1, c("d4b070"))
            rect(im, 2, hy - 1, 12, 1, c("bf9958"))
            rect(im, 1, hy, 14, 2, c("a37e40"))
            put(im, 0, hy + 1, OUT); put(im, 15, hy + 1, OUT)

        # Eyes & facial features
        put(im, 5, hy + 4, HAIR_D); put(im, 10, hy + 4, HAIR_D)
        put(im, 5, hy + 5, EYE); put(im, 6, hy + 5, WHITE_EYE)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        if prop == "glasses":
            put(im, 4, hy + 5, c("4a3b32")); put(im, 7, hy + 5, c("4a3b32"))
            put(im, 8, hy + 5, c("4a3b32")); put(im, 11, hy + 5, c("4a3b32"))
        elif prop == "full_beard":
            rect(im, 4, hy + 7, 8, 2, HAIR_D)
            rect(im, 5, hy + 9, 6, 1, HAIR_O)
        elif prop == "beard_stubble":
            for xx in range(5, 11):
                put(im, xx, hy + 8, HAIR_M)
        elif hstyle == "buzz_stubble":
            put(im, 6, hy + 8, HAIR_M); put(im, 9, hy + 8, HAIR_M)
        else:
            put(im, 7, hy + 7, SKIN_S); put(im, 8, hy + 7, SKIN_S)

    elif direction == 2:  # Up (back of head)
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        back_rows = 8 if hstyle in ("bob", "goggle_bob", "half_long") else 7
        for dy in range(back_rows):
            x0, x1 = (4, 11) if dy in (0, back_rows - 1) else (3, 12)
            for xx in range(x0, x1 + 1):
                put(im, xx, hy + dy, HAIR_O if xx in (x0, x1) else (HAIR_D if dy >= 4 else HAIR_M))
        if hstyle in ("low_bun", "braid_bun"):
            rect(im, 6, hy + 5, 4, 3, HAIR_O)
            rect(im, 7, hy + 6, 2, 2, HAIR_M)
        elif hstyle == "elder_bun_pins":
            rect(im, 6, hy - 2, 4, 3, HAIR_L)
            put(im, 4, hy - 1, c("8c5327")); put(im, 11, hy - 1, c("8c5327"))
        elif hstyle == "headscarf":
            rect(im, 3, hy, 10, 5, c("cfc89d"))
            rect(im, 6, hy + 5, 4, 3, HAIR_D)
        elif hstyle == "chef_band":
            rect(im, 3, hy + 1, 10, 2, c("273e6b"))
            put(im, 12, hy + 3, c("273e6b"))
        elif hstyle == "postal_cap":
            rect(im, 4, hy - 2, 8, 2, c("497a55"))
            rect(im, 3, hy, 10, 3, c("34593d"))
        elif hstyle == "miner_cap":
            rect(im, 4, hy - 2, 8, 2, c("85775c"))
            rect(im, 3, hy, 10, 3, c("695d47"))
        elif hstyle == "bamboo_hat":
            rect(im, 6, hy - 3, 4, 1, OUT)
            rect(im, 4, hy - 2, 8, 1, c("d4b070"))
            rect(im, 2, hy - 1, 12, 2, c("bf9958"))
            rect(im, 1, hy + 1, 14, 2, c("a37e40"))

    else:  # Right profile (direction == 1)
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for dy in range(7):
            for xx in range(3, 12):
                if dy <= 2 or xx <= 6:
                    put(im, xx, hy + dy, HAIR_O if xx == 3 else (HAIR_M if dy <= 3 else HAIR_D))
        if hstyle in ("low_bun", "braid_bun"):
            rect(im, 1, hy + 5, 3, 3, HAIR_D); put(im, 1, hy + 6, HAIR_O)
        elif hstyle == "elder_bun_pins":
            rect(im, 4, hy - 2, 4, 2, HAIR_L); put(im, 2, hy - 1, c("8c5327"))
        elif hstyle == "headscarf":
            rect(im, 3, hy - 1, 8, 4, c("d9d2a7"))
            rect(im, 1, hy + 5, 3, 3, HAIR_D)
        elif hstyle == "chef_band":
            rect(im, 3, hy + 1, 9, 2, c("273e6b"))
            put(im, 2, hy + 2, c("273e6b")); put(im, 1, hy + 3, c("273e6b"))
        elif hstyle == "postal_cap":
            rect(im, 4, hy - 2, 8, 2, c("497a55"))
            rect(im, 3, hy, 9, 2, c("34593d"))
            rect(im, 9, hy + 2, 5, 1, c("1e3323"))
        elif hstyle == "miner_cap":
            rect(im, 4, hy - 2, 8, 2, c("85775c"))
            rect(im, 3, hy, 9, 2, c("695d47"))
            put(im, 11, hy, c("f5dc7a"))
            rect(im, 9, hy + 2, 5, 1, c("3b3326"))
        elif hstyle == "bamboo_hat":
            rect(im, 6, hy - 3, 4, 1, OUT)
            rect(im, 4, hy - 2, 8, 1, c("d4b070"))
            rect(im, 2, hy - 1, 12, 1, c("bf9958"))
            rect(im, 1, hy, 14, 2, c("a37e40"))
        elif hstyle == "goggle_bob":
            rect(im, 6, hy + 1, 6, 2, c("b88b3b")); put(im, 10, hy + 2, c("62848f"))
            rect(im, 3, hy + 4, 4, 5, HAIR_D)

        put(im, 6, hy + 5, SKIN_L)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        if prop == "glasses":
            put(im, 8, hy + 5, c("4a3b32")); put(im, 11, hy + 5, c("4a3b32"))
        elif prop == "full_beard":
            rect(im, 8, hy + 7, 4, 2, HAIR_D); rect(im, 9, hy + 9, 3, 1, HAIR_O)

    # Torso & Attire (y = 13+bob .. 22+bob)
    ty = 13 + bob
    collar = spec["collar"]
    sleeve_col = TOP_D
    forearm_skin = collar in ("frog_rolled", "open_rolled")
    if collar == "clinic_coat":
        sleeve_col = TOP_M
    elif collar == "hemp_vest":
        sleeve_col = c("d9d0ba")
    elif collar == "cream_vest":
        sleeve_col = c("e8dec0")
    elif collar == "charcoal_vest":
        sleeve_col = c("43464d")
    elif collar == "navy_vest":
        sleeve_col = c("2a3c5c")
    elif collar == "teal_vest":
        sleeve_col = c("4f7075")

    if direction in (0, 2):
        x_left = 2 if broad else 3
        x_right = 13 if broad else 12
        for dy in range(10):
            yy = ty + dy
            xl = x_left + (1 if dy in (0, 8, 9) and broad else 0)
            xr = x_right - (1 if dy in (0, 8, 9) and broad else 0)
            for xx in range(xl, xr + 1):
                put(im, xx, yy, OUT if xx in (xl, xr) or dy == 9 else (TOP_L if dy <= 2 and xx in (6, 9) else TOP_M))

        if direction == 0:
            if collar == "clinic_coat":
                rect(im, 6, ty, 4, 9, c("a3bfb0"))
                put(im, 5, ty + 1, TOP_L); put(im, 10, ty + 1, TOP_L)
            elif collar in ("hemp_vest", "cream_vest", "charcoal_vest", "navy_vest", "teal_vest"):
                inner = {
                    "hemp_vest": c("ded6c1"), "cream_vest": c("ebe0c2"),
                    "charcoal_vest": c("43464d"), "navy_vest": c("2a3c5c"), "teal_vest": c("527378"),
                }[collar]
                rect(im, 6, ty, 4, 8, inner)
                put(im, 7, ty, SKIN_S); put(im, 8, ty, SKIN_S)
            elif collar in ("frog", "frog_rolled", "zhongshan"):
                put(im, 7, ty, SKIN_S); put(im, 8, ty, SKIN_S)
                for by in (ty + 2, ty + 4, ty + 6):
                    put(im, 7, by, OUT); put(im, 8, by, TOP_D)
            elif collar == "slanted":
                put(im, 7, ty, SKIN_S); put(im, 8, ty + 1, OUT); put(im, 9, ty + 2, OUT); put(im, 9, ty + 4, OUT)
            elif collar == "chef_double":
                put(im, 7, ty, c("273e6b")); put(im, 8, ty, c("273e6b"))
                for by in (ty + 2, ty + 5):
                    put(im, 6, by, c("273e6b")); put(im, 9, by, c("273e6b"))
            elif collar == "stand_bow":
                rect(im, 7, ty + 1, 2, 3, c("243659"))
                put(im, 6, ty + 2, c("243659")); put(im, 9, ty + 2, c("243659"))

            # Signature front props
            if prop == "pen_ledger":
                put(im, 9, ty + 3, c("f0e6cc")); put(im, 10, ty + 3, c("d4a446"))
            elif prop in ("wood_ruler", "map_strap", "mail_strap", "cross_strap"):
                sc = c("d9b87c") if prop == "wood_ruler" else c("c49e68") if prop == "mail_strap" else c("6e4427")
                for d in range(7):
                    put(im, 5 + d // 2, ty + 1 + d, sc)
                    if prop == "cross_strap":
                        put(im, 10 - d // 2, ty + 1 + d, sc)
            elif prop == "indigo_apron":
                rect(im, 5, ty + 3, 6, 6, c("343f5e"))
            elif prop == "navy_apron":
                rect(im, 4, ty + 6, 8, 3, c("273e6b"))
            elif prop == "shoulder_towel":
                rect(im, 9, ty + 1, 2, 6, c("f2f4f7"))
            elif prop == "rescue_rope":
                rect(im, 4, ty + 1, 2, 6, c("c4a166"))
            elif prop == "tape_measure":
                rect(im, 5, ty + 1, 1, 6, c("ebcf75")); rect(im, 10, ty + 1, 1, 6, c("ebcf75"))

        # Arms
        la = 1 if step == 1 else (-1 if step == 3 else 0)
        ra = -la
        lx = 1 if broad else 2
        rx = 13 if broad else 13
        for side_x, shift in ((lx, la), (rx, ra)):
            ay = ty + 1 + shift
            rect(im, side_x, ay, 2, 3, sleeve_col)
            rect(im, side_x, ay + 3, 2, 2, SKIN_M if forearm_skin else sleeve_col)
            rect(im, side_x, ay + 5, 2, 1, SKIN_M)
            rect(im, side_x, ay + 6, 2, 1, OUT)

    else:  # Right profile torso & arm
        for dy in range(10):
            yy = ty + dy
            for xx in range(4, 12):
                put(im, xx, yy, OUT if xx in (4, 11) or dy == 9 else TOP_M)
        if prop == "shoulder_towel":
            rect(im, 7, ty + 1, 2, 5, c("f2f4f7"))
        elif prop == "rescue_rope":
            rect(im, 6, ty + 1, 2, 5, c("c4a166"))
        elif prop == "mail_strap":
            rect(im, 5, ty + 5, 3, 3, c("b58f59"))
        ax = 6 + (1 if step == 1 else -1 if step == 3 else 0)
        rect(im, ax, ty + 2, 3, 3, sleeve_col)
        rect(im, ax, ty + 5, 3, 2, SKIN_M)
        rect(im, ax, ty + 7, 3, 1, OUT)

    # Legs & grounded Chinese cloth work shoes (foot row y=31 always grounded)
    SOLE = c("d9d1c0")
    ly = 23 + bob
    if direction in (0, 2):
        l_end = 30 if step == 1 else 31
        r_end = 30 if step == 3 else 31
        for x0, end_y in ((4, l_end), (9, r_end)):
            for yy in range(ly, end_y - 1):
                put(im, x0 - 1, yy, OUT); put(im, x0 + 3, yy, OUT)
                rect(im, x0, yy, 3, 1, PANT_M if yy > ly else PANT_D)
            rect(im, x0 - 1, end_y - 1, 4, 1, SHOE_D)
            put(im, x0 - 1, end_y, OUT); rect(im, x0, end_y, 2, 1, SOLE); put(im, x0 + 2, end_y, OUT)
    else:
        if step in (1, 3):
            front_x, back_x = (8, 4) if step == 1 else (4, 8)
            rect(im, back_x, ly, 3, 5, PANT_D); rect(im, back_x, 29, 4, 1, SHOE_D); rect(im, back_x, 30, 4, 1, SOLE)
            rect(im, front_x, ly, 3, 6, PANT_M); rect(im, front_x, 30, 4, 1, SHOE_D); put(im, front_x, 31, OUT); rect(im, front_x + 1, 31, 2, 1, SOLE); put(im, front_x + 3, 31, OUT)
        else:
            for yy in range(ly, 30):
                put(im, 5, yy, OUT); rect(im, 6, yy, 4, 1, PANT_M); put(im, 10, yy, OUT)
            rect(im, 5, 30, 6, 1, SHOE_D)
            put(im, 5, 31, OUT); rect(im, 6, 31, 4, 1, SOLE); put(im, 10, 31, OUT)
    return im


def build_npc_sheet(spec: dict) -> Image.Image:
    sheet = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
    for row_dir in range(4):
        for step in range(4):
            frame = draw_npc_frame(spec, row_dir, step)
            sheet.paste(frame, (step * 16, row_dir * 32))
    return sheet


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", required=True, type=Path)
    parser.add_argument("--out-root", required=True, type=Path)
    args = parser.parse_args()

    harbor_p_dir = args.out_root / "portraits" / "harbor"
    harbor_c_dir = args.out_root / "characters" / "harbor"
    harbor_p_dir.mkdir(parents=True, exist_ok=True)
    harbor_c_dir.mkdir(parents=True, exist_ok=True)

    for npc_id, fname in PORTRAIT_SOURCES.items():
        p_img = extract_parchment_64_portrait(args.raw_dir / fname)
        p_img.save(harbor_p_dir / f"{npc_id}.png")
        c_img = build_npc_sheet(NPC_SPECS[npc_id])
        c_img.save(harbor_c_dir / f"{npc_id}.png")

    # Rebuild complete harbor manifests covering all present PNGs
    p_files = sorted(p.name for p in harbor_p_dir.glob("*.png"))
    (harbor_p_dir / "manifest.json").write_text(
        json.dumps(
            {
                "files": [
                    {"id": fn[:-4], "file": fn, "canvas": list(Image.open(harbor_p_dir / fn).size), "sha256": sha256_file(harbor_p_dir / fn)}
                    for fn in p_files
                ]
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    c_files = sorted(p.name for p in harbor_c_dir.glob("*.png"))
    (harbor_c_dir / "manifest.json").write_text(
        json.dumps(
            {
                "files": [
                    {"file": fn, "canvas": list(Image.open(harbor_c_dir / fn).size), "sha256": sha256_file(harbor_c_dir / fn)}
                    for fn in c_files
                ]
            },
            indent=2,
        ),
        encoding="utf-8",
    )

    # Render contact sheet of all 16 new portraits + 4-dir sprites (2 rows of 8)
    contact = Image.new("RGBA", (1120, 620), (42, 52, 58, 255))
    rect(contact, 0, 0, 1120, 140, c("f0e6cd"))
    rect(contact, 0, 310, 1120, 140, c("f0e6cd"))
    ids = list(PORTRAIT_SOURCES.keys())
    for idx, npc_id in enumerate(ids):
        col = idx % 8
        row = idx // 8
        ox = 16 + col * 136
        oy = row * 310
        p = Image.open(harbor_p_dir / f"{npc_id}.png").resize((96, 96), Image.NEAREST)
        contact.paste(p, (ox + 16, oy + 22), p)
        s = Image.open(harbor_c_dir / f"{npc_id}.png")
        for d_idx, sheet_row in enumerate((0, 1, 3, 2)):
            f0 = s.crop((0, sheet_row * 32, 16, (sheet_row + 1) * 32)).resize((32, 64), Image.NEAREST)
            contact.paste(f0, (ox + d_idx * 32, oy + 160), f0)
        f_walk = s.crop((16, 0, 32, 32)).resize((32, 64), Image.NEAREST)
        contact.paste(f_walk, (ox + 48, oy + 232), f_walk)
    contact_out = args.raw_dir / "scratch" / "contact_020.png"
    contact_out.parent.mkdir(parents=True, exist_ok=True)
    contact.save(contact_out)
    print(f"Built 16 harbor NPC portraits & world sheets; contact sheet at {contact_out}")


if __name__ == "__main__":
    main()

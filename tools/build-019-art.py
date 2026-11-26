"""Build 0.19 Tidehaven original pixel-art assets:
1. Chroma-key & grid-sample 5 ocean companion 64x64 portraits + 4 Chinese harbor 64x64 portraits.
2. Author pixel-crisp 64x128 4-direction world sheets for P2-08a Yan Zhen (严砧) and Mu Tong (沐桐).
3. Author Chinese Harbor player layered hairstyles & Republican-era work shirts compatible with PlayerArt.
"""
import argparse
import collections
import hashlib
import json
import shutil
from pathlib import Path
from PIL import Image


def is_magenta_bg(r: int, g: int, b: int, strict: bool = False) -> bool:
    if strict:
        return r > 175 and b > 165 and g < 115 and (r - g) > 75 and (b - g) > 70
    return r > g + 38 and b > g + 38 and (g < 135 or (r > 185 and b > 175))


def extract_64_portrait(src_path: Path, shift_bottom: bool = False) -> Image.Image:
    src = Image.open(src_path).convert("RGBA")
    w, h = src.size
    px = src.load()
    bg = [[False] * w for _ in range(h)]
    q: collections.deque[tuple[int, int]] = collections.deque()

    for x in range(w):
        for y in (0, h - 1):
            r, g, b, _ = px[x, y]
            if is_magenta_bg(r, g, b):
                bg[y][x] = True
                q.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if not bg[y][x]:
                r, g, b, _ = px[x, y]
                if is_magenta_bg(r, g, b):
                    bg[y][x] = True
                    q.append((x, y))

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                r, g, b, _ = px[nx, ny]
                if is_magenta_bg(r, g, b):
                    bg[ny][nx] = True
                    q.append((nx, ny))

    # Clean 2px JPEG magenta fringe bordering flood-filled background
    for _ in range(3):
        to_clear = []
        for y in range(h):
            for x in range(w):
                if bg[y][x]:
                    continue
                if any(0 <= nx < w and 0 <= ny < h and bg[ny][nx] for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1))):
                    r, g, b, _ = px[x, y]
                    if r > g + 26 and b > g + 26 and g < 150:
                        to_clear.append((x, y))
        for x, y in to_clear:
            bg[y][x] = True

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
            fg_samples = []
            for sy in range(y0 + 2, max(y0 + 3, y1 - 2), 2):
                for sx in range(x0 + 2, max(x0 + 3, x1 - 2), 2):
                    if not bg[sy][sx]:
                        r, g, b, _ = px[sx, sy]
                        if not is_magenta_bg(r, g, b, strict=True):
                            fg_samples.append((r, g, b))
            total_probe = max(1, ((max(y0 + 3, y1 - 2) - (y0 + 2) + 1) // 2) * ((max(x0 + 3, x1 - 2) - (x0 + 2) + 1) // 2))
            if len(fg_samples) * 2 >= total_probe:
                if not bg[cy][cx]:
                    cr, cg, cb, _ = px[cx, cy]
                    if r_ok := not (cr > cg + 25 and cb > cg + 25 and cg < 145):
                        opx[gx, gy] = (cr, cg, cb, 255)
                        continue
                mid = fg_samples[len(fg_samples) // 2]
                opx[gx, gy] = (mid[0], mid[1], mid[2], 255)

    # Despill any remaining edge pixel that leans purple against transparent neighbor
    for gy in range(64):
        for gx in range(64):
            r, g, b, a = opx[gx, gy]
            if a == 0:
                continue
            has_trans = any(not (0 <= nx < 64 and 0 <= ny < 64) or opx[nx, ny][3] == 0 for nx, ny in ((gx - 1, gy), (gx + 1, gy), (gx, gy - 1), (gx, gy + 1)))
            if has_trans and r > g + 24 and b > g + 24:
                # Darken outline edge to warm dark ink instead of purple JPEG halo
                v = max(24, min(70, g))
                opx[gx, gy] = (int(v * 1.15), int(v * 0.85), int(v * 0.8), 255)

    if shift_bottom:
        bbox = out.getbbox()
        if bbox and bbox[3] < 64:
            dy = 64 - bbox[3]
            shifted = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
            shifted.paste(out, (0, dy))
            out = shifted
    return out


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


def draw_oval_head(
    im: Image.Image,
    hy: int,
    out: tuple,
    skin_s: tuple,
    skin_m: tuple,
    skin_l: tuple,
    slim: bool = False,
) -> None:
    """Draw organic rounded 16-bit head base centered at x=3..12, y=hy..hy+10."""
    # Tapered rounded silhouette: 6 -> 8 -> 10 -> 10 -> 10 -> 10 -> 8 -> 6
    spans = [
        (5, 10),
        (4, 11),
        (3, 12),
        (3, 12),
        (3, 12),
        (3, 12),
        (3, 12),
        (4, 11),
        (4, 11) if not slim else (5, 10),
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


def draw_yan_zhen_frame(direction: int, step: int) -> Image.Image:
    """Organic 16x32 pixel-art frame for 严砧 (older Chinese harbor blacksmith:
    cropped salt-and-pepper hair & mustache/beard, charcoal Mandarin-collar short tunic
    with frog buttons, ochre leather apron, sturdy arms & cloth work shoes).
    direction: 0=down, 1=right, 2=up, 3=left.
    """
    if direction == 3:
        return draw_yan_zhen_frame(1, step).transpose(Image.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    bob = 1 if step in (1, 3) else 0
    OUT = c("2a201d")
    HAIR_O = c("26292e")
    HAIR_D, HAIR_M, HAIR_L = c("434952"), c("707782"), c("a2aab5")
    SKIN_S, SKIN_M, SKIN_L = c("bd7b50"), c("e09c6c"), c("f2b78a")
    WHITE_EYE, EYE = c("f5efe6"), c("211715")
    TUNIC_D, TUNIC_M, TUNIC_L = c("3c424a"), c("525964"), c("6b7482")
    APRON_D, APRON_M, APRON_L = c("6e3c18"), c("985827"), c("ba7339")
    PANT_D, PANT_M = c("252d38"), c("364150")
    SHOE_D, SHOE_L = c("221d1a"), c("4a3e35")

    hy = 3 + bob
    draw_oval_head(im, hy, OUT, SKIN_S, SKIN_M, SKIN_L, slim=False)

    if direction == 0:  # Down
        # Rounded cropped salt-and-pepper hair crown & temples
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for xx in range(4, 12):
            put(im, xx, hy, HAIR_M if xx not in (4, 11) else HAIR_O)
        for xx in range(3, 13):
            put(im, xx, hy + 1, HAIR_L if xx in (6, 9) else HAIR_M if 4 <= xx <= 11 else HAIR_O)
            put(im, xx, hy + 2, HAIR_D if xx in (4, 7, 11) else HAIR_M if 4 <= xx <= 11 else HAIR_O)
        put(im, 3, hy + 3, HAIR_O); put(im, 4, hy + 3, HAIR_D)
        put(im, 11, hy + 3, HAIR_D); put(im, 12, hy + 3, HAIR_O)
        # Brows & 2px eyes
        put(im, 5, hy + 4, HAIR_D); put(im, 6, hy + 4, HAIR_D)
        put(im, 9, hy + 4, HAIR_D); put(im, 10, hy + 4, HAIR_D)
        put(im, 5, hy + 5, EYE); put(im, 6, hy + 5, WHITE_EYE)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        # Salt-and-pepper mustache & chin beard
        for xx in range(5, 11):
            put(im, xx, hy + 7, HAIR_D if xx in (5, 10) else HAIR_M)
        for xx in range(6, 10):
            put(im, xx, hy + 8, HAIR_D)
            put(im, xx, hy + 9, HAIR_O)
    elif direction == 2:  # Up (back of head)
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for dy, (x0, x1) in enumerate([(4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11)]):
            for xx in range(x0, x1 + 1):
                col = HAIR_O if xx in (x0, x1) else (HAIR_L if (xx + dy) % 4 == 0 else HAIR_D if dy >= 5 else HAIR_M)
                put(im, xx, hy + dy, col)
    else:  # Right profile
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for dy in range(7):
            for xx in range(3, 12):
                if dy <= 2 or xx <= 6:
                    col = HAIR_O if xx == 3 or (dy == 0 and xx in (4, 11)) else (HAIR_L if (xx + dy) % 4 == 1 else HAIR_M if dy <= 3 else HAIR_D)
                    put(im, xx, hy + dy, col)
        put(im, 6, hy + 5, SKIN_L)  # ear
        put(im, 9, hy + 4, HAIR_D); put(im, 10, hy + 4, HAIR_D)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        put(im, 12, hy + 6, SKIN_M)
        rect(im, 9, hy + 7, 3, 1, HAIR_D)
        rect(im, 9, hy + 8, 3, 1, HAIR_O)

    # Broad rounded shoulders & torso (y = 13+bob .. 25)
    ty = 13 + bob
    if direction in (0, 2):
        torso_spans = [(3, 12), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (2, 13), (3, 12), (3, 12), (3, 12)]
        for dy, (x0, x1) in enumerate(torso_spans):
            yy = ty + dy
            for xx in range(x0, x1 + 1):
                put(im, xx, yy, OUT if xx in (x0, x1) or dy == len(torso_spans) - 1 else TUNIC_M)
        if direction == 0:
            # Mandarin collar + frog button placket
            put(im, 7, ty, SKIN_S); put(im, 8, ty, SKIN_S)
            put(im, 6, ty, TUNIC_L); put(im, 9, ty, TUNIC_L)
            put(im, 7, ty + 1, OUT); put(im, 8, ty + 1, OUT)
            put(im, 7, ty + 2, TUNIC_D); put(im, 8, ty + 2, TUNIC_D)
            # Ochre leather apron straps & bib
            rect(im, 5, ty + 1, 1, 3, APRON_M); rect(im, 10, ty + 1, 1, 3, APRON_M)
            rect(im, 4, ty + 3, 8, 6, APRON_M)
            rect(im, 5, ty + 4, 6, 3, APRON_L)
            rect(im, 4, ty + 8, 8, 1, APRON_D)
        else:
            rect(im, 5, ty + 1, 6, 2, TUNIC_L)
            rect(im, 4, ty + 5, 8, 1, APRON_D)
            put(im, 7, ty + 6, APRON_M); put(im, 8, ty + 6, APRON_M)
        # Curved arms on left (x=1..2) & right (x=13..14)
        la = 1 if step == 1 else (-1 if step == 3 else 0)
        ra = -la
        for side_x, shift in ((1, la), (13, ra)):
            ay = ty + 2 + shift
            rect(im, side_x, ay, 2, 3, TUNIC_D)
            put(im, side_x if side_x == 1 else 14, ay, OUT)
            rect(im, side_x, ay + 3, 2, 3, SKIN_M)
            put(im, side_x if side_x == 1 else 14, ay + 4, OUT)
            rect(im, side_x, ay + 6, 2, 1, OUT)
    else:  # Right profile torso & swinging arm
        for dy in range(10):
            yy = ty + dy
            for xx in range(4, 12):
                put(im, xx, yy, OUT if xx in (4, 11) or dy == 9 else TUNIC_M)
        rect(im, 8, ty + 2, 3, 7, APRON_M)
        rect(im, 9, ty + 3, 2, 3, APRON_L)
        ax = 6 + (1 if step == 1 else -1 if step == 3 else 0)
        rect(im, ax, ty + 2, 3, 3, TUNIC_L)
        rect(im, ax, ty + 5, 3, 2, SKIN_M)
        rect(im, ax, ty + 7, 3, 1, OUT)

    # Legs & sturdy harbor work shoes (foot grounded at y=31)
    ly = 23 + bob
    if direction in (0, 2):
        l_end = 30 if step == 1 else 31
        r_end = 30 if step == 3 else 31
        for x0, end_y in ((4, l_end), (9, r_end)):
            for yy in range(ly, end_y - 1):
                put(im, x0 - 1, yy, OUT); put(im, x0 + 3, yy, OUT)
                rect(im, x0, yy, 3, 1, PANT_M if yy > ly else PANT_D)
            rect(im, x0 - 1, end_y - 1, 4, 1, SHOE_L)
            rect(im, x0 - 1, end_y, 4, 1, SHOE_D)
    else:
        if step in (1, 3):
            front_x, back_x = (8, 4) if step == 1 else (4, 8)
            rect(im, back_x, ly, 3, 5, PANT_D); rect(im, back_x, 29, 4, 2, SHOE_D)
            rect(im, front_x, ly, 3, 6, PANT_M); rect(im, front_x, 30, 4, 1, SHOE_L); rect(im, front_x, 31, 4, 1, SHOE_D)
        else:
            for yy in range(ly, 30):
                put(im, 5, yy, OUT); rect(im, 6, yy, 4, 1, PANT_M); put(im, 10, yy, OUT)
            rect(im, 5, 30, 6, 1, SHOE_L)
            rect(im, 5, 31, 6, 1, SHOE_D)
    return im


def draw_mu_tong_frame(direction: int, step: int) -> Image.Image:
    """Organic 16x32 pixel-art frame for 沐桐 (young Chinese botanical illustrator:
    ink-black parted hair + low braided bun + wooden hairpin, moss-green slanted-collar
    linen shirt, diagonal canvas sketchbook satchel, dark trousers & cloth shoes).
    direction: 0=down, 1=right, 2=up, 3=left.
    """
    if direction == 3:
        return draw_mu_tong_frame(1, step).transpose(Image.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    bob = 1 if step in (1, 3) else 0
    OUT = c("261c1a")
    HAIR_O = c("12161c")
    HAIR_D, HAIR_M, HAIR_L = c("1d242e"), c("2e3947"), c("475669")
    PIN = c("b5743c")
    SKIN_S, SKIN_M, SKIN_L = c("cf8e62"), c("efb084"), c("fad0ad")
    WHITE_EYE, EYE = c("f7f2eb"), c("211513")
    SHIRT_D, SHIRT_M, SHIRT_L = c("4d6949"), c("6d8f67"), c("8db085")
    BAG_D, BAG_M, BAG_L = c("6d3f1b"), c("995d2b"), c("bb783e")
    PANT_D, PANT_M = c("313742"), c("454d59")
    SHOE_D, SHOE_SOLE = c("23262e"), c("dfd6c3")

    hy = 4 + bob
    draw_oval_head(im, hy, OUT, SKIN_S, SKIN_M, SKIN_L, slim=True)

    if direction == 0:
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for xx in range(4, 12):
            put(im, xx, hy, HAIR_M if 5 <= xx <= 10 else HAIR_O)
        for xx in range(3, 13):
            put(im, xx, hy + 1, HAIR_L if xx in (6, 10) else HAIR_M if 4 <= xx <= 11 else HAIR_O)
        # Center-parted curved bangs framing temples
        for xx in (3, 4, 5, 10, 11, 12):
            put(im, xx, hy + 2, HAIR_D if xx not in (3, 12) else HAIR_O)
        for xx in (3, 4, 11, 12):
            put(im, xx, hy + 3, HAIR_D if xx in (4, 11) else HAIR_O)
        put(im, 3, hy + 4, HAIR_O); put(im, 12, hy + 4, HAIR_O)
        # Low side bun & wooden hairpin peeking on right
        rect(im, 11, hy + 6, 3, 3, HAIR_D); put(im, 13, hy + 7, HAIR_O)
        put(im, 13, hy + 4, PIN); put(im, 14, hy + 3, PIN)
        # Brows & warm 2px eyes
        put(im, 5, hy + 4, HAIR_D); put(im, 6, hy + 4, HAIR_D)
        put(im, 9, hy + 4, HAIR_D); put(im, 10, hy + 4, HAIR_D)
        put(im, 5, hy + 5, EYE); put(im, 6, hy + 5, WHITE_EYE)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        put(im, 7, hy + 7, SKIN_S); put(im, 8, hy + 7, SKIN_S)
    elif direction == 2:
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for dy, (x0, x1) in enumerate([(4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11)]):
            for xx in range(x0, x1 + 1):
                put(im, xx, hy + dy, HAIR_O if xx in (x0, x1) else (HAIR_L if (xx + dy) % 5 == 0 else HAIR_M))
        # Coiled low bun + wooden hairpin
        rect(im, 5, hy + 5, 6, 4, HAIR_O)
        rect(im, 6, hy + 6, 4, 2, HAIR_D)
        put(im, 4, hy + 6, PIN); put(im, 11, hy + 5, PIN); put(im, 12, hy + 4, PIN)
    else:  # Right profile
        for xx in range(5, 11):
            put(im, xx, hy - 1, HAIR_O)
        for dy in range(7):
            for xx in range(3, 12):
                if dy <= 2 or xx <= 6:
                    put(im, xx, hy + dy, HAIR_O if xx == 3 else (HAIR_L if (xx + dy) % 4 == 0 else HAIR_M))
        # Nape bun + wooden pin at back-left
        rect(im, 1, hy + 5, 3, 4, HAIR_O); rect(im, 2, hy + 6, 2, 2, HAIR_D)
        put(im, 2, hy + 4, PIN); put(im, 1, hy + 3, PIN)
        put(im, 6, hy + 5, SKIN_L)
        put(im, 9, hy + 4, HAIR_D); put(im, 10, hy + 4, HAIR_D)
        put(im, 9, hy + 5, WHITE_EYE); put(im, 10, hy + 5, EYE)
        put(im, 12, hy + 6, SKIN_M)

    # Moss-green slanted-collar linen short shirt + diagonal sketchbook satchel
    ty = 14 + bob
    if direction in (0, 2):
        spans = [(4, 11), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (3, 12), (4, 11), (4, 11)]
        for dy, (x0, x1) in enumerate(spans):
            yy = ty + dy
            for xx in range(x0, x1 + 1):
                put(im, xx, yy, OUT if xx in (x0, x1) or dy == len(spans) - 1 else SHIRT_M)
        if direction == 0:
            put(im, 7, ty, SKIN_M); put(im, 8, ty, SKIN_M)
            put(im, 6, ty + 1, SHIRT_L); put(im, 7, ty + 1, SHIRT_D); put(im, 6, ty + 2, OUT); put(im, 5, ty + 3, SHIRT_D)
            for k in range(5):
                put(im, 10 - k, ty + 1 + k, BAG_M)
                put(im, 10 - k, ty + 2 + k, BAG_D)
            rect(im, 3, ty + 5, 3, 3, BAG_M); put(im, 4, ty + 6, BAG_L)
        else:
            rect(im, 5, ty + 1, 6, 2, SHIRT_L)
            for k in range(5):
                put(im, 5 + k, ty + 1 + k, BAG_M)
            rect(im, 3, ty + 5, 3, 3, BAG_D)
        la = 1 if step == 1 else (-1 if step == 3 else 0)
        ra = -la
        for side_x, shift in ((2, la), (12, ra)):
            ay = ty + 2 + shift
            rect(im, side_x, ay, 2, 3, SHIRT_D)
            put(im, side_x if side_x == 2 else 13, ay, OUT)
            rect(im, side_x, ay + 3, 2, 2, SKIN_M)
            put(im, side_x, ay + 5, OUT); put(im, side_x + 1, ay + 5, OUT)
    else:
        for dy in range(9):
            yy = ty + dy
            for xx in range(5, 11):
                put(im, xx, yy, OUT if xx in (5, 10) or dy == 8 else SHIRT_M)
        rect(im, 5, ty + 4, 4, 4, BAG_M); put(im, 6, ty + 5, BAG_L)
        ax = 7 + (1 if step == 1 else -1 if step == 3 else 0)
        rect(im, ax, ty + 2, 2, 3, SHIRT_L)
        rect(im, ax, ty + 5, 2, 2, SKIN_M)
        put(im, ax, ty + 7, OUT)

    # Trousers & traditional cloth shoes (foot at y=31)
    ly = 23 + bob
    if direction in (0, 2):
        l_end = 30 if step == 1 else 31
        r_end = 30 if step == 3 else 31
        for x0, end_y in ((5, l_end), (9, r_end)):
            for yy in range(ly, end_y - 1):
                put(im, x0 - 1, yy, OUT); rect(im, x0, yy, 2, 1, PANT_M); put(im, x0 + 2, yy, OUT)
            rect(im, x0 - 1, end_y - 1, 3, 1, SHOE_D)
            rect(im, x0 - 1, end_y, 3, 1, SHOE_SOLE if end_y == 31 else SHOE_D)
    else:
        if step in (1, 3):
            front_x, back_x = (8, 5) if step == 1 else (5, 8)
            rect(im, back_x, ly, 2, 5, PANT_D); rect(im, back_x, 29, 3, 2, SHOE_D)
            rect(im, front_x, ly, 2, 6, PANT_M); rect(im, front_x, 30, 3, 1, SHOE_D); rect(im, front_x, 31, 3, 1, SHOE_SOLE)
        else:
            for yy in range(ly, 30):
                put(im, 5, yy, OUT); rect(im, 6, yy, 4, 1, PANT_M); put(im, 10, yy, OUT)
            rect(im, 6, 30, 4, 1, SHOE_D)
            rect(im, 6, 31, 4, 1, SHOE_SOLE)
    return im


def build_npc_sheet(frame_fn) -> Image.Image:
    sheet = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
    for row in range(4):
        for col in range(4):
            frame = frame_fn(row, col)
            sheet.paste(frame, (col * 16, row * 32))
    return sheet


def build_harbor_shirts() -> Image.Image:
    """Create a 128x32 compact sheet for 8 Republican-era Chinese harbor work shirts.
    Each shirt i in 0..7 occupies x = i*8 .. i*8+7, with 4 directional rows of height 8:
    y=0..7 (down), y=8..15 (right), y=16..23 (left), y=24..31 (up).
    Also stores sleeve palette pixels at y=2..4, x=i*8 so PlayerArt._palette reads matching sleeves!
    """
    sheet = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    designs = [
        # (dark, mid, light, accent/collar, style)
        ("23324d", "32486e", "476391", "ebe6d8", "frog_center"),  # 0: 藏蓝对襟盘扣短衫 (Host default)
        ("234f59", "336e7a", "4b8d99", "1d3c45", "slanted"),      # 1: 青碧斜襟盘扣短衫 (Guest default)
        ("9c927e", "cfc4ae", "e6decb", "3b4454", "frog_center"),  # 2: 本白粗布海港褂
        ("383d45", "4f5661", "68707d", "8f5526", "apron"),        # 3: 炭灰工匠围裙褂
        ("6b4423", "8f5d32", "ad7544", "d9ceb8", "vest"),         # 4: 赭褐船工坎肩
        ("435c3f", "5c7d57", "769c70", "32452f", "slanted"),      # 5: 苍绿斜襟采药衫
        ("692727", "8c3737", "ab4b4b", "e8dcc5", "frog_center"),  # 6: 绛红渔港对襟衫
        ("2c3e52", "3e5670", "547291", "9c7a4c", "sash"),         # 7: 靛青束腰学徒衫
    ]
    for idx, (cd, cm, cl, ca, kind) in enumerate(designs):
        D, M, L, A = c(cd), c(cm), c(cl), c(ca)
        ox = idx * 8
        for dir_idx, oy in ((0, 0), (2, 8), (1, 16), (3, 24)):
            rect(sheet, ox, oy, 8, 8, M)
            rect(sheet, ox, oy + 7, 8, 1, D)
            rect(sheet, ox + 1, oy, 6, 2, L)
            if dir_idx == 0:  # Down
                put(sheet, ox + 3, oy, A); put(sheet, ox + 4, oy, A)
                if kind == "frog_center":
                    for yy in (1, 3, 5):
                        put(sheet, ox + 3, oy + yy, D); put(sheet, ox + 4, oy + yy, D)
                        put(sheet, ox + 2, oy + yy, A if kind == "vest" else D)
                elif kind == "slanted":
                    put(sheet, ox + 2, oy + 1, D); put(sheet, ox + 3, oy + 2, D)
                    put(sheet, ox + 2, oy + 3, A); put(sheet, ox + 1, oy + 4, D)
                elif kind == "apron":
                    rect(sheet, ox + 1, oy + 2, 6, 5, A)
                elif kind == "vest":
                    rect(sheet, ox + 2, oy + 1, 4, 6, A)
                elif kind == "sash":
                    rect(sheet, ox, oy + 5, 8, 2, A)
            elif dir_idx == 3:  # Up (back)
                rect(sheet, ox + 1, oy + 1, 6, 5, M)
                if kind in ("apron", "sash"):
                    rect(sheet, ox, oy + 5, 8, 1, A)
            else:  # Side
                rect(sheet, ox + 1, oy + 1, 6, 6, M)
                if kind in ("apron", "sash"):
                    rect(sheet, ox + 1, oy + 5, 6, 1, A)
        # Ensure x=ox, y=2..4 encode L, M, D for PlayerArt._palette sleeve lookup!
        put(sheet, ox, 2, L)
        put(sheet, ox, 3, M)
        put(sheet, ox, 4, D)
    return sheet


def build_harbor_hairstyles() -> Image.Image:
    """Create grayscale-tintable 128x96 sheet for 8 Chinese harbor hairstyles (indices 0..7).
    Each hairstyle i is at x = i*16 .. i*16+15, with 3 rows of 16x32:
    y=0..31 (down), y=32..63 (right; flipped for left by PlayerArt), y=64..95 (up).
    Uses white/gray luminance so PlayerArt._tinted(hair, hair_color) shades naturally!
    """
    sheet = Image.new("RGBA", (128, 96), (0, 0, 0, 0))
    G_OUT = (95, 95, 100, 255)
    G_D = (150, 150, 158, 255)
    G_M = (205, 205, 212, 255)
    G_L = (245, 245, 250, 255)
    BAND_TEAL = c("3d8b96")
    BAND_CLOTH = c("d8ceb8")
    PIN_WOOD = c("c98a52")

    for idx in range(8):
        ox = idx * 16
        # Align precisely to farmer_base head (crown at y=3..4, head wrap at y=5..9, eyes at y=9..10)
        for row_idx, oy in enumerate((0, 32, 64)):
            for xx in range(5, 11):
                put(sheet, ox + xx, oy + 3, G_OUT)
            for xx in range(4, 12):
                put(sheet, ox + xx, oy + 4, G_M if 5 <= xx <= 10 else G_OUT)
            for xx in range(2, 14):
                put(sheet, ox + xx, oy + 5, G_L if xx in (6, 9) else G_M if 3 <= xx <= 12 else G_OUT)
                put(sheet, ox + xx, oy + 6, G_M if 3 <= xx <= 12 else G_OUT)
            if row_idx == 0:  # Down
                for xx in (2, 3, 4, 11, 12, 13):
                    put(sheet, ox + xx, oy + 7, G_D if xx not in (2, 13) else G_OUT)
                put(sheet, ox + 2, oy + 8, G_OUT); put(sheet, ox + 3, oy + 8, G_D)
                put(sheet, ox + 12, oy + 8, G_D); put(sheet, ox + 13, oy + 8, G_OUT)
                if idx == 0:  # 偏分利落短发 (Host default)
                    for xx in (4, 5, 6, 7, 10, 11):
                        put(sheet, ox + xx, oy + 7, G_D)
                    put(sheet, ox + 4, oy + 8, G_D); put(sheet, ox + 5, oy + 8, G_D)
                elif idx == 1:  # 船工平寸短发
                    rect(sheet, ox + 4, oy + 7, 8, 1, G_OUT)
                elif idx == 2:  # 海港布巾包头
                    rect(sheet, ox + 3, oy + 6, 10, 2, BAND_CLOTH)
                elif idx == 3:  # 清爽碎发
                    for xx in (4, 6, 8, 11):
                        put(sheet, xx + ox, oy + 7, G_D)
                        put(sheet, xx + ox, oy + 8, G_OUT)
                elif idx == 4:  # 海商微卷背头
                    rect(sheet, ox + 5, oy + 4, 6, 2, G_L)
                    put(sheet, ox + 3, oy + 9, G_D); put(sheet, ox + 12, oy + 9, G_D)
                elif idx == 5:  # 民国齐耳短发
                    rect(sheet, ox + 2, oy + 7, 2, 6, G_M); rect(sheet, ox + 12, oy + 7, 2, 6, G_M)
                    put(sheet, ox + 2, oy + 12, G_OUT); put(sheet, ox + 13, oy + 12, G_OUT)
                elif idx == 6:  # 青丝垂肩麻花辫 (Guest default)
                    rect(sheet, ox + 3, oy + 7, 3, 2, G_D); rect(sheet, ox + 10, oy + 7, 3, 2, G_D)
                    rect(sheet, ox + 2, oy + 9, 3, 7, G_M)
                    put(sheet, ox + 2, oy + 13, BAND_TEAL); put(sheet, ox + 3, oy + 13, BAND_TEAL)
                    put(sheet, ox + 3, oy + 15, G_OUT)
                elif idx == 7:  # 木簪低挽发髻
                    rect(sheet, ox + 3, oy + 7, 2, 4, G_D); rect(sheet, ox + 11, oy + 7, 2, 4, G_D)
                    put(sheet, ox + 13, oy + 7, PIN_WOOD); put(sheet, ox + 14, oy + 6, PIN_WOOD)
            elif row_idx == 1:  # Right profile
                rect(sheet, ox + 2, oy + 6, 5, 5, G_D)
                rect(sheet, ox + 7, oy + 6, 4, 2, G_M)
                put(sheet, ox + 2, oy + 7, G_OUT); put(sheet, ox + 2, oy + 8, G_OUT)
                if idx == 2:
                    rect(sheet, ox + 3, oy + 6, 9, 2, BAND_CLOTH)
                    put(sheet, ox + 1, oy + 7, BAND_CLOTH)
                elif idx == 5:
                    rect(sheet, ox + 2, oy + 7, 5, 6, G_M)
                elif idx == 6:
                    rect(sheet, ox + 2, oy + 9, 3, 8, G_M)
                    put(sheet, ox + 2, oy + 14, BAND_TEAL); put(sheet, ox + 3, oy + 14, BAND_TEAL)
                elif idx == 7:
                    rect(sheet, ox + 1, oy + 8, 3, 4, G_D)
                    put(sheet, ox + 1, oy + 7, PIN_WOOD); put(sheet, ox, oy + 6, PIN_WOOD)
            else:  # Up (back of head)
                for dy in range(6, 12):
                    for xx in range(3, 13):
                        put(sheet, ox + xx, oy + dy, G_OUT if xx in (3, 12) or dy == 11 else (G_D if dy >= 9 else G_M))
                if idx == 2:
                    rect(sheet, ox + 3, oy + 6, 10, 2, BAND_CLOTH)
                elif idx == 6:
                    rect(sheet, ox + 6, oy + 11, 3, 6, G_D)
                    put(sheet, ox + 6, oy + 15, BAND_TEAL); put(sheet, ox + 7, oy + 15, BAND_TEAL)
                elif idx == 7:
                    rect(sheet, ox + 5, oy + 8, 6, 4, G_D)
                    put(sheet, ox + 4, oy + 9, PIN_WOOD); put(sheet, ox + 11, oy + 8, PIN_WOOD)
    return sheet


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--raw-dir", required=True, type=Path)
    parser.add_argument("--out-root", required=True, type=Path)
    args = parser.parse_args()

    ocean_dir = args.out_root / "portraits" / "ocean"
    harbor_p_dir = args.out_root / "portraits" / "harbor"
    harbor_c_dir = args.out_root / "characters" / "harbor"
    for d in (ocean_dir, harbor_p_dir, harbor_c_dir):
        d.mkdir(parents=True, exist_ok=True)

    ocean_map = {
        "bai_fan": ("bai_fan_1795659557299.jpg", False),
        "chi_sheng": ("chi_sheng_1795659567521.jpg", False),
        "chao_jia": ("chao_jia_fixed_1795659618249.jpg", False),
        "tai_lu": ("tai_lu_v3_1795659684285.jpg", True),
        "lan_ying": ("lan_ying_1795659595128.jpg", False),
    }
    harbor_map = {
        "player_male": "player_male_1795659557353.jpg",
        "player_female": "player_female_1795659577744.jpg",
        "yan_zhen": "yan_zhen_1795659590998.jpg",
        "mu_tong": "mu_tong_1795659633901.jpg",
    }

    ocean_manifest = []
    for key, (fname, shift_b) in ocean_map.items():
        img = extract_64_portrait(args.raw_dir / fname, shift_bottom=shift_b)
        dest = ocean_dir / f"{key}.png"
        img.save(dest)
        ocean_manifest.append({"id": key, "file": f"{key}.png", "canvas": [64, 64], "sha256": sha256_file(dest)})

    harbor_manifest = []
    for key, fname in harbor_map.items():
        img = extract_64_portrait(args.raw_dir / fname, shift_bottom=False)
        dest = harbor_p_dir / f"{key}.png"
        img.save(dest)
        harbor_manifest.append({"id": key, "file": f"{key}.png", "canvas": [64, 64], "sha256": sha256_file(dest)})

    yz = build_npc_sheet(draw_yan_zhen_frame)
    yz.save(harbor_c_dir / "yan_zhen.png")
    mt = build_npc_sheet(draw_mu_tong_frame)
    mt.save(harbor_c_dir / "mu_tong.png")
    shirts = build_harbor_shirts()
    shirts.save(harbor_c_dir / "harbor_shirts.png")
    hairs = build_harbor_hairstyles()
    hairs.save(harbor_c_dir / "harbor_hairstyles.png")

    char_manifest = [
        {"file": fn, "canvas": list(Image.open(harbor_c_dir / fn).size), "sha256": sha256_file(harbor_c_dir / fn)}
        for fn in ("yan_zhen.png", "mu_tong.png", "harbor_shirts.png", "harbor_hairstyles.png")
    ]
    (ocean_dir / "manifest.json").write_text(json.dumps({"files": ocean_manifest}, indent=2), encoding="utf-8")
    (harbor_p_dir / "manifest.json").write_text(json.dumps({"files": harbor_manifest}, indent=2), encoding="utf-8")
    (harbor_c_dir / "manifest.json").write_text(json.dumps({"files": char_manifest}, indent=2), encoding="utf-8")

    # Build visual verification contact sheet on both warm paper (#f0e6cd) and slate (#283238)
    preview = Image.new("RGBA", (940, 460), (40, 50, 56, 255))
    rect(preview, 0, 0, 940, 155, c("f0e6cd"))
    for i, key in enumerate(["bai_fan", "chi_sheng", "chao_jia", "tai_lu", "lan_ying"]):
        p = Image.open(ocean_dir / f"{key}.png").resize((96, 96), Image.NEAREST)
        preview.paste(p, (12 + i * 102, 24), p)
        preview.paste(p, (12 + i * 102, 175), p)
    for i, key in enumerate(["player_male", "player_female", "yan_zhen", "mu_tong"]):
        p = Image.open(harbor_p_dir / f"{key}.png").resize((96, 96), Image.NEAREST)
        preview.paste(p, (530 + i * 100, 24), p)
        preview.paste(p, (530 + i * 100, 175), p)
    preview.paste(yz.resize((128, 256), Image.NEAREST), (540, 285), yz.resize((128, 256), Image.NEAREST))
    preview.paste(mt.resize((128, 256), Image.NEAREST), (700, 285), mt.resize((128, 256), Image.NEAREST))
    preview.save(args.out_root / "contact_sheet.png")
    print("Built all 0.19 portraits & harbor sprite sheets cleanly.")


if __name__ == "__main__":
    main()

"""Build 0.22 Tidehaven 4 new characters (P2-32..P2-35):
- Harbor town residents (64x64 binary-alpha portrait + 64x128 4-dir x 4-frame 16x32 world sheet):
  - cen_po  : Retired harbor pilot (silver low bun + brass pin, slate-navy pilot coat, ochre scarf & whistle)
  - a_yuan  : Signboard painter (top bun + crossed paintbrushes, striped harbor shirt, ochre smock & brush strap)
- Ocean & coastal companions (64x64 binary-alpha portrait + 64x32 2-frame 32x32 world sheet):
  - mi_luo  : Merfolk clockwork tinkerer (brass loupe goggles, coral fin ears, gear strap, coiled iridescent tail)
  - san_jin : Scale-hogging spotted harbor seal (plump spotted silver-taupe body, brass scale pan & scallop shell)
Updates all 4 manifest.json & SOURCE.md files and outputs scratch/contact_022.png for visual verification.
"""
import collections
import hashlib
import json
from pathlib import Path
from PIL import Image


RAW_DIR = Path(r"C:\Users\s_f15\.gemini\antigravity-cli\brain\eafec623-ae74-4c72-b32d-3a1807222f04")
PORTRAIT_RAW = {
    "cen_po": ("harbor", "cen_po_1795695139140.jpg"),
    "a_yuan": ("harbor", "a_yuan_1795695149155.jpg"),
    "mi_luo": ("ocean", "mi_luo_1795695206209.jpg"),
    "san_jin": ("ocean", "san_jin_1795695217894.jpg"),
}


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


def extract_parchment_64_portrait(src_path: Path) -> Image.Image:
    src = Image.open(src_path).convert("RGBA")
    w, h = src.size
    px = src.load()

    samples = [px[4, 4][:3], px[w - 5, 4][:3], px[4, 20][:3], px[w - 5, 20][:3]]
    br = sum(s[0] for s in samples) // len(samples)
    bg_g = sum(s[1] for s in samples) // len(samples)
    bb = sum(s[2] for s in samples) // len(samples)

    def is_parchment(r: int, g: int, b: int, tol: int = 28) -> bool:
        return abs(r - br) <= tol and abs(g - bg_g) <= tol and abs(b - bb) <= tol

    bg = [[False] * w for _ in range(h)]
    q: collections.deque[tuple[int, int]] = collections.deque()

    for x in range(w):
        for y_edge in (0, h - 1):
            r, g, b, _ = px[x, y_edge]
            if is_parchment(r, g, b, 30) and not bg[y_edge][x]:
                bg[y_edge][x] = True
                q.append((x, y_edge))
    for y in range(h):
        for x_edge in (0, w - 1):
            if not bg[y][x_edge]:
                r, g, b, _ = px[x_edge, y]
                if is_parchment(r, g, b, 30):
                    bg[y][x_edge] = True
                    q.append((x_edge, y))

    while q:
        cx, cy = q.popleft()
        for nx, ny in ((cx - 1, cy), (cx + 1, cy), (cx, cy - 1), (cx, cy + 1)):
            if 0 <= nx < w and 0 <= ny < h and not bg[ny][nx]:
                r, g, b, _ = px[nx, ny]
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

    out_ink = (38, 27, 23, 255)
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
                opx[gx, gy] = out_ink

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


def draw_cen_po_frame(direction: int, step: int) -> Image.Image:
    if direction == 3:
        return draw_cen_po_frame(1, step).transpose(Image.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    bob = 1 if step in (1, 3) else 0
    out = c("241a17")
    sk_s, sk_m, sk_l = c("b57347"), c("d69162"), c("ebae83")
    hr_o, hr_d, hr_m, hr_l = c("383e47"), c("6c7582"), c("9ea7b3"), c("cfd6de")
    ct_d, ct_m, ct_l = c("2c3c4d"), c("3f556b"), c("58728c")
    cream = c("ebe0c5")
    sc_d, sc_l = c("9c4e1f"), c("c76c32")
    gold = c("e0b443")
    pt_d, pt_m = c("242e3b"), c("334152")
    sh_d, sole = c("211b18"), c("d9d1c0")
    eye, weye = c("211614"), c("f5efe6")

    hy = 3 + bob
    draw_oval_head(im, hy, out, sk_s, sk_m, sk_l, slim=False)

    if direction == 0:
        for xx in range(5, 11):
            put(im, xx, hy - 1, hr_o)
        for xx in range(4, 12):
            put(im, xx, hy, hr_l if xx in (6, 9) else (hr_m if 4 < xx < 11 else hr_o))
        for xx in range(3, 13):
            put(im, xx, hy + 1, hr_l if xx in (5, 6, 9, 10) else (hr_m if 3 < xx < 12 else hr_o))
        for xx in (3, 4, 11, 12):
            put(im, xx, hy + 2, hr_o if xx in (3, 12) else hr_d)
            put(im, xx, hy + 3, hr_o if xx in (3, 12) else hr_m)
        # Side-low silver bun & brass pin on left side (x=1..3)
        rect(im, 1, hy + 4, 3, 3, hr_m)
        put(im, 1, hy + 5, hr_o)
        put(im, 2, hy + 4, hr_l)
        put(im, 1, hy + 3, gold)
        put(im, 2, hy + 3, out)
        # Eyes & warm brows
        put(im, 5, hy + 4, hr_d); put(im, 10, hy + 4, hr_d)
        put(im, 5, hy + 5, eye); put(im, 6, hy + 5, weye)
        put(im, 9, hy + 5, weye); put(im, 10, hy + 5, eye)
        put(im, 7, hy + 7, sk_s); put(im, 8, hy + 7, sk_s)
    elif direction == 2:
        for xx in range(5, 11):
            put(im, xx, hy - 1, hr_o)
        for dy in range(7):
            x0, x1 = (4, 11) if dy in (0, 6) else (3, 12)
            for xx in range(x0, x1 + 1):
                put(im, xx, hy + dy, hr_o if xx in (x0, x1) else (hr_l if dy <= 2 else hr_m))
        rect(im, 5, hy + 4, 6, 4, hr_o)
        rect(im, 6, hy + 5, 4, 2, hr_l)
        put(im, 4, hy + 4, gold); put(im, 3, hy + 3, gold)
    else:
        for xx in range(5, 11):
            put(im, xx, hy - 1, hr_o)
        for dy in range(7):
            for xx in range(3, 12):
                if dy <= 2 or xx <= 6:
                    put(im, xx, hy + dy, hr_o if xx == 3 else (hr_l if dy <= 2 else hr_m))
        rect(im, 1, hy + 4, 3, 3, hr_m)
        put(im, 1, hy + 5, hr_o); put(im, 1, hy + 3, gold)
        put(im, 9, hy + 5, weye); put(im, 10, hy + 5, eye)

    ty = 13 + bob
    if direction in (0, 2):
        for dy in range(10):
            yy = ty + dy
            for xx in range(3, 13):
                put(im, xx, yy, out if xx in (3, 12) or dy == 9 else (ct_l if dy <= 2 and xx in (5, 10) else ct_m))
        if direction == 0:
            # Cream lapel + ochre sea scarf + brass whistle
            put(im, 6, ty, cream); put(im, 9, ty, cream)
            put(im, 6, ty + 1, cream); put(im, 9, ty + 1, cream)
            rect(im, 7, ty, 2, 3, sc_l)
            rect(im, 7, ty + 3, 2, 4, sc_d)
            put(im, 7, ty + 5, gold); put(im, 8, ty + 5, gold)
            put(im, 5, ty + 2, ct_d); put(im, 10, ty + 2, ct_d)
        else:
            rect(im, 6, ty, 4, 1, sc_d)
        la = 1 if step == 1 else (-1 if step == 3 else 0)
        for side_x, shift in ((2, la), (13, -la)):
            ay = ty + 1 + shift
            rect(im, side_x, ay, 2, 4, ct_d)
            rect(im, side_x, ay + 4, 2, 1, cream)
            rect(im, side_x, ay + 5, 2, 1, sk_m)
            rect(im, side_x, ay + 6, 2, 1, out)
    else:
        for dy in range(10):
            yy = ty + dy
            for xx in range(4, 12):
                put(im, xx, yy, out if xx in (4, 11) or dy == 9 else ct_m)
        rect(im, 9, ty, 2, 4, sc_l)
        put(im, 10, ty + 4, gold)
        ax = 6 + (1 if step == 1 else -1 if step == 3 else 0)
        rect(im, ax, ty + 2, 3, 4, ct_d)
        rect(im, ax, ty + 6, 3, 1, sk_m)
        rect(im, ax, ty + 7, 3, 1, out)

    ly = 23 + bob
    if direction in (0, 2):
        l_end = 30 if step == 1 else 31
        r_end = 30 if step == 3 else 31
        for x0, end_y in ((4, l_end), (9, r_end)):
            for yy in range(ly, end_y - 1):
                put(im, x0 - 1, yy, out); put(im, x0 + 3, yy, out)
                rect(im, x0, yy, 3, 1, pt_m if yy > ly else pt_d)
            rect(im, x0 - 1, end_y - 1, 4, 1, sh_d)
            put(im, x0 - 1, end_y, out); rect(im, x0, end_y, 2, 1, sole); put(im, x0 + 2, end_y, out)
    else:
        if step in (1, 3):
            front_x, back_x = (8, 4) if step == 1 else (4, 8)
            rect(im, back_x, ly, 3, 5, pt_d); rect(im, back_x, 29, 4, 1, sh_d); rect(im, back_x, 30, 4, 1, sole)
            rect(im, front_x, ly, 3, 6, pt_m); rect(im, front_x, 30, 4, 1, sh_d); put(im, front_x, 31, out); rect(im, front_x + 1, 31, 2, 1, sole); put(im, front_x + 3, 31, out)
        else:
            for yy in range(ly, 30):
                put(im, 5, yy, out); rect(im, 6, yy, 4, 1, pt_m); put(im, 10, yy, out)
            rect(im, 5, 30, 6, 1, sh_d)
            put(im, 5, 31, out); rect(im, 6, 31, 4, 1, sole); put(im, 10, 31, out)
    return im


def draw_a_yuan_frame(direction: int, step: int) -> Image.Image:
    if direction == 3:
        return draw_a_yuan_frame(1, step).transpose(Image.FLIP_LEFT_RIGHT)
    im = Image.new("RGBA", (16, 32), (0, 0, 0, 0))
    bob = 1 if step in (1, 3) else 0
    out = c("241815")
    sk_s, sk_m, sk_l = c("cf8e63"), c("f0b489"), c("fcd5b5")
    hr_o, hr_d, hr_m, hr_l = c("1f1210"), c("3b221d"), c("59362e"), c("75493f")
    sm_d, sm_m, sm_l = c("ab6e1f"), c("d48f31"), c("ebaa49")
    st_blue, st_cream = c("263d66"), c("f0e6ce")
    strap = c("c7b387")
    red_dot = c("d93b30")
    wood_pin = c("9e6433")
    pt_d, pt_m = c("263247"), c("364663")
    sh_d, sole = c("241c18"), c("dfd7c5")
    eye, weye = c("211513"), c("f7f1e8")

    hy = 3 + bob
    draw_oval_head(im, hy, out, sk_s, sk_m, sk_l, slim=True)

    # Top bun + crossed paintbrushes
    if direction in (0, 2):
        rect(im, 5, hy - 3, 6, 3, hr_o)
        rect(im, 6, hy - 2, 4, 2, hr_m)
        put(im, 3, hy - 2, wood_pin); put(im, 4, hy - 1, wood_pin)
        put(im, 11, hy - 2, wood_pin); put(im, 12, hy - 3, red_dot)
    else:
        rect(im, 4, hy - 3, 5, 3, hr_o)
        rect(im, 5, hy - 2, 3, 2, hr_m)
        put(im, 2, hy - 2, wood_pin); put(im, 3, hy - 1, wood_pin)
        put(im, 9, hy - 3, red_dot)

    if direction == 0:
        for xx in range(4, 12):
            put(im, xx, hy, hr_m if 4 < xx < 11 else hr_o)
        for xx in range(3, 13):
            put(im, xx, hy + 1, hr_l if xx in (6, 9) else (hr_d if 3 < xx < 12 else hr_o))
        for xx in (3, 4, 5, 10, 11, 12):
            put(im, xx, hy + 2, hr_o if xx in (3, 12) else hr_d)
        put(im, 3, hy + 3, hr_o); put(im, 12, hy + 3, hr_o)
        put(im, 5, hy + 4, hr_d); put(im, 10, hy + 4, hr_d)
        put(im, 5, hy + 5, eye); put(im, 6, hy + 5, weye)
        put(im, 9, hy + 5, weye); put(im, 10, hy + 5, eye)
        put(im, 10, hy + 6, red_dot)  # signature vermilion paint smudge!
        put(im, 7, hy + 7, sk_s); put(im, 8, hy + 7, sk_s)
    elif direction == 2:
        for dy in range(7):
            x0, x1 = (4, 11) if dy in (0, 6) else (3, 12)
            for xx in range(x0, x1 + 1):
                put(im, xx, hy + dy, hr_o if xx in (x0, x1) else (hr_d if dy >= 4 else hr_m))
    else:
        for dy in range(7):
            for xx in range(3, 12):
                if dy <= 2 or xx <= 6:
                    put(im, xx, hy + dy, hr_o if xx == 3 else (hr_m if dy <= 2 else hr_d))
        put(im, 9, hy + 5, weye); put(im, 10, hy + 5, eye)
        put(im, 9, hy + 6, red_dot)

    ty = 13 + bob
    if direction in (0, 2):
        for dy in range(10):
            yy = ty + dy
            stripe = st_cream if dy % 2 == 0 else st_blue
            for xx in range(3, 13):
                if xx in (3, 12) or dy == 9:
                    put(im, xx, yy, out)
                elif dy <= 2 and 5 <= xx <= 10 and direction == 0:
                    put(im, xx, yy, stripe)
                else:
                    put(im, xx, yy, sm_l if dy == 3 else sm_m)
        if direction == 0:
            # Ochre overall straps + canvas brush roll strap on left shoulder
            rect(im, 5, ty, 1, 3, sm_m); rect(im, 10, ty, 1, 3, sm_m)
            rect(im, 4, ty, 2, 6, strap)
            put(im, 5, ty + 4, red_dot); put(im, 4, ty + 4, st_blue)
            rect(im, 6, ty + 5, 4, 3, sm_d)
        la = 1 if step == 1 else (-1 if step == 3 else 0)
        for side_x, shift in ((2, la), (13, -la)):
            ay = ty + 1 + shift
            for sy in range(4):
                rect(im, side_x, ay + sy, 2, 1, st_cream if sy % 2 == 0 else st_blue)
            rect(im, side_x, ay + 4, 2, 2, sk_m)
            rect(im, side_x, ay + 6, 2, 1, out)
    else:
        for dy in range(10):
            yy = ty + dy
            stripe = st_cream if dy % 2 == 0 else st_blue
            for xx in range(4, 12):
                put(im, xx, yy, out if xx in (4, 11) or dy == 9 else (stripe if dy <= 2 else sm_m))
        rect(im, 6, ty, 2, 6, strap)
        ax = 6 + (1 if step == 1 else -1 if step == 3 else 0)
        for sy in range(4):
            rect(im, ax, ty + 2 + sy, 3, 1, st_cream if sy % 2 == 0 else st_blue)
        rect(im, ax, ty + 6, 3, 1, sk_m)
        rect(im, ax, ty + 7, 3, 1, out)

    ly = 23 + bob
    if direction in (0, 2):
        l_end = 30 if step == 1 else 31
        r_end = 30 if step == 3 else 31
        for x0, end_y in ((4, l_end), (9, r_end)):
            for yy in range(ly, end_y - 1):
                put(im, x0 - 1, yy, out); put(im, x0 + 3, yy, out)
                rect(im, x0, yy, 3, 1, pt_m if yy > ly else pt_d)
            rect(im, x0 - 1, end_y - 1, 4, 1, sh_d)
            put(im, x0 - 1, end_y, out); rect(im, x0, end_y, 2, 1, sole); put(im, x0 + 2, end_y, out)
    else:
        if step in (1, 3):
            front_x, back_x = (8, 4) if step == 1 else (4, 8)
            rect(im, back_x, ly, 3, 5, pt_d); rect(im, back_x, 29, 4, 1, sh_d); rect(im, back_x, 30, 4, 1, sole)
            rect(im, front_x, ly, 3, 6, pt_m); rect(im, front_x, 30, 4, 1, sh_d); put(im, front_x, 31, out); rect(im, front_x + 1, 31, 2, 1, sole); put(im, front_x + 3, 31, out)
        else:
            for yy in range(ly, 30):
                put(im, 5, yy, out); rect(im, 6, yy, 4, 1, pt_m); put(im, 10, yy, out)
            rect(im, 5, 30, 6, 1, sh_d)
            put(im, 5, 31, out); rect(im, 6, 31, 4, 1, sole); put(im, 10, 31, out)
    return im


def build_4dir_sheet(fn) -> Image.Image:
    sheet = Image.new("RGBA", (64, 128), (0, 0, 0, 0))
    for row_dir in range(4):
        for step in range(4):
            sheet.paste(fn(row_dir, step), (step * 16, row_dir * 32))
    return sheet


def build_mi_luo() -> Image.Image:
    # 64x32 (2 frames of 32x32 -> 64x64 world). Side-coiled merfolk clockwork tinkerer!
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out = c("122226")
    sk_s, sk_m, sk_l = c("9ec7be"), c("c7e6de"), c("e4f7f2")
    hr_d, hr_m, hr_l = c("104042"), c("1d6666"), c("328f8b")
    fin_d, fin_l = c("c95f4d"), c("f28d79")
    gog_d, gog_l, lens = c("8f6524"), c("e3b54b"), c("699699")
    tun_d, tun_m = c("8f8470"), c("bab09b")
    strap = c("593822")
    gear = c("f0c24d")
    tl_d, tl_m, tl_l = c("145254"), c("217d7a"), c("47b5ab")

    for f in range(2):
        ox = f * 32
        bob = f
        # Wavy teal kelp hair & head (x=9..20, y=2..13)
        rect(im, ox + 9, 2 + bob, 11, 11, out)
        rect(im, ox + 10, 3 + bob, 9, 9, sk_m)
        rect(im, ox + 11, 4 + bob, 7, 4, sk_l)
        # Wavy hair crown & side locks
        rect(im, ox + 9, 2 + bob, 11, 3, hr_m)
        put(im, ox + 11, 2 + bob, hr_l); put(im, ox + 16, 2 + bob, hr_l)
        rect(im, ox + 8, 5 + bob, 2, 8, hr_d)
        rect(im, ox + 19, 5 + bob, 2, 7, hr_d)
        # Coral webbed fin ears (x=6..8 and x=20..22)
        for ex, d_sign in ((6, -1), (20, 1)):
            rect(im, ox + ex, 6 + bob, 3, 4, out)
            rect(im, ox + ex + (1 if d_sign < 0 else 0), 7 + bob, 2, 2, fin_l)
            put(im, ox + ex + 1, 8 + bob, fin_d)
        # Brass watchmaker loupe goggles on forehead (y=4..5)
        rect(im, ox + 10, 4 + bob, 9, 2, gog_d)
        rect(im, ox + 11, 4 + bob, 3, 2, gog_l); put(im, ox + 12, 5 + bob, lens)
        rect(im, ox + 15, 4 + bob, 3, 2, gog_l); put(im, ox + 16, 5 + bob, lens)
        # Eyes & turquoise cheek scales
        put(im, ox + 11, 8 + bob, out); put(im, ox + 12, 8 + bob, tl_l)
        put(im, ox + 16, 8 + bob, tl_l); put(im, ox + 17, 8 + bob, out)
        put(im, ox + 10, 9 + bob, tl_l); put(im, ox + 18, 9 + bob, tl_l)
        rect(im, ox + 13, 10 + bob, 3, 1, sk_s)

        # Sand-linen sea tunic + leather gear bandolier (y=13..20)
        rect(im, ox + 8, 13 + bob, 13, 7, out)
        rect(im, ox + 9, 13 + bob, 11, 6, tun_m)
        rect(im, ox + 9, 17 + bob, 11, 2, tun_d)
        for d in range(6):
            rect(im, ox + 10 + d, 13 + bob + d, 2, 1, strap)
        # Brass gears on strap + held brass clock wheel on right hand
        rect(im, ox + 12, 15 + bob, 2, 2, gear)
        put(im, ox + 15, 17 + bob, gear)
        # Tinkering arms (right hand raises tiny brass gear on frame 1)
        gy = 14 if f == 0 else 13
        rect(im, ox + 21, gy, 4, 4, out)
        rect(im, ox + 22, gy + 1, 2, 2, gear)
        rect(im, ox + 7, 14 + bob, 2, 4, sk_m)
        rect(im, ox + 20, 15, 2, 3, sk_m)

        # Side-coiled iridescent merfolk tail & coral fluke sweeping right (y=19..30)
        tail_segments = [
            (9, 19, 11, 3),
            (10, 22, 12, 3),
            (13, 25, 11, 3),
            (18, 26 - f, 7, 3),
        ]
        for sx, sy, sw, sh in tail_segments:
            rect(im, ox + sx - 1, sy - 1, sw + 2, sh + 2, out)
        for idx, (sx, sy, sw, sh) in enumerate(tail_segments):
            for yy in range(sy, sy + sh):
                for xx in range(sx, sx + sw):
                    col = tl_l if (xx + yy) % 3 == 0 else (tl_m if yy < sy + sh - 1 else tl_d)
                    put(im, ox + xx, yy, col)
        # Coral-tipped tail fin fluke at right tip (x=24..29, y=23..29)
        fy = 24 - f
        rect(im, ox + 24, fy, 5, 6, out)
        rect(im, ox + 25, fy + 1, 3, 4, fin_l)
        put(im, ox + 25, fy + 2, fin_d); put(im, ox + 27, fy + 3, fin_d)
    return im


def build_san_jin() -> Image.Image:
    # 64x32 (2 frames of 32x32 -> 64x64 world). Plump spotted harbor seal with brass scale pan!
    im = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    out = c("241b17")
    fur_d, fur_m, fur_l = c("877d73"), c("b3a89d"), c("dfd7ce")
    spot = c("453b36")
    eye, catch = c("1f1412"), c("f7f2eb")
    br_d, br_m, br_l = c("78581f"), c("ad8434"), c("deb559")
    sh_l, sh_d = c("f0ddd1"), c("b89684")

    for f in range(2):
        ox = f * 32
        tilt = f  # head & flipper pat motion
        # Plump seal body & tail flippers (left-to-right loafing posture, y=8..29)
        # Tail flippers at left (x=2..7, y=22..28)
        rect(im, ox + 2, 22, 6, 6, out)
        rect(im, ox + 3, 23, 4, 4, fur_d)
        put(im, ox + 3, 24, fur_m)
        # Round torso (x=6..23, y=14..29)
        for yy in range(14, 29):
            x0 = 6 if yy >= 18 else (8 if yy >= 16 else 10)
            x1 = 23 if yy >= 18 else 22
            for xx in range(x0, x1 + 1):
                if yy in (14, 28) or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif yy >= 23 and xx >= 13:
                    put(im, ox + xx, yy, fur_l)
                elif yy <= 17:
                    put(im, ox + xx, yy, fur_d)
                else:
                    put(im, ox + xx, yy, fur_m)
        # Round seal head (x=12..25, y=6+tilt..18)
        hy = 6 + (0 if f == 0 else 1)
        head_spans = [
            (15, 21), (13, 23), (12, 24), (12, 25), (12, 25),
            (12, 25), (12, 25), (13, 24), (13, 23),
        ]
        for dy, (x0, x1) in enumerate(head_spans):
            yy = hy + dy
            for xx in range(x0, x1 + 1):
                if dy == 0 or xx in (x0, x1):
                    put(im, ox + xx, yy, out)
                elif dy >= 5 and xx >= 16:
                    put(im, ox + xx, yy, fur_l)
                else:
                    put(im, ox + xx, yy, fur_m)
        # Dark pebble spots on back & crown
        for sx, sy in ((14, hy + 2), (17, hy + 1), (9, 18), (11, 21), (8, 23), (12, 17)):
            put(im, ox + sx, sy, spot)
        # Glossy eyes, nose & whiskers
        rect(im, ox + 16, hy + 3, 2, 2, eye); put(im, ox + 16, hy + 3, catch)
        rect(im, ox + 21, hy + 3, 2, 2, eye); put(im, ox + 21, hy + 3, catch)
        rect(im, ox + 19, hy + 5, 2, 1, out)
        put(im, ox + 18, hy + 6, out); put(im, ox + 20, hy + 6, out)
        put(im, ox + 14, hy + 6, out); put(im, ox + 25, hy + 6, out)

        # Antique brass fish-scale pan at front-right (x=16..29, y=24..30) with scallop shell
        rect(im, ox + 16, 25, 14, 5, out)
        rect(im, ox + 17, 25, 12, 2, br_l)
        rect(im, ox + 17, 27, 12, 2, br_m)
        put(im, ox + 18, 28, br_d); put(im, ox + 27, 28, br_d)
        # Scallop shell inside pan
        rect(im, ox + 23, 26, 3, 2, sh_l)
        put(im, ox + 24, 27, sh_d)
        # Chubby front flipper patting the brass pan rim!
        fy = 22 + (0 if f == 0 else 1)
        rect(im, ox + 14, fy, 6, 4, out)
        rect(im, ox + 15, fy + 1, 4, 2, fur_m)
        put(im, ox + 18, fy + 2, fur_l)
    return im


def sha256_file(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def assert_binary_alpha(img: Image.Image, label: str) -> None:
    for y in range(img.height):
        for x in range(img.width):
            a = img.getpixel((x, y))[3]
            assert a in (0, 255), f"Non-binary alpha in {label} at ({x},{y}): {a}"


def main() -> None:
    root = Path(__file__).resolve().parents[1]
    assets = root / "assets"
    hp_dir = assets / "portraits" / "harbor"
    op_dir = assets / "portraits" / "ocean"
    hc_dir = assets / "characters" / "harbor"
    oc_dir = assets / "characters" / "ocean"

    # 1. Extract & verify 4 64x64 portraits
    for npc_id, (group, fname) in PORTRAIT_RAW.items():
        p_img = extract_parchment_64_portrait(RAW_DIR / fname)
        assert_binary_alpha(p_img, f"portrait:{npc_id}")
        target_dir = hp_dir if group == "harbor" else op_dir
        p_img.save(target_dir / f"{npc_id}.png", "PNG")

    # 2. Build & verify 4 world sprite sheets
    cen_sheet = build_4dir_sheet(draw_cen_po_frame)
    a_yuan_sheet = build_4dir_sheet(draw_a_yuan_frame)
    assert_binary_alpha(cen_sheet, "world:cen_po")
    assert_binary_alpha(a_yuan_sheet, "world:a_yuan")
    cen_sheet.save(hc_dir / "cen_po.png", "PNG")
    a_yuan_sheet.save(hc_dir / "a_yuan.png", "PNG")

    mi_luo_sheet = build_mi_luo()
    san_jin_sheet = build_san_jin()
    assert_binary_alpha(mi_luo_sheet, "world:mi_luo")
    assert_binary_alpha(san_jin_sheet, "world:san_jin")
    mi_luo_sheet.save(oc_dir / "mi_luo.png", "PNG")
    san_jin_sheet.save(oc_dir / "san_jin.png", "PNG")

    # 3. Rebuild all 4 manifests deterministically
    for p_dir in (hp_dir, op_dir):
        files = sorted(p.name for p in p_dir.glob("*.png"))
        (p_dir / "manifest.json").write_text(
            json.dumps(
                {
                    "files": [
                        {
                            "id": fn[:-4],
                            "file": fn,
                            "canvas": list(Image.open(p_dir / fn).size),
                            "sha256": sha256_file(p_dir / fn),
                        }
                        for fn in files
                    ]
                },
                indent=2,
            )
            + "\n",
            encoding="utf-8",
        )

    hc_files = sorted(p.name for p in hc_dir.glob("*.png"))
    (hc_dir / "manifest.json").write_text(
        json.dumps(
            {
                "files": [
                    {
                        "file": fn,
                        "canvas": list(Image.open(hc_dir / fn).size),
                        "sha256": sha256_file(hc_dir / fn),
                    }
                    for fn in hc_files
                ]
            },
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    oc_files = sorted(p.name for p in oc_dir.glob("*.png"))
    oc_manifest = {
        "version": "0.22.0",
        "license": "Original project pixel art (redistributable)",
        "files": {
            fn: {
                "width": Image.open(oc_dir / fn).width,
                "height": Image.open(oc_dir / fn).height,
                "sha256": sha256_file(oc_dir / fn),
            }
            for fn in oc_files
        },
    }
    (oc_dir / "manifest.json").write_text(json.dumps(oc_manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    # 4. Build visual contact sheet for 0.22 verification
    contact = Image.new("RGBA", (680, 380), c("28363a"))
    rect(contact, 0, 0, 680, 136, c("f0e6cd"))
    order = ["cen_po", "a_yuan", "mi_luo", "san_jin"]
    for idx, npc_id in enumerate(order):
        ox = 20 + idx * 164
        p_dir = hp_dir if npc_id in ("cen_po", "a_yuan") else op_dir
        p_img = Image.open(p_dir / f"{npc_id}.png").resize((96, 96), Image.Resampling.NEAREST)
        contact.alpha_composite(p_img, (ox + 20, 20))
        if npc_id in ("cen_po", "a_yuan"):
            s = Image.open(hc_dir / f"{npc_id}.png")
            for d_idx, sheet_row in enumerate((0, 1, 3, 2)):
                f0 = s.crop((0, sheet_row * 32, 16, (sheet_row + 1) * 32)).resize((32, 64), Image.Resampling.NEAREST)
                contact.alpha_composite(f0, (ox + d_idx * 34, 156))
            fw = s.crop((16, 0, 32, 32)).resize((32, 64), Image.Resampling.NEAREST)
            contact.alpha_composite(fw, (ox + 50, 240))
        else:
            s = Image.open(oc_dir / f"{npc_id}.png")
            for f_idx in range(2):
                fr = s.crop((f_idx * 32, 0, (f_idx + 1) * 32, 32)).resize((64, 64), Image.Resampling.NEAREST)
                contact.alpha_composite(fr, (ox + f_idx * 72, 168))

    contact_out = RAW_DIR / "scratch" / "contact_022.png"
    contact_out.parent.mkdir(parents=True, exist_ok=True)
    contact.save(contact_out, "PNG")
    print("Built 0.22 portraits & world sprites ->", contact_out)


if __name__ == "__main__":
    main()

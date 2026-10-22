"""Роуэн (Robin Hood маягийн баатар)-ы pixel sprite-уудыг үүсгэнэ.

Үсэг бүр нэг өнгө. "." бол тунгалаг. Засаад `python3 hero.py` гэж ажиллуулахад PNG-үүд дахин үүснэ.
"""
from PIL import Image, ImageDraw
import os

OUT = os.path.dirname(os.path.abspath(__file__))
NAME = "rowan"

PAL = {
    "S": (252, 184, 160), "s": (216, 136, 112), "E": (24, 16, 40),   # арьс, сүүдэр, нүд
    "h": (136, 56, 0),                                                # үс
    "G": (88, 216, 84), "g": (24, 120, 24), "r": (216, 40, 0),       # малгай, малгайн сүүдэр, өд
    "T": (56, 168, 56), "t": (24, 104, 24),                           # цамц
    "L": (107, 58, 16), "Y": (248, 184, 0),                           # бүс, гархи
    "P": (120, 104, 48), "N": (80, 48, 0),                            # өмд, гутал
    "Q": (168, 96, 0), "q": (107, 58, 16),                            # нум, сагадаг
    "W": (252, 252, 252), "w": (168, 168, 168),                       # ган, сум
    "H": (168, 96, 0), "j": (200, 128, 32),                           # бамбай
}
OUTLINE = (26, 16, 40)
F = 32  # frame size

TOP = [  # rows 2..16: малгай, толгой, цамцны дээд хэсэг (баруун тийш харсан)
    "...r............",
    "....r.GGG.......",
    "....rGGGGGG.....",
    "....gGGGGGGGG...",
    "....hhSSSSS.....",
    "....hSSSSES.....",
    "....hSSSSES.....",
    "....hsSSSSS.....",
    ".....hSSSS......",
    ".....tTTTTT.....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
]
MID = [  # rows 17..25: бүс, цамцны доод хэсэг (шүдлэг захтай)
    "....LLLLLYLL....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
    "....tTTTTTTT....",
    "...ttTTTTTTTT...",
    "...tTTTTTTTTT...",
    "...tTTTTTTTTT...",
    "...tTtTtTtTtT...",
    "...t.t.t.t.t....",
]


def legs(rows):  # дээд 3 мөр нь өмд, доод нь гутал
    return [r.replace("N", "P") if i < 3 else r for i, r in enumerate(rows)]


LEGS = {
    "stand": legs([".....NN..NN.....", ".....NN..NN.....", ".....NN..NN.....",
                   ".....NN..NN.....", "....NNN..NNN....", "....NNN..NNN...."]),
    "walkA": legs(["....NN....NN....", "....NN....NN....", "...NN......NN...",
                   "...NN......NN...", "..NNN......NNN..", "..NNN......NNN.."]),
    "walkB": legs([".....NN..NN.....", ".....NN..NN.....", ".....NN..NN.....",
                   ".....NN.NNN.....", "....NNN.NN......", "....NNN........."]),
    "walkC": legs([".....NN..NN.....", ".....NN..NN.....", ".....NN..NN.....",
                   ".....NNN.NN.....", "......NN.NNN....", ".........NNN...."]),
    "jump":  legs(["....NNNNNNN.....", "....NNN.NNN.....", "...NNN...NNN....",
                   "...NN.....NN....", "................", "................"]),
}
X0 = 8  # 16 пикселийн биеийн зүүн ирмэг 32px кадр дотор


def blank():
    return [["." for _ in range(F)] for _ in range(F)]


def paste(g, rows, dx, dy):
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            x, y = dx + i, dy + j
            if ch != "." and 0 <= x < F and 0 <= y < F:
                g[y][x] = ch


def dot(g, pts, ch):
    for x, y in pts:
        if 0 <= x < F and 0 <= y < F:
            g[y][x] = ch


def quiver(g, dy=0):  # нуруун дээрх сагадаг, сумны өдтэй
    dot(g, [(X0 + 1, 8 + dy), (X0 + 3, 8 + dy)], "r")
    dot(g, [(X0 + 2, 9 + dy), (X0 + 1, 9 + dy), (X0 + 3, 9 + dy)], "W")
    for y in range(10, 17):
        dot(g, [(X0 + 2, y + dy)], "Q")
        dot(g, [(X0 + 3, y + dy)], "q")


def shield(g, top):  # 3x10 модон бамбай урдаа
    for y in range(top, top + 10):
        edge = y in (top, top + 9)
        dot(g, [(X0 + 12, y), (X0 + 14, y)], "H")
        if not edge:
            dot(g, [(X0 + 13, y)], "j")
    dot(g, [(X0 + 13, top + 4), (X0 + 13, top + 5)], "Y")
    dot(g, [(X0 + 11, top + 5)], "S")  # гар


def sword_hip(g, dy=0):
    dot(g, [(X0 + 3, 17 + dy), (X0 + 4, 17 + dy)], "Y")
    dot(g, [(X0 + 3, y + dy) for y in range(18, 25)], "W")


def sword_raised(g, dy=0):
    dot(g, [(X0 + 4, 12 + dy), (X0 + 5, 12 + dy)], "S")
    dot(g, [(X0 + 3, 11 + dy), (X0 + 4, 11 + dy), (X0 + 5, 11 + dy)], "Y")
    dot(g, [(X0 + 4, y + dy) for y in range(1, 11)], "W")


def sword_thrust(g, row):
    dot(g, [(X0 + 11, row), (X0 + 12, row), (X0 + 11, row + 1), (X0 + 12, row + 1)], "T")
    dot(g, [(X0 + 13, row), (X0 + 13, row + 1)], "S")
    dot(g, [(X0 + 14, row - 1), (X0 + 14, row), (X0 + 14, row + 1), (X0 + 14, row + 2)], "Y")
    dot(g, [(X0 + x, row) for x in range(15, 24)], "W")
    dot(g, [(X0 + x, row + 1) for x in range(15, 23)], "w")


def bow(g, drawn):  # нум, drawn=True бол хөвчөө татсан
    dot(g, [(X0 + 15, y) for y in range(13, 22)], "Q")
    dot(g, [(X0 + 14, 12), (X0 + 14, 22)], "Q")
    dot(g, [(X0 + 11, 17), (X0 + 12, 17), (X0 + 13, 17), (X0 + 14, 17)], "T")
    dot(g, [(X0 + 15, 17)], "S")
    if drawn:
        dot(g, [(X0 + 13, 13), (X0 + 12, 14), (X0 + 11, 15), (X0 + 11, 19), (X0 + 12, 20), (X0 + 13, 21)], "W")
        dot(g, [(X0 + x, 16) for x in range(10, 19)], "w")
        dot(g, [(X0 + 19, 16)], "W")
        dot(g, [(X0 + 9, 15), (X0 + 9, 17)], "r")
        dot(g, [(X0 + 10, 17)], "S")
    else:
        dot(g, [(X0 + 14, y) for y in range(13, 22)], "W")


def body(leg="stand", bob=0, crouch=False):
    g = blank()
    if crouch:
        paste(g, TOP, X0, 2 + 6)
        paste(g, MID[:7], X0, 17 + 6)
        paste(g, ["...NNNttttNNN...."], X0, 31)
        quiver(g, 6)
    else:
        paste(g, LEGS[leg], X0, 26)
        paste(g, MID, X0, 17 + bob)
        paste(g, TOP, X0, 2 + bob)
        quiver(g, bob)
    return g


def frame(kind):
    if kind == "idle1":
        g = body(); shield(g, 13); sword_hip(g)
    elif kind == "idle2":
        g = blank(); paste(g, LEGS["stand"], X0, 26); paste(g, MID, X0, 17)
        paste(g, TOP, X0, 3); quiver(g, 1); shield(g, 14); sword_hip(g)
    elif kind in ("walk1", "walk3"):
        g = body("walkA"); shield(g, 13); sword_hip(g)
    elif kind == "walk2":
        g = body("walkB", bob=-1); shield(g, 12); sword_hip(g, -1)
    elif kind == "walk4":
        g = body("walkC", bob=-1); shield(g, 12); sword_hip(g, -1)
    elif kind == "jump":
        g = blank(); paste(g, LEGS["jump"], X0, 24); paste(g, MID, X0, 15)
        paste(g, TOP, X0, 0); quiver(g, -2); shield(g, 11); sword_hip(g, -2)
    elif kind == "crouch":
        g = body(crouch=True); shield(g, 20); sword_hip(g, 6)
    elif kind == "attack1":
        g = body(); shield(g, 13); sword_raised(g)
    elif kind == "attack2":
        g = body(); sword_thrust(g, 18)
        for y in range(13, 23):  # хатгахдаа бамбайгаа бага зэрэг хойш татна
            dot(g, [(X0 + 10, y)], "H")
    elif kind == "crouch_attack":
        g = body(crouch=True); sword_thrust(g, 25)
        for y in range(20, 30):
            dot(g, [(X0 + 10, y)], "H")
    elif kind == "shoot1":
        g = body(); sword_hip(g); bow(g, True)
    elif kind == "shoot2":
        g = body(); sword_hip(g); bow(g, False)
    elif kind == "hurt":
        g = body(leg="walkA"); shield(g, 13)
        dot(g, [(X0 + 9, 8), (X0 + 9, 9)], "S"); dot(g, [(X0 + 8, 9), (X0 + 9, 9)], "E")
    return g


def render(g):
    im = Image.new("RGBA", (F, F), (0, 0, 0, 0))
    px = im.load()
    for y in range(F):
        for x in range(F):
            if g[y][x] != ".":
                px[x, y] = PAL[g[y][x]] + (255,)
    out = im.copy(); po = out.load()  # 1px бараан хүрээ
    for y in range(F):
        for x in range(F):
            if px[x, y][3] == 0:
                for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    nx, ny = x + ax, y + ay
                    if 0 <= nx < F and 0 <= ny < F and px[nx, ny][3]:
                        po[x, y] = OUTLINE + (255,); break
    return out


ANIMS = {
    "idle": ["idle1", "idle2"],
    "walk": ["walk1", "walk2", "walk3", "walk4"],
    "jump": ["jump"],
    "crouch": ["crouch"],
    "attack": ["attack1", "attack2"],
    "crouch_attack": ["crouch", "crouch_attack"],
    "shoot": ["shoot1", "shoot2"],
    "hurt": ["hurt"],
}

frames = {}
for kinds in ANIMS.values():
    for k in kinds:
        frames.setdefault(k, render(frame(k)))

# анимаци бүр тусдаа хэвтээ зурвас (Pixelorama: Spritesheet, Horizontal frames = кадрын тоо)
for name, kinds in ANIMS.items():
    strip = Image.new("RGBA", (F * len(kinds), F), (0, 0, 0, 0))
    for i, k in enumerate(kinds):
        strip.paste(frames[k], (i * F, 0))
    strip.save(f"{OUT}/{NAME}_{name}.png")

# бүх анимаци нэг файлд, мөр бүр нэг анимаци
cols = max(len(v) for v in ANIMS.values())
sheet = Image.new("RGBA", (F * cols, F * len(ANIMS)), (0, 0, 0, 0))
for r, kinds in enumerate(ANIMS.values()):
    for i, k in enumerate(kinds):
        sheet.paste(frames[k], (i * F, r * F))
sheet.save(f"{OUT}/{NAME}_sheet.png")

# зөвхөн харахад зориулсан 8 дахин томруулсан зураг
S = 8
prev = Image.new("RGBA", (F * cols * S + 160, F * len(ANIMS) * S), (20, 15, 42, 255))
d = ImageDraw.Draw(prev)
for r, (name, kinds) in enumerate(ANIMS.items()):
    d.text((8, r * F * S + 8), name, fill=(240, 236, 255))
    for i, k in enumerate(kinds):
        x, y = 160 + i * F * S, r * F * S
        d.rectangle([x, y, x + F * S - 1, y + F * S - 1], fill=(36, 30, 80) if (i + r) % 2 else (30, 25, 68))
        prev.alpha_composite(frames[k].resize((F * S, F * S), Image.NEAREST), (x, y))
prev.save(f"{OUT}/{NAME}_preview.png")
print("ok")

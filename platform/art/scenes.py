"""3 бүлгийн концепт зураг (Шорон, Их танхим, Цамхаг)-ийг pixel art-аар үүсгэнэ.

rowan_sheet.png-г ашигладаг тул эхлээд hero.py-г ажиллуулсан байх ёстой.
Гаралт: scene_ch1.png, scene_ch2.png, scene_ch3.png (320x180, 4 дахин томруулсан 1280x720).
"""
from PIL import Image, ImageDraw, ImageOps
import math, os, random

HERE = os.path.dirname(os.path.abspath(__file__))
W, H, FLOOR, SCALE = 320, 180, 156, 4
OUTLINE = (26, 16, 40, 255)

PAL = {
    "S": (252, 184, 160), "s": (216, 136, 112), "E": (24, 16, 40), "W": (252, 252, 252), "w": (168, 168, 168),
    "K": (16, 12, 24), "R": (248, 56, 0), "r": (168, 0, 32), "Y": (248, 184, 0),
    "M": (188, 188, 188), "m": (140, 140, 140), "A": (124, 124, 124), "a": (88, 88, 88), "k": (32, 32, 32),
    "L": (120, 72, 32), "l": (88, 48, 16), "V": (106, 42, 156), "v": (64, 20, 94), "p": (200, 120, 255),
    "T": (168, 24, 40),
}

# ---------- sprites (бүгд баруун тийш харсан) ----------
GORT = [
    "......rr........", ".....rrr........", "....MMMMMM......", "...MMMMMMMM.....",
    "...MmMMMKKM.....", "...MmMMMKRM.....", "...MmMMMMMM.....", "....MMMMMM......",
    "...AAAAAAAA.....", "..AAAAAAAAAA....", "..aAAAAAAAAA....", "..aAAAAAAAAA....",
    "..aAAAAAAAAA....", "..aAAAAAAAAA....", "..aAAAAAAAAA....", "..aAAAAAAAAA....",
    "..rrrrrrrrrr....", "..aAAAAAAAAA....", "..aAAAAAAAAA....", "...aAAAAAAA.....",
    "...aAA..AAA.....", "...aAA..AAA.....", "...aAA..AAA.....", "...aAA..AAA.....",
    "...aAA..AAA.....", "...aAA..AAA.....", "..kkkk..kkkk....", "..kkkk..kkkk....",
]
GUARD = [
    ".............W..", "............WWW.", ".............w..", "....aaaaa....w..",
    "...aMMMMMa...w..", "...aSSSSS....w..", "...SSSESS....w..", "...SSSSSS....w..",
    "....SSSS.....w..", "...TTTTTTT...w..", "..TTTTTTTTTSSw..", "..TTTTYTTTT..w..",
    "..TTTYYYTTT..w..", "..TTTTYTTTT..w..", "..TTTTTTTTT..w..", "..LLLLLLLLL..w..",
    "..TTTTTTTTT..w..", "..TTTTTTTTT..w..", "...TTTTTTT...w..", "...aaa.aaa...w..",
    "...aaa.aaa...w..", "...aaa.aaa...w..", "...aaa.aaa...w..", "...aaa.aaa...w..",
    "..kkkk.kkkk..w..", "..kkkk.kkkk.....",
]
JAILER = (
    ["........KKKKK.........", ".......KKKKKKK........", "......KKKKKKKKK.......",
     "......KKKWKKWKK.......", "......KKKKKKKKK.......", ".......KKKKKKK........",
     "....SSSSKKKKKSSSS.....", "...SSSSSLLLLLSSSSS....", "..SSSSSLLLLLLLSSSSS...",
     "..SSS.LLLLLLLLL.SSS...", "..SSS.LLLLLLLLL.SSS...", "..SSS.LLLLLLLLL.SSS...",
     "..ss..LLLLLLLLL..ss...", "..ss..lllYlllll..ss...", "..SS..LLLLLLLLL..SS...",
     "..SS..LLLLLLLLL..SS..."]
    + ["......LLLLLLLLL......."] * 6
    + [".....LLLLLLLLLLL......"]
    + [".....aaa.....aaa......"] * 6
    + ["....kkkk.....kkkk....."] * 2
)
MALVANE = [
    "....KKKKKK......", "...KKKKKKKK.....", "...KSSSSSK......", "...KSSSESS......",
    "...KSSSSSS......", "....SSSSS.......", "...YVVVVVVY.....", "..vVVVVVVVVV....",
    "..vVVVYVVVVV....", "..vVVVYVVVVV....", "..vVVVVVVVVSSpppp", "..vVVVVVVVVV....",
    "..vVVYYYYVVV....", "..vVVVVVVVVV....", "..vVVVVVVVVV....", ".vvVVVVVVVVVV...",
    ".vVVVVVVVVVVV...", ".vVVVVVVVVVVV...", ".vVVVVVVVVVVV...", ".vVVVVVVVVVVVV..",
    "vvVVVVVVVVVVVV..", "vVVVVVVVVVVVVVV.", "vVVVVVVVVVVVVVV.", "vVVVVVVVVVVVVVV.",
    "vVVVVVVVVVVVVVV.", "vYYYYYYYYYYYYYY.", "...kk....kk.....",
]
CROWN = ["K..K..K", "KK.K.KK", "KKKKKKK", "KpKpKpK", "YYYYYYY"]
RAT = ["......aa.", "..aaaaaaR", "laaaaaaa.", "..k..k..."]
BAT = ["V.......V", "VV.VVV.VV", ".VVVVVVV.", "..R...R.."]
HEART = [".XX.XX.", "XXXXXXX", "XXXXXXX", ".XXXXX.", "..XXX..", "...X..."]


def sprite(rows, mirror=False):
    w, h = max(len(r) for r in rows), len(rows)
    im = Image.new("RGBA", (w + 2, h + 2), (0, 0, 0, 0))
    px = im.load()
    for j, row in enumerate(rows):
        for i, ch in enumerate(row):
            if ch != ".":
                px[i + 1, j + 1] = PAL[ch] + (255,)
    out = im.copy(); po = out.load()
    for y in range(h + 2):
        for x in range(w + 2):
            if px[x, y][3] == 0 and any(
                0 <= x + ax < w + 2 and 0 <= y + ay < h + 2 and px[x + ax, y + ay][3]
                for ax, ay in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                po[x, y] = OUTLINE
    return ImageOps.mirror(out) if mirror else out


def place(img, spr, cx, feet):
    img.alpha_composite(spr, (int(cx - spr.width / 2), int(feet - spr.height + 1)))


SHEET = Image.open(os.path.join(HERE, "rowan_sheet.png")).convert("RGBA")
ROWS = {"idle": 0, "walk": 1, "jump": 2, "crouch": 3, "attack": 4, "crouch_attack": 5, "shoot": 6, "hurt": 7}


def rowan(anim, frame, mirror=False):
    r = ROWS[anim]
    f = SHEET.crop((frame * 32, r * 32, frame * 32 + 32, r * 32 + 32))
    return ImageOps.mirror(f) if mirror else f


def bricks(d, x0, y0, x1, y1, bw, bh, cols, mortar):
    d.rectangle([x0, y0, x1, y1], fill=mortar)
    rnd = random.Random(x0 * 7 + y0)
    for row, y in enumerate(range(y0, y1, bh)):
        off = (bw // 2) if row % 2 else 0
        for x in range(x0 - bw, x1, bw):
            bx = x + off
            ax, bx2 = max(x0, bx + 1), min(x1, bx + bw - 1)
            if bx2 >= ax:
                d.rectangle([ax, y + 1, bx2, min(y1, y + bh - 1)], fill=rnd.choice(cols))


def torch(d, x, y):
    d.rectangle([x - 1, y, x + 1, y + 7], fill=(80, 48, 0)); d.rectangle([x - 3, y, x + 3, y + 1], fill=(80, 48, 0))
    d.rectangle([x - 2, y - 6, x + 2, y - 1], fill=(216, 40, 0)); d.rectangle([x - 1, y - 5, x + 1, y - 2], fill=(252, 160, 68))
    d.point((x, y - 3), fill=(248, 184, 0))


def glow(img, cx, cy, r, col):
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0)); ld = ImageDraw.Draw(lay)
    for k in range(r, 0, -2):
        a = int(70 * (1 - k / r)) + 8
        ld.ellipse([cx - k, cy - k, cx + k, cy + k], fill=col + (a,))
    img.alpha_composite(lay)


def hud(img, hp, arrows, boss):
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 11], fill=(0, 0, 0))
    for i in range(6):
        col = (216, 40, 0) if i < hp else (58, 20, 16)
        for j, row in enumerate(HEART):
            for k, ch in enumerate(row):
                if ch == "X":
                    d.point((5 + i * 9 + k, 3 + j), fill=col)
    for i in range(arrows):  # сумны тоо
        x = 70 + i * 6
        d.line([x, 3, x, 8], fill=(252, 252, 252)); d.point((x, 2), fill=(168, 168, 168))
        d.point((x - 1, 8), fill=(216, 40, 0)); d.point((x + 1, 8), fill=(216, 40, 0))
    if boss is not None:
        for i in range(8):
            d.rectangle([228 + i * 11, 4, 236 + i * 11, 7], fill=(168, 0, 32) if i < boss else (42, 10, 20))


def spark(d, x, y):
    for dx, dy in ((0, -3), (0, 3), (-3, 0), (3, 0), (-2, -2), (2, 2), (2, -2), (-2, 2)):
        d.point((x + dx, y + dy), fill=(252, 252, 252))
    d.point((x, y), fill=(248, 184, 0))


# ---------- 1-р бүлэг: Шорон ----------
def ch1():
    img = Image.new("RGBA", (W, H), (20, 24, 40, 255)); d = ImageDraw.Draw(img)
    bricks(d, 0, 12, W, FLOOR, 16, 8, [(42, 48, 72), (50, 58, 86), (38, 44, 66)], (20, 24, 40))
    for cx in (52, 268):  # шоронгийн өрөөнүүд
        d.rectangle([cx - 26, 46, cx + 26, FLOOR - 1], fill=(8, 10, 18))
        d.rectangle([cx - 28, 42, cx + 28, 45], fill=(88, 88, 88))
    # Брам торны цаана
    d.rectangle([40, 112, 64, FLOOR - 1], fill=(52, 38, 30)); d.ellipse([44, 96, 60, 114], fill=(52, 38, 30))
    d.point((49, 104), fill=(252, 252, 252)); d.point((55, 104), fill=(252, 252, 252))
    for cx in (52, 268):
        for x in range(cx - 24, cx + 26, 6):
            d.rectangle([x, 46, x + 1, FLOOR - 1], fill=(124, 124, 124))
        d.rectangle([cx - 26, 70, cx + 26, 71], fill=(124, 124, 124))
    for x in (110, 210):  # гинж
        for y in range(12, 60, 3):
            d.point((x, y), fill=(110, 110, 110)); d.point((x + 1, y + 1), fill=(80, 80, 80))
        d.ellipse([x - 3, 58, x + 4, 64], outline=(110, 110, 110))
    torch(d, 92, 70); torch(d, 230, 70)
    d.rectangle([0, FLOOR, W, H], fill=(46, 46, 60))
    for x in range(0, W, 16):
        d.rectangle([x + 1, FLOOR + 1, x + 15, FLOOR + 7], fill=(66, 66, 84))
        d.rectangle([x + 9, FLOOR + 9, x + 23, FLOOR + 15], fill=(58, 58, 76))
    d.rectangle([150, FLOOR + 2, 170, FLOOR + 6], fill=(10, 12, 20))  # ус зайлуулах сараалж
    for x in range(152, 170, 4):
        d.line([x, FLOOR + 2, x, FLOOR + 6], fill=(88, 88, 88))
    place(img, sprite(RAT), 168, FLOOR - 1)
    place(img, rowan("attack", 1), 128, FLOOR - 1)
    # Шоронгийн манаач, гинжит бороохойтой
    place(img, sprite(JAILER, mirror=True), 214, FLOOR - 1)
    for t in range(0, 12):
        d.point((200 - t * 1.4, 128 + t * 0.6), fill=(140, 140, 140))
    d.ellipse([178, 130, 188, 140], fill=(88, 88, 88), outline=OUTLINE[:3])
    for a in range(0, 360, 60):
        d.point((183 + 6 * math.cos(math.radians(a)), 135 + 6 * math.sin(math.radians(a))), fill=(188, 188, 188))
    hud(img, 5, 4, 6)
    return img


# ---------- 2-р бүлэг: Их танхим ----------
def ch2():
    img = Image.new("RGBA", (W, H), (42, 15, 20, 255)); d = ImageDraw.Draw(img)
    bricks(d, 0, 12, W, FLOOR, 24, 10, [(58, 22, 28), (69, 27, 34), (52, 20, 26)], (36, 12, 18))
    for cx in (40, 160, 280):  # цонх, сарны гэрэл
        d.rectangle([cx - 14, 34, cx + 14, 104], fill=(28, 44, 90)); d.ellipse([cx - 14, 20, cx + 14, 48], fill=(28, 44, 90))
        d.line([cx, 22, cx, 104], fill=(88, 48, 16)); d.line([cx - 14, 62, cx + 14, 62], fill=(88, 48, 16))
        d.rectangle([cx - 16, 104, cx + 16, 107], fill=(88, 48, 16))
    lay = Image.new("RGBA", img.size, (0, 0, 0, 0)); ld = ImageDraw.Draw(lay)
    for cx in (40, 160, 280):
        ld.polygon([(cx - 14, 104), (cx + 14, 104), (cx + 40, FLOOR), (cx - 4, FLOOR)], fill=(120, 150, 255, 28))
    img.alpha_composite(lay); d = ImageDraw.Draw(img)
    for cx in (100, 220):  # туг
        d.rectangle([cx - 10, 22, cx + 10, 82], fill=(168, 24, 40)); d.polygon([(cx - 10, 82), (cx, 90), (cx + 10, 82)], fill=(168, 24, 40))
        d.polygon([(cx, 40), (cx + 6, 50), (cx, 60), (cx - 6, 50)], fill=(248, 184, 0)); d.rectangle([cx - 12, 20, cx + 12, 21], fill=(248, 184, 0))
    d.line([160, 12, 160, 18], fill=(248, 184, 0)); d.rectangle([146, 18, 174, 19], fill=(248, 184, 0))  # дэнлүү
    for x in (148, 156, 164, 172):
        d.rectangle([x, 15, x + 1, 17], fill=(252, 252, 252)); d.point((x, 14), fill=(252, 160, 68))
    # тагт
    d.rectangle([214, 100, W, 107], fill=(96, 72, 64))
    for x in range(218, W, 10):
        d.rectangle([x, 107, x + 3, 118], fill=(96, 72, 64))
    place(img, sprite(GUARD, mirror=True), 262, 99)
    d.rectangle([0, FLOOR, W, H], fill=(88, 48, 16))
    for y in range(FLOOR + 1, H, 6):
        for x in range((y // 6 % 2) * 20, W, 40):
            d.rectangle([x, y, x + 38, y + 4], fill=(124, 76, 32))
    d.rectangle([60, FLOOR, 260, FLOOR + 3], fill=(168, 24, 40))
    place(img, rowan("attack", 1), 126, FLOOR - 1)
    gort = sprite(GORT, mirror=True)
    gd = ImageDraw.Draw(gort)  # бамбай доод хэсэгт
    for y in range(17, 28):
        gd.line([1, y, 3, y], fill=(168, 0, 32)); gd.point((2, y), fill=(216, 40, 72))
    gd.point((2, 22), fill=(248, 184, 0)); gd.rectangle([0, 17, 0, 27], fill=OUTLINE)
    place(img, gort, 158, FLOOR - 1)
    spark(d, 152, 133)
    hud(img, 4, 3, 5)
    return img


# ---------- 3-р бүлэг: Цамхаг ----------
def ch3():
    img = Image.new("RGBA", (W, H), (0, 0, 0, 255)); d = ImageDraw.Draw(img)
    for y in range(12, H):
        t = (y - 12) / (H - 12)
        d.line([0, y, W, y], fill=(int(14 + 40 * t), int(10 + 12 * t), int(40 + 50 * t)))
    rnd = random.Random(3)
    for _ in range(70):
        d.point((rnd.randrange(W), rnd.randrange(14, 120)), fill=(220, 220, 255))
    d.ellipse([28, 22, 64, 58], fill=(240, 232, 200)); d.ellipse([36, 28, 44, 36], fill=(220, 210, 180))
    # хол харагдах цамхгууд
    for x, h in ((120, 70), (150, 90), (300, 60)):
        d.rectangle([x, FLOOR - h, x + 14, FLOOR], fill=(30, 22, 54))
        for k in range(x, x + 14, 4):
            d.rectangle([k, FLOOR - h - 3, k + 2, FLOOR - h], fill=(30, 22, 54))
        d.rectangle([x + 6, FLOOR - h + 10, x + 8, FLOOR - h + 14], fill=(248, 184, 0))
    # цамхгийн орой
    d.rectangle([0, FLOOR, W, H], fill=(70, 66, 92))
    for x in range(0, W, 16):
        d.rectangle([x, FLOOR - 8, x + 9, FLOOR], fill=(70, 66, 92)); d.rectangle([x + 1, FLOOR - 7, x + 8, FLOOR - 1], fill=(88, 84, 112))
        d.rectangle([x + 1, FLOOR + 1, x + 15, FLOOR + 7], fill=(88, 84, 112))
    # нурж буй тавцан
    d.rectangle([54, 116, 106, 123], fill=(70, 66, 92)); d.rectangle([56, 117, 104, 121], fill=(88, 84, 112))
    for x, y in ((60, 126), (78, 130), (98, 127)):
        d.rectangle([x, y, x + 2, y + 2], fill=(70, 66, 92))
    for x, y in ((140, 50), (190, 36), (230, 64)):
        place(img, sprite(BAT), x, y)
    place(img, rowan("shoot", 0), 82, 115)
    d.line([150, 100, 160, 100], fill=(168, 168, 168)); d.point((161, 100), fill=(252, 252, 252)); d.point((149, 99), fill=(216, 40, 0))
    # сүүдэр Роуэн
    sh = rowan("idle", 0, mirror=True); px = sh.load()
    for y in range(32):
        for x in range(32):
            if px[x, y][3] and px[x, y][:3] != OUTLINE[:3]:
                px[x, y] = (46, 32, 78, 255)
    px[14, 7] = (248, 56, 0, 255); px[14, 8] = (248, 56, 0, 255)
    place(img, sh, 196, FLOOR - 1)
    place(img, sprite(MALVANE, mirror=True), 262, FLOOR - 1)
    glow(img, 230, 100, 18, (180, 90, 255))
    place(img, sprite(CROWN), 230, 103)
    hud(img, 3, 2, 3)
    return img


for name, fn in (("scene_ch1", ch1), ("scene_ch2", ch2), ("scene_ch3", ch3)):
    im = fn()
    im.save(os.path.join(HERE, name + "_small.png"))
    im.resize((W * SCALE, H * SCALE), Image.NEAREST).save(os.path.join(HERE, name + ".png"))
print("ok")

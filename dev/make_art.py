# Draws Flintar's Fun 'n' Games's own textures into ../Art as 32-bit TGA files
# (power-of-two sizes, which is what the game needs). Run: python make_art.py
# Shapes are drawn 4x larger and scaled down, for smooth edges.
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'Art')
os.makedirs(OUT, exist_ok=True)
SS = 4  # supersampling

RED = (200, 30, 40, 255)
BLACK = (25, 25, 30, 255)
GOLD = (222, 178, 74, 255)


def save(img, name, size):
    img = img.resize(size, Image.LANCZOS)
    img.save(os.path.join(OUT, name + '.tga'))


# ---------------------------------------------------------------- suits
def suit(kind):
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = n / 64.0

    def circle(cx, cy, r, col):
        d.ellipse([(cx - r) * s, (cy - r) * s, (cx + r) * s, (cy + r) * s], fill=col)

    def poly(pts, col):
        d.polygon([(x * s, y * s) for x, y in pts], fill=col)

    if kind == 'heart':
        circle(21, 22, 13, RED)
        circle(43, 22, 13, RED)
        poly([(9, 27), (55, 27), (32, 56)], RED)
    elif kind == 'diamond':
        poly([(32, 4), (54, 32), (32, 60), (10, 32)], RED)
    elif kind == 'spade':
        circle(21, 36, 12, BLACK)
        circle(43, 36, 12, BLACK)
        poly([(32, 4), (54, 31), (10, 31)], BLACK)
        poly([(10, 31), (54, 31), (32, 46)], BLACK)
        poly([(32, 38), (41, 60), (23, 60)], BLACK)
    elif kind == 'club':
        circle(32, 18, 12, BLACK)
        circle(19, 37, 12, BLACK)
        circle(45, 37, 12, BLACK)
        circle(32, 33, 7, BLACK)
        poly([(32, 30), (42, 60), (22, 60)], BLACK)
    save(img, 'Suit' + kind.capitalize(), (64, 64))


for k in ('heart', 'diamond', 'spade', 'club'):
    suit(k)

# ---------------------------------------------------------------- cards
# The card sits in the top 128x180 of a 128x256 texture (the game wants
# power-of-two sizes); the addon crops with texture coordinates.
W, H, CH = 128, 256, 180


def rounded(d, box, r, **kw):
    d.rounded_rectangle([v * SS for v in box], radius=r * SS, **kw)


def card_front():
    img = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (1, 1, W - 2, CH - 2), 12, fill=(70, 60, 45, 255))
    rounded(d, (3, 3, W - 4, CH - 4), 10, fill=(250, 246, 236, 255))
    rounded(d, (9, 9, W - 10, CH - 10), 6, outline=(214, 196, 150, 255), width=2 * SS)
    save(img, 'CardFront', (W, H))


def card_back():
    img = Image.new('RGBA', (W * SS, H * SS), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    rounded(d, (1, 1, W - 2, CH - 2), 12, fill=(60, 40, 20, 255))
    rounded(d, (3, 3, W - 4, CH - 4), 10, fill=GOLD)
    rounded(d, (8, 8, W - 9, CH - 9), 7, fill=(110, 18, 26, 255))
    # Gold diamond lattice inside the red field.
    lattice = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ld = ImageDraw.Draw(lattice)
    step = 16
    for i in range(-CH, W + CH, step):
        ld.line([(i * SS, 8 * SS), ((i + CH) * SS, (8 + CH) * SS)], fill=(222, 178, 74, 70), width=SS)
        ld.line([(i * SS, (8 + CH) * SS), ((i + CH) * SS, 8 * SS)], fill=(222, 178, 74, 70), width=SS)
    mask = Image.new('L', img.size, 0)
    rounded(ImageDraw.Draw(mask), (12, 12, W - 13, CH - 13), 5, fill=255)
    img.paste(lattice, (0, 0), Image.composite(lattice, Image.new('RGBA', img.size), mask).split()[3])
    rounded(d, (12, 12, W - 13, CH - 13), 5, outline=GOLD, width=2 * SS)
    # A die in the middle.
    cx, cy, r = W / 2, CH / 2, 22
    rounded(d, (cx - r - 3, cy - r - 3, cx + r + 3, cy + r + 3), 9, fill=GOLD)
    rounded(d, (cx - r, cy - r, cx + r, cy + r), 7, fill=(250, 246, 236, 255))
    for px, py in ((-12, -12), (12, -12), (0, 0), (-12, 12), (12, 12)):
        d.ellipse([(cx + px - 5) * SS, (cy + py - 5) * SS, (cx + px + 5) * SS, (cy + py + 5) * SS], fill=(110, 18, 26, 255))
    save(img, 'CardBack', (W, H))


card_front()
card_back()
print('written to', os.path.normpath(OUT))


# A square background that darkens towards the top and bottom (blended,
# not painted over).
def vignette(n, color, strength):
    img = Image.new('RGBA', (n, n), color)
    shade = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shade)
    for i in range(n):
        sd.line([(0, i), (n, i)], fill=(0, 0, 0, int(strength * abs(i - n / 2) / (n / 2))))
    return Image.alpha_composite(img, shade)


# ---------------------------------------------------------------- tab icon
# Two fanned cards on a dark square, like the game's own 64x64 icons.
def poker_icon():
    n = 64 * SS
    img = vignette(n, (24, 60, 36, 255), 90)
    front = Image.open(os.path.join(OUT, 'CardFront.tga')).crop((0, 0, 128, 180)).resize((30 * SS, 42 * SS), Image.LANCZOS)
    back = Image.open(os.path.join(OUT, 'CardBack.tga')).crop((0, 0, 128, 180)).resize((30 * SS, 42 * SS), Image.LANCZOS)
    heart = Image.open(os.path.join(OUT, 'SuitHeart.tga')).resize((16 * SS, 16 * SS), Image.LANCZOS)
    spade = Image.open(os.path.join(OUT, 'SuitSpade.tga')).resize((16 * SS, 16 * SS), Image.LANCZOS)
    a = front.copy()
    a.paste(spade, (7 * SS, 13 * SS), spade)
    b = front.copy()
    b.paste(heart, (7 * SS, 13 * SS), heart)
    for card, angle, x in ((back, 24, 4), (a, 0, 17), (b, -24, 30)):
        r = card.rotate(angle, resample=Image.BICUBIC, expand=True)
        img.paste(r, (x * SS - (r.width - card.width) // 2 + 0, 9 * SS - (r.height - card.height) // 2), r)
    save(img, 'IconPoker', (64, 64))


poker_icon()


# ---------------------------------------------------------------- slots
from PIL import ImageFont, ImageFilter

FONTS = 'C:/Windows/Fonts/'


def canvas(n=64):
    return Image.new('RGBA', (n * SS, n * SS), (0, 0, 0, 0))


def shadowed(img):
    # A soft drop shadow under the symbol, so it sits on the reel.
    alpha = img.split()[3]
    sh = Image.new('RGBA', img.size, (0, 0, 0, 0))
    sh.putalpha(alpha.point(lambda a: a * 0.45))
    sh = sh.filter(ImageFilter.GaussianBlur(2 * SS))
    out = Image.new('RGBA', img.size, (0, 0, 0, 0))
    out.paste(sh, (SS * 2, SS * 3), sh)
    out.paste(img, (0, 0), img)
    return out


def cherry():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    d.line([(24 * s, 38 * s), (36 * s, 10 * s)], fill=(70, 120, 30, 255), width=3 * s)
    d.line([(44 * s, 40 * s), (36 * s, 10 * s)], fill=(70, 120, 30, 255), width=3 * s)
    d.ellipse([36 * s, 6 * s, 54 * s, 16 * s], fill=(90, 160, 40, 255))  # leaf
    for cx, cy in ((22, 44), (44, 46)):
        d.ellipse([(cx - 11) * s, (cy - 11) * s, (cx + 11) * s, (cy + 11) * s], fill=(190, 20, 35, 255))
        d.ellipse([(cx - 6) * s, (cy - 7) * s, (cx - 1) * s, (cy - 2) * s], fill=(255, 150, 150, 230))
    return img


def lemon():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([8 * s, 16 * s, 56 * s, 50 * s], fill=(240, 205, 40, 255))
    d.ellipse([4 * s, 28 * s, 14 * s, 38 * s], fill=(240, 205, 40, 255))
    d.ellipse([50 * s, 28 * s, 60 * s, 38 * s], fill=(240, 205, 40, 255))
    d.ellipse([16 * s, 21 * s, 30 * s, 29 * s], fill=(255, 245, 170, 230))
    return img


def bell():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    d.pieslice([12 * s, 8 * s, 52 * s, 56 * s], 180, 360, fill=(235, 180, 40, 255))
    d.polygon([(12 * s, 32 * s), (52 * s, 32 * s), (58 * s, 48 * s), (6 * s, 48 * s)], fill=(235, 180, 40, 255))
    d.rounded_rectangle([4 * s, 46 * s, 60 * s, 52 * s], radius=3 * s, fill=(200, 140, 20, 255))
    d.ellipse([27 * s, 50 * s, 37 * s, 60 * s], fill=(150, 100, 20, 255))
    d.ellipse([20 * s, 14 * s, 27 * s, 28 * s], fill=(255, 235, 160, 220))
    d.ellipse([29 * s, 3 * s, 35 * s, 9 * s], fill=(200, 140, 20, 255))
    return img


def bar():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    d.rounded_rectangle([4 * s, 18 * s, 60 * s, 46 * s], radius=5 * s, fill=(25, 25, 30, 255), outline=(222, 178, 74, 255), width=2 * s)
    f = ImageFont.truetype(FONTS + 'impact.ttf', 24 * s)
    w = d.textlength('BAR', font=f)
    d.text(((64 * s - w) / 2, 17 * s), 'BAR', font=f, fill=(250, 246, 236, 255))
    return img


def gem():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    top = [(16, 14), (48, 14), (58, 26), (6, 26)]
    d.polygon([(x * s, y * s) for x, y in top], fill=(110, 200, 255, 255))
    d.polygon([(6 * s, 26 * s), (58 * s, 26 * s), (32 * s, 58 * s)], fill=(40, 120, 220, 255))
    d.polygon([(16 * s, 14 * s), (32 * s, 26 * s), (48 * s, 14 * s)], fill=(170, 230, 255, 255))
    d.polygon([(20 * s, 26 * s), (44 * s, 26 * s), (32 * s, 58 * s)], fill=(70, 160, 240, 255))
    return img


def seven():
    img = canvas()
    d = ImageDraw.Draw(img)
    s = SS
    f = ImageFont.truetype(FONTS + 'georgiab.ttf', 58 * s)
    w = d.textlength('7', font=f)
    x, y = (64 * s - w) / 2, -6 * s
    d.text((x, y), '7', font=f, fill=(120, 0, 10, 255), stroke_width=3 * s, stroke_fill=(222, 178, 74, 255))
    d.text((x, y), '7', font=f, fill=(215, 25, 35, 255))
    return img


for name, fn in (('Cherry', cherry), ('Lemon', lemon), ('Bell', bell), ('Bar', bar), ('Gem', gem), ('Seven', seven)):
    save(shadowed(fn()), 'Slot' + name, (64, 64))


# The reel: a white cylinder, darker towards the top and bottom.
def reel():
    w, h = 64, 128
    img = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in range(h):
        t = abs(y - h / 2) / (h / 2)
        v = int(250 - 120 * t * t)
        d.line([(0, y), (w, y)], fill=(v, v - 4, v - 12, 255))
    img.save(os.path.join(OUT, 'SlotReel.tga'))


# Lever knob: a shiny red ball.
def knob():
    img = canvas(32)
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([2 * s, 2 * s, 30 * s, 30 * s], fill=(170, 15, 25, 255))
    d.ellipse([5 * s, 5 * s, 27 * s, 27 * s], fill=(210, 30, 40, 255))
    d.ellipse([9 * s, 7 * s, 17 * s, 14 * s], fill=(255, 190, 190, 230))
    save(img, 'SlotKnob', (32, 32))


# A marquee bulb: white glow, tinted in game.
def bulb():
    n = 16
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    for y in range(n):
        for x in range(n):
            r = ((x - 7.5) ** 2 + (y - 7.5) ** 2) ** 0.5 / 7.5
            a = max(0, 1 - r) ** 1.5
            img.putpixel((x, y), (255, 255, 255, int(255 * a)))
    img.save(os.path.join(OUT, 'SlotBulb.tga'))


reel()
knob()
bulb()


def slots_icon():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (60, 10, 15, 255))
    d = ImageDraw.Draw(img)
    s = SS
    d.rounded_rectangle([6 * s, 14 * s, 58 * s, 50 * s], radius=4 * s, fill=(222, 178, 74, 255))
    d.rounded_rectangle([9 * s, 17 * s, 55 * s, 47 * s], radius=3 * s, fill=(245, 240, 228, 255))
    sev = seven().resize((18 * s, 18 * s), Image.LANCZOS)
    for i in range(3):
        img.paste(sev, ((10 + i * 15) * s, 23 * s), sev)
    save(img, 'IconSlots', (64, 64))


slots_icon()
print('slots art written')


# ---------------------------------------------------------------- roulette
import math

WHEEL_ORDER = [0, 32, 15, 19, 4, 21, 2, 25, 17, 34, 6, 27, 13, 36, 11, 30, 8, 23, 10,
               5, 24, 16, 33, 1, 20, 14, 31, 9, 22, 18, 29, 7, 28, 12, 35, 3, 26]
RED_NUMBERS = {1, 3, 5, 7, 9, 12, 14, 16, 18, 19, 21, 23, 25, 27, 30, 32, 34, 36}


def pocket_color(n, light=False):
    if n == 0:
        return (40, 150, 70, 255) if light else (20, 110, 50, 255)
    if n in RED_NUMBERS:
        return (200, 40, 40, 255) if light else (165, 20, 25, 255)
    return (55, 55, 60, 255) if light else (20, 20, 24, 255)


# The wheel: wooden rim, a band of numbers, the pockets, and a dark cone.
# Pocket i sits at a clockwise angle of i * 360/37 degrees from the top.
def wheel():
    N = 512 * 2  # drawn at 2x, then halved
    img = Image.new('RGBA', (N, N), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = N / 2
    k = N / 512

    def ring(r, col):
        d.ellipse([c - r * k, c - r * k, c + r * k, c + r * k], fill=col)

    ring(255, (60, 32, 16, 255))
    ring(246, (120, 70, 35, 255))
    ring(236, (85, 48, 22, 255))
    step = 360 / 37
    # PIL angles go clockwise from 3 o'clock; ours go clockwise from 12.
    for i, n in enumerate(WHEEL_ORDER):
        a0 = -90 + i * step - step / 2
        d.pieslice([c - 232 * k, c - 232 * k, c + 232 * k, c + 232 * k], a0, a0 + step, fill=pocket_color(n))
    ring(196, (0, 0, 0, 0))
    for i, n in enumerate(WHEEL_ORDER):
        a0 = -90 + i * step - step / 2
        d.pieslice([c - 196 * k, c - 196 * k, c + 196 * k, c + 196 * k], a0, a0 + step, fill=pocket_color(n, True))
    # Gold frets between the pockets.
    for i in range(37):
        a = math.radians(i * step - step / 2)
        x1, y1 = c + 160 * k * math.sin(a), c - 160 * k * math.cos(a)
        x2, y2 = c + 232 * k * math.sin(a), c - 232 * k * math.cos(a)
        d.line([(x1, y1), (x2, y2)], fill=(222, 178, 74, 255), width=int(2 * k))
    for r, w in ((232, 3), (196, 3), (160, 3)):
        d.ellipse([c - r * k, c - r * k, c + r * k, c + r * k], outline=(222, 178, 74, 255), width=int(w * k))
    # The cone inside the pockets.
    for r in range(158, 0, -2):
        t = r / 158
        v = int(40 + 50 * t)
        d.ellipse([c - r * k, c - r * k, c + r * k, c + r * k], fill=(v + 20, v, int(v * 0.6), 255))
    # Numbers on the outer band, turned to face outwards.
    font = ImageFont.truetype(FONTS + 'arialbd.ttf', int(24 * k))
    for i, n in enumerate(WHEEL_ORDER):
        label = str(n)
        tw = int(d.textlength(label, font=font)) + 4
        tile = Image.new('RGBA', (tw, int(30 * k)), (0, 0, 0, 0))
        ImageDraw.Draw(tile).text((2, 0), label, font=font, fill=(250, 246, 236, 255))
        tile = tile.rotate(-i * step, resample=Image.BICUBIC, expand=True)
        a = math.radians(i * step)
        x, y = c + 214 * k * math.sin(a), c - 214 * k * math.cos(a)
        img.paste(tile, (int(x - tile.width / 2), int(y - tile.height / 2)), tile)
    img = img.resize((512, 512), Image.LANCZOS)
    img.save(os.path.join(OUT, 'RouletteWheel.tga'))


# The turning centre: a gold turret with four spokes.
def hub():
    n = 256 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    c = n / 2
    s = SS
    for a in (0, 90, 180, 270):
        r = math.radians(a)
        x, y = c + 120 * s * math.sin(r), c - 120 * s * math.cos(r)
        d.line([(c, c), (x, y)], fill=(200, 155, 60, 255), width=10 * s)
        d.ellipse([x - 12 * s, y - 12 * s, x + 12 * s, y + 12 * s], fill=(230, 190, 90, 255))
    d.ellipse([c - 46 * s, c - 46 * s, c + 46 * s, c + 46 * s], fill=(170, 125, 45, 255))
    d.ellipse([c - 36 * s, c - 36 * s, c + 36 * s, c + 36 * s], fill=(230, 190, 90, 255))
    d.ellipse([c - 14 * s, c - 30 * s, c + 4 * s, c - 12 * s], fill=(255, 240, 190, 220))
    save(img, 'RouletteHub', (256, 256))


def ball():
    img = canvas(32)
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([2 * s, 2 * s, 30 * s, 30 * s], fill=(205, 205, 210, 255))
    d.ellipse([4 * s, 4 * s, 28 * s, 28 * s], fill=(245, 245, 248, 255))
    d.ellipse([9 * s, 7 * s, 17 * s, 15 * s], fill=(255, 255, 255, 255))
    save(img, 'RouletteBall', (32, 32))


def roulette_icon():
    w = Image.open(os.path.join(OUT, 'RouletteWheel.tga')).resize((60, 60), Image.LANCZOS)
    h = Image.open(os.path.join(OUT, 'RouletteHub.tga')).resize((26, 26), Image.LANCZOS)
    img = Image.new('RGBA', (64, 64), (24, 40, 30, 255))
    img.paste(w, (2, 2), w)
    img.paste(h, (19, 19), h)
    b = Image.open(os.path.join(OUT, 'RouletteBall.tga')).resize((9, 9), Image.LANCZOS)
    img.paste(b, (40, 9), b)
    img.save(os.path.join(OUT, 'IconRoulette.tga'))


wheel()
hub()
ball()
roulette_icon()
print('roulette art written')


# ---------------------------------------------------------------- portraits
# A gold ring around a round portrait, with a dark rim inside.
def portrait_ring():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([1 * s, 1 * s, 63 * s, 63 * s], fill=(120, 85, 30, 255))
    d.ellipse([3 * s, 3 * s, 61 * s, 61 * s], fill=(222, 178, 74, 255))
    d.ellipse([6 * s, 6 * s, 58 * s, 58 * s], fill=(60, 40, 15, 255))
    d.ellipse([8 * s, 8 * s, 56 * s, 56 * s], fill=(0, 0, 0, 0))
    d.arc([3 * s, 3 * s, 61 * s, 61 * s], 200, 300, fill=(255, 235, 170, 255), width=2 * s)
    save(img, 'PortraitRing', (64, 64))


# A round dark backing, so a portrait never shows square corners.
def portrait_back():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    ImageDraw.Draw(img).ellipse([6 * SS, 6 * SS, 58 * SS, 58 * SS], fill=(20, 16, 12, 255))
    save(img, 'PortraitBack', (64, 64))


portrait_ring()
portrait_back()
print('portrait art written')


# ---------------------------------------------------------------- blackjack
# Tab icon: an ace and a king fanned on felt, using the same card art.
def blackjack_icon():
    n = 64 * SS
    img = vignette(n, (22, 70, 40, 255), 80)
    font = ImageFont.truetype(FONTS + 'georgiab.ttf', 13 * SS)

    def face(rank, suit, color):
        c = Image.open(os.path.join(OUT, 'CardFront.tga')).crop((0, 0, 128, 180)).resize((32 * SS, 45 * SS), Image.LANCZOS)
        cd = ImageDraw.Draw(c)
        cd.text((4 * SS, 1 * SS), rank, font=font, fill=color)
        sym = Image.open(os.path.join(OUT, 'Suit' + suit + '.tga')).resize((17 * SS, 17 * SS), Image.LANCZOS)
        c.paste(sym, (11 * SS, 20 * SS), sym)
        return c

    for card, angle, x in ((face('K', 'Heart', (200, 30, 40, 255)), 14, 8), (face('A', 'Spade', (25, 25, 30, 255)), -12, 24)):
        r = card.rotate(angle, resample=Image.BICUBIC, expand=True)
        img.paste(r, (x * SS - (r.width - card.width) // 2, 10 * SS - (r.height - card.height) // 2), r)
    save(img, 'IconBlackjack', (64, 64))


blackjack_icon()
print('blackjack art written')


# ---------------------------------------------------------------- raffle
# A golden ticket: notched corners, a dashed tear line, a star.
def ticket(w=256, h=128, name='RaffleTicket'):
    W2, H2 = w * SS, h * SS
    img = Image.new('RGBA', (W2, H2), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS * w / 256
    d.rounded_rectangle([4 * s, 8 * s, 252 * s, 120 * s], radius=10 * s, fill=(150, 100, 25, 255))
    d.rounded_rectangle([7 * s, 11 * s, 249 * s, 117 * s], radius=8 * s, fill=(236, 190, 80, 255))
    d.rounded_rectangle([14 * s, 18 * s, 242 * s, 110 * s], radius=6 * s, outline=(170, 115, 30, 255), width=int(2 * s))
    for cx, cy in ((4, 64), (252, 64)):  # notches
        d.ellipse([(cx - 12) * s, (cy - 12) * s, (cx + 12) * s, (cy + 12) * s], fill=(0, 0, 0, 0))
    for y in range(22, 108, 10):  # tear line
        d.line([(196 * s, y * s), (196 * s, (y + 5) * s)], fill=(150, 100, 25, 255), width=int(2 * s))
    cx, cy, r1, r2 = 222 * s, 64 * s, 14 * s, 6 * s  # star
    pts = []
    for i in range(10):
        a = math.radians(-90 + i * 36)
        r = r1 if i % 2 == 0 else r2
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.polygon(pts, fill=(200, 40, 40, 255))
    img = img.resize((w, h), Image.LANCZOS)
    img.save(os.path.join(OUT, name + '.tga'))


def raffle_icon():
    img = vignette(64 * SS, (60, 20, 70, 255), 80)
    t = Image.open(os.path.join(OUT, 'RaffleTicket.tga')).resize((52 * SS, 26 * SS), Image.LANCZOS)
    for angle, (x, y) in ((18, (3, 12)), (-8, (8, 26))):
        r = t.rotate(angle, resample=Image.BICUBIC, expand=True)
        img.paste(r, (x * SS, y * SS), r)
    save(img, 'IconRaffle', (64, 64))


ticket()
raffle_icon()
print('raffle art written')


# ---------------------------------------------------------------- tic-tac-toe
def ttt_x(size=128, name='TttX'):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = SS * size / 64
    for a, b in (((14, 14), (50, 50)), ((50, 14), (14, 50))):
        d.line([(a[0] * s, a[1] * s), (b[0] * s, b[1] * s)], fill=(120, 15, 20, 255), width=int(12 * s))
        d.line([(a[0] * s, a[1] * s), (b[0] * s, b[1] * s)], fill=(215, 45, 45, 255), width=int(8 * s))
    save(shadowed(img), name, (size, size))


def ttt_o(size=128, name='TttO'):
    img = canvas(size)
    d = ImageDraw.Draw(img)
    s = SS * size / 64
    d.ellipse([12 * s, 12 * s, 52 * s, 52 * s], outline=(20, 60, 130, 255), width=int(12 * s))
    d.ellipse([14 * s, 14 * s, 50 * s, 50 * s], outline=(70, 140, 230, 255), width=int(8 * s))
    save(shadowed(img), name, (size, size))


def ttt_icon():
    n = 64 * SS
    img = vignette(n, (70, 50, 30, 255), 70)
    d = ImageDraw.Draw(img)
    s = SS
    for k in (1, 2):
        d.line([(8 * s + k * 16 * s, 8 * s), (8 * s + k * 16 * s, 56 * s)], fill=(235, 220, 180, 255), width=3 * s)
        d.line([(8 * s, 8 * s + k * 16 * s), (56 * s, 8 * s + k * 16 * s)], fill=(235, 220, 180, 255), width=3 * s)
    x = Image.open(os.path.join(OUT, 'TttX.tga')).resize((15 * s, 15 * s), Image.LANCZOS)
    o = Image.open(os.path.join(OUT, 'TttO.tga')).resize((15 * s, 15 * s), Image.LANCZOS)
    for img2, (cx, cy) in ((x, (0, 0)), (o, (1, 0)), (x, (1, 1)), (o, (2, 1)), (x, (2, 2))):
        img.paste(img2, ((9 + cx * 16) * s, (9 + cy * 16) * s), img2)
    save(img, 'IconTicTacToe', (64, 64))


ttt_x()
ttt_o()
ttt_icon()
print('tic-tac-toe art written')


# ---------------------------------------------------------------- agar.io
# A white blob (tinted per player in game): a darker rim, a soft highlight.
def blob():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([2 * s, 2 * s, 126 * s, 126 * s], fill=(175, 175, 175, 255))
    d.ellipse([9 * s, 9 * s, 119 * s, 119 * s], fill=(255, 255, 255, 255))
    hl = Image.new('RGBA', img.size, (0, 0, 0, 0))
    ImageDraw.Draw(hl).ellipse([30 * s, 22 * s, 64 * s, 50 * s], fill=(255, 255, 255, 140))
    hl = hl.filter(ImageFilter.GaussianBlur(6 * s))
    img = Image.alpha_composite(img, hl)
    save(img, 'Blob', (128, 128))


def agar_icon():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (14, 18, 24, 255))
    d = ImageDraw.Draw(img)
    s = SS
    for k in range(0, 64, 12):
        d.line([(k * s, 0), (k * s, n)], fill=(32, 38, 48, 255), width=s)
        d.line([(0, k * s), (n, k * s)], fill=(32, 38, 48, 255), width=s)
    b = Image.open(os.path.join(OUT, 'Blob.tga'))

    def put(size, x, y, color):
        t = b.resize((size * s, size * s), Image.LANCZOS)
        r, g, bb, a = t.split()
        tint = Image.new('RGBA', t.size, color)
        t = Image.composite(Image.blend(t, tint, 0.55), Image.new('RGBA', t.size, (0, 0, 0, 0)), a)
        t.putalpha(a)
        img.paste(t, (x * s, y * s), t)

    put(34, 18, 16, (60, 200, 235, 255))
    put(16, 6, 6, (240, 120, 30, 255))
    put(12, 44, 44, (170, 210, 110, 255))
    for (x, y, c) in ((8, 44, (255, 90, 90)), (50, 10, (255, 230, 80)), (30, 54, (190, 120, 255)), (52, 30, (90, 255, 160))):
        d.ellipse([x * s, y * s, (x + 4) * s, (y + 4) * s], fill=c + (255,))
    save(img, 'IconAgario', (64, 64))


blob()
agar_icon()
print('agar art written')


# ---------------------------------------------------------------- battleship
def bs_hit():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    c = 32
    pts = []
    for i in range(16):
        a = math.radians(i * 22.5)
        r = 28 if i % 2 == 0 else 13
        pts.append(((c + r * math.cos(a)) * s, (c + r * math.sin(a)) * s))
    d.polygon(pts, fill=(200, 40, 20, 255))
    pts2 = [((c + (r * 0.62) * math.cos(math.radians(i * 22.5 + 11))) * s,
             (c + (r * 0.62) * math.sin(math.radians(i * 22.5 + 11))) * s) for i, r in enumerate([28 if k % 2 == 0 else 13 for k in range(16)])]
    d.polygon(pts2, fill=(255, 170, 40, 255))
    d.ellipse([(c - 7) * s, (c - 7) * s, (c + 7) * s, (c + 7) * s], fill=(255, 245, 190, 255))
    save(img, 'BsHit', (64, 64))


def bs_miss():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    for r, a in ((24, 120), (16, 190), (8, 255)):
        d.ellipse([(32 - r) * s, (32 - r) * s, (32 + r) * s, (32 + r) * s], outline=(230, 245, 255, a), width=3 * s)
    save(img, 'BsMiss', (64, 64))


# A ship segment: grey hull plate with rivets, tinted in game.
def bs_ship():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rounded_rectangle([3 * s, 3 * s, 61 * s, 61 * s], radius=10 * s, fill=(95, 100, 110, 255))
    d.rounded_rectangle([7 * s, 7 * s, 57 * s, 57 * s], radius=8 * s, fill=(140, 146, 158, 255))
    for x, y in ((14, 14), (50, 14), (14, 50), (50, 50)):
        d.ellipse([(x - 3) * s, (y - 3) * s, (x + 3) * s, (y + 3) * s], fill=(90, 94, 104, 255))
    save(img, 'BsShip', (64, 64))


def bs_icon():
    n = 64 * SS
    img = vignette(n, (20, 50, 95, 255), 70)
    d = ImageDraw.Draw(img)
    s = SS
    for y in (44, 52):  # waves
        for x in range(-4, 64, 12):
            d.arc([x * s, (y - 4) * s, (x + 12) * s, (y + 4) * s], 0, 180, fill=(120, 180, 240, 255), width=2 * s)
    d.polygon([(8 * s, 34 * s), (56 * s, 34 * s), (50 * s, 44 * s), (14 * s, 44 * s)], fill=(150, 156, 168, 255))
    d.rectangle([22 * s, 24 * s, 40 * s, 34 * s], fill=(120, 126, 138, 255))
    d.rectangle([28 * s, 16 * s, 32 * s, 24 * s], fill=(100, 106, 118, 255))
    d.line([(36 * s, 28 * s), (50 * s, 22 * s)], fill=(90, 94, 104, 255), width=3 * s)
    hit = Image.open(os.path.join(OUT, 'BsHit.tga')).resize((20 * s, 20 * s), Image.LANCZOS)
    img.paste(hit, (40 * s, 6 * s), hit)
    save(img, 'IconBattleship', (64, 64))


bs_hit()
bs_miss()
bs_ship()
bs_icon()
print('battleship art written')


# ---------------------------------------------------------------- solo games
def mine_bomb():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    for a in range(0, 360, 45):
        r = math.radians(a)
        d.line([(32 * s, 32 * s), ((32 + 26 * math.cos(r)) * s, (32 + 26 * math.sin(r)) * s)], fill=(30, 30, 34, 255), width=4 * s)
    d.ellipse([12 * s, 12 * s, 52 * s, 52 * s], fill=(30, 30, 34, 255))
    d.ellipse([20 * s, 18 * s, 30 * s, 28 * s], fill=(200, 200, 210, 230))
    save(img, 'MineBomb', (64, 64))


def mine_flag():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rectangle([28 * s, 10 * s, 32 * s, 52 * s], fill=(60, 50, 40, 255))
    d.polygon([(32 * s, 10 * s), (54 * s, 20 * s), (32 * s, 30 * s)], fill=(215, 40, 40, 255))
    d.rounded_rectangle([18 * s, 50 * s, 42 * s, 56 * s], radius=2 * s, fill=(60, 50, 40, 255))
    save(img, 'MineFlag', (64, 64))


def snake_icon():
    n = 64 * SS
    img = vignette(n, (20, 60, 30, 255), 70)
    d = ImageDraw.Draw(img)
    s = SS
    path = [(10, 46), (22, 46), (22, 34), (40, 34), (40, 20), (52, 20)]
    d.line([(x * s, y * s) for x, y in path], fill=(90, 200, 80, 255), width=9 * s, joint='curve')
    d.ellipse([46 * s, 14 * s, 58 * s, 26 * s], fill=(120, 230, 100, 255))
    d.ellipse([50 * s, 17 * s, 53 * s, 20 * s], fill=(10, 10, 10, 255))
    d.ellipse([10 * s, 10 * s, 20 * s, 20 * s], fill=(220, 40, 40, 255))
    save(img, 'IconSnake', (64, 64))


def icon_2048():
    n = 64 * SS
    img = vignette(n, (120, 105, 90, 255), 50)
    d = ImageDraw.Draw(img)
    s = SS
    cols = [(238, 228, 218), (237, 224, 200), (242, 177, 121), (237, 194, 46)]
    for i, (x, y) in enumerate(((6, 6), (34, 6), (6, 34), (34, 34))):
        d.rounded_rectangle([x * s, y * s, (x + 24) * s, (y + 24) * s], radius=3 * s, fill=cols[i] + (255,))
    f = ImageFont.truetype(FONTS + 'arialbd.ttf', 11 * s)
    for (x, y, t, c) in ((18, 18, '2', (119, 110, 101)), (46, 18, '4', (119, 110, 101)), (18, 46, '16', (255, 255, 255)), (46, 46, '2k', (255, 255, 255))):
        w = d.textlength(t, font=f)
        d.text((x * s - w / 2, (y - 7) * s), t, font=f, fill=c + (255,))
    save(img, 'Icon2048', (64, 64))


def mines_icon():
    n = 64 * SS
    img = vignette(n, (70, 75, 85, 255), 50)
    d = ImageDraw.Draw(img)
    s = SS
    for r in range(3):
        for c in range(3):
            x, y = 6 + c * 18, 6 + r * 18
            col = (150, 155, 165) if (r + c) % 2 else (120, 125, 135)
            d.rectangle([x * s, y * s, (x + 16) * s, (y + 16) * s], fill=col + (255,))
    bomb = Image.open(os.path.join(OUT, 'MineBomb.tga')).resize((16 * s, 16 * s), Image.LANCZOS)
    flag = Image.open(os.path.join(OUT, 'MineFlag.tga')).resize((16 * s, 16 * s), Image.LANCZOS)
    img.paste(bomb, (24 * s, 24 * s), bomb)
    img.paste(flag, (42 * s, 6 * s), flag)
    f = ImageFont.truetype(FONTS + 'arialbd.ttf', 12 * s)
    d.text((10 * s, 42 * s), '2', font=f, fill=(40, 120, 40, 255))
    d.text((11 * s, 6 * s), '1', font=f, fill=(40, 80, 200, 255))
    save(img, 'IconMines', (64, 64))


mine_bomb()
mine_flag()
snake_icon()
icon_2048()
mines_icon()
print('solo art written')


# ---------------------------------------------------------------- tetris, flappy, wordle
# A bevelled block, white so it can be tinted per piece.
def block():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rectangle([0, 0, n, n], fill=(200, 200, 200, 255))
    d.polygon([(0, 0), (n, 0), (54 * s, 10 * s), (10 * s, 10 * s), (10 * s, 54 * s), (0, n)], fill=(255, 255, 255, 255))
    d.polygon([(n, n), (0, n), (10 * s, 54 * s), (54 * s, 54 * s), (54 * s, 10 * s), (n, 0)], fill=(140, 140, 140, 255))
    d.rectangle([10 * s, 10 * s, 54 * s, 54 * s], fill=(215, 215, 215, 255))
    save(img, 'Block', (64, 64))


def flappy_bird():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([8 * s, 14 * s, 54 * s, 52 * s], fill=(120, 80, 10, 255))
    d.ellipse([10 * s, 16 * s, 52 * s, 50 * s], fill=(250, 205, 40, 255))
    d.ellipse([12 * s, 34 * s, 32 * s, 46 * s], fill=(255, 240, 160, 255))  # wing
    d.ellipse([34 * s, 18 * s, 48 * s, 32 * s], fill=(255, 255, 255, 255))
    d.ellipse([41 * s, 22 * s, 46 * s, 28 * s], fill=(20, 20, 20, 255))
    d.polygon([(48 * s, 32 * s), (62 * s, 36 * s), (48 * s, 42 * s)], fill=(235, 90, 30, 255))
    save(img, 'FlappyBird', (64, 64))


def tetris_icon():
    n = 64 * SS
    img = vignette(n, (25, 25, 45, 255), 60)
    b = Image.open(os.path.join(OUT, 'Block.tga')).resize((14 * SS, 14 * SS), Image.LANCZOS)
    cells = [((1, 3), (0, 200, 220)), ((2, 3), (0, 200, 220)), ((3, 3), (0, 200, 220)), ((2, 2), (0, 200, 220)),
             ((0, 1), (230, 60, 60)), ((0, 2), (230, 60, 60)), ((1, 2), (230, 60, 60)),
             ((3, 1), (240, 200, 40)), ((3, 2), (240, 200, 40)), ((2, 1), (240, 200, 40))]
    for (x, y), col in cells:
        t = Image.new('RGBA', b.size, col + (255,))
        t = Image.blend(t, b, 0.45)
        t.putalpha(b.split()[3])
        img.paste(t, ((4 + x * 14) * SS, (4 + y * 14) * SS), t)
    save(img, 'IconTetris', (64, 64))


def flappy_icon():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (110, 195, 235, 255))
    d = ImageDraw.Draw(img)
    s = SS
    for x in (40,):
        d.rectangle([x * s, 0, (x + 14) * s, 20 * s], fill=(80, 170, 60, 255))
        d.rectangle([(x - 2) * s, 16 * s, (x + 16) * s, 22 * s], fill=(60, 140, 45, 255))
        d.rectangle([x * s, 42 * s, (x + 14) * s, 56 * s], fill=(80, 170, 60, 255))
        d.rectangle([(x - 2) * s, 40 * s, (x + 16) * s, 46 * s], fill=(60, 140, 45, 255))
    d.rectangle([0, 56 * s, n, n], fill=(220, 190, 110, 255))
    bird = Image.open(os.path.join(OUT, 'FlappyBird.tga')).resize((30 * s, 30 * s), Image.LANCZOS)
    img.paste(bird, (6 * s, 18 * s), bird)
    save(img, 'IconFlappy', (64, 64))


def wordle_icon():
    n = 64 * SS
    img = vignette(n, (30, 30, 34, 255), 40)
    d = ImageDraw.Draw(img)
    s = SS
    f = ImageFont.truetype(FONTS + 'arialbd.ttf', 12 * s)
    cols = [(106, 170, 100), (201, 180, 88), (120, 124, 126), (106, 170, 100)]
    for i, ch in enumerate('WORD'):
        x = 4 + i * 14
        d.rounded_rectangle([x * s, 24 * s, (x + 13) * s, 40 * s], radius=2 * s, fill=cols[i] + (255,))
        w = d.textlength(ch, font=f)
        d.text(((x + 6.5) * s - w / 2, 25 * s), ch, font=f, fill=(255, 255, 255, 255))
    save(img, 'IconWordle', (64, 64))


block()
flappy_bird()
tetris_icon()
flappy_icon()
wordle_icon()
print('batch 2 art written')


# ---------------------------------------------------------------- space shooter, candy crush, angry birds
def ship():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.polygon([(32 * s, 4 * s), (44 * s, 40 * s), (60 * s, 54 * s), (40 * s, 52 * s), (32 * s, 60 * s),
               (24 * s, 52 * s), (4 * s, 54 * s), (20 * s, 40 * s)], fill=(160, 175, 200, 255))
    d.polygon([(32 * s, 4 * s), (38 * s, 36 * s), (32 * s, 50 * s), (26 * s, 36 * s)], fill=(225, 235, 250, 255))
    d.ellipse([28 * s, 22 * s, 36 * s, 34 * s], fill=(70, 170, 255, 255))
    d.polygon([(26 * s, 54 * s), (38 * s, 54 * s), (32 * s, 63 * s)], fill=(255, 150, 40, 255))
    save(img, 'Ship', (64, 64))


def alien():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([10 * s, 12 * s, 54 * s, 46 * s], fill=(235, 235, 235, 255))
    d.rectangle([10 * s, 30 * s, 54 * s, 40 * s], fill=(235, 235, 235, 255))
    for x in (10, 24, 38):
        d.polygon([(x * s, 40 * s), ((x + 16) * s, 40 * s), ((x + 8) * s, 56 * s)], fill=(235, 235, 235, 255))
    d.ellipse([18 * s, 20 * s, 28 * s, 32 * s], fill=(25, 25, 25, 255))
    d.ellipse([36 * s, 20 * s, 46 * s, 32 * s], fill=(25, 25, 25, 255))
    d.line([(20 * s, 12 * s), (14 * s, 2 * s)], fill=(235, 235, 235, 255), width=3 * s)
    d.line([(44 * s, 12 * s), (50 * s, 2 * s)], fill=(235, 235, 235, 255), width=3 * s)
    save(img, 'Alien', (64, 64))


def boulder():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([4 * s, 4 * s, 60 * s, 60 * s], fill=(80, 74, 68, 255))
    d.ellipse([6 * s, 6 * s, 56 * s, 56 * s], fill=(135, 126, 115, 255))
    d.ellipse([14 * s, 12 * s, 34 * s, 28 * s], fill=(170, 162, 150, 255))
    d.ellipse([34 * s, 36 * s, 44 * s, 44 * s], fill=(100, 94, 86, 255))
    save(img, 'Boulder', (64, 64))


def murloc():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.polygon([(20 * s, 14 * s), (32 * s, 0), (44 * s, 14 * s)], fill=(200, 80, 60, 255))  # fin
    d.ellipse([8 * s, 10 * s, 56 * s, 62 * s], fill=(40, 110, 60, 255))
    d.ellipse([11 * s, 13 * s, 53 * s, 59 * s], fill=(80, 170, 95, 255))
    d.ellipse([16 * s, 40 * s, 48 * s, 58 * s], fill=(200, 225, 170, 255))  # belly/mouth
    d.chord([20 * s, 36 * s, 44 * s, 54 * s], 0, 180, fill=(120, 30, 40, 255))
    for x in (16, 36):
        d.ellipse([x * s, 18 * s, (x + 12) * s, 32 * s], fill=(255, 245, 120, 255))
        d.ellipse([(x + 4) * s, 22 * s, (x + 9) * s, 29 * s], fill=(20, 20, 20, 255))
    save(img, 'Murloc', (64, 64))


def plank(name, base, dark, grain):
    n = 64 * SS
    img = Image.new('RGBA', (n, n), base + (255,))
    d = ImageDraw.Draw(img)
    s = SS
    d.rectangle([0, 0, n - 1, n - 1], outline=dark + (255,), width=4 * s)
    if grain:
        for y in (18, 32, 46):
            d.line([(6 * s, y * s), (58 * s, (y + 2) * s)], fill=dark + (160,), width=2 * s)
    else:
        d.line([(0, 32 * s), (n, 32 * s)], fill=dark + (200,), width=2 * s)
        d.line([(32 * s, 0), (32 * s, 32 * s)], fill=dark + (200,), width=2 * s)
        d.line([(16 * s, 32 * s), (16 * s, n)], fill=dark + (200,), width=2 * s)
        d.line([(48 * s, 32 * s), (48 * s, n)], fill=dark + (200,), width=2 * s)
    save(img, name, (64, 64))


def shooter_icon():
    n = 64 * SS
    img = vignette(n, (12, 10, 35, 255), 60)
    d = ImageDraw.Draw(img)
    s = SS
    for x, y in ((8, 10), (50, 6), (30, 30), (12, 44), (54, 40)):
        d.ellipse([x * s, y * s, (x + 2) * s, (y + 2) * s], fill=(255, 255, 255, 200))
    a = Image.open(os.path.join(OUT, 'Alien.tga')).resize((22 * s, 22 * s), Image.LANCZOS)
    t = Image.new('RGBA', a.size, (120, 255, 120, 255)); t.putalpha(a.split()[3])
    t = Image.composite(Image.blend(t, a, 0.3), Image.new('RGBA', a.size, (0, 0, 0, 0)), a.split()[3])
    img.paste(t, (21 * s, 4 * s), t)
    d.rectangle([31 * s, 28 * s, 33 * s, 36 * s], fill=(255, 230, 90, 255))
    sh = Image.open(os.path.join(OUT, 'Ship.tga')).resize((24 * s, 24 * s), Image.LANCZOS)
    img.paste(sh, (20 * s, 38 * s), sh)
    save(img, 'IconShooter', (64, 64))


def angrybirds_icon():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (125, 190, 235, 255))
    d = ImageDraw.Draw(img)
    s = SS
    d.rectangle([0, 52 * s, n, n], fill=(95, 150, 60, 255))
    wood = Image.open(os.path.join(OUT, 'Wood.tga')).resize((12 * s, 12 * s), Image.LANCZOS)
    for x, y in ((36, 40), (48, 40), (42, 28)):
        img.paste(wood, (x * s, y * s), wood)
    m = Image.open(os.path.join(OUT, 'Murloc.tga')).resize((14 * s, 14 * s), Image.LANCZOS)
    img.paste(m, (41 * s, 14 * s), m)
    b = Image.open(os.path.join(OUT, 'Boulder.tga')).resize((14 * s, 14 * s), Image.LANCZOS)
    img.paste(b, (8 * s, 12 * s), b)
    d.line([(14 * s, 52 * s), (18 * s, 32 * s)], fill=(110, 70, 30, 255), width=4 * s)
    d.line([(18 * s, 32 * s), (12 * s, 26 * s)], fill=(110, 70, 30, 255), width=3 * s)
    d.line([(18 * s, 32 * s), (24 * s, 26 * s)], fill=(110, 70, 30, 255), width=3 * s)
    save(img, 'IconAngryBirds', (64, 64))


def candycrush_icon():
    n = 64 * SS
    img = vignette(n, (40, 25, 55, 255), 50)
    d = ImageDraw.Draw(img)
    s = SS
    # A star, a diamond, a circle, a triangle in a 2x2.
    d.polygon([(16 * s, 4 * s), (19 * s, 13 * s), (28 * s, 13 * s), (21 * s, 18 * s), (24 * s, 27 * s),
               (16 * s, 21 * s), (8 * s, 27 * s), (11 * s, 18 * s), (4 * s, 13 * s), (13 * s, 13 * s)],
              fill=(250, 220, 40, 255))
    d.polygon([(48 * s, 4 * s), (58 * s, 16 * s), (48 * s, 28 * s), (38 * s, 16 * s)], fill=(190, 80, 240, 255))
    d.ellipse([6 * s, 36 * s, 26 * s, 56 * s], fill=(250, 140, 30, 255))
    d.polygon([(48 * s, 36 * s), (59 * s, 56 * s), (37 * s, 56 * s)], fill=(60, 210, 80, 255))
    save(img, 'IconCandyCrush', (64, 64))


ship()
alien()
boulder()
murloc()
plank('Wood', (170, 120, 65), (95, 60, 25), True)
plank('Stone', (150, 150, 158), (90, 90, 98), False)
shooter_icon()
angrybirds_icon()
candycrush_icon()
print('batch 3 art written')


# ---------------------------------------------------------------- hearthstone
# Card frames are 256x512 files with the card in the top 256x356 (the
# page uses texcoords 0..356/512). Frames are light and neutral so the page
# can tint them per class with SetVertexColor.
def hs_card(kind):
    W_, H_ = 256 * SS, 512 * SS
    img = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rounded_rectangle([6 * s, 6 * s, 250 * s, 350 * s], radius=20 * s, fill=(70, 58, 45, 255))
    d.rounded_rectangle([12 * s, 12 * s, 244 * s, 344 * s], radius=16 * s, fill=(222, 214, 200, 255))
    # Inner bevel.
    d.rounded_rectangle([18 * s, 18 * s, 238 * s, 338 * s], radius=12 * s, outline=(165, 152, 132, 255), width=3 * s)
    # Text box.
    d.rounded_rectangle([30 * s, 222 * s, 226 * s, 330 * s], radius=10 * s, fill=(240, 232, 212, 255),
                        outline=(150, 135, 110, 255), width=2 * s)
    # Art window border, then the hole.
    if kind == 'minion':
        d.ellipse([42 * s, 26 * s, 214 * s, 186 * s], fill=(120, 100, 70, 255))
        d.ellipse([48 * s, 32 * s, 208 * s, 180 * s], fill=(0, 0, 0, 0))
    else:
        d.rounded_rectangle([34 * s, 30 * s, 222 * s, 176 * s], radius=10 * s, fill=(120, 100, 70, 255))
        d.rounded_rectangle([40 * s, 36 * s, 216 * s, 170 * s], radius=6 * s, fill=(0, 0, 0, 0))
    # Name banner.
    d.polygon([(20 * s, 186 * s), (236 * s, 186 * s), (228 * s, 202 * s), (236 * s, 218 * s), (20 * s, 218 * s),
               (28 * s, 202 * s)], fill=(95, 78, 58, 255))
    d.line([(28 * s, 189 * s), (228 * s, 189 * s)], fill=(140, 118, 88, 255), width=2 * s)
    save(img, 'HsCard' + kind.capitalize(), (256, 512))


def hs_back():
    W_, H_ = 256 * SS, 512 * SS
    img = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rounded_rectangle([6 * s, 6 * s, 250 * s, 350 * s], radius=20 * s, fill=(60, 40, 22, 255))
    d.rounded_rectangle([14 * s, 14 * s, 242 * s, 342 * s], radius=14 * s, fill=(40, 70, 140, 255))
    stripes = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
    sd = ImageDraw.Draw(stripes)
    for i in range(-120, 360, 24):
        sd.line([(14 * s, (14 + i) * s), (242 * s, (14 + i + 120) * s)], fill=(50, 85, 160, 255), width=6 * s)
    clip = Image.new('L', (W_, H_), 0)
    ImageDraw.Draw(clip).rounded_rectangle([14 * s, 14 * s, 242 * s, 342 * s], radius=14 * s, fill=255)
    img.paste(stripes, (0, 0), Image.composite(stripes.split()[3], Image.new('L', (W_, H_), 0), clip))
    d = ImageDraw.Draw(img)
    d.rounded_rectangle([14 * s, 14 * s, 242 * s, 342 * s], radius=14 * s, outline=(200, 160, 70, 255), width=6 * s)
    d.ellipse([78 * s, 128 * s, 178 * s, 228 * s], fill=(200, 160, 70, 255))
    d.ellipse([90 * s, 140 * s, 166 * s, 216 * s], fill=(40, 70, 140, 255))
    d.ellipse([110 * s, 160 * s, 146 * s, 196 * s], fill=(230, 190, 90, 255))
    # Blank out the area below the card.
    save(img, 'HsCardBack', (256, 512))


def hs_badge(name, fill, edge, shape):
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    if shape == 'gem':
        pts = [(32 * s, 2 * s), (60 * s, 22 * s), (50 * s, 60 * s), (14 * s, 60 * s), (4 * s, 22 * s)]
        d.polygon(pts, fill=edge)
        pts = [(32 * s, 8 * s), (54 * s, 24 * s), (46 * s, 55 * s), (18 * s, 55 * s), (10 * s, 24 * s)]
        d.polygon(pts, fill=fill)
        d.polygon([(32 * s, 8 * s), (54 * s, 24 * s), (32 * s, 30 * s), (10 * s, 24 * s)], fill=tuple(min(255, c + 50) for c in fill[:3]) + (255,))
    elif shape == 'drop':
        d.ellipse([6 * s, 16 * s, 58 * s, 62 * s], fill=edge)
        d.polygon([(32 * s, 0), (10 * s, 30 * s), (54 * s, 30 * s)], fill=edge)
        d.ellipse([11 * s, 21 * s, 53 * s, 57 * s], fill=fill)
        d.polygon([(32 * s, 7 * s), (15 * s, 32 * s), (49 * s, 32 * s)], fill=fill)
    elif shape == 'shield':
        d.polygon([(6 * s, 6 * s), (58 * s, 6 * s), (56 * s, 36 * s), (32 * s, 62 * s), (8 * s, 36 * s)], fill=edge)
        d.polygon([(12 * s, 11 * s), (52 * s, 11 * s), (50 * s, 34 * s), (32 * s, 55 * s), (14 * s, 34 * s)], fill=fill)
    else:  # round
        d.ellipse([3 * s, 3 * s, 61 * s, 61 * s], fill=edge)
        d.ellipse([9 * s, 9 * s, 55 * s, 55 * s], fill=fill)
    save(img, name, (64, 64))


def hs_minion_ring():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([4 * s, 4 * s, 124 * s, 124 * s], fill=(70, 55, 38, 255))
    d.ellipse([9 * s, 9 * s, 119 * s, 119 * s], fill=(190, 170, 130, 255))
    d.ellipse([14 * s, 14 * s, 114 * s, 114 * s], fill=(0, 0, 0, 0))
    save(img, 'HsMinionRing', (128, 128))


def hs_mask(name, inset):
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([inset * s, inset * s, (128 - inset) * s, (128 - inset) * s], fill=(255, 255, 255, 255))
    save(img, name, (128, 128))


def hs_taunt():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    pts = [(10 * s, 8 * s), (64 * s, 0), (118 * s, 8 * s), (116 * s, 70 * s), (64 * s, 126 * s), (12 * s, 70 * s)]
    d.polygon(pts, fill=(60, 60, 66, 255))
    pts = [(16 * s, 13 * s), (64 * s, 6 * s), (112 * s, 13 * s), (110 * s, 68 * s), (64 * s, 118 * s), (18 * s, 68 * s)]
    d.polygon(pts, fill=(150, 150, 160, 255))
    d.line([(64 * s, 6 * s), (64 * s, 118 * s)], fill=(110, 110, 120, 255), width=3 * s)
    save(img, 'HsTaunt', (128, 128))


def hs_glow(name, color, width):
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    for i in range(width, 0, -1):
        a = int(color[3] * (1 - i / (width + 1)))
        layer = Image.new('RGBA', (n, n), (0, 0, 0, 0))
        ImageDraw.Draw(layer).ellipse([(8 + width - i) * SS, (8 + width - i) * SS, (120 - width + i) * SS,
                                       (120 - width + i) * SS], outline=color[:3] + (a,), width=2 * SS)
        img = Image.alpha_composite(img, layer)
    save(img, name, (128, 128))


def hs_frozen():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([10 * s, 10 * s, 118 * s, 118 * s], fill=(150, 210, 255, 90))
    for pts in ([(20, 90), (34, 60), (44, 96)], [(80, 20), (100, 36), (76, 44)], [(60, 100), (74, 72), (90, 104)],
                [(28, 30), (50, 22), (40, 48)]):
        d.polygon([(x * s, y * s) for x, y in pts], fill=(225, 245, 255, 200))
    save(img, 'HsFrozen', (128, 128))


def hs_crystal():
    n = 32 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.polygon([(16 * s, 1 * s), (29 * s, 12 * s), (16 * s, 31 * s), (3 * s, 12 * s)], fill=(20, 40, 90, 255))
    d.polygon([(16 * s, 4 * s), (26 * s, 12 * s), (16 * s, 27 * s), (6 * s, 12 * s)], fill=(70, 150, 255, 255))
    d.polygon([(16 * s, 4 * s), (26 * s, 12 * s), (16 * s, 14 * s), (6 * s, 12 * s)], fill=(160, 210, 255, 255))
    save(img, 'HsCrystal', (32, 32))


def hs_icon():
    n = 64 * SS
    img = vignette(n, (60, 38, 22, 255), 50)
    d = ImageDraw.Draw(img)
    s = SS
    back = Image.open(os.path.join(OUT, 'HsCardBack.tga')).crop((0, 0, 256, 356)).resize((26 * s, 36 * s), Image.LANCZOS)
    img.paste(back.rotate(12, expand=True), (4 * s, 10 * s), back.rotate(12, expand=True))
    front = Image.open(os.path.join(OUT, 'HsCardMinion.tga')).crop((0, 0, 256, 356)).resize((28 * s, 39 * s), Image.LANCZOS)
    img.paste(front.rotate(-10, expand=True), (26 * s, 8 * s), front.rotate(-10, expand=True))
    gem = Image.open(os.path.join(OUT, 'HsGem.tga')).resize((14 * s, 14 * s), Image.LANCZOS)
    img.paste(gem, (26 * s, 6 * s), gem)
    save(img, 'IconHearthstone', (64, 64))


hs_card('minion')
hs_card('spell')
hs_back()
hs_badge('HsGem', (40, 110, 230, 255), (15, 35, 90, 255), 'gem')
hs_badge('HsAttack', (235, 180, 40, 255), (110, 70, 10, 255), 'round')
hs_badge('HsHealth', (210, 40, 40, 255), (90, 10, 10, 255), 'drop')
hs_badge('HsArmor', (170, 175, 185, 255), (70, 72, 80, 255), 'shield')
hs_minion_ring()
hs_mask('HsOvalMask', 12)
hs_taunt()
hs_glow('HsDivine', (255, 220, 90, 230), 10)
hs_frozen()
hs_crystal()
hs_icon()
print('hearthstone art written')


# ---------------------------------------------------------------- hearthstone board
# HsBoard: 1024x1024 file, the board in the top 1024x640 (page 738x462,
# so 1 page unit = 1024/738 texture px). Tavern wood, a carved stone rim
# with gold trim, a sandy field, stone pedestals for the heroes and a slot
# for the End Turn button.
def hs_board():
    import random
    rnd = random.Random(7)
    S2 = 2  # lighter supersampling for the big texture
    F = 1024 / 738
    W_, H_ = 1024 * S2, 1024 * S2
    img = Image.new('RGBA', (W_, H_), (0, 0, 0, 255))
    d = ImageDraw.Draw(img)

    def P(x, y):  # page -> texture (supersampled)
        return x * F * S2, y * F * S2

    # Wood planks.
    plank = 58 * S2
    y = 0
    while y < 640 * S2:
        base = rnd.randint(78, 96)
        d.rectangle([0, y, W_, y + plank], fill=(base + 18, int(base * 0.62), int(base * 0.33), 255))
        for _ in range(40):
            gy = y + rnd.randint(2, plank - 2)
            x0 = rnd.randint(0, W_)
            d.line([(x0, gy), (x0 + rnd.randint(80, 400) * S2 // 2, gy + rnd.randint(-3, 3))],
                   fill=(base - 4, int(base * 0.5), int(base * 0.26), 255), width=S2)
        d.line([(0, y), (W_, y)], fill=(40, 24, 12, 255), width=3 * S2)
        x = rnd.randint(0, 300) * S2
        while x < W_:
            d.line([(x, y), (x, y + plank)], fill=(45, 27, 14, 255), width=3 * S2)
            x += rnd.randint(260, 420) * S2
        y += plank
    # Darker edges.
    vig = Image.new('L', (W_, H_), 0)
    vd = ImageDraw.Draw(vig)
    for i in range(60):
        a = int(150 * (1 - i / 60))
        vd.rectangle([i * 4 * S2, i * 4 * S2, W_ - i * 4 * S2, 640 * S2 - i * 4 * S2], outline=a, width=4 * S2)
    img = Image.composite(Image.new('RGBA', (W_, H_), (0, 0, 0, 255)), img, vig)
    d = ImageDraw.Draw(img)

    def rrect(box, r, **kw):
        (x1, y1), (x2, y2) = P(box[0], box[1]), P(box[2], box[3])
        d.rounded_rectangle([x1, y1, x2, y2], radius=r * F * S2, **kw)

    def circle(cx, cy, r, **kw):
        x, y = P(cx, cy)
        rr = r * F * S2
        d.ellipse([x - rr, y - rr, x + rr, y + rr], **kw)

    # Stone rim around the field, with a gold trim.
    rrect((100, 78, 638, 286), 46, fill=(62, 54, 46, 255))
    rrect((106, 84, 632, 280), 42, fill=(128, 116, 100, 255))
    for _ in range(900):
        x, y = P(rnd.uniform(108, 630), rnd.uniform(86, 278))
        c = rnd.randint(95, 150)
        d.point((x, y), fill=(c, c - 10, c - 22, 255))
    rrect((116, 94, 622, 270), 34, fill=(196, 160, 70, 255))
    # The sandy field.
    rrect((120, 98, 618, 266), 30, fill=(198, 176, 136, 255))
    for _ in range(5000):
        x, y = P(rnd.uniform(124, 614), rnd.uniform(102, 262))
        c = rnd.randint(-22, 14)
        d.point((x, y), fill=(198 + c, 176 + c, 136 + c, 255))
    # Lighter middle.
    glow = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    for i in range(30):
        a = int(3 + i * 0.9)
        x1, y1 = P(140 + i * 5, 110 + i * 1.8)
        x2, y2 = P(598 - i * 5, 254 - i * 1.8)
        gd.rounded_rectangle([x1, y1, x2, y2], radius=20 * S2, fill=(255, 240, 200, a))
    img = Image.alpha_composite(img, glow)
    d = ImageDraw.Draw(img)
    # Middle line with a gem.
    x1, y = P(150, 182)
    x2, _ = P(588, 182)
    d.line([(x1, y), (x2, y)], fill=(150, 125, 85, 255), width=2 * S2)
    circle(369, 182, 7, fill=(120, 90, 40, 255))
    circle(369, 182, 5, fill=(90, 160, 220, 255))
    # Hero pedestals (stone discs with a gold ring).
    for cy in (58, 306):
        circle(369, cy, 54, fill=(55, 47, 40, 255))
        circle(369, cy, 50, fill=(120, 108, 94, 255))
        circle(369, cy, 45, fill=(190, 152, 66, 255))
        circle(369, cy, 42, fill=(70, 60, 50, 255))
        # Hero power stand.
        circle(451, cy + 8, 30, fill=(55, 47, 40, 255))
        circle(451, cy + 8, 27, fill=(120, 108, 94, 255))
    # End Turn slot.
    rrect((622, 160, 732, 204), 22, fill=(45, 38, 32, 255))
    rrect((626, 164, 728, 200), 18, fill=(110, 98, 84, 255))
    # Deck shelves on the right.
    for cy in (104, 262):
        rrect((668, cy - 40, 722, cy + 40), 8, fill=(48, 34, 22, 255))
    # Brass studs in the corners of the rim.
    for cx, cy in ((120, 98), (618, 98), (120, 266), (618, 266)):
        circle(cx, cy, 9, fill=(80, 60, 25, 255))
        circle(cx, cy, 6, fill=(225, 185, 85, 255))
    img = img.resize((1024, 1024), Image.LANCZOS)
    img.save(os.path.join(OUT, 'HsBoard.tga'))


def hs_hero_frame():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([2 * s, 2 * s, 126 * s, 126 * s], fill=(60, 45, 20, 255))
    d.ellipse([6 * s, 6 * s, 122 * s, 122 * s], fill=(214, 172, 74, 255))
    d.ellipse([12 * s, 12 * s, 116 * s, 116 * s], fill=(120, 90, 40, 255))
    d.ellipse([16 * s, 16 * s, 112 * s, 112 * s], fill=(0, 0, 0, 0))
    # Little gems at the sides.
    for x, y in ((64, 4), (4, 64), (124, 64)):
        d.ellipse([(x - 6) * s, (y - 6) * s, (x + 6) * s, (y + 6) * s], fill=(60, 45, 20, 255))
        d.ellipse([(x - 4) * s, (y - 4) * s, (x + 4) * s, (y + 4) * s], fill=(200, 40, 40, 255))
    save(img, 'HsHeroFrame', (128, 128))


def hs_end_turn():
    W_, H_ = 256 * SS, 128 * SS
    img = Image.new('RGBA', (W_, H_), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([4 * s, 14 * s, 252 * s, 114 * s], fill=(60, 45, 20, 255))
    d.ellipse([10 * s, 20 * s, 246 * s, 108 * s], fill=(210, 170, 70, 255))
    # The face is light grey so the page can tint it (yellow / green / grey).
    d.ellipse([18 * s, 27 * s, 238 * s, 101 * s], fill=(235, 235, 235, 255))
    d.ellipse([30 * s, 32 * s, 226 * s, 60 * s], fill=(255, 255, 255, 255))
    save(img, 'HsEndTurn', (256, 128))


hs_board()
hs_hero_frame()
hs_end_turn()
print('hearthstone board written')


# ---------------------------------------------------------------- warcraft (rts)
def wc_grass():
    import random
    rnd = random.Random(11)
    n = 256
    img = Image.new('RGBA', (n, n), (70, 110, 45, 255))
    px = img.load()
    for y in range(n):
        for x in range(n):
            c = rnd.randint(-10, 10)
            px[x, y] = (70 + c, 112 + c, 44 + c // 2, 255)
    d = ImageDraw.Draw(img)
    for _ in range(260):
        x, y = rnd.randint(0, n - 1), rnd.randint(0, n - 1)
        col = (rnd.randint(50, 70), rnd.randint(95, 130), rnd.randint(30, 45), 255)
        for k in range(3):
            d.line([(x + k - 1, y), (x + k - 2 + rnd.randint(0, 2), y - rnd.randint(2, 5))], fill=col)
    for _ in range(40):
        x, y = rnd.randint(0, n - 1), rnd.randint(0, n - 1)
        r = rnd.randint(6, 14)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(80, 118, 50, 70))
    img.save(os.path.join(OUT, 'WcGrass.tga'))


def wc_tree():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([10 * s, 40 * s, 58 * s, 60 * s], fill=(0, 0, 0, 90))  # shadow
    d.rectangle([29 * s, 40 * s, 35 * s, 56 * s], fill=(80, 50, 25, 255))
    for (y, w, col) in ((30, 26, (20, 70, 30)), (20, 21, (28, 88, 38)), (10, 15, (36, 104, 46))):
        d.polygon([(32 * s, (y - 14) * s), ((32 + w) * s, (y + 16) * s), ((32 - w) * s, (y + 16) * s)], fill=col + (255,))
    save(img, 'WcTree', (64, 64))


def wc_mine():
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([6 * s, 30 * s, 122 * s, 124 * s], fill=(0, 0, 0, 90))
    d.ellipse([4 * s, 18 * s, 124 * s, 118 * s], fill=(105, 95, 85, 255))
    d.ellipse([14 * s, 22 * s, 114 * s, 100 * s], fill=(135, 125, 110, 255))
    d.chord([40 * s, 50 * s, 88 * s, 110 * s], 180, 360, fill=(30, 22, 15, 255))
    d.rectangle([40 * s, 80 * s, 88 * s, 106 * s], fill=(30, 22, 15, 255))
    d.rectangle([36 * s, 74 * s, 42 * s, 108 * s], fill=(110, 75, 40, 255))
    d.rectangle([86 * s, 74 * s, 92 * s, 108 * s], fill=(110, 75, 40, 255))
    d.rectangle([34 * s, 70 * s, 94 * s, 78 * s], fill=(110, 75, 40, 255))
    for x, y in ((24, 44), (96, 40), (70, 30), (20, 80), (104, 78), (52, 34)):
        d.ellipse([x * s, y * s, (x + 10) * s, (y + 8) * s], fill=(240, 200, 60, 255))
        d.ellipse([(x + 2) * s, (y + 1) * s, (x + 6) * s, (y + 4) * s], fill=(255, 240, 160, 255))
    save(img, 'WcMine', (128, 128))


def wc_building(name, size_px, base, roof, trim, kind):
    n = 128 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.rectangle([8 * s, 16 * s, 124 * s, 124 * s], fill=(0, 0, 0, 80))
    if kind == 'human':
        d.rectangle([6 * s, 40 * s, 120 * s, 118 * s], fill=base + (255,))
        for yy in range(48, 118, 12):
            d.line([(6 * s, yy * s), (120 * s, yy * s)], fill=tuple(max(0, c - 30) for c in base) + (255,), width=s)
        d.polygon([(0, 46 * s), (64 * s, 4 * s), (126 * s, 46 * s)], fill=roof + (255,))
        d.polygon([(10 * s, 46 * s), (64 * s, 12 * s), (116 * s, 46 * s)], fill=tuple(min(255, c + 30) for c in roof) + (255,))
        d.rectangle([52 * s, 86 * s, 76 * s, 118 * s], fill=(70, 45, 25, 255))
        d.rectangle([0, 44 * s, 126 * s, 50 * s], fill=trim + (255,))
    else:
        d.ellipse([4 * s, 30 * s, 122 * s, 122 * s], fill=base + (255,))
        d.ellipse([16 * s, 40 * s, 110 * s, 112 * s], fill=tuple(min(255, c + 25) for c in base) + (255,))
        for x0, y0 in ((10, 40), (40, 18), (88, 18), (118, 40), (64, 6)):
            d.polygon([(x0 * s, (y0 + 30) * s), ((x0 - 6) * s, (y0 + 30) * s), ((x0 - 3) * s, y0 * s)], fill=(235, 225, 200, 255))
        d.chord([46 * s, 74 * s, 82 * s, 122 * s], 180, 360, fill=(40, 25, 15, 255))
        d.rectangle([46 * s, 98 * s, 82 * s, 116 * s], fill=(40, 25, 15, 255))
        d.rectangle([60 * s, 30 * s, 68 * s, 64 * s], fill=trim + (255,))
    save(img, name, (size_px, size_px))


def wc_ring(name, color, width):
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    s = SS
    d.ellipse([2 * s, 2 * s, 62 * s, 62 * s], outline=color, width=width * s)
    save(img, name, (64, 64))


def wc_res_icons():
    n = 32 * SS
    s = SS
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for x, y in ((4, 14), (14, 8), (14, 18)):
        d.ellipse([x * s, y * s, (x + 14) * s, (y + 10) * s], fill=(200, 150, 30, 255))
        d.ellipse([(x + 2) * s, (y + 1) * s, (x + 12) * s, (y + 7) * s], fill=(250, 210, 70, 255))
    save(img, 'WcGold', (32, 32))
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    for y in (8, 15, 22):
        d.rounded_rectangle([3 * s, y * s, 29 * s, (y + 6) * s], radius=3 * s, fill=(130, 85, 40, 255))
        d.ellipse([24 * s, y * s, 30 * s, (y + 6) * s], fill=(200, 160, 100, 255))
    save(img, 'WcLumber', (32, 32))
    img = Image.new('RGBA', (n, n), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.ellipse([6 * s, 6 * s, 26 * s, 24 * s], fill=(200, 90, 50, 255))
    d.rectangle([14 * s, 20 * s, 18 * s, 30 * s], fill=(230, 220, 200, 255))
    d.ellipse([10 * s, 10 * s, 16 * s, 15 * s], fill=(240, 150, 110, 255))
    save(img, 'WcFood', (32, 32))


def wc_icon():
    n = 64 * SS
    img = Image.new('RGBA', (n, n), (70, 110, 45, 255))
    d = ImageDraw.Draw(img)
    s = SS
    th = Image.open(os.path.join(OUT, 'WcTownHall.tga')).resize((30 * s, 30 * s), Image.LANCZOS)
    gh = Image.open(os.path.join(OUT, 'WcGreatHall.tga')).resize((30 * s, 30 * s), Image.LANCZOS)
    img.paste(th, (2 * s, 2 * s), th)
    img.paste(gh, (32 * s, 32 * s), gh)
    for x, y, c in ((40, 14, (60, 120, 230)), (48, 20, (60, 120, 230)), (16, 44, (220, 50, 40)), (24, 50, (220, 50, 40))):
        d.ellipse([x * s, y * s, (x + 8) * s, (y + 8) * s], fill=c + (255,), outline=(255, 255, 255, 255), width=s)
    d.line([(36 * s, 30 * s), (28 * s, 38 * s)], fill=(255, 230, 120, 255), width=2 * s)
    save(img, 'IconWarcraft', (64, 64))


wc_grass()
wc_tree()
wc_mine()
wc_building('WcTownHall', 128, (150, 140, 125), (50, 90, 170), (200, 170, 70), 'human')
wc_building('WcFarm', 64, (170, 130, 80), (160, 60, 40), (200, 170, 70), 'human')
wc_building('WcBarracks', 128, (130, 120, 110), (60, 70, 140), (180, 40, 40), 'human')
wc_building('WcGreatHall', 128, (120, 80, 45), (0, 0, 0), (170, 30, 30), 'orc')
wc_building('WcBurrow', 64, (105, 75, 45), (0, 0, 0), (170, 30, 30), 'orc')
wc_building('WcOrcBarracks', 128, (95, 65, 40), (0, 0, 0), (170, 30, 30), 'orc')
wc_ring('WcRing', (255, 255, 255, 255), 5)
wc_ring('WcSelect', (80, 255, 80, 255), 3)
wc_res_icons()
wc_icon()
print('warcraft art written')

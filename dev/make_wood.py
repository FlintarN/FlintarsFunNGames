# Draws Art/WoodPlanks.tga: dark tavern wood planks for the Warcraft 4 and
# Hearthstone 2 menus. 512 x 512, tiles seamlessly both ways.
# Run: python dev/make_wood.py
import os
import numpy as np
from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, '..', 'Art', 'WoodPlanks.tga')
N = 512
PLANKS = 8
H = N // PLANKS
rng = np.random.default_rng(7)

y, x = np.mgrid[0:N, 0:N].astype(np.float64)
img = np.zeros((N, N, 3))

def periodic_noise(octaves):
    # Smooth noise that wraps round: a sum of sines with whole cycles.
    out = np.zeros((N, N))
    for cx, cy, amp in octaves:
        ph = rng.uniform(0, 2 * np.pi)
        out += amp * np.sin(2 * np.pi * (cx * x + cy * y) / N + ph)
    return out

for i in range(PLANKS):
    y0 = i * H
    rows = (y >= y0) & (y < y0 + H)
    base = np.array([92, 56, 30]) * rng.uniform(0.82, 1.1)
    # Grain: long streaks along the plank, wobbling a little.
    wob = periodic_noise([(1, 0, 3.0), (3, 0, 1.5), (7, 0, 0.6)])
    k = rng.uniform(0.35, 0.6)
    grain = np.sin((y - y0 + wob) * k * 2.2 + periodic_noise([(2, 0, 2.0), (5, 0, 1.0)]))
    fine = periodic_noise([(23, 3, 0.25), (41, 7, 0.15), (67, 11, 0.1)])
    shade = 1 + 0.16 * grain + 0.35 * fine * 0.4
    # A knot or two.
    for _ in range(rng.integers(0, 3)):
        kx, ky = rng.uniform(0, N), y0 + rng.uniform(H * 0.3, H * 0.7)
        dx = np.minimum(np.abs(x - kx), N - np.abs(x - kx))
        d = np.sqrt((dx / 1.8) ** 2 + (y - ky) ** 2)
        shade -= 0.25 * np.exp(-(d / 7) ** 2) * (0.6 + 0.4 * np.sin(d * 1.3))
    for c in range(3):
        img[..., c] = np.where(rows, base[c] * shade, img[..., c])
    # Bevel: light top edge, dark bottom edge, a dark gap between planks.
    edge = y - y0
    img[(rows) & (edge < 2)] *= 1.18
    img[(rows) & (edge > H - 4)] *= 0.72
    img[(rows) & (edge > H - 2)] *= 0.35
    # Where boards meet (staggered), with two nails.
    jx = int(rng.uniform(0, N))
    for j in (jx, (jx + N // 2) % N):
        cols = (np.abs(x - j) < 1.5) | (np.abs(x - j - N) < 1.5)
        img[rows & cols] *= 0.35
        for ny in (y0 + H * 0.3, y0 + H * 0.7):
            for nx in (j - 6, j + 6):
                nx = nx % N
                d = np.sqrt((x - nx) ** 2 + (y - ny) ** 2)
                m = d < 2.6
                img[m] = img[m] * 0.4 + np.array([150, 140, 120]) * 0.6

# Darker towards nothing in particular: a gentle overall dimming (menus sit on it).
img *= 0.78
img = np.clip(img, 0, 255).astype(np.uint8)
alpha = np.full((N, N, 1), 255, np.uint8)
Image.fromarray(np.concatenate([img, alpha], axis=2), 'RGBA').save(OUT)
print('wrote', OUT)

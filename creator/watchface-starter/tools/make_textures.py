#!/usr/bin/env python3
"""Render the optional near-black dial textures (mottled washi, snowfall, birch bark).

Needs pillow + numpy. Run from creator/watchface-starter:  python3 tools/make_textures.py
Writes resources-round-<N>x<N>/drawables/tex_<name>.png at the strongest ("Bold") level,
dithered to RGB565 (the Venu 3's 16-bit colour). The watch tints them darker for the
weaker Texture Strength settings, so one image per pattern covers every strength.
Same patterns as the 1.4.0 options preview.
"""
import os
import numpy as np
from PIL import Image

# Calibration knobs: judge on the watch, tweak, re-run.
BASE = 26.0   # dial grey at Bold (0-255); the watch scales it down for weaker strengths
AMP = 34.0    # relief at Bold; Medium (x0.55) is a little above the preview's "visible" setting


def perm(seed):
    p = list(range(256))
    s = seed
    for i in range(255, 0, -1):
        s = (s * 16807) % 2147483647
        j = s % (i + 1)
        p[i], p[j] = p[j], p[i]
    return np.array(p + p, dtype=np.int64)


def value_noise(p):
    def n(x, y):
        fx, fy = np.floor(x), np.floor(y)
        xi, yi = fx.astype(np.int64) & 255, fy.astype(np.int64) & 255
        u, v = x - fx, y - fy
        u, v = u * u * (3 - 2 * u), v * v * (3 - 2 * v)
        h = lambda i, j: p[p[i] + j] / 255.0
        a, b, c, d = h(xi, yi), h(xi + 1, yi), h(xi, yi + 1), h(xi + 1, yi + 1)
        return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v
    return n


N1, N2, N3 = value_noise(perm(7)), value_noise(perm(19)), value_noise(perm(31))


def fbm(n, x, y, octaves):
    s, a, t = 0.0, 0.5, 0.0
    for _ in range(octaves):
        s = s + a * n(x, y)
        t += a
        x, y, a = x * 2.03, y * 2.03, a * 0.5
    return s / t


HEIGHT = {
    "washi": lambda x, y: np.clip((fbm(N1, x / 55, y / 55, 5) - 0.38) * 3.2, 0, 1) * 0.75 + fbm(N2, x / 6, y / 6, 2) * 0.25,
    "snowfall": lambda x, y: fbm(N1, x / 7, y / 9, 3) * 0.7 + fbm(N3, x / 2.6, y / 2.6, 2) * 0.3,
    "birch": lambda x, y: fbm(N1, x / 3.2, y / 48, 3) * 0.75 + fbm(N2, x / 24, y / 7, 2) * 0.25,
}


def render(kind, n):
    y, x = np.mgrid[0:n + 2, 0:n + 2].astype(np.float64)
    h = HEIGHT[kind](x, y)
    gx = h[1:-1, 2:] - h[1:-1, :-2]
    gy = h[2:, 1:-1] - h[:-2, 1:-1]
    shade = (gx + gy) * 0.7071 + (h[1:-1, 1:-1] - 0.5) * 0.15   # relief lit from the upper left
    v = BASE + AMP * shade / np.abs(shade).max()
    return np.stack([v, v, v + 1.5], axis=-1)


def dither565(img):
    h, w, _ = img.shape
    out = np.zeros((h, w, 3), np.uint8)
    for ch, bits in enumerate((5, 6, 5)):
        top = (1 << bits) - 1
        p = img[..., ch].tolist()
        o = out[..., ch]
        for yy in range(h):
            row, nxt = p[yy], p[yy + 1] if yy + 1 < h else None
            for xx in range(w):
                q = min(top, max(0, round(row[xx] * top / 255)))
                err = row[xx] - q * 255 / top
                o[yy, xx] = (q << (8 - bits)) | (q >> (2 * bits - 8))
                if xx + 1 < w:
                    row[xx + 1] += err * 7 / 16
                if nxt is not None:
                    if xx > 0:
                        nxt[xx - 1] += err * 3 / 16
                    nxt[xx] += err * 5 / 16
                    if xx + 1 < w:
                        nxt[xx + 1] += err / 16
    return out


if __name__ == "__main__":
    for n in (454, 390):   # venu3, venu3s
        folder = f"resources-round-{n}x{n}/drawables"
        os.makedirs(folder, exist_ok=True)
        for kind in HEIGHT:
            path = f"{folder}/tex_{kind}.png"
            Image.fromarray(dither565(render(kind, n))).save(path, optimize=True)
            print(f"wrote {path}  {os.path.getsize(path) // 1024} KB")

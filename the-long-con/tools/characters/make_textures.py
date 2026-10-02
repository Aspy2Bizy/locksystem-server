#!/usr/bin/env python3
"""Generate tileable detail textures for characters (normal maps + detail masks).

All textures are procedural, so there is nothing to license.
Usage: python3 tools/characters/make_textures.py
Needs: numpy, pillow
"""

import os

import numpy as np
from PIL import Image

OUT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "assets", "characters", "textures"))
N = 512
rng = np.random.default_rng(1234)


def periodic_noise(size, cutoff_lo, cutoff_hi=None):
    """Band-limited tileable noise via FFT filtering."""
    white = rng.standard_normal((size, size))
    f = np.fft.fft2(white)
    fy = np.fft.fftfreq(size)[:, None]
    fx = np.fft.fftfreq(size)[None, :]
    r = np.sqrt(fx * fx + fy * fy) * size
    mask = r <= cutoff_lo if cutoff_hi is None else (r >= cutoff_lo) & (r <= cutoff_hi)
    out = np.real(np.fft.ifft2(f * mask))
    return (out - out.mean()) / (out.std() + 1e-9)


def height_to_normal(h, strength):
    dx = (np.roll(h, -1, axis=1) - np.roll(h, 1, axis=1)) * 0.5 * strength
    dy = (np.roll(h, -1, axis=0) - np.roll(h, 1, axis=0)) * 0.5 * strength
    n = np.dstack([-dx, -dy, np.ones_like(h)])
    n /= np.linalg.norm(n, axis=2, keepdims=True)
    return Image.fromarray(((n * 0.5 + 0.5) * 255).astype(np.uint8), "RGB")


def gray(h):
    h = (h - h.min()) / (h.max() - h.min() + 1e-9)
    return Image.fromarray((h * 255).astype(np.uint8), "L")


def save(img, name):
    img.save(os.path.join(OUT, name))
    print("wrote", name)


def main():
    os.makedirs(OUT, exist_ok=True)
    y, x = np.mgrid[0:N, 0:N].astype(np.float64)

    # Skin: pores (small pits), fine wrinkles, soft mottling.
    pores = np.zeros((N, N))
    for _ in range(4000):
        cx, cy = rng.integers(0, N, 2)
        r = rng.uniform(0.8, 1.8)
        dxp = np.minimum(np.abs(x - cx), N - np.abs(x - cx))
        dyp = np.minimum(np.abs(y - cy), N - np.abs(y - cy))
        d2 = dxp * dxp + dyp * dyp
        pores -= np.exp(-d2 / (2 * r * r)) * rng.uniform(0.5, 1.0)
    wrinkles = periodic_noise(N, 40, 90)
    skin_h = pores + 0.25 * wrinkles + 0.15 * periodic_noise(N, 6)
    save(height_to_normal(skin_h, 1.2), "skin_pores_n.png")
    save(gray(periodic_noise(N, 5) + 0.3 * periodic_noise(N, 25)), "skin_mottle.png")

    # Twill (diagonal weave) for trousers, uniforms, jumpsuits.
    t = np.sin((x + y) * 2 * np.pi / 8) + 0.35 * np.sin(x * 2 * np.pi / 4)
    twill_h = t + 0.25 * periodic_noise(N, 60, 160)
    save(height_to_normal(twill_h, 0.6), "fabric_twill_n.png")

    # Ripstop: plain weave with a reinforcing grid every 32 px.
    plain = np.sin(x * 2 * np.pi / 4) * np.sin(y * 2 * np.pi / 4)
    grid = (np.exp(-((x % 32) - 16) ** 2 / 2.0) + np.exp(-((y % 32) - 16) ** 2 / 2.0))
    save(height_to_normal(0.5 * plain + 1.2 * grid + 0.2 * periodic_noise(N, 80, 200), 0.7), "fabric_ripstop_n.png")

    # Rib knit for balaclavas.
    knit = np.abs(np.sin(x * 2 * np.pi / 16)) + 0.4 * np.sin(y * 2 * np.pi / 8 + np.sin(x * 2 * np.pi / 16) * 2)
    save(height_to_normal(knit + 0.2 * periodic_noise(N, 80, 200), 1.4), "knit_n.png")

    # Coarse nylon (cordura) for plate carriers.
    cord = np.sin(x * 2 * np.pi / 6) + np.sin(y * 2 * np.pi / 6) + 0.6 * periodic_noise(N, 50, 140)
    save(height_to_normal(cord, 1.0), "cordura_n.png")

    # Leather grain for gloves and boots.
    grain = periodic_noise(N, 30, 120) + 0.5 * np.abs(periodic_noise(N, 10, 30))
    save(height_to_normal(grain, 0.8), "leather_n.png")

    # Hair strands (anisotropic streaks) for the short-hair cap.
    sx = np.fft.fftfreq(N)[None, :]
    sy = np.fft.fftfreq(N)[:, None]
    f = np.fft.fft2(rng.standard_normal((N, N)))
    mask = (np.abs(sy * N) < 3) & (np.abs(sx * N) > 20) & (np.abs(sx * N) < 200)
    strands = np.real(np.fft.ifft2(f * mask))
    save(height_to_normal(strands / (strands.std() + 1e-9), 1.5), "hair_n.png")
    save(gray(strands), "hair_mask.png")


if __name__ == "__main__":
    main()

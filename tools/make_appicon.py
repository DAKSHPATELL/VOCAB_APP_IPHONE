#!/usr/bin/env python3
"""Renders the 1024×1024 App Store icon with the same ember language as the
wallpapers. Pure standard library — no Pillow, no design tool, no binary blob
checked into the repo that nobody can regenerate.

Run:  python3 tools/make_appicon.py
"""

import math
import pathlib
import random
import struct
import zlib

SIZE = 1024
OUT = (pathlib.Path(__file__).resolve().parent.parent
       / "App/VocabWallpaper/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png")

VOID = (0x05, 0x03, 0x04)
PITCH = (0x0E, 0x07, 0x07)
BLOOD = (0xB0, 0x14, 0x14)
EMBER = (0xFF, 0x4D, 0x1C)
ORANGE = (0xFF, 0x8A, 0x28)
GOLD = (0xFF, 0xC7, 0x6B)


def mix(a, b, t):
    t = max(0.0, min(1.0, t))
    return tuple(a[i] + (b[i] - a[i]) * t for i in range(3))


def screen(base, light, amount):
    """Screen blend, so glows stack the way they do in the SwiftUI canvas."""
    amount = max(0.0, min(1.0, amount))
    return tuple(
        255 - (255 - base[i]) * (255 - light[i] * amount) / 255
        for i in range(3)
    )


def falloff(distance, radius):
    if distance >= radius:
        return 0.0
    t = 1.0 - distance / radius
    return t * t * t


def distance_to_segment(px, py, ax, ay, bx, by):
    dx, dy = bx - ax, by - ay
    length_squared = dx * dx + dy * dy
    if length_squared == 0:
        return math.hypot(px - ax, py - ay)
    t = max(0.0, min(1.0, ((px - ax) * dx + (py - ay) * dy) / length_squared))
    return math.hypot(px - (ax + t * dx), py - (ay + t * dy))


# A capital W drawn as four strokes — "Wort". Rasterising a real serif face
# would mean shipping a font binary; this keeps the icon reproducible.
W_STROKES = [
    ((0.250, 0.330), (0.393, 0.712)),
    ((0.393, 0.712), (0.500, 0.472)),
    ((0.500, 0.472), (0.607, 0.712)),
    ((0.607, 0.712), (0.750, 0.330)),
]
W_HALF_WIDTH = 0.0345


def render():
    rng = random.Random(0x5645_524E)
    rows = []

    # Pre-computed glow centres: (x, y, radius, colour, strength)
    blooms = [
        (0.50, 0.90, 0.60, EMBER, 0.90),
        (0.18, 0.96, 0.42, BLOOD, 0.65),
        (0.84, 0.82, 0.38, ORANGE, 0.55),
        (0.50, 0.52, 0.34, BLOOD, 0.30),
    ]

    for py in range(SIZE):
        v = py / (SIZE - 1)
        row = bytearray()
        base_row = mix(PITCH, VOID, min(v * 1.4, 1.0))

        for px in range(SIZE):
            u = px / (SIZE - 1)
            colour = base_row

            for bx, by, radius, tint, strength in blooms:
                distance = math.hypot(u - bx, v - by)
                weight = falloff(distance, radius)
                if weight > 0:
                    colour = screen(colour, tint, weight * strength)

            # Vignette pulls the corners back down to black.
            edge = math.hypot(u - 0.5, v - 0.5) / 0.707
            colour = mix(colour, VOID, max(0.0, (edge - 0.55)) * 1.5)

            # The letter, plus the heat it throws off.
            letter_distance = min(
                distance_to_segment(u, v, ax, ay, bx, by)
                for (ax, ay), (bx, by) in W_STROKES
            )
            if letter_distance < W_HALF_WIDTH * 5:
                halo = falloff(letter_distance, W_HALF_WIDTH * 5)
                colour = screen(colour, EMBER, halo * 0.75)
            if letter_distance < W_HALF_WIDTH + 0.004:
                # Vertical gradient down the strokes: gold at the top, ember below.
                tint = mix(GOLD, EMBER, max(0.0, min(1.0, (v - 0.33) / 0.38)))
                coverage = min(1.0, (W_HALF_WIDTH + 0.004 - letter_distance) / 0.0035)
                colour = mix(colour, tint, coverage)

            # A whisper of grain so the gradients never band on an OLED panel.
            noise = (rng.random() - 0.5) * 2.2
            row += bytes(
                max(0, min(255, int(round(channel + noise))))
                for channel in colour
            )

        rows.append(bytes(row))

    return rows


def write_png(rows, path):
    raw = b"".join(b"\x00" + row for row in rows)

    def chunk(tag, payload):
        data = tag + payload
        return (struct.pack(">I", len(payload)) + data
                + struct.pack(">I", zlib.crc32(data) & 0xFFFF_FFFF))

    header = struct.pack(">IIBBBBB", SIZE, SIZE, 8, 2, 0, 0, 0)  # 8-bit truecolour, no alpha
    png = (b"\x89PNG\r\n\x1a\n"
           + chunk(b"IHDR", header)
           + chunk(b"IDAT", zlib.compress(raw, 9))
           + chunk(b"IEND", b""))
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)
    return len(png)


if __name__ == "__main__":
    size = write_png(render(), OUT)
    print(f"wrote {OUT.name} ({size / 1024:.0f} KB, {SIZE}×{SIZE}, no alpha channel)")

#!/usr/bin/env python3
"""Generate an opaque 1024px app icon using only Python's standard library."""
import json
import math
from pathlib import Path
import struct
import zlib

SIZE = 1024
pixels = bytearray(SIZE * SIZE * 3)
for y in range(SIZE):
    for x in range(SIZE):
        t = (x + y) / (SIZE * 2)
        color = tuple(round(a + (b - a) * t) for a, b in zip((7, 63, 64), (18, 149, 119)))
        i = (y * SIZE + x) * 3
        pixels[i:i+3] = bytes(color)

def rounded(x0, y0, x1, y1, radius, color):
    for y in range(y0, y1):
        for x in range(x0, x1):
            cx = min(max(x, x0 + radius), x1 - radius - 1)
            cy = min(max(y, y0 + radius), y1 - radius - 1)
            if (x - cx) ** 2 + (y - cy) ** 2 <= radius ** 2:
                i = (y * SIZE + x) * 3
                pixels[i:i+3] = bytes(color)

rounded(214, 244, 834, 848, 76, (9, 77, 69))
rounded(202, 214, 822, 818, 76, (245, 249, 244))
rounded(202, 214, 822, 380, 76, (222, 237, 225))
rounded(202, 300, 822, 380, 0, (222, 237, 225))
rounded(322, 155, 364, 296, 21, (245, 249, 244))
rounded(660, 155, 702, 296, 21, (245, 249, 244))
for x, y in [(294, 444), (466, 444), (638, 444), (294, 608), (466, 608)]:
    rounded(x, y, x + 80, y + 80, 19, (53, 135, 111))
rounded(592, 571, 884, 863, 146, (13, 126, 103))
rounded(715, 636, 761, 798, 12, (255, 255, 255))
rounded(657, 694, 819, 740, 12, (255, 255, 255))

def chunk(kind, data):
    return struct.pack('>I', len(data)) + kind + data + struct.pack('>I', zlib.crc32(kind + data) & 0xffffffff)

raw = b''.join(b'\x00' + pixels[y * SIZE * 3:(y + 1) * SIZE * 3] for y in range(SIZE))
png = b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', SIZE, SIZE, 8, 2, 0, 0, 0)) + chunk(b'IDAT', zlib.compress(raw, 9)) + chunk(b'IEND', b'')
assets = Path(__file__).resolve().parent.parent / 'PlantaoNaMao' / 'Assets.xcassets'
icon = assets / 'AppIcon.appiconset'
icon.mkdir(parents=True, exist_ok=True)
(icon / 'AppIcon.png').write_bytes(png)
(assets / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
(icon / 'Contents.json').write_text(json.dumps({'images': [{'filename': 'AppIcon.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'}], 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
print(f'AppIcon.png: {len(png)} bytes, RGB 1024x1024')

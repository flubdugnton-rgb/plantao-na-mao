#!/usr/bin/env python3
"""Prepare the approved artwork, or validate the installed icon without replacing it.

Usage: python3 scripts/generate-icon.py [approved-square.png]
Resizing a supplied source uses sips on macOS. Never draws a substitute icon.
"""
import argparse
from pathlib import Path
import shutil
import struct
import subprocess


def png_info(path):
    data = path.read_bytes()
    if data[:8] != b'\x89PNG\r\n\x1a\n' or data[12:16] != b'IHDR':
        raise SystemExit('O ícone deve ser um arquivo PNG válido.')
    width, height, depth, color = struct.unpack('>IIBB', data[16:26])
    if width != height or depth != 8 or color != 2:
        raise SystemExit('Use PNG quadrado, RGB de 8 bits e sem transparência.')
    return width, height


parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('source', nargs='?', type=Path)
args = parser.parse_args()
icon = Path(__file__).resolve().parent.parent / 'PlantaoNaMao/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
if args.source:
    size = png_info(args.source)
    if args.source.resolve() != icon.resolve():
        if size == (1024, 1024):
            shutil.copyfile(args.source, icon)
        else:
            subprocess.run(['sips', '-s', 'format', 'png', '-z', '1024', '1024', str(args.source), '--out', str(icon)], check=True)
if png_info(icon) != (1024, 1024):
    raise SystemExit('O ícone final deve ter 1024 × 1024 pixels.')
print(f'Ícone aprovado preservado: RGB opaco, 1024 × 1024, {icon.stat().st_size} bytes')

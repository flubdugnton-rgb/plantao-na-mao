#!/usr/bin/env python3
"""Build the Mac icon from the exact approved iOS artwork."""
import json
from pathlib import Path
import subprocess

root = Path(__file__).resolve().parent.parent
source = root / 'PlantaoNaMao/Assets.xcassets/AppIcon.appiconset/AppIcon.png'
catalog = root / 'PlantaoNaMaoMac/Assets.xcassets'
folder = catalog / 'MacAppIcon.appiconset'
folder.mkdir(parents=True, exist_ok=True)
(catalog / 'Contents.json').write_text(json.dumps({'info': {'author': 'xcode', 'version': 1}}))
images = []
for size in (16, 32, 128, 256, 512):
    for scale in (1, 2):
        filename = f'icon_{size}x{size}@{scale}x.png'
        destination = folder / filename
        pixels = str(size * scale)
        if not destination.exists() or destination.stat().st_mtime < source.stat().st_mtime:
            subprocess.run(['sips', '-z', pixels, pixels, str(source), '--out', str(destination)], check=True, stdout=subprocess.DEVNULL)
        images.append({'idiom': 'mac', 'size': f'{size}x{size}', 'scale': f'{scale}x', 'filename': filename})
(folder / 'Contents.json').write_text(json.dumps({'images': images, 'info': {'author': 'xcode', 'version': 1}}, indent=2) + '\n')
print('Ícone macOS preparado a partir da arte original do Plantão na Mão.')

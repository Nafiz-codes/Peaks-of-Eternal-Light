"""Convert user-provided NASA CGI Moon Kit TIFFs to Godot runtime textures.
Usage: python tools/prepare_moon_maps.py E:/
Requires Pillow and NumPy. Source files are read only.
"""
from pathlib import Path
import argparse
import numpy as np
from PIL import Image


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('source', type=Path)
    args = parser.parse_args()
    output = Path(__file__).resolve().parents[1] / 'Assets' / 'moon'
    output.mkdir(parents=True, exist_ok=True)
    for source, target in [('lroc_color_16bit_srgb_4k.tif', 'lroc_2025_4k.png'),
                           ('lroc_color_poles_4k.tif', 'lroc_2019_4k.png')]:
        with Image.open(args.source / source) as image:
            assert image.size == (4096, 2048), (source, image.size)
            # Pillow decodes 16-bit/channel RGB to 8-bit/channel RGB.
            # Keep native 4K spatial resolution and the source sRGB encoding.
            image.convert('RGB').save(output / target)
    with Image.open(args.source / 'ldem_4.tif') as image:
        height = np.array(image, dtype=np.float64)
    assert height.shape == (720, 1440) and np.isfinite(height).all()
    rows, cols = height.shape
    latitude = np.pi / 2 - (np.arange(rows) + 0.5) * np.pi / rows
    # Slopes in the east/north basis. Longitude neighbors wrap at +/-180.
    east = (np.roll(height, -1, axis=1) - np.roll(height, 1, axis=1)) / (4 * np.pi / cols)
    north = -np.gradient(height, np.pi / rows, axis=0)
    radius = 1737.4 + height  # NASA's float TIFF stores elevation in kilometers.
    east /= radius * np.cos(latitude)[:, None]
    north /= radius
    normal = np.stack((-east, -north, np.ones_like(height)), axis=-1)
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    # Fade the singular tangent basis over the last degree at each pole.
    fade = np.clip((np.pi / 2 - np.abs(latitude)) / np.deg2rad(1), 0, 1)
    normal[:, :, :2] *= fade[:, None, None]
    normal /= np.linalg.norm(normal, axis=-1, keepdims=True)
    encoded = np.rint((normal * 0.5 + 0.5) * 255).clip(0, 255).astype(np.uint8)
    Image.fromarray(encoded).save(output / 'lola_relief.png')
    print('Generated two 4096x2048 color maps and a 1440x720 LOLA relief map.')


if __name__ == '__main__':
    main()

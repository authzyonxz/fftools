#!/usr/bin/env python3
"""Generate FFPatch app/game icons from the project owner's supplied artwork.

Sources (see NOTICE.md for source links):
    Resources/SourceArt/ff_normal.jpg  Free Fire Normal logo supplied by owner
    Resources/SourceArt/ff_max.jpg     Free Fire MAX logo supplied by owner
    Resources/SourceArt/app_logo.jpg   vertical app logo supplied by owner

Outputs:
    Resources/Assets/ic_game_normal.png  192 px in-app game card
    Resources/Assets/ic_game_max.png     192 px in-app game card
    Resources/Assets.xcassets/AppIcon.appiconset/*.png  SpringBoard icon
"""
import os
from PIL import Image, ImageDraw, ImageStat

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCE = os.path.join(ROOT, "Resources", "SourceArt")
ASSETS = os.path.join(ROOT, "Resources", "Assets")
APPICON = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")

os.makedirs(ASSETS, exist_ok=True)
os.makedirs(APPICON, exist_ok=True)


def load(path):
    with Image.open(path) as source:
        return source.convert("RGB")


def square(image, size):
    """Resize a square source; reject non-square input instead of silently cropping it."""
    if image.width != image.height:
        raise ValueError(f"Esperado logo quadrado, recebido {image.width}x{image.height}")
    return image.resize((size, size), Image.Resampling.LANCZOS)


def fit_app_logo(image, size):
    """Fit the full portrait artwork on a matching red square canvas (no crop)."""
    scale = min(size / image.width, size / image.height)
    fitted = image.resize((round(image.width * scale), round(image.height * scale)),
                          Image.Resampling.LANCZOS)
    background_strip = image.crop((0, 0, image.width, max(1, image.height // 4)))
    color = tuple(round(channel) for channel in ImageStat.Stat(background_strip).mean[:3])
    canvas = Image.new("RGB", (size, size), color)
    canvas.paste(fitted, ((size - fitted.width) // 2, (size - fitted.height) // 2))
    return canvas


def rounded_alpha(image, radius_ratio=0.235):
    """Cut the supplied artwork's baked-in rounded corners for the in-app cards."""
    size = image.size[0]
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255
    )
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


def save(image, path):
    image.save(path, "PNG", optimize=True)
    print(f"{os.path.relpath(path, ROOT):60s} {os.path.getsize(path):>8d} B  {image.width}x{image.height}")


normal = load(os.path.join(SOURCE, "ff_normal.jpg"))
maximum = load(os.path.join(SOURCE, "ff_max.jpg"))
app_logo = load(os.path.join(SOURCE, "app_logo.jpg"))

for name, source in (("normal", normal), ("max", maximum)):
    game_icon = rounded_alpha(square(source, 192))
    save(game_icon, os.path.join(ASSETS, f"ic_game_{name}.png"))

for filename, size in (("Icon-60@2x.png", 120),
                       ("Icon-60@3x.png", 180),
                       ("Icon-1024.png", 1024)):
    save(fit_app_logo(app_logo, size), os.path.join(APPICON, filename))

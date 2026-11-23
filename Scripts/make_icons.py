#!/usr/bin/env python3
"""Generate every PNG asset FFPatch needs from the two source artworks.

Sources (already downloaded, see NOTICE.md for the origin of each):
    ff_normal_source.jpg              Garena Free Fire icon (user supplied)
    raw/ff_max_play_icon_512.png      Garena Free Fire MAX icon (Play Store)

Outputs:
    Resources/Assets/ic_game_normal*.png     64/128/192   in-app game cards
    Resources/Assets/ic_game_max*.png        64/128/192   in-app game cards
    Resources/Assets.xcassets/AppIcon.appiconset/*.png   home-screen icon
    Resources/Assets/app_icon_1024.png       preview
"""
import os
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASSETS = os.path.join(ROOT, "Resources", "Assets")
APPICON = os.path.join(ROOT, "Resources", "Assets.xcassets", "AppIcon.appiconset")

os.makedirs(ASSETS, exist_ok=True)
os.makedirs(APPICON, exist_ok=True)


def load(path):
    image = Image.open(path)
    image = image.convert("RGBA") if image.mode in ("RGBA", "LA", "P") else image.convert("RGB")
    return image


def square(image, size):
    """Cover-crop to a square, then resize with Lanczos."""
    width, height = image.size
    edge = min(width, height)
    left = (width - edge) // 2
    top = (height - edge) // 2
    image = image.crop((left, top, left + edge, top + edge))
    return image.resize((size, size), Image.LANCZOS)


def save(image, path):
    image.save(path, "PNG", optimize=True)
    print(f"{os.path.relpath(path, ROOT):60s} {os.path.getsize(path):>8d} B  {image.size[0]}x{image.size[1]}")


def rounded_alpha(image, radius_ratio=0.235):
    """Cut the artwork's baked-in white rounded corners to transparency so the
    in-app cornerRadius (and the mockups) never show white slivers."""
    from PIL import ImageDraw as _ImageDraw
    size = image.size[0]
    mask = Image.new("L", (size, size), 0)
    _ImageDraw.Draw(mask).rounded_rectangle(
        (0, 0, size - 1, size - 1), radius=int(size * radius_ratio), fill=255
    )
    result = image.convert("RGBA")
    result.putalpha(mask)
    return result


normal = load(os.path.join(ROOT, "ff_normal_source.jpg"))
maximum = load(os.path.join(ROOT, "raw", "ff_max_play_icon_512.png"))

normal_1024 = square(normal, 1024)
max_1024 = square(maximum, 1024)

# In-app game card icons: 64 pt → 1x/2x/3x
for name, base in (("normal", normal_1024), ("max", max_1024)):
    for suffix, size in (("", 64), ("@2x", 128), ("@3x", 192)):
        save(rounded_alpha(square(base, size)), os.path.join(ASSETS, f"ic_game_{name}{suffix}.png"))

save(normal_1024, os.path.join(ASSETS, "app_icon_1024.png"))

# Home-screen icon: the tool uses the Free Fire artwork so it reads as a
# companion app on the springboard.
app_icon_sizes = {
    "Icon-20@2x.png": 40, "Icon-20@3x.png": 60,
    "Icon-29@2x.png": 58, "Icon-29@3x.png": 87,
    "Icon-40@2x.png": 80, "Icon-40@3x.png": 120,
    "Icon-60@2x.png": 120, "Icon-60@3x.png": 180,
    "Icon-1024.png": 1024,
}
for filename, size in app_icon_sizes.items():
    save(square(normal_1024, size), os.path.join(APPICON, filename))

#!/usr/bin/env python3
"""FFPatch — render UI mockups (design reference, not a device screenshot).

Produces, at 2x of an 828x1792 logical screen:
    docs/images/mockup_home.png    FUNÇÕES screen
    docs/images/mockup_alert.png   same screen with the STATUS alert
    docs/images/mockup.png         both side by side

The pixels come from the same palette/metrics as Sources/UI/FFTheme.m, so the
mockup and the shipped UIKit code cannot drift without being visible here.
"""
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "images")
os.makedirs(OUT, exist_ok=True)

W, H = 828, 1792
BLACK = (0, 0, 0)
CARD = (28, 28, 30)
CARD2 = (44, 44, 46)
SEP = (58, 58, 60)
WHITE = (255, 255, 255)
GRAY = (142, 142, 147)
ACCENT = (226, 55, 68)
GREEN = (48, 209, 88)

FONT_DIR = r"C:\Windows\Fonts"
BOLD = os.path.join(FONT_DIR, "segoeuib.ttf")
SEMI = os.path.join(FONT_DIR, "seguisb.ttf")
REG = os.path.join(FONT_DIR, "segoeui.ttf")


def font(path, size):
    try:
        return ImageFont.truetype(path, size)
    except OSError:
        return ImageFont.load_default()


F_TITLE = font(BOLD, 44)
F_CARD = font(SEMI, 30)
F_SECTION = font(SEMI, 25)
F_ROW = font(SEMI, 34)
F_SUB = font(REG, 26)
F_TAB = font(SEMI, 22)
F_TINY = font(SEMI, 22)


def rounded(draw, box, radius, fill=None, outline=None, width=1):
    draw.rounded_rectangle(box, radius=radius, fill=fill, outline=outline, width=width)


def text_center(draw, cx, y, text, fnt, fill):
    width = draw.textlength(text, font=fnt)
    draw.text((cx - width / 2, y), text, font=fnt, fill=fill)


def toggle(draw, x, y, on=False):
    w, h = 102, 62
    rounded(draw, (x, y, x + w, y + h), h // 2, fill=ACCENT if on else (72, 72, 74))
    knob = 54
    kx = x + w - knob - 4 if on else x + 4
    draw.ellipse((kx, y + 4, kx + knob, y + 4 + knob), fill=WHITE)


def icon_image(name, size, radius):
    source = Image.open(os.path.join(ROOT, "Resources", "Assets", f"{name}.png")).convert("RGBA")
    source = source.resize((size, size), Image.LANCZOS)
    backdrop = Image.new("RGBA", (size, size), CARD + (255,))
    backdrop.alpha_composite(source)
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size, size), radius=radius, fill=255)
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(backdrop, (0, 0), mask)
    return icon


def draw_house(draw, cx, cy, color, size=46):
    half = size // 2
    draw.polygon(
        [(cx, cy - half - 2), (cx - half - 6, cy + 4), (cx + half + 6, cy + 4)], fill=color
    )
    draw.rectangle((cx - half + 8, cy + 2, cx + half - 8, cy + half - 2), fill=color)


def draw_person(draw, cx, cy, color, size=46):
    head = size // 4
    draw.ellipse((cx - head, cy - size // 2, cx + head, cy - size // 2 + 2 * head), fill=color)
    draw.rounded_rectangle(
        (cx - size // 2 + 4, cy + head - 4, cx + size // 2 - 4, cy + size // 2),
        radius=size // 3, fill=color
    )


def build_home(with_alert=False):
    image = Image.new("RGB", (W, H), BLACK)
    draw = ImageDraw.Draw(image)

    # status bar
    draw.text((64, 62), "17:59", font=font(SEMI, 34), fill=WHITE)
    bars = [(600, 106), (620, 96), (640, 86), (660, 76)]
    for x, top in bars:
        draw.rounded_rectangle((x, top, x + 12, 110), radius=3, fill=WHITE)
    draw.rounded_rectangle((700, 74, 790, 110), radius=9, outline=WHITE, width=3)
    draw.rectangle((706, 80, 762, 104), fill=WHITE)
    draw.rounded_rectangle((793, 84, 798, 100), radius=2, fill=WHITE)

    text_center(draw, W // 2, 176, "FUNÇÕES", F_TITLE, WHITE)

    # game cards
    cards = [("Free Fire Normal", "ic_game_normal", True), ("Free Fire Max", "ic_game_max", False)]
    card_w, card_h = 366, 236
    positions = [(46, 268), (416, 268)]
    for (label, icon, active), (x, y) in zip(cards, positions):
        rounded(draw, (x, y, x + card_w, y + card_h), 32, fill=CARD,
                outline=WHITE if active else CARD, width=3 if active else 1)
        icon = icon_image(icon, 128, 32)
        image.paste(icon, (x + card_w // 2 - 64, y + 28), icon)
        text_center(draw, x + card_w // 2, y + 172, label, F_CARD, WHITE)

    def section(y, title):
        draw.text((44, y), title, font=F_SECTION, fill=GRAY)
        return y + 44

    def group(y, rows, height):
        rounded(draw, (44, y, W - 44, y + height), 28, fill=CARD)
        cursor = y
        for index, (title, subtitle, on) in enumerate(rows):
            draw.text((76, cursor + 26), title, font=F_ROW, fill=WHITE)
            draw.text((76, cursor + 74), subtitle, font=F_SUB, fill=GRAY)
            toggle(draw, W - 44 - 16 - 102, cursor + 40, on)
            cursor += 140
            if index + 1 < len(rows):
                draw.rectangle((76, cursor - 1, W - 44, cursor), fill=SEP)
        return y + height

    aimbot = [
        ("HS ALTO", "HS Acima da Cabeça do Inimigo.", True),
        ("HS ALTO + PESCOÇO", "HS Acima da Cabeça e no Pescoço.", False),
        ("HS PESCOÇO", "HS Apenas no Pescoço do Inimigo.", False),
        ("HS CAVEIRA", "HS Abaixo do Pescoço do Inimigo.", False),
        ("HS PEITO", "HS no Peito do Inimigo.", False),
    ]
    hologram = [("HOLOGRAMA ARMAS", "Usar Gráfico no Padrão Para Funcionar.", False)]

    y = section(548, "FUNÇÕES DE AIMBOT")
    y = group(y, aimbot, 140 * len(aimbot)) + 46
    y = section(y, "FUNÇÕES DE HOLOGRAMA")
    y = group(y, hologram, 140)

    # tab bar
    tab_top = H - 150
    draw.rectangle((0, tab_top, W, H), fill=(10, 10, 10))
    draw.rectangle((0, tab_top, W, tab_top + 2), fill=(30, 30, 30))
    draw_house(draw, W // 4, tab_top + 52, WHITE)
    text_center(draw, W // 4, tab_top + 92, "Início", F_TAB, WHITE)
    draw_person(draw, 3 * W // 4, tab_top + 52, GRAY)
    text_center(draw, 3 * W // 4, tab_top + 92, "Perfil", F_TAB, GRAY)
    draw.rounded_rectangle((W // 2 - 90, H - 18, W // 2 + 90, H - 8), radius=6, fill=WHITE)

    if with_alert:
        overlay = Image.new("RGBA", (W, H), (0, 0, 0, 158))
        image = image.convert("RGBA")
        image.alpha_composite(overlay)
        draw = ImageDraw.Draw(image)
        card_w, card_h = 620, 560
        x = (W - card_w) // 2
        y = (H - card_h) // 2
        rounded(draw, (x, y, x + card_w, y + card_h), 44, fill=CARD2)
        # success glyph
        cy = y + 112
        draw.ellipse((W // 2 - 62, cy - 62, W // 2 + 62, cy + 62), fill=GREEN)
        draw.line(
            [(W // 2 - 26, cy + 2), (W // 2 - 6, cy + 24), (W // 2 + 30, cy - 24)],
            fill=WHITE, width=12, joint="curve"
        )
        text_center(draw, W // 2, cy + 82, "S T A T U S", font(SEMI, 23), GRAY)
        text_center(draw, W // 2, cy + 122, "INJETADO COM", font(BOLD, 36), WHITE)
        text_center(draw, W // 2, cy + 168, "SUCESSO", font(BOLD, 36), WHITE)
        text_center(draw, W // 2, cy + 236, "ID 0x1001 · HS ALTO", font(REG, 25), GRAY)
        text_center(draw, W // 2, cy + 272, "Free Fire Normal · 2 arquivos", font(REG, 25), GRAY)
        draw.rectangle((x, y + card_h - 104, x + card_w, y + card_h - 103), fill=SEP)
        text_center(draw, W // 2, y + card_h - 76, "FECHAR", font(SEMI, 33), WHITE)
        image = image.convert("RGB")

    return image


home = build_home(False)
alert = build_home(True)
home.save(os.path.join(OUT, "mockup_home.png"))
alert.save(os.path.join(OUT, "mockup_alert.png"))

combined = Image.new("RGB", (W * 2 + 60, H), (18, 18, 20))
combined.paste(home, (0, 0))
combined.paste(alert, (W + 60, 0))
combined.save(os.path.join(OUT, "mockup.png"))

for name in ("mockup_home.png", "mockup_alert.png", "mockup.png"):
    path = os.path.join(OUT, name)
    print(f"{name:22s} {os.path.getsize(path):>9d} B  {Image.open(path).size}")

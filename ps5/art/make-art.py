#!/usr/bin/env python3
"""Generate PS5 launcher art for Ship of Harkinian from the official SoH icon.

Outputs (next to this script):
  icon0.png            512x512 RGB launcher icon
  pic0-source.png      3840x2160 selection background (converted to pic0.dds)
  pic1-source.png      3840x2160 launch background   (converted to pic1.dds)
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = Path(__file__).resolve().parent
SRC = Image.open(HERE / "sohIcon-source.png").convert("RGBA")

# Blue tile of the macOS-style icon (rounded square with a transparent margin).
TILE = (102, 102, 922, 922)
SKY_TOP = (116, 153, 238)
SKY_BOTTOM = (104, 136, 214)
NIGHT = (14, 22, 48)

TITLE_FONT = "/usr/share/fonts/opentype/cantarell/Cantarell-Bold.otf"
BODY_FONT = "/usr/share/fonts/opentype/cantarell/Cantarell-Regular.otf"


def vertical_gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(h - 1, 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize((w, h))


def ship_only(fade_bottom=True):
    """The ship artwork with the rounded blue tile removed (transparent sky)."""
    tile = SRC.crop(TILE)
    r, g, b, a = tile.split()
    px = tile.load()
    mask = Image.new("L", tile.size, 0)
    mp = mask.load()
    for y in range(tile.height):
        for x in range(tile.width):
            pr, pg, pb, pa = px[x, y]
            # Sky pixels are saturated blue; keep everything else (sails, hull, flag).
            is_sky = pb > 180 and pb - pr > 70 and pb - pg > 30
            mp[x, y] = 0 if is_sky or pa < 16 else pa
    mask = mask.filter(ImageFilter.MinFilter(3)).filter(ImageFilter.GaussianBlur(1.2))
    # Drop the anti-aliased rim of the rounded tile, which the sky test misses.
    inset = Image.new("L", tile.size, 0)
    ImageDraw.Draw(inset).rounded_rectangle((14, 14, tile.width - 15, tile.height - 15), radius=170, fill=255)
    mask = Image.composite(mask, inset, inset)
    # The tile clips the hull flat; fade its bottom edge instead.
    fade = Image.new("L", tile.size, 255)
    if not fade_bottom:
        tile.putalpha(mask)
        return tile
    fd = ImageDraw.Draw(fade)
    for i in range(90):
        fd.line((0, tile.height - 1 - i, tile.width, tile.height - 1 - i), fill=round(255 * i / 90))
    mask = Image.composite(mask, Image.new("L", tile.size, 0), fade)
    tile.putalpha(mask)
    return tile


def make_icon():
    tile = SRC.crop(TILE)
    base = vertical_gradient(tile.size, SKY_TOP, SKY_BOTTOM).convert("RGBA")
    ship = ship_only(fade_bottom=False)
    base.alpha_composite(ship)
    base.convert("RGB").resize((512, 512), Image.LANCZOS).save(HERE / "icon0.png", optimize=True)


def make_background(name, ship_box, title_xy, title_size, subtitle, align="left"):
    W, H = 3840, 2160
    bg = vertical_gradient((W, H), SKY_TOP, NIGHT).convert("RGBA")

    # Soft light behind the ship.
    glow = Image.new("L", (W, H), 0)
    gx0, gy0, gx1, gy1 = ship_box
    pad = (gx1 - gx0) // 3
    ImageDraw.Draw(glow).ellipse((gx0 - pad, gy0 - pad, gx1 + pad, gy1 + pad), fill=110)
    glow = glow.filter(ImageFilter.GaussianBlur(220))
    bg.alpha_composite(Image.merge("RGBA", (
        Image.new("L", (W, H), 190), Image.new("L", (W, H), 210), Image.new("L", (W, H), 255), glow)))

    ship = ship_only().resize((gx1 - gx0, gy1 - gy0), Image.LANCZOS)
    shadow = Image.new("RGBA", ship.size, (0, 0, 0, 0))
    shadow.putalpha(ship.getchannel("A").point(lambda v: v * 0.45))
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    bg.alpha_composite(shadow, (gx0 + 30, gy0 + 40))
    bg.alpha_composite(ship, (gx0, gy0))

    draw = ImageDraw.Draw(bg)
    title = ImageFont.truetype(TITLE_FONT, title_size)
    body = ImageFont.truetype(BODY_FONT, round(title_size * 0.34))
    lines = [("Ship of", title), ("Harkinian", title)]
    x, y = title_xy
    for text, font in lines:
        tw = draw.textlength(text, font=font)
        tx = x - tw / 2 if align == "center" else x
        draw.text((tx + 8, y + 10), text, font=font, fill=(0, 0, 0, 120))
        draw.text((tx, y), text, font=font, fill=(255, 255, 255, 255))
        y += round(title_size * 1.02)
    y += round(title_size * 0.18)
    tw = draw.textlength(subtitle, font=body)
    tx = x - tw / 2 if align == "center" else x
    draw.text((tx, y), subtitle, font=body, fill=(214, 226, 255, 235))

    bg.convert("RGB").save(HERE / name, optimize=True)


if __name__ == "__main__":
    make_icon()
    # Selection background: ship on the right, title on the left.
    make_background("pic0-source.png", (2120, 330, 3700, 1910), (260, 640), 300,
                    "The Legend of Zelda: Ocarina of Time  ·  PS5")
    # Launch background: ship centred above the title.
    make_background("pic1-source.png", (1420, 150, 2420, 1150), (1920, 1230), 250,
                    "The Legend of Zelda: Ocarina of Time", align="center")
    print("ok")

#!/usr/bin/env python3
"""Build a small SoH O2R with Kenney's CC0 PlayStation prompts.

Requires Pillow. Reads texture dimensions from the user's oot.o2r; no game pixels
are copied. Layout: Cross=A, Circle=B, L1=L, R2=R, L2=Z, right stick=C.
"""
import argparse
import io
import struct
import urllib.parse
import urllib.request
import zipfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

REVISION = "49f37cc4e74fa661382f9752567924a8109b6568"
BASE = f"https://raw.githubusercontent.com/tanuki-billie/kenney-input-prompts/{REVISION}/"
ICONS = "addons/kenney_input_prompts/PlayStation Series/Double/"
MAPPING = {
    "nes_font_static/gMsgChar9FButtonATex": "playstation_button_cross",
    "nes_font_static/gMsgCharA0ButtonBTex": "playstation_button_circle",
    "nes_font_static/gMsgCharA1ButtonCTex": "playstation_stick_r",
    "nes_font_static/gMsgCharA2ButtonLTex": "playstation_trigger_l1",
    "nes_font_static/gMsgCharA3ButtonRTex": "playstation_trigger_r2",
    "nes_font_static/gMsgCharA4ButtonZTex": "playstation_trigger_l2",
    "nes_font_static/gMsgCharA5ButtonCUpTex": "playstation_stick_r_up",
    "nes_font_static/gMsgCharA6ButtonCDownTex": "playstation_stick_r_down",
    "nes_font_static/gMsgCharA7ButtonCLeftTex": "playstation_stick_r_left",
    "nes_font_static/gMsgCharA8ButtonCRightTex": "playstation_stick_r_right",
    "nes_font_static/gMsgCharAAControlStickTex": "playstation_stick_l",
    "nes_font_static/gMsgCharABControlPadTex": "playstation_dpad",
    "icon_item_static/gABtnSymbolTex": "playstation_button_cross",
    "icon_item_static/gBBtnSymbolTex": "playstation_button_circle",
    "icon_item_static/gLButtonTex": "playstation_trigger_l1",
    "icon_item_static/gRButtonTex": "playstation_trigger_r2",
    "parameter_static/gOcarinaBtnIconATex": "playstation_button_cross",
    "parameter_static/gOcarinaBtnIconCUpTex": "playstation_stick_r_up",
    "parameter_static/gOcarinaBtnIconCDownTex": "playstation_stick_r_down",
    "parameter_static/gOcarinaBtnIconCLeftTex": "playstation_stick_r_left",
    "parameter_static/gOcarinaBtnIconCRightTex": "playstation_stick_r_right",
    "parameter_static/gEmptyCLeftArrowTex": "playstation_stick_r_left",
    "parameter_static/gEmptyCDownArrowTex": "playstation_stick_r_down",
    "parameter_static/gEmptyCRightArrowTex": "playstation_stick_r_right",
}


def download(name, cache):
    path = cache / Path(name).name
    if not path.exists():
        request = urllib.request.Request(BASE + urllib.parse.quote(name), headers={"User-Agent": "oot64-ps5"})
        with urllib.request.urlopen(request, timeout=30) as response:
            path.write_bytes(response.read())
    return path.read_bytes()


def icon(name, cache, size):
    image = Image.open(io.BytesIO(download(ICONS + name + ".png", cache))).convert("RGBA")
    image = image.crop(image.getbbox())
    image.thumbnail((max(1, int(size[0] * .9)), max(1, int(size[1] * .9))), Image.Resampling.LANCZOS)
    result = Image.new("RGBA", size)
    result.alpha_composite(image, ((size[0] - image.width) // 2, (size[1] - image.height) // 2))
    return result


def dimensions(archive, name):
    try:
        data = archive.read("textures/" + name)
    except KeyError:
        return None
    if len(data) < 80 or data[0] != 0 or struct.unpack_from("<I", data, 4)[0] != 0x4F544558:
        raise ValueError("Unsupported texture header: " + name)
    return struct.unpack_from("<III", data, 64)


def resource(image, kind, original):
    header = bytearray(64)
    struct.pack_into("<BBHIIQ", header, 0, 0, 1, 0, 0x4F544558, 1, 0)
    data = image.tobytes()
    # Raw replacement pixels are RGBA32 even when the original display list
    # loads I4/IA8. HByteScale scales bytes, not texel width (IA8 -> RGBA is 4x).
    bits_per_pixel = {1: 32, 2: 16, 3: 4, 4: 8, 5: 4, 6: 8, 7: 4, 8: 8, 9: 16}[kind]
    return bytes(header) + struct.pack("<IIIIffI", kind, image.width, image.height, 1,
                                       image.width / original[0] * 32 / bits_per_pixel,
                                       image.height / original[1], len(data)) + data


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("oot", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--cache", type=Path, required=True)
    parser.add_argument("--camera-controls", action="store_true",
                        help="Keep native C-button arrows for D-pad controls; replace other prompts")
    args = parser.parse_args()
    args.cache.mkdir(parents=True, exist_ok=True)
    license_text = download("LICENSE.txt", args.cache)
    previews = []
    with zipfile.ZipFile(args.oot) as base, zipfile.ZipFile(args.output, "w", zipfile.ZIP_DEFLATED) as out:
        mappings = dict(MAPPING)
        mappings["icon_item_static/gCBtnSymbolsTex"] = ["playstation_stick_r_left", "playstation_stick_r_down",
                                                       "playstation_stick_r_right"]
        if args.camera_controls:
            mappings = {name: symbols for name, symbols in mappings.items()
                        if not any("playstation_stick_r" in symbol for symbol in
                                   (symbols if isinstance(symbols, list) else [symbols]))}
        for name, symbols in mappings.items():
            spec = dimensions(base, name)
            if spec is None:
                print(f"Skipping texture absent from this ROM: {name}")
                continue
            kind, w, h = spec
            size = (w * 8, h * 8)
            if isinstance(symbols, list):
                image = Image.new("RGBA", size)
                cell = (size[0] // len(symbols), size[1])
                for i, symbol in enumerate(symbols):
                    image.alpha_composite(icon(symbol, args.cache, cell), (i * cell[0], 0))
            else:
                image = icon(symbols, args.cache, size)
            out.writestr("alt/textures/" + name, resource(image, kind, (w, h)))
            previews.append((name.rsplit("/", 1)[-1], image))
        # An explicit controls line avoids the hard-coded A/B letters at file select.
        name = "title_static/gFileSelControlsENGTex"
        kind, w, h = dimensions(base, name)
        image = Image.new("RGBA", (w * 8, h * 8))
        entries = [("playstation_stick_l", "Select"), ("playstation_button_cross", "Confirm"),
                   ("playstation_button_circle", "Back")]
        font = ImageFont.load_default(size=max(12, h * 3))
        cell = image.width // len(entries)
        for i, (symbol, label) in enumerate(entries):
            image.alpha_composite(icon(symbol, args.cache, (image.height, image.height)), (i * cell, 0))
            ImageDraw.Draw(image).text((i * cell + image.height, image.height // 2), label,
                                       font=font, fill="white", anchor="lm")
        out.writestr("alt/textures/" + name, resource(image, kind, (w, h)))
        out.writestr("playstation-prompts/LICENSE.txt", license_text)
    sheet = Image.new("RGB", (900, ((len(previews) + 2) // 3) * 120), "#454545")
    for i, (name, image) in enumerate(previews):
        image.thumbnail((280, 88))
        x, y = i % 3 * 300, i // 3 * 120
        sheet.paste(image, (x, y), image)
        ImageDraw.Draw(sheet).text((x, y + 90), name, fill="white")
    sheet.save(args.output.with_suffix(".png"))
    print(f"Wrote {args.output} ({args.output.stat().st_size:,} bytes), {len(previews)+1} prompt textures")


if __name__ == "__main__":
    main()

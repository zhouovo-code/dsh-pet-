"""Icons v2: proper face framing (avatar as-is, sleepy face located by skin tone)."""
from pathlib import Path
from PIL import Image, ImageDraw, ImageEnhance

OUT = Path(r"C:\Users\l\Desktop\dsh-pet\assets")
SIZES = [(256, 256), (128, 128), (64, 64), (48, 48), (32, 32), (16, 16)]
ACCENT = (122, 172, 255)
RED = (236, 96, 96)


def rounded(img, ratio=0.24):
    w, h = img.size
    mask = Image.new("L", (w * 4, h * 4), 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, w * 4 - 1, h * 4 - 1], radius=int(w * 4 * ratio), fill=255)
    mask = mask.resize((w, h), Image.LANCZOS)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


def square_around(img, cx, cy, side, bg=(30, 44, 84)):
    side = int(side)
    box = (int(cx - side / 2), int(cy - side / 2), int(cx + side / 2), int(cy + side / 2))
    pad = Image.new("RGBA", (side, side), (0, 0, 0, 0))
    crop = img.crop(box)
    pad.paste(crop, ((side - crop.width) // 2, (side - crop.height) // 2), crop)
    tile = Image.new("RGBA", (side, side), bg + (255,))
    tile.paste(pad, (0, 0), pad)
    return tile


def skin_box(img):
    px = img.load()
    w, h = img.size
    x0 = y0 = 10 ** 9
    x1 = y1 = -1
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b, a = px[x, y]
            if a > 200 and r > 215 and g > 170 and b > 150 and r > g + 12 and g > b + 6:
                x0 = min(x0, x); x1 = max(x1, x)
                y0 = min(y0, y); y1 = max(y1, y)
    return x0, y0, x1, y1


def badge(img, kind):
    d = ImageDraw.Draw(img)
    s = img.width
    r = int(s * 0.175)
    pad = int(s * 0.045)
    cx, cy = s - pad - r, s - pad - r
    d.ellipse([cx - r * 1.12, cy - r * 1.12, cx + r * 1.12, cy + r * 1.12], fill=(14, 17, 28, 240))
    d.ellipse([cx - r, cy - r, cx + r, cy + r], fill=ACCENT if kind == "on" else RED)
    lw = max(2, int(r * 0.26))
    if kind == "on":
        d.line([(cx - r * 0.44, cy + r * 0.02), (cx - r * 0.10, cy + r * 0.38)], fill=(14, 17, 28), width=lw)
        d.line([(cx - r * 0.10, cy + r * 0.38), (cx + r * 0.48, cy - r * 0.40)], fill=(14, 17, 28), width=lw)
    else:
        d.line([(cx - r * 0.40, cy - r * 0.40), (cx + r * 0.40, cy + r * 0.40)], fill=(255, 255, 255), width=lw)
        d.line([(cx + r * 0.40, cy - r * 0.40), (cx - r * 0.40, cy + r * 0.40)], fill=(255, 255, 255), width=lw)


def main():
    # start: locate her face in the main drawing (the avatar asset is too tight)
    full = Image.open(OUT / "pet20-full.png").convert("RGBA")
    fx0, fy0, fx1, fy1 = skin_box(full)
    ffw = fx1 - fx0
    start = square_around(full, (fx0 + fx1) / 2, (fy0 + fy1) / 2 + ffw * 0.16, ffw * 2.15)
    start = rounded(start)
    badge(start, "on")

    # stop: locate the sleepy face by skin tone
    sl = Image.open(OUT / "pet20-sleepy.png").convert("RGBA")
    x0, y0, x1, y1 = skin_box(sl)
    fw = x1 - x0
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    sleepy = square_around(sl, cx, cy + fw * 0.05, fw * 2.0, (26, 34, 62))
    sleepy = ImageEnhance.Brightness(sleepy).enhance(0.78)
    sleepy = ImageEnhance.Color(sleepy).enhance(0.7)
    sleepy = rounded(sleepy)
    badge(sleepy, "off")

    for name, img in (("icon-start.ico", start), ("icon-stop.ico", sleepy)):
        img.save(OUT / name, sizes=SIZES)
        img.resize((256, 256), Image.LANCZOS).save(OUT / name.replace(".ico", "-preview.png"))
        print(name, round((OUT / name).stat().st_size / 1024, 1), "KB")

    strip = Image.new("RGB", (256 * 2 + 24, 256), (40, 44, 56))
    for i, n in enumerate(("icon-start-preview.png", "icon-stop-preview.png")):
        im = Image.open(OUT / n).convert("RGBA")
        strip.paste(im, (i * 280, 0), im)
    strip.save(OUT / "_icons-preview.png")
    print("preview rebuilt; start face =", (fx0, fy0, fx1, fy1), "sleepy face =", (x0, y0, x1, y1))


if __name__ == "__main__":
    main()

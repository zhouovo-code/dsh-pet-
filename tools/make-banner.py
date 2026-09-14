"""README banner: text block on the left, the four expressions tiled on the right."""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(r"C:\Users\l\Desktop\dsh-pet\assets")
W, H = 1600, 520
BG_TOP, BG_BOTTOM = (16, 20, 34), (28, 38, 70)
ACCENT = (122, 172, 255)
TEXT = (238, 242, 252)
MUTED = (152, 166, 198)


def font(size: int, bold: bool = False):
    for name in (("msyhbd.ttc", "msyh.ttc") if bold else ("msyh.ttc", "msyhbd.ttc")):
        p = Path(r"C:\Windows\Fonts") / name
        if p.exists():
            try:
                return ImageFont.truetype(str(p), size)
            except OSError:
                continue
    return ImageFont.load_default()


def gradient() -> Image.Image:
    img = Image.new("RGB", (W, H))
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / (H - 1)
        d.line([(0, y), (W, y)], fill=tuple(round(BG_TOP[i] + (BG_BOTTOM[i] - BG_TOP[i]) * t) for i in range(3)))
    return img


def main() -> None:
    img = gradient()

    # soft blue glow behind the characters (right half)
    overlay = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    od = ImageDraw.Draw(overlay)
    od.ellipse([W * 0.42, H * 0.05, W * 1.05, H * 0.98], fill=(90, 140, 255, 58))
    overlay = overlay.filter(ImageFilter.GaussianBlur(85))
    img = Image.alpha_composite(img.convert("RGBA"), overlay).convert("RGB")

    # ---- sprites: crop to content, tile from the right ----
    names = ["pet20-full.png", "pet20-panic.png", "pet20-sleepy.png", "pet22-shy.png"]
    tiles = []
    for n in names:
        s = Image.open(OUT / n).convert("RGBA")
        box = s.getchannel("A").getbbox()
        s = s.crop(box)
        h = 372
        tiles.append(s.resize((round(s.width * h / s.height), h), Image.LANCZOS))

    # fit the row into the free area right of the text block
    AVAIL = 820
    gap = -22
    total = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    if total > AVAIL:
        k = AVAIL / total
        tiles = [t.resize((max(1, round(t.width * k)), max(1, round(t.height * k))), Image.LANCZOS) for t in tiles]
        total = sum(t.width for t in tiles) + gap * (len(tiles) - 1)
    x = W - 30 - total
    for t in tiles:
        img.paste(t, (round(x), H - 384), t)
        x += t.width + gap

    # ---- text ----
    d = ImageDraw.Draw(img)
    d.text((64, 78), "dsh-pet", font=font(92, True), fill=TEXT)
    d.text((68, 192), "看板娘余额挂件", font=font(44, True), fill=ACCENT)
    d.text((68, 256), "浮在 DSH Web GUI 上的桌面宠物", font=font(28), fill=TEXT)
    d.text((68, 298), "DeepSeek 余额 · 今日用量 · 可点击抚摸 · 四种表情", font=font(23), fill=MUTED)

    cx, cy = 68, 366
    for label in ["一键安装", "免构建", "纯本地", "MIT 许可"]:
        f = font(21, True)
        tw = d.textlength(label, font=f)
        d.rounded_rectangle([cx, cy, cx + tw + 36, cy + 42], radius=21, fill=(36, 50, 90), outline=(72, 100, 156), width=2)
        d.text((cx + 18, cy + 9), label, font=f, fill=ACCENT)
        cx += tw + 50

    d.rectangle([0, H - 3, W, H], fill=ACCENT)
    img.save(OUT / "banner.png", optimize=True)
    print("banner.png", img.size, round((OUT / "banner.png").stat().st_size / 1024), "KB")


if __name__ == "__main__":
    main()

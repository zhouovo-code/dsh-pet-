"""Move every sprite back onto the compact 1440x1199 canvas.

The 1920 canvas only existed to fit the shy drawing at its earlier size; at the
current size its content ends at x=1062, so the compact canvas fits all four and
the widget stops looking stretched.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image  # noqa: E402

import split_expressions as se  # noqa: E402

W, H = 1440, 1199
MAP = {
    "pet17-full.png": "pet20-full.png",
    "pet17-panic.png": "pet20-panic.png",
    "pet17-sleepy.png": "pet20-sleepy.png",
    "pet19-shy.png": "pet20-shy.png",
    "pet17-avatar.png": "pet20-avatar.png",
}


def main() -> None:
    for src, dst in MAP.items():
        img = Image.open(se.OUT / src).convert("RGBA")
        if img.size == (220, 220):                     # avatar, just rename
            img.save(se.OUT / dst)
            print(f"{src} -> {dst} (kept {img.size})")
            continue
        matte = se.matte_of(img)
        box = se.bbox_of(matte)
        if box[2] > W or box[3] > H:
            raise SystemExit(f"{src} content {box} does not fit {W}x{H}")
        cropped = img.crop((0, 0, W, H))
        cropped.save(se.OUT / dst)
        print(f"{src} {img.size} content {box} -> {dst} {cropped.size}")

    panels = []
    for n in ("pet20-full.png", "pet20-panic.png", "pet20-sleepy.png", "pet20-shy.png"):
        img = Image.open(se.OUT / n).convert("RGBA").resize((200, 167), Image.LANCZOS)
        t = Image.new("RGB", (200, 167), (240, 243, 249))
        t.paste(img, (0, 0), img)
        panels.append(t)
    strip = Image.new("RGB", (208 * len(panels), 167), (200, 60, 60))
    for i, t in enumerate(panels):
        strip.paste(t, (208 * i, 0))
    strip.save(se.OUT / "previews-all.png")
    print("previews-all.png rebuilt at the compact 200x167 display size")


if __name__ == "__main__":
    main()

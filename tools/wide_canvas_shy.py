"""Fit the wide shy drawing by widening the shared canvas.

The new shy drawing is 1231px wide of content (it includes the tail) against
597px for the sheet version, so no placement can keep her head aligned and the
tail inside a 1440px canvas. Widening the canvas to 1920 and growing the client's
sprite box by the same ratio keeps every expression at its current on-screen size.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image  # noqa: E402

import split_expressions as se  # noqa: E402

NEW_SHY = Path(r"C:\Users\l\.dsh\attachments\v1\objects\77\77c5854dfda18f2ec298a6e5acb6a0b75b9c94e03612af60f9babed8842ef61a")
CANVAS = (1920, 1199)
se.CANVAS = CANVAS          # place() reads the module constant, so keep them in sync
SHY_SCALE = 1.182          # the size that matched the previous shy drawing
PAD = ("pet8-full.png", "pet8-panic.png", "pet14-sleepy.png")


def main() -> None:
    # 1) pad the existing sprites onto the wider canvas (no resampling: bit-exact)
    for name in PAD:
        img = se.load_rgba(se.OUT / name)
        wider = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        wider.alpha_composite(img, (0, 0))
        wider.save(se.OUT / name)
        print(f"padded {name} {img.size} -> {wider.size}")

    # 2) place the new shy drawing: head aligned, whole pose inside
    new = se.load_rgba(NEW_SHY)
    matte = se.matte_of(new)
    box = se.bbox_of(matte)
    target = se.load_rgba(se.OUT / "pet8-full.png")     # any padded sprite = same canvas
    tf = se.frill_anchor(target, se.matte_of(target), se.bbox_of(se.matte_of(target)))
    nf = se.frill_anchor(new, matte, box)
    scale = SHY_SCALE
    want_x = (tf[0] + tf[2]) / 2 - (nf[0] + nf[2]) / 2 * scale
    want_y = (tf[1] + tf[3]) / 2 - (nf[1] + nf[3]) / 2 * scale

    # keep the visible content inside the canvas, staying as close to that as possible
    min_x = -box[0] * scale
    max_x = CANVAS[0] - box[2] * scale
    min_y = -box[1] * scale
    max_y = CANVAS[1] - box[3] * scale
    if min_x > max_x:
        raise SystemExit(f"drawing {box} cannot fit: needs {(box[2]-box[0])*scale:.0f}px, canvas {CANVAS[0]}")
    offx = max(min_x, min(max_x, want_x))
    offy = max(min_y, min(max_y, want_y))
    print(f"content {box} scale {scale} -> off=({offx:.0f},{offy:.0f}) "
          f"head shift=({offx - want_x:+.0f},{offy - want_y:+.0f})px")

    out = se.place(new, matte, scale, offx, offy)
    out.save(se.OUT / "pet16-shy.png")

    # "nothing was clipped" == the placed content is the same size as the scaled
    # content; touching a canvas edge is fine when the missing part is only the
    # drawing's own transparent margin.
    placed = se.bbox_of(se.matte_of(out))
    exp_w = (box[2] - box[0]) * scale
    exp_h = (box[3] - box[1]) * scale
    got_w = placed[2] - placed[0]
    got_h = placed[3] - placed[1]
    fits = abs(got_w - exp_w) <= 6 and abs(got_h - exp_h) <= 6 and placed[2] <= CANVAS[0] and placed[3] <= CANVAS[1]
    print(f"placed content {placed} size {got_w}x{got_h} expected {exp_w:.0f}x{exp_h:.0f} -> intact: {fits}")
    if not fits:
        raise SystemExit("WARNING: drawing was clipped")

    # 3) review strip at true display scale (box 264 wide == canvas 1920)
    names = ["pet8-full.png", "pet8-panic.png", "pet14-sleepy.png", "pet16-shy.png"]
    tiles = []
    for n in names:
        img = Image.open(se.OUT / n).convert("RGBA").resize((264, 165), Image.LANCZOS)
        t = Image.new("RGB", (264, 165), (240, 243, 249))
        t.paste(img, (0, 0), img)
        tiles.append(t)
    strip = Image.new("RGB", (272 * len(tiles), 165), (200, 60, 60))
    for i, t in enumerate(tiles):
        strip.paste(t, (272 * i, 0))
    strip.save(se.OUT / "previews-all.png")
    print("previews-all.png rebuilt (true display scale): 常态 | 慌张 | 偷懒 | 害羞")


if __name__ == "__main__":
    main()

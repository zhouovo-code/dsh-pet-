"""Place the shy drawing at an absolute scale, anchored to the main sprite.

Needs no previous shy file: the head anchor comes from pet17-full.png, so the
face lands exactly where the other expressions keep theirs.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image  # noqa: E402

import split_expressions as se  # noqa: E402
from update_shy import NEW, matte_auto  # noqa: E402

REF = se.OUT / "pet20-full.png"
OUTPATH = se.OUT / "pet22-shy.png"


def main(scale: float) -> None:
    ref = se.load_rgba(REF)
    ref_matte = se.matte_of(ref)
    ref_box = se.bbox_of(ref_matte)
    ref_frill = se.frill_anchor(ref, ref_matte, ref_box)

    new = se.load_rgba(NEW)
    new_matte = matte_auto(new)
    new_box = se.bbox_of(new_matte)
    new_frill = se.frill_anchor(new, new_matte, new_box)

    want_x = (ref_frill[0] + ref_frill[2]) / 2 - (new_frill[0] + new_frill[2]) / 2 * scale
    want_y = (ref_frill[1] + ref_frill[3]) / 2 - (new_frill[1] + new_frill[3]) / 2 * scale

    min_x, max_x = -new_box[0] * scale, se.CANVAS[0] - new_box[2] * scale
    min_y, max_y = -new_box[1] * scale, se.CANVAS[1] - new_box[3] * scale
    offx = max(min_x, min(max_x, want_x))
    offy = max(min_y, min(max_y, want_y))
    print(f"ref frill {ref_frill} | new frill {new_frill} | scale {scale}")
    print(f"off=({offx:.0f},{offy:.0f}) head shift=({offx-want_x:+.0f},{offy-want_y:+.0f})px")

    out = se.place(new, new_matte, scale, offx, offy)
    out.save(OUTPATH)

    placed = se.bbox_of(se.matte_of(out))
    exp_w = (new_box[2] - new_box[0]) * scale
    exp_h = (new_box[3] - new_box[1]) * scale
    got_w, got_h = placed[2] - placed[0], placed[3] - placed[1]
    print(f"placed {placed} {got_w}x{got_h} expected {exp_w:.0f}x{exp_h:.0f}")
    if abs(got_w - exp_w) > 6 or abs(got_h - exp_h) > 6:
        raise SystemExit("WARNING: drawing was clipped")

    # preview against the other expressions at true display size
    panels = []
    for n in ("pet20-full.png", "pet20-panic.png", "pet20-sleepy.png", "pet22-shy.png"):
        img = Image.open(se.OUT / n).convert("RGBA").resize((264, 165), Image.LANCZOS)
        t = Image.new("RGB", (264, 165), (240, 243, 249))
        t.paste(img, (0, 0), img)
        panels.append(t)
    strip = Image.new("RGB", (272 * len(panels), 165), (200, 60, 60))
    for i, t in enumerate(panels):
        strip.paste(t, (272 * i, 0))
    strip.save(se.OUT / "previews-all.png")
    print("previews-all.png rebuilt")


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 0.935)

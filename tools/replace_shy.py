"""Swap in a sharper shy drawing without changing its on-screen size.

The new drawing is aligned against the *current* shy sprite (same pose, same
lighting), so the headdress measurement bias cancels out and the size stays put.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image  # noqa: E402

import split_expressions as se  # noqa: E402

NEW_SHY = Path(r"C:\Users\l\.dsh\attachments\v1\objects\77\77c5854dfda18f2ec298a6e5acb6a0b75b9c94e03612af60f9babed8842ef61a")
CURRENT = se.OUT / "pet12-shy.png"     # size reference (the shipped shy sprite)
OUTPATH = se.OUT / "pet15-shy.png"     # fresh name so the browser refetches


def frill(img: Image.Image):
    matte = se.matte_of(img)
    return se.frill_anchor(img, matte, se.bbox_of(matte))


def main(factor: float = 1.12) -> None:
    current = se.load_rgba(CURRENT)
    new = se.load_rgba(NEW_SHY)
    print(f"current shy {current.size}, new drawing {new.size}")

    cf = frill(current)
    nf = frill(new)
    cw = cf[2] - cf[0]
    nw = nf[2] - nf[0]
    scale = (cw / nw) * factor   # the frill measures wider on the new drawing, so it needs a nudge
    offx = (cf[0] + cf[2]) / 2 - (nf[0] + nf[2]) / 2 * scale
    offy = (cf[1] + cf[3]) / 2 - (nf[1] + nf[3]) / 2 * scale
    # keep the whole drawing inside the canvas
    offx = max(0.0, min(offx, se.CANVAS[0] - new.width * scale))
    offy = max(0.0, min(offy, se.CANVAS[1] - new.height * scale))
    print(f"target frill {cw}px, new frill {nw}px -> scale={scale:.4f} off=({offx:.0f},{offy:.0f})")

    out = se.place(new, se.matte_of(new), scale, offx, offy)
    out.save(OUTPATH)

    # A drawing wider than the canvas silently loses its right edge, which is
    # exactly how the flustered tail got cut before: always verify afterwards.
    box = se.bbox_of(se.matte_of(out))
    ok_w = box[2] < se.CANVAS[0] - 2
    ok_h = box[3] < se.CANVAS[1] - 2
    print(f"placed at {box} canvas {se.CANVAS} -> fits: width={ok_w} height={ok_h}")
    if not (ok_w and ok_h):
        raise SystemExit("WARNING: drawing touches the canvas edge and would be clipped")
    print("wrote", OUTPATH.name, round(OUTPATH.stat().st_size / 1024), "KB")

    # review strip: reference | previous shy | new shy | sleepy
    names = ["pet8-full.png", "pet14-shy.png", "pet15-shy.png", "pet14-sleepy.png"]
    tiles = []
    for n in names:
        img = Image.open(se.OUT / n).convert("RGBA").resize((340, 283), Image.LANCZOS)
        tile = Image.new("RGB", (340, 283), (240, 243, 249))
        tile.paste(img, (0, 0), img)
        tiles.append(tile)
    strip = Image.new("RGB", (348 * len(tiles), 283), (200, 60, 60))
    for i, t in enumerate(tiles):
        strip.paste(t, (348 * i, 0))
    strip.save(se.OUT / "_strip-shy.png")
    print("strip: ref | old shy | new shy | sleepy")


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 1.12)

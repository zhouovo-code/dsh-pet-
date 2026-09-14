"""Look for a baked-in white halo along each sprite's silhouette.

Renders, for every expression, a 3x crop of the head-area silhouette over a dark
background: a matte fringe shows up immediately as a pale rim.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image  # noqa: E402

import split_expressions as se  # noqa: E402

NAMES = ["pet17-full.png", "pet17-panic.png", "pet17-sleepy.png", "pet17-shy.png"]
CROP = 420
SCALE = 2
CELL = CROP * SCALE


def main() -> None:
    tiles = []
    for name in NAMES:
        img = se.load_rgba(se.OUT / name)
        matte = se.matte_of(img)
        box = se.bbox_of(matte)
        # top-left corner of the visible content = head/hair silhouette
        crop = img.crop((box[0], box[1], box[0] + CROP, box[1] + CROP)).resize((CELL, CELL), Image.LANCZOS)
        tile = Image.new("RGB", (CELL, CELL), (26, 28, 36))       # dark backdrop
        tile.paste(crop, (0, 0), crop)

        # measure pale fringe: opaque-ish pixels that are nearly white, sitting on
        # the outer side of the silhouette
        px = img.load()
        mx = matte.load()
        pale = 0
        for y in range(box[1], min(img.height, box[1] + CROP)):
            for x in range(box[0], min(img.width, box[0] + CROP)):
                if mx[x, y] > 180:
                    r, g, b, _ = px[x, y]
                    if min(r, g, b) > 235:
                        pale += 1
        print(f"{name:18s} bbox={box} pale opaque pixels in head crop: {pale}")
        tiles.append(tile)

    strip = Image.new("RGB", (CELL * len(tiles) + 8 * (len(tiles) - 1), CELL), (200, 60, 60))
    x = 0
    for t in tiles:
        strip.paste(t, (x, 0))
        x += CELL + 8
    strip.save(se.OUT / "_halo-check.png")
    print("saved _halo-check.png (2x crops over a dark background)")


if __name__ == "__main__":
    main()

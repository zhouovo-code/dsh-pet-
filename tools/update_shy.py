"""Swap in a new shy drawing that ships as a black-background JPEG.

Black keying needs its own flood fill (the art's dress is dark navy, so the
threshold is tight), plus a 1px matte erosion and a soft blur to kill the JPEG
edge halo. Size and head placement follow the current shy sprite.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
from PIL import Image, ImageFilter  # noqa: E402

import split_expressions as se  # noqa: E402

NEW = Path(r"C:\Users\l\.dsh\attachments\v1\objects\cb\cba5cee2784b850843babbcb08754443bb7da274019b5413cf480a2662b036ce")
CURRENT = se.OUT / "pet18-shy.png"      # size + head reference
OUTPATH = se.OUT / "pet19-shy.png"
ERODE = 2


def matte_auto(img: Image.Image) -> Image.Image:
    """alpha if the file carries one, else key the border colour (white or black)"""
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo < 250 and (hi - lo) > 40:
        data = alpha.load()
        for y in range(img.height):
            for x in range(img.width):
                a = data[x, y]
                data[x, y] = 0 if a <= 4 else (255 if a >= 249 else a)
        return alpha

    px = img.load()
    w, h = img.size
    corners = [px[0, 0], px[w - 1, 0], px[0, h - 1], px[w - 1, h - 1]]
    avg = [sum(c[i] for c in corners) / len(corners) for i in range(3)]
    dark = max(avg) < 60
    print(f"no alpha -> keying border rgb~{tuple(round(v) for v in avg)} ({'black' if dark else 'white'})")

    def is_bg(x, y):
        r, g, b, _ = px[x, y]
        if dark:
            return max(r, g, b) < 42
        return min(r, g, b) >= 230 and (max(r, g, b) - min(r, g, b)) <= 28

    from collections import deque
    outside = bytearray(w * h)
    queue = deque()
    for x in range(w):
        for y in (0, h - 1):
            if is_bg(x, y) and not outside[y * w + x]:
                outside[y * w + x] = 1
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_bg(x, y) and not outside[y * w + x]:
                outside[y * w + x] = 1
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[ny * w + nx] and is_bg(nx, ny):
                outside[ny * w + nx] = 1
                queue.append((nx, ny))
    mask = Image.frombytes("L", (w, h), bytes(0 if v else 255 for v in outside))
    if ERODE:
        mask = mask.filter(ImageFilter.MinFilter(3))         # pull 1px inside the outline
    return mask.filter(ImageFilter.GaussianBlur(0.7))        # soften the keyed edge


def main(factor: float = 1.0) -> None:
    cur = se.load_rgba(CURRENT)
    new = se.load_rgba(NEW)
    cm = se.matte_of(cur)
    nm = matte_auto(new)
    cb, nb = se.bbox_of(cm), se.bbox_of(nm)
    print(f"current shy {cur.size} content {cb}; new drawing {new.size} content {nb}")

    cf = se.frill_anchor(cur, cm, cb)
    nf = se.frill_anchor(new, nm, nb)
    scale = ((cf[2] - cf[0]) / (nf[2] - nf[0])) * factor
    want_x = (cf[0] + cf[2]) / 2 - (nf[0] + nf[2]) / 2 * scale
    want_y = (cf[1] + cf[3]) / 2 - (nf[1] + nf[3]) / 2 * scale

    min_x, max_x = -nb[0] * scale, se.CANVAS[0] - nb[2] * scale
    min_y, max_y = -nb[1] * scale, se.CANVAS[1] - nb[3] * scale
    offx = max(min_x, min(max_x, want_x))
    offy = max(min_y, min(max_y, want_y))
    print(f"scale={scale:.4f} off=({offx:.0f},{offy:.0f}) head shift=({offx-want_x:+.0f},{offy-want_y:+.0f})px")

    out = se.place(new, nm, scale, offx, offy)
    out.save(OUTPATH)

    placed = se.bbox_of(se.matte_of(out))
    exp_w = (nb[2] - nb[0]) * scale
    exp_h = (nb[3] - nb[1]) * scale
    got_w, got_h = placed[2] - placed[0], placed[3] - placed[1]
    intact = abs(got_w - exp_w) <= 6 and abs(got_h - exp_h) <= 6
    print(f"placed {placed} {got_w}x{got_h} expected {exp_w:.0f}x{exp_h:.0f} -> intact {intact}")
    if not intact:
        raise SystemExit("WARNING: drawing was clipped")

    # review: old vs new on a dark and a light backdrop (black-key halos show on light)
    panels = []
    for bg in ((24, 26, 34), (240, 243, 249)):
        for img_path in (CURRENT, OUTPATH):
            img = Image.open(img_path).convert("RGBA").resize((340, 212), Image.LANCZOS)
            t = Image.new("RGB", (340, 212), bg)
            t.paste(img, (0, 0), img)
            panels.append(t)
    strip = Image.new("RGB", (348 * len(panels), 212), (200, 60, 60))
    for i, t in enumerate(panels):
        strip.paste(t, (348 * i, 0))
    strip.save(se.OUT / "previews-shy.png")
    print("previews-shy.png: [old dark | new dark | old light | new light]")


if __name__ == "__main__":
    main(float(sys.argv[1]) if len(sys.argv) > 1 else 1.0)

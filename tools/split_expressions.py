"""Split the two-pose sheet into separate sprites and align them to the reference.

Alignment anchor: the white frilly headdress band. Unlike hair silhouette or face
shape it does not deform when the expression changes, so it gives a stable scale
and centre for every pose.
"""
from collections import deque
from pathlib import Path

from PIL import Image

SRC = Path(r"C:\Users\l\.dsh\attachments\v1\objects\d2\d2e1cb75389aa88d76f0a010cec41869096234e39b550d37934002af57d8fca4")
REF = Path(r"C:\Users\l\.dsh\plugins\dsh-pet\assets\pet8-full.png")
OUT = Path(r"C:\Users\l\.dsh\plugins\dsh-pet\assets")
CANVAS = (1440, 1199)
# Hand-tuned per pose: the frilly headdress is a good anchor for the sleeping
# pose, but the shy pose's frill sits in shadow and measures ~16% narrow, which
# would over-enlarge it. Values verified against the reference strip.
OUTNAME = {"sleepy": "pet14-sleepy.png", "shy": "pet12-shy.png"}
SCALE_OVERRIDE = {"sleepy": 1.475, "shy": 1.6275}


def load_rgba(path: Path) -> Image.Image:
    return Image.open(path).convert("RGBA")


def matte_of(img: Image.Image) -> Image.Image:
    """Return an L-mode matte: the image's own alpha when it has one, else a
    white-key flood fill from the border."""
    alpha = img.getchannel("A")
    lo, hi = alpha.getextrema()
    if lo < 250 and (hi - lo) > 40:
        data = alpha.load()
        w, h = img.size
        for y in range(h):
            for x in range(w):
                a = data[x, y]
                data[x, y] = 0 if a <= 4 else (255 if a >= 249 else a)
        return alpha

    px = img.load()
    w, h = img.size
    outside = bytearray(w * h)
    queue = deque()

    def is_white(x: int, y: int) -> bool:
        r, g, b, _ = px[x, y]
        return min(r, g, b) >= 230 and (max(r, g, b) - min(r, g, b)) <= 28

    for x in range(w):
        for y in (0, h - 1):
            if is_white(x, y) and not outside[y * w + x]:
                outside[y * w + x] = 1
                queue.append((x, y))
    for y in range(h):
        for x in (0, w - 1):
            if is_white(x, y) and not outside[y * w + x]:
                outside[y * w + x] = 1
                queue.append((x, y))
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not outside[ny * w + nx] and is_white(nx, ny):
                outside[ny * w + nx] = 1
                queue.append((nx, ny))
    return Image.frombytes("L", (w, h), bytes(0 if v else 255 for v in outside))


def bbox_of(matte: Image.Image, thr: int = 24):
    return matte.point(lambda v: 255 if v > thr else 0).getbbox()


def frill_anchor(img: Image.Image, matte: Image.Image, box):
    """bbox of the bright white headdress inside the upper part of the pose"""
    x0, y0, x1, y1 = box
    limit = y0 + int((y1 - y0) * 0.45)
    px = img.load()
    mx = matte.load()
    fx0 = fy0 = 10 ** 9
    fx1 = fy1 = -1
    for y in range(y0, min(limit, img.size[1])):
        for x in range(x0, x1):
            if mx[x, y] < 200:
                continue
            r, g, b, _ = px[x, y]
            if min(r, g, b) > 232:
                fx0 = min(fx0, x); fx1 = max(fx1, x)
                fy0 = min(fy0, y); fy1 = max(fy1, y)
    if fx1 < 0:
        raise SystemExit("frill anchor not found")
    return fx0, fy0, fx1, fy1


def flip_half(img: Image.Image, x0: int, x1: int) -> Image.Image:
    return img.crop((x0, 0, x1, img.size[1]))


def split_columns(img: Image.Image):
    """Widest empty vertical gap inside the middle band = the pose separator."""
    matte = matte_of(img)
    w, h = img.size
    mx = matte.load()
    empty = []
    for x in range(int(w * 0.30), int(w * 0.70)):
        col = sum(1 for y in range(h) if mx[x, y] > 24)
        empty.append((col, x))
    best = min(empty)[1]
    return best, matte


def place(img: Image.Image, matte: Image.Image, scale: float, offx: float, offy: float) -> Image.Image:
    size = (max(1, round(img.width * scale)), max(1, round(img.height * scale)))
    sprite = img.resize(size, Image.LANCZOS)
    smatte = matte.resize(size, Image.LANCZOS)
    sprite.putalpha(smatte)
    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    canvas.alpha_composite(sprite, (round(offx), round(offy)))
    return canvas


def anchor_top(img: Image.Image, matte: Image.Image, box):
    """Head anchor that survives lighting and pose changes: horizontal centre of
    the opaque head plus the topmost bright (headdress) row."""
    x0, y0, x1, y1 = box
    px = img.load()
    mx = matte.load()
    band = y0 + max(8, int((y1 - y0) * 0.40))
    lefts, rights = [], []
    top_bright = None
    for y in range(y0, min(band, img.size[1])):
        row = [x for x in range(x0, x1) if mx[x, y] > 24]
        if row:
            lefts.append(min(row)); rights.append(max(row))
        if top_bright is None:
            for x in range(x0, x1):
                if mx[x, y] > 200:
                    r, g, b, _ = px[x, y]
                    if min(r, g, b) > 232:
                        top_bright = y
                        break
    if not lefts:
        raise SystemExit("head anchor not found")
    widths = sorted(r - l + 1 for l, r in zip(lefts, rights))
    med = widths[len(widths) // 2]
    centres = sorted((l + r) / 2 for l, r in zip(lefts, rights) if (r - l + 1) >= med * 0.6)
    return med, centres[len(centres) // 2], (top_bright if top_bright is not None else y0)


def ahoge_anchor(img: Image.Image, matte: Image.Image, box):
    """Bbox of the dark-blue ahoge loop: rigid across poses and unaffected by
    lighting or by whatever she is holding, so it is the safest scale reference."""
    x0, y0, x1, y1 = box
    limit = y0 + int((y1 - y0) * 0.22)
    px = img.load()
    mx = matte.load()
    ax0 = ay0 = 10 ** 9
    ax1 = ay1 = -1
    for y in range(y0, min(limit, img.size[1])):
        for x in range(x0, x1):
            if mx[x, y] < 200:
                continue
            r, g, b, _ = px[x, y]
            lum = 0.299 * r + 0.587 * g + 0.114 * b
            if b > r + 10 and b > g + 6 and lum < 150:
                ax0 = min(ax0, x); ax1 = max(ax1, x)
                ay0 = min(ay0, y); ay1 = max(ay1, y)
    if ax1 < 0:
        return None
    return ax0, ay0, ax1, ay1


def calib() -> None:
    """Render the two new poses at several scales side by side with the reference."""
    sheet = load_rgba(SRC)
    split_x, _ = split_columns(sheet)
    poses = {"sleepy": flip_half(sheet, 0, split_x), "shy": flip_half(sheet, split_x, sheet.width)}
    ref = load_rgba(REF)
    ref_matte = matte_of(ref)
    rw, rcx, rtop = anchor_top(ref, ref_matte, bbox_of(ref_matte))
    print(f"ref head w={rw} cx={rcx:.0f} top={rtop}")

    scales = [0.80, 0.90, 1.00]
    tiles = []
    tile = Image.new("RGB", (300, 250), (232, 235, 242))
    sprite = ref.convert("RGBA").resize((300, 250), Image.LANCZOS)
    tile.paste(sprite, (0, 0), sprite)
    tiles.append(("ref", 0.0, tile))
    for name, pose in poses.items():
        matte = matte_of(pose)
        w, cx, top = anchor_top(pose, matte, bbox_of(matte))
        for s in scales:
            scale = rw / w * s
            offx = rcx - cx * scale
            offy = rtop - top * scale
            canvas = place(pose, matte, scale, max(0, min(offx, CANVAS[0] - pose.width * scale)), max(0, min(offy, CANVAS[1] - pose.height * scale)))
            tile = Image.new("RGB", (300, 250), (232, 235, 242))
            small = canvas.resize((300, 250), Image.LANCZOS)
            tile.paste(small, (0, 0), small)
            tiles.append((f"{name}@{s:.2f}", scale, tile))
            print(f"{name}@{s:.2f} -> scale={scale:.3f}")

    strip = Image.new("RGB", (308 * len(tiles), 250), (200, 60, 60))
    for i, (_, _, tile) in enumerate(tiles):
        strip.paste(tile, (308 * i, 0))
    strip.save(OUT / "_strip9.png")
    print("labels:", ", ".join(f"{i}:{n}" for i, (n, _, _) in enumerate(tiles)))


def final(scale: float) -> None:
    """Write pet9-sleepy.png / pet9-shy.png at a hand-calibrated scale."""
    sheet = load_rgba(SRC)
    split_x, _ = split_columns(sheet)
    poses = {"sleepy": flip_half(sheet, 0, split_x), "shy": flip_half(sheet, split_x, sheet.width)}
    ref = load_rgba(REF)
    ref_matte = matte_of(ref)
    rw, rcx, rtop = anchor_top(ref, ref_matte, bbox_of(ref_matte))
    for name, pose in poses.items():
        matte = matte_of(pose)
        offx = rcx - (pose.width / 2) * scale if False else None  # placeholder, replaced below
        _, cx, top = anchor_top(pose, matte, bbox_of(matte))
        offx = rcx - cx * scale
        offy = rtop - top * scale
        offx = max(0, min(offx, CANVAS[0] - pose.width * scale))
        offy = max(0, min(offy, CANVAS[1] - pose.height * scale))
        out = place(pose, matte, scale, offx, offy)
        out.save(OUT / OUTNAME.get(name, f"pet9-{name}.png"))
        print(f"{name}: scale={scale} off=({offx:.0f},{offy:.0f})")

    tiles = []
    for n in ("pet8-full.png", "pet8-panic.png", OUTNAME["sleepy"], OUTNAME["shy"]):
        tile = Image.new("RGB", (300, 250), (232, 235, 242))
        sprite = Image.open(OUT / n).convert("RGBA").resize((300, 250), Image.LANCZOS)
        tile.paste(sprite, (0, 0), sprite)
        tiles.append(tile)
    strip = Image.new("RGB", (308 * len(tiles), 250), (200, 60, 60))
    for i, tile in enumerate(tiles):
        strip.paste(tile, (308 * i, 0))
    strip.save(OUT / "_strip9.png")
    print("strip: ref | panic | sleepy | shy")


def main() -> None:
    sheet = load_rgba(SRC)
    split_x, _ = split_columns(sheet)
    left = flip_half(sheet, 0, split_x)
    right = flip_half(sheet, split_x, sheet.width)
    print(f"sheet {sheet.size} split at x={split_x}")

    ref = load_rgba(REF)
    ref_matte = matte_of(ref)
    ref_box = bbox_of(ref_matte)
    ref_frill = frill_anchor(ref, ref_matte, ref_box)
    ref_fw = ref_frill[2] - ref_frill[0]
    ref_fcx = (ref_frill[0] + ref_frill[2]) / 2
    ref_fcy = (ref_frill[1] + ref_frill[3]) / 2
    print(f"ref frill w={ref_fw} centre=({ref_fcx:.0f},{ref_fcy:.0f})")

    for name, pose in (("sleepy", left), ("shy", right)):
        matte = matte_of(pose)
        box = bbox_of(matte)
        frill = frill_anchor(pose, matte, box)
        fw = frill[2] - frill[0]
        fcx = (frill[0] + frill[2]) / 2
        fcy = (frill[1] + frill[3]) / 2
        # Automatic anchors all failed here: the sleeping pose's hair spread
        # inflates head-width, its lowered head compresses the ahoge, and the shy
        # pose's frill sits in shadow. These scales were verified by eye against
        # the reference strip instead.
        scale = SCALE_OVERRIDE.get(name, ref_fw / fw)
        how = "hand-calibrated"
        offx = ref_fcx - fcx * scale
        offy = ref_fcy - fcy * scale
        # keep the whole pose inside the canvas (the tail reaches far right)
        offx = min(offx, CANVAS[0] - pose.width * scale)
        offy = min(offy, CANVAS[1] - pose.height * scale)
        offx = max(offx, 0)
        offy = max(offy, 0)
        out = place(pose, matte, scale, offx, offy)
        out.save(OUT / OUTNAME.get(name, f"pet9-{name}.png"))
        print(f"{name}: pose {pose.size} frill w={fw} bbox={box} -> scale={scale:.4f} ({how}) off=({offx:.0f},{offy:.0f})")

    # review strip
    strip_names = ["pet8-full.png", OUTNAME["sleepy"], OUTNAME["shy"]]
    tiles = []
    for n in strip_names:
        tile = Image.new("RGB", (430, 358), (232, 235, 242))
        sprite = Image.open(OUT / n).convert("RGBA").resize((430, 358), Image.LANCZOS)
        tile.paste(sprite, (0, 0), sprite)
        tiles.append(tile)
    strip = Image.new("RGB", (430 * len(tiles) + 8 * (len(tiles) - 1), 358), (200, 60, 60))
    x = 0
    for tile in tiles:
        strip.paste(tile, (x, 0))
        x += 438
    strip.save(OUT / "_strip9.png")
    print("strip saved")


if __name__ == "__main__":
    import sys

    if len(sys.argv) > 1 and sys.argv[1] == "calib":
        calib()
    elif len(sys.argv) > 1 and sys.argv[1] == "final":
        final(float(sys.argv[2]))
    else:
        main()

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Rebuild both expressions on one WIDER canvas (1440x1199) so the flustered pose's
# tail is not clipped: its art is 1451 wide and, scaled to 0.97 for head match,
# reaches x=1418 -- past the old 1312 canvas edge.
$cs = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class PetWide {
  static bool IsWhite(byte r, byte g, byte b) {
    int mn = Math.Min(r, Math.Min(g, b));
    int mx = Math.Max(r, Math.Max(g, b));
    return mn >= 230 && (mx - mn) <= 28;
  }

  static bool[] OutsideOf(byte[] px, int w, int h) {
    var outside = new bool[w * h];
    var stack = new Stack<int>();
    for (int x = 0; x < w; x++) { stack.Push(x); stack.Push((h - 1) * w + x); }
    for (int y = 0; y < h; y++) { stack.Push(y * w); stack.Push(y * w + w - 1); }
    while (stack.Count > 0) {
      int i = stack.Pop();
      if (outside[i]) continue;
      int p = i * 4;
      if (!IsWhite(px[p + 2], px[p + 1], px[p])) continue;
      outside[i] = true;
      int x = i % w, y = i / w;
      if (x > 0) stack.Push(i - 1);
      if (x < w - 1) stack.Push(i + 1);
      if (y > 0) stack.Push(i - w);
      if (y < h - 1) stack.Push(i + w);
    }
    return outside;
  }

  static byte[] MatteOf(Bitmap img, out byte[] px) {
    int w = img.Width, h = img.Height;
    var d = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    px = new byte[w * h * 4];
    System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
    img.UnlockBits(d);
    int mn = 255, mx = 0;
    for (int i = 0; i < w * h; i++) { int a = px[i * 4 + 3]; if (a < mn) mn = a; if (a > mx) mx = a; }
    var matte = new byte[w * h];
    if (mn < 250 && (mx - mn) > 40) {
      for (int i = 0; i < w * h; i++) { byte a = px[i * 4 + 3]; matte[i] = a <= 4 ? (byte)0 : (a >= 249 ? (byte)255 : a); }
    } else {
      var outside = OutsideOf(px, w, h);
      for (int i = 0; i < w * h; i++) matte[i] = outside[i] ? (byte)0 : (byte)255;
    }
    return matte;
  }

  static int[] Bbox(byte[] matte, int w, int h) {
    int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1;
    for (int y = 0; y < h; y++)
      for (int x = 0; x < w; x++)
        if (matte[y * w + x] > 24) {
          if (x < x0) x0 = x; if (x > x1) x1 = x;
          if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
    return new[] { x0, y0, x1, y1 };
  }

  static double Median(List<double> v) {
    if (v.Count == 0) return 0;
    v.Sort();
    int m = v.Count / 2;
    return v.Count % 2 == 0 ? (v[m - 1] + v[m]) / 2.0 : v[m];
  }

  static double[] HeadAnchor(byte[] matte, int w, int h, int[] bbox) {
    int band = Math.Max(8, (int)((bbox[3] - bbox[1]) * 0.34));
    var widths = new List<double>(); var centers = new List<double>(); var rows = new List<double>();
    for (int y = bbox[1]; y < Math.Min(h, bbox[1] + band); y++) {
      int left = -1, right = -1;
      for (int x = 0; x < w; x++) if (matte[y * w + x] > 24) { if (left < 0) left = x; right = x; }
      if (left < 0) continue;
      widths.Add(right - left + 1); centers.Add((left + right) / 2.0); rows.Add(y);
    }
    double wMed = Median(widths);
    var kc = new List<double>(); var kr = new List<double>();
    for (int i = 0; i < widths.Count; i++) if (widths[i] >= wMed * 0.6) { kc.Add(centers[i]); kr.Add(rows[i]); }
    return new[] { wMed, Median(kc), Median(kr) };
  }

  /// Re-emit a sprite onto a wider transparent canvas at (offX, offY).
  public static string Place(string src, string outPath, int canvasW, int canvasH, int offX, int offY, double scale) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(canvasW, canvasH, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
      g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
      g.Clear(Color.Transparent);
      g.DrawImage(img, new Rectangle(offX, offY, (int)Math.Round(img.Width * scale), (int)Math.Round(img.Height * scale)));
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Align the flustered art to the reference head, on the wide canvas.
  public static string AlignWide(string src, string refPath, string outPath, int canvasW, int canvasH, double scale) {
    using (var refImg = new Bitmap(refPath))
    using (var img = new Bitmap(src)) {
      byte[] refPx, srcPx;
      var refMatte = MatteOf(refImg, out refPx);
      var srcMatte = MatteOf(img, out srcPx);
      var rb = Bbox(refMatte, refImg.Width, refImg.Height);
      var sb = Bbox(srcMatte, img.Width, img.Height);
      var ra = HeadAnchor(refMatte, refImg.Width, refImg.Height, rb);
      var sa = HeadAnchor(srcMatte, img.Width, img.Height, sb);
      double offX = ra[1] - sa[1] * scale;
      double offY = ra[2] - sa[2] * scale;
      // keep the whole pose inside the canvas
      double right = offX + img.Width * scale, bottom = offY + img.Height * scale;
      if (right > canvasW) offX -= (right - canvasW);
      if (bottom > canvasH) offY -= (bottom - canvasH);
      Place(src, outPath, canvasW, canvasH, (int)Math.Round(offX), (int)Math.Round(offY), scale);
      return "scale=" + scale + " off=" + Math.Round(offX) + "," + Math.Round(offY)
        + " poseRight=" + Math.Round(offX + img.Width * scale) + "/" + canvasW
        + " headCx " + Math.Round(ra[1]) + " srcHeadCx " + Math.Round(sa[1]);
    }
  }

  public static string Preview(string src, string outPath, int width) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(width, (int)(img.Height * (double)width / img.Width), PixelFormat.Format24bppRgb))
    using (var g = Graphics.FromImage(bmp)) {
      int cell = Math.Max(10, width / 26);
      for (int y = 0; y < bmp.Height; y += cell)
        for (int x = 0; x < bmp.Width; x += cell) {
          bool on = ((x / cell) + (y / cell)) % 2 == 0;
          using (var brush = new SolidBrush(on ? Color.FromArgb(255, 62, 62, 72) : Color.FromArgb(255, 36, 36, 44)))
            g.FillRectangle(brush, x, y, cell, cell);
        }
      g.DrawImage(img, 0, 0, bmp.Width, bmp.Height);
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  public static string Compare(string aPath, string bPath, string outPath, int width) {
    using (var a = new Bitmap(aPath))
    using (var b = new Bitmap(bPath)) {
      int w = width, h = (int)(a.Height * (double)width / a.Width);
      using (var bmp = new Bitmap(w * 2 + 8, h, PixelFormat.Format24bppRgb))
      using (var g = Graphics.FromImage(bmp)) {
        g.Clear(Color.FromArgb(232, 235, 242));
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.DrawImage(a, new Rectangle(0, 0, w, h));
        g.DrawImage(b, new Rectangle(w + 8, 0, w, h));
        bmp.Save(outPath, ImageFormat.Png);
      }
    }
    return outPath;
  }

  public static string Avatar(string src, string outPath, double fx, double fy, double fw, double fh, int size) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
      g.Clear(Color.Transparent);
      g.DrawImage(img, new Rectangle(0, 0, size, size),
        new Rectangle((int)(img.Width * fx), (int)(img.Height * fy), (int)(img.Width * fw), (int)(img.Height * fh)),
        GraphicsUnit.Pixel);
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
$refOld = Join-Path $dir 'pet7-full.png'          # 1312x1199, head centred as before
$panicSrc = 'C:\Users\l\.dsh\attachments\v1\objects\89\89fd0f742956748a79b9d74f4dacdce1fbd11ef8b06dbd2c9b5d7d9d1b29a50c'
$full = Join-Path $dir 'pet8-full.png'
$panic = Join-Path $dir 'pet8-panic.png'
$avatar = Join-Path $dir 'pet8-avatar.png'

$W = 1440; $H = 1199
[PetWide]::Place($refOld, $full, $W, $H, 0, 0, 1.0) | Out-Null
Write-Output ('full  -> ' + [PetWide]::AlignWide($panicSrc, $full, $panic, $W, $H, 0.97))
[PetWide]::Avatar($full, $avatar, 0.237, 0.23, 0.29, 0.34, 220) | Out-Null
[PetWide]::Preview($panic, (Join-Path $dir 'preview-panic.png'), 900) | Out-Null
[PetWide]::Preview($full, (Join-Path $dir 'preview-whole.png'), 900) | Out-Null
[PetWide]::Compare($full, $panic, (Join-Path $dir '_compare-expr.png'), 430) | Out-Null

foreach ($f in $full, $panic, $avatar) {
  $img = [System.Drawing.Image]::FromFile($f)
  Write-Output ((Split-Path $f -Leaf).PadRight(18) + $img.Width + 'x' + $img.Height + '  ' + [math]::Round((Get-Item $f).Length / 1KB) + ' KB')
  $img.Dispose()
}

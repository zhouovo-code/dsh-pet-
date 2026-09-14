$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# Second expression: cut it out and align it to the reference sprite so the two
# can cross-fade in place. Alignment matches the head (top band of the character
# bbox) because every pose shares the same head, not the same body extent.
$cs = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class PetExpr {
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

  /// alpha matte: use the source alpha when it carries one, else key out white
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

  static int[] Bbox(byte[] matte, int w, int h, int yFrom, int yTo) {
    int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1;
    for (int y = yFrom; y < yTo; y++)
      for (int x = 0; x < w; x++)
        if (matte[y * w + x] > 24) {
          if (x < x0) x0 = x; if (x > x1) x1 = x;
          if (y < y0) y0 = y; if (y > y1) y1 = y;
        }
    return new[] { x0, y0, x1, y1 };
  }

  /// Face anchor: the skin-coloured region is pose independent, unlike hair
  /// silhouette or bbox extent.
  static bool IsSkin(byte r, byte g, byte b) {
    return r > 215 && g > 170 && b > 150 && r > g + 12 && g > b + 6;
  }

  static double[] FaceAnchor(byte[] px, int w, int h, int[] bbox) {
    int x0 = int.MaxValue, y0 = int.MaxValue, x1 = -1, y1 = -1, count = 0;
    int limit = Math.Min(h, bbox[1] + (int)((bbox[3] - bbox[1]) * 0.75));
    for (int y = bbox[1]; y < limit; y++)
      for (int x = 0; x < w; x++) {
        int p = (y * w + x) * 4;
        if (!IsSkin(px[p + 2], px[p + 1], px[p])) continue;
        count++;
        if (x < x0) x0 = x; if (x > x1) x1 = x;
        if (y < y0) y0 = y; if (y > y1) y1 = y;
      }
    if (count < 200) return null;
    return new double[] { x1 - x0 + 1, (x0 + x1) / 2.0, (y0 + y1) / 2.0, count };
  }

  static double Median(List<double> values) {
    if (values.Count == 0) return 0;
    values.Sort();
    int mid = values.Count / 2;
    return values.Count % 2 == 0 ? (values[mid - 1] + values[mid]) / 2.0 : values[mid];
  }

  /// Head anchor from the top band, measured per row and reduced with a median so
  /// detached bits (sweat drops, sparkles) cannot skew it.
  static double[] HeadAnchor(byte[] matte, int w, int h, int[] bbox) {
    int band = Math.Max(8, (int)((bbox[3] - bbox[1]) * 0.34));
    var widths = new List<double>();
    var centers = new List<double>();
    var rows = new List<double>();
    for (int y = bbox[1]; y < Math.Min(h, bbox[1] + band); y++) {
      int left = -1, right = -1;
      for (int x = 0; x < w; x++) if (matte[y * w + x] > 24) { if (left < 0) left = x; right = x; }
      if (left < 0) continue;
      widths.Add(right - left + 1);
      centers.Add((left + right) / 2.0);
      rows.Add(y);
    }
    double wMed = Median(widths);
    var keepCenters = new List<double>();
    var keepRows = new List<double>();
    for (int i = 0; i < widths.Count; i++) {
      if (widths[i] >= wMed * 0.6) { keepCenters.Add(centers[i]); keepRows.Add(rows[i]); }
    }
    return new[] { wMed, Median(keepCenters), Median(keepRows) };
  }

  /// Variant with an explicit scale, centred on the head band -- used for manual
  /// calibration, because expression changes make automatic face/hair anchors noisy.
  public static string AlignScaled(string src, string refPath, string outPath, double scale) {
    using (var refImg = new Bitmap(refPath))
    using (var img = new Bitmap(src)) {
      int cw = refImg.Width, ch = refImg.Height;
      byte[] refPx, srcPx;
      var refMatte = MatteOf(refImg, out refPx);
      var srcMatte = MatteOf(img, out srcPx);
      var rb = Bbox(refMatte, cw, ch, 0, ch);
      var sb = Bbox(srcMatte, img.Width, img.Height, 0, img.Height);
      var ra = HeadAnchor(refMatte, cw, ch, rb);
      var sa = HeadAnchor(srcMatte, img.Width, img.Height, sb);
      double offX = ra[1] - sa[1] * scale;
      double offY = rb[1] - sb[1] * scale;
      using (var outBmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
      using (var g = Graphics.FromImage(outBmp)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.Clear(Color.Transparent);
        g.DrawImage(img, new Rectangle((int)Math.Round(offX), (int)Math.Round(offY),
            (int)Math.Round(img.Width * scale), (int)Math.Round(img.Height * scale)));
        outBmp.Save(outPath, ImageFormat.Png);
      }
      return "scale=" + scale + " off=" + Math.Round(offX) + "," + Math.Round(offY) + " srcTop=" + sb[1];
    }
  }

  /// three-way comparison strip: reference | variant A | variant B | variant C
  public static string Strip(string refPath, string aPath, string bPath, string cPath, string outPath, int width) {
    using (var r = new Bitmap(refPath))
    using (var a = new Bitmap(aPath))
    using (var b = new Bitmap(bPath))
    using (var c = new Bitmap(cPath)) {
      int w = width, h = (int)(r.Height * (double)width / r.Width);
      using (var bmp = new Bitmap(w * 4 + 24, h, PixelFormat.Format24bppRgb))
      using (var g = Graphics.FromImage(bmp)) {
        g.Clear(Color.FromArgb(232, 235, 242));
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.DrawImage(r, new Rectangle(0, 0, w, h));
        g.DrawImage(a, new Rectangle(w + 8, 0, w, h));
        g.DrawImage(b, new Rectangle((w + 8) * 2, 0, w, h));
        g.DrawImage(c, new Rectangle((w + 8) * 3, 0, w, h));
        bmp.Save(outPath, ImageFormat.Png);
      }
    }
    return outPath;
  }

  /// Write the expression aligned into a canvas the size of the reference sprite.
  public static string Align(string src, string refPath, string outPath) {
    using (var refImg = new Bitmap(refPath))
    using (var img = new Bitmap(src)) {
      int cw = refImg.Width, ch = refImg.Height;
      byte[] refPx, srcPx;
      var refMatte = MatteOf(refImg, out refPx);
      var srcMatte = MatteOf(img, out srcPx);
      var rb = Bbox(refMatte, cw, ch, 0, ch);
      var sb = Bbox(srcMatte, img.Width, img.Height, 0, img.Height);
      var ra = FaceAnchor(refPx, cw, ch, rb);
      var sa = FaceAnchor(srcPx, img.Width, img.Height, sb);
      if (ra == null || sa == null) throw new Exception("face anchor not found (ref=" + (ra != null) + " src=" + (sa != null) + ")");
      double scale = ra[0] / sa[0];
      double offX = ra[1] - sa[1] * scale;
      double offY = ra[2] - sa[2] * scale;

      using (var outBmp = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
      using (var g = Graphics.FromImage(outBmp)) {
        g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
        g.PixelOffsetMode = System.Drawing.Drawing2D.PixelOffsetMode.HighQuality;
        g.Clear(Color.Transparent);
        g.DrawImage(img, new Rectangle((int)Math.Round(offX), (int)Math.Round(offY),
            (int)Math.Round(img.Width * scale), (int)Math.Round(img.Height * scale)));
        outBmp.Save(outPath, ImageFormat.Png);
      }
      return "scale=" + Math.Round(scale, 4) + " offset=" + Math.Round(offX) + "," + Math.Round(offY)
        + " faceW " + Math.Round(sa[0]) + "->" + Math.Round(ra[0])
        + " faceC " + Math.Round(sa[1]) + "," + Math.Round(sa[2]) + " -> " + Math.Round(ra[1]) + "," + Math.Round(ra[2]);
    }
  }

  /// checkerboard preview of one sprite, optionally on a light page background
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

  /// side-by-side comparison at display scale, on a light background
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
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
$ref = Join-Path $dir 'pet7-full.png'
$newSrc = 'C:\Users\l\.dsh\attachments\v1\objects\89\89fd0f742956748a79b9d74f4dacdce1fbd11ef8b06dbd2c9b5d7d9d1b29a50c'
$panic = Join-Path $dir 'pet7-panic.png'

# 0.97 keeps the head the same size as the reference sprite (calibrated by eye
# against tools output); the pose difference is intentional, the head is not.
$info = [PetExpr]::AlignScaled($newSrc, $ref, $panic, 0.97)
Write-Output ('align: ' + $info)
[PetExpr]::Preview($panic, (Join-Path $dir 'preview-panic.png'), 900) | Out-Null
[PetExpr]::Compare($ref, $panic, (Join-Path $dir '_compare-expr.png'), 430) | Out-Null
Remove-Item (Join-Path $dir '_expr-090.png'), (Join-Path $dir '_expr-094.png'), (Join-Path $dir '_expr-098.png'), (Join-Path $dir '_calib.png') -Force -ErrorAction SilentlyContinue
foreach ($extra in (Get-ChildItem $dir -File | Where-Object { $_.Name -like '_expr-*' -or $_.Name -eq '_calib.png' })) { Remove-Item $extra.FullName -Force }
Write-Output ((Split-Path $panic -Leaf) + ' ' + [math]::Round((Get-Item $panic).Length / 1KB) + ' KB')
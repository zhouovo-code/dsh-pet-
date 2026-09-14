$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# --------------------------------------------------------------- layer regions
# Ahoge: the hair loop + its legs, generously reaching into the white headdress
# where the cut is hidden behind the body layer.
$rect_generic = $null
$ahogeRegion = @($null)   # handled as a rectangle: x0, y0, x1, y1
$ahogeRect = @(250, 0, 720, 265)

# Tail: upper lobe + fluke + stem, left edge following the fin so no hair moves
$tailPoly = @(
  1045,690,  1100,685,  1160,730,  1190,800,  1170,850,  1230,860,  1300,890,  1312,935,
  1280,975,  1180,960,  1120,1010, 1060,1100, 1010,1199, 940,1199,  905,1150,  950,1050,
  985,950,   1015,860,  1030,780
)

$cs = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class Pet2Cut {
  static bool IsWhite(byte r, byte g, byte b) {
    int mn = Math.Min(r, Math.Min(g, b));
    int mx = Math.Max(r, Math.Max(g, b));
    return mn >= 230 && (mx - mn) <= 28;
  }

  /// flood fill the white background inwards from every border pixel
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

  static byte[] Blur(byte[] mask, int w, int h, int radius) {
    if (radius <= 0) return mask;
    var tmp = new byte[w * h];
    for (int y = 0; y < h; y++) {
      int sum = 0, n = 0;
      for (int x = -radius; x <= radius; x++) { sum += mask[y * w + Math.Min(w - 1, Math.Max(0, x))]; n++; }
      for (int x = 0; x < w; x++) {
        tmp[y * w + x] = (byte)(sum / n);
        sum += mask[y * w + Math.Min(w - 1, x + radius + 1)] - mask[y * w + Math.Max(0, x - radius)];
      }
    }
    for (int x = 0; x < w; x++) {
      int sum = 0, n = 0;
      for (int y = -radius; y <= radius; y++) { sum += tmp[Math.Min(h - 1, Math.Max(0, y)) * w + x]; n++; }
      for (int y = 0; y < h; y++) {
        mask[y * w + x] = (byte)(sum / n);
        sum += tmp[Math.Min(h - 1, y + radius + 1) * w + x] - tmp[Math.Max(0, y - radius) * w + x];
      }
    }
    return mask;
  }

  static byte[] Erode(byte[] mask, int w, int h) {
    var outv = new byte[w * h];
    for (int y = 0; y < h; y++) {
      for (int x = 0; x < w; x++) {
        byte m = 255;
        for (int dy = -1; dy <= 1; dy++) {
          int yy = Math.Min(h - 1, Math.Max(0, y + dy));
          for (int dx = -1; dx <= 1; dx++) {
            int xx = Math.Min(w - 1, Math.Max(0, x + dx));
            byte v = mask[yy * w + xx];
            if (v < m) m = v;
          }
        }
        outv[y * w + x] = m;
      }
    }
    return outv;
  }

  static bool InPoly(int[] flat, int x, int y) {
    bool inside = false;
    int n = flat.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      int xi = flat[i * 2], yi = flat[i * 2 + 1], xj = flat[j * 2], yj = flat[j * 2 + 1];
      if (((yi > y) != (yj > y)) && (x < (double)(xj - xi) * (y - yi) / (double)(yj - yi) + xi)) inside = !inside;
    }
    return inside;
  }

  /// Write one layer: global alpha (white removed, 1px feathered) restricted to a
  /// region, with a soft rim glow. kind: 0 body, 1 ahoge, 2 tail.
  public static string Layer(string src, string outPath, int kind, int[] poly, int[] rect) {
    using (var img = new Bitmap(src))
    using (var outBmp = new Bitmap(img.Width, img.Height, PixelFormat.Format32bppArgb)) {
      int w = img.Width, h = img.Height;
      var data = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var px = new byte[w * h * 4];
      System.Runtime.InteropServices.Marshal.Copy(data.Scan0, px, 0, px.Length);
      img.UnlockBits(data);

      // The source may already be a real cut-out: then its own alpha channel IS
      // the matte, and keying colours would be wrong (a transparent background
      // usually carries RGB 0,0,0, which a white-key reads as solid black and
      // turns into exactly the dark fringe we are trying to avoid). Only fall
      // back to keying white when the image carries no usable alpha.
      int alphaMin = 255, alphaMax = 0;
      for (int i = 0; i < w * h; i++) {
        int a = px[i * 4 + 3];
        if (a < alphaMin) alphaMin = a;
        if (a > alphaMax) alphaMax = a;
      }
      bool hasAlpha = alphaMin < 250 && (alphaMax - alphaMin) > 40;
      byte[] soft;
      if (hasAlpha) {
        soft = new byte[w * h];
        for (int i = 0; i < w * h; i++) {
          int a = px[i * 4 + 3];
          soft[i] = (byte)(a < 6 ? 0 : a);
        }
      } else {
        var outside = OutsideOf(px, w, h);
        var global = new byte[w * h];
        for (int i = 0; i < w * h; i++) global[i] = outside[i] ? (byte)0 : (byte)255;
        soft = Blur((byte[])global.Clone(), w, h, 1);
      }

      var mask = new byte[w * h];
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int i = y * w + x;
          bool inAhoge = rect != null && x >= rect[0] && y >= rect[1] && x <= rect[2] && y <= rect[3];
          bool inTail = poly != null && InPoly(poly, x, y);
          bool use;
          if (kind == 1) use = inAhoge;              // ahoge: rectangle keep-region
          else if (kind == 2) use = inTail;          // tail: polygon keep-region
          else use = !inAhoge && !inTail;            // body: everything else
          if (!use) continue;
          byte a = soft[i];
          if (kind == 1) {
            // the loop's enclosed hole is white: clear white inside the region
            int p = i * 4;
            if (IsWhite(px[p + 2], px[p + 1], px[p])) a = 0;
          }
          mask[i] = a;
        }
      }

      // Straight pass-through: the matte is already correct, so no glow, no
      // erosion and no colour decontamination -- any of those would only
      // reintroduce a fringe.
      var outBytes = new byte[w * h * 4];
      for (int i = 0; i < w * h; i++) {
        outBytes[i * 4] = px[i * 4];
        outBytes[i * 4 + 1] = px[i * 4 + 1];
        outBytes[i * 4 + 2] = px[i * 4 + 2];
        outBytes[i * 4 + 3] = mask[i];
      }
      var outData = outBmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
      System.Runtime.InteropServices.Marshal.Copy(outBytes, 0, outData.Scan0, outBytes.Length);
      outBmp.UnlockBits(outData);
      outBmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Crop all layers to the union alpha bbox (they stay aligned), then save.
  public static string CropAll(string[] inputs, string[] outputs, int margin) {
    int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1, w = 0, h = 0;
    foreach (var path in inputs) {
      using (var bmp = new Bitmap(path)) {
        w = bmp.Width; h = bmp.Height;
        var d = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var bytes = new byte[w * h * 4];
        System.Runtime.InteropServices.Marshal.Copy(d.Scan0, bytes, 0, bytes.Length);
        bmp.UnlockBits(d);
        for (int y = 0; y < h; y++)
          for (int x = 0; x < w; x++)
            if (bytes[(y * w + x) * 4 + 3] > 8) {
              if (x < minX) minX = x; if (x > maxX) maxX = x;
              if (y < minY) minY = y; if (y > maxY) maxY = y;
            }
      }
    }
    if (maxX < 0) return "empty";
    minX = Math.Max(0, minX - margin); minY = Math.Max(0, minY - margin);
    maxX = Math.Min(w - 1, maxX + margin); maxY = Math.Min(h - 1, maxY + margin);
    int cw = maxX - minX + 1, ch = maxY - minY + 1;
    var copies = new Bitmap[inputs.Length];
    for (int i = 0; i < inputs.Length; i++) using (var s = new Bitmap(inputs[i])) copies[i] = new Bitmap(s);
    for (int i = 0; i < inputs.Length; i++) {
      using (var dst = new Bitmap(cw, ch, PixelFormat.Format32bppArgb))
      using (var g = Graphics.FromImage(dst)) {
        g.DrawImage(copies[i], new Rectangle(0, 0, cw, ch), new Rectangle(minX, minY, cw, ch), GraphicsUnit.Pixel);
        dst.Save(outputs[i], ImageFormat.Png);
      }
      copies[i].Dispose();
    }
    return minX + "," + minY + "," + cw + "," + ch;
  }

  /// square avatar crop out of a layer, in fractions of that layer's box
  public static string Avatar(string src, string outPath, double fx, double fy, double fw, double fh, int size) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(size, size, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.InterpolationMode = System.Drawing.Drawing2D.InterpolationMode.HighQualityBicubic;
      g.Clear(Color.Transparent);
      var s = new Rectangle((int)(img.Width * fx), (int)(img.Height * fy), (int)(img.Width * fw), (int)(img.Height * fh));
      g.DrawImage(img, new Rectangle(0, 0, size, size), s, GraphicsUnit.Pixel);
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// composite the three layers over a checkerboard for review
  public static string Preview(string body, string tail, string ahoge, string outPath) {
    using (var first = new Bitmap(body))
    using (var bmp = new Bitmap(first.Width, first.Height, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      int cell = Math.Max(12, first.Width / 30);
      for (int y = 0; y < bmp.Height; y += cell)
        for (int x = 0; x < bmp.Width; x += cell) {
          bool on = ((x / cell) + (y / cell)) % 2 == 0;
          using (var brush = new SolidBrush(on ? Color.FromArgb(255, 62, 62, 72) : Color.FromArgb(255, 36, 36, 44)))
            g.FillRectangle(brush, x, y, cell, cell);
        }
      foreach (var path in new[] { ahoge, tail, body }) {
        if (System.IO.File.Exists(path)) using (var l = new Bitmap(path)) g.DrawImage(l, 0, 0, bmp.Width, bmp.Height);
      }
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }
}
"@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$src = 'C:\Users\l\.dsh\attachments\v1\objects\3e\3ef5a5982b235b326ec9c6632a50c74bbfb70fc0174d2962176a7dfa01f4f213'
$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
$body = Join-Path $dir 'pet5-body.png'
$tail = Join-Path $dir 'pet5-tail.png'
$ahoge = Join-Path $dir 'pet5-ahoge.png'
$head = Join-Path $dir 'pet5-head.png'
$preview = Join-Path $dir 'preview-cutout5.png'

[Pet2Cut]::Layer($src, $body, 0, $tailPoly, $ahogeRect) | Out-Null
[Pet2Cut]::Layer($src, $tail, 2, $tailPoly, $ahogeRect) | Out-Null
[Pet2Cut]::Layer($src, $ahoge, 1, $tailPoly, $ahogeRect) | Out-Null
# No crop pass: re-drawing the layers through GDI+ rewrites some low-alpha
# pixels (measured ~1% with a worst-case channel error of 255). The canvas is
# already tight, so passing the bytes straight through keeps the artist's matte
# bit-exact and the three layers aligned by construction.
[Pet2Cut]::Avatar($body, $head, 0.255, 0.365, 0.31, 0.34, 220) | Out-Null
[Pet2Cut]::Preview($body, $tail, $ahoge, $preview) | Out-Null

foreach ($f in $body, $tail, $ahoge, $head, $preview) {
  Write-Output ((Split-Path $f -Leaf) + '  ' + (Get-Item $f).Length + ' bytes')
}

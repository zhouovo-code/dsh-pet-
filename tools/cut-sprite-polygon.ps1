$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- coordinates
# body = bust silhouette (arms/laptop fall into the bottom fade)
$body = @(
  152,130, 142,108, 152,88, 178,80, 214,78, 254,86, 300,96, 344,106, 378,124, 404,150,
  428,180, 450,212, 470,244, 482,285, 500,310, 525,340, 552,372, 578,400, 600,428, 616,458,
  628,490, 638,522, 648,556, 654,592, 656,628, 656,664, 652,700, 646,740, 634,775, 616,805,
  592,824, 562,836, 520,844, 470,846, 420,844, 370,838, 320,830, 272,818, 228,802, 188,784,
  154,762, 126,734, 102,700, 84,662, 70,620, 60,574, 52,524, 46,472, 44,420, 48,368,
  58,318, 74,272, 94,230, 116,192, 136,158
)
# tail = whale fluke; generous on the left so it tucks behind the hair
$tail = @(
  660,512, 700,504, 744,542, 774,578, 800,598, 830,606, 874,612, 874,700, 826,704, 796,716,
  768,752, 736,784, 700,800, 660,802, 624,792, 604,760, 598,700, 600,640, 616,576, 638,536
)
# ahoge = stroked centreline of the hair loop above the headdress
$ahoge = @(
  152,128, 146,104, 150,74, 164,46, 190,24, 224,12, 260,14, 288,28, 306,52, 310,78, 298,98, 278,112, 256,120
)

function Flat($arr) { return ($arr -join ', ') }

$cs = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;

public static class PetCut {
  static PointF[] Points(int[] flat) {
    var list = new List<PointF>();
    for (int i = 0; i + 1 < flat.Length; i += 2) list.Add(new PointF(flat[i], flat[i + 1]));
    return list.ToArray();
  }

  static byte[] Coverage(int w, int h, int[] flat, bool stroked, float strokeWidth) {
    using (var bmp = new Bitmap(w, h, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.SmoothingMode = SmoothingMode.AntiAlias;
      g.Clear(Color.Transparent);
      var pts = Points(flat);
      if (stroked) {
        using (var pen = new Pen(Color.FromArgb(255, 255, 255, 255), strokeWidth)) {
          pen.StartCap = LineCap.Round;
          pen.EndCap = LineCap.Round;
          pen.LineJoin = LineJoin.Round;
          if (pts.Length > 1) g.DrawLines(pen, pts);
        }
      } else {
        using (var path = new GraphicsPath()) {
          path.AddPolygon(pts);
          using (var brush = new SolidBrush(Color.FromArgb(255, 255, 255, 255))) g.FillPath(brush, path);
        }
      }
      var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var bytes = new byte[w * h * 4];
      System.Runtime.InteropServices.Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
      bmp.UnlockBits(data);
      var mask = new byte[w * h];
      for (int i = 0; i < w * h; i++) mask[i] = bytes[i * 4 + 3];
      return mask;
    }
  }

  static void Blur(byte[] mask, int w, int h, int radius) {
    if (radius <= 0) return;
    var tmp = new byte[w * h];
    for (int y = 0; y < h; y++) {
      int sum = 0, count = 0;
      for (int x = -radius; x <= radius; x++) { int xx = Math.Min(w - 1, Math.Max(0, x)); sum += mask[y * w + xx]; count++; }
      for (int x = 0; x < w; x++) {
        tmp[y * w + x] = (byte)(sum / count);
        int addX = Math.Min(w - 1, x + radius + 1), subX = Math.Max(0, x - radius);
        sum += mask[y * w + addX] - mask[y * w + subX];
      }
    }
    for (int x = 0; x < w; x++) {
      int sum = 0, count = 0;
      for (int y = -radius; y <= radius; y++) { int yy = Math.Min(h - 1, Math.Max(0, y)); sum += tmp[yy * w + x]; count++; }
      for (int y = 0; y < h; y++) {
        mask[y * w + x] = (byte)(sum / count);
        int addY = Math.Min(h - 1, y + radius + 1), subY = Math.Max(0, y - radius);
        sum += tmp[addY * w + x] - tmp[subY * w + x];
      }
    }
  }

  /// src -> outPath with an antialiased polygon/stroke mask, optional bottom and
  /// right fades, and an optional soft rim glow baked underneath.
  public static string Cut(string src, string outPath, int[] flat, bool stroked, float strokeWidth,
                           float bottomFadeStart, float bottomFadeEnd,
                           float rightFadeStart, float rightFadeEnd,
                           int glowRadius, int glowAlpha,
                           int[] eraseFlat, int eraseSoft) {
    using (var img = new Bitmap(src))
    using (var outBmp = new Bitmap(img.Width, img.Height, PixelFormat.Format32bppArgb)) {
      int w = img.Width, h = img.Height;
      var mask = Coverage(w, h, flat, stroked, strokeWidth);
      if (eraseFlat != null && eraseFlat.Length >= 6) {
        var erase = Coverage(w, h, eraseFlat, false, 0);
        Blur(erase, w, h, eraseSoft);
        for (int i = 0; i < w * h; i++) mask[i] = (byte)(mask[i] * (255 - erase[i]) / 255);
      }
      for (int y = 0; y < h; y++) {
        float fy = 1f;
        if (bottomFadeEnd > bottomFadeStart) fy = Math.Min(1f, Math.Max(0f, (bottomFadeEnd - y) / (bottomFadeEnd - bottomFadeStart)));
        for (int x = 0; x < w; x++) {
          float fx = 1f;
          if (rightFadeEnd > rightFadeStart) fx = Math.Min(1f, Math.Max(0f, (rightFadeEnd - x) / (rightFadeEnd - rightFadeStart)));
          int i = y * w + x;
          mask[i] = (byte)(mask[i] * fy * fx);
        }
      }

      byte[] glow = null;
      if (glowRadius > 0) {
        glow = new byte[w * h];
        for (int y = 0; y < h; y++) {
          for (int x = 0; x < w; x++) {
            byte best = 0;
            for (int dy = -glowRadius; dy <= glowRadius; dy++) {
              int yy = y + dy; if (yy < 0 || yy >= h) continue;
              for (int dx = -glowRadius; dx <= glowRadius; dx++) {
                int xx = x + dx; if (xx < 0 || xx >= w) continue;
                if (dx * dx + dy * dy > glowRadius * glowRadius) continue;
                byte v = mask[yy * w + xx];
                if (v > best) best = v;
              }
            }
            glow[y * w + x] = best;
          }
        }
        Blur(glow, w, h, 3);
      }

      var srcData = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var srcBytes = new byte[w * h * 4];
      System.Runtime.InteropServices.Marshal.Copy(srcData.Scan0, srcBytes, 0, srcBytes.Length);
      img.UnlockBits(srcData);

      var outData = outBmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
      var outBytes = new byte[w * h * 4];
      for (int i = 0; i < w * h; i++) {
        int a = mask[i];
        byte r = srcBytes[i * 4 + 2], g = srcBytes[i * 4 + 1], b = srcBytes[i * 4];
        if (glow != null) {
          int outside = Math.Max(0, glow[i] - mask[i]);
          int ga = outside * glowAlpha / 255;
          if (ga > 0) {
            int nr = (r * a + 206 * ga) / Math.Max(1, a + ga);
            int ng = (g * a + 232 * ga) / Math.Max(1, a + ga);
            int nb = (b * a + 255 * ga) / Math.Max(1, a + ga);
            r = (byte)nr; g = (byte)ng; b = (byte)nb;
            a = Math.Min(255, a + ga);
          }
        }
        outBytes[i * 4] = b;
        outBytes[i * 4 + 1] = g;
        outBytes[i * 4 + 2] = r;
        outBytes[i * 4 + 3] = (byte)a;
      }
      System.Runtime.InteropServices.Marshal.Copy(outBytes, 0, outData.Scan0, outBytes.Length);
      outBmp.UnlockBits(outData);
      outBmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// checkerboard + dark preview so the cut edges are visible
  public static string Preview(string bodyPath, string tailPath, string ahogePath, string outPath, int cell) {
    string[] layers = { ahogePath, tailPath, bodyPath };
    using (var first = new Bitmap(bodyPath))
    using (var bmp = new Bitmap(first.Width, first.Height, PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.Clear(Color.Transparent);
      for (int y = 0; y < bmp.Height; y += cell)
        for (int x = 0; x < bmp.Width; x += cell) {
          bool on = ((x / cell) + (y / cell)) % 2 == 0;
          using (var brush = new SolidBrush(on ? Color.FromArgb(255, 60, 60, 70) : Color.FromArgb(255, 34, 34, 42)))
            g.FillRectangle(brush, x, y, cell, cell);
        }
      foreach (var path in layers) {
        if (System.IO.File.Exists(path)) {
          using (var layer = new Bitmap(path)) g.DrawImage(layer, 0, 0, bmp.Width, bmp.Height);
        }
      }
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Crop every layer to the union alpha bounding box (plus margin) so the
  /// stacked layers stay aligned and the widget box stays tight.
  public static string CropAll(string[] inputs, string[] outputs, int margin) {
    int minX = int.MaxValue, minY = int.MaxValue, maxX = -1, maxY = -1;
    int w = 0, h = 0;
    foreach (var path in inputs) {
      using (var bmp = new Bitmap(path)) {
        w = bmp.Width; h = bmp.Height;
        var data = bmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        var bytes = new byte[w * h * 4];
        System.Runtime.InteropServices.Marshal.Copy(data.Scan0, bytes, 0, bytes.Length);
        bmp.UnlockBits(data);
        for (int y = 0; y < h; y++)
          for (int x = 0; x < w; x++)
            if (bytes[(y * w + x) * 4 + 3] > 8) {
              if (x < minX) minX = x;
              if (x > maxX) maxX = x;
              if (y < minY) minY = y;
              if (y > maxY) maxY = y;
            }
      }
    }
    if (maxX < 0) return "0,0,0,0";
    minX = Math.Max(0, minX - margin); minY = Math.Max(0, minY - margin);
    maxX = Math.Min(w - 1, maxX + margin); maxY = Math.Min(h - 1, maxY + margin);
    int cw = maxX - minX + 1, ch = maxY - minY + 1;
    // copy every layer into memory first: saving over the file we are reading
    // from makes GDI+ fail with a generic error
    var copies = new Bitmap[inputs.Length];
    for (int i = 0; i < inputs.Length; i++) {
      using (var src = new Bitmap(inputs[i])) copies[i] = new Bitmap(src);
    }
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
}
"@

Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$src = 'C:\Users\l\.dsh\attachments\v1\objects\3b\3bf2278e109904456e0da519fd90de5005f638fd826c1f931e4faf438487fae3'
$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
$bodyPath = Join-Path $dir 'pet-body.png'
$tailPath = Join-Path $dir 'pet-tail.png'
$ahogePath = Join-Path $dir 'pet-ahoge.png'
$preview = Join-Path $dir '_preview.png'

# laptop glow / desk corner that must not travel with her
$erase = @(-20,560, 40,580, 62,660, 84,740, 120,820, 170,880, -20,880)

# body: bust, arms/hands/laptop dissolve into the bottom fade
[PetCut]::Cut($src, $bodyPath, [int[]]$body, $false, 0, 700, 820, 0, 0, 6, 120, [int[]]$erase, 16) | Out-Null
# tail: whale fluke, tucked behind the hair; far end fades instead of a hard frame cut
[PetCut]::Cut($src, $tailPath, [int[]]$tail, $false, 0, 782, 824, 838, 874, 6, 110, $null, 0) | Out-Null
# ahoge: the hair loop stroked along its centreline
[PetCut]::Cut($src, $ahogePath, [int[]]$ahoge, $true, 18, 0, 0, 0, 0, 5, 90, $null, 0) | Out-Null

# crop all layers to the union bounds so they stay aligned and the box is tight
$box = [PetCut]::CropAll(@($bodyPath, $tailPath, $ahogePath), @($bodyPath, $tailPath, $ahogePath), 10)
Write-Output ('crop box (x,y,w,h) = ' + $box)

[PetCut]::Preview($bodyPath, $tailPath, $ahogePath, $preview, 28) | Out-Null

foreach ($f in $bodyPath, $tailPath, $ahogePath, $preview) {
  Write-Output ((Split-Path $f -Leaf) + '  ' + (Get-Item $f).Length + ' bytes')
}

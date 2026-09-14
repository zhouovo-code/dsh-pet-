$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# ---------------------------------------------------------------- part regions
# Values are the same source so every cut can be checked against the artwork.
# Each animated part keeps a generous overlap under the part drawn in front of
# it, so a rotated part never opens a gap.

$tailPoly   = @(1000,760, 1060,700, 1120,690, 1180,730, 1210,800, 1170,850, 1230,860, 1300,890, 1312,935, 1280,975,
                1180,960, 1120,1010, 1060,1100, 1010,1199, 900,1199, 880,1120, 900,980, 950,860, 980,800)

$ahogeRect  = @(250,0, 720,0, 720,300, 250,300)

# outer left hair band only: far enough from the body that the body never moves,
# close enough that the seam sits inside hair-on-hair
$hairL      = @(4,236, 150,242, 240,262, 300,330, 318,440, 318,700, 306,860, 268,1000, 224,1120, 190,1199, 4,1199)
$hairL2     = @(4,700, 318,700, 306,860, 268,1000, 224,1120, 190,1199, 4,1199)

# outer right hair band, kept clear of the dress frill (x<=950) and the tail
$hairR      = @(944,250, 1040,265, 1120,340, 1150,460, 1150,600, 1130,720, 1110,860, 1085,980, 1055,1090, 1030,1199,
                962,1199, 996,1080, 1010,960, 1015,840, 1000,700, 975,560, 950,420, 936,320)
$hairR2     = @(944,700, 1130,720, 1110,860, 1085,980, 1055,1090, 1030,1199, 962,1199, 996,1080, 1010,960, 1015,840, 1000,700)

$laptopPoly = @(0,812, 140,826, 250,892, 302,986, 432,1026, 526,1116, 546,1199, 0,1199)

$cs = @"
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Imaging;

public static class PetParts {
  static bool InPoly(int[] flat, int x, int y) {
    bool inside = false;
    int n = flat.Length / 2;
    for (int i = 0, j = n - 1; i < n; j = i++) {
      int xi = flat[i * 2], yi = flat[i * 2 + 1], xj = flat[j * 2], yj = flat[j * 2 + 1];
      if (((yi > y) != (yj > y)) && (x < (double)(xj - xi) * (y - yi) / (double)(yj - yi) + xi)) inside = !inside;
    }
    return inside;
  }

  static byte[] SourceBytes(Bitmap img, out byte[] px) {
    var d = img.LockBits(new Rectangle(0, 0, img.Width, img.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
    px = new byte[img.Width * img.Height * 4];
    System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
    img.UnlockBits(d);
    var alpha = new byte[img.Width * img.Height];
    for (int i = 0; i < alpha.Length; i++) {
      byte a = px[i * 4 + 3];
      // clean the matte: drop sub-visible noise, snap near-opaque to fully
      // opaque (the source sits at ~253 everywhere, which is pure PNG entropy)
      alpha[i] = a <= 4 ? (byte)0 : (a >= 249 ? (byte)255 : a);
    }
    return alpha;
  }

  /// One part: source alpha restricted to `include` minus `excludes`.
  public static string Part(string src, string outPath, int[] include, int[][] excludes) {
    using (var img = new Bitmap(src))
    using (var outBmp = new Bitmap(img.Width, img.Height, PixelFormat.Format32bppArgb)) {
      int w = img.Width, h = img.Height;
      byte[] px;
      var baseAlpha = SourceBytes(img, out px);
      var outBytes = new byte[w * h * 4];
      for (int y = 0; y < h; y++) {
        for (int x = 0; x < w; x++) {
          int i = y * w + x;
          bool keep = InPoly(include, x, y);
          if (keep && excludes != null) foreach (var ex in excludes) if (ex != null && InPoly(ex, x, y)) { keep = false; break; }
          if (!keep) continue;
          outBytes[i * 4] = px[i * 4];
          outBytes[i * 4 + 1] = px[i * 4 + 1];
          outBytes[i * 4 + 2] = px[i * 4 + 2];
          outBytes[i * 4 + 3] = baseAlpha[i];
        }
      }
      var od = outBmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
      System.Runtime.InteropServices.Marshal.Copy(outBytes, 0, od.Scan0, outBytes.Length);
      outBmp.UnlockBits(od);
      outBmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Outline every region over the artwork so the cuts can be reviewed.
  public static string Map(string src, string outPath, string[] names, int[][] polys) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(img.Width, img.Height, PixelFormat.Format24bppRgb))
    using (var g = Graphics.FromImage(bmp)) {
      g.Clear(Color.FromArgb(255, 255, 255));
      g.DrawImage(img, 0, 0, img.Width, img.Height);
      var colors = new[] { Color.Cyan, Color.Yellow, Color.Orange, Color.Magenta, Color.Violet, Color.Red, Color.Lime, Color.White, Color.DeepSkyBlue };
      var font = new Font("Consolas", 22, FontStyle.Bold);
      for (int k = 0; k < polys.Length; k++) {
        var flat = polys[k];
        var pts = new List<PointF>();
        for (int i = 0; i + 1 < flat.Length; i += 2) pts.Add(new PointF(flat[i], flat[i + 1]));
        if (pts.Count < 2) continue;
        using (var pen = new Pen(colors[k % colors.Length], 3)) g.DrawPolygon(pen, pts.ToArray());
        using (var brush = new SolidBrush(colors[k % colors.Length])) g.DrawString(names[k], font, brush, pts[0].X + 6, pts[0].Y + 6);
      }
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Composite parts in the given order over a checkerboard.
  public static string Preview(string[] parts, string outPath, int width) {
    using (var first = new Bitmap(parts[0]))
    using (var bmp = new Bitmap(width, (int)(first.Height * (double)width / first.Width), PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      int cell = Math.Max(10, width / 28);
      for (int y = 0; y < bmp.Height; y += cell)
        for (int x = 0; x < bmp.Width; x += cell) {
          bool on = ((x / cell) + (y / cell)) % 2 == 0;
          using (var brush = new SolidBrush(on ? Color.FromArgb(255, 60, 60, 70) : Color.FromArgb(255, 34, 34, 42)))
            g.FillRectangle(brush, x, y, cell, cell);
        }
      foreach (var p in parts) using (var layer = new Bitmap(p)) g.DrawImage(layer, 0, 0, bmp.Width, bmp.Height);
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }

  /// Face avatar straight out of a layer.
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

$src = 'C:\Users\l\.dsh\attachments\v1\objects\3e\3ef5a5982b235b326ec9c6632a50c74bbfb70fc0174d2962176a7dfa01f4f213'
$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
function P($n) { return (Join-Path $dir $n) }

$tail   = P 'pet6-tail.png'
$outL1  = P 'pet6-hair-l1.png'
$outL2  = P 'pet6-hair-l2.png'
$outR1  = P 'pet6-hair-r1.png'
$outR2  = P 'pet6-hair-r2.png'
$ahoge  = P 'pet6-ahoge.png'
$laptop = P 'pet6-laptop.png'
$torso  = P 'pet6-torso.png'
$head   = P 'pet6-head.png'
$avatar = P 'pet6-avatar.png'
$map    = P 'parts-map.png'
$prev   = P 'preview-parts.png'

# torso keeps a static copy of everything (minus tail/ahoge/laptop): the hair
# layers are painted on top, so a swaying strand never opens a gap -- it just
# uncovers the identical static pixels underneath.
$torsoEx = @($tailPoly, $ahogeRect, $laptopPoly)
$allRect = @(0,0, 1312,0, 1312,1199, 0,1199)
$noTail = @($tailPoly)
$noTailLaptop = @($tailPoly, $laptopPoly)

[PetParts]::Part($src, $tail,   $tailPoly,   @()) | Out-Null
[PetParts]::Part($src, $outL2,  $hairL2,     $noTailLaptop) | Out-Null
[PetParts]::Part($src, $outL1,  $hairL,      @($tailPoly, $laptopPoly, $hairL2)) | Out-Null
[PetParts]::Part($src, $outR2,  $hairR2,     $noTail) | Out-Null
[PetParts]::Part($src, $outR1,  $hairR,      @($tailPoly, $hairR2)) | Out-Null
[PetParts]::Part($src, $ahoge,  $ahogeRect,  @()) | Out-Null
[PetParts]::Part($src, $laptop, $laptopPoly, @()) | Out-Null
[PetParts]::Part($src, $torso,  $allRect,    $torsoEx) | Out-Null

[PetParts]::Map($src, $map, @('tail','hairL','hairL2','hairR','hairR2','ahoge','laptop','head'),
  @($tailPoly, $hairL, $hairL2, $hairR, $hairR2, $ahogeRect, $laptopPoly)) | Out-Null
[PetParts]::Preview(@($tail, $outL1, $outL2, $outR1, $outR2, $ahoge, $laptop, $torso, $head), $prev, 900) | Out-Null
[PetParts]::Avatar($head, $avatar, 0.255, 0.365, 0.31, 0.34, 220) | Out-Null

$total = 0
foreach ($f in $tail, $outL1, $outL2, $outR1, $outR2, $ahoge, $laptop, $torso, $head, $avatar) {
  $len = (Get-Item $f).Length
  $total += $len
  Write-Output ((Split-Path $f -Leaf).PadRight(20) + $len + ' bytes')
}
Write-Output ('total parts = ' + [math]::Round($total / 1MB, 2) + ' MB')

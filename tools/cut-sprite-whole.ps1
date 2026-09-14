$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing

# One flattened sprite: the whole character as a single layer, so no seam can
# ever appear between parts. Alpha comes straight from the artist's matte.
$cs = @"
using System;
using System.Drawing;
using System.Drawing.Imaging;

public static class PetWhole {
  public static string Whole(string src, string outPath) {
    using (var img = new Bitmap(src))
    using (var outBmp = new Bitmap(img.Width, img.Height, PixelFormat.Format32bppArgb)) {
      int w = img.Width, h = img.Height;
      var d = img.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
      var px = new byte[w * h * 4];
      System.Runtime.InteropServices.Marshal.Copy(d.Scan0, px, 0, px.Length);
      img.UnlockBits(d);
      var outBytes = new byte[w * h * 4];
      for (int i = 0; i < w * h; i++) {
        byte a = px[i * 4 + 3];
        outBytes[i * 4] = px[i * 4];
        outBytes[i * 4 + 1] = px[i * 4 + 1];
        outBytes[i * 4 + 2] = px[i * 4 + 2];
        outBytes[i * 4 + 3] = a <= 4 ? (byte)0 : (a >= 249 ? (byte)255 : a);
      }
      var od = outBmp.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.WriteOnly, PixelFormat.Format32bppArgb);
      System.Runtime.InteropServices.Marshal.Copy(outBytes, 0, od.Scan0, outBytes.Length);
      outBmp.UnlockBits(od);
      outBmp.Save(outPath, ImageFormat.Png);
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

  public static string Preview(string src, string outPath, int width) {
    using (var img = new Bitmap(src))
    using (var bmp = new Bitmap(width, (int)(img.Height * (double)width / img.Width), PixelFormat.Format32bppArgb))
    using (var g = Graphics.FromImage(bmp)) {
      int cell = Math.Max(10, width / 28);
      for (int y = 0; y < bmp.Height; y += cell)
        for (int x = 0; x < bmp.Width; x += cell) {
          bool on = ((x / cell) + (y / cell)) % 2 == 0;
          using (var brush = new SolidBrush(on ? Color.FromArgb(255, 60, 60, 70) : Color.FromArgb(255, 34, 34, 42)))
            g.FillRectangle(brush, x, y, cell, cell);
        }
      g.DrawImage(img, 0, 0, bmp.Width, bmp.Height);
      bmp.Save(outPath, ImageFormat.Png);
    }
    return outPath;
  }
}
"@
Add-Type -TypeDefinition $cs -ReferencedAssemblies System.Drawing

$src = 'C:\Users\l\.dsh\attachments\v1\objects\3e\3ef5a5982b235b326ec9c6632a50c74bbfb70fc0174d2962176a7dfa01f4f213'
$dir = 'C:\Users\l\.dsh\plugins\dsh-pet\assets'
$full = Join-Path $dir 'pet7-full.png'
$avatar = Join-Path $dir 'pet7-avatar.png'
$preview = Join-Path $dir 'preview-whole.png'

[PetWhole]::Whole($src, $full) | Out-Null
[PetWhole]::Avatar($full, $avatar, 0.26, 0.23, 0.32, 0.34, 220) | Out-Null
[PetWhole]::Preview($full, $preview, 900) | Out-Null

foreach ($f in $full, $avatar, $preview) {
  Write-Output ((Split-Path $f -Leaf).PadRight(20) + [math]::Round((Get-Item $f).Length / 1KB) + ' KB')
}

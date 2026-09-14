<#
  把 install.ps1 / uninstall.ps1 编译成双击即用的 install.exe / uninstall.exe

  原理：把 PowerShell 脚本以 base64 形式嵌进一个极小的 C# 启动器，启动器在运行时
  把脚本释放到临时目录并调用 powershell 执行（脚本内容与仓库里的 .ps1 完全一致，
  只是包了一层 exe 外壳，双击即可，不需要用户理解执行策略）。

  编译用系统自带的 csc.exe（.NET Framework 4.x），不需要安装任何额外工具。
  用法：powershell -NoProfile -ExecutionPolicy Bypass -File tools\build-exe.ps1
#>
$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
$icon = 'C:\Users\l\Desktop\DeepSeek Harness.ico'

$csc = $null
foreach ($p in @(
  (Join-Path $env:windir 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'),
  (Join-Path $env:windir 'Microsoft.NET\Framework\v4.0.30319\csc.exe')
)) { if (Test-Path $p) { $csc = $p; break } }
if (-not $csc) { throw '找不到 csc.exe（需要 .NET Framework 4.x）' }

function Build-Exe {
  param(
    [string]$ScriptPath,      # 要嵌入的 .ps1
    [string]$OutName,         # 产物文件名
    [bool]$PassSourceDir,     # 是否把 exe 所在目录作为 -SourceDir 传给脚本
    [bool]$Hidden = $false,   # 静默模式：不显示控制台窗口（用于启动器）
    [bool]$ForwardArgs = $false # 是否把命令行参数透传给内嵌脚本
  )

  $bytes = [System.IO.File]::ReadAllBytes($ScriptPath)
  $b64 = [Convert]::ToBase64String($bytes)
  $scriptName = Split-Path -Leaf $ScriptPath

  $cs = @"
using System;
using System.Diagnostics;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;

internal static class PetLauncher
{
    private const string ScriptB64 = "$b64";
    private const string ScriptName = "$scriptName";
    private const bool PassSourceDir = $(if ($PassSourceDir) { 'true' } else { 'false' });
    private const bool Hidden = $(if ($Hidden) { 'true' } else { 'false' });
    private const bool ForwardArgs = $(if ($ForwardArgs) { 'true' } else { 'false' });

    [DllImport("kernel32.dll")]
    private static extern IntPtr GetConsoleWindow();
    [DllImport("user32.dll")]
    private static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    private static int Main(string[] args)
    {
        if (Hidden)
        {
            // 不用 winexe（产物会被本机安全软件吃掉），改用普通 exe 自己藏窗口
            try { ShowWindow(GetConsoleWindow(), 0); } catch { }
        }
        string exeDir = AppDomain.CurrentDomain.BaseDirectory;
        string work = Path.Combine(Path.GetTempPath(), "dsh-pet-" + Guid.NewGuid().ToString("N").Substring(0, 8));
        string script = Path.Combine(work, ScriptName);
        try
        {
            Directory.CreateDirectory(work);
            File.WriteAllBytes(script, Convert.FromBase64String(ScriptB64));

            var psi = new ProcessStartInfo("powershell.exe");
            var sb = new StringBuilder();
            sb.Append("-NoProfile -ExecutionPolicy Bypass -File \"").Append(script).Append("\"");
            if (PassSourceDir) sb.Append(" -SourceDir \"").Append(exeDir.TrimEnd('\\')).Append("\"");
            if (ForwardArgs)
            {
                foreach (string extra in args)
                {
                    // 只有明确需要透传的产物（install/uninstall 的 -Yes）才转发，
                    // 否则快捷方式里残留的 PowerShell 宿主参数会让脚本直接报错。
                    if (extra == "--no-pause") continue;
                    sb.Append(' ').Append(extra);
                }
            }
            sb.Append(" -WindowStyle Hidden");
            psi.Arguments = sb.ToString();
            psi.UseShellExecute = false;
            psi.CreateNoWindow = Hidden;

            var p = Process.Start(psi);
            p.WaitForExit();

            if (!Hidden && Environment.UserInteractive && Array.IndexOf(args, "--no-pause") < 0)
            {
                Console.WriteLine();
                Console.Write("按回车键关闭窗口...");
                Console.ReadLine();
            }
            return p.ExitCode;
        }
        catch (Exception ex)
        {
            Console.WriteLine("启动失败：" + ex.Message);
            if (Environment.UserInteractive) { Console.Write("按回车键关闭窗口..."); Console.ReadLine(); }
            return 1;
        }
        finally
        {
            try { if (File.Exists(script)) File.Delete(script); if (Directory.Exists(work)) Directory.Delete(work, true); } catch { }
        }
    }
}
"@

  $csPath = Join-Path $env:TEMP ("petlauncher-" + $OutName + ".cs")
  [System.IO.File]::WriteAllText($csPath, $cs, (New-Object System.Text.UTF8Encoding($true)))

  $outPath = Join-Path $root $OutName
  $args = @('/nologo', '/target:exe', '/platform:anycpu', '/optimize+', '/codepage:65001')
  if (Test-Path $icon) { $args += ('/win32icon:' + $icon) }
  $args += @(('/out:' + $outPath), $csPath)

  $log = & $csc @args 2>&1
  if (-not (Test-Path $outPath)) {
    Write-Host ($log | Out-String) -ForegroundColor Red
    throw "编译失败：$OutName"
  }
  Remove-Item $csPath -Force -ErrorAction SilentlyContinue
  Write-Host ("  [ok] $OutName  " + [math]::Round((Get-Item $outPath).Length / 1KB) + ' KB') -ForegroundColor Green
}

Write-Host "==> 编译 exe 启动器（csc: $csc）" -ForegroundColor Cyan
if (-not (Test-Path $icon)) { Write-Host "  [!]  图标不存在，将使用默认图标：$icon" -ForegroundColor Yellow }
Build-Exe -ScriptPath (Join-Path $root 'install.ps1') -OutName 'install.exe' -PassSourceDir $true -ForwardArgs $true
Build-Exe -ScriptPath (Join-Path $root 'uninstall.ps1') -OutName 'uninstall.exe' -PassSourceDir $false -ForwardArgs $true
$launcher = Join-Path $root 'start-dsh-pet.ps1'
if (Test-Path $launcher) {
  Build-Exe -ScriptPath $launcher -OutName 'start-dsh-pet.exe' -PassSourceDir $false -Hidden $true
}
Write-Host "完成：install.exe 安装 / uninstall.exe 卸载 / start-dsh-pet.exe 启动（静默）" -ForegroundColor Green

# 关闭器：静默 exe，双击即把看板娘关掉
$stopper = Join-Path $root 'stop-dsh-pet.ps1'
if (Test-Path $stopper) {
  Build-Exe -ScriptPath $stopper -OutName 'stop-dsh-pet.exe' -PassSourceDir $false -Hidden $true
}
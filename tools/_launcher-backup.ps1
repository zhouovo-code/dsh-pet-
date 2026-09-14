# DeepSeek Harness desktop launcher (stable)
# Invoked by the desktop shortcut through a hidden PowerShell window.
# Goal: always bring up the *right* GUI instance, exactly one page, no guessing.
param(
  [switch]$Probe
)

$ErrorActionPreference = 'SilentlyContinue'

$stateDir   = Join-Path $env:LOCALAPPDATA 'DeepSeekHarness'
$stateFile  = Join-Path $stateDir 'state.json'
$logFile    = Join-Path $stateDir 'server.log'
$cmdFile    = Join-Path $stateDir 'dsh-server.cmd'

# Port used only when this launcher has to start a server itself: the plain
# "npx @deepseek-ai/dsh web" default, so the address stays the familiar
# http://127.0.0.1:3080. If that port is taken, the OS assigns a free one and the
# authenticated URL printed by dsh is used instead. An already running instance
# is always detected on whatever port it actually listens on.
$preferPort = 3080

# Window-title fingerprint of a real GUI page (a real page title is
# "<session title> - DeepSeek Harness" and browsers append their own name).
# The dash class covers hyphen, en dash and em dash; it keeps look-alike pages
# such as "DeepSeek Harness download guide" from matching.
$dash = '[' + [char]0x2013 + [char]0x2014 + '-]'
$titlePattern = 'DeepSeek Harness\s*' + $dash + '\s*(Mozilla Firefox|Firefox|Google Chrome|Chrome|Microsoft Edge|Edge|Brave|Opera|Vivaldi|Chromium)'

# ---------------------------------------------------------------- native helpers
try {
  Add-Type -TypeDefinition @'
using System;
using System.Text;
using System.Text.RegularExpressions;
using System.Runtime.InteropServices;

public static class DshWin {
  public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);

  [DllImport("user32.dll")]
  private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
  [DllImport("user32.dll")]
  private static extern bool IsWindowVisible(IntPtr hWnd);
  [DllImport("user32.dll", CharSet = CharSet.Unicode)]
  private static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
  [DllImport("user32.dll")]
  public static extern bool SetForegroundWindow(IntPtr hWnd);
  [DllImport("user32.dll")]
  public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);
  [DllImport("user32.dll")]
  public static extern IntPtr GetForegroundWindow();
  [DllImport("user32.dll")]
  public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
  [DllImport("user32.dll")]
  public static extern bool AttachThreadInput(uint idAttach, uint idAttachTo, bool fAttach);
  [DllImport("kernel32.dll")]
  public static extern uint GetCurrentThreadId();

  public static IntPtr FindByRegex(string pattern) {
    IntPtr found = IntPtr.Zero;
    Regex rx = new Regex(pattern, RegexOptions.IgnoreCase);
    EnumWindows(delegate(IntPtr hWnd, IntPtr lParam) {
      if (IsWindowVisible(hWnd)) {
        StringBuilder sb = new StringBuilder(512);
        GetWindowText(hWnd, sb, 512);
        if (rx.IsMatch(sb.ToString())) { found = hWnd; return false; }
      }
      return true;
    }, IntPtr.Zero);
    return found;
  }

  public static void FocusWindow(IntPtr hWnd) {
    if (hWnd == IntPtr.Zero) return;
    ShowWindow(hWnd, 9); // SW_RESTORE
    uint fgThread = 0;
    uint targetThread = 0;
    uint selfThread = GetCurrentThreadId();
    GetWindowThreadProcessId(GetForegroundWindow(), out fgThread);
    GetWindowThreadProcessId(hWnd, out targetThread);
    try {
      if (fgThread != 0 && fgThread != selfThread) AttachThreadInput(selfThread, fgThread, true);
      if (targetThread != 0 && targetThread != selfThread) AttachThreadInput(selfThread, targetThread, true);
      SetForegroundWindow(hWnd);
      if (fgThread != 0 && fgThread != selfThread) AttachThreadInput(selfThread, fgThread, false);
      if (targetThread != 0 && targetThread != selfThread) AttachThreadInput(selfThread, targetThread, false);
    } catch { }
  }
}
'@
} catch { }

# ---------------------------------------------------------------- small utilities
# Raw HTTP status without following redirects and without throwing on 4xx.
function Get-Status([string]$url) {
  try {
    $req = [System.Net.HttpWebRequest]::Create($url)
    $req.AllowAutoRedirect = $false
    $req.Timeout = 3000
    $req.Method = 'GET'
    $resp = $req.GetResponse()
    $code = [int]$resp.StatusCode
    $resp.Close()
    return $code
  } catch [System.Net.WebException] {
    if ($_.Exception.Response -ne $null) { return [int]$_.Exception.Response.StatusCode }
    return -1
  } catch { return -1 }
}

function Test-TcpPort([int]$port) {
  try {
    $client = New-Object System.Net.Sockets.TcpClient
    $iar = $client.BeginConnect('127.0.0.1', $port, $null, $null)
    $ok = $iar.AsyncWaitHandle.WaitOne(500, $false)
    $up = $ok -and $client.Connected
    $client.Close()
    return $up
  } catch { return $false }
}

# A port is a DeepSeek Harness GUI when a node process listens on loopback and
# the unauthenticated frontend manifest answers 200 there.
function Test-DshPort([int]$port, [int]$procId) {
  if (-not (Test-TcpPort $port)) { return $false }
  try {
    if ($procId -gt 0) {
      $p = Get-Process -Id $procId -ErrorAction Stop
      if ($p.ProcessName -ne 'node') { return $false }
    }
  } catch { }
  $code = Get-Status ('http://127.0.0.1:' + $port + '/manifest.webmanifest')
  return ($code -eq 200)
}

# All live DSH GUI instances, newest first.
function Get-DshInstances {
  $result = New-Object System.Collections.ArrayList
  $seen = @{}
  $listeners = New-Object System.Collections.ArrayList
  foreach ($line in (netstat -ano | Select-String 'LISTENING')) {
    $f = @(($line.ToString() -split '\s+') | Where-Object { $_ -ne '' })
    if ($f.Count -lt 5) { continue }
    if ($f[0] -ne 'TCP') { continue }
    $local = $f[1]
    if ($local -notmatch '^127\.0\.0\.1:(\d+)$') { continue }
    [void]$listeners.Add([pscustomobject]@{ Port = [int]$Matches[1]; Pid = [int]$f[4] })
  }
  foreach ($l in $listeners) {
    if ($seen.ContainsKey($l.Port)) { continue }
    $seen[$l.Port] = $true
    if (-not (Test-DshPort $l.Port $l.Pid)) { continue }
    $start = [datetime]::MinValue
    try { $start = (Get-Process -Id $l.Pid -ErrorAction Stop).StartTime } catch { }
    [void]$result.Add([pscustomobject]@{ Port = $l.Port; Pid = $l.Pid; Started = $start })
  }
  return @($result | Sort-Object -Property Started -Descending)
}

function Get-StoredTokenUrl {
  try {
    if (-not (Test-Path $stateFile)) { return $null }
    $s = Get-Content -Raw $stateFile | ConvertFrom-Json
    if ($s.TokenUrl -and $s.TokenUrl -match '^http://127\.0\.0\.1:\d+/\?token=') { return [string]$s.TokenUrl }
  } catch { }
  return $null
}

function Save-State([string]$tokenUrl, [int]$port) {
  try {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    [pscustomobject]@{
      TokenUrl  = $tokenUrl
      Port      = $port
      UpdatedAt = (Get-Date).ToString('s')
    } | ConvertTo-Json | Set-Content -Path $stateFile -Encoding UTF8
    return (Test-Path $stateFile)
  } catch { return $false }
}

# Short decision log: makes "why did it do that" answerable after the fact.
function Write-Log([string]$msg) {
  try {
    New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
    $log = Join-Path $stateDir 'launcher.log'
    if ((Test-Path $log) -and ((Get-Item $log).Length -gt 262144)) { Remove-Item $log -Force }
    Add-Content -Path $log -Value ((Get-Date).ToString('yyyy-MM-dd HH:mm:ss') + '  ' + $msg)
  } catch { }
}

# NOTE: always call Get-DshInstances through @(...). A bare assignment unwraps a
# one-element result into a scalar, and a scalar PSCustomObject has no .Count
# before PowerShell 6, which silently disables the "no instance" decision.


# ---------------------------------------------------------------- page opening
# Focus an already open GUI page instead of piling up new tabs.
function Open-Once([string]$url) {
  try {
    $h = [DshWin]::FindByRegex($titlePattern)
    if ($h -ne [IntPtr]::Zero) {
      [DshWin]::FocusWindow($h)
      return
    }
  } catch { }
  Start-Process $url
}

# ---------------------------------------------------------------- server start
# Prefer the already-installed copy: no npm resolution, no network, fast.
function Get-LocalLaunchCommand {
  $node = (Get-Command node.exe -ErrorAction SilentlyContinue).Source
  if (-not $node) { $node = (Get-Command node -ErrorAction SilentlyContinue).Source }
  if (-not $node) { return $null }
  $roots = @()
  if ($env:LOCALAPPDATA) { $roots += (Join-Path $env:LOCALAPPDATA 'npm-cache\_npx') }
  if ($env:APPDATA) { $roots += (Join-Path $env:APPDATA 'npm-cache\_npx') }
  $bins = @()
  foreach ($root in $roots) {
    if (-not (Test-Path $root)) { continue }
    foreach ($dir in (Get-ChildItem $root -Directory -ErrorAction SilentlyContinue)) {
      $cand = Join-Path $dir.FullName 'node_modules\@deepseek-ai\dsh\lib\bin.js'
      if (Test-Path $cand) { $bins += (Get-Item $cand) }
    }
  }
  if ($bins.Count -eq 0) { return $null }
  $bin = $bins | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1
  return ('"' + $node + '" "' + $bin.FullName + '"')
}

function Start-DshServer {
  New-Item -ItemType Directory -Path $stateDir -Force | Out-Null
  Remove-Item $logFile -Force -ErrorAction SilentlyContinue

  $base = Get-LocalLaunchCommand
  if (-not $base) { $base = 'npx --yes @deepseek-ai/dsh' }

  # Keep the familiar authority when it is free so an existing browser cookie
  # for that host:port keeps working; otherwise let the OS assign one.
  $port = $preferPort
  if (Test-TcpPort $port) { $port = 0 }

  $launch = $base + ' web --no-open --port ' + $port
  $cmd = "@echo off`r`ntitle DeepSeek Harness server`r`ncd /d `"%USERPROFILE%`"`r`n" +
         $launch + ' > "' + $logFile + '" 2>&1' + "`r`n"
  Set-Content -Path $cmdFile -Value $cmd -Encoding ASCII

  Start-Process -FilePath $cmdFile -WindowStyle Minimized

  $deadline = (Get-Date).AddSeconds(150)
  while ((Get-Date) -lt $deadline) {
    Start-Sleep -Milliseconds 700
    if (Test-Path $logFile) {
      # A freshly created log is empty: Get-Content -Raw then returns $null, and
      # [regex]::Match($null, ...) throws a *terminating* error that would kill
      # this launcher silently. Always coerce to a string first.
      $txt = [string](Get-Content -Raw $logFile)
      if ($txt.Length -gt 0) {
        $m = [regex]::Match($txt, 'http://127\.0\.0\.1:\d+/\?token=[A-Za-z0-9_\-]+')
        if ($m.Success) { return $m.Value }
      }
    }
  }
  return $null
}

function Show-Failure([string]$text) {
  try {
    $vbs = Join-Path $env:TEMP ('dsh_fail_' + [guid]::NewGuid().ToString('N') + '.vbs')
    Set-Content -Path $vbs -Value ('MsgBox "' + $text + '", 48, "DeepSeek Harness"') -Encoding ASCII
    Start-Process wscript.exe -ArgumentList ('"' + $vbs + '"') -Wait
    Remove-Item $vbs -Force
  } catch { }
}

# ---------------------------------------------------------------- main
# Only one launcher run may start a server at a time.
$mtx = New-Object System.Threading.Mutex($false, 'Local\DshWebLauncher')
$haveLock = $mtx.WaitOne(0)

if (-not $haveLock) {
  Write-Log 'another launcher run holds the lock; waiting for its server'
  for ($i = 0; $i -lt 90; $i++) {
    Start-Sleep -Seconds 1
    $others = @(Get-DshInstances)
    if ($others.Count -gt 0 -and $others[0].Port) {
      Write-Log ('lock-wait: opening port ' + $others[0].Port)
      Open-Once ('http://127.0.0.1:' + $others[0].Port + '/')
      exit 0
    }
  }
  Write-Log 'lock-wait: gave up waiting'
  exit 0
}

try {
  $serialized = @((Get-DshInstances) | ForEach-Object { $_.Port }) -join ','
  if ($Probe) {
    Write-Output ('stored token url: ' + (Get-StoredTokenUrl))
    foreach ($i in (Get-DshInstances)) { Write-Output ('instance port=' + $i.Port + ' pid=' + $i.Pid + ' started=' + $i.Started) }
    $h = [DshWin]::FindByRegex($titlePattern)
    Write-Output ('gui window handle: ' + $h)
    Write-Output ('local launch base: ' + (Get-LocalLaunchCommand))
    Write-Output ('preferred cold-start port: ' + $preferPort)
    Write-Output ('log file: ' + (Join-Path $stateDir 'launcher.log'))
    exit 0
  }
  Write-Log ('start; live dsh ports = [' + $serialized + ']')

  # 1) A GUI instance is already running (started by this launcher, by a manual
  #    "npx @deepseek-ai/dsh web", or by an earlier session). Use the newest one:
  #    that is the instance the user most recently brought up, and typically the
  #    one their browser already holds a login cookie for.
  $instances = @(Get-DshInstances)
  if ($instances.Count -gt 0 -and $instances[0].Port) {
    $targetPort = [int]$instances[0].Port
    $target = 'http://127.0.0.1:' + $targetPort + '/'

    # If this is the instance we started ourselves, its stored token URL is the
    # best link: it mints a fresh browser cookie even after the cookie expired.
    $stored = Get-StoredTokenUrl
    if ($stored) {
      $storedPort = 0
      if ($stored -match '^http://127\.0\.0\.1:(\d+)/') { $storedPort = [int]$Matches[1] }
      if ($storedPort -eq $targetPort) {
        $status = Get-Status $stored
        Write-Log ('stored token url for port ' + $storedPort + ' status=' + $status)
        if ($status -eq 303) { $target = $stored }
      }
    }

    Write-Log ('attaching to newest live instance: ' + $target)
    Open-Once $target
    exit 0
  }

  # 2) Nothing is running: start one, then open the authenticated URL it prints.
  #    The page is opened directly (not focused) because any browser window left
  #    over from a dead instance cannot be showing this brand-new one.
  $url = Start-DshServer
  if ($url) {
    $port = 0
    if ($url -match '^http://127\.0\.0\.1:(\d+)/') { $port = [int]$Matches[1] }
    Write-Log ('started new instance on port ' + $port + '; opening token url')
    $saved = Save-State $url $port
    Write-Log ('state saved: ' + $saved)
    Start-Process $url
    exit 0
  }

  Write-Log 'start failed: no token url within 150s'
  Show-Failure 'DeepSeek Harness did not start within 150 seconds. Check the "DeepSeek Harness server" console window for errors.'
  exit 1
} catch {
  # Never die silently: record the reason so the next run can be diagnosed.
  Write-Log ('ERROR: ' + $_.Exception.GetType().FullName + ' | ' + $_.Exception.Message)
  Write-Log ('AT: ' + $_.InvocationInfo.PositionMessage)
  Show-Failure ('DeepSeek Harness launcher failed: ' + $_.Exception.Message + '  (see launcher.log in %LOCALAPPDATA%\DeepSeekHarness)')
  exit 1
} finally {
  try { $mtx.ReleaseMutex() } catch { }
}


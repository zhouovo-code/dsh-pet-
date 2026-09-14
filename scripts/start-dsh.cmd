@echo off
chcp 936 >nul
setlocal EnableExtensions
title dsh-pet 看板娘余额挂件

if defined DSH_HOME (set "DH=%DSH_HOME%") else (set "DH=%USERPROFILE%\.dsh")
set "TARGET=%DH%\plugins\dsh-pet"

cls
echo.
echo    ┌──────────────────────────────────────────────────┐
echo    │   dsh-pet   ·   看板娘余额挂件                   │
echo    │   打开挂件  ／  启动或切换 DSH                   │
echo    └──────────────────────────────────────────────────┘
echo.

if not exist "%TARGET%\data" (
  echo    [×] 没有找到插件：
  echo        %TARGET%
  echo.
  echo        请先双击 install.cmd 完成安装，再回来运行本启动器。
  echo.
  pause
  exit /b 1
)

>"%TARGET%\data\enabled.json" echo {"enabled":true}
echo    [√] 挂件开关        已打开

rem ---- 找一个真正的 DSH 端口：先试 3080，再逐个用 manifest 探测 ----
set "LIVE="
call :probe 3080
if not defined LIVE call :scan

if defined LIVE (
  echo    [√] DSH 实例        端口 %LIVE%
  call :show %LIVE%
  exit /b 0
)

rem ---- 没在跑：启动本地缓存的 DSH，然后等它就绪 ----
set "BIN="
for /d %%D in ("%LOCALAPPDATA%\npm-cache\_npx\*") do (
  if exist "%%D\node_modules\@deepseek-ai\dsh\lib\bin.js" set "BIN=%%D\node_modules\@deepseek-ai\dsh\lib\bin.js"
)
if not defined BIN (
  echo    [×] 没找到本地缓存的 DSH 版本
  echo.
  echo        请先运行一次这个命令，再回来用本启动器：
  echo            npx @deepseek-ai/dsh web
  echo.
  pause
  exit /b 1
)

echo    [i] 没检测到运行中的 DSH，正在启动（窗口最小化）…
start "DeepSeek Harness server" /min cmd /c node "%BIN%" web

echo    [i] 等待它就绪（最多约 40 秒）…
for /l %%N in (1,1,20) do (
  if not defined LIVE (
    ping -n 2 127.0.0.1 >nul 2>&1
    call :probe 3080
    if not defined LIVE call :scan
  )
)

if defined LIVE (
  echo    [√] DSH 已就绪        端口 %LIVE%
  call :show %LIVE%
  exit /b 0
)

echo    [×] 40 秒内没有起来。
echo.
echo        请在一个终端里手动执行，看它的报错：
echo            npx @deepseek-ai/dsh web
echo.
pause
exit /b 1

rem ================= 子过程 =================

rem 探测某个端口是不是 DSH（manifest 返回 200 才算）
:probe
set "CODE=000"
for /f "delims=" %%C in ('curl.exe -s -o NUL -w "%%{http_code}" --max-time 3 "http://127.0.0.1:%~1/manifest.webmanifest" 2^>NUL') do set "CODE=%%C"
if "%CODE%"=="200" set "LIVE=%~1"
exit /b 0

rem 扫描所有 127.0.0.1 监听端口，逐个探测（跳过已经确定的）
:scan
for /f "tokens=3 delims=: " %%P in ('netstat -ano ^| findstr /C:"LISTENING" ^| findstr /C:"127.0.0.1:"') do (
  if not defined LIVE call :probe %%P
)
exit /b 0

rem 展示结果：先尝试切到已打开的页面；否则提示按 O 才新开
:show
set "PORT=%~1"
set "URL=http://127.0.0.1:%PORT%/"
set "FOCUSED="
for /f "delims=" %%R in ('cscript //nologo "%~dp0focus-or-open.vbs" "%URL%" "DeepSeek Harness" 2^>NUL') do set "FOCUSED=%%R"
if "%FOCUSED%"=="focused" (
  echo    [√] 已切到你打开的 DSH 页面
  echo.
  echo    ──────────────────────────────────────────────────
  echo    完成！她就在这个页面右下角。
  ping -n 4 127.0.0.1 >nul 2>&1
  exit /b 0
)
echo    [i] 回到你已打开的 DSH 页面即可（4 秒内出现）
echo    [i] 没开着页面的话：地址是 %URL%
echo.
choice /c ON /n /t 8 /d N /m "按 O 打开新页面 / 按 N 或 8 秒后自动结束： " 2>NUL
if errorlevel 2 (
  echo    ──────────────────────────────────────────────────
  echo    完成！她会在你打开的页面里出现。
  exit /b 0
)
echo    [i] 正在打开 %URL% …
start "" "%URL%"
echo    ──────────────────────────────────────────────────
echo    完成！她会在几秒内出现。
ping -n 4 127.0.0.1 >nul 2>&1
exit /b 0
@echo off
rem dsh-pet 安装（纯批处理：不调用 PowerShell、不内嵌脚本、无 Bypass）
rem 双击即可安装；可以重复运行。
chcp 936 >nul
setlocal EnableExtensions
title dsh-pet 看板娘余额挂件 - 安装

set "SRC=%~dp0"
if "%SRC:~-1%"=="\" set "SRC=%SRC:~0,-1%"

if defined DSH_HOME (set "DH=%DSH_HOME%") else (set "DH=%USERPROFILE%\.dsh")
set "TARGET=%DH%\plugins\dsh-pet"
set "PATCH=%DH%\profiles\web\cordis.patch.yml"

echo.
echo   dsh-pet 看板娘余额挂件 - 安装
echo   ==============================
echo   DSH 目录 : %DH%
echo   安装到   : %TARGET%
echo.

if not exist "%DH%" echo   [!] 没找到 %DH%  —— 如果你还没用过 DSH，请先运行一次 DSH Web 再安装。

if not exist "%DH%\plugins" mkdir "%DH%\plugins"
if not exist "%TARGET%" mkdir "%TARGET%"
if not exist "%TARGET%\data" mkdir "%TARGET%\data"

set "COPIED=0"
for %%D in (lib assets) do (
  if exist "%SRC%\plugin\%%D" (
    if not exist "%TARGET%\%%D" mkdir "%TARGET%\%%D"
    xcopy "%SRC%\plugin\%%D\*" "%TARGET%\%%D\" /E /I /Y /Q >nul
    set "COPIED=1"
  )
)
if exist "%SRC%\plugin\package.json" copy /Y "%SRC%\plugin\package.json" "%TARGET%\package.json" >nul
for %%F in (README.md LICENSE) do (
  if exist "%SRC%\%%F" copy /Y "%SRC%\%%F" "%TARGET%\%%F" >nul
)

if "%COPIED%"=="0" (
  echo   [x] 没有找到 plugin\lib 或 plugin\assets 目录。
  echo       请先把整个压缩包解压，再运行解压目录里的「安装看板娘.cmd」。
  echo.
  pause
  exit /b 1
)
if not exist "%TARGET%\lib\host.js" (
  echo   [x] 复制失败：%TARGET%\lib\host.js 不存在。
  echo.
  pause
  exit /b 1
)
echo   [ok] 已复制插件本体（lib + assets + package.json）

if not exist "%DH%\profiles\web" mkdir "%DH%\profiles\web"
set "PFWD=%TARGET:\=/%"
set "URL=file:///%PFWD%/lib/host.js"

rem ---- 写配置：文件不存在或 0 字节 → 直接写；否则交给 install-patch.vbs 安全处理 ----
set "PSIZE=0"
if exist "%PATCH%" for %%A in ("%PATCH%") do set "PSIZE=%%~zA"
set "PRES="
if "%PSIZE%"=="0" (
  >"%PATCH%" echo - insert:
  >>"%PATCH%" echo     - id: dsh-pet
  >>"%PATCH%" echo       name: '%URL%'
  set "PRES=added"
) else (
  copy /Y "%PATCH%" "%PATCH%.bak" >nul
  for /f "delims=" %%R in ('cscript //nologo "%SRC%\scripts\install-patch.vbs" "%PATCH%" "%URL%" 2^>NUL') do set "PRES=%%R"
)

if "%PRES%"=="exists" (
  echo   [ok] 配置里已经有 dsh-pet，保持不变
) else if "%PRES%"=="added" (
  echo   [ok] 已写入配置（已有内容原样保留；改前备份为 cordis.patch.yml.bak）
) else if "%PRES%"=="nonascii" (
  echo   [!] 你的配置文件里有非 ASCII 内容（例如中文注释），脚本不敢自动改
  echo       请手动把下面这条加进 %PATCH% ：
  echo         - insert:
  echo             - id: dsh-pet
  echo               name: '%URL%'
) else (
  echo   [!] 配置写入脚本返回异常："%PRES%"
  echo       请手动把下面这条加进 %PATCH% ：
  echo         - insert:
  echo             - id: dsh-pet
  echo               name: '%URL%'
)

for %%F in (start-dsh.cmd stop-pet.cmd uninstall.cmd uninstall.vbs install-patch.vbs focus-or-open.vbs make-shortcuts.vbs) do (
  if exist "%SRC%\scripts\%%F" copy /Y "%SRC%\scripts\%%F" "%TARGET%\%%F" >nul
)
echo   [ok] 启动 / 关闭 / 卸载脚本已放进插件目录

set "MADE="
if exist "%TARGET%\make-shortcuts.vbs" (
  for /f "delims=" %%R in ('cscript //nologo "%TARGET%\make-shortcuts.vbs" "%TARGET%" 2^>NUL') do set "MADE=%%R"
)
if "%MADE%"=="ok" (
  echo   [ok] 已在桌面创建： 「启动看板娘」 「关闭看板娘」  ^(带图标^)
) else (
  echo   [!] 桌面快捷方式没建成：可右键 start-dsh.cmd -^> 发送到 -^> 桌面快捷方式
)

rem ---- 找真正的 DSH 端口（3080 优先，其余用 manifest 探测）----
set "LIVE="
call :probe 3080
if not defined LIVE call :scan
if defined LIVE (
  call :show %LIVE%
) else (
  echo   [i] 没检测到正在运行的 DSH：先运行 dsh web，再打开它打印的地址
  echo       然后在页面上按一次 Ctrl + Shift + R
)
goto :final

rem ================= 子过程 =================
:probe
set "CODE=000"
for /f "delims=" %%C in ('curl.exe -s -o NUL -w "%%{http_code}" --max-time 3 "http://127.0.0.1:%~1/manifest.webmanifest" 2^>NUL') do set "CODE=%%C"
if "%CODE%"=="200" set "LIVE=%~1"
exit /b 0

:scan
for /f "tokens=3 delims=: " %%P in ('netstat -ano ^| findstr /C:"LISTENING" ^| findstr /C:"127.0.0.1:"') do (
  if not defined LIVE call :probe %%P
)
exit /b 0

:show
set "PORT=%~1"
set "URL=http://127.0.0.1:%PORT%/"
set "FOCUSED="
for /f "delims=" %%R in ('cscript //nologo "%~dp0scripts\focus-or-open.vbs" "%URL%" "DeepSeek Harness" 2^>NUL') do set "FOCUSED=%%R"
if "%FOCUSED%"=="focused" (
  echo   [ok] 已切到你打开的 DSH 页面
  echo        在这个页面按一次 Ctrl + Shift + R 就能看到看板娘
  exit /b 0
)
echo   [i] 安装完成 —— 回到你已打开的 DSH 页面即可（按一次 Ctrl + Shift + R）
echo   [i] 页面没开着的话，地址是 %URL%
choice /c ON /n /t 8 /d N /m "     按 O 打开新页面 / 按 N 或 8 秒后自动结束： " 2>NUL
if errorlevel 2 exit /b 0
echo   [i] 正在打开 %URL% …
start "" "%URL%"
exit /b 0

:final
echo.
echo   安装完成！接下来：
echo     1. 先确认 DSH 正在运行（插件挂在 DSH 上，DSH 没跑就看不到她）
echo     2. 回到你打开的 DSH 页面，按一次 Ctrl + Shift + R —— 右下角就有她
echo     3. 看不到余额？那是还没配 DeepSeek API Key（不配也能用，只是余额区没数据）：
echo            setx DEEPSEEK_API_KEY "sk-你的key"      然后重开 DSH
echo.
echo   桌面快捷方式： 「启动看板娘」 打开她 / 「关闭看板娘」 彻底关掉她
echo   想彻底卸载：回到本解压目录，双击「卸载看板娘.cmd」
echo   详细排查：见本目录的 快速上手.txt
echo.
pause
endlocal
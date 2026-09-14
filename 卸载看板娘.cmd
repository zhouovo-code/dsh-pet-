@echo off
chcp 936 >nul
setlocal EnableExtensions EnableDelayedExpansion
title dsh-pet 卸载看板娘

set "YES="
if /i "%~1"=="/y" set "YES=1"

if defined DSH_HOME (set "DH=%DSH_HOME%") else (set "DH=%USERPROFILE%\.dsh")
set "TARGET=%DH%\plugins\dsh-pet"
set "PATCH=%DH%\profiles\web\cordis.patch.yml"
set "DESK=%DSH_PET_DESKTOP%"
if "%DESK%"=="" set "DESK=%USERPROFILE%\Desktop"

cls
echo.
echo    ┌──────────────────────────────────────────────────┐
echo    │   dsh-pet   ·   卸载看板娘                        │
echo    │   完整卸载：插件 + 桌面快捷方式 + DSH 配置条目     │
echo    └──────────────────────────────────────────────────┘
echo.
echo    将要删除 / 修改：
echo      1) 插件目录      %TARGET%
echo      2) 桌面快捷方式   启动看板娘 / 关闭看板娘 / 卸载看板娘
echo      3) 配置里的条目   %PATCH%
echo                        ^(只删 dsh-pet 那几行；其他插件配置原样保留；改前自动备份 .bak^)
echo.

if not defined YES (
  choice /c YN /n /t 20 /d N /m "    确认全部卸载？(Y=卸载 / N=取消) "
  if errorlevel 2 (
    echo.
    echo    已取消，什么都没有改动。
    ping -n 3 127.0.0.1 >nul 2>&1
    exit /b 0
  )
)

rem ---- 1) 先处理 DSH 配置（脚本在插件目录里，必须在删目录之前调用）----
set "VBS=%~dp0uninstall.vbs"
if not exist "%VBS%" set "VBS=%TARGET%\uninstall.vbs"
if exist "%VBS%" (
  if exist "%PATCH%" (
    set "RES="
    for /f "delims=" %%R in ('cscript //nologo "%VBS%" "%PATCH%" 2^>NUL') do set "RES=%%R"
    if defined RES (
      echo    [ok] DSH 配置已清理：!RES!   ^(备份 %PATCH%.bak^)
    ) else (
      echo    [!] 配置清理返回空，请手动检查 %PATCH%
    )
  ) else (
    echo    [i] 没有找到 %PATCH% ，跳过配置清理
  )
) else (
  echo    [!] 没找到 uninstall.vbs，配置里可能残留 dsh-pet 条目，请手动删除
)

rem ---- 2) 桌面快捷方式 ----
set "D=0"
for %%N in ("启动看板娘" "关闭看板娘" "卸载看板娘") do (
  if exist "%DESK%\%%~N.lnk" (
    del /f /q "%DESK%\%%~N.lnk" >nul 2>&1
    set /a D+=1
  )
)
echo    [ok] 已删除桌面快捷方式 !D! 个

rem ---- 3) 插件目录 ----
if exist "%TARGET%" (
  rd /s /q "%TARGET%" >nul 2>&1
  if exist "%TARGET%" (
    echo    [x] 插件目录删除失败（可能被占用）：%TARGET%
  ) else (
    echo    [ok] 插件目录已删除：%TARGET%
  )
) else (
  echo    [i] 插件目录本来就不存在
)

echo.
echo    ──────────────────────────────────────────────────
echo    卸载完成！刷新一下 DSH 页面（Ctrl + Shift + R），看板娘就消失了。
echo    想再装回来：重新解压安装包，双击「安装看板娘.cmd」即可。
echo.
ping -n 4 127.0.0.1 >nul 2>&1
endlocal

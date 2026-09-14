@echo off
chcp 936 >nul
setlocal EnableExtensions
title dsh-pet 看板娘余额挂件
cls

if defined DSH_HOME (set "DH=%DSH_HOME%") else (set "DH=%USERPROFILE%\.dsh")
set "TARGET=%DH%\plugins\dsh-pet"

echo.
echo    ┌──────────────────────────────────────────────────┐
echo    │   dsh-pet   ·   看板娘余额挂件                   │
echo    │   关闭挂件（连小圆牌也不显示）                   │
echo    └──────────────────────────────────────────────────┘
echo.

if not exist "%TARGET%\data" mkdir "%TARGET%\data" >nul 2>&1
>"%TARGET%\data\enabled.json" echo {"enabled":false}

if errorlevel 1 (
  echo    [×] 无法写入：
  echo        %TARGET%\data\enabled.json
  echo.
  pause
  exit /b 1
)

echo    [√] 挂件开关        已关闭
echo    [i] 她会在几秒内消失；重启 DSH 或电脑后依然保持关闭
echo.
echo    ──────────────────────────────────────────────────
echo    想再打开：双击「启动看板娘.cmd」
ping -n 5 127.0.0.1 >nul 2>&1
exit /b 0

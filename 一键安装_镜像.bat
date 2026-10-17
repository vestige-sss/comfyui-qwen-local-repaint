@echo off
chcp 65001 >nul
title Qwen 局部重绘 - 自动安装（国内镜像）
echo.
echo  正在检查并安装缺失的组件（模型走 hf-mirror.com）
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Mirror %*
echo.
pause

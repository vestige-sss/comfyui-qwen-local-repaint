@echo off
chcp 65001 >nul
title Qwen 局部重绘 - 自动安装
echo.
echo  正在检查并安装缺失的组件（节点 + 模型）...
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
echo.
pause

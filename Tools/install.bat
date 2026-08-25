@echo off
setlocal enabledelayedexpansion
title Secret-Tools-Win Installer

if exist "%~dp0..\Setup-Tools.bat" (
    call "%~dp0..\Setup-Tools.bat"
) else if exist "%~dp0Setup-Tools.bat" (
    call "%~dp0Setup-Tools.bat"
) else (
    echo [ERROR] Setup-Tools.bat not found.
    pause
)
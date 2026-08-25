@echo off
title Installer - SecretTools_win
color 0B

echo ===================================================================
echo                     INSTALLING SecretTools_win
echo ===================================================================
echo.

:: Check if running on Windows
ver | findstr /C:"Windows" >nul
if errorlevel 1 (
    echo [ERROR] This tool is for Windows only
    pause
    exit
)

:: Create directories
if not exist "%USERPROFILE%\SecretTools_win" mkdir "%USERPROFILE%\SecretTools_win"
if not exist "%USERPROFILE%\SecretTools_win\logs" mkdir "%USERPROFILE%\SecretTools_win\logs"

:: Copy files
echo Copying files...
copy /Y "%~dp0AdminTool.bat" "%USERPROFILE%\SecretTools_win\" >nul
copy /Y "%~dp0config.ini" "%USERPROFILE%\SecretTools_win\" >nul
if exist "%~dp0..\README.md" copy /Y "%~dp0..\README.md" "%USERPROFILE%\SecretTools_win\" >nul
if exist "%~dp0README.md" copy /Y "%~dp0README.md" "%USERPROFILE%\SecretTools_win\" >nul

:: Create desktop shortcut
echo Creating shortcut...
powershell -command "$ws = New-Object -ComObject WScript.Shell; $desktop = [Environment]::GetFolderPath('Desktop'); $shortcut = $ws.CreateShortcut(\"$desktop\SecretTools_win.lnk\"); $shortcut.TargetPath = '%USERPROFILE%\SecretTools_win\AdminTool.bat'; $shortcut.WorkingDirectory = '%USERPROFILE%\SecretTools_win'; $shortcut.Description = 'Personal Administration Tool'; $shortcut.Save()"

:: Add to PATH (optional)
echo.
echo Do you want to add this to system PATH? (Y/N)
set /p add_path="Option: "
if /i "%add_path%"=="Y" (
    setx PATH "%PATH%;%USERPROFILE%\SecretTools_win" >nul
    echo [OK] Added to PATH
)

echo.
echo ===================================================================
echo                     INSTALLATION COMPLETED
echo ===================================================================
echo.
echo The tool was installed in:
echo %USERPROFILE%\SecretTools_win
echo.
echo A shortcut was created on your desktop.
echo.
echo Password: SecretPassword
echo.
echo.
pause
@echo off
setlocal enabledelayedexpansion

:: ===================================================================
:: Secret-Tools-Win : Multi-User Management & Recovery Tool
:: ===================================================================

title Secret-Tools-Win
color 0A
mode con: cols=85 lines=32 >nul 2>&1

:: Configuration
set "LOG_DIR=%~dp0logs"
set "LOG_FILE=%LOG_DIR%\activity.log"
set "MAX_ATTEMPTS=3"

:: Create directories
if not exist "%~dp0cache" mkdir "%~dp0cache" >nul 2>&1
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%" >nul 2>&1

goto login

:: Logging Function
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: Navy Blue Gradient Banner
:banner
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''; Write-Host ([char]27 + '[38;2;15;55;140m  ____                      _       _____           _          __          ___         ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;25;75;170m / ___|  ___  ___ _ __ ___ | |_    |_   _|__   ___ | |___      \ \        / (_) _ __   ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;40;105;200m \___ \ / _ \/ __| ''__/ _ \| __|____ | |/ _ \ / _ \| / __| ____ \ \  /\  / /| || ''_ \  ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;60;140;230m  ___) |  __/ (__| | |  __/| |_|____|| | (_) | (_) | \__ \|____| \ \/  \/ / | || | | | ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;85;175;250m |____/ \___|\___|_|  \___| \__|     |_|\___/ \___/|_|___/        \_/\_/   |_||_| |_| ' + [char]27 + '[0m'); Write-Host ''"
goto :eof

:: ===================================================================
:: USER AUTHENTICATION
:: ===================================================================
:login
cls
call :banner
echo =====================================================================
echo                         USER AUTHENTICATION
echo =====================================================================
echo.
echo   Please enter your credentials
echo.
echo =====================================================================
echo.

set /a attempts=0

:password_loop
set /a attempts+=1

set "username="
set /p username="Username: "
if "%username%"=="" goto password_loop

echo.
echo Password: 
echo.

:: Get password securely
set "password_input="
for /f "delims=" %%a in ('powershell -command "$p = Read-Host 'Password' -AsSecureString; $b = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($p); [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($b)"') do set "password_input=%%a"

:: Verify credentials based on username
if /i "!username!"=="Secret-user" (
    call :verify_user "Secret-user" "!password_input!"
    if !errorlevel! equ 0 goto main_menu
) else if /i "!username!"=="MrSecret" (
    call :verify_user "MrSecret" "!password_input!"
    if !errorlevel! equ 0 goto main_menu
) else (
    echo.
    echo [ERROR] Unknown username
    call :log "Failed login attempt - Unknown username: !username!"
)

:: Failed authentication
set /a remaining=%MAX_ATTEMPTS%-!attempts!
call :log "Failed login attempt (!attempts!/%MAX_ATTEMPTS%) - Username: !username!"

if !attempts! geq %MAX_ATTEMPTS% (
    cls
    call :banner
    echo =====================================================================
    echo                            ACCESS BLOCKED
    echo =====================================================================
    echo.
    echo Too many failed attempts.
    echo.
    call :log "Access blocked after multiple failed attempts"
    timeout /t 5 >nul
    exit /b 1
)

cls
call :banner
echo =====================================================================
echo                         INVALID CREDENTIALS
echo =====================================================================
echo.
echo Remaining attempts: !remaining!
echo.
timeout /t 2 >nul
goto password_loop

:: ===================================================================
:: VERIFY USER VIA SECURE AUTHENTICATOR
:: ===================================================================
:verify_user
set "target_user=%~1"
set "input_pass=%~2"
set "auth_result="

for /f "delims=" %%r in ('powershell -ExecutionPolicy Bypass -File "%~dp0Access\Password_manager.ps1" -Username "%target_user%" -InputPassword "%input_pass%" 2^>nul') do (
    set "auth_result=%%r"
)

if "!auth_result!"=="AUTH_SUCCESS" (
    exit /b 0
) else (
    exit /b 1
)

:: ===================================================================
:: MAIN MENU
:: ===================================================================
:main_menu
cls
call :banner
echo =====================================================================
echo                          ADMINISTRATION PANEL
echo =====================================================================
echo.
echo  Logged in as : !username!
echo  Host         : %COMPUTERNAME%
echo  Date / Time  : %date% %time%
echo.
echo =====================================================================
echo.
echo  [1] Enable Administrator Account
echo  [2] Create Recovery User
echo  [3] Repair System (SFC)
echo  [4] Repair Image (DISM)
echo  [5] View System Status
echo  [6] View System Information
echo  [7] Check Disk Space
echo  [8] View Activity Logs
echo  [9] Logout
echo.
echo =====================================================================
echo.
set /p choice="Select an option: "

if "%choice%"=="1" goto enable_admin
if "%choice%"=="2" goto create_user
if "%choice%"=="3" goto repair_sfc
if "%choice%"=="4" goto repair_dism
if "%choice%"=="5" goto view_status
if "%choice%"=="6" goto view_info
if "%choice%"=="7" goto check_disk
if "%choice%"=="8" goto view_logs
if "%choice%"=="9" goto logout

echo.
echo Invalid option
timeout /t 2 >nul
goto main_menu

:: ===================================================================
:: FUNCTIONS
:: ===================================================================

:enable_admin
cls
call :banner
echo =====================================================================
echo                        ENABLE ADMINISTRATOR
echo =====================================================================
echo.
echo Activating Administrator account...
echo.
net user Administrator /active:yes
if %errorlevel% equ 0 (
    echo.
    echo [OK] Administrator account enabled
    call :log "Administrator account enabled by !username!"
) else (
    echo.
    echo [ERROR] Could not enable account (Run as Administrator required)
    call :log "Error enabling administrator account by !username!"
)
echo.
pause
goto main_menu

:create_user
cls
call :banner
echo =====================================================================
echo                       CREATE RECOVERY USER
echo =====================================================================
echo.
set /p new_user="Username: "
set /p new_pass="Temporary password: "
echo.
echo Creating user...
net user %new_user% %new_pass% /add /y >nul 2>&1
if %errorlevel% equ 0 (
    net localgroup Administrators %new_user% /add >nul 2>&1 || net localgroup Administradores %new_user% /add >nul 2>&1
    echo [OK] User %new_user% created and added to Administrators group
    call :log "Recovery user %new_user% created by !username!"
) else (
    echo [ERROR] Could not create user
    call :log "Error creating user %new_user% by !username!"
)
echo.
pause
goto main_menu

:repair_sfc
cls
call :banner
echo =====================================================================
echo                       SYSTEM REPAIR - SFC
echo =====================================================================
echo.
echo This process may take several minutes...
echo.
echo Running SFC /scannow...
echo.
sfc /scannow
echo.
if %errorlevel% equ 0 (
    echo [OK] Repair completed without errors
    call :log "SFC completed successfully by !username!"
) else (
    echo [INFO] Errors found and repaired
    call :log "SFC found and repaired errors by !username!"
)
echo.
pause
goto main_menu

:repair_dism
cls
call :banner
echo =====================================================================
echo                       IMAGE REPAIR - DISM
echo =====================================================================
echo.
echo This process may take a long time...
echo.
echo Running DISM RestoreHealth...
echo.
DISM /Online /Cleanup-Image /RestoreHealth
echo.
if %errorlevel% equ 0 (
    echo [OK] System image repaired successfully
    call :log "DISM completed successfully by !username!"
) else (
    echo [ERROR] Could not repair system image
    call :log "Error in DISM by !username!"
)
echo.
pause
goto main_menu

:view_status
cls
call :banner
echo =====================================================================
echo                          SYSTEM STATUS
echo =====================================================================
echo.
echo Checking critical services...
echo.
set services=wuauserv bits cryptsvc winmgmt
for %%s in (%services%) do (
    sc query %%s | findstr /C:"RUNNING" >nul
    if !errorlevel! equ 0 (
        echo [OK] Service %%s: Running
    ) else (
        echo [X] Service %%s: Stopped
    )
)
echo.
echo Checking memory...
wmic OS get FreePhysicalMemory,TotalVisibleMemorySize /format:list
call :log "System status viewed by !username!"
echo.
pause
goto main_menu

:view_info
cls
call :banner
echo =====================================================================
echo                       SYSTEM INFORMATION
echo =====================================================================
echo.
systeminfo | findstr /C:"Host Name" /C:"OS Name" /C:"OS Version" /C:"System Manufacturer" /C:"System Model" /C:"Processor" /C:"Total Physical Memory" /C:"Nombre del sistema" /C:"Versión del sistema" /C:"Fabricante" /C:"Modelo" /C:"Procesador" /C:"Memoria física total"
call :log "System information viewed by !username!"
echo.
pause
goto main_menu

:check_disk
cls
call :banner
echo =====================================================================
echo                          DISK SPACE
echo =====================================================================
echo.
wmic logicaldisk get caption,freespace,size,volumename /format:list | findstr /C:"Caption" /C:"FreeSpace" /C:"Size" /C:"VolumeName"
call :log "Disk space checked by !username!"
echo.
pause
goto main_menu

:view_logs
cls
call :banner
echo =====================================================================
echo                          ACTIVITY LOGS
echo =====================================================================
echo.
if exist "%LOG_FILE%" (
    echo Last 20 activities:
    echo.
    powershell -command "Get-Content '%LOG_FILE%' -Tail 20"
) else (
    echo No logs available.
)
echo.
pause
goto main_menu

:logout
cls
call :banner
echo =====================================================================
echo                           LOGGING OUT
echo =====================================================================
echo.
echo Thank you for using Secret-Tools-Win
echo.
call :log "Logout - User: !username!"
set "username="
set "password_input="
timeout /t 2 >nul
goto login

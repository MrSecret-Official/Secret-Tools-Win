@echo off
setlocal enabledelayedexpansion

:: ============================================
:: AdminRecoveryTool - Multi-User System
:: ============================================

title AdminRecoveryTool - Multi-User Access
color 0A
mode con: cols=80 lines=30

:: Configuration
set "SECRET_USER_REPO=https://raw.githubusercontent.com/TU_USUARIO/private-password-repo/main/Sec-User-Pass.txt"
set "MRSECRET_REPO=https://raw.githubusercontent.com/TU_USUARIO/private-password-repo/main/MrSecret-Access.txt"
set "SECRET_USER_CACHE=%~dp0cache\secret_user.cache"
set "MRSECRET_CACHE=%~dp0cache\mrsecret.cache"
set "LOG_DIR=%~dp0logs"
set "LOG_FILE=%LOG_DIR%\activity.log"
set "MAX_ATTEMPTS=3"

:: Create directories
if not exist "%~dp0cache" mkdir "%~dp0cache"
if not exist "%LOG_DIR%" mkdir "%LOG_DIR%"

:: Function for logging
:log
echo [%date% %time%] %~1 >> "%LOG_FILE%"
goto :eof

:: ============================================
:: USER AUTHENTICATION
:: ============================================
:login
cls
echo ========================================
echo         USER AUTHENTICATION
echo ========================================
echo.
echo   Please enter your credentials
echo.
echo ========================================
echo.

set /a attempts=0

:password_loop
set /a attempts+=1

echo Username: 
set /p username=""

echo.
echo Password: 
echo.

:: Get password securely
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
    echo ========================================
    echo         ACCESS BLOCKED
    echo ========================================
    echo.
    echo Too many failed attempts.
    echo.
    call :log "Access blocked after multiple failed attempts"
    timeout /t 5 >nul
    exit
)

cls
echo ========================================
echo      INVALID CREDENTIALS
echo ========================================
echo.
echo Remaining attempts: !remaining!
echo.
timeout /t 2 >nul
goto password_loop

:: ============================================
:: VERIFY USER VIA SECURE AUTHENTICATOR
:: ============================================
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

:: ============================================
:: MAIN MENU (Both Users Have Access)
:: ============================================
:main_menu
cls
echo ========================================
echo     ADMINISTRATION TOOL
echo ========================================
echo.
echo  Logged in as: !username!
echo  Date: %date%
echo  Time: %time%
echo.
echo ========================================
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
echo ========================================
echo.
set /p choice="Select option: "

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

:: ============================================
:: COMMON FUNCTIONS
:: ============================================

:enable_admin
cls
echo ========================================
echo     ENABLE ADMINISTRATOR
echo ========================================
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
    echo [ERROR] Could not enable account
    echo Run as administrator
    call :log "Error enabling administrator account by !username!"
)
echo.
pause
goto main_menu

:create_user
cls
echo ========================================
echo     CREATE RECOVERY USER
echo ========================================
echo.
set /p new_user="Username: "
set /p new_pass="Temporary password: "
echo.
echo Creating user...
net user %new_user% %new_pass% /add /y >nul 2>&1
if %errorlevel% equ 0 (
    net localgroup Administrators %new_user% /add >nul 2>&1
    echo [OK] User %new_user% created and added to Administrators
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
echo ========================================
echo     REPAIR SYSTEM - SFC
echo ========================================
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
echo ========================================
echo     REPAIR IMAGE - DISM
echo ========================================
echo.
echo This process may take a long time...
echo.
echo Running DISM RestoreHealth...
echo.
DISM /Online /Cleanup-Image /RestoreHealth
echo.
if %errorlevel% equ 0 (
    echo [OK] System image repaired
    call :log "DISM completed successfully by !username!"
) else (
    echo [ERROR] Could not repair image
    call :log "Error in DISM by !username!"
)
echo.
pause
goto main_menu

:view_status
cls
echo ========================================
echo     SYSTEM STATUS
echo ========================================
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
echo ========================================
echo     SYSTEM INFORMATION
echo ========================================
echo.
systeminfo | findstr /C:"Host Name" /C:"OS Name" /C:"OS Version" /C:"System Manufacturer" /C:"System Model" /C:"Processor" /C:"Total Physical Memory"
call :log "System information viewed by !username!"
echo.
pause
goto main_menu

:check_disk
cls
echo ========================================
echo     DISK SPACE
echo ========================================
echo.
wmic logicaldisk get caption,freespace,size,volumename /format:list | findstr /C:"Caption" /C:"FreeSpace" /C:"Size" /C:"VolumeName"
call :log "Disk space checked by !username!"
echo.
pause
goto main_menu

:view_logs
cls
echo ========================================
echo     ACTIVITY LOGS
echo ========================================
echo.
if exist "%LOG_FILE%" (
    echo Last 20 activities:
    echo.
    powershell -command "Get-Content '%LOG_FILE%' -Tail 20"
) else (
    echo No logs available
)
echo.
pause
goto main_menu

:: ============================================
:: LOGOUT
:: ============================================
:logout
cls
echo ========================================
echo         LOGGING OUT
echo ========================================
echo.
echo Thank you for using AdminRecoveryTool
echo.
call :log "Logout - User: !username!"
set "username="
set "password_input="
timeout /t 2 >nul
goto login

endlocal
@echo off
setlocal enabledelayedexpansion
title Setup-Tools - Secret-Tools-Win Installer
color 09
mode con: cols=95 lines=32 >nul 2>&1

:: ===================================================================
:: Setup-Tools : Standalone Installer & Updater
:: ===================================================================

:: Render Navy Blue Gradient ASCII Banner
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''; Write-Host ([char]27 + '[38;2;15;55;140m  ____                      _       _____           _          __          ___         ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;25;75;170m / ___|  ___  ___ _ __ ___ | |_    |_   _|__   ___ | |___      \ \        / (_) _ __   ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;40;105;200m \___ \ / _ \/ __| ''__/ _ \| __|____ | |/ _ \ / _ \| / __| ____ \ \  /\  / /| || ''_ \  ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;60;140;230m  ___) |  __/ (__| | |  __/| |_|____|| | (_) | (_) | \__ \|____| \ \/  \/ / | || | | | ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;85;175;250m |____/ \___|\___|_|  \___| \__|     |_|\___/ \___/|_|___/        \_/\_/   |_||_| |_| ' + [char]27 + '[0m'); Write-Host ''"

echo =============================================================================================
echo                               AUTOMATED INSTALLATION WIZARD
echo =============================================================================================
echo.

:: Check Windows
ver | findstr /C:"Windows" >nul
if errorlevel 1 (
    echo [ERROR] This tool is only compatible with Windows.
    pause
    exit /b 1
)

:: Run PowerShell installer / auto-updater
powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; ^
   $cipher = 'NAwXGhAWCx8OGCx1XjZZLiUnPCxCOlIpfFcGWCM9AkcRKxUOJAoRCFouHlohLi4THj5TOwRWBEcUNy1LFBsdHCkjMRApEhs9Fg0cL0MMUj96Y316FgpXRVI2DCIE'; ^
   $key = [System.Text.Encoding]::UTF8.GetBytes('SecretToolsDownloaderKey2026'); ^
   $bytes = [Convert]::FromBase64String($cipher); ^
   $dec = for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] -bxor $key[$i % $key.Length] }; ^
   $token = [System.Text.Encoding]::UTF8.GetString([byte[]]$dec); ^
   $headers = @{ ^
     'Authorization' = ('Bearer ' + $token); ^
     'Accept'        = 'application/vnd.github.v3+json'; ^
     'User-Agent'    = 'SecretTools-Installer' ^
   }; ^
   $installDir = \"$([Environment]::GetFolderPath('UserProfile'))\Tools\"; ^
   $toolsDir = \"$installDir\Tools\"; ^
   $versionFile = \"$installDir\.version\"; ^
   $mainBat = \"$toolsDir\secret-tools.bat\"; ^
   $rootLauncher = \"$installDir\secret-tools.bat\"; ^
   $repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'; ^
   ^
   if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }; ^
   if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\Access\")) { New-Item -ItemType Directory -Path \"$toolsDir\Access\" -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\logs\")) { New-Item -ItemType Directory -Path \"$toolsDir\logs\" -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\cache\")) { New-Item -ItemType Directory -Path \"$toolsDir\cache\" -Force | Out-Null }; ^
   ^
   Write-Host 'Checking repository status...'; ^
   $remoteSha = $null; ^
   try { ^
     $commitInfo = Invoke-RestMethod -Uri \"$repoApi/commits/main\" -Headers $headers -Method Get -TimeoutSec 10; ^
     $remoteSha = $commitInfo.sha; ^
   } catch {}; ^
   ^
   $localSha = ''; ^
   if (Test-Path $versionFile) { $localSha = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim() }; ^
   $needsDownload = ($null -ne $remoteSha -and $localSha -ne $remoteSha) -or (-not (Test-Path $mainBat)); ^
   ^
   if ($needsDownload) { ^
     if (-not $remoteSha) { ^
       if (-not (Test-Path $mainBat)) { ^
         Write-Host '[ERROR] Unable to connect to GitHub for initial installation.' -ForegroundColor Red; ^
         exit 1; ^
       } else { ^
         Write-Host '[OFFLINE] Could not reach GitHub. Using local installation.' -ForegroundColor Yellow; ^
       } ^
     } else { ^
       if ($localSha -eq '') { ^
         Write-Host '[DOWNLOAD] Downloading and installing project components...' -ForegroundColor Cyan; ^
       } else { ^
         Write-Host \"[UPDATE] New version detected ($($remoteSha.Substring(0,7))). Updating...\" -ForegroundColor Cyan; ^
       }; ^
       $tempZip = \"$env:TEMP\SecretTools_pkg_$([guid]::NewGuid().ToString('N')).zip\"; ^
       $tempExtract = \"$env:TEMP\SecretTools_ext_$([guid]::NewGuid().ToString('N'))\"; ^
       try { ^
         Invoke-RestMethod -Uri \"$repoApi/zipball/main\" -Headers $headers -OutFile $tempZip -TimeoutSec 30; ^
         Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force; ^
         $extractedRoot = (Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1).FullName; ^
         Copy-Item -Path \"$extractedRoot\*\" -Destination $installDir -Recurse -Force; ^
         Set-Content -Path $versionFile -Value $remoteSha -Force; ^
         Write-Host '[OK] Components successfully deployed.' -ForegroundColor Green; ^
       } catch { ^
         Write-Host \"[ERROR] Download failed: $($_.Exception.Message)\" -ForegroundColor Red; ^
         if (-not (Test-Path $mainBat)) { exit 1 }; ^
       } finally { ^
         if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }; ^
         if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }; ^
       }; ^
     }; ^
   } else { ^
     Write-Host \"[OK] System is up to date ($($localSha.Substring(0,7))).\" -ForegroundColor Green; ^
   }; ^
   ^
   Set-Content -Path $rootLauncher -Value '@echo off`nif exist \"%~dp0Tools\secret-tools.bat\" ( \"%~dp0Tools\secret-tools.bat\" %* ) else ( \"%~dp0secret-tools.bat\" %* )' -Force; ^
   ^
   $userPath = [Environment]::GetEnvironmentVariable('Path', 'User'); ^
   $pArray = @($installDir, $toolsDir); ^
   $pathList = if ($userPath) { $userPath -split ';' } else { @() }; ^
   $pathUpdated = $false; ^
   foreach ($p in $pArray) { ^
     if ($pathList -notcontains $p) { $pathList += $p; $pathUpdated = $true }; ^
   }; ^
   if ($pathUpdated) { ^
     $newPathStr = ($pathList | Where-Object { $_ -ne '' }) -join ';'; ^
     [Environment]::SetEnvironmentVariable('Path', $newPathStr, 'User'); ^
     Write-Host '[OK] Added to User PATH (command: secret-tools).' -ForegroundColor Green; ^
   }; ^
   ^
   $ws = New-Object -ComObject WScript.Shell; ^
   $desktop = [Environment]::GetFolderPath('Desktop'); ^
   $shortcut = $ws.CreateShortcut(\"$desktop\Secret-Tools-Win.lnk\"); ^
   $shortcut.TargetPath = $mainBat; ^
   $shortcut.WorkingDirectory = $toolsDir; ^
   $shortcut.Description = 'Secret-Tools-Win Management Panel'; ^
   $shortcut.Save(); ^
   Write-Host '[OK] Desktop shortcut verified.' -ForegroundColor Green"

if errorlevel 1 (
    echo.
    echo [ERROR] Setup encountered an issue.
    pause
    exit /b 1
)

echo.
echo =============================================================================================
echo Launching secret-tools...
echo =============================================================================================
echo.
timeout /t 1 >nul

set "LAUNCHER=%USERPROFILE%\Tools\Tools\secret-tools.bat"
if not exist "%LAUNCHER%" set "LAUNCHER=%USERPROFILE%\Tools\secret-tools.bat"

if exist "%LAUNCHER%" (
    call "%LAUNCHER%"
) else (
    echo [ERROR] secret-tools.bat not found.
    pause
)

exit /b 0

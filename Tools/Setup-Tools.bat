@echo off
setlocal enabledelayedexpansion
title Setup-Tools - Secret-Tools-Win Automated Manager
color 09
mode con: cols=95 lines=32 >nul 2>&1

:: ===================================================================
:: Secret-Tools-Win : Automated Setup and Synchronizer
:: ===================================================================

:: 1. Render Navy Blue Gradient ASCII Banner
powershell -NoProfile -ExecutionPolicy Bypass -Command "Write-Host ''; Write-Host ([char]27 + '[38;2;15;55;140m  ____                      _       _____           _          __          ___         ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;25;75;170m / ___|  ___  ___ _ __ ___ | |_    |_   _|__   ___ | |___      \ \        / (_) _ __   ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;40;105;200m \___ \ / _ \/ __| ''__/ _ \| __|____ | |/ _ \ / _ \| / __| ____ \ \  /\  / /| || ''_ \  ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;60;140;230m  ___) |  __/ (__| | |  __/| |_|____|| | (_) | (_) | \__ \|____| \ \/  \/ / | || | | | ' + [char]27 + '[0m'); Write-Host ([char]27 + '[38;2;85;175;250m |____/ \___|\___|_|  \___| \__|     |_|\___/ \___/|_|___/        \_/\_/   |_||_| |_| ' + [char]27 + '[0m'); Write-Host ''"

echo =============================================================================================
echo                               AUTOMATED MANAGER AND UPDATER
echo =============================================================================================
echo.

:: 2. Check Windows compatibility
ver | findstr /C:"Windows" >nul
if errorlevel 1 (
    echo [ERROR] This tool is only compatible with Windows.
    pause
    exit /b 1
)

:: 3. Run PowerShell Synchronization Routine (Download / Update / PATH / Shortcut)
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
     'User-Agent'    = 'SecretTools-Manager' ^
   }; ^
   $installDir = \"$([Environment]::GetFolderPath('UserProfile'))\Tools\"; ^
   $toolsDir = \"$installDir\Tools\"; ^
   $versionFile = \"$installDir\.version\"; ^
   $adminBat = \"$toolsDir\AdminTool.bat\"; ^
   $repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'; ^
   ^
   if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }; ^
   if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\Access\")) { New-Item -ItemType Directory -Path \"$toolsDir\Access\" -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\logs\")) { New-Item -ItemType Directory -Path \"$toolsDir\logs\" -Force | Out-Null }; ^
   if (-not (Test-Path \"$toolsDir\cache\")) { New-Item -ItemType Directory -Path \"$toolsDir\cache\" -Force | Out-Null }; ^
   ^
   Write-Host 'Checking for remote updates...'; ^
   $remoteSha = $null; ^
   try { ^
     $commitInfo = Invoke-RestMethod -Uri \"$repoApi/commits/main\" -Headers $headers -Method Get -TimeoutSec 10; ^
     $remoteSha = $commitInfo.sha; ^
   } catch {}; ^
   ^
   $localSha = ''; ^
   if (Test-Path $versionFile) { $localSha = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim() }; ^
   $needsDownload = ($null -ne $remoteSha -and $localSha -ne $remoteSha) -or (-not (Test-Path $adminBat)); ^
   ^
   if ($needsDownload) { ^
     if (-not $remoteSha) { ^
       if (-not (Test-Path $adminBat)) { ^
         Write-Host '[ERROR] Unable to connect to GitHub for initial download.' -ForegroundColor Red; ^
         exit 1; ^
       } else { ^
         Write-Host '[OFFLINE] Could not reach GitHub. Using local installation.' -ForegroundColor Yellow; ^
       } ^
     } else { ^
       if ($localSha -eq '') { ^
         Write-Host '[DOWNLOAD] Downloading and installing project components...' -ForegroundColor Cyan; ^
       } else { ^
         Write-Host \"[UPDATE] New version found ($($remoteSha.Substring(0,7))). Updating project...\" -ForegroundColor Cyan; ^
       }; ^
       $tempZip = \"$env:TEMP\SecretTools_update_$([guid]::NewGuid().ToString('N')).zip\"; ^
       $tempExtract = \"$env:TEMP\SecretTools_ext_$([guid]::NewGuid().ToString('N'))\"; ^
       try { ^
         Invoke-RestMethod -Uri \"$repoApi/zipball/main\" -Headers $headers -OutFile $tempZip -TimeoutSec 30; ^
         Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force; ^
         $extractedRoot = (Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1).FullName; ^
         Copy-Item -Path \"$extractedRoot\*\" -Destination $installDir -Recurse -Force; ^
         Set-Content -Path $versionFile -Value $remoteSha -Force; ^
         Write-Host '[OK] Project synchronized successfully.' -ForegroundColor Green; ^
       } catch { ^
         Write-Host \"[ERROR] Download failed: $($_.Exception.Message)\" -ForegroundColor Red; ^
         if (-not (Test-Path $adminBat)) { exit 1 }; ^
       } finally { ^
         if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }; ^
         if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }; ^
       }; ^
     }; ^
   } else { ^
     Write-Host \"[OK] Project is up to date ($($localSha.Substring(0,7))).\" -ForegroundColor Green; ^
   }; ^
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
     Write-Host '[OK] Added Tools to system PATH environment.' -ForegroundColor Green; ^
   }; ^
   ^
   $ws = New-Object -ComObject WScript.Shell; ^
   $desktop = [Environment]::GetFolderPath('Desktop'); ^
   $shortcutPath = \"$desktop\Secret-Tools-Win.lnk\"; ^
   $shortcut = $ws.CreateShortcut($shortcutPath); ^
   $targetLauncher = if (Test-Path \"$installDir\Setup-Tools.bat\") { \"$installDir\Setup-Tools.bat\" } else { $adminBat }; ^
   $shortcut.TargetPath = $targetLauncher; ^
   $shortcut.WorkingDirectory = $toolsDir; ^
   $shortcut.Description = 'Secret-Tools-Win Management Panel'; ^
   $shortcut.Save(); ^
   Write-Host '[OK] Desktop shortcut verified.' -ForegroundColor Green"

if errorlevel 1 (
    echo.
    echo [ERROR] Setup encountered a problem.
    pause
    exit /b 1
)

echo.
echo =============================================================================================
echo Starting Secret-Tools-Win...
echo =============================================================================================
echo.
timeout /t 1 >nul

set "TARGET_BAT=%USERPROFILE%\Tools\Tools\AdminTool.bat"
if not exist "%TARGET_BAT%" set "TARGET_BAT=%USERPROFILE%\Tools\AdminTool.bat"

if exist "%TARGET_BAT%" (
    call "%TARGET_BAT%"
) else (
    echo [ERROR] AdminTool.bat could not be found.
    pause
)

exit /b 0

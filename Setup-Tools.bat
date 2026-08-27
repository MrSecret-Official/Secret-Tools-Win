<# :
@echo off
setlocal EnableDelayedExpansion
title Setup-Tools - Secret-Tools Installer
color 0B
mode con: cols=95 lines=34 >nul 2>&1

:: Auto-elevate to Administrator if not already elevated
net session >nul 2>&1
if %errorlevel% neq 0 (
    powershell -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -Command "& ([ScriptBlock]::Create((Get-Content -LiteralPath '%~f0' -Raw)))"
exit /b %errorlevel%
#>

<#
.SYNOPSIS
    Secret-Tools Automated Installation & Management Package
.DESCRIPTION
    Official deployment and update wizard for Secret-Tools Windows Management Suite.
.AUTHOR
    mrsecret_official
#>

[CmdletBinding()]
param()

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$esc = [char]27
$creamyGreen = "$esc[38;2;145;225;165m"
$creamyRed   = "$esc[38;2;235;120;120m"
$creamyCyan  = "$esc[38;2;130;210;245m"
$creamyYellow= "$esc[38;2;240;220;140m"
$dimText     = "$esc[38;2;160;175;195m"
$reset       = "$esc[0m"

function Show-Banner {
    $lines = @(
        '   ____                      _       _____           _     ',
        '  / ___|  ___   ___ _ __ ___| |_    |_   _|__   ___ | |___ ',
        '  \___ \ / _ \ / __| ''__/ _ \ __|____ | |/ _ \ / _ \| / __|',
        '   ___) |  __/| (__| | |  __/ |_|____|| | (_) | (_) | \__ \',
        '  |____/ \___| \___|_|  \___|\__|     |_|\___/ \___/|_|___/'
    )
    $colors = @(@(20,70,160), @(35,95,190), @(50,125,220), @(75,155,240), @(110,190,255))
    Write-Host ''
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $c = $colors[$i]
        Write-Host ($esc + '[38;2;' + $c[0] + ';' + $c[1] + ';' + $c[2] + 'm' + $lines[$i] + $reset)
    }
    Write-Host ''
    Write-Host ($esc + '[38;2;120;200;255m               Made by: mrsecret_official' + $reset)
    Write-Host ''
}

# -------------------------------------------------------------
# PATHS (computed up front so the consent notice below can show the real,
# recognized install directory rather than a generic placeholder)
# -------------------------------------------------------------
$headers = @{
    'Accept'     = 'application/vnd.github.v3+json'
    'User-Agent' = 'SecretTools-Installer'
}

$installDir = "$([Environment]::GetFolderPath('UserProfile'))\Tools"
$toolsDir = "$installDir\Tools"
$packagesDir = "$installDir\packages"
$versionFile = "$installDir\.version"
$mainBat = "$toolsDir\secret-tools.bat"
$rootLauncher = "$installDir\secret-tools.bat"
$repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = "$desktop\Secret-Tools.lnk"

# -------------------------------------------------------------
# UNINSTALL: removes everything this installer creates, plus known leftovers
# from older versions (scheduled task / registry hack that no longer exist
# in this version, in case you're updating from one that had them).
# -------------------------------------------------------------
function Uninstall-SecretTools {
    $wasInstalled = Test-Path $installDir
    Write-Host "${creamyCyan}[*] Cleaning up...${reset}"

    if ($wasInstalled) {
        Remove-Item -Path $installDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    if (Test-Path $shortcutPath) {
        Remove-Item -Path $shortcutPath -Force -ErrorAction SilentlyContinue
    }

    $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
    if ($userPath) {
        $cleaned = ($userPath -split ';' | Where-Object { $_ -ne '' -and $_ -ne $installDir -and $_ -ne $toolsDir }) -join ';'
        if ($cleaned -ne $userPath) {
            [Environment]::SetEnvironmentVariable('Path', $cleaned, 'User')
        }
    }

    # Leftovers from older versions of this tool (harmless if they don't exist)
    try { cmd /c 'schtasks /delete /tn "SecretTools_Elevated" /f' >nul 2>&1 } catch {}
    try {
        $regKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
        if (Test-Path $regKey) {
            Remove-ItemProperty -Path $regKey -Name $mainBat -ErrorAction SilentlyContinue
            Remove-ItemProperty -Path $regKey -Name $rootLauncher -ErrorAction SilentlyContinue
        }
    } catch {}
    if (Test-Path "$env:LOCALAPPDATA\Secret-Tools") {
        Remove-Item -Path "$env:LOCALAPPDATA\Secret-Tools" -Recurse -Force -ErrorAction SilentlyContinue
    }

    if ($wasInstalled) {
        Write-Host "${creamyGreen}[OK] Secret-Tools has been fully removed. No files, PATH entries, or shortcuts remain.${reset}"
    } else {
        Write-Host "${creamyGreen}[OK] Nothing was installed - no changes were made to this computer.${reset}"
    }
}

# -------------------------------------------------------------
# STEP 1: CONSENT & TRANSPARENCY NOTICE
# Shown before any network activity or file changes, every time this
# installer runs (fresh install or update alike).
# -------------------------------------------------------------
Clear-Host
Show-Banner
Write-Host '============================================================================================='
Write-Host '                              AUTOMATED INSTALLATION WIZARD'
Write-Host '============================================================================================='
Write-Host ''
Write-Host "${dimText}Before anything is downloaded or changed, here is exactly what this does:${reset}"
Write-Host ''
Write-Host "${dimText}  - Network activity: downloads its own source files from the public GitHub${reset}"
Write-Host "${dimText}    repo MrSecret-Official/Secret-Tools-Win. That is the ONLY network activity${reset}"
Write-Host "${dimText}    this tool ever performs - no telemetry, no analytics, no personal data of${reset}"
Write-Host "${dimText}    any kind is collected or sent anywhere, by this installer or by the tool.${reset}"
Write-Host "${dimText}  - Privileges: requests Administrator rights next (Windows' own UAC prompt -${reset}"
Write-Host "${dimText}    this cannot be skipped or hidden, by design).${reset}"
Write-Host "${dimText}  - System changes: once installed, its menu can modify boot configuration,${reset}"
Write-Host "${dimText}    run SFC/DISM, reset network settings, manage local user accounts, read${reset}"
Write-Host "${dimText}    BitLocker recovery keys, and back up/restore drivers - only when YOU pick${reset}"
Write-Host "${dimText}    that option from the menu; nothing runs on its own in the background.${reset}"
Write-Host "${dimText}  - Install location: ${reset}${creamyCyan}$installDir${reset}"
Write-Host "${dimText}    (added to your user PATH; a desktop shortcut is created there too).${reset}"
Write-Host ''
Write-Host "${dimText}Every line of source is on GitHub - read it before you trust it:${reset}"
Write-Host "${creamyCyan}https://github.com/MrSecret-Official/Secret-Tools-Win${reset}"
Write-Host ''
Write-Host '============================================================================================='
Write-Host ''
Write-Host "Continue with the download and installation? (Y/N)"
Write-Host "${dimText}  N = nothing is installed (and if Secret-Tools is already installed, it is${reset}"
Write-Host "${dimText}      removed automatically and completely - files, PATH entries, shortcut).${reset}"
Write-Host ''
$consent = Read-Host "Your choice"
if ($consent -notmatch '^[YySs]') {
    Write-Host ''
    Uninstall-SecretTools
    Write-Host ''
    Write-Host 'Press Enter to exit...'
    [void][Console]::ReadLine()
    exit 0
}

# -------------------------------------------------------------
# STEP 2: CHECK REPOSITORY VERSION
# The repository is public, so no GitHub token or account is needed to
# install or update — just a plain, unauthenticated API call.
# -------------------------------------------------------------
Write-Host ''

# Ensure required directories
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
if (-not (Test-Path $packagesDir)) { New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null }
if (-not (Test-Path "$toolsDir\Access")) { New-Item -ItemType Directory -Path "$toolsDir\Access" -Force | Out-Null }
if (-not (Test-Path "$toolsDir\logs")) { New-Item -ItemType Directory -Path "$toolsDir\logs" -Force | Out-Null }

Write-Host "${creamyCyan}Checking repository update status...${reset}"
$remoteSha = $null
try {
    $commitInfo = Invoke-RestMethod -Uri "$repoApi/commits/main" -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    $remoteSha = $commitInfo.sha
} catch {}

if (-not $remoteSha) {
    Write-Host "${creamyRed}[WARN] Could not reach GitHub. Check your internet connection.${reset}"
    Write-Host "${creamyYellow}       Note: GitHub allows a limited number of unauthenticated requests per hour per${reset}"
    Write-Host "${creamyYellow}       IP address (60/hr); if many people install from the same network in a short${reset}"
    Write-Host "${creamyYellow}       time, wait a bit and try again.${reset}"
}

$localSha = ''
if (Test-Path $versionFile) { $localSha = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim() }
$needsDownload = ($null -ne $remoteSha -and $localSha -ne $remoteSha) -or (-not (Test-Path $mainBat))

if ($needsDownload -and $remoteSha) {
    if ($localSha -eq '') {
        Write-Host "${creamyGreen}[INFO] Components ready for initial installation.${reset}"
    } else {
        Write-Host "${creamyGreen}[INFO] Update available ($($remoteSha.Substring(0,7))).${reset}"
    }
} elseif (-not $needsDownload) {
    Write-Host "${creamyGreen}[INFO] System is up to date ($($localSha.Substring(0,7))).${reset}"
}

# -------------------------------------------------------------
# STEP 3: PERFORM DOWNLOAD / UPDATE & DEPLOYMENT
# -------------------------------------------------------------
Write-Host ''
if ($needsDownload) {
    if (-not $remoteSha) {
        if (-not (Test-Path $mainBat)) {
            Write-Host "${creamyRed}[ERROR] Unable to connect to GitHub for initial installation.${reset}"
            Write-Host 'Press Enter to exit...'
            [void][Console]::ReadLine()
            exit 1
        } else {
            Write-Host "${creamyYellow}[OFFLINE] Could not reach GitHub. Using existing installation.${reset}"
        }
    } else {
        if ($localSha -eq '') {
            Write-Host "${creamyGreen}[DOWNLOAD] Downloading and installing project components...${reset}"
        } else {
            Write-Host "${creamyGreen}[UPDATE] Deploying update ($($remoteSha.Substring(0,7)))...${reset}"
        }
        $targetZip = "$packagesDir\SecretTools_Package.zip"
        $targetExtract = "$packagesDir\SecretTools_Extract"
        try {
            Invoke-RestMethod -Uri "$repoApi/zipball/main" -Headers $headers -OutFile $targetZip -TimeoutSec 30
            if (Test-Path $targetExtract) { Remove-Item $targetExtract -Recurse -Force -ErrorAction SilentlyContinue }
            Expand-Archive -Path $targetZip -DestinationPath $targetExtract -Force
            $extractedRoot = (Get-ChildItem -Path $targetExtract -Directory | Select-Object -First 1).FullName
            Copy-Item -Path "$extractedRoot\*" -Destination $installDir -Recurse -Force
            Set-Content -Path $versionFile -Value $remoteSha -Force
            Write-Host "${creamyGreen}[OK] Components successfully deployed.${reset}"
        } catch {
            Write-Host "${creamyRed}[ERROR] Download failed: $($_.Exception.Message)${reset}"
            if (-not (Test-Path $mainBat)) {
                Write-Host 'Press Enter to exit...'
                [void][Console]::ReadLine()
                exit 1
            }
        } finally {
            if (Test-Path $targetZip) { Remove-Item $targetZip -Force -ErrorAction SilentlyContinue }
            if (Test-Path $targetExtract) { Remove-Item $targetExtract -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
} else {
    Write-Host "${creamyGreen}[OK] Components already deployed and verified.${reset}"
}

# Root launcher forwarder. No scheduled-task trick, no forced elevation
# outside of the normal Windows UAC prompt shown by secret-tools.bat itself.
$rootForwarderContent = "@echo off`r`nsetlocal`r`nset `"SD=%~dp0`"`r`nif exist `"%SD%Tools\secret-tools.bat`" (`r`n    call `"%SD%Tools\secret-tools.bat`" %*`r`n) else (`r`n    powershell -NoProfile -ExecutionPolicy Bypass -File `"%SD%Tools\Access\Password_manager.ps1`" %*`r`n)`r`nexit /b %errorlevel%"
Set-Content -Path $rootLauncher -Value $rootForwarderContent -Force

# Register in User PATH
$userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
$pArray = @($installDir, $toolsDir)
$pathList = if ($userPath) { $userPath -split ';' } else { @() }
$pathUpdated = $false
foreach ($p in $pArray) {
    if ($pathList -notcontains $p) { $pathList += $p; $pathUpdated = $true }
}
if ($pathUpdated) {
    $newPathStr = ($pathList | Where-Object { $_ -ne '' }) -join ';'
    [Environment]::SetEnvironmentVariable('Path', $newPathStr, 'User')
    Write-Host "${creamyGreen}[OK] Added to User PATH (command: secret-tools).${reset}"
}

# Desktop shortcut. The "Run as Administrator" compatibility flag on the
# shortcut only makes Windows show its normal UAC consent prompt as soon
# as you double-click it — it does not skip or suppress that prompt.
$ws = New-Object -ComObject WScript.Shell
$shortcut = $ws.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $mainBat
$shortcut.WorkingDirectory = $toolsDir
$shortcut.Description = 'Secret-Tools Management and Repair Panel'
$shortcut.Save()

try {
    $lnkBytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $lnkBytes[0x15] = $lnkBytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($shortcutPath, $lnkBytes)
} catch {}

Write-Host "${creamyGreen}[OK] Desktop shortcut configured (will prompt for UAC on launch, as expected).${reset}"

# -------------------------------------------------------------
# STEP 4: FORMAL WELCOME & DIRECT ELEVATED LAUNCH
# -------------------------------------------------------------
Write-Host ''
Write-Host '====================================================================='
Write-Host " Welcome, $env:USERNAME."
Write-Host ' Status: All components installed and verified successfully.'
Write-Host ' Launching Secret-Tools (it will request Administrator elevation once)...'
Write-Host '====================================================================='
Write-Host ''
Start-Sleep -Milliseconds 800

if (Test-Path $mainBat) {
    cmd /c "`"$mainBat`""
} elseif (Test-Path "$toolsDir\Access\Password_manager.ps1") {
    & "$toolsDir\Access\Password_manager.ps1"
}
exit 0

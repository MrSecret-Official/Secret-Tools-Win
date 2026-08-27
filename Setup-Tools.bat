<# :
@echo off
setlocal EnableDelayedExpansion
title Setup-Tools - Secret-Tools Installer
color 0B
mode con: cols=100 lines=55 >nul 2>&1

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
# STEP 2: ANTIVIRUS DETECTION & EXCLUSION NOTICE
# Dynamically detects all installed and active antivirus engines
# (Windows Defender, Avast, Kaspersky, Bitdefender, Norton, McAfee, etc.)
# and renders tailored step-by-step instructions for the active product.
# -------------------------------------------------------------
function Get-DetectedAntivirus {
    $results = @()
    try {
        $wmi = Get-CimInstance -Namespace 'root/SecurityCenter2' -ClassName 'AntiVirusProduct' -ErrorAction Stop
        foreach ($item in $wmi) {
            $hex = ([int]$item.productState).ToString('X6')
            $rtByte = if ($hex.Length -ge 4) { $hex.Substring(2,2) } else { '00' }
            $isActive = ($rtByte -in @('10', '11'))
            $results += [PSCustomObject]@{
                Name     = $item.displayName
                IsActive = $isActive
                Path     = $item.pathToSignedProductExe
            }
        }
    } catch {}

    if ($results.Count -eq 0) {
        $procMap = [ordered]@{
            'MsMpEng'     = 'Windows Defender'
            'AvastSvc'    = 'Avast Antivirus'
            'AvgSvc'      = 'AVG Antivirus'
            'avp'         = 'Kaspersky'
            'vsserv'      = 'Bitdefender'
            'ccSvcHst'    = 'Norton / Symantec'
            'mcshield'    = 'McAfee'
            'MBAMService' = 'Malwarebytes'
            'ekrn'        = 'ESET Security'
            'SophosEDR'   = 'Sophos'
        }
        foreach ($p in $procMap.Keys) {
            if (Get-Process -Name $p -ErrorAction SilentlyContinue) {
                $results += [PSCustomObject]@{
                    Name     = $procMap[$p]
                    IsActive = $true
                    Path     = ''
                }
            }
        }
    }
    return $results
}

Clear-Host
Show-Banner
Write-Host '============================================================================================='
Write-Host '                         ANTIVIRUS / SECURITY SOFTWARE NOTICE'
Write-Host '============================================================================================='
Write-Host ''
Write-Host "${creamyYellow}[WARNING] Antivirus software may intercept, pause, or block the download!${reset}"
Write-Host ''
Write-Host "${dimText}Because Secret-Tools contains administrative diagnostic, repair, and password management${reset}"
Write-Host "${dimText}scripts, antivirus engines frequently trigger false positives and may stop the download${reset}"
Write-Host "${dimText}or quarantine essential script components.${reset}"
Write-Host ''

# Ensure required directories exist before registering exclusion
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
if (-not (Test-Path $packagesDir)) { New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null }
if (-not (Test-Path "$toolsDir\Access")) { New-Item -ItemType Directory -Path "$toolsDir\Access" -Force | Out-Null }
if (-not (Test-Path "$toolsDir\logs")) { New-Item -ItemType Directory -Path "$toolsDir\logs" -Force | Out-Null }

$detectedAVs = Get-DetectedAntivirus
Write-Host "${creamyCyan}Detected Security & Antivirus Engines on this PC:${reset}"
if ($detectedAVs.Count -gt 0) {
    foreach ($av in $detectedAVs) {
        $statusBadge = if ($av.IsActive) { "${creamyGreen}[ACTIVE / IN USE]${reset}" } else { "${dimText}[INACTIVE / SECONDARY]${reset}" }
        Write-Host "  * $($av.Name) $statusBadge"
    }
} else {
    Write-Host "  * Windows Security / Microsoft Defender ${creamyGreen}[ACTIVE / IN USE]${reset}"
}
Write-Host ''

Write-Host "${creamyCyan}Target Directory to Exclude:${reset}"
Write-Host "  ${creamyGreen}$installDir${reset}"
Write-Host ''

# Show tailored instructions based on the active or detected antivirus
$activeNames = ($detectedAVs | Where-Object { $_.IsActive } | Select-Object -ExpandProperty Name) -join ' '
if (-not $activeNames) { $activeNames = ($detectedAVs | Select-Object -ExpandProperty Name) -join ' ' }

$isThirdParty = ($activeNames -match 'Avast|AVG|Kaspersky|Bitdefender|Norton|Symantec|McAfee|ESET|Malwarebytes|Sophos')

function Show-ManualAVInstructions {
    Write-Host ''
    if ($activeNames -match 'Avast|AVG') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Avast / AVG:${reset}"
        Write-Host "${dimText}  1. Open Avast / AVG -> Click 'Menu (≡)' (top right) -> 'Settings'${reset}"
        Write-Host "${dimText}  2. Go to 'General' tab -> select 'Exceptions'${reset}"
        Write-Host "${dimText}  3. Click 'Add Exception' and enter or browse to: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'Kaspersky') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Kaspersky:${reset}"
        Write-Host "${dimText}  1. Open Kaspersky -> Click the 'Settings (gear)' icon in the bottom left${reset}"
        Write-Host "${dimText}  2. Go to 'Security settings' -> 'Threats and Exclusions' -> 'Manage exclusions'${reset}"
        Write-Host "${dimText}  3. Click 'Add' -> Browse and select folder: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'Bitdefender') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Bitdefender:${reset}"
        Write-Host "${dimText}  1. Open Bitdefender -> Click 'Protection' (left panel) -> 'Antivirus'${reset}"
        Write-Host "${dimText}  2. Go to 'Settings' / 'Exclusions' tab -> Click 'Manage exclusions'${reset}"
        Write-Host "${dimText}  3. Click 'Add an exclusion' -> Select folder: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'Norton|Symantec') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Norton 360 / Symantec:${reset}"
        Write-Host "${dimText}  1. Open Norton -> Click 'Settings' -> 'Antivirus'${reset}"
        Write-Host "${dimText}  2. Select 'Scans and Risks' -> scroll down to 'Exclusions / Low Risks'${reset}"
        Write-Host "${dimText}  3. Next to 'Items to Exclude from Scans', click 'Configure [+]' -> 'Add Folders'${reset}"
        Write-Host "${dimText}  4. Browse to and select: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'McAfee') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for McAfee:${reset}"
        Write-Host "${dimText}  1. Open McAfee -> Go to 'My Protection' (or gear icon) -> 'Real-Time Scanning'${reset}"
        Write-Host "${dimText}  2. Expand 'Excluded Files' -> Click 'Add file or folder'${reset}"
        Write-Host "${dimText}  3. Browse and select folder: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'ESET|NOD32') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for ESET:${reset}"
        Write-Host "${dimText}  1. Open ESET -> Press 'F5' to open Advanced Setup${reset}"
        Write-Host "${dimText}  2. Go to 'Detection Engine' -> 'Exclusions' -> 'Detection exclusions'${reset}"
        Write-Host "${dimText}  3. Click 'Edit' -> 'Add' -> Select folder: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($activeNames -match 'Malwarebytes') {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Malwarebytes:${reset}"
        Write-Host "${dimText}  1. Open Malwarebytes -> Click 'Settings (gear)' -> 'Allow List' tab${reset}"
        Write-Host "${dimText}  2. Click 'Add' -> 'Allow a file or folder'${reset}"
        Write-Host "${dimText}  3. Browse and select folder: ${reset}${creamyCyan}$installDir${reset}"
    } elseif ($detectedAVs.Count -gt 0 -and $activeNames -notmatch 'Windows Defender') {
        Write-Host "${creamyCyan}General Exclusion Guide for your Antivirus:${reset}"
        Write-Host "${dimText}  1. Open your Antivirus control panel from the system tray or Start menu${reset}"
        Write-Host "${dimText}  2. Navigate to Settings -> 'Exclusions', 'Exceptions' or 'Allow List'${reset}"
        Write-Host "${dimText}  3. Add the following folder path to the whitelist: ${reset}${creamyCyan}$installDir${reset}"
    } else {
        Write-Host "${creamyCyan}Step-by-step Exclusion Guide for Windows Defender:${reset}"
        Write-Host "${dimText}  1. Open Windows Security -> Virus & threat protection${reset}"
        Write-Host "${dimText}  2. Click 'Manage settings' under Virus & threat protection settings${reset}"
        Write-Host "${dimText}  3. Under 'Exclusions', click 'Add or remove exclusions' -> 'Add an exclusion'${reset}"
        Write-Host "${dimText}  4. Select 'Folder' and choose: ${reset}${creamyCyan}$installDir${reset}"
    }
    Write-Host ''
    if (-not $isThirdParty) {
        try {
            Start-Process 'windowsdefender://threatsettings' -ErrorAction SilentlyContinue
            Write-Host "${creamyGreen}[*] Opened Windows Security settings page.${reset}"
            Write-Host ''
        } catch {}
    }
}

# Check if folder is already excluded in Defender
$alreadyExcluded = $false
try {
    $currentPrefs = Get-MpPreference -ErrorAction SilentlyContinue
    if ($currentPrefs -and ($currentPrefs.ExclusionPath -contains $installDir)) {
        $alreadyExcluded = $true
    }
} catch {}

if ($alreadyExcluded) {
    Write-Host "${creamyGreen}[OK] Folder '$installDir' is already excluded in Windows Defender.${reset}"
    Write-Host ''
} else {
    Write-Host "${creamyYellow}How would you like to configure antivirus exclusions?${reset}"
    Write-Host ''
    Write-Host "  ${creamyGreen}[1] Automatic Exclusion (Recommended)${reset}"
    Write-Host "${dimText}      Automatically adds '$installDir' to Windows Defender exclusions now.${reset}"
    Write-Host "  ${creamyCyan}[2] Manual Configuration${reset}"
    Write-Host "${dimText}      Opens Windows Security settings and displays step-by-step instructions.${reset}"
    Write-Host "  ${dimText}[3] Skip / Continue without adding exclusion${reset}"
    Write-Host ''
    $exChoice = Read-Host "Select an option (1-3, default: 1)"
    if (-not $exChoice) { $exChoice = '1' }

    if ($exChoice -in @('1', 'Y', 'y', 'S', 's', 'auto', 'automatic')) {
        Write-Host ''
        Write-Host "${creamyCyan}[*] Adding '$installDir' to Windows Defender exclusions...${reset}"
        try {
            Add-MpPreference -ExclusionPath $installDir -ErrorAction Stop
            Write-Host "${creamyGreen}[OK] Successfully added '$installDir' to Windows Defender exclusions!${reset}"
            if ($isThirdParty) {
                Write-Host ''
                Write-Host "${creamyYellow}[!] Note: Third-party antivirus also detected ($activeNames).${reset}"
                Write-Host "${dimText}    Third-party suites cannot be whitelisted via script. Here are the manual steps if needed:${reset}"
                Show-ManualAVInstructions
            }
        } catch {
            Write-Host "${creamyYellow}[!] Automatic exclusion could not be applied directly ($($_.Exception.Message)).${reset}"
            Write-Host "${dimText}    Opening manual security settings...${reset}"
            Show-ManualAVInstructions
        }
    } elseif ($exChoice -in @('2', 'M', 'm', 'manual')) {
        Show-ManualAVInstructions
    } else {
        Write-Host ''
        Write-Host "${dimText}[INFO] Exclusion configuration skipped by user.${reset}"
    }
}

Write-Host ''
Write-Host '============================================================================================='
Write-Host ''
Write-Host 'Press Enter to proceed with download and installation...'
[void][Console]::ReadLine()

# -------------------------------------------------------------
# STEP 3: CHECK REPOSITORY VERSION
# The repository is public, so no GitHub token or account is needed to
# install or update — just a plain, unauthenticated API call.
# -------------------------------------------------------------
Clear-Host
Show-Banner
Write-Host '============================================================================================='
Write-Host '                              DOWNLOAD & INSTALLATION'
Write-Host '============================================================================================='
Write-Host ''

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
# STEP 4: PERFORM DOWNLOAD / UPDATE & DEPLOYMENT
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
# STEP 5: FORMAL WELCOME & DIRECT ELEVATED LAUNCH
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

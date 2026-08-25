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

function Get-DownloaderToken {
    return @(
        'github_pat_11A7BJFXI0q7PNg4npXa5t_',
        'AaKfbL5Yp6NOJvlu6B6f6qGRN9qoIsFOBTFeuQylxJ1G7FHSOLEo477BXMk'
    ) -join ''
}

function Get-AuthToken {
    return @(
        'github_pat_11A7BJFXI0aWiLGzKPpoFO_',
        '2zU1UxvcnbxwZXuLJAXxmC7x8cznkLWEX5lcjinftjyNPS27AYRKvFH89wq'
    ) -join ''
}

function Fetch-RemotePassword([string]$url, [string]$cachePath) {
    try {
        $authTok = Get-AuthToken
        $h = @{
            'Authorization' = ('Bearer ' + $authTok)
            'Accept'        = 'application/vnd.github.v3.raw'
            'User-Agent'    = 'SecretTools-Client'
        }
        $res = Invoke-RestMethod -Uri $url -Headers $h -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
        if ($res) {
            $val = ($res.ToString()).Trim()
            $cd = Split-Path $cachePath -Parent
            if (-not (Test-Path $cd)) { New-Item -ItemType Directory -Path $cd -Force | Out-Null }
            $val | Out-File -FilePath $cachePath -Force -Encoding UTF8
            return $val
        }
    } catch {}
    if (Test-Path $cachePath) {
        return (Get-Content $cachePath -Raw -ErrorAction SilentlyContinue).Trim()
    }
    return $null
}

function Read-MaskedPassword {
    $pass = ""
    while ($true) {
        $key = [Console]::ReadKey($true)
        if ($key.Key -eq [ConsoleKey]::Enter) {
            break
        } elseif ($key.Key -eq [ConsoleKey]::Backspace) {
            if ($pass.Length -gt 0) {
                $pass = $pass.Substring(0, $pass.Length - 1)
                Write-Host -NoNewline "`b `b"
            }
        } else {
            $char = $key.KeyChar
            if ([int]$char -ge 32) {
                $pass += $char
                Write-Host -NoNewline "*"
            }
        }
    }
    Write-Host ""
    return $pass
}

# -------------------------------------------------------------
# STEP 1: INITIALIZE & CHECK REPOSITORY VERSION
# -------------------------------------------------------------
Clear-Host
Show-Banner
Write-Host '============================================================================================='
Write-Host '                              AUTOMATED INSTALLATION WIZARD'
Write-Host '============================================================================================='
Write-Host ''

$token = Get-DownloaderToken
$headers = @{
    'Authorization' = ('Bearer ' + $token)
    'Accept'        = 'application/vnd.github.v3+json'
    'User-Agent'    = 'SecretTools-Installer'
}

$installDir = "$([Environment]::GetFolderPath('UserProfile'))\Tools"
$toolsDir = "$installDir\Tools"
$packagesDir = "$installDir\packages"
$versionFile = "$installDir\.version"
$mainBat = "$toolsDir\secret-tools.bat"
$rootLauncher = "$installDir\secret-tools.bat"
$repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'

# Ensure required directories
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
if (-not (Test-Path $packagesDir)) { New-Item -ItemType Directory -Path $packagesDir -Force | Out-Null }
if (-not (Test-Path "$toolsDir\Access")) { New-Item -ItemType Directory -Path "$toolsDir\Access" -Force | Out-Null }
if (-not (Test-Path "$toolsDir\logs")) { New-Item -ItemType Directory -Path "$toolsDir\logs" -Force | Out-Null }
if (-not (Test-Path "$toolsDir\cache")) { New-Item -ItemType Directory -Path "$toolsDir\cache" -Force | Out-Null }

Write-Host "${creamyCyan}Checking repository update status...${reset}"
$remoteSha = $null
try {
    $commitInfo = Invoke-RestMethod -Uri "$repoApi/commits/main" -Headers $headers -Method Get -TimeoutSec 10 -ErrorAction SilentlyContinue
    $remoteSha = $commitInfo.sha
} catch {}

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
# STEP 2: CREDENTIAL VALIDATION (REQUIRED BEFORE INSTALLING)
# -------------------------------------------------------------
$cacheDir = "$toolsDir\cache"
$u1 = 'https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/Sec-User-Pass.txt'
$u2 = 'https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/MrSecret-Access.txt'
$c1 = "$cacheDir\secret_user.cache"
$c2 = "$cacheDir\mrsecret.cache"

$passSecretUser = Fetch-RemotePassword -url $u1 -cachePath $c1
$passMrSecret = Fetch-RemotePassword -url $u2 -cachePath $c2

Write-Host ''
Write-Host 'Username: Secret-user'
Write-Host ''

$maxAttempts = 3
$attempts = 0
$lastError = ''
$authenticatedUser = $null

while ($attempts -lt $maxAttempts) {
    $passLine = [Console]::CursorTop
    Write-Host -NoNewline 'Password: '
    if ($lastError) {
        Write-Host ''
        Write-Host "${creamyRed}${lastError}${reset}"
        try {
            [Console]::SetCursorPosition(10, $passLine)
        } catch {}
    }
    
    $inputPass = Read-MaskedPassword
    $cleanInput = if ($inputPass) { $inputPass.Trim() } else { '' }
    
    if ($passSecretUser -and ($cleanInput -eq $passSecretUser)) {
        $authenticatedUser = 'Secret-user'
        break
    } elseif ($passMrSecret -and ($cleanInput -eq $passMrSecret)) {
        $authenticatedUser = 'MrSecret_Official'
        break
    } else {
        $attempts++
        $remaining = $maxAttempts - $attempts
        if ($remaining -gt 0) {
            $lastError = "[ERROR] Incorrect password. Attempts remaining: $remaining"
        } else {
            Write-Host ''
            Write-Host "${creamyRed}[ERROR] Access blocked due to multiple failed attempts.${reset}"
            Start-Sleep -Seconds 3
            exit 1
        }
    }
}

if (-not $authenticatedUser) {
    exit 1
}

# Save session cache
$sessionFile = "$cacheDir\session.cache"
$authenticatedUser | Out-File -FilePath $sessionFile -Force -Encoding UTF8
$rootCache = "$installDir\cache"
if (-not (Test-Path $rootCache)) { New-Item -ItemType Directory -Path $rootCache -Force | Out-Null }
$authenticatedUser | Out-File -FilePath "$rootCache\session.cache" -Force -Encoding UTF8

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

# Root launcher forwarder with automated elevated launch
$rootForwarderContent = "@echo off`nsetlocal`nset `"SD=%~dp0`"`nnet session >nul 2>&1`nif %errorlevel% equ 0 (`n    if exist `"%SD%Tools\secret-tools.bat`" (`n        call `"%SD%Tools\secret-tools.bat`" %*`n    ) else (`n        powershell -NoProfile -ExecutionPolicy Bypass -File `"%SD%Tools\Access\Password_manager.ps1`" %*`n    )`n    exit /b %errorlevel%`n)`nschtasks /query /tn `"SecretTools_Elevated`" >nul 2>&1`nif %errorlevel% equ 0 (`n    schtasks /run /tn `"SecretTools_Elevated`" >nul 2>&1`n    exit /b 0`n)`nif exist `"%SD%Tools\secret-tools.bat`" (`n    call `"%SD%Tools\secret-tools.bat`" %*`n) else (`n    powershell -NoProfile -ExecutionPolicy Bypass -File `"%SD%Tools\Access\Password_manager.ps1`" %*`n)`nexit /b %errorlevel%"
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

# Desktop shortcut with mandatory Run As Administrator Flag
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcutPath = "$desktop\Secret-Tools.lnk"
$shortcut = $ws.CreateShortcut($shortcutPath)
$shortcut.TargetPath = $mainBat
$shortcut.WorkingDirectory = $toolsDir
$shortcut.Description = 'Secret-Tools Management and Repair Panel'
$shortcut.Save()

# Set Run as Administrator byte in shortcut file
try {
    $lnkBytes = [System.IO.File]::ReadAllBytes($shortcutPath)
    $lnkBytes[0x15] = $lnkBytes[0x15] -bor 0x20
    [System.IO.File]::WriteAllBytes($shortcutPath, $lnkBytes)
} catch {}

# Register Windows AppCompatFlags to ensure Secret-Tools always runs as Admin
try {
    $regKey = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
    if (-not (Test-Path $regKey)) { New-Item -Path $regKey -Force | Out-Null }
    Set-ItemProperty -Path $regKey -Name $mainBat -Value "~ RUNASADMIN" -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $regKey -Name $rootLauncher -Value "~ RUNASADMIN" -Force -ErrorAction SilentlyContinue
} catch {}

# Register Elevated Scheduled Task (Runs with HIGHEST privileges without UAC prompts)
try {
    cmd /c "schtasks /create /tn `"SecretTools_Elevated`" /tr `"$mainBat`" /rl HIGHEST /sc ONCE /st 00:00 /f" >nul 2>&1
} catch {}

Write-Host "${creamyGreen}[OK] Desktop shortcut & Administrator execution policies configured.${reset}"

# -------------------------------------------------------------
# STEP 4: FORMAL WELCOME & DIRECT ELEVATED LAUNCH
# -------------------------------------------------------------
Write-Host ''
Write-Host '====================================================================='
Write-Host " Welcome, $authenticatedUser."
Write-Host ' Status: All components installed and verified successfully.'
Write-Host ' Launching Secret-Tools directly with Administrator privileges...'
Write-Host '====================================================================='
Write-Host ''
Start-Sleep -Milliseconds 800

# Direct execution handover to Secret-Tools within the same elevated token
if (Test-Path $mainBat) {
    cmd /c "`"$mainBat`""
} elseif (Test-Path "$toolsDir\Access\Password_manager.ps1") {
    & "$toolsDir\Access\Password_manager.ps1"
}
exit 0

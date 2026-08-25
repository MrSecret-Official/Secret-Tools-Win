<# :
@echo off
setlocal
title Setup-Tools - Secret-Tools Installer
color 0B
mode con: cols=95 lines=34 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
exit /b %errorlevel%
#>

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
    $cipher = 'NAwXGhAWCx8OGCx1XjZZLiUnPCxCOlIpfFcGWCM9AkcRKxUOJAoRCFouHlohLi4THj5TOwRWBEcUNy1LFBsdHCkjMRApEhs9Fg0cL0MMUj96Y316FgpXRVI2DCIE'
    $key = [System.Text.Encoding]::UTF8.GetBytes('SecretToolsDownloaderKey2026')
    $bytes = [Convert]::FromBase64String($cipher)
    $dec = for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] -bxor $key[$i % $key.Length] }
    return [System.Text.Encoding]::UTF8.GetString([byte[]]$dec)
}

function Get-AuthToken {
    $cipher = 'NAwXGhAWCx8OGCxiVCJCMCMyIQJVGGVZfnEpLjMCCjIbMF0WJmIwGwMRBxYBPD8hR3x4dwsdDjFSDGwMFQIYHzImLUcFFxMiCx9GWkt4AzZRRSQtBiQZKjtrXBQE'
    $key = [System.Text.Encoding]::UTF8.GetBytes('SecretToolsSecurityKey2026')
    $bytes = [Convert]::FromBase64String($cipher)
    $dec = for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] -bxor $key[$i % $key.Length] }
    return [System.Text.Encoding]::UTF8.GetString([byte[]]$dec)
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
$versionFile = "$installDir\.version"
$mainBat = "$toolsDir\secret-tools.bat"
$rootLauncher = "$installDir\secret-tools.bat"
$repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'

# Ensure required directories
if (-not (Test-Path $installDir)) { New-Item -ItemType Directory -Path $installDir -Force | Out-Null }
if (-not (Test-Path $toolsDir)) { New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null }
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
        $tempZip = "$env:TEMP\SecretTools_pkg_$([guid]::NewGuid().ToString('N')).zip"
        $tempExtract = "$env:TEMP\SecretTools_ext_$([guid]::NewGuid().ToString('N'))"
        try {
            Invoke-RestMethod -Uri "$repoApi/zipball/main" -Headers $headers -OutFile $tempZip -TimeoutSec 30
            Expand-Archive -Path $tempZip -DestinationPath $tempExtract -Force
            $extractedRoot = (Get-ChildItem -Path $tempExtract -Directory | Select-Object -First 1).FullName
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
            if (Test-Path $tempZip) { Remove-Item $tempZip -Force -ErrorAction SilentlyContinue }
            if (Test-Path $tempExtract) { Remove-Item $tempExtract -Recurse -Force -ErrorAction SilentlyContinue }
        }
    }
} else {
    Write-Host "${creamyGreen}[OK] Components already deployed and verified.${reset}"
}

# Root launcher forwarder
$rootForwarderContent = "@echo off`nsetlocal`nset `"SD=%~dp0`"`nif exist `"%SD%Tools\secret-tools.bat`" (`n    call `"%SD%Tools\secret-tools.bat`" %*`n) else (`n    powershell -NoProfile -ExecutionPolicy Bypass -File `"%SD%Tools\Access\Password_manager.ps1`" %*`n)`nexit /b %errorlevel%"
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

# Desktop shortcut
$ws = New-Object -ComObject WScript.Shell
$desktop = [Environment]::GetFolderPath('Desktop')
$shortcut = $ws.CreateShortcut("$desktop\Secret-Tools.lnk")
$shortcut.TargetPath = $mainBat
$shortcut.WorkingDirectory = $toolsDir
$shortcut.Description = 'Secret-Tools Management Panel'
$shortcut.Save()
Write-Host "${creamyGreen}[OK] Desktop shortcut verified.${reset}"

# -------------------------------------------------------------
# STEP 4: FORMAL WELCOME & FINISH
# -------------------------------------------------------------
Write-Host ''
Write-Host '====================================================================='
Write-Host " Welcome, $authenticatedUser."
Write-Host ' Status: All components installed and verified successfully.'
Write-Host '====================================================================='
Write-Host ''
Write-Host 'Press Enter to exit...'
[void][Console]::ReadLine()
exit 0

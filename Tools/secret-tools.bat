<# :
@echo off
setlocal
title Secret-Tools
color 0B
mode con: cols=85 lines=32 >nul 2>&1
powershell -NoProfile -ExecutionPolicy Bypass -Command "Invoke-Expression $([System.IO.File]::ReadAllText('%~f0'))"
exit /b %errorlevel%
#>

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$esc = [char]27
$creamyGreen = "$esc[38;2;145;225;165m"
$creamyRed   = "$esc[38;2;235;120;120m"
$creamyCyan  = "$esc[38;2;130;210;245m"
$reset       = "$esc[0m"

$scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
if (-not $scriptDir) { $scriptDir = "$([Environment]::GetFolderPath('UserProfile'))\Tools" }

$userProfile = [Environment]::GetFolderPath('UserProfile')
$candidateCaches = @(
    "$scriptDir\cache",
    "$userProfile\Tools\cache",
    "$userProfile\Tools\Tools\cache"
)

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

function Get-AuthToken {
    $cipher = 'NAwXGhAWCx8OGCxiVCJCMCMyIQJVGGVZfnEpLjMCCjIbMF0WJmIwGwMRBxYBPD8hR3x4dwsdDjFSDGwMFQIYHzImLUcFFxMiCx9GWkt4AzZRRSQtBiQZKjtrXBQE'
    $key = [System.Text.Encoding]::UTF8.GetBytes('SecretToolsSecurityKey2026')
    $bytes = [Convert]::FromBase64String($cipher)
    $dec = for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] -bxor $key[$i % $key.Length] }
    return [System.Text.Encoding]::UTF8.GetString([byte[]]$dec)
}

function Fetch-Password([string]$url, [string]$cachePath) {
    try {
        $t = Get-AuthToken
        $h = @{
            'Authorization' = ('Bearer ' + $t)
            'Accept'        = 'application/vnd.github.v3.raw'
            'User-Agent'    = 'SecretTools-Client'
        }
        $res = Invoke-RestMethod -Uri $url -Headers $h -Method Get -TimeoutSec 10
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

# 1. Check if session cache exists from Setup or previous login
$cachedUser = $null
foreach ($c in $candidateCaches) {
    $sf = "$c\session.cache"
    if (Test-Path $sf) {
        $u = (Get-Content $sf -Raw -ErrorAction SilentlyContinue).Trim()
        if ($u -eq 'Secret-user' -or $u -eq 'MrSecret_Official') {
            $cachedUser = $u
            break
        }
    }
}

if ($cachedUser) {
    Clear-Host
    Show-Banner
    Write-Host '====================================================================='
    Write-Host " Welcome back, $cachedUser."
    Write-Host ' Status: All components verified and operating normally.'
    Write-Host '====================================================================='
    Write-Host ''
    Write-Host 'Press Enter to exit...'
    [void][Console]::ReadLine()
    exit 0
}

# 2. If no valid session cache, prompt for credentials using exact Setup UI
$primaryCache = $candidateCaches[0]
if (-not (Test-Path $primaryCache)) { New-Item -ItemType Directory -Path $primaryCache -Force | Out-Null }

$u1 = 'https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/Sec-User-Pass.txt'
$u2 = 'https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/MrSecret-Access.txt'
$c1 = "$primaryCache\secret_user.cache"
$c2 = "$primaryCache\mrsecret.cache"

$passSecretUser = Fetch-Password -url $u1 -cachePath $c1
$passMrSecret = Fetch-Password -url $u2 -cachePath $c2

if (-not $passSecretUser -and -not $passMrSecret) {
    Clear-Host
    Show-Banner
    Write-Host "${creamyRed}[ERROR] No credentials available in cache. Initial internet connection required.${reset}"
    Write-Host ''
    Write-Host 'Press Enter to exit...'
    [void][Console]::ReadLine()
    exit 1
}

$maxAttempts = 3
$attempts = 0
$lastError = ''

while ($attempts -lt $maxAttempts) {
    Clear-Host
    Show-Banner
    Write-Host 'Username: Secret-user'
    Write-Host ''
    
    if ($lastError) {
        Write-Host "${creamyRed}${lastError}${reset}"
        Write-Host ''
    }
    
    $sec = Read-Host 'Password' -AsSecureString
    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    $inputPass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    
    $cleanInput = if ($inputPass) { $inputPass.Trim() } else { '' }
    
    $authUser = $null
    if ($passSecretUser -and ($cleanInput -eq $passSecretUser)) {
        $authUser = 'Secret-user'
    } elseif ($passMrSecret -and ($cleanInput -eq $passMrSecret)) {
        $authUser = 'MrSecret_Official'
    }
    
    if ($authUser) {
        foreach ($c in $candidateCaches) {
            if (-not (Test-Path $c)) { New-Item -ItemType Directory -Path $c -Force | Out-Null }
            $authUser | Out-File -FilePath "$c\session.cache" -Force -Encoding UTF8
        }
        Clear-Host
        Show-Banner
        Write-Host '====================================================================='
        Write-Host " Welcome, $authUser."
        Write-Host ' Status: All components installed and verified successfully.'
        Write-Host '====================================================================='
        Write-Host ''
        Write-Host 'Press Enter to exit...'
        [void][Console]::ReadLine()
        exit 0
    } else {
        $attempts++
        $remaining = $maxAttempts - $attempts
        if ($remaining -gt 0) {
            $lastError = "[ERROR] Incorrect password. Attempts remaining: $remaining"
        } else {
            Clear-Host
            Show-Banner
            Write-Host "${creamyRed}[ERROR] Access blocked due to multiple failed attempts.${reset}"
            Start-Sleep -Seconds 3
            exit 1
        }
    }
}

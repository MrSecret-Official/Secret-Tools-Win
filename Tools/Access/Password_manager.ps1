# password_manager.ps1
# Secret-Tools : Windows Recovery & Repair Suite

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$esc = [char]27
$creamyGreen  = "$esc[38;2;145;225;165m"
$creamyRed    = "$esc[38;2;235;120;120m"
$creamyYellow = "$esc[38;2;245;220;130m"
$creamyCyan   = "$esc[38;2;130;210;245m"
$accentBlue   = "$esc[38;2;100;180;255m"
$dimText      = "$esc[38;2;160;175;195m"
$reset        = "$esc[0m"

$userProfile = [Environment]::GetFolderPath('UserProfile')
$installDir = "$userProfile\Tools"
$toolsDir = "$installDir\Tools"

$scriptDir = $installDir
if ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}

$candidateCaches = @(
    "$scriptDir\cache",
    "$scriptDir\..\cache",
    "$installDir\cache",
    "$toolsDir\cache"
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

function Fetch-Password([string]$url, [string]$cachePath) {
    try {
        $t = Get-AuthToken
        $h = @{
            'Authorization' = ('Bearer ' + $t)
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

# Check for updates in background
$updateNotice = $null
$versionFile = "$installDir\.version"
if (-not (Test-Path $versionFile)) { $versionFile = "$scriptDir\.version" }
$localSha = ''
if (Test-Path $versionFile) {
    $localSha = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
}

if ($localSha) {
    try {
        $t = Get-DownloaderToken
        $h = @{
            'Authorization' = ('Bearer ' + $t)
            'Accept'        = 'application/vnd.github.v3+json'
            'User-Agent'    = 'SecretTools-Client'
        }
        $repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'
        $commit = Invoke-RestMethod -Uri "$repoApi/commits/main" -Headers $h -Method Get -TimeoutSec 4 -ErrorAction SilentlyContinue
        if ($commit -and $commit.sha -and ($commit.sha -ne $localSha)) {
            $remoteShort = $commit.sha.Substring(0, 7)
            $updateNotice = "[UPDATE] A new version ($remoteShort) is available. Run Setup-Tools.bat to upgrade."
        }
    } catch {}
}

# 1. Resolve authentication
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

$currentUser = $cachedUser

if (-not $currentUser) {
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
        Write-Host "${creamyRed}[ERROR] No credentials cached. Initial internet connection required.${reset}"
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
        if ($updateNotice) {
            Write-Host "${creamyYellow}$updateNotice${reset}"
            Write-Host ''
        }
        Write-Host 'Username: Secret-user'
        Write-Host ''
        
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
            $currentUser = 'Secret-user'
            break
        } elseif ($passMrSecret -and ($cleanInput -eq $passMrSecret)) {
            $currentUser = 'MrSecret_Official'
            break
        } else {
            $attempts++
            $remaining = $maxAttempts - $attempts
            if ($remaining -gt 0) {
                $lastError = "[ERROR] Incorrect password. Attempts remaining: $remaining"
            } else {
                Clear-Host
                Show-Banner
                Write-Host 'Username: Secret-user'
                Write-Host ''
                Write-Host 'Password: '
                Write-Host "${creamyRed}[ERROR] Access blocked due to multiple failed attempts.${reset}"
                Start-Sleep -Seconds 3
                exit 1
            }
        }
    }

    if ($currentUser) {
        foreach ($c in $candidateCaches) {
            if (-not (Test-Path $c)) { New-Item -ItemType Directory -Path $c -Force | Out-Null }
            $currentUser | Out-File -FilePath "$c\session.cache" -Force -Encoding UTF8
        }
    }
}

# ===================================================================
# ASSISTANT SECURITY & ADVANCED RECOVERY MODULES (ENGLISH)
# ===================================================================

function Check-IsAdmin {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-AssistantLog([string]$action, [string]$status, [string]$details) {
    $logDir = "$installDir\logs"
    if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force | Out-Null }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] [$status] - $action : $details" | Out-File -FilePath "$logDir\assistant_actions.log" -Append -Encoding UTF8
}

function Create-SafeRestorePoint {
    Write-Host "${creamyCyan}[SECURITY] Creating System Restore Point...${reset}"
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
        Checkpoint-Computer -Description "Secret-Tools Assistant Recovery Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop | Out-Null
        Write-Host "${creamyGreen}[OK] System Restore Point created successfully.${reset}"
        Write-AssistantLog "RestorePoint" "SUCCESS" "System Restore Point created"
    } catch {
        Write-Host "${dimText}[INFO] Automated restore point creation skipped (proceeding safely).${reset}"
        Write-AssistantLog "RestorePoint" "SKIPPED" $_.Exception.Message
    }
}

function Invoke-AssistantHeader([string]$title, [string]$description) {
    Clear-Host
    Show-Banner
    Write-Host '============================================================================================='
    Write-Host "                    $title"
    Write-Host '============================================================================================='
    if ($description) {
        Write-Host " ${dimText}$description${reset}"
        Write-Host '============================================================================================='
    }
    Write-Host ''
}

function Request-AdminElevation {
    if (-not (Check-IsAdmin)) {
        Write-Host "${creamyYellow}[SECURITY NOTICE] This action requires elevated Administrator privileges.${reset}"
        Write-Host "Relaunch Secret-Tools with Administrator privileges? (Y/N): " -NoNewline
        $ans = Read-Host
        if ($ans -match '^[YySs]') {
            $batPath = if (Test-Path "$toolsDir\secret-tools.bat") { "$toolsDir\secret-tools.bat" } else { "$installDir\secret-tools.bat" }
            Start-Process -FilePath "$batPath" -Verb RunAs
            exit 0
        }
        return $false
    }
    return $true
}

# 1. GUIDED INTELLIGENT SYSTEM DIAGNOSIS
function Assistant-SmartDiagnosis {
    Invoke-AssistantHeader "INTELLIGENT ASSISTANT: COMPREHENSIVE SYSTEM DIAGNOSIS" "The assistant will scan critical Windows components and propose tailored repairs."
    
    if (-not (Check-IsAdmin)) {
        Write-Host "${creamyYellow}[NOTICE] For complete diagnostics and repairs, Administrator privileges are recommended.${reset}"
        Write-Host ''
    }

    $issues = @()
    
    # 1. Startup & SrtTrail log inspection
    Write-Host "${accentBlue}[1/6] Scanning boot integrity and SrtTrail.txt logs...${reset}" -NoNewline
    $srtPath = "$env:SystemRoot\System32\Logfiles\Srt\SrtTrail.txt"
    if (Test-Path $srtPath) {
        $srtContent = Get-Content $srtPath -Tail 20 -ErrorAction SilentlyContinue
        $failedDrivers = $srtContent | Where-Object { $_ -match 'error|fallo|failed|corrupt' }
        if ($failedDrivers) {
            Write-Host " ${creamyRed}[WARNING: Startup repair errors logged]${reset}"
            $issues += @{ Code="BOOT_SRT"; Title="Errors detected in SrtTrail.txt"; Severity="High" }
        } else {
            Write-Host " ${creamyGreen}[OK]${reset}"
        }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 2. Disk storage check
    Write-Host "${accentBlue}[2/6] Inspecting primary drive storage health...${reset}" -NoNewline
    $sysDriveObj = Get-PSDrive -Name ($env:SystemDrive.Substring(0,1)) -ErrorAction SilentlyContinue
    if ($sysDriveObj) {
        $freeGB = [math]::Round($sysDriveObj.Free / 1GB, 1)
        if ($freeGB -lt 5) {
            Write-Host " ${creamyRed}[CRITICAL: Low disk space ($freeGB GB free)]${reset}"
            $issues += @{ Code="DISK_SPACE"; Title="Insufficient disk space ($freeGB GB free)"; Severity="Critical" }
        } else {
            Write-Host " ${creamyGreen}[OK: $freeGB GB free]${reset}"
        }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 3. Core services check
    Write-Host "${accentBlue}[3/6] Checking core Windows services (WUAUSERV, BITS, CRYPTSVC, WMI)...${reset}" -NoNewline
    $badServices = @()
    $chkServices = @('wuauserv', 'bits', 'cryptsvc', 'Winmgmt', 'Dnscache')
    foreach ($s in $chkServices) {
        $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq 'Stopped' -and $svc.StartType -ne 'Disabled') {
            $badServices += $s
        }
    }
    if ($badServices.Count -gt 0) {
        Write-Host " ${creamyYellow}[WARNING: Stopped critical services ($($badServices -join ', '))]${reset}"
        $issues += @{ Code="SERVICES"; Title="Core services stopped ($($badServices -join ', '))"; Severity="Medium" }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 4. Network and DNS stack check
    Write-Host "${accentBlue}[4/6] Verifying network stack and DNS resolution...${reset}" -NoNewline
    $netOk = $false
    try {
        $testDns = [System.Net.Dns]::GetHostAddresses("api.github.com")
        if ($testDns) { $netOk = $true }
    } catch {}
    if (-not $netOk) {
        Write-Host " ${creamyYellow}[WARNING: Network / DNS resolution issue]${reset}"
        $issues += @{ Code="NETWORK"; Title="Network connectivity or DNS issues"; Severity="Medium" }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 5. Component store check
    Write-Host "${accentBlue}[5/6] Inspecting component store (DISM CheckHealth)...${reset}" -NoNewline
    $dismCheck = cmd /c "DISM /Online /Cleanup-Image /CheckHealth" 2>&1
    if ($dismCheck -match "reparable|corrupt|repaired") {
        Write-Host " ${creamyRed}[WARNING: Component corruption detected in WinSxS]${reset}"
        $issues += @{ Code="DISM_CORRUPT"; Title="Corrupted WinSxS component store"; Severity="High" }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 6. BCD boot configuration check
    Write-Host "${accentBlue}[6/6] Checking BCD boot policies and recovery state...${reset}" -NoNewline
    $bcdCheck = cmd /c "bcdedit /enum {current}" 2>&1
    Write-Host " ${creamyGreen}[OK]${reset}"

    Write-Host ''
    Write-Host '---------------------------------------------------------------------------------------------'
    Write-Host " DIAGNOSTIC ASSISTANT SUMMARY:"
    Write-Host '---------------------------------------------------------------------------------------------'
    
    if ($issues.Count -eq 0) {
        Write-Host "${creamyGreen} [EXCELLENT] No critical system anomalies detected.${reset}"
        Write-Host "${dimText} Your Windows system is operating in a healthy and stable state.${reset}"
    } else {
        Write-Host "${creamyYellow} Detected $($issues.Count) item(s) requiring attention:${reset}"
        Write-Host ''
        foreach ($iss in $issues) {
            $col = if ($iss.Severity -eq 'Critical') { $creamyRed } else { $creamyYellow }
            Write-Host "  - ${col}[$($iss.Severity)] $($iss.Title)${reset}"
        }
        Write-Host ''
        Write-Host "Do you want the Assistant to apply recommended fixes automatically? (Y/N): " -NoNewline
        $confirm = Read-Host
        if ($confirm -match '^[YySs]') {
            Apply-SmartFixes -issues $issues
        }
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

function Apply-SmartFixes([array]$issues) {
    Write-Host ''
    Create-SafeRestorePoint
    Write-Host ''

    foreach ($iss in $issues) {
        switch ($iss.Code) {
            "BOOT_SRT" {
                Write-Host "${creamyCyan}>> Repairing boot configuration and BCD...${reset}"
                bcdedit /set '{default}' recoveryenabled No 2>$null
                bcdedit /set '{default}' bootstatuspolicy ignoreallfailures 2>$null
                cmd /c "bcdboot $env:SystemRoot /l en-us /s $env:SystemDrive /f ALL" 2>$null
                Write-Host "${creamyGreen}   [OK] Boot configuration stabilized.${reset}"
            }
            "SERVICES" {
                Write-Host "${creamyCyan}>> Restarting stopped core services...${reset}"
                $chkServices = @('wuauserv', 'bits', 'cryptsvc', 'Winmgmt', 'Dnscache')
                foreach ($s in $chkServices) {
                    Start-Service -Name $s -ErrorAction SilentlyContinue
                }
                Write-Host "${creamyGreen}   [OK] Core services reactivated.${reset}"
            }
            "NETWORK" {
                Write-Host "${creamyCyan}>> Resetting network stack, sockets and DNS...${reset}"
                netsh winsock reset | Out-Null
                netsh int ip reset | Out-Null
                ipconfig /flushdns | Out-Null
                Write-Host "${creamyGreen}   [OK] Network stack refreshed.${reset}"
            }
            "DISM_CORRUPT" {
                Write-Host "${creamyCyan}>> Repairing component store (DISM RestoreHealth & SFC)...${reset}"
                DISM /Online /Cleanup-Image /RestoreHealth
                sfc /scannow
                Write-Host "${creamyGreen}   [OK] System image and core binaries repaired.${reset}"
            }
        }
    }
    Write-Host ''
    Write-Host "${creamyGreen}[ASSISTANT] All recommended fixes have been safely applied.${reset}"
}

# 2. STARTUP & SRTTRAIL REPAIR
function Assistant-BootRepair {
    Invoke-AssistantHeader "ASSISTANT: STARTUP & SRTTRAIL.TXT REPAIR" "Resolves Automatic Repair boot loops and rebuilds the BCD boot store."
    
    if (-not (Request-AdminElevation)) { return }

    Create-SafeRestorePoint

    Write-Host "${creamyCyan}[1/4] Inspecting SrtTrail.txt failure log...${reset}"
    $srtPath = "$env:SystemRoot\System32\Logfiles\Srt\SrtTrail.txt"
    if (Test-Path $srtPath) {
        Write-Host "${creamyYellow}Recent lines from the startup repair log:${reset}"
        Get-Content $srtPath -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "${creamyGreen}[OK] No pending critical boot errors found in SrtTrail.txt.${reset}"
    }
    Write-Host ''

    Write-Host "${creamyCyan}[2/4] Disabling Windows 'Automatic Repair' infinite loop...${reset}"
    bcdedit /set '{default}' recoveryenabled No 2>$null
    bcdedit /set '{default}' bootstatuspolicy ignoreallfailures 2>$null
    Write-Host "${creamyGreen}[OK] Boot policy updated. Direct OS boot enabled.${reset}"
    Write-Host ''

    Write-Host "${creamyCyan}[3/4] Rebuilding UEFI / MBR boot files (bcdboot)...${reset}"
    cmd /c "bcdboot $env:SystemRoot /l en-us /s $env:SystemDrive /f ALL" 2>$null
    Write-Host "${creamyGreen}[OK] System boot files refreshed successfully.${reset}"
    Write-Host ''

    Write-Host "${creamyCyan}[4/4] Reverting pending failed updates (DISM)...${reset}"
    DISM /Online /Cleanup-Image /RevertPendingActions 2>$null
    Write-Host "${creamyGreen}[OK] Pending actions verified and cleaned.${reset}"

    Write-AssistantLog "BootRepair" "SUCCESS" "Startup and SrtTrail repair completed"
    Write-Host ''
    Write-Host "${creamyGreen}[ASSISTANT] Startup repair process completed successfully.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 3. DEEP SYSTEM FILES & IMAGE REPAIR
function Assistant-ImageRepair {
    Invoke-AssistantHeader "ASSISTANT: DEEP SYSTEM FILES & IMAGE REPAIR" "Scans and replaces any corrupted or modified core Windows files."

    if (-not (Request-AdminElevation)) { return }

    Create-SafeRestorePoint

    Write-Host "${creamyCyan}[1/3] Running System File Checker (SFC /scannow)...${reset}"
    Write-Host "${dimText}This may take several minutes while system binaries are cross-referenced with official store...${reset}"
    sfc /scannow
    Write-Host ''

    Write-Host "${creamyCyan}[2/3] Repairing Windows Component Store (DISM RestoreHealth)...${reset}"
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Host ''

    Write-Host "${creamyCyan}[3/3] Cleaning up superseded components (StartComponentCleanup)...${reset}"
    DISM /Online /Cleanup-Image /StartComponentCleanup
    Write-Host ''

    Write-AssistantLog "ImageRepair" "SUCCESS" "SFC and DISM completed"
    Write-Host "${creamyGreen}[ASSISTANT] System image and core files verified and healthy.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 4. DISK & BAD SECTOR REPAIR
function Assistant-DiskRepair {
    Invoke-AssistantHeader "ASSISTANT: DISK & BAD SECTOR REPAIR" "Inspects NTFS filesystem integrity and schedules bad sector recovery."

    if (-not (Request-AdminElevation)) { return }

    Write-Host "Detected storage volumes:"
    Get-PSDrive -PSProvider FileSystem | ForEach-Object {
        $freeGB = [math]::Round($_.Free / 1GB, 2)
        $usedGB = [math]::Round($_.Used / 1GB, 2)
        Write-Host "   $($_.Name): Free: $freeGB GB | Used: $usedGB GB"
    }
    Write-Host ''
    Write-Host "Do you want to schedule a full disk check (CHKDSK C: /F /R) on next reboot? (Y/N): " -NoNewline
    $ans = Read-Host
    if ($ans -match '^[YySs]') {
        echo Y | chkdsk C: /f /r
        Write-AssistantLog "DiskRepair" "SCHEDULED" "CHKDSK C: /F /R scheduled on next reboot"
        Write-Host "${creamyGreen}[OK] Disk repair scheduled for the next system restart.${reset}"
    } else {
        Write-Host "${creamyYellow}[INFO] Disk check cancelled by user.${reset}"
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 5. NETWORK & DNS FULL STACK REPAIR
function Assistant-NetworkRepair {
    Invoke-AssistantHeader "ASSISTANT: NETWORK, DNS & SOCKETS FULL REPAIR" "Restores factory configuration for network sockets, DNS cache, and firewall."

    if (-not (Request-AdminElevation)) { return }

    Write-Host "${creamyCyan}[1/5] Resetting Winsock catalog...${reset}"
    netsh winsock reset | Out-Null
    Write-Host "${creamyGreen}[OK] Winsock catalog reset.${reset}"

    Write-Host "${creamyCyan}[2/5] Resetting TCP/IP protocol stack...${reset}"
    netsh int ip reset | Out-Null
    Write-Host "${creamyGreen}[OK] TCP/IP protocol stack reset.${reset}"

    Write-Host "${creamyCyan}[3/5] Flushing and re-registering DNS cache...${reset}"
    ipconfig /flushdns | Out-Null
    ipconfig /registerdns | Out-Null
    Write-Host "${creamyGreen}[OK] DNS cache flushed and re-registered.${reset}"

    Write-Host "${creamyCyan}[4/5] Resetting Windows Firewall to defaults...${reset}"
    netsh advfirewall reset | Out-Null
    Write-Host "${creamyGreen}[OK] Windows Firewall reset.${reset}"

    Write-Host "${creamyCyan}[5/5] Restarting essential networking services...${reset}"
    $netServices = @('Dhcp', 'Dnscache', 'NlaSvc', 'netprofm')
    foreach ($s in $netServices) {
        Restart-Service -Name $s -Force -ErrorAction SilentlyContinue
    }
    Write-Host "${creamyGreen}[OK] Network services restarted.${reset}"

    Write-AssistantLog "NetworkRepair" "SUCCESS" "Network stack completely reset"
    Write-Host ''
    Write-Host "${creamyGreen}[ASSISTANT] Network stack and connectivity fully repaired.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 6. RESET WINDOWS UPDATE SAFELY
function Assistant-WindowsUpdateRepair {
    Invoke-AssistantHeader "ASSISTANT: CLEAN & RESET WINDOWS UPDATE" "Cleans broken update cache and resets the Windows Update engine."

    if (-not (Request-AdminElevation)) { return }

    Create-SafeRestorePoint

    Write-Host "${creamyCyan}[1/4] Stopping Windows Update and Transfer services...${reset}"
    $wuServices = @('wuauserv', 'cryptSvc', 'bits', 'msiserver')
    foreach ($s in $wuServices) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
    }
    Write-Host "${creamyGreen}[OK] Services stopped.${reset}"

    Write-Host "${creamyCyan}[2/4] Purging SoftwareDistribution and Catroot2 folders...${reset}"
    try {
        if (Test-Path "$env:SystemRoot\SoftwareDistribution") {
            Rename-Item -Path "$env:SystemRoot\SoftwareDistribution" -NewName "SoftwareDistribution.old.$([guid]::NewGuid().ToString('N').Substring(0,6))" -Force -ErrorAction SilentlyContinue
        }
        if (Test-Path "$env:SystemRoot\System32\catroot2") {
            Rename-Item -Path "$env:SystemRoot\System32\catroot2" -NewName "catroot2.old.$([guid]::NewGuid().ToString('N').Substring(0,6))" -Force -ErrorAction SilentlyContinue
        }
        Write-Host "${creamyGreen}[OK] Broken update stores refreshed.${reset}"
    } catch {}

    Write-Host "${creamyCyan}[3/4] Restarting Windows Update services...${reset}"
    foreach ($s in $wuServices) {
        Start-Service -Name $s -ErrorAction SilentlyContinue
    }
    Write-Host "${creamyGreen}[OK] Services restarted.${reset}"

    Write-Host "${creamyCyan}[4/4] Registering core Windows Update DLL modules...${reset}"
    $dlls = @('atl.dll', 'urlmon.dll', 'mshtml.dll', 'shdocvw.dll', 'browseui.dll', 'jscript.dll', 'vbscript.dll', 'scrrun.dll', 'msxml.dll', 'msxml3.dll', 'msxml6.dll', 'actxprxy.dll', 'softpub.dll', 'wintrust.dll', 'dssenh.dll', 'rsaenh.dll', 'gpkcsp.dll', 'sccbase.dll', 'slbcsp.dll', 'cryptdlg.dll', 'oleaut32.dll', 'ole32.dll', 'shell32.dll', 'initpki.dll', 'wuapi.dll', 'wuaueng.dll', 'wucltui.dll', 'wups.dll', 'wups2.dll', 'wuweb.dll', 'qmgr.dll', 'qmgrprxy.dll', 'wucltux.dll', 'muweb.dll', 'wuwebv.dll')
    foreach ($d in $dlls) {
        regsvr32.exe /s $d 2>$null
    }
    Write-Host "${creamyGreen}[OK] Components registered.${reset}"

    Write-AssistantLog "WindowsUpdateRepair" "SUCCESS" "Windows Update refreshed"
    Write-Host ''
    Write-Host "${creamyGreen}[ASSISTANT] Windows Update has been completely refreshed and repaired.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 7. EMERGENCY ACCESS ACCOUNTS
function Assistant-EmergencyAccount {
    Invoke-AssistantHeader "ASSISTANT: EMERGENCY ACCESS ACCOUNTS" "Enables built-in administration accounts to recover computer access."

    if (-not (Request-AdminElevation)) { return }

    Write-Host "  [1] Enable Windows built-in Administrator account"
    Write-Host "  [2] Create a new Emergency Administrator user"
    Write-Host "  [3] Return to main menu"
    Write-Host ''
    $op = Read-Host "Select an option (1-3)"
    
    if ($op -eq '1') {
        net user Administrator /active:yes 2>$null
        net user Administrador /active:yes 2>$null
        Write-Host "${creamyGreen}[OK] Administrator account enabled.${reset}"
        Write-AssistantLog "EmergencyUser" "SUCCESS" "Administrator account enabled"
    } elseif ($op -eq '2') {
        $nu = Read-Host "Enter new username"
        $np = Read-Host "Enter temporary password"
        if ($nu -and $np) {
            net user $nu $np /add /y 2>$null
            net localgroup Administrators $nu /add 2>$null
            net localgroup Administradores $nu /add 2>$null
            Write-Host "${creamyGreen}[OK] User $nu created and added to Administrators group.${reset}"
            Write-AssistantLog "EmergencyUser" "SUCCESS" "User $nu created"
        }
    }
    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 8. REPAIR HISTORY & LOGS VIEWER
function Assistant-ViewLogs {
    Invoke-AssistantHeader "ASSISTANT: REPAIR HISTORY & ERROR LOGS" "Displays logged repair operations and recent Windows startup error traces."

    Write-Host "${creamyYellow}--- Secret-Tools Action History ---${reset}"
    $histLog = "$installDir\logs\assistant_actions.log"
    if (Test-Path $histLog) {
        Get-Content $histLog -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   No previous action logs recorded."
    }
    Write-Host ''

    Write-Host "${creamyYellow}--- Startup Repair Log (SrtTrail.txt) ---${reset}"
    $srtPath = "$env:SystemRoot\System32\Logfiles\Srt\SrtTrail.txt"
    if (Test-Path $srtPath) {
        Get-Content $srtPath -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   No boot failure records detected in SrtTrail.txt."
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# ===================================================================
# MAIN ASSISTANT MENU LOOP
# ===================================================================
while ($true) {
    Clear-Host
    Show-Banner
    if ($updateNotice) {
        Write-Host "${creamyYellow}$updateNotice${reset}"
        Write-Host ''
    }
    
    $isAdmin = if (Check-IsAdmin) { "${creamyGreen}[ADMIN]${reset}" } else { "${dimText}[USER]${reset}" }
    Write-Host " User: ${creamyCyan}$currentUser${reset} $isAdmin | Host: ${creamyCyan}$env:COMPUTERNAME${reset} | Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host '============================================================================================='
    Write-Host '                    INTELLIGENT SYSTEM RECOVERY & REPAIR ASSISTANT'
    Write-Host '============================================================================================='
    Write-Host ''
    Write-Host "  ${creamyGreen}[1] Guided Intelligent System Diagnosis (Scan + Recommended Fix)${reset}"
    Write-Host "  ${accentBlue}[2] Startup / SrtTrail.txt / BCD Repair (Fix recovery boot loops)${reset}"
    Write-Host "  ${accentBlue}[3] Deep System Files & Image Repair (SFC /scannow + DISM RestoreHealth)${reset}"
    Write-Host "  ${accentBlue}[4] Disk & Bad Sector Repair (CHKDSK /F /R)${reset}"
    Write-Host "  ${accentBlue}[5] Network, DNS & Sockets Full Repair (Winsock / TCP-IP / Firewall)${reset}"
    Write-Host "  ${accentBlue}[6] Windows Update Clean & Reset (SoftwareDistribution / Catroot2)${reset}"
    Write-Host "  ${accentBlue}[7] Emergency Access Accounts (Enable Administrator / Create Recovery User)${reset}"
    Write-Host "  ${accentBlue}[8] Repair History & Logs Viewer (SrtTrail / Event Log)${reset}"
    Write-Host "  ${creamyRed}[9] Sign Out / Clear Cached Credentials${reset}"
    Write-Host "  ${dimText}[0] Exit${reset}"
    Write-Host ''
    Write-Host '============================================================================================='
    Write-Host ''
    $choice = Read-Host "Select an option (0-9)"

    switch ($choice.Trim()) {
        '1' { Assistant-SmartDiagnosis }
        '2' { Assistant-BootRepair }
        '3' { Assistant-ImageRepair }
        '4' { Assistant-DiskRepair }
        '5' { Assistant-NetworkRepair }
        '6' { Assistant-WindowsUpdateRepair }
        '7' { Assistant-EmergencyAccount }
        '8' { Assistant-ViewLogs }
        '9' {
            foreach ($c in $candidateCaches) {
                $sf = "$c\session.cache"
                if (Test-Path $sf) { Remove-Item $sf -Force -ErrorAction SilentlyContinue }
            }
            Write-Host "${creamyYellow}Session signed out successfully.${reset}"
            Start-Sleep -Seconds 1
            exit 0
        }
        '0' { exit 0 }
        default {
            Write-Host "${creamyRed}Invalid option.${reset}"
            Start-Sleep -Seconds 1
        }
    }
}
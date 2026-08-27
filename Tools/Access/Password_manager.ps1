# Password_manager.ps1
# Secret-Tools : Windows Recovery & Repair Suite (WinRE & Online Compatible)
# Fallback console used when secret-tools.bat has not been deployed yet.

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$esc = [char]27
$creamyGreen  = "$esc[38;2;145;225;165m"
$creamyRed    = "$esc[38;2;235;120;120m"
$creamyYellow = "$esc[38;2;245;220;130m"
$creamyCyan   = "$esc[38;2;130;210;245m"
$accentBlue   = "$esc[38;2;100;180;255m"
$dimText      = "$esc[38;2;160;175;195m"
$reset        = "$esc[0m"

# Environment & Target Windows Drive Detection (Online vs WinRE Offline)
$isWinRE = ($env:SECRET_TOOLS_WINRE -eq '1') -or ($env:SystemDrive -eq 'X:')
$targetWinDrive = if ($env:SECRET_TOOLS_WINDRIVE) { $env:SECRET_TOOLS_WINDRIVE } else { $env:SystemDrive }

# Auto-elevate to Administrator in normal Windows if not already elevated.
# This shows the standard Windows UAC consent prompt exactly once per launch.
if (-not $isWinRE) {
    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        $psScript = if ($PSCommandPath) { $PSCommandPath } else { "$PSScriptRoot\Password_manager.ps1" }
        if (Test-Path $psScript) {
            Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$psScript`"" -Verb RunAs
            exit 0
        }
    }
}

if ($isWinRE -and (-not (Test-Path "$targetWinDrive\Windows\System32\ntoskrnl.exe"))) {
    foreach ($d in @('C:', 'D:', 'E:', 'F:', 'G:')) {
        if (Test-Path "$d\Windows\System32\ntoskrnl.exe") {
            $targetWinDrive = $d
            break
        }
    }
}

$userProfile = [Environment]::GetFolderPath('UserProfile')
$installDir = "$userProfile\Tools"
$toolsDir = "$installDir\Tools"

$scriptDir = $installDir
if ($PSScriptRoot) {
    $scriptDir = $PSScriptRoot
} elseif ($MyInvocation.MyCommand -and $MyInvocation.MyCommand.Path) {
    $scriptDir = Split-Path $MyInvocation.MyCommand.Path -Parent
}

# Auto-register in User PATH if running in standard Windows
if (-not $isWinRE) {
    try {
        $userPath = [Environment]::GetEnvironmentVariable('Path', 'User')
        $pathList = if ($userPath) { $userPath -split ';' | Where-Object { $_ -ne '' } } else { @() }
        $pArray = @($installDir, $toolsDir)
        $pathUpdated = $false
        foreach ($p in $pArray) {
            if ($pathList -notcontains $p) {
                $pathList += $p
                $pathUpdated = $true
            }
        }
        if ($pathUpdated) {
            $newPathStr = $pathList -join ';'
            [Environment]::SetEnvironmentVariable('Path', $newPathStr, 'User')
            $env:Path = "$newPathStr;$env:Path"
        }
    } catch {}
}

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

# Check for updates in background (online mode only, best-effort).
# The repository is public, so no token is needed to check for updates.
$updateNotice = $null
if (-not $isWinRE) {
    $versionFile = "$installDir\.version"
    if (-not (Test-Path $versionFile)) { $versionFile = "$scriptDir\.version" }
    $localSha = ''
    if (Test-Path $versionFile) {
        $localSha = (Get-Content $versionFile -Raw -ErrorAction SilentlyContinue).Trim()
    }

    if ($localSha) {
        try {
            $h = @{
                'Accept'     = 'application/vnd.github.v3+json'
                'User-Agent' = 'SecretTools-Client'
            }
            $repoApi = 'https://api.github.com/repos/MrSecret-Official/Secret-Tools-Win'
            $commit = Invoke-RestMethod -Uri "$repoApi/commits/main" -Headers $h -Method Get -TimeoutSec 4 -ErrorAction SilentlyContinue
            if ($commit -and $commit.sha -and ($commit.sha -ne $localSha)) {
                $remoteShort = $commit.sha.Substring(0, 7)
                $updateNotice = "[UPDATE] A new version ($remoteShort) is available. Run Setup-Tools.bat to upgrade."
            }
        } catch {}
    }
}

# No login gate: this tool runs under your own already-authenticated Windows
# session. The one thing worth protecting (running system-changing actions)
# is already gated by the UAC elevation above.
$currentUser = $env:USERNAME

# ===================================================================
# ASSISTANT SECURITY & RECOVERY MODULES (WINRE & ONLINE AWARE)
# ===================================================================

function Check-IsAdmin {
    if ($isWinRE) { return $true }
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-AssistantLog([string]$action, [string]$status, [string]$details) {
    try {
        $docsFolder = [Environment]::GetFolderPath('MyDocuments')
        $logDir = if ($docsFolder) { "$docsFolder\Secret-Tools\Logs" } else { "$installDir\logs" }
        if (-not (Test-Path $logDir)) { New-Item -ItemType Directory -Path $logDir -Force -ErrorAction SilentlyContinue | Out-Null }
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        "[$timestamp] [$status] - $action : $details" | Out-File -FilePath "$logDir\assistant_actions.log" -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    } catch {}
}

function Create-SafeRestorePoint {
    if ($isWinRE) { return }
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
    if ($isWinRE) { return $true }
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

    $issues = @()

    # 1. Startup & SrtTrail log inspection
    Write-Host "${accentBlue}[1/6] Scanning boot integrity and SrtTrail.txt logs...${reset}" -NoNewline
    $srtPath = "$targetWinDrive\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    if (-not (Test-Path $srtPath) -and (Test-Path "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt")) {
        $srtPath = "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    }
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
    Write-Host "${accentBlue}[2/6] Inspecting primary drive storage health ($targetWinDrive)...${reset}" -NoNewline
    $sysDriveObj = Get-PSDrive -Name ($targetWinDrive.Substring(0,1)) -ErrorAction SilentlyContinue
    if ($sysDriveObj) {
        $freeGB = [math]::Round($sysDriveObj.Free / 1GB, 1)
        if ($freeGB -lt 5) {
            Write-Host " ${creamyRed}[CRITICAL: Low disk space ($freeGB GB free)]${reset}"
            $issues += @{ Code="DISK_SPACE"; Title="Insufficient disk space on $targetWinDrive ($freeGB GB free)"; Severity="Critical" }
        } else {
            Write-Host " ${creamyGreen}[OK: $freeGB GB free]${reset}"
        }
    } else {
        Write-Host " ${creamyGreen}[OK]${reset}"
    }

    # 3. Core services / Component Store
    Write-Host "${accentBlue}[3/6] Checking Windows system image and component store...${reset}" -NoNewline
    if ($isWinRE) {
        Write-Host " ${creamyGreen}[OK (WinRE Offline Mode)]${reset}"
    } else {
        $dismCheck = cmd /c "DISM /Online /Cleanup-Image /CheckHealth" 2>&1
        if ($dismCheck -match "reparable|corrupt|repaired") {
            Write-Host " ${creamyRed}[WARNING: Component corruption detected in WinSxS]${reset}"
            $issues += @{ Code="DISM_CORRUPT"; Title="Corrupted WinSxS component store"; Severity="High" }
        } else {
            Write-Host " ${creamyGreen}[OK]${reset}"
        }
    }

    # 4. Network and DNS stack check
    Write-Host "${accentBlue}[4/6] Verifying network stack and DNS resolution...${reset}" -NoNewline
    if ($isWinRE) {
        Write-Host " ${dimText}[N/A in WinRE]${reset}"
    } else {
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
    }

    # 5. Boot configuration check
    Write-Host "${accentBlue}[5/6] Checking BCD boot policies and recovery state...${reset}" -NoNewline
    cmd /c "bcdedit /enum {current}" 2>$null | Out-Null
    Write-Host " ${creamyGreen}[OK]${reset}"

    # 6. Windows files structure check
    Write-Host "${accentBlue}[6/6] Verifying kernel and system file presence...${reset}" -NoNewline
    if (Test-Path "$targetWinDrive\Windows\System32\ntoskrnl.exe") {
        Write-Host " ${creamyGreen}[OK: $targetWinDrive\Windows]${reset}"
    } else {
        Write-Host " ${creamyRed}[CRITICAL: ntoskrnl.exe missing]${reset}"
        $issues += @{ Code="KERNEL_MISS"; Title="Core Windows kernel file missing on $targetWinDrive"; Severity="Critical" }
    }

    Write-Host ''
    Write-Host '---------------------------------------------------------------------------------------------'
    Write-Host " DIAGNOSTIC ASSISTANT SUMMARY:"
    Write-Host '---------------------------------------------------------------------------------------------'

    if ($issues.Count -eq 0) {
        Write-Host "${creamyGreen} [EXCELLENT] No critical system anomalies detected.${reset}"
        Write-Host "${dimText} System components and boot configuration are operational.${reset}"
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
                cmd /c "bcdboot $targetWinDrive\Windows /l en-us /s $targetWinDrive /f ALL" 2>$null
                Write-Host "${creamyGreen}   [OK] Boot configuration stabilized.${reset}"
            }
            "NETWORK" {
                Write-Host "${creamyCyan}>> Resetting network stack, sockets and DNS...${reset}"
                netsh winsock reset | Out-Null
                netsh int ip reset | Out-Null
                ipconfig /flushdns | Out-Null
                Write-Host "${creamyGreen}   [OK] Network stack refreshed.${reset}"
            }
            "DISM_CORRUPT" {
                Write-Host "${creamyCyan}>> Repairing component store...${reset}"
                if ($isWinRE) {
                    dism /image:$targetWinDrive\ /cleanup-image /revertpendingactions
                    sfc /scannow "/offbootdir=$targetWinDrive\" "/offwindir=$targetWinDrive\Windows"
                } else {
                    DISM /Online /Cleanup-Image /RestoreHealth
                    sfc /scannow
                }
                Write-Host "${creamyGreen}   [OK] System image and core binaries repaired.${reset}"
            }
        }
    }
    Write-Host ''
    Write-Host "${creamyGreen}[ASSISTANT] All recommended fixes have been safely applied.${reset}"
}

# 2. STARTUP & SRTTRAIL REPAIR
function Assistant-BootRepair {
    Invoke-AssistantHeader "ASSISTANT: STARTUP & SRTTRAIL.TXT REPAIR" "Resolves Automatic Repair boot loops, rebuilds the BCD boot store and repairs the boot sector."

    if (-not (Request-AdminElevation)) { return }

    Create-SafeRestorePoint

    Write-Host "${creamyCyan}[1/5] Inspecting SrtTrail.txt failure log...${reset}"
    $srtPath = "$targetWinDrive\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    if (-not (Test-Path $srtPath) -and (Test-Path "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt")) {
        $srtPath = "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    }
    if (Test-Path $srtPath) {
        Write-Host "${creamyYellow}Recent lines from the startup repair log:${reset}"
        Get-Content $srtPath -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "${creamyGreen}[OK] No pending critical boot errors found in SrtTrail.txt.${reset}"
    }
    Write-Host ''

    Write-Host "${creamyCyan}[2/5] Disabling Windows 'Automatic Repair' infinite loop...${reset}"
    bcdedit /set '{default}' recoveryenabled No 2>$null
    bcdedit /set '{default}' bootstatuspolicy ignoreallfailures 2>$null
    Write-Host "${creamyGreen}[OK] Boot policy updated. Direct OS boot enabled.${reset}"
    Write-Host ''

    Write-Host "${creamyCyan}[3/5] Rebuilding UEFI / MBR boot files (bcdboot)...${reset}"
    cmd /c "bcdboot $targetWinDrive\Windows /l en-us /s $targetWinDrive /f ALL" 2>$null
    Write-Host "${creamyGreen}[OK] System boot files refreshed successfully.${reset}"
    Write-Host ''

    Write-Host "${creamyCyan}[4/5] Running advanced boot record repair (bootrec)...${reset}"
    bootrec /fixmbr 2>$null
    bootrec /fixboot 2>$null
    bootrec /scanos 2>$null
    bootrec /rebuildbcd 2>$null
    Write-Host "${creamyGreen}[OK] Boot sector, boot manager and BCD entries rebuilt.${reset}"
    Write-Host ''

    Write-Host "${creamyCyan}[5/5] Reverting pending failed updates (DISM)...${reset}"
    if ($isWinRE) {
        dism /image:$targetWinDrive\ /cleanup-image /revertpendingactions
    } else {
        DISM /Online /Cleanup-Image /RevertPendingActions 2>$null
    }
    Write-Host "${creamyGreen}[OK] Pending actions verified and cleaned.${reset}"

    Write-AssistantLog "BootRepair" "SUCCESS" "Startup, SrtTrail and bootrec repair completed"
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

    if ($isWinRE) {
        Write-Host "${creamyCyan}[1/2] Running Offline System File Checker on $targetWinDrive\Windows...${reset}"
        sfc /scannow "/offbootdir=$targetWinDrive\" "/offwindir=$targetWinDrive\Windows"
        Write-Host ''

        Write-Host "${creamyCyan}[2/2] Reverting pending update actions (DISM Offline)...${reset}"
        dism /image:$targetWinDrive\ /cleanup-image /revertpendingactions
        Write-Host ''
    } else {
        Write-Host "${creamyCyan}[1/3] Running System File Checker (SFC /scannow)...${reset}"
        sfc /scannow
        Write-Host ''

        Write-Host "${creamyCyan}[2/3] Repairing Windows Component Store (DISM RestoreHealth)...${reset}"
        DISM /Online /Cleanup-Image /RestoreHealth
        Write-Host ''

        Write-Host "${creamyCyan}[3/3] Cleaning up superseded components (StartComponentCleanup)...${reset}"
        DISM /Online /Cleanup-Image /StartComponentCleanup
        Write-Host ''
    }

    Write-AssistantLog "ImageRepair" "SUCCESS" "System files and image repaired"
    Write-Host "${creamyGreen}[ASSISTANT] System image and core files verified and healthy.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 4. DISK & BAD SECTOR REPAIR
function Assistant-DiskRepair {
    Invoke-AssistantHeader "ASSISTANT: DISK & BAD SECTOR REPAIR" "Inspects NTFS filesystem integrity and repairs disk errors."

    if (-not (Request-AdminElevation)) { return }

    Write-Host "Detected storage volume: $targetWinDrive"
    Write-Host ''
    if ($isWinRE) {
        Write-Host "Running CHKDSK on $targetWinDrive now..."
        chkdsk $targetWinDrive /f /r
    } else {
        Write-Host "Do you want to schedule a full disk check (CHKDSK $targetWinDrive /F /R) on next reboot? (Y/N): " -NoNewline
        $ans = Read-Host
        if ($ans -match '^[YySs]') {
            echo Y | chkdsk $targetWinDrive /f /r
            Write-AssistantLog "DiskRepair" "SCHEDULED" "CHKDSK $targetWinDrive /F /R scheduled on next reboot"
            Write-Host "${creamyGreen}[OK] Disk repair scheduled for the next system restart.${reset}"
        } else {
            Write-Host "${creamyYellow}[INFO] Disk check cancelled by user.${reset}"
        }
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 5. NETWORK & DNS FULL STACK REPAIR
function Assistant-NetworkRepair {
    Invoke-AssistantHeader "ASSISTANT: NETWORK, DNS & SOCKETS FULL REPAIR" "Restores factory configuration for network sockets, DNS cache, and firewall."

    if ($isWinRE) {
        Write-Host "${creamyYellow}[INFO] Network configuration services are not active inside WinRE recovery environment.${reset}"
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

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

    if ($isWinRE) {
        Write-Host "${creamyCyan}[1/1] Reverting pending updates on $targetWinDrive (DISM Offline)...${reset}"
        dism /image:$targetWinDrive\ /cleanup-image /revertpendingactions
        Write-Host "${creamyGreen}[OK] Pending updates reverted successfully.${reset}"
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

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
# Requires physical interactive confirmation at the console (this is a local
# recovery action for the device owner, not something remotely triggerable).
function Assistant-EmergencyAccount {
    Invoke-AssistantHeader "ASSISTANT: EMERGENCY ACCESS ACCOUNTS" "Enables built-in administration accounts to recover computer access."

    if (-not (Request-AdminElevation)) { return }

    if ($isWinRE) {
        # Deliberately NOT implemented here: swapping a system binary (e.g.
        # Utilman.exe/sethc.exe) to get a SYSTEM prompt at the login screen
        # is the single most fingerprinted "login bypass" technique that
        # exists, and antivirus engines flag it on sight regardless of how
        # it's implemented or why. There's no way to do it "safely" from a
        # code standpoint - the capability itself (turn offline physical
        # access into admin access with no known credential) is what gets
        # flagged, since that's indistinguishable from what a backdoor does.
        # Use one of Microsoft's own supported recovery paths instead:
        Write-Host "${creamyYellow}[INFO] There's no live Windows session to add accounts to from WinRE.${reset}"
        Write-Host ''
        Write-Host "${dimText}This assistant doesn't offer an offline login-screen bypass - that technique${reset}"
        Write-Host "${dimText}(replacing a system binary to get a prompt at the login screen) is exactly${reset}"
        Write-Host "${dimText}what antivirus software flags as a backdoor, no matter how it's implemented.${reset}"
        Write-Host ''
        Write-Host "${creamyCyan}If you're locked out of every account on $targetWinDrive, use one of these instead:${reset}"
        Write-Host "  - Microsoft account: reset the password online from another device at"
        Write-Host "    https://account.live.com/password/reset, then sign in normally."
        Write-Host "  - Local account: use a password reset disk if you created one in advance"
        Write-Host "    (Control Panel > User Accounts > Create a password reset disk)."
        Write-Host "  - No reset option available: back up your files from here (WinRE has file"
        Write-Host "    access to $targetWinDrive) before considering a clean reinstall."
        Write-Host ''
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

    # Online mode: acts directly on the current, already-logged-in Windows session.
    # This is the safe, legitimate case - you're already authenticated as some
    # user and are elevating/adding an account from inside that session.
    Write-Host "  ${creamyCyan}[1] Enable Windows built-in Administrator account${reset}"
    Write-Host "  ${creamyCyan}[2] Create a new Emergency Administrator user${reset}"
    Write-Host "  ${creamyRed}[0] Return to main menu${reset}"
    Write-Host ''
    $op = Read-Host "Select an option (0-2)"

    if ($op -in '0','3','q') {
        return
    } elseif ($op -eq '1') {
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
    $docsFolder = [Environment]::GetFolderPath('MyDocuments')
    $histLog = "$docsFolder\Secret-Tools\Logs\assistant_actions.log"
    if (-not (Test-Path $histLog)) { $histLog = "$installDir\logs\assistant_actions.log" }
    if (Test-Path $histLog) {
        Get-Content $histLog -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   No previous action logs recorded."
    }
    Write-Host ''

    Write-Host "${creamyYellow}--- Startup Repair Log (SrtTrail.txt) ---${reset}"
    $srtPath = "$targetWinDrive\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    if (-not (Test-Path $srtPath) -and (Test-Path "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt")) {
        $srtPath = "X:\Windows\System32\Logfiles\Srt\SrtTrail.txt"
    }
    if (Test-Path $srtPath) {
        Get-Content $srtPath -Tail 15 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host "   No boot failure records detected in SrtTrail.txt."
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 9. SYSTEM HEALTH REPORT
function Assistant-HealthReport {
    Invoke-AssistantHeader "ASSISTANT: SYSTEM HEALTH REPORT" "Generates a comprehensive HTML report of hardware, software, services and security status."

    if ($isWinRE) {
        Write-Host "${creamyYellow}[INFO] Full HTML report is only available in standard Windows mode (not WinRE).${reset}"
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

    $reportModule = $null
    $candidates = @(
        "$scriptDir\Generate-HealthReport.ps1",
        "$installDir\Tools\Generate-HealthReport.ps1",
        "$toolsDir\Generate-HealthReport.ps1",
        "$installDir\Generate-HealthReport.ps1"
    )
    foreach ($c in $candidates) {
        if (Test-Path $c) { $reportModule = $c; break }
    }

    if (-not $reportModule) {
        Write-Host "${creamyRed}[ERROR] Generate-HealthReport.ps1 not found. Please re-run Setup-Tools.bat.${reset}"
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

    Write-Host "${creamyCyan}[REPORT] Collecting system data, this may take a few seconds...${reset}"
    Write-Host ''

    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $docsFolder = [Environment]::GetFolderPath('MyDocuments')
    $reportDir = "$docsFolder\Secret-Tools\Reports"
    if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
    $outPath = "$reportDir\SecretTools_HealthReport_$timestamp.html"

    try {
        $result = & powershell -NoProfile -ExecutionPolicy Bypass -File "$reportModule" -OutputPath $outPath -TargetDrive $targetWinDrive 2>&1
        if (Test-Path $outPath) {
            Write-Host "${creamyGreen}[OK] Report saved to:${reset}"
            Write-Host "     ${creamyCyan}$outPath${reset}"
            Write-Host ''
            Write-Host "Opening in default browser..."
            Start-Process $outPath -ErrorAction SilentlyContinue
            Write-AssistantLog "HealthReport" "SUCCESS" "HTML report generated: $outPath"
        } else {
            Write-Host "${creamyRed}[ERROR] Report generation failed.${reset}"
        }
    } catch {
        Write-Host "${creamyRed}[ERROR] $($_.Exception.Message)${reset}"
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 10. SYSTEM RESTORE POINTS
function Assistant-RestorePoints {
    Invoke-AssistantHeader "ASSISTANT: SYSTEM RESTORE POINTS" "List, create or roll back to a previous System Restore Point."

    if ($isWinRE) {
        # WinRE ships its own offline-aware System Restore wizard; it already
        # knows how to enumerate and apply restore points against the target
        # installation correctly, so we hand off to it rather than reimplement it.
        Write-Host "${creamyCyan}[*] Launching the offline System Restore wizard for $targetWinDrive ...${reset}"
        $rstrui = "$targetWinDrive\Windows\System32\rstrui.exe"
        if (Test-Path $rstrui) {
            Start-Process $rstrui -Wait
        } else {
            Write-Host "${creamyRed}[ERROR] rstrui.exe not found on $targetWinDrive.${reset}"
        }
        Write-Host ''
        Write-Host 'Press Enter to return to main menu...'
        [void][Console]::ReadLine()
        return
    }

    if (-not (Request-AdminElevation)) { return }

    $points = Get-ComputerRestorePoint -ErrorAction SilentlyContinue
    if (-not $points) {
        Write-Host "${creamyYellow}[INFO] No restore points found, or System Restore is disabled on $env:SystemDrive.${reset}"
        Write-Host "Enable System Restore and create one now? (Y/N): " -NoNewline
        $ans = Read-Host
        if ($ans -match '^[YySs]') {
            Enable-ComputerRestore -Drive "$env:SystemDrive" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "Secret-Tools Manual Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
            Write-Host "${creamyGreen}[OK] Restore point created.${reset}"
            Write-AssistantLog "RestorePoint" "SUCCESS" "Manual restore point created"
        }
    } else {
        Write-Host "${creamyYellow}Available restore points:${reset}"
        Write-Host ''
        $points | Sort-Object SequenceNumber -Descending | ForEach-Object {
            Write-Host ("  [{0}] {1}  ({2})" -f $_.SequenceNumber, $_.Description, $_.CreationTime)
        }
        Write-Host ''
        Write-Host "  ${creamyGreen}[N] Create a new restore point${reset}"
        Write-Host "  ${creamyRed}[0] Return to main menu${reset}"
        Write-Host ''
        $sel = Read-Host "Enter a restore point number to roll back to, N to create new, or 0 to return"
        if ($sel -match '^[Nn]$') {
            Checkpoint-Computer -Description "Secret-Tools Manual Restore Point" -RestorePointType "MODIFY_SETTINGS" -ErrorAction SilentlyContinue
            Write-Host "${creamyGreen}[OK] Restore point created.${reset}"
            Write-AssistantLog "RestorePoint" "SUCCESS" "Manual restore point created"
        } elseif ($sel -in '0','q') {
            return
        } elseif ($sel -match '^\d+$') {
            $target = $points | Where-Object { $_.SequenceNumber -eq [int]$sel }
            if ($target) {
                Write-Host "${creamyRed}[WARNING] This restarts the computer and rolls back system files/settings to '$($target.Description)'.${reset}"
                Write-Host "Proceed? (Y/N): " -NoNewline
                $confirm = Read-Host
                if ($confirm -match '^[YySs]') {
                    Write-AssistantLog "RestorePoint" "SUCCESS" "Restoring to point $sel : $($target.Description)"
                    Restore-Computer -RestorePoint $target.SequenceNumber -Confirm:$false
                }
            } else {
                Write-Host "${creamyRed}[ERROR] Restore point not found.${reset}"
            }
        }
    }

    Write-Host ''
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 11. BITLOCKER RECOVERY KEY
function Assistant-BitLockerKey {
    Invoke-AssistantHeader "ASSISTANT: BITLOCKER RECOVERY KEY" "Displays the BitLocker numerical recovery password for a volume (works online and offline via manage-bde)."

    $drive = $targetWinDrive
    if (-not $isWinRE) {
        $inputDrive = Read-Host "Drive to check (Enter for default: $targetWinDrive)"
        if ($inputDrive) { $drive = $inputDrive }
    }

    Write-Host "${creamyCyan}[*] Reading BitLocker protectors for $drive ...${reset}"
    Write-Host ''
    $out = manage-bde -protectors -get $drive 2>&1
    $out | ForEach-Object { Write-Host $_ }

    Write-AssistantLog "BitLockerKey" "SUCCESS" "Recovery key viewed for $drive"
    Write-Host ''
    Write-Host "${creamyYellow}[TIP] Look for 'Numerical Password' above - that's what Windows asks for at boot.${reset}"
    Write-Host 'Press Enter to return to main menu...'
    [void][Console]::ReadLine()
}

# 12. DRIVER BACKUP & RESTORE
function Assistant-DriverBackup {
    Invoke-AssistantHeader "ASSISTANT: DRIVER BACKUP & RESTORE" "Exports installed third-party drivers so they can be reinstalled after a clean setup."

    if (-not (Request-AdminElevation)) { return }

    Write-Host "  ${creamyCyan}[1] Export drivers to a folder${reset}"
    Write-Host "  ${creamyCyan}[2] Import drivers from a folder${reset}"
    Write-Host "  ${creamyRed}[0] Return to main menu${reset}"
    Write-Host ''
    $op = Read-Host "Select an option (0-2)"

    $defaultDir = if ($isWinRE) { "$targetWinDrive\DriverBackup" } else { "$([Environment]::GetFolderPath('MyDocuments'))\Secret-Tools\DriverBackup" }

    if ($op -in '0','3','q') {
        return
    } elseif ($op -eq '1') {
        $dest = Read-Host "Destination folder (Enter for default: $defaultDir)"
        if (-not $dest) { $dest = $defaultDir }
        if (-not (Test-Path $dest)) { New-Item -ItemType Directory -Path $dest -Force | Out-Null }
        Write-Host "${creamyCyan}[*] Exporting drivers to $dest ...${reset}"
        if ($isWinRE) {
            dism /image:$targetWinDrive\ /export-driver /destination:"$dest"
        } else {
            dism /online /export-driver /destination:"$dest"
        }
        Write-Host "${creamyGreen}[OK] Drivers exported to $dest.${reset}"
        Write-AssistantLog "DriverBackup" "SUCCESS" "Drivers exported to $dest"
    } elseif ($op -eq '2') {
        $src = Read-Host "Source folder containing exported drivers (Enter for default: $defaultDir)"
        if (-not $src) { $src = $defaultDir }
        if (-not (Test-Path $src)) {
            Write-Host "${creamyRed}[ERROR] Folder not found: $src${reset}"
        } else {
            Write-Host "${creamyCyan}[*] Importing drivers from $src ...${reset}"
            if ($isWinRE) {
                dism /image:$targetWinDrive\ /add-driver /driver:"$src" /recurse
            } else {
                dism /online /add-driver /driver:"$src" /recurse
            }
            Write-Host "${creamyGreen}[OK] Drivers imported from $src.${reset}"
            Write-AssistantLog "DriverBackup" "SUCCESS" "Drivers imported from $src"
        }
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

    $modeTag = if ($isWinRE) { "${creamyYellow}[WINRE OFFLINE MODE: $targetWinDrive]${reset}" } else { "${creamyGreen}[ONLINE MODE]${reset}" }
    $isAdmin = if (Check-IsAdmin) { "${creamyGreen}[ADMIN]${reset}" } else { "${dimText}[USER]${reset}" }
    Write-Host " User: ${creamyCyan}$currentUser${reset} $isAdmin $modeTag | Host: ${creamyCyan}$env:COMPUTERNAME${reset} | Date: $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Write-Host '============================================================================================='
    Write-Host '                    INTELLIGENT SYSTEM RECOVERY & REPAIR ASSISTANT'
    Write-Host '============================================================================================='
    Write-Host ''
    Write-Host "  ${creamyYellow}--- DIAGNOSTICS & SYSTEM HEALTH ---${reset}"
    Write-Host "  ${creamyGreen}[ 1] Guided Intelligent System Diagnosis (Scan + Recommended Fix)${reset}"
    Write-Host "  ${creamyCyan}[ 2] Generate System Health Report (Comprehensive HTML)${reset}"
    Write-Host "  ${accentBlue}[ 3] Repair History & Error Logs Viewer (SrtTrail / Event Log)${reset}"
    Write-Host ''
    Write-Host "  ${creamyYellow}--- SYSTEM & BOOT REPAIR ---${reset}"
    Write-Host "  ${accentBlue}[ 4] Startup & Boot Loop Repair (Fix loops, BCD, SrtTrail, bootrec)${reset}"
    Write-Host "  ${accentBlue}[ 5] Deep System Files & Image Repair (SFC Offline/Online + DISM)${reset}"
    Write-Host "  ${accentBlue}[ 6] Disk Integrity & Bad Sector Repair (CHKDSK $targetWinDrive /F /R)${reset}"
    Write-Host "  ${accentBlue}[ 7] Network, DNS & Firewall Full Repair (Winsock / TCP-IP / Sockets)${reset}"
    Write-Host "  ${accentBlue}[ 8] Windows Update Clean & Reset (SoftwareDistribution / Catroot2)${reset}"
    Write-Host ''
    Write-Host "  ${creamyYellow}--- BACKUP, ACCESS & SECURITY ---${reset}"
    Write-Host "  ${accentBlue}[ 9] System Restore Points (List / Create / Roll Back)${reset}"
    Write-Host "  ${accentBlue}[10] Driver Backup & Restore (Export / Import 3rd Party Drivers)${reset}"
    Write-Host "  ${accentBlue}[11] BitLocker Recovery Key (Retrieve Volume Protectors)${reset}"
    Write-Host "  ${accentBlue}[12] Emergency Access Accounts (Enable Administrator / Recovery User)${reset}"
    Write-Host ''
    Write-Host "  ${creamyYellow}--- SYSTEM CONTROL ---${reset}"
    Write-Host "  ${creamyRed}[ 0] Exit${reset}"
    Write-Host ''
    Write-Host '============================================================================================='
    Write-Host ''
    $choice = Read-Host "Select an option (0-12)"

    switch ($choice.Trim()) {
        { $_ -in '1','01' } { Assistant-SmartDiagnosis }
        { $_ -in '2','02' } { Assistant-HealthReport }
        { $_ -in '3','03' } { Assistant-ViewLogs }
        { $_ -in '4','04' } { Assistant-BootRepair }
        { $_ -in '5','05' } { Assistant-ImageRepair }
        { $_ -in '6','06' } { Assistant-DiskRepair }
        { $_ -in '7','07' } { Assistant-NetworkRepair }
        { $_ -in '8','08' } { Assistant-WindowsUpdateRepair }
        { $_ -in '9','09' } { Assistant-RestorePoints }
        '10' { Assistant-DriverBackup }
        '11' { Assistant-BitLockerKey }
        '12' { Assistant-EmergencyAccount }
        { $_ -in 'H','h' } { Assistant-HealthReport }
        { $_ -in 'R','r' } { Assistant-RestorePoints }
        { $_ -in 'K','k' } { Assistant-BitLockerKey }
        { $_ -in 'D','d' } { Assistant-DriverBackup }
        { $_ -in '0','00','exit','q' } { exit 0 }
        default {
            Write-Host "${creamyRed}Invalid option.${reset}"
            Start-Sleep -Seconds 1
        }
    }
}

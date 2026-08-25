<#
.SYNOPSIS
    Secret-Tools System Health Report Generator
.DESCRIPTION
    Generates a comprehensive, formal HTML health report of the Windows system.
.AUTHOR
    mrsecret_official
#>

[CmdletBinding()]
param(
    [string]$OutputPath = "",
    [string]$TargetDrive = $env:SystemDrive,
    [switch]$IsWinRE = $false
)

$esc = [char]27
$creamyGreen  = "$esc[38;2;145;225;165m"
$creamyRed    = "$esc[38;2;235;120;120m"
$creamyCyan   = "$esc[38;2;130;210;245m"
$creamyYellow = "$esc[38;2;245;220;130m"
$dimText      = "$esc[38;2;160;175;195m"
$reset        = "$esc[0m"

if (-not $OutputPath) {
    $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $desktopPath = [Environment]::GetFolderPath('Desktop')
    $reportDir = "$([Environment]::GetFolderPath('UserProfile'))\Tools\reports"
    if (-not (Test-Path $reportDir)) { New-Item -ItemType Directory -Path $reportDir -Force | Out-Null }
    $OutputPath = "$reportDir\SecretTools_HealthReport_$timestamp.html"
}

Write-Host ""
Write-Host "${creamyCyan}[REPORT] Collecting system data...${reset}"

# ──────────────────────────────────────────────
# DATA COLLECTION
# ──────────────────────────────────────────────

# Basic System Info
$os = Get-WmiObject Win32_OperatingSystem
$cs = Get-WmiObject Win32_ComputerSystem
$bios = Get-WmiObject Win32_BIOS
$cpu = Get-WmiObject Win32_Processor | Select-Object -First 1
$reportDate = Get-Date -Format "dddd, MMMM dd, yyyy - HH:mm:ss"
$hostname = $env:COMPUTERNAME
$currentUser = $env:USERNAME
$uptime = if ($os) { $os.ConvertToDateTime($os.LastBootUpTime) } else { 'N/A' }
$osName = if ($os) { $os.Caption } else { 'N/A' }
$osBuild = if ($os) { $os.BuildNumber } else { 'N/A' }
$osArch = if ($os) { $os.OSArchitecture } else { 'N/A' }
$installDate = if ($os) { $os.ConvertToDateTime($os.InstallDate).ToString("yyyy-MM-dd") } else { 'N/A' }

Write-Host "${dimText}  [1/8] OS info collected...${reset}"

# CPU Info
$cpuName = if ($cpu) { $cpu.Name.Trim() } else { 'N/A' }
$cpuCores = if ($cpu) { "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads" } else { 'N/A' }
$cpuSpeed = if ($cpu) { "$([math]::Round($cpu.MaxClockSpeed/1000, 2)) GHz" } else { 'N/A' }
$cpuLoad = if ($cpu) { "$($cpu.LoadPercentage)%" } else { 'N/A' }

Write-Host "${dimText}  [2/8] CPU info collected...${reset}"

# RAM
$totalRam = if ($cs) { [math]::Round($cs.TotalPhysicalMemory / 1GB, 2) } else { 0 }
$freeRam  = if ($os) { [math]::Round($os.FreePhysicalMemory / 1MB, 2) } else { 0 }
$usedRam  = [math]::Round($totalRam - $freeRam, 2)
$ramPercent = if ($totalRam -gt 0) { [math]::Round(($usedRam / $totalRam) * 100, 1) } else { 0 }

$ramModules = @()
try {
    $ramModules = Get-WmiObject Win32_PhysicalMemory | Select-Object BankLabel,
        @{N='Capacity';E={[math]::Round($_.Capacity/1GB,1)}},
        Speed, Manufacturer, MemoryType
} catch {}

Write-Host "${dimText}  [3/8] RAM info collected...${reset}"

# Disk Info
$disks = @()
try {
    $disks = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
        $free = [math]::Round($_.FreeSpace / 1GB, 2)
        $total = [math]::Round($_.Size / 1GB, 2)
        $used = [math]::Round($total - $free, 2)
        $pct = if ($total -gt 0) { [math]::Round(($used / $total) * 100, 1) } else { 0 }
        $status = if ($pct -gt 90) { 'Critical' } elseif ($pct -gt 75) { 'Warning' } else { 'OK' }
        [PSCustomObject]@{
            Drive = $_.DeviceID
            Total = $total
            Used  = $used
            Free  = $free
            Pct   = $pct
            Status = $status
            FS    = $_.FileSystem
        }
    }
} catch {}

Write-Host "${dimText}  [4/8] Disk info collected...${reset}"

# GPU Info
$gpus = @()
try {
    $gpus = Get-WmiObject Win32_VideoController | Select-Object Name,
        @{N='VRAM';E={[math]::Round($_.AdapterRAM/1MB,0)}},
        DriverVersion, VideoModeDescription
} catch {}

Write-Host "${dimText}  [5/8] GPU info collected...${reset}"

# Network
$netAdapters = @()
try {
    $netAdapters = Get-WmiObject Win32_NetworkAdapterConfiguration -Filter "IPEnabled=True" | ForEach-Object {
        [PSCustomObject]@{
            Name    = $_.Description
            IP      = ($_.IPAddress -join ', ')
            MAC     = $_.MACAddress
            Gateway = ($_.DefaultIPGateway -join ', ')
            DNS     = ($_.DNSServerSearchOrder -join ', ')
            DHCP    = if ($_.DHCPEnabled) { 'Yes' } else { 'No' }
        }
    }
} catch {}

Write-Host "${dimText}  [6/8] Network info collected...${reset}"

# SMART / Disk Health
$diskPhysical = @()
try {
    $diskPhysical = Get-WmiObject Win32_DiskDrive | Select-Object Model, Status,
        @{N='SizeGB';E={[math]::Round($_.Size/1GB,1)}},
        InterfaceType, MediaType
} catch {}

# Services (critical)
$criticalServices = @('wuauserv','WinDefend','BITS','Spooler','EventLog','SamSs','Schedule','Dhcp','Dnscache','W32Time','WlanSvc','wscsvc')
$serviceStatus = @()
foreach ($svc in $criticalServices) {
    try {
        $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
        if ($s) {
            $serviceStatus += [PSCustomObject]@{
                Name = $s.DisplayName
                Status = $s.Status.ToString()
                StartType = $s.StartType.ToString()
            }
        }
    } catch {}
}

Write-Host "${dimText}  [7/8] Services info collected...${reset}"

# SrtTrail
$srtContent = ''
$srtPath = "$TargetDrive\Windows\System32\Logfiles\Srt\SrtTrail.txt"
if (Test-Path $srtPath) {
    $srtContent = (Get-Content $srtPath -Tail 20 -ErrorAction SilentlyContinue) -join "`n"
}

# Windows Defender Status
$defenderStatus = 'N/A'
$defenderDefs = 'N/A'
try {
    $def = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($def) {
        $defenderStatus = if ($def.RealTimeProtectionEnabled) { 'Active' } else { 'Disabled' }
        $defenderDefs = $def.AntivirusSignatureLastUpdated.ToString("yyyy-MM-dd HH:mm")
    }
} catch {}

# Pending Windows Updates count
$pendingUpdates = 'N/A'
try {
    $sess = New-Object -ComObject Microsoft.Update.Session -ErrorAction SilentlyContinue
    if ($sess) {
        $search = $sess.CreateUpdateSearcher()
        $result = $search.Search("IsInstalled=0 and Type='Software'")
        $pendingUpdates = $result.Updates.Count.ToString()
    }
} catch {}

Write-Host "${dimText}  [8/8] Security info collected...${reset}"

# ──────────────────────────────────────────────
# HEALTH SCORES
# ──────────────────────────────────────────────
$diskScore = if ($disks) { if (($disks | Where-Object { $_.Status -eq 'Critical' }).Count -gt 0) { 'Critical' } elseif (($disks | Where-Object { $_.Status -eq 'Warning' }).Count -gt 0) { 'Warning' } else { 'Healthy' } } else { 'Unknown' }
$ramScore = if ($ramPercent -gt 90) { 'Critical' } elseif ($ramPercent -gt 75) { 'Warning' } else { 'Healthy' }
$cpuScore = try { $l = [int]($cpu.LoadPercentage); if ($l -gt 90) { 'Critical' } elseif ($l -gt 70) { 'Warning' } else { 'Healthy' } } catch { 'Unknown' }
$secScore = if ($defenderStatus -eq 'Active') { 'Healthy' } else { 'Warning' }

function Get-StatusBadge([string]$status) {
    switch ($status) {
        'Healthy'  { return '<span class="badge badge-ok">Healthy</span>' }
        'Warning'  { return '<span class="badge badge-warn">Warning</span>' }
        'Critical' { return '<span class="badge badge-crit">Critical</span>' }
        'Active'   { return '<span class="badge badge-ok">Active</span>' }
        'Disabled' { return '<span class="badge badge-crit">Disabled</span>' }
        'Running'  { return '<span class="badge badge-ok">Running</span>' }
        'Stopped'  { return '<span class="badge badge-crit">Stopped</span>' }
        'OK'       { return '<span class="badge badge-ok">OK</span>' }
        default    { return "<span class='badge badge-warn'>$status</span>" }
    }
}

function Get-DiskBar([int]$pct, [string]$status) {
    $col = switch ($status) {
        'Critical' { '#e87878' }
        'Warning'  { '#f5dc82' }
        default    { '#91e1a5' }
    }
    return "<div class='disk-bar-bg'><div class='disk-bar-fill' style='width:${pct}%;background:${col}'></div></div><span class='disk-pct'>${pct}%</span>"
}

# ──────────────────────────────────────────────
# RAM modules rows
$ramRows = ''
foreach ($mod in $ramModules) {
    $ramRows += "<tr><td>$($mod.BankLabel)</td><td>$($mod.Capacity) GB</td><td>$($mod.Speed) MHz</td><td>$($mod.Manufacturer)</td></tr>"
}
if (-not $ramRows) { $ramRows = '<tr><td colspan="4" class="no-data">No RAM module details available</td></tr>' }

# Disk rows
$diskRows = ''
foreach ($d in $disks) {
    $diskRows += "<tr>
        <td><span class='drive-label'>$($d.Drive)</span></td>
        <td>$($d.FS)</td>
        <td>$($d.Total) GB</td>
        <td>$($d.Used) GB</td>
        <td>$($d.Free) GB</td>
        <td>$(Get-DiskBar -pct $d.Pct -status $d.Status)</td>
        <td>$(Get-StatusBadge $d.Status)</td>
    </tr>"
}
if (-not $diskRows) { $diskRows = '<tr><td colspan="7" class="no-data">No disk data available</td></tr>' }

# Physical disk rows
$physRows = ''
foreach ($d in $diskPhysical) {
    $st = if ($d.Status -eq 'OK') { 'OK' } else { 'Warning' }
    $physRows += "<tr><td>$($d.Model)</td><td>$($d.SizeGB) GB</td><td>$($d.InterfaceType)</td><td>$($d.MediaType)</td><td>$(Get-StatusBadge $st)</td></tr>"
}
if (-not $physRows) { $physRows = '<tr><td colspan="5" class="no-data">No physical disk data available</td></tr>' }

# GPU rows
$gpuRows = ''
foreach ($g in $gpus) {
    $gpuRows += "<tr><td>$($g.Name)</td><td>$($g.VRAM) MB</td><td>$($g.DriverVersion)</td><td>$($g.VideoModeDescription)</td></tr>"
}
if (-not $gpuRows) { $gpuRows = '<tr><td colspan="4" class="no-data">No GPU data available</td></tr>' }

# Network rows
$netRows = ''
foreach ($n in $netAdapters) {
    $netRows += "<tr><td>$($n.Name)</td><td>$($n.IP)</td><td>$($n.MAC)</td><td>$($n.Gateway)</td><td>$($n.DNS)</td><td>$($n.DHCP)</td></tr>"
}
if (-not $netRows) { $netRows = '<tr><td colspan="6" class="no-data">No active network adapters found</td></tr>' }

# Service rows
$svcRows = ''
foreach ($s in $serviceStatus) {
    $svcRows += "<tr><td>$($s.Name)</td><td>$(Get-StatusBadge $s.Status)</td><td>$($s.StartType)</td></tr>"
}
if (-not $svcRows) { $svcRows = '<tr><td colspan="3" class="no-data">No service data available</td></tr>' }

# SRT section
$srtSection = if ($srtContent) {
    "<pre class='log-block'>$([System.Web.HttpUtility]::HtmlEncode($srtContent))</pre>"
} else {
    '<p class="no-data-p">No SrtTrail.txt log found on this system. Boot process is clean.</p>'
}

# Overall health
$allScores = @($diskScore, $ramScore, $cpuScore, $secScore)
$overallHealth = if ($allScores -contains 'Critical') { 'Critical' } elseif ($allScores -contains 'Warning') { 'Warning' } else { 'Healthy' }
$overallColor = switch ($overallHealth) {
    'Critical' { '#e87878' }
    'Warning'  { '#f5dc82' }
    default    { '#91e1a5' }
}

# ──────────────────────────────────────────────
# HTML GENERATION
# ──────────────────────────────────────────────
$html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Secret-Tools System Health Report - $hostname</title>
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&family=JetBrains+Mono:wght@400;500&display=swap');

    :root {
        --bg-primary: #0d1117;
        --bg-secondary: #161b22;
        --bg-card: #1c2128;
        --bg-card-hover: #21262d;
        --border: #30363d;
        --border-light: #21262d;
        --text-primary: #e6edf3;
        --text-secondary: #8b949e;
        --text-muted: #6e7681;
        --accent-blue: #4493f8;
        --accent-green: #3fb950;
        --accent-yellow: #d29922;
        --accent-red: #f85149;
        --accent-purple: #bc8cff;
        --ok-bg: rgba(63, 185, 80, 0.12);
        --ok-text: #3fb950;
        --warn-bg: rgba(210, 153, 34, 0.15);
        --warn-text: #d29922;
        --crit-bg: rgba(248, 81, 73, 0.15);
        --crit-text: #f85149;
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
        font-family: 'Inter', sans-serif;
        background-color: var(--bg-primary);
        color: var(--text-primary);
        font-size: 14px;
        line-height: 1.6;
        min-height: 100vh;
    }

    .report-header {
        background: linear-gradient(135deg, #0d1117 0%, #161b22 50%, #1c2128 100%);
        border-bottom: 1px solid var(--border);
        padding: 48px 60px 40px;
        position: relative;
        overflow: hidden;
    }

    .report-header::before {
        content: '';
        position: absolute;
        top: -80px;
        right: -80px;
        width: 300px;
        height: 300px;
        background: radial-gradient(circle, rgba(68, 147, 248, 0.08) 0%, transparent 70%);
        border-radius: 50%;
    }

    .report-header::after {
        content: '';
        position: absolute;
        bottom: -60px;
        left: 200px;
        width: 200px;
        height: 200px;
        background: radial-gradient(circle, rgba(63, 185, 80, 0.06) 0%, transparent 70%);
        border-radius: 50%;
    }

    .header-top {
        display: flex;
        align-items: flex-start;
        justify-content: space-between;
        gap: 30px;
    }

    .header-left {
        display: flex;
        flex-direction: column;
    }

    .report-title {
        font-size: 28px;
        font-weight: 700;
        color: var(--text-primary);
        letter-spacing: -0.5px;
        margin-bottom: 6px;
    }

    .report-subtitle {
        font-size: 14px;
        color: var(--text-secondary);
        margin-bottom: 16px;
    }

    .header-right {
        text-align: right;
        display: flex;
        flex-direction: column;
        align-items: flex-end;
        justify-content: flex-start;
    }

    .brand-name {
        font-size: 20px;
        font-weight: 700;
        color: var(--accent-blue);
        letter-spacing: 0.5px;
        line-height: 1.2;
    }

    .brand-sub {
        font-size: 12px;
        color: var(--text-secondary);
        font-weight: 500;
        margin-top: 2px;
        margin-bottom: 12px;
    }

    .report-date {
        font-size: 12px;
        color: var(--text-primary);
        font-family: 'JetBrains Mono', monospace;
        margin-bottom: 4px;
        text-transform: capitalize;
    }

    .report-host {
        font-size: 12px;
        color: var(--text-muted);
        font-family: 'JetBrains Mono', monospace;
    }

    .overall-health {
        display: inline-flex;
        align-items: center;
        gap: 10px;
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 8px 16px;
        width: fit-content;
    }

    .health-dot {
        width: 10px;
        height: 10px;
        border-radius: 50%;
        background: $overallColor;
        box-shadow: 0 0 8px ${overallColor}88;
    }

    .health-text { font-size: 13px; color: var(--text-secondary); }
    .health-value { font-size: 13px; font-weight: 600; color: $overallColor; }

    .container { max-width: 1200px; margin: 0 auto; padding: 40px 60px; }

    .summary-grid {
        display: grid;
        grid-template-columns: repeat(4, 1fr);
        gap: 16px;
        margin-bottom: 40px;
    }

    .summary-card {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 20px;
        transition: border-color 0.2s;
    }

    .summary-card:hover { border-color: var(--accent-blue); }
    .summary-card-label { font-size: 11px; text-transform: uppercase; letter-spacing: 1px; color: var(--text-muted); margin-bottom: 8px; font-weight: 500; }
    .summary-card-value { font-size: 22px; font-weight: 700; color: var(--text-primary); margin-bottom: 4px; }
    .summary-card-sub { font-size: 11px; color: var(--text-secondary); }
    .summary-card-status { font-size: 11px; font-weight: 600; margin-top: 6px; }

    .section { margin-bottom: 40px; }

    .section-header {
        display: flex;
        align-items: center;
        gap: 10px;
        margin-bottom: 16px;
        padding-bottom: 12px;
        border-bottom: 1px solid var(--border-light);
    }

    .section-icon {
        width: 32px;
        height: 32px;
        border-radius: 8px;
        display: flex;
        align-items: center;
        justify-content: center;
        flex-shrink: 0;
    }

    .section-icon svg {
        width: 17px;
        height: 17px;
        stroke: currentColor;
        fill: none;
        stroke-width: 2;
        stroke-linecap: round;
        stroke-linejoin: round;
    }

    .section-title { font-size: 16px; font-weight: 600; color: var(--text-primary); }
    .section-desc { font-size: 12px; color: var(--text-muted); }

    table { width: 100%; border-collapse: collapse; }

    .table-wrap {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: 12px;
        overflow: hidden;
    }

    thead tr { background: var(--bg-secondary); }

    th {
        padding: 10px 16px;
        text-align: left;
        font-size: 11px;
        font-weight: 600;
        text-transform: uppercase;
        letter-spacing: 0.8px;
        color: var(--text-muted);
        border-bottom: 1px solid var(--border);
    }

    td {
        padding: 12px 16px;
        font-size: 13px;
        color: var(--text-primary);
        border-bottom: 1px solid var(--border-light);
        vertical-align: middle;
    }

    tbody tr:last-child td { border-bottom: none; }
    tbody tr:hover { background: var(--bg-card-hover); }

    .badge {
        display: inline-block;
        padding: 2px 10px;
        border-radius: 20px;
        font-size: 11px;
        font-weight: 600;
        letter-spacing: 0.3px;
    }

    .badge-ok   { background: var(--ok-bg);   color: var(--ok-text);   }
    .badge-warn { background: var(--warn-bg);  color: var(--warn-text); }
    .badge-crit { background: var(--crit-bg);  color: var(--crit-text); }

    .drive-label {
        font-family: 'JetBrains Mono', monospace;
        font-size: 12px;
        font-weight: 600;
        color: var(--accent-blue);
    }

    .disk-bar-bg {
        display: inline-block;
        width: 110px;
        height: 6px;
        background: var(--bg-secondary);
        border-radius: 4px;
        overflow: hidden;
        vertical-align: middle;
        margin-right: 8px;
    }

    .disk-bar-fill { height: 100%; border-radius: 4px; transition: width 0.3s; }
    .disk-pct { font-size: 12px; color: var(--text-secondary); font-family: 'JetBrains Mono', monospace; vertical-align: middle; }

    .info-grid {
        display: grid;
        grid-template-columns: 1fr 1fr;
        gap: 16px;
    }

    .info-card {
        background: var(--bg-card);
        border: 1px solid var(--border);
        border-radius: 12px;
        padding: 20px 24px;
    }

    .info-row { display: flex; justify-content: space-between; align-items: center; padding: 7px 0; border-bottom: 1px solid var(--border-light); }
    .info-row:last-child { border-bottom: none; }
    .info-label { font-size: 12px; color: var(--text-muted); }
    .info-value { font-size: 12px; color: var(--text-primary); font-weight: 500; text-align: right; max-width: 60%; word-break: break-word; }

    .ram-bar-wrap { margin-top: 4px; }

    .ram-bar-bg {
        width: 100%;
        height: 8px;
        background: var(--bg-secondary);
        border-radius: 6px;
        overflow: hidden;
        margin-bottom: 6px;
    }

    .ram-bar-fill {
        height: 100%;
        border-radius: 6px;
        background: linear-gradient(90deg, var(--accent-blue), #6cb4f8);
    }

    .log-block {
        background: var(--bg-secondary);
        border: 1px solid var(--border);
        border-radius: 10px;
        padding: 16px 20px;
        font-family: 'JetBrains Mono', monospace;
        font-size: 12px;
        color: var(--text-secondary);
        white-space: pre-wrap;
        word-break: break-word;
        line-height: 1.7;
        max-height: 300px;
        overflow-y: auto;
    }

    .no-data { font-size: 12px; color: var(--text-muted); font-style: italic; text-align: center; }
    .no-data-p { font-size: 12px; color: var(--text-muted); font-style: italic; padding: 16px 0; }

    .section-icon-os    { background: rgba(68,147,248,0.12); color: var(--accent-blue); }
    .section-icon-cpu   { background: rgba(188,140,255,0.12); color: var(--accent-purple); }
    .section-icon-ram   { background: rgba(63,185,80,0.12);  color: var(--accent-green); }
    .section-icon-disk  { background: rgba(210,153,34,0.12); color: var(--accent-yellow); }
    .section-icon-gpu   { background: rgba(248,81,73,0.12);  color: var(--accent-red); }
    .section-icon-net   { background: rgba(68,147,248,0.12); color: var(--accent-blue); }
    .section-icon-svc   { background: rgba(63,185,80,0.12);  color: var(--accent-green); }
    .section-icon-sec   { background: rgba(210,153,34,0.12); color: var(--accent-yellow); }
    .section-icon-log   { background: rgba(160,175,195,0.12); color: #a0afbf; }

    .footer {
        margin-top: 60px;
        padding: 24px 60px;
        border-top: 1px solid var(--border);
        display: flex;
        justify-content: space-between;
        align-items: center;
    }

    .footer-brand { font-size: 12px; color: var(--text-muted); }
    .footer-brand span { color: var(--accent-blue); font-weight: 600; }
    .footer-date { font-size: 11px; color: var(--text-muted); font-family: 'JetBrains Mono', monospace; }

    @media print {
        body { background: #fff; color: #000; }
    }
</style>
</head>
<body>

<header class="report-header">
    <div class="header-top">
        <div class="header-left">
            <div class="report-title">System Health Report</div>
            <div class="report-subtitle">Comprehensive diagnostics and status analysis for $osName</div>
            <div class="overall-health">
                <div class="health-dot"></div>
                <span class="health-text">Overall System Status:</span>
                <span class="health-value">$overallHealth</span>
            </div>
        </div>
        <div class="header-right">
            <div class="brand-name">Secret-Tools</div>
            <div class="brand-sub">Windows Management Suite</div>
            <div class="report-date">$reportDate</div>
            <div class="report-host">Host: $hostname &bull; User: $currentUser</div>
        </div>
    </div>
</header>

<div class="container">

    <!-- SUMMARY CARDS -->
    <div class="summary-grid">
        <div class="summary-card">
            <div class="summary-card-label">Processor</div>
            <div class="summary-card-value" style="font-size:14px;line-height:1.4">$cpuName</div>
            <div class="summary-card-sub">$cpuCores &bull; $cpuSpeed</div>
            <div class="summary-card-status" style="color:$(switch($cpuScore){'Healthy'{'#3fb950'}'Warning'{'#d29922'}default{'#f85149'}})">$cpuScore</div>
        </div>
        <div class="summary-card">
            <div class="summary-card-label">Memory (RAM)</div>
            <div class="summary-card-value">${usedRam} GB <span style="font-size:14px;font-weight:400;color:var(--text-muted)">/ ${totalRam} GB</span></div>
            <div class="summary-card-sub">$ramPercent% in use</div>
            <div class="summary-card-status" style="color:$(switch($ramScore){'Healthy'{'#3fb950'}'Warning'{'#d29922'}default{'#f85149'}})">$ramScore</div>
        </div>
        <div class="summary-card">
            <div class="summary-card-label">Storage</div>
            <div class="summary-card-value">$($disks.Count) <span style="font-size:14px;font-weight:400;color:var(--text-muted)">Volume(s)</span></div>
            <div class="summary-card-sub">$($diskPhysical.Count) Physical Drive(s) detected</div>
            <div class="summary-card-status" style="color:$(switch($diskScore){'Healthy'{'#3fb950'}'Warning'{'#d29922'}default{'#f85149'}})">$diskScore</div>
        </div>
        <div class="summary-card">
            <div class="summary-card-label">Security</div>
            <div class="summary-card-value" style="font-size:16px">Windows Defender</div>
            <div class="summary-card-sub">Defs: $defenderDefs</div>
            <div class="summary-card-status" style="color:$(if($defenderStatus -eq 'Active'){'#3fb950'}else{'#f85149'})">$defenderStatus</div>
        </div>
    </div>

    <!-- OS -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-os">
                <svg viewBox="0 0 24 24"><rect x="2" y="3" width="20" height="14" rx="2"/><line x1="8" y1="21" x2="16" y2="21"/><line x1="12" y1="17" x2="12" y2="21"/></svg>
            </div>
            <div>
                <div class="section-title">Operating System</div>
                <div class="section-desc">Windows version, build, architecture and installation details</div>
            </div>
        </div>
        <div class="info-grid">
            <div class="info-card">
                <div class="info-row"><span class="info-label">Operating System</span><span class="info-value">$osName</span></div>
                <div class="info-row"><span class="info-label">Build Number</span><span class="info-value">$osBuild</span></div>
                <div class="info-row"><span class="info-label">Architecture</span><span class="info-value">$osArch</span></div>
                <div class="info-row"><span class="info-label">Installation Date</span><span class="info-value">$installDate</span></div>
            </div>
            <div class="info-card">
                <div class="info-row"><span class="info-label">Last Boot Time</span><span class="info-value">$uptime</span></div>
                <div class="info-row"><span class="info-label">Computer Name</span><span class="info-value">$hostname</span></div>
                <div class="info-row"><span class="info-label">Manufacturer</span><span class="info-value">$(if($cs){$cs.Manufacturer}else{'N/A'})</span></div>
                <div class="info-row"><span class="info-label">Model</span><span class="info-value">$(if($cs){$cs.Model}else{'N/A'})</span></div>
            </div>
        </div>
    </div>

    <!-- CPU -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-cpu">
                <svg viewBox="0 0 24 24"><rect x="4" y="4" width="16" height="16" rx="2"/><rect x="9" y="9" width="6" height="6"/><path d="M9 1v3M15 1v3M9 20v3M15 20v3M20 9h3M20 14h3M1 9h3M1 14h3"/></svg>
            </div>
            <div>
                <div class="section-title">Processor</div>
                <div class="section-desc">CPU model, frequency, core count and current load</div>
            </div>
        </div>
        <div class="info-card">
            <div class="info-row"><span class="info-label">Model</span><span class="info-value">$cpuName</span></div>
            <div class="info-row"><span class="info-label">Cores / Threads</span><span class="info-value">$cpuCores</span></div>
            <div class="info-row"><span class="info-label">Max Frequency</span><span class="info-value">$cpuSpeed</span></div>
            <div class="info-row"><span class="info-label">Current Load</span><span class="info-value">$cpuLoad</span></div>
            <div class="info-row"><span class="info-label">Socket</span><span class="info-value">$(if($cpu){$cpu.SocketDesignation}else{'N/A'})</span></div>
        </div>
    </div>

    <!-- RAM -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-ram">
                <svg viewBox="0 0 24 24"><path d="M2 7a2 2 0 0 1 2-2h16a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H4a2 2 0 0 1-2-2V7z"/><line x1="6" y1="9" x2="6" y2="13"/><line x1="10" y1="9" x2="10" y2="13"/><line x1="14" y1="9" x2="14" y2="13"/><line x1="18" y1="9" x2="18" y2="13"/><line x1="6" y1="19" x2="6" y2="21"/><line x1="10" y1="19" x2="10" y2="21"/><line x1="14" y1="19" x2="14" y2="21"/><line x1="18" y1="19" x2="18" y2="21"/></svg>
            </div>
            <div>
                <div class="section-title">Memory (RAM)</div>
                <div class="section-desc">Physical memory usage and installed modules</div>
            </div>
        </div>
        <div class="info-card" style="margin-bottom:16px">
            <div class="info-row"><span class="info-label">Total RAM</span><span class="info-value">${totalRam} GB</span></div>
            <div class="info-row"><span class="info-label">Used</span><span class="info-value">${usedRam} GB ($ramPercent%)</span></div>
            <div class="info-row"><span class="info-label">Free</span><span class="info-value">${freeRam} GB</span></div>
            <div class="info-row" style="display:block;padding:10px 0">
                <div class="ram-bar-wrap">
                    <div class="ram-bar-bg"><div class="ram-bar-fill" style="width:${ramPercent}%"></div></div>
                </div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Slot</th><th>Capacity</th><th>Speed</th><th>Manufacturer</th></tr></thead>
                <tbody>$ramRows</tbody>
            </table>
        </div>
    </div>

    <!-- DISK LOGICAL -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-disk">
                <svg viewBox="0 0 24 24"><rect x="3" y="4" width="18" height="16" rx="2"/><line x1="3" y1="12" x2="21" y2="12"/><line x1="7" y1="8" x2="7.01" y2="8"/><line x1="7" y1="16" x2="7.01" y2="16"/></svg>
            </div>
            <div>
                <div class="section-title">Storage - Logical Volumes</div>
                <div class="section-desc">Disk usage per drive letter and filesystem type</div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Drive</th><th>FS</th><th>Total</th><th>Used</th><th>Free</th><th>Usage</th><th>Status</th></tr></thead>
                <tbody>$diskRows</tbody>
            </table>
        </div>
    </div>

    <!-- DISK PHYSICAL -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-disk">
                <svg viewBox="0 0 24 24"><line x1="22" y1="12" x2="2" y2="12"/><path d="M5.45 5.11L2 12v6a2 2 0 0 0 2 2h16a2 2 0 0 0 2-2v-6l-3.45-6.89A2 2 0 0 0 16.76 4H7.24a2 2 0 0 0-1.79 1.11z"/><line x1="6" y1="16" x2="6.01" y2="16"/><line x1="10" y1="16" x2="10.01" y2="16"/></svg>
            </div>
            <div>
                <div class="section-title">Storage - Physical Drives</div>
                <div class="section-desc">Hardware disk drives detected, interface type and reported health status</div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Model</th><th>Size</th><th>Interface</th><th>Media Type</th><th>Status</th></tr></thead>
                <tbody>$physRows</tbody>
            </table>
        </div>
    </div>

    <!-- GPU -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-gpu">
                <svg viewBox="0 0 24 24"><rect x="2" y="5" width="20" height="14" rx="2"/><path d="M6 9h4v6H6z"/><circle cx="16" cy="12" r="3"/><line x1="6" y1="19" x2="6" y2="22"/><line x1="10" y1="19" x2="10" y2="22"/><line x1="14" y1="19" x2="14" y2="22"/></svg>
            </div>
            <div>
                <div class="section-title">Graphics (GPU)</div>
                <div class="section-desc">Video adapters, VRAM and driver versions</div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Adapter</th><th>VRAM</th><th>Driver Version</th><th>Resolution</th></tr></thead>
                <tbody>$gpuRows</tbody>
            </table>
        </div>
    </div>

    <!-- NETWORK -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-net">
                <svg viewBox="0 0 24 24"><rect x="2" y="2" width="6" height="6" rx="1"/><rect x="16" y="2" width="6" height="6" rx="1"/><rect x="9" y="16" width="6" height="6" rx="1"/><path d="M5 8v3a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V8"/><line x1="12" y1="13" x2="12" y2="16"/></svg>
            </div>
            <div>
                <div class="section-title">Network Adapters</div>
                <div class="section-desc">Active network interfaces, IP addresses and DNS configuration</div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Adapter</th><th>IP Address</th><th>MAC</th><th>Gateway</th><th>DNS</th><th>DHCP</th></tr></thead>
                <tbody>$netRows</tbody>
            </table>
        </div>
    </div>

    <!-- SERVICES -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-svc">
                <svg viewBox="0 0 24 24"><path d="M12 2v4M12 18v4M4.93 4.93l2.83 2.83M16.24 16.24l2.83 2.83M2 12h4M18 12h4M4.93 19.07l2.83-2.83M16.24 7.76l2.83-2.83"/><circle cx="12" cy="12" r="4"/></svg>
            </div>
            <div>
                <div class="section-title">Critical Windows Services</div>
                <div class="section-desc">Status of essential system services required for stable operation</div>
            </div>
        </div>
        <div class="table-wrap">
            <table>
                <thead><tr><th>Service</th><th>Status</th><th>Start Type</th></tr></thead>
                <tbody>$svcRows</tbody>
            </table>
        </div>
    </div>

    <!-- SECURITY -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-sec">
                <svg viewBox="0 0 24 24"><path d="M12 22s8-4 8-10V5l-8-3-8 3v7c0 6 8 10 8 10z"/><path d="M9 12l2 2 4-4"/></svg>
            </div>
            <div>
                <div class="section-title">Security Status</div>
                <div class="section-desc">Windows Defender, antivirus definitions and pending updates</div>
            </div>
        </div>
        <div class="info-card">
            <div class="info-row">
                <span class="info-label">Windows Defender</span>
                <span class="info-value">$(Get-StatusBadge $defenderStatus)</span>
            </div>
            <div class="info-row"><span class="info-label">Last Definition Update</span><span class="info-value">$defenderDefs</span></div>
            <div class="info-row"><span class="info-label">Pending Windows Updates</span><span class="info-value">$pendingUpdates</span></div>
            <div class="info-row"><span class="info-label">BIOS Version</span><span class="info-value">$(if($bios){"$($bios.Manufacturer) $($bios.SMBIOSBIOSVersion)"}else{'N/A'})</span></div>
            <div class="info-row"><span class="info-label">BIOS Release Date</span><span class="info-value">$(if($bios){$bios.ConvertToDateTime($bios.ReleaseDate).ToString('yyyy-MM-dd')}else{'N/A'})</span></div>
        </div>
    </div>

    <!-- SRTTRAIL -->
    <div class="section">
        <div class="section-header">
            <div class="section-icon section-icon-log">
                <svg viewBox="0 0 24 24"><path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"/><polyline points="14 2 14 8 20 8"/><line x1="16" y1="13" x2="8" y2="13"/><line x1="16" y1="17" x2="8" y2="17"/><line x1="10" y1="9" x2="8" y2="9"/></svg>
            </div>
            <div>
                <div class="section-title">Startup Repair Log (SrtTrail.txt)</div>
                <div class="section-desc">Last 20 lines from the Windows startup diagnosis log</div>
            </div>
        </div>
        $srtSection
    </div>

</div>

<footer class="footer">
    <div class="footer-brand">Generated by <span>Secret-Tools</span> &bull; mrsecret_official &bull; All data collected locally</div>
    <div class="footer-date">$reportDate</div>
</footer>

</body>
</html>
"@

# ──────────────────────────────────────────────
# OUTPUT
# ──────────────────────────────────────────────
try {
    [System.IO.File]::WriteAllText($OutputPath, $html, [System.Text.Encoding]::UTF8)
    Write-Host ""
    Write-Host "${creamyGreen}[OK] Health report generated successfully.${reset}"
    Write-Host "     Path: ${creamyCyan}$OutputPath${reset}"
    Write-Host ""
    # Open in browser
    try { Start-Process $OutputPath -ErrorAction SilentlyContinue } catch {}
    return $OutputPath
} catch {
    Write-Host "${creamyRed}[ERROR] Failed to write report: $($_.Exception.Message)${reset}"
    return $null
}

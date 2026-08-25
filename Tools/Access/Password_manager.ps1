# password_manager.ps1
# Multi-user password management - Secure Remote Authentication

param(
    [string]$Username = "",
    [string]$InputPassword = "",
    [string]$Action = "verify"
)

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$Config = @{
    "Secret-user" = @{
        ApiUrl    = "https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/Sec-User-Pass.txt"
        CacheFile = "$PSScriptRoot\..\cache\secret_user.cache"
    }
    "MrSecret"    = @{
        ApiUrl    = "https://api.github.com/repos/MrSecret-Official/Secret-Credentials/contents/Secret-Tools-Win/Passwords/MrSecret-Access.txt"
        CacheFile = "$PSScriptRoot\..\cache\mrsecret.cache"
    }
}

function Get-SecureAuthToken {
    # Obfuscated in-memory token reconstruction
    $cipher = "NAwXGhAWCx8OGCxiVCJCMCMyIQJVGGVZfnEpLjMCCjIbMF0WJmIwGwMRBxYBPD8hR3x4dwsdDjFSDGwMFQIYHzImLUcFFxMiCx9GWkt4AzZRRSQtBiQZKjtrXBQE"
    $key = [System.Text.Encoding]::UTF8.GetBytes("SecretToolsSecurityKey2026")
    $bytes = [Convert]::FromBase64String($cipher)
    $dec = for ($i = 0; $i -lt $bytes.Length; $i++) { $bytes[$i] -bxor $key[$i % $key.Length] }
    return [System.Text.Encoding]::UTF8.GetString([byte[]]$dec)
}

function Write-Log {
    param([string]$Message)
    $logDir = "$PSScriptRoot\..\logs"
    if (-not (Test-Path $logDir)) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
    }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "$timestamp - $Message" | Out-File -FilePath "$logDir\activity.log" -Append -Encoding UTF8
}

function Get-RemotePassword {
    param([string]$ApiUrl)
    
    try {
        $token = Get-SecureAuthToken
        $headers = @{
            "Authorization" = "Bearer $token"
            "Accept"        = "application/vnd.github.v3.raw"
            "User-Agent"    = "SecretTools-Client"
        }
        
        $response = Invoke-RestMethod -Uri $ApiUrl -Headers $headers -Method Get -TimeoutSec 10
        if ($response) {
            return ($response.ToString()).Trim()
        }
        return $null
    }
    catch {
        Write-Log "Failed to fetch password from remote API: $($_.Exception.Message)"
        return $null
    }
}

function Get-CachedPassword {
    param([string]$CacheFile)
    
    if (Test-Path $CacheFile) {
        return (Get-Content $CacheFile -Raw -ErrorAction SilentlyContinue).Trim()
    }
    return $null
}

function Save-CachedPassword {
    param(
        [string]$Password,
        [string]$CacheFile
    )
    
    $cacheDir = Split-Path $CacheFile -Parent
    if (-not (Test-Path $cacheDir)) {
        New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
    }
    
    $Password | Out-File -FilePath $CacheFile -Force -Encoding UTF8
    Write-Log "Password cached for user"
}

function Verify-User {
    param(
        [string]$Username,
        [string]$PasswordToTest
    )
    
    if (-not $Config.ContainsKey($Username)) {
        Write-Log "Unknown username attempted: $Username"
        return $false
    }
    
    $userConfig = $Config[$Username]
    
    # Try remote fetch first
    $remotePassword = Get-RemotePassword -ApiUrl $userConfig.ApiUrl
    
    if ($remotePassword) {
        Save-CachedPassword -Password $remotePassword -CacheFile $userConfig.CacheFile
        Write-Log "Password updated from remote for $Username"
        $expectedPassword = $remotePassword
    }
    else {
        # Use cache if offline
        $cachedPassword = Get-CachedPassword -CacheFile $userConfig.CacheFile
        if ($cachedPassword) {
            Write-Log "Using cached password for $Username (offline mode)"
            $expectedPassword = $cachedPassword
        }
        else {
            Write-Log "No credentials available for $Username"
            return $false
        }
    }
    
    return ($PasswordToTest -eq $expectedPassword)
}

# Main execution
if ($Username) {
    if (-not $InputPassword) {
        $sec = Read-Host "Enter password" -AsSecureString
        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
        $InputPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
    
    if (Verify-User -Username $Username -PasswordToTest $InputPassword) {
        Write-Log "Successful login: $Username"
        Write-Output "AUTH_SUCCESS"
        exit 0
    }
    else {
        Write-Log "Failed login: $Username"
        Write-Output "AUTH_FAIL"
        exit 1
    }
}
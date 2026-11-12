#requires -Version 5.1
<#
.SYNOPSIS
  Hunt a Legion budget exit in Glen Burnie, Maryland 21061.

.DESCRIPTION
  Uses the saved login at %LOCALAPPDATA%\proxycheck-credential.xml.
  Username shape the gateway accepts:
    {account}_country-US_state-maryland_session-{id}_sesstime-1440
  Stops when ipinfo reports Glen Burnie, Maryland, and ZIP 21061.
  Copies a Linken Sphere line: host:port:username:password
  That is budget.legionproxy.io:1337:USER:PASS
  It does not build host:port@user:pass.

.EXAMPLE
  powershell -ExecutionPolicy Bypass -File .\hunt-glen-burnie-md.ps1
#>
[CmdletBinding()]
param(
    [string]$Zip = '21061',
    [int]$Attempts = 100
)

$ErrorActionPreference = 'Stop'
if (Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue) {
    $PSNativeCommandUseErrorActionPreference = $false
}

if ($Zip -notmatch '^[0-9]{5}$') {
    throw 'ZIP must be five digits.'
}
if ($Attempts -lt 1) {
    throw '-Attempts must be at least 1.'
}

$loginFile = Join-Path $env:LOCALAPPDATA 'proxycheck-credential.xml'
if (-not (Test-Path -LiteralPath $loginFile -PathType Leaf)) {
    throw 'Saved LegionProxy login was not found for this Windows account.'
}

$credential = Import-Clixml -LiteralPath $loginFile -ErrorAction Stop
$account = $credential.UserName
$password = $credential.GetNetworkCredential().Password
if (-not $account -or -not $password) {
    throw 'The saved LegionProxy login has no username or password.'
}

try {
    $location = Invoke-RestMethod -Uri "https://api.zippopotam.us/us/$Zip" -TimeoutSec 10 -ErrorAction Stop
}
catch {
    throw "Could not look up ZIP $Zip. $($_.Exception.Message)"
}

$place = $location.places | Select-Object -First 1
if (-not $place.state -or -not $place.latitude -or -not $place.longitude) {
    throw "The ZIP lookup did not return a state and coordinates for $Zip."
}

$wantCity = [string]$place.'place name'
$wantRegion = [string]$place.state
$culture = [Globalization.CultureInfo]::InvariantCulture
$radians = [math]::PI / 180
$centerLat = [double]::Parse($place.latitude, $culture) * $radians
$centerLon = [double]::Parse($place.longitude, $culture) * $radians
$stateSlug = $place.state.ToLowerInvariant() -replace '\s+', '-'
$gateway = 'http://budget.legionproxy.io:1337'
$checked = 0
$closestMiles = [double]::PositiveInfinity
$closest = $null

Write-Host "Hunting $wantCity, $wantRegion $Zip"
Write-Host "Username: ${account}_country-US_state-${stateSlug}_session-XXXXXXXXXX_sesstime-1440"
Write-Host "Match rule: ipinfo city, state, and ZIP. Linken Sphere copy is host:port:user:pass."

try {
    for ($i = 1; $i -le $Attempts; $i++) {
        Write-Progress -Activity "Finding a LegionProxy exit in $wantCity $Zip" `
            -Status "Attempt $i of $Attempts" `
            -PercentComplete (($i - 1) * 100 / $Attempts)

        $session = [guid]::NewGuid().ToString('N').Substring(0, 10)
        $username = "${account}_country-US_state-${stateSlug}_session-${session}_sesstime-1440"
        $login = "${username}:${password}".Replace('\', '\\').Replace('"', '\"')
        $config = @"
proxy-user = "$login"
noproxy = ""
"@
        $response = $config | curl.exe -q --config - --silent --fail `
            --connect-timeout 5 --max-time 20 `
            --proxy $gateway 'https://ipinfo.io/json'
        if ($LASTEXITCODE -ne 0 -or -not $response) {
            Write-Host "[$i/$Attempts] no response"
            continue
        }

        try {
            $info = ($response -join "`n") | ConvertFrom-Json -ErrorAction Stop
            if (-not $info.ip -or -not $info.loc) { continue }
            $coords = $info.loc -split ',', 2
            if ($coords.Count -ne 2) { continue }
            $exitLat = [double]::Parse($coords[0], $culture) * $radians
            $exitLon = [double]::Parse($coords[1], $culture) * $radians
        }
        catch {
            Write-Host "[$i/$Attempts] bad ipinfo payload"
            continue
        }

        $checked++
        $halfLat = ($exitLat - $centerLat) / 2
        $halfLon = ($exitLon - $centerLon) / 2
        $a = [math]::Pow([math]::Sin($halfLat), 2) +
            [math]::Cos($centerLat) * [math]::Cos($exitLat) *
            [math]::Pow([math]::Sin($halfLon), 2)
        $a = [math]::Max(0.0, [math]::Min(1.0, $a))
        $miles = 3958.8 * 2 * [math]::Asin([math]::Sqrt($a))
        $milesRounded = [math]::Round($miles, 2)

        Write-Host ("[{0}/{1}] {2}, {3} {4}  {5} mi  {6}" -f $i, $Attempts, $info.city, $info.region, $info.postal, $milesRounded, $info.ip)

        if ($miles -lt $closestMiles) {
            $closestMiles = $miles
            $closest = '{0}, {1} {2} ({3} mi)' -f $info.city, $info.region, $info.postal, $milesRounded
        }

        $cityOk = ([string]$info.city).Trim().Equals($wantCity, [StringComparison]::OrdinalIgnoreCase)
        $stateOk = ([string]$info.region).Trim().Equals($wantRegion, [StringComparison]::OrdinalIgnoreCase)
        $zipOk = ([string]$info.postal).Trim().StartsWith($Zip)
        if ($info.country -ne 'US' -or -not $cityOk -or -not $stateOk -or -not $zipOk) {
            continue
        }

        $endpoint = [uri]$gateway
        # Linken Sphere: host:port:username:password
        $proxyEntry = '{0}:{1}:{2}:{3}' -f $endpoint.Host, $endpoint.Port, $username, $password
        Set-Clipboard -Value $proxyEntry -ErrorAction Stop

        Write-Host ''
        Write-Host "MATCH $($info.ip)  $($info.city), $($info.region) $($info.postal)  $milesRounded mi"
        Write-Host "session=$session"
        Write-Host "Copied budget.legionproxy.io:1337:${username}:<password>"
        Write-Host 'Paste into Linken Sphere.'
        return
    }
}
finally {
    Write-Progress -Activity "Finding a LegionProxy exit in $wantCity $Zip" -Completed
    Remove-Variable password, login, config, proxyEntry -ErrorAction SilentlyContinue
}

Write-Host ''
if ($checked -eq 0) {
    Write-Warning "No usable ipinfo results after $Attempts attempts. Check the saved Legion login, then run test-one-line.ps1 if you get a 407."
}
else {
    Write-Host "No $wantCity, $wantRegion $Zip exit in $Attempts attempts ($checked usable)."
    Write-Host "Closest: $closest"
}
exit 1

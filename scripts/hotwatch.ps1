# Hotwatch: On-Together relaunch handler in case of a crash or scheduled reboot
# Windows version. Requires Enabled = true in awe.hotserver.cfg. Start it in the background with: hotcli start hotwatch

# BepInEx folder HOTServer is installed in, saved by hotcli setup
$PathsFile = Join-Path (Split-Path $PSScriptRoot -Parent) 'hotserver.paths'
$Root = $null
if (Test-Path $PathsFile) { foreach ($l in [IO.File]::ReadAllLines($PathsFile)) { if ($l.StartsWith('BEPINEX=')) { $Root = $l.Substring(8) } } }
if (-not $Root) { [Console]::Error.WriteLine('HOTServer location unknown. Run: hotcli setup'); exit 1 }
$Flag  = Join-Path $Root 'hotserver.stopped'   # written by `hotcli stop`, removed when the game starts
$Cfg   = Join-Path $Root 'config\awe.hotserver.cfg'
$Port  = 27555
if (Test-Path $Cfg) { foreach ($l in [IO.File]::ReadAllLines($Cfg)) { if ($l.StartsWith('Port = ')) { $Port = [int]$l.Substring(7) } } }
$WatchLog = Join-Path $Root 'hotwatch.log'
$Check     = 30    # seconds between checks
$Grace     = 180   # Gives a grace period before we start watching
$HangFails = 2     # Failed health checks in a row (~1 min). Possibly hung, so we kill

function Log($msg) {
    $line = "[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $msg
    Write-Host $line
    Add-Content -Path $WatchLog -Value $line -ErrorAction SilentlyContinue
}
function Get-GameProcs    { @(Get-CimInstance Win32_Process -Filter "Name='OnTogether.exe'" -ErrorAction SilentlyContinue) }
function Get-ServerProcs  { @(Get-GameProcs | Where-Object { $_.CommandLine -match '-batchmode' }) }   # our headless instance
function Test-Running     { [bool](Get-ServerProcs) }
function Test-GameRunning { [bool](Get-GameProcs) }                                                   # any instance, incl. normal play
function Test-Booting     { ((Get-Date) - $script:launched).TotalSeconds -lt $Grace }
function Start-Game       { Log 'launching'; & "$PSScriptRoot\hotcli.ps1" start | Out-Null; $script:launched = Get-Date }

# Health check: does HOTServer answer `status`?
function Test-Healthy {
    $client = New-Object Net.Sockets.TcpClient
    try {
        $client.Connect('127.0.0.1', $Port)
        $stream = $client.GetStream(); $stream.ReadTimeout = 10000
        $writer = New-Object IO.StreamWriter($stream); $writer.NewLine = "`n"; $writer.AutoFlush = $true
        $writer.WriteLine('status')
        return ($null -ne (New-Object IO.StreamReader($stream)).ReadLine())
    } catch { return $false } finally { $client.Close() }
}

$launched = [datetime]::MinValue
$fails = 0
Log "hotwatch started (BepInEx: $Root)"

while ($true) {
    if (Test-Path $Flag) {                    # stopped on purpose
        Start-Sleep -Seconds $Check; continue
    }

    if (-not (Test-Running)) {
        if (Test-GameRunning) {               # someone is playing normally, leave it alone
            Start-Sleep -Seconds $Check; continue
        }
        if (-not (Test-Booting)) { Log 'game not running'; Start-Game }
        $fails = 0; Start-Sleep -Seconds $Check; continue
    }

    if (-not (Test-Booting)) {
        if (Test-Healthy) {
            $fails = 0
        } else {
            $fails++
            if ($fails -ge $HangFails) {
                Log "unresponsive for ~$($HangFails * $Check)s, killing"
                Get-ServerProcs | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
                $fails = 0; Start-Sleep -Seconds 10
            }
        }
    }
    Start-Sleep -Seconds $Check
}

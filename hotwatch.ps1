# Hotwatch: On-Together relaunch handler in case of a crash or scheduled reboot
# Windows version. Requires Enabled = true in awe.hotserver.cfg

# Find the game folder through Steam (registry -> libraryfolders.vdf), since these scripts can live anywhere.
# Set HOT_GAME to skip the lookup.
function Find-GameDir {
    if ($env:HOT_GAME) { return $env:HOT_GAME }
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if (-not $steam) { $steam = "${env:ProgramFiles(x86)}\Steam" }
    $libs = @($steam)
    $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
    if (Test-Path $vdf) {
        foreach ($l in Get-Content $vdf) {
            if ($l -match '^\s*"path"\s+"(.+)"') { $libs += ($Matches[1] -replace '\\\\', '\') }
        }
    }
    foreach ($lib in $libs) {
        $dir = Join-Path $lib 'steamapps\common\On-Together\On-Together'
        if (Test-Path $dir) { return $dir }
    }
    [Console]::Error.WriteLine('Could not find On-Together. Set HOT_GAME to the game folder (the one with OnTogether.exe).')
    exit 1
}
$Game  = Find-GameDir
$Flag  = Join-Path $Game 'BepInEx\hotserver.stopped'   # written by `hotctl stop`, removed when the game starts
$Port  = if ($env:HOTCTL_PORT) { [int]$env:HOTCTL_PORT } else { 27555 }
$AppId = 3707400
$Check     = 15    # seconds between checks
$Grace     = 180   # Gives a grace period before we start watching
$HangFails = 4     # Failed health checks in a row (~1 min). Possibly hung, so we kill

function Log($msg)    { Write-Host ("[{0:yyyy-MM-dd HH:mm:ss}] {1}" -f (Get-Date), $msg) }
function Test-Running { [bool](Get-Process -Name OnTogether -ErrorAction SilentlyContinue) }
function Test-Booting { ((Get-Date) - $script:launched).TotalSeconds -lt $Grace }
function Start-Game   { Log 'launching'; Start-Process "steam://rungameid/$AppId"; $script:launched = Get-Date }

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
Log "hotwatch started (game: $Game)"

while ($true) {
    if (Test-Path $Flag) {                    # stopped on purpose
        Start-Sleep -Seconds $Check; continue
    }

    if (-not (Test-Running)) {
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
                Stop-Process -Name OnTogether -Force -ErrorAction SilentlyContinue
                $fails = 0; Start-Sleep -Seconds 10
            }
        }
    }
    Start-Sleep -Seconds $Check
}

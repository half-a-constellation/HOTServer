# hotctl <command...>   e.g. hotctl status | hotctl set name My Room | hotctl players | hotctl start
# Windows version. Can live anywhere; finds the game through Steam.

$Port  = if ($env:HOTCTL_PORT) { [int]$env:HOTCTL_PORT } else { 27555 }
$AppId = 3707400

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
$Tags  = @('focus', 'mature', 'chill', 'break', 'modded')

$Help = @"
hotctl commands:
  start                                  Start the server
  stop                                   Stop the server (hotwatch won't relaunch it)
  reboot | restart                       Restart the server
  status                                 Lobby ID, player count, lobby name, next reboot
  players                                Everyone in the lobby
  config                                 Current lobby settings
  set name <text>                        Lobby name
  set maxplayers <number>                Player limit
  set public|voice|request true|false    Visibility / voice chat / request to join
  tag add|remove <tag>                   Tags: focus, mature, chill, break, modded
"@

$argv = @($args)
if ($argv.Count -eq 0 -or @('help', '-h', '--help') -contains $argv[0]) { Write-Output $Help; exit 0 }
$Game  = Find-GameDir
$Cfg   = Join-Path $Game 'BepInEx\config\awe.hotserver.cfg'
$Flag  = Join-Path $Game 'BepInEx\hotserver.stopped'   # tells hotwatch that we stopped on purpose so it doesnt try to restart thinking it was a crash

function Test-Running { [bool](Get-Process -Name OnTogether -ErrorAction SilentlyContinue) }
function Start-Game   { Start-Process "steam://rungameid/$AppId" }
function Fail($msg)   { [Console]::Error.WriteLine($msg); exit 1 }

# Send one command to the running server and print its reply
function Send-Line($client, $line) {
    $stream = $client.GetStream()
    $stream.ReadTimeout = 10000
    $writer = New-Object IO.StreamWriter($stream); $writer.NewLine = "`n"; $writer.AutoFlush = $true
    $reader = New-Object IO.StreamReader($stream)
    $writer.WriteLine($line)
    try {
        while ($null -ne ($reply = $reader.ReadLine())) {
            if ($reply -eq '.') { break }
            Write-Output $reply
        }
    } catch { }
    $client.Close()
}

# Offline-able commands
function Test-Truthy($v) { if (@('1', 'true', 'yes', 'on', 't') -contains $v.ToLower()) { 'true' } else { 'false' } }
function Assert-Cfg      { if (-not (Test-Path $Cfg)) { Fail "Config not found: $Cfg (launch the game once first)" } }
function Get-CfgValue($key) {
    foreach ($l in [IO.File]::ReadAllLines($Cfg)) { if ($l.StartsWith("$key = ")) { return $l.Substring($key.Length + 3) } }
    return ''
}
function Set-CfgValue($key, $value) {
    $lines = [IO.File]::ReadAllLines($Cfg)
    for ($i = 0; $i -lt $lines.Length; $i++) { if ($lines[$i].StartsWith("$key = ")) { $lines[$i] = "$key = $value" } }
    [IO.File]::WriteAllLines($Cfg, $lines, (New-Object Text.UTF8Encoding $false))
}

if ($argv[0] -eq 'restart') { $argv[0] = 'reboot' }
$cmd = $argv[0].ToLower()

$client = New-Object Net.Sockets.TcpClient
try { $client.Connect('127.0.0.1', $Port); $online = $true } catch { $online = $false }

if ($online) {
    if ($cmd -eq 'reboot') {
        Send-Line $client 'reboot' | Out-Null
        for ($i = 0; $i -lt 60 -and (Test-Running); $i++) { Start-Sleep -Seconds 1 }
        Start-Game
        Write-Output 'Rebooting HOTServer'
        exit 0
    }
    Send-Line $client ($argv -join ' ')
    exit 0
}

if (Test-Running) {
    Fail "The game is running but HOTServer isn't answering yet (still starting, or the config has Enabled = false). Try again in a moment."
}

switch ($cmd) {
    'start' {
        Start-Game
        Write-Output 'Starting server HOTServer'
    }

    'stop' {
        New-Item -ItemType File -Force -Path $Flag | Out-Null
        Write-Output 'HOTServer already stopped'
    }

    'config' {
        Assert-Cfg
        Write-Output ("name=`"{0}`" maxplayers={1} public={2} voice={3} request={4} tags={5} (server off)" -f `
            (Get-CfgValue 'Name'), (Get-CfgValue 'MaxPlayers'), (Get-CfgValue 'Public'), `
            (Get-CfgValue 'VoiceChat'), (Get-CfgValue 'RequestToJoin'), (Get-CfgValue 'Tags'))
    }

    'set' {
        Assert-Cfg
        if ($argv.Count -lt 3) { Fail 'usage: hotctl set <name|maxplayers|public|voice|request> <value>' }
        $val = ($argv[2..($argv.Count - 1)] -join ' ')
        switch ($argv[1].ToLower()) {
            'name'       { Set-CfgValue 'Name' $val }
            'maxplayers' { if ($val -notmatch '^\d+$' -or [int]$val -lt 1) { Fail 'ERR int >= 1' }; Set-CfgValue 'MaxPlayers' $val }
            'public'     { Set-CfgValue 'Public' (Test-Truthy $val) }
            'voice'      { Set-CfgValue 'VoiceChat' (Test-Truthy $val) }
            'request'    { Set-CfgValue 'RequestToJoin' (Test-Truthy $val) }
            default      { Fail 'ERR unknown key' }
        }
        Write-Output 'OK (restart HOTServer to apply)'
    }

    'tag' {
        Assert-Cfg
        $op  = if ($argv.Count -gt 1) { $argv[1].ToLower() } else { '' }
        $tag = if ($argv.Count -gt 2) { $argv[2].ToLower() } else { '' }
        if (@('add', 'remove') -notcontains $op -or -not $tag) { Fail "usage: hotctl tag <add|remove> <tag>   (tags: $($Tags -join ','))" }
        if ($Tags -notcontains $tag) { Fail "ERR unknown tag (tags: $($Tags -join ','))" }
        $current = @((Get-CfgValue 'Tags').ToLower() -split '[,\s]+' | Where-Object { $_ -and $_ -ne $tag })
        if ($op -eq 'add') { $current += $tag }
        $new = $current -join ','
        Set-CfgValue 'Tags' $new
        Write-Output ("OK tags={0} (applies on next start)" -f $(if ($new) { $new } else { '(none)' }))
    }

    { @('status', 'players', 'reboot') -contains $_ } {
        Fail "HOTServer isn't running. Start it first: hotctl start"
    }

    default {
        Fail 'ERR unknown command (try: hotctl help)'
    }
}

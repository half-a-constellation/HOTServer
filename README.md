# HOTServer
**A headless server mod for the game On-Together: Virtual Co-Working**

*Just don’t run it on a cheap VPS in summer*

Note: This mod only works on Linux (Game running under Proton-GE Latest) so far.
Other OSes are on the way!

## DISCLAIMER
Installing the mod enables the mod by default. This is intended for quick server-setups. If you wish to play on the same system, in your BepInEx config folder, inside `awe.hotserver.cfg` set `Enabled = true` to `false`, then launch the game.
Once done and you want to run it headless again, set it to `Enabled = true`

## Features

### Server Compatibility
You can run the server 24/7 on a VPS in the cloud. I am yet to perform a 24h test on a Microsoft Azure Standard D2as v6 (2 vcpus, 8 GiB memory) instance.

### Auto recover and reboot
Schedule server reboots at a specific time to prevent memory buildup.
A service can automatically attempt to restart the server when it detects a crash.

### ZERO GPU Usage.
Since the game runs headless, it only uses your CPU. Feel free to run another game or graphically intensive task in the background.

### Mod Support
Should be compatible with other BepInEx mods. If there is any problem, please open an Issue.

### Lightweight
Adds no overhead on top of the game. This mod simply enables the creation of the server using the game's own functionality.

## Config
All your server information and config data lives in `GAME_FOLDER/BepInEx/config/awe.hotserver.cfg`. If you wish to edit it manually, you can.

## Setup
### 1. Install BepInEx
Download the **windows** release of [BepInEx](https://github.com/BepInEx/BepInEx/releases/) and extract the contents to the game folder at `~/.local/share/Steam/steamapps/common/On-Together/On-Together`
### 2. Run the game
Set the launch options (Steam → On-Together → Properties → Launch Options) to ```WINEDLLOVERRIDES="winhttp=n,b" %command% -batchmode``` and run the game once to generate the BepInEx files.
### 3. Install HOTServer
Download the latest `HOTServer.zip` from the [releases](https://github.com/half-a-constellation/HOTServer/releases) into `BepInEx/plugins/` inside the game folder.
### 4. Install hotctl and hotwatch
Cd into `BepInEx/plugins/HOTServer` and run
```bash
install -m 755 hotctl ~/.local/bin/
hotctl status
```

### 5. HOTWatch
Server crash, hang detection and scheduled reboot functionality is provided by HOTWatch.
It is NOT a mod and is a separate service that runs on your system. This is completely OPTIONAL. If you wish not to install it, you may skip this step.
```bash
install -m 755 hotwatch ~/.local/bin/
```
and then run it
```bash
hotwatch
```
You can use it on your desktop too, but please remember to stop the game using `hotctl stop` instead of quitting directly.
Do NOT play with `Enabled=false` and HOTWatch running at the same time!

## CLI Usage

| Command | What it does |
| --- | --- |
| `hotctl help` | Lists all commands |
| `hotctl start` | Starts the server (Runs steam game) |
| `hotctl status` | Shows server status (Lobby ID, Player count, Lobby name) |
| `hotctl players` | Lists everyone in the lobby with SteamID and name |
| `hotctl config` | Shows current server settings |
| `hotctl set name <servername>` | Changes the server name |
| `hotctl set maxplayers <number>` | Changes the player limit |
| `hotctl set public true\|false` | Changes the server visibility |
| `hotctl set voice true\|false` | Enables / disables voicechat functionality |
| `hotctl set request true\|false` | Enables / disables 'request to join' |
| `hotctl tag add <tag>` | Adds a tag to the lobby (focus, mature, chill, break, modded) |
| `hotctl tag remove <tag>` | Removes a tag from the lobby (focus, mature, chill, break, modded) |
| `hotctl stop` | Stops the server |
| `hotctl reboot` | Reboots the server |

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
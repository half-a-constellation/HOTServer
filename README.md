# HOTServer
**A headless server mod for the game On-Together: Virtual Co-Working**

Just don’t run it on a cheap VPS in summer *wink*

![Linux](https://img.shields.io/badge/Linux-tested-brightgreen?logo=linux&logoColor=white)
![Windows](https://img.shields.io/badge/Windows-experimental-orange?logo=windows&logoColor=white)
![BepInEx](https://img.shields.io/badge/BepInEx-5.4.23.5-blue)
![Release](https://img.shields.io/github/v/release/half-a-constellation/HOTServer)
![License](https://img.shields.io/github/license/half-a-constellation/HOTServer)

## DISCLAIMER
The mod only runs when the game is started by `hotcli start`. If you wish to play on the same system, just launch the game from Steam.
Mod manager installs (r2modman, Gale) are experimental and untested.

## Features

### Server Compatibility
You no longer need an extra laptop to run an OT server. This mod works in a cloud VPS and has passed a 10h test on a Microsoft Azure Standard D2as v6 (2 vcpus, 8 GiB memory) instance.

### Auto recover and reboot
Schedule server reboots at a specific time to prevent memory buildup.
A service can automatically attempt to restart the server when it detects a crash.

### ZERO GPU Usage.
Since the game runs headless, it only uses your CPU (and ~1 GB of VRAM). Feel free to run another game or graphically intensive task in the background.

### Mod Support
Being a mod itself, it's compatible with other BepInEx mods (such as Heartbeat). If there is any problem, please open an Issue.

### Lightweight
Adds no overhead on top of the game. This mod simply enables the creation of the server using the game's own functionality.

## Config
All your server information and config data lives in `GAME_FOLDER/BepInEx/config/awe.hotserver.cfg` (or in your mod manager profile's `BepInEx/config`). If you wish to edit it manually, you can.

## Setup
Note: The following setup instructions are for non-mod manager setups. For mod manager setups, please read the instructions on the store page.
See the [Windows setup guide](docs/setup/windows.md) for running HOTServer on a windows desktop.  
See the [Linux setup guide](docs/setup/linux.md) for running HOTServer on a linux desktop.  
See the [VPS setup guide](docs/setup/vps.md) for running HOTServer on a linux cloud server.  


## CLI Usage

| Command | What it does |
| --- | --- |
| `hotcli help` | Lists all commands |
| `hotcli setup` | Runs setup (runs automatically the first time) |
| `hotcli start` | Starts the server (Runs steam game) |
| `hotcli status` | Shows server status (Lobby ID, Player count, Lobby name, next reboot, HOTWatch) |
| `hotcli players` | Lists everyone in the lobby with SteamID and name |
| `hotcli config` | Shows current server settings |
| `hotcli set name <servername>` | Changes the server name |
| `hotcli set maxplayers <number>` | Changes the player limit |
| `hotcli set public true\|false` | Changes the server visibility |
| `hotcli set voice true\|false` | Enables / disables voicechat functionality |
| `hotcli set request true\|false` | Enables / disables 'request to join' |
| `hotcli set reboot <HH:MM\|off>` | Sets the daily reboot time (24h format), or turns it off |
| `hotcli tag add <tag>` | Adds a tag to the lobby (focus, mature, chill, break, modded) |
| `hotcli tag remove <tag>` | Removes a tag from the lobby (focus, mature, chill, break, modded) |
| `hotcli stop` | Stops the server |
| `hotcli reboot` | Reboots the server |
| `hotcli start hotwatch` | Starts HOTWatch in the background |
| `hotcli stop hotwatch` | Stops HOTWatch |

## Contributing
Contributions are welcome! Please feel free to submit a Pull Request.

## License
This project is licensed under the MIT License - see the LICENSE file for details.
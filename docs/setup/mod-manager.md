### 1. Install HOTServer with your mod manager.
BepInEx is installed automatically.  
**LINUX ONLY** set the launch options (Steam → On-Together → Properties → Launch Options) to `WINEDLLOVERRIDES="winhttp=n,b" %command%`
### 2. Run the game
Click **Start modded** once, then close the game. This creates the config file.
### 3. Download the necessary scripts
Download and extract `HOTServer-Scripts_<version>.zip` from the [GitHub releases](https://github.com/half-a-constellation/HOTServer/releases).
### 4. Run the server
Open `linux_run.sh` or `windows_run.cmd` from the extracted folder, use `hotcli` to edit your config, then run `hotcli start` to run the server.

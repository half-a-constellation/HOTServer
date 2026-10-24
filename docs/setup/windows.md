### 1. Install BepInEx
Download [BepInEx_win_x64_5.4.23.5.zip](https://github.com/BepInEx/BepInEx/releases/)  
In Steam, right-click On-Together, then Manage → Browse local files. That opens the game folder.  
Extract the contents of BepInEx to the game folder.
### 2. Run the game
Run the game once to generate the BepInEx files.
### 3. Download and install HOTServer
Download the latest `HOTServer-dll_<version>.zip` from the [releases](https://github.com/half-a-constellation/HOTServer/releases), extract it anywhere and copy the `HOTServer` folder into `BepInEx/plugins/` inside the game folder.  
Also download and extract `HOTServer-Scripts_<version>.zip`. It contains the necessary scripts to start and manage the server.  
### 4. Run the game once more to generate the config file
The mod creates `BepInEx\config\awe.hotserver.cfg` and stays idle, so you can set the lobby name before the first real start.
### 5. Edit your server config and run the game!
Open `windows_run.cmd` in the extracted HOTServer-Scripts folder and use `hotcli` to edit your config, or edit your config manually at `BepInEx/config/awe.hotserver.cfg`. Then, run `hotcli start` to run the server
### 6. HOTWatch (Optional)
Type `hotcli start hotwatch` to start HOTWatch, a service that handles server crashes, prolonged hangs and scheduled reboots. You can stop it using `hotcli stop hotwatch` It runs hidden in the background and logs to BepInEx\hotwatch.log.
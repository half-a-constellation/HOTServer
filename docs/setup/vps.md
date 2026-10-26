> The following assumes that you are running an x86 VPS on Ubuntu 24.04 lts or higher.
> For other distros, look for the equivalent of the following commands

Tested on a Microsoft Azure Standard D2as v6 (2 vCPUs, 8 GiB memory).  

### 1. Install required packages
```bash
sudo apt update
sudo apt install -y xvfb x11vnc openbox xterm x11-utils unzip wget screen python3-vdf
```

### 2. Install Steam
We are using Valve's own repository. If you want to do this yourself in another way, go ahead but I wouldn't recommend it  
```bash
sudo dpkg --add-architecture i386
curl -fsSL https://repo.steampowered.com/steam/archive/stable/steam.gpg | sudo tee /usr/share/keyrings/steam.gpg >/dev/null
sudo tee /etc/apt/sources.list.d/steam.sources >/dev/null <<'EOF'
Types: deb
URIs: https://repo.steampowered.com/steam/
Suites: stable
Components: steam
Architectures: amd64 i386
Signed-By: /usr/share/keyrings/steam.gpg
EOF
sudo apt update
sudo apt install -y steam-launcher
```

### 3. Set up a virtual screen
Steam NEEDS a screen to run, else it simply refuses to. We are creating a virtual monitor in the system memory, which you can connect to from your PC and display.  
We are also creating a few autostart rules  
```bash
U=$USER
sudo tee /etc/systemd/system/xvfb.service >/dev/null <<EOF
[Unit]
Description=Virtual display :1
After=network.target

[Service]
User=$U
ExecStartPre=-/bin/rm -f /tmp/.X1-lock /tmp/.X11-unix/X1
ExecStart=/usr/bin/Xvfb :1 -screen 0 1024x600x24 -nolisten tcp
ExecStartPost=/bin/sh -c 'for i in \$(seq 50); do [ -S /tmp/.X11-unix/X1 ] && exit 0; sleep 0.1; done; exit 1'
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/openbox.service >/dev/null <<EOF
[Unit]
Description=Window manager on :1
BindsTo=xvfb.service
After=xvfb.service

[Service]
User=$U
Environment=DISPLAY=:1
ExecStart=/usr/bin/openbox
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/x11vnc.service >/dev/null <<EOF
[Unit]
Description=VNC for :1 (localhost only)
BindsTo=xvfb.service
After=xvfb.service

[Service]
User=$U
ExecStart=/usr/bin/x11vnc -display :1 -localhost -forever -nopw -shared
Restart=always

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable --now xvfb openbox x11vnc
systemctl status xvfb openbox x11vnc --no-pager
```
VNC only listens on localhost, so it can only be reached through an SSH tunnel.  

### 4. Open the display we created on your system
We're gonna connect to the virtual screen we just created. Run this in a terminal on your system. This opens a tunnel to your server.  
```bash
ssh -i Your_VM_Key.pem -N -L 5900:localhost:5900 user@your-vps-ip
```
Then use a VNC viewer to connect to `localhost:5900`. I personally recommend TigerVNC.  

Now on the server, start steam.  
```bash
DISPLAY=:1 steam
```
You should be able to see a steam window open (if not, give it some time). You can also watch the logs. How long it takes depends on the speed of your vps.  
Login to your steam account and install On-Together.  

### 5. Set the launch options
After installing the game, Right click open properties. If it opens, congrats, just paste this into launch options under the General category.  
`WINEDLLOVERRIDES="winhttp=n,b" %command%`  
If it doesn't like it did for me, close steam using `pkill -f steam` and run the following  
```bash
python3 - <<'EOF'
import glob, vdf
for p in glob.glob('/home/' + __import__('getpass').getuser() + '/.local/share/Steam/userdata/*/config/localconfig.vdf'):
    d = vdf.load(open(p, encoding='utf-8'))
    apps = d['UserLocalConfigStore']['Software']['Valve']['Steam']['apps']
    apps.setdefault('3707400', {})['LaunchOptions'] = 'WINEDLLOVERRIDES="winhttp=n,b" %command%'
    vdf.dump(d, open(p, 'w', encoding='utf-8'), pretty=True)
    print('updated', p)
EOF
```
Now open steam and check if `WINEDLLOVERRIDES="winhttp=n,b" %command%` is visible under the game launch options in properties.
If it does, kill it again (lol) using `pkill -f steam` for the next step

### 6. Keep Steam running
Run Steam inside `screen` (it's what it says), so it keeps running after you close SSH  
```bash
screen -S steam
DISPLAY=:1 steam -silent
```
Detach from the screen with `Ctrl+A` then `D`. Use `screen -r steam` to bring it back.  
You can close the VNC viewer and the terminal tunnel now.

### 7. Install BepInEx
Run the following command to install BepInEx to your game folder.  
If you installed steam through another method (Flatpak, snap, etc) your game directory will likely be different. Find that game dir and run the command accordingly.
```bash
GAME=~/.local/share/Steam/steamapps/common/On-Together/On-Together
wget https://github.com/BepInEx/BepInEx/releases/download/v5.4.23.5/BepInEx_win_x64_5.4.23.5.zip
unzip BepInEx_win_x64_5.4.23.5.zip -d "$GAME"
```

### 8. Install HOTServer
Download `HOTServer-dll_<version>.zip` and `HOTServer-Scripts_<version>.zip` from the Github [releases](https://github.com/half-a-constellation/HOTServer/releases).
Copy the link of the latest release and run the following commands accordingly
```bash
GAME=~/.local/share/Steam/steamapps/common/On-Together/On-Together
wget <link to HOTServer-dll zip>
wget <link to HOTServer-Scripts zip>
mkdir -p "$GAME/BepInEx/plugins"
unzip HOTServer-dll_*.zip -d "$GAME/BepInEx/plugins"
unzip HOTServer-Scripts_*.zip
```

### 9. Run the game once to generate the config file
```bash
DISPLAY=:1 steam -applaunch 3707400
```
Wait about 2 minutes, then close it:
```bash
pkill -f OnTogether.exe
```
`BepInEx/config/awe.hotserver.cfg` should be created now.

### 10. Edit your server config and run the server
```bash
~/HOTServer/linux_run.sh
```
Use `hotcli` to edit your config (or edit `BepInEx/config/awe.hotserver.cfg` manually), then run `hotcli start`.  
`hotcli status` shows the lobby once the server is up.

### 11. HOTWatch (Optional)
`hotcli start hotwatch` handles crashes, prolonged hangs and scheduled reboots.

### Notes
- Nothing starts HOTServer after the VPS restarts. The virtual screen comes back on its own, but you have to run `hotcli start` manually. Just ssh and run it.
- Steam may log you out at times, or you may have sync issues. If you notice that `hotcli status` doesn't show that the lobby started after a while, run step 4 to connect and see what the issue is.
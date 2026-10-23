0.2.0

Fix `hotctl restart` stops hotserver but doesnt start it again  
Made hotctl commands work offline. Those that need the server running will prompt you to start it now  
Addressed a small time gap between running `hotctl start` and the server being up during which it would report that the server is not running.  
Moved all commands out of src so its easier to run  
Add Windows equivalents of the hotctl and hotwatch handlers  
Reverted hotwatch check interval from 30 to 15 seconds  
Fixed a white/black screen on proton when server is running  
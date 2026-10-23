@echo off
title HOTServer
cd /d "%~dp0"

call hotctl.cmd start
echo.
call hotctl.cmd help
echo.
echo Type hotctl commands below, e.g.  hotctl status
echo Closing this window does NOT stop the server. Use  hotctl stop  for that.
echo.

prompt HOTServer$G
cmd /k

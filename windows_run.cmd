@echo off
rem Run to get a terminal with HOTCli ready to use.
title HOTServer
powershell -NoLogo -NoProfile -NoExit -ExecutionPolicy Bypass -Command "function global:hotcli { & '%~dp0scripts\hotcli.ps1' @args }; function global:prompt { 'HOTServer> ' }; hotcli help; 'Type hotcli commands here, e.g.  hotcli status'; 'Start the server using hotcli start'; 'Closing this window does NOT stop the server. Use  hotcli stop  for that.'; ''"

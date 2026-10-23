@echo off
title HOTWatch
echo HOTWatch is watching HOTServer for crashes.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hotwatch.ps1"

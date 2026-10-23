@echo off
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0hotctl.ps1" %*
exit /b %ERRORLEVEL%

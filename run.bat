@echo off
powershell.exe -NoProfile -File "%~dp0devops.ps1"
set "setup_exit=%errorlevel%"
pause
exit /b %setup_exit%

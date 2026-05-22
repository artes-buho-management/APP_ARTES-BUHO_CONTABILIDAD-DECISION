@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\appscript\scripts\pull_api.ps1" -TokenProfile default
set EXIT_CODE=%ERRORLEVEL%
if not "%EXIT_CODE%"=="0" (
  echo PULL_APPS_SCRIPT_ERROR codigo=%EXIT_CODE%
  exit /b %EXIT_CODE%
)

echo PULL_APPS_SCRIPT_OK
exit /b 0

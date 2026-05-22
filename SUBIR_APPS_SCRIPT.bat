@echo off
setlocal
cd /d "%~dp0"

powershell -NoProfile -ExecutionPolicy Bypass -File ".\appscript\scripts\push_api.ps1" -AuthMode auto -TokenProfile booking_workspace_full_bella
set EXIT_CODE=%ERRORLEVEL%
if not "%EXIT_CODE%"=="0" (
  echo PUSH_APPS_SCRIPT_ERROR codigo=%EXIT_CODE%
  exit /b %EXIT_CODE%
)

echo PUSH_APPS_SCRIPT_OK
exit /b 0

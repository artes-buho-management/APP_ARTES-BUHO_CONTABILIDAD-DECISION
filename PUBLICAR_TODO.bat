@echo off
setlocal
cd /d "%~dp0"

if "%~1"=="" (
  powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\pipeline_respuesta_automatica.ps1" -PublishManual
) else (
  powershell -NoProfile -ExecutionPolicy Bypass -File ".\tools\pipeline_respuesta_automatica.ps1" -PublishManual -CommitMessage "%*"
)

set EXIT_CODE=%ERRORLEVEL%
if not "%EXIT_CODE%"=="0" (
  echo PUBLICACION_ERROR codigo=%EXIT_CODE%
  exit /b %EXIT_CODE%
)

echo PUBLICACION_OK
exit /b 0

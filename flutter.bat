@echo off
setlocal
set "PROJECT_FLUTTER=%~dp0tools\flutter\bin\flutter.bat"
if not exist "%PROJECT_FLUTTER%" (
  echo [ERROR] Project Flutter SDK not found at "%PROJECT_FLUTTER%".
  exit /b 1
)
call "%PROJECT_FLUTTER%" %*

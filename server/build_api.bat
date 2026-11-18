@echo off

cd /d "%~dp0"

echo Building API CLI bundle...

dart pub get

if errorlevel 1 exit /b 1

if not exist "build\api_release\bundle\bin" mkdir "build\api_release\bundle\bin"

dart compile exe bin\server.dart -o build\api_release\bundle\bin\server.exe

if errorlevel 1 exit /b 1

echo.

echo Output: %CD%\build\api_release\bundle\

echo   bin\server.exe

pause

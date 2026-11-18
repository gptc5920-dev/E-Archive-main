@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo   E-Archive Inno Setup installer build
echo ============================================
echo.

call build_release.bat --no-pause
if errorlevel 1 exit /b 1

echo.
echo Building the installer from the complete release folder...
call dart run inno_bundle --no-app
if errorlevel 1 exit /b 1

echo.
echo ============================================
echo   Installer build complete
echo ============================================
echo Output: build\windows\x64\installer\Release
echo.
pause

@echo off
cd /d "%~dp0"
echo ============================================
echo   E-Archive API  (keep this window OPEN)
echo   MySQL:  defaults to root@127.0.0.1:3306/e_archive
echo   URL:    http://127.0.0.1:8080
echo ============================================
echo If port 8080 is busy, run stop_server.bat first.
echo.

call "%~dp0stop_server.bat" nopause

dart pub get

if errorlevel 1 exit /b 1

dart run bin/server.dart

pause

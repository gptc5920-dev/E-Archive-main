@echo off
setlocal
cd /d "%~dp0"

echo ============================================
echo   E-Archive release build (Windows)
echo ============================================
echo.

echo [1/4] Building API executable (no Dart needed at runtime)...
cd server
call dart pub get
if errorlevel 1 exit /b 1
REM Use a dedicated staging directory. The development app may currently be
REM running build\api_release\bundle\bin\server.exe, which Windows then locks.
if exist "build\package_staging" rmdir /s /q "build\package_staging"
if not exist "build\package_staging\bundle\bin" mkdir "build\package_staging\bundle\bin"
call dart compile exe bin\server.dart -o build\package_staging\bundle\bin\server.exe
if errorlevel 1 exit /b 1
cd ..

if not exist "server\build\package_staging\bundle\bin\server.exe" (
  echo ERROR: The staged API executable was not created.
  exit /b 1
)
echo.
echo [2/4] Preparing Flutter release dependencies...
call flutter pub get
if errorlevel 1 exit /b 1
call dart run pdfrx:remove_wasm_modules
if errorlevel 1 exit /b 1

echo.
echo [3/4] Building Flutter Windows release...
set "RELEASE=build\windows\x64\runner\Release"
if exist "%RELEASE%" rmdir /s /q "%RELEASE%"
call flutter build windows --release -t lib/main.dart
if errorlevel 1 exit /b 1

echo.
echo [4/4] Packaging API next to the app...
set "API_SRC=server\build\package_staging\bundle"

if not exist "%RELEASE%\e_archive.exe" (
  echo ERROR: %RELEASE%\e_archive.exe not found.
  exit /b 1
)

if exist "%RELEASE%\api" rmdir /s /q "%RELEASE%\api"
if exist "%RELEASE%\api_release" rmdir /s /q "%RELEASE%\api_release"

xcopy /E /I /Y "%API_SRC%" "%RELEASE%\api" >nul
if errorlevel 1 (
  echo ERROR: Failed to copy API bundle into %RELEASE%\api
  exit /b 1
)

if not exist "%RELEASE%\uploads" mkdir "%RELEASE%\uploads"
if exist "server\uploads" (
  xcopy /E /I /Y "server\uploads\*" "%RELEASE%\uploads\" >nul
)

if not exist "%RELEASE%\api\bin\server.exe" (
  echo ERROR: %RELEASE%\api\bin\server.exe is missing after packaging.
  exit /b 1
)

echo.
echo ============================================
echo   Done
echo ============================================
echo.
echo Run the app from:
echo   %RELEASE%\e_archive.exe
echo.
echo To install on another PC, copy the ENTIRE Release folder:
echo   %RELEASE%
echo   (e_archive.exe, flutter_windows.dll, data\, api\, uploads\)
echo.
echo The API starts automatically (api\bin\server.exe).
echo Database: MySQL (defaults to root@127.0.0.1:3306/e_archive)
echo.
if /i "%~1"=="--no-pause" exit /b 0
pause

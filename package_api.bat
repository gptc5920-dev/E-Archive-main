@echo off
setlocal
cd /d "%~dp0"

echo Packaging API into the release folder...
echo.

echo Building a fresh API executable...
cd server
call dart pub get
if errorlevel 1 exit /b 1
REM Keep packaging output separate from the executable used by a running
REM development app so Windows file locks cannot make this build fail.
if exist "build\package_staging" rmdir /s /q "build\package_staging"
if not exist "build\package_staging\bundle\bin" mkdir "build\package_staging\bundle\bin"
call dart compile exe bin\server.dart -o build\package_staging\bundle\bin\server.exe
if errorlevel 1 exit /b 1
cd ..

set "RELEASE=build\windows\x64\runner\Release"
set "API_SRC=server\build\package_staging\bundle"

if not exist "%RELEASE%\e_archive.exe" (
  echo ERROR: Build the app first: flutter build windows --release
  echo        or run build_release.bat
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
echo OK: %RELEASE%\api\bin\server.exe is ready.
echo Copy the entire Release folder to other PCs:
echo   %RELEASE%
echo Run: %RELEASE%\e_archive.exe
echo.
if /i "%~1"=="--no-pause" exit /b 0
pause

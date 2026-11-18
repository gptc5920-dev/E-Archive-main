# Run from server folder:  .\run_server.ps1

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
Set-Location $PSScriptRoot

Write-Host 'Stopping API on port 8080...'
try {
    $lines = netstat -ano | Select-String ':8080\s+.*LISTENING'
    foreach ($line in $lines) {
        $procId = ($line -split '\s+')[-1]
        if ($procId -match '^\d+$') {
            Write-Host "  Stopping PID $procId"
            Stop-Process -Id ([int]$procId) -Force -ErrorAction SilentlyContinue
        }
    }
    Start-Sleep -Seconds 1
} catch {
    Write-Warning "Could not stop processes: $_"
}

Write-Host 'Starting E-Archive API...'
dart pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
dart run bin/server.dart

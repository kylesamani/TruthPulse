# TruthPulse PowerToys Run Plugin installer
# Run from packages/windows/ directory

$ErrorActionPreference = "Stop"

$dest = "$env:LOCALAPPDATA\Microsoft\PowerToys\PowerToys Run\Plugins\TruthPulse"

# Build the plugin
Write-Host "Building TruthPulse PowerToys Run plugin..." -ForegroundColor Cyan
dotnet build PowerToysPlugin -c Release
if ($LASTEXITCODE -ne 0) { throw "Build failed" }

# Stop PowerToys if running
$pt = Get-Process -Name "PowerToys" -ErrorAction SilentlyContinue
if ($pt) {
    Write-Host "Stopping PowerToys..." -ForegroundColor Yellow
    Stop-Process -Name PowerToys -Force
    Start-Sleep -Seconds 2
}

# Copy plugin files
Write-Host "Installing plugin to $dest" -ForegroundColor Cyan
New-Item -ItemType Directory -Path $dest -Force | Out-Null
Copy-Item "PowerToysPlugin\bin\Release\*" $dest -Recurse -Force

Write-Host ""
Write-Host "Done! Restart PowerToys, then type 'tp ' followed by your search query." -ForegroundColor Green
Write-Host "Example: tp trump" -ForegroundColor Gray
Write-Host ""
Write-Host "NOTE: The TruthPulse desktop app must be running for the plugin to return results." -ForegroundColor Yellow

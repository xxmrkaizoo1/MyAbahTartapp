# Runs the app on the USB-connected Android phone with the AI link set up.
# Usage (from the project folder):  powershell -ExecutionPolicy Bypass -File tool\run_phone.ps1
# Works on mobile hotspot: the phone reaches Ollama through the USB cable, not Wi-Fi.

$ErrorActionPreference = 'Stop'
Set-Location (Split-Path $PSScriptRoot -Parent)

try {
    Invoke-RestMethod -Uri 'http://localhost:11434/api/tags' -TimeoutSec 3 | Out-Null
    Write-Host 'Ollama is running.'
} catch {
    Write-Host 'Ollama is not running. Starting it...'
    Start-Process 'ollama' -ArgumentList 'serve' -WindowStyle Hidden
    Start-Sleep -Seconds 3
}

$device = (adb devices | Select-String '\tdevice$' | Select-Object -First 1)
if (-not $device) {
    Write-Host 'No phone found. Plug it in by USB, allow USB debugging, then run this again.'
    exit 1
}
$id = ($device.ToString() -split "`t")[0]

adb -s $id reverse tcp:11434 tcp:11434 | Out-Null
Write-Host "AI link ready: phone localhost:11434 -> this computer (device $id)"

flutter run -d $id

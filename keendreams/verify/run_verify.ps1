# Keen Dreams sim-verification gate (mirrors keen13/verify and omnispeak verify).
# Replays the recorded baseline with per-frame full-sim hashes; PASS proves a
# change touched only presentation.  Run after ANY engine change.
$ErrorActionPreference = "Stop"
$PSNativeCommandUseErrorActionPreference = $false
$game = Join-Path $PSScriptRoot "..\game"
$trace = Join-Path $PSScriptRoot "baseline_kdreams.klr"
Push-Location $game
$env:KL_WARP = "1"
$env:KL_REPLAY = $trace
$ErrorActionPreference = "Continue"
$out = & .\reflection-kdreams.exe -gamever kdreamse100 -cfgdir ..\verify\cfg -datadir data 2>&1 | Out-String
$ErrorActionPreference = "Stop"
$env:KL_REPLAY = $null
$env:KL_WARP = $null
Pop-Location
if ($out -match "KL REPLAY OK \((\d+) frames\)") {
    Write-Host "Keen Dreams : PASS ($($Matches[1]) frames)" -ForegroundColor Green
} else {
    $why = ($out -split "`n" | Select-String "KL VERIFY" | Select-Object -First 1)
    Write-Host "Keen Dreams : FAIL -- $why" -ForegroundColor Red
    exit 1
}

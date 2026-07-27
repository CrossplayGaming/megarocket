# Keen Launcher sim-verification harness.
# Replays Keen 4 demos through the sim with per-frame state checksums and
# compares against the committed baselines (which are themselves verified
# byte-identical to pristine upstream Omnispeak at commit 144f21e).
#
# Run after ANY engine change. A PASS proves the change did not touch the
# simulation. Usage:  powershell -File run_verify.ps1

$ErrorActionPreference = "Stop"
$rt = Join-Path $PSScriptRoot "..\rt"
$baselines = Join-Path $PSScriptRoot "baselines"
Set-Location $rt

# Isolated config: modern presentation defaults, windowed.
New-Item -ItemType Directory -Force -Path vfy_run | Out-Null
Set-Content vfy_run\OMNISPK.CFG "fullscreen = false"

$fail = 0
foreach ($d in 0, 1, 2, 3) {
    $trace = "vfy_run\trace_d$d.txt"
    $p = Start-Process .\omnispeak-wide.exe -ArgumentList "/EPISODE", "4", "/PLAYDEMO", "$d", "/USERPATH", "vfy_run", "/CHECKSUM", $trace -PassThru
    $p.WaitForExit(120000) | Out-Null
    if (-not $p.HasExited) { Stop-Process -Id $p.Id -Force; Write-Host "demo $d : TIMEOUT" -ForegroundColor Red; $fail++; continue }
    $base = Join-Path $baselines "keen4_demo$d.txt"
    if ((Get-FileHash $trace).Hash -eq (Get-FileHash $base).Hash) {
        Write-Host "demo $d : PASS ($(Get-Content $trace -Tail 1))" -ForegroundColor Green
    } else {
        $diff = Compare-Object (Get-Content $base) (Get-Content $trace) | Select-Object -First 3
        Write-Host "demo $d : FAIL -- sim diverged from baseline" -ForegroundColor Red
        $diff | Format-Table | Out-String | Write-Host
        $fail++
    }
}

if ($fail -eq 0) { Write-Host "`nALL PASS -- simulation is bit-identical to verified baseline." -ForegroundColor Green }
else { Write-Host "`n$fail FAILURE(S) -- a change has touched the simulation." -ForegroundColor Red; exit 1 }

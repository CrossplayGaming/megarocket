# Keen 1-3 sim-verification harness.
#
# Replays a recorded input trace through each episode's simulation, checking
# seven component state hashes per frame (objects, projectiles, gamestate,
# origin, level, RNG).  A PASS proves the change under test did not alter the
# simulation -- run it after ANY engine change.
#
# Usage:  powershell -File run_verify.ps1

$ErrorActionPreference = "Stop"
$root = Join-Path $PSScriptRoot ".."
# the verdict comes out on stderr; PowerShell would otherwise treat that as
# a terminating error and abort the run before we can read it
$PSNativeCommandUseErrorActionPreference = $false
$fail = 0

$episodes = @(
    @{ ep = 1; dir = "gamedata";  exe = "keen13.exe";     trace = "baseline_keen1.k13r" },
    @{ ep = 2; dir = "gamedata2"; exe = "keen13_ep2.exe"; trace = "baseline_keen2.k13r" },
    @{ ep = 3; dir = "gamedata3"; exe = "keen13_ep3.exe"; trace = "baseline_keen3.k13r" }
)

foreach ($e in $episodes) {
    $dir = Join-Path $root $e.dir
    $exe = Join-Path $dir $e.exe
    $trace = Join-Path $PSScriptRoot $e.trace
    if (-not (Test-Path $exe))   { Write-Host "Keen $($e.ep) : no exe staged"   -ForegroundColor Yellow; $fail++; continue }
    if (-not (Test-Path $trace)) { Write-Host "Keen $($e.ep) : no baseline"     -ForegroundColor Yellow; $fail++; continue }

    Push-Location $dir
    $env:K13_REPLAY = $trace
    $env:K13_WARP = "1"
    $ErrorActionPreference = "Continue"
    $out = & ".\$($e.exe)" 2>&1 | Out-String
    $ErrorActionPreference = "Stop"
    Remove-Item Env:\K13_REPLAY, Env:\K13_WARP -ErrorAction SilentlyContinue
    Pop-Location

    if ($out -match "REPLAY OK \((\d+) frames\)") {
        Write-Host "Keen $($e.ep) : PASS ($($Matches[1]) frames)" -ForegroundColor Green
    } else {
        $why = ($out -split "`n" | Select-String "K13 VERIFY" | Select-Object -First 1)
        Write-Host "Keen $($e.ep) : FAIL -- $why" -ForegroundColor Red
        $fail++
    }
}

Write-Host ""
if ($fail -eq 0) { Write-Host "ALL PASS -- simulation unchanged across Keen 1-3." -ForegroundColor Green }
else { Write-Host "$fail episode(s) failed." -ForegroundColor Red; exit 1 }

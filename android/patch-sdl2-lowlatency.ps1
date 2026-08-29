# Backports SDL3's AAudio low-latency request into the vendored SDL2 tree.
# SDL2's AAudio backend never asks for AAUDIO_PERFORMANCE_MODE_LOW_LATENCY,
# so Android serves the default power-saving stream: 40-150ms of output
# buffering, audible as a solid action-to-sound gap in the games.
# Idempotent: run once per fresh SDL2 tree.
#
#   powershell -File android\patch-sdl2-lowlatency.ps1 [-Sdl2 <path>]

param([string]$Sdl2 = "$PSScriptRoot\..\deps\SDL2-2.32.10-src")

$ErrorActionPreference = "Stop"
$funcs = Join-Path $Sdl2 "src\audio\aaudio\SDL_aaudiofuncs.h"
$impl  = Join-Path $Sdl2 "src\audio\aaudio\SDL_aaudio.c"

if (-not (Test-Path $impl)) { throw "not an SDL2 source tree: $Sdl2" }

$f = Get-Content $funcs -Raw
if ($f -match "SDL_PROC_UNUSED\(void, AAudioStreamBuilder_setPerformanceMode") {
    $f = $f -replace "SDL_PROC_UNUSED\(void, AAudioStreamBuilder_setPerformanceMode",
                     "SDL_PROC(void, AAudioStreamBuilder_setPerformanceMode"
    Set-Content $funcs $f -NoNewline
    Write-Host "patched $funcs (symbol now loaded)"
}

$c = Get-Content $impl -Raw
if ($c -notmatch "setPerformanceMode") {
    $anchor = "    ctx.AAudioStreamBuilder_setErrorCallback(ctx.builder, aaudio_errorCallback,"
    $inject = "    ctx.AAudioStreamBuilder_setPerformanceMode(ctx.builder, AAUDIO_PERFORMANCE_MODE_LOW_LATENCY);`r`n`r`n"
    $c = $c.Replace($anchor, $inject + $anchor)
    Set-Content $impl $c -NoNewline
    Write-Host "patched $impl (low-latency requested at both open sites)"
}

Write-Host "SDL2 AAudio now requests LOW_LATENCY (as SDL3 does upstream)"

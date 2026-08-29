# Renames SDL3's Android Java glue from org.libsdl.app to org.libsdl3.app
# inside the vendored SDL3 source tree, so SDL2's and SDL3's glue can
# coexist in one APK (the megarocket app hosts SDL2 engines and the SDL3
# Keen Dreams engine together).  Idempotent: run once per fresh SDL3 tree.
#
#   powershell -File android\patch-sdl3-java-package.ps1 [-Sdl3 <path>]

param([string]$Sdl3 = "$PSScriptRoot\..\deps\SDL3-3.2.30")

$ErrorActionPreference = "Stop"
$javaDir = Join-Path $Sdl3 "android-project\app\src\main\java\org\libsdl\app"
$native  = Join-Path $Sdl3 "src\core\android\SDL_android.c"

if (-not (Test-Path $native)) { throw "not an SDL3 source tree: $Sdl3" }

# Native side: JNI class-path strings
$c = Get-Content $native -Raw
if ($c -match "org/libsdl/app") {
    Set-Content $native ($c -replace "org/libsdl/app", "org/libsdl3/app") -NoNewline
    Write-Host "patched $native"
}

# Java side: package/import declarations, then move the directory
if (Test-Path $javaDir) {
    Get-ChildItem $javaDir -Filter *.java | ForEach-Object {
        $j = Get-Content $_.FullName -Raw
        Set-Content $_.FullName ($j -replace "org\.libsdl\.app", "org.libsdl3.app") -NoNewline
    }
    $newDir = Join-Path $Sdl3 "android-project\app\src\main\java\org\libsdl3\app"
    New-Item -ItemType Directory -Force (Split-Path $newDir) | Out-Null
    Move-Item $javaDir $newDir
    Write-Host "renamed java package dir -> org\libsdl3\app"
}

Write-Host "SDL3 glue now lives in org.libsdl3.app"

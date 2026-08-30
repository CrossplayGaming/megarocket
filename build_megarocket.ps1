# Megarocket distribution builder ("the recompiler build").
#
# Rebuilds every engine + the launcher from source, then assembles a
# clean distributable tree by CONSTRUCTIVE COPY: only known-safe files
# are placed (GPL binaries we built, stock SDL DLLs, omnispeak's own
# public metadata, README).  No game data, no derived assets (title art,
# Galaxy audio, configs, saves) can leak in, because nothing is copied
# from the working game folders at all.

$ErrorActionPreference = "Stop"
$root  = $PSScriptRoot
$cmake = (Get-Command cmake -ErrorAction SilentlyContinue).Source
if (-not $cmake) {
    $cmake = "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin\cmake.exe"
}
if (-not (Test-Path $cmake)) { throw "cmake not found; install VS Build Tools or add cmake to PATH" }
$dist  = "$root\dist\Megarocket"

function Build($dir, $config, $what) {
    Write-Host "== building $what"
    & $cmake --build "$dir\build" --config $config 2>&1 |
        Where-Object { $_ -match ": error" } | ForEach-Object { Write-Host $_ }
    if ($LASTEXITCODE -ne 0) { throw "build failed: $what" }
}

Build "$root\keen13\port" "Release"        "Keen 1-3 engine"
Build "$root\omnispeak"   "RelWithDebInfo" "Keen 4-6 engine (omnispeak)"
Build "$root\refkeen"     "Release"        "Keen Dreams engine (refkeen)"
Build "$root\launcher"    "Release"        "Megarocket launcher"

Write-Host "== assembling $dist"
if (Test-Path $dist) {
    # The user's Steam shortcut points INTO this tree and they have copied
    # their game files (and so their saves) into it.  A dist that contains
    # game data is somebody's live install: refuse to delete it rather than
    # silently eat their saves.  Point the shortcut at another copy (e.g.
    # F:\Dropbox\Megarocket) or move the data out to rebuild here.
    $inhabited = Get-ChildItem -Recurse -File $dist -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "^(KEEN[123]\.EXE|kdreams\.exe)$" -or
                       $_.Extension -match "^\.(ck[1-6]|kdr)$" -and
                       $_.Name -notmatch "^(ACTION|EPISODE|AUDINFOE|GFXINFOE|MAPINFO|TERMINFO|GFXCHUNK|AUDIOHHD|AUDIODCT|EGADICT|EGAHEAD|STRINGS)" }
    if ($inhabited) {
        throw "dist contains GAME DATA (someone plays from it) -- refusing to wipe $dist"
    }
    Remove-Item -Recurse -Force $dist
}
$dirs = @(
    "$dist\launcher",
    "$dist\keen13\gamedata", "$dist\keen13\gamedata2", "$dist\keen13\gamedata3",
    "$dist\rt", "$dist\rt\keen6-data\e10", "$dist\rt\keen6-data\e14",
    "$dist\rt\keen6-data\e15", "$dist\keendreams\game"
)
$dirs | ForEach-Object { New-Item -ItemType Directory -Force $_ | Out-Null }

$sdl2 = "$root\deps\SDL2-2.32.10\lib\x64\SDL2.dll"
$sdl3 = "$root\deps\SDL3-3.2.18\lib\x64\SDL3.dll"

# launcher
Copy-Item "$root\launcher\build\Release\keenlauncher.exe" "$dist\launcher\Megarocket.exe"
Copy-Item $sdl2 "$dist\launcher\SDL2.dll"
Set-Content "$dist\Start Megarocket.bat" "@echo off`r`nstart `"`" `"%~dp0launcher\Megarocket.exe`"`r`n"

# Keen 1-3 (data-free engines; tables boot-ripped from the user's exes)
Copy-Item "$root\keen13\port\build\Release\keen13.exe"     "$dist\keen13\gamedata\keen13.exe"
Copy-Item "$root\keen13\port\build\Release\keen13_ep2.exe" "$dist\keen13\gamedata2\keen13_ep2.exe"
Copy-Item "$root\keen13\port\build\Release\keen13_ep3.exe" "$dist\keen13\gamedata3\keen13_ep3.exe"
"gamedata", "gamedata2", "gamedata3" | ForEach-Object {
    Copy-Item $sdl2 "$dist\keen13\$_\SDL2.dll"
}

# Keen 4-6 (omnispeak's own public metadata ships; game files do not)
Copy-Item "$root\omnispeak\build\RelWithDebInfo\omnispeak.exe" "$dist\rt\omnispeak-wide.exe"
Copy-Item $sdl2 "$dist\rt\SDL2.dll"
Copy-Item "$root\omnispeak\data\keen4\*"    "$dist\rt\"
Copy-Item "$root\omnispeak\data\keen5\*"    "$dist\rt\"
Copy-Item "$root\omnispeak\data\keen6e14\*" "$dist\rt\"
Copy-Item "$root\omnispeak\data\keen6e10\*" "$dist\rt\keen6-data\e10\"
Copy-Item "$root\omnispeak\data\keen6e14\*" "$dist\rt\keen6-data\e14\"
Copy-Item "$root\omnispeak\data\keen6e15\*" "$dist\rt\keen6-data\e15\"

# Keen Dreams (refkeen reads everything from the user's kdreams.exe/data)
Copy-Item "$root\refkeen\build\Release\reflection-kdreams.exe" "$dist\keendreams\game\reflection-kdreams.exe"
Copy-Item $sdl3 "$dist\keendreams\game\SDL3.dll"

Copy-Item "$root\dist-src\README.txt" "$dist\README.txt"

# a placement guide INSIDE each game folder -- the files go loose in the
# folder (next to the engine exe), never as a subfolder
$guides = @{
    "$dist\keen13\gamedata\PUT KEEN 1 FILES HERE.txt" = @"
Copy the Keen 1 files LOOSE into this folder, next to keen13.exe
(no subfolder!).  When it is right, this folder contains:

    keen13.exe  SDL2.dll  <-- already here
    KEEN1.EXE                  (required: the engine reads id's data
                                tables out of it at every boot)
    EGAHEAD.CK1  EGALATCH.CK1  EGASPRIT.CK1  ...and the other .CK1 files

The slot lights up READY in the launcher when the files are in place.
"@
    "$dist\keen13\gamedata2\PUT KEEN 2 FILES HERE.txt" = @"
Copy the Keen 2 files LOOSE into this folder, next to keen13_ep2.exe
(no subfolder!): KEEN2.EXE plus all the .CK2 files.
"@
    "$dist\keen13\gamedata3\PUT KEEN 3 FILES HERE.txt" = @"
Copy the Keen 3 files LOOSE into this folder, next to keen13_ep3.exe
(no subfolder!): KEEN3.EXE plus all the .CK3 files.
"@
    "$dist\rt\PUT KEEN 4 5 6 FILES HERE.txt" = @"
Keen 4, 5 and 6 SHARE this folder.  Copy all three games' files LOOSE
in here, next to omnispeak-wide.exe (no subfolders!) -- the .CK4, .CK5
and .CK6 extensions keep them apart:

    EGAGRAPH.CK4  GAMEMAPS.CK4  AUDIO.CK4   (and the rest of Keen 4)
    EGAGRAPH.CK5  GAMEMAPS.CK5  AUDIO.CK5   (and the rest of Keen 5)
    EGAGRAPH.CK6  GAMEMAPS.CK6  AUDIO.CK6   (and the rest of Keen 6)

Keen 6 note: this folder comes set up for v1.4.  If your copy is v1.0
or v1.5, first copy the contents of keen6-data\e10 (or e15) over the
files here.  With Keen 4 and 5 installed, Keen 1-3 also gain the
"Galaxy sfx" and "Galaxy tunes" options automatically.
"@
    "$dist\keendreams\game\PUT KEEN DREAMS FILES HERE.txt" = @"
Copy the Keen Dreams files LOOSE into this folder, next to
reflection-kdreams.exe (no subfolder!): kdreams.exe plus the .KDR
files (egagraph.kdr, gamemaps.kdr, audio.kdr).
"@
}
foreach ($g in $guides.GetEnumerator()) { Set-Content $g.Key $g.Value }

# audit: fail loudly if anything that looks like game data slipped in
$leaks = Get-ChildItem -Recurse -File $dist | Where-Object {
    $_.Extension -match "^\.(ck1|ck2|ck3|kdr|wav|imf|ppm|cfg|png)$" -and
    $_.Name -notmatch "^(ACTION|EPISODE|AUDINFOE|GFXINFOE|MAPINFO|TERMINFO|GFXCHUNK|AUDIOHHD|AUDIODCT|EGADICT|EGAHEAD|STRINGS)"
}
if ($leaks) { $leaks | ForEach-Object { Write-Host "LEAK: $($_.FullName)" }; throw "game data leaked into dist" }

$size = [math]::Round((Get-ChildItem -Recurse -File $dist | Measure-Object Length -Sum).Sum / 1MB, 1)
Write-Host "== done: $dist ($size MB, $((Get-ChildItem -Recurse -File $dist).Count) files)"

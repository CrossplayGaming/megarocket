@echo off
REM ---------------------------------------------------------------------------
REM  Open the Keen launcher for testing.
REM
REM  Lives at the repo root on purpose: the launcher works out where the games
REM  are from its own location, and KEEN_ROOT is set here explicitly so this
REM  still works from a desktop shortcut, where the working directory is
REM  whatever Explorer felt like.
REM ---------------------------------------------------------------------------

setlocal

REM %~dp0 ends with a backslash; strip it so paths don't come out as "...\/..."
set "KEEN_ROOT=%~dp0"
set "KEEN_ROOT=%KEEN_ROOT:~0,-1%"

set "LAUNCHER=%~dp0launcher\keenlauncher.exe"

if not exist "%LAUNCHER%" (
    echo.
    echo   keenlauncher.exe not found at:
    echo     %LAUNCHER%
    echo.
    echo   Build it first:
    echo     cd /d "%~dp0launcher"
    echo     cmake -S . -B build -G "Visual Studio 17 2022" -A x64 ^
-DSDL2_DIR=F:/KeenLauncher/deps/SDL2-2.32.10/cmake
    echo     cmake --build build --config Release
    echo     copy build\Release\keenlauncher.exe .
    echo     copy build\Release\SDL2.dll .
    echo.
    pause
    exit /b 1
)

REM Run from the launcher's own folder so it finds SDL2.dll beside the exe.
REM "start" hands off and lets this console close; %* passes any extra args
REM straight through.
start "Commander Keen" /d "%~dp0launcher" "%LAUNCHER%" %*

endlocal

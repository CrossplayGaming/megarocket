@echo off
:go
rem tc %1.prj
make -f%1.MAK
cd %1
if "%3"=="noLZEXE" goto crc
if "%3"=="PKLITE" goto pklite
..\lzexe\lzexe.exe %1.exe
goto crc
:pklite
..\PKLITE1.05\PKLITE.EXE %1.exe
:crc
..\CHECKCRC\CHECKCRC.EXE %1.exe %2
if not errorlevel 1 goto done
choice /s Delete .OBJ files and recompile? /n 
if errorlevel 2 goto done
echo.
cd ..
call cleanup.bat %1
goto go

:done
echo.
cd..
@echo off
cycles max

rem *** Mount the Turbo C++ 1.0 directory as drive X: ***
mount x D:\DOS\TCPP100

rem *** Mount the Turbo Assembler directory as drive W: ***
mount w D:\DOS\SOURCE\TASM200

rem *** Make sure TC++ and TASM executables are in the PATH environment: ***
set PATH=%PATH%;X:\BIN;W:\
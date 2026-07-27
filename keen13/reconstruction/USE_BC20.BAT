@echo off
cycles max

rem *** Mount the Borland C++ 2.0 directory as drive X: ***
mount x D:\DOS\SOURCE\BC20

rem *** Make sure BC++ and TASM executables are in the PATH environment: ***
set PATH=%PATH%;X:\BIN
@echo off
if "%1"=="" goto help
make -f%1.MAK
goto end
:help
echo You must type BUILD followed by the project name.
echo For example: BUILD RCK1
echo.
:end
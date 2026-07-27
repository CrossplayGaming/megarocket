@echo off
if "%1"=="" goto all
del %1\KEEN*.OBJ
del %1\ID*.OBJ
del %1\%1.EXE
del %1\%1.OLD
goto end

:all
call cleanup.bat rck1
call cleanup.bat rck2
call cleanup.bat rck3

call cleanup.bat rck1beta
call cleanup.bat rck1v10
call cleanup.bat rck1v11
call cleanup.bat rck1v13
call cleanup.bat rck1v132
call cleanup.bat rck1v134

call cleanup.bat rck2v10
call cleanup.bat rck2v11
call cleanup.bat rck2v132

call cleanup.bat rck3v10
call cleanup.bat rck3v11
call cleanup.bat rck3v132

:end
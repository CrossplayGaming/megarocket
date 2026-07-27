.AUTODEPEND

.PATH.obj = rck1v10

#		*Translator Definitions*
CC = tcc +rck1v10.cfg
TASM = TASM
TLIB = tlib
TLINK = tlink
LIBPATH = X:\LIB
INCLUDEPATH = X:\INCLUDE


#		*Implicit Rules*
.c.obj:
  $(CC) -c {$< }

.cpp.obj:
  $(CC) -c {$< }

#		*List Macros*


EXE_dependencies =  \
 tinfck1.obj \
 keenmain.obj \
 keen1act.obj \
 idlibc.obj \
 keendemo.obj \
 rck1v10\idasm.obj \
 rck1v10\endscrn.obj

#		*Explicit Rules*
rck1v10\rck1v10.exe: rck1v10.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1v10\tinfck1.obj+
rck1v10\keenmain.obj+
rck1v10\keen1act.obj+
rck1v10\idlibc.obj+
rck1v10\keendemo.obj+
rck1v10\idasm.obj+
rck1v10\endscrn.obj
rck1v10\rck1v10
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1v10.cfg tinfck1.c 

keenmain.obj: rck1v10.cfg keenmain.c 

keen1act.obj: rck1v10.cfg keen1act.c 

idlibc.obj: rck1v10.cfg idlibc.c 

keendemo.obj: rck1v10.cfg keendemo.c keenscrn.c 

rck1v10\idasm.obj: rck1v10.cfg idasm.asm 
	$(TASM) /MX /ZI /O /DUSELOOPS /DOLDKEYBOARD idasm.asm,rck1v10\idasm.obj

#		*Compiler Configuration File*
rck1v10.cfg: rck1v10.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck1v10
-DVERSION=0x0100
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1v10.cfg



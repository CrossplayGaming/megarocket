.AUTODEPEND

.PATH.obj = rck1v11

#		*Translator Definitions*
CC = tcc +rck1v11.cfg
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
 rck1v11\idasm.obj \
 rck1v11\endscrn.obj

#		*Explicit Rules*
rck1v11\rck1v11.exe: rck1v11.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1v11\tinfck1.obj+
rck1v11\keenmain.obj+
rck1v11\keen1act.obj+
rck1v11\idlibc.obj+
rck1v11\keendemo.obj+
rck1v11\idasm.obj+
rck1v11\endscrn.obj
rck1v11\rck1v11
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1v11.cfg tinfck1.c 

keenmain.obj: rck1v11.cfg keenmain.c 

keen1act.obj: rck1v11.cfg keen1act.c 

idlibc.obj: rck1v11.cfg idlibc.c 

keendemo.obj: rck1v11.cfg keendemo.c keenscrn.c 

rck1v11\idasm.obj: rck1v11.mak idasm.asm 
	$(TASM) /MX /ZI /O /DOLDKEYBOARD idasm.asm,rck1v11\idasm.obj

#		*Compiler Configuration File*
rck1v11.cfg: rck1v11.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck1v11
-DVERSION=0x0110
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1v11.cfg



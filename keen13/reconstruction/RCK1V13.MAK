.AUTODEPEND

.PATH.obj = RCK1V13

#		*Translator Definitions*
CC = tcc +RCK1V13.CFG
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
 keenscrn.obj \
 rck1v13\idasm.obj \
 rck1v13\endscrn.obj

#		*Explicit Rules*
rck1v13\rck1v13.exe: rck1v13.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1v13\tinfck1.obj+
rck1v13\keenmain.obj+
rck1v13\keen1act.obj+
rck1v13\idlibc.obj+
rck1v13\keendemo.obj+
rck1v13\keenscrn.obj+
rck1v13\idasm.obj+
rck1v13\endscrn.obj
rck1v13\rck1v13
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1v13.cfg tinfck1.c 

keenmain.obj: rck1v13.cfg keenmain.c 

keen1act.obj: rck1v13.cfg keen1act.c 

idlibc.obj: rck1v13.cfg idlibc.c 

keendemo.obj: rck1v13.cfg keendemo.c 

keenscrn.obj: rck1v13.cfg keenscrn.c 

rck1v13\idasm.obj: rck1v13.cfg idasm.asm 
	$(TASM) /MX /ZI /O /DVER_130 IDASM.ASM,RCK1V13\IDASM.OBJ

#		*Compiler Configuration File*
rck1v13.cfg: rck1v13.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nRCK1V13
-DVERSION=0x0130
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1v13.cfg



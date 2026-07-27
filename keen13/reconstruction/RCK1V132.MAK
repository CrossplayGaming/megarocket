.AUTODEPEND

.PATH.obj = RCK1V132

#		*Translator Definitions*
CC = bcc +rck1v132.CFG
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
 rck1v132\idasm.obj \
 rck1v132\endscrn.obj

#		*Explicit Rules*
rck1v132\rck1v132.exe: rck1v132.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1v132\tinfck1.obj+
rck1v132\keenmain.obj+
rck1v132\keen1act.obj+
rck1v132\idlibc.obj+
rck1v132\keendemo.obj+
rck1v132\keenscrn.obj+
rck1v132\idasm.obj+
rck1v132\endscrn.obj+
rck1v132\introscn.obj
rck1v132\rck1v132
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1v132.cfg tinfck1.c 

keenmain.obj: rck1v132.cfg keenmain.c 

keen1act.obj: rck1v132.cfg keen1act.c 

idlibc.obj: rck1v132.cfg idlibc.c 

keendemo.obj: rck1v132.cfg keendemo.c 

keenscrn.obj: rck1v132.cfg keenscrn.c 

rck1v132\idasm.obj: rck1v132.cfg idasm.asm 
	$(TASM) /MX /ZI /O /DNEWORDER IDASM.ASM,rck1v132\IDASM.OBJ

#		*Compiler Configuration File*
rck1v132.cfg: rck1v132.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck1v132
-DVERSION=0x0132
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1v132.cfg



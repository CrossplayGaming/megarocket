.AUTODEPEND

.PATH.obj = RCK1

#		*Translator Definitions*
CC = tcc +RCK1.CFG
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
 rck1\idasm.obj \
 rck1\endscrn.obj

#		*Explicit Rules*
rck1\rck1.exe: rck1.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1\tinfck1.obj+
rck1\keenmain.obj+
rck1\keen1act.obj+
rck1\idlibc.obj+
rck1\keendemo.obj+
rck1\keenscrn.obj+
rck1\idasm.obj+
rck1\endscrn.obj
rck1\rck1
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1.cfg tinfck1.c 

keenmain.obj: rck1.cfg keenmain.c 

keen1act.obj: rck1.cfg keen1act.c 

idlibc.obj: rck1.cfg idlibc.c 

keendemo.obj: rck1.cfg keendemo.c 

keenscrn.obj: rck1.cfg keenscrn.c 

rck1\idasm.obj: rck1.cfg idasm.asm 
	$(TASM) /MX /ZI /O IDASM.ASM,RCK1\IDASM.OBJ

#		*Compiler Configuration File*
rck1.cfg: rck1.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nRCK1
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1.cfg



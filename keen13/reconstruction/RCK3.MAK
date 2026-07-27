.AUTODEPEND

.PATH.obj = RCK3

#		*Translator Definitions*
CC = tcc +RCK3.CFG
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
 tinfck3.obj \
 keenmain.obj \
 idlibc.obj \
 keen3act.obj \
 keendemo.obj \
 keenscrn.obj \
 rck3\idasm.obj \
 rck3\endscrn.obj \
 rck3\sounds.obj \
 rck3\helptext.obj \
 rck3\endtext.obj \
 rck3\previews.obj \
 rck3\storytxt.obj

#		*Explicit Rules*
rck3\rck3.exe: rck3.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck3\tinfck3.obj+
rck3\keenmain.obj+
rck3\idlibc.obj+
rck3\keen3act.obj+
rck3\keendemo.obj+
rck3\keenscrn.obj+
rck3\idasm.obj+
rck3\endscrn.obj+
rck3\sounds.obj+
rck3\helptext.obj+
rck3\endtext.obj+
rck3\previews.obj+
rck3\storytxt.obj
rck3\rck3
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck3.obj: rck3.cfg tinfck3.c 

keenmain.obj: rck3.cfg keenmain.c 

idlibc.obj: rck3.cfg idlibc.c 

keen3act.obj: rck3.cfg keen3act.c 

keendemo.obj: rck3.cfg keendemo.c 

keenscrn.obj: rck3.cfg keenscrn.c 

rck3\idasm.obj: rck3.cfg idasm.asm 
	$(TASM) /MX /ZI /O IDASM.ASM,RCK3\IDASM.OBJ

#		*Compiler Configuration File*
rck3.cfg: rck3.mak
  copy &&|
-f-
-v
-vi-
-weas
-nRCK3
-I$(INCLUDEPATH)
-L$(LIBPATH)
-DEPISODE=3
-P-.C
| rck3.cfg



.AUTODEPEND

.PATH.obj = RCK2

#		*Translator Definitions*
CC = tcc +RCK2.CFG
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
 tinfck2.obj \
 keenmain.obj \
 idlibc.obj \
 keen2act.obj \
 keendemo.obj \
 keenscrn.obj \
 rck2\idasm.obj \
 rck2\endscrn.obj \
 rck2\sounds.obj \
 rck2\endtext.obj \
 rck2\helptext.obj \
 rck2\previews.obj \
 rck2\storytxt.obj

#		*Explicit Rules*
rck2\rck2.exe: rck2.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck2\tinfck2.obj+
rck2\keenmain.obj+
rck2\idlibc.obj+
rck2\keen2act.obj+
rck2\keendemo.obj+
rck2\keenscrn.obj+
rck2\idasm.obj+
rck2\endscrn.obj+
rck2\sounds.obj+
rck2\endtext.obj+
rck2\helptext.obj+
rck2\previews.obj+
rck2\storytxt.obj
rck2\rck2
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck2.obj: rck2.cfg tinfck2.c 

keenmain.obj: rck2.cfg keenmain.c 

idlibc.obj: rck2.cfg idlibc.c 

keen2act.obj: rck2.cfg keen2act.c 

keendemo.obj: rck2.cfg keendemo.c 

keenscrn.obj: rck2.cfg keenscrn.c 

rck2\idasm.obj: rck2.cfg idasm.asm 
	$(TASM) /MX /ZI /O IDASM.ASM,RCK2\IDASM.OBJ

#		*Compiler Configuration File*
rck2.cfg: rck2.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nRCK2
-I$(INCLUDEPATH)
-L$(LIBPATH)
-DEPISODE=2
-P-.C
| rck2.cfg



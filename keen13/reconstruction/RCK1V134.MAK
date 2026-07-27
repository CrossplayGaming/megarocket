.AUTODEPEND

.PATH.obj = rck1v134

#		*Translator Definitions*
CC = bcc +rck1v134.cfg
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
 rck1v134\idasm.obj \
 rck1v134\endscrn.obj

#		*Explicit Rules*
rck1v134\rck1v134.exe: rck1v134.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1v134\tinfck1.obj+
rck1v134\keenmain.obj+
rck1v134\keen1act.obj+
rck1v134\idlibc.obj+
rck1v134\keendemo.obj+
rck1v134\keenscrn.obj+
rck1v134\idasm.obj+
rck1v134\endscrn.obj
rck1v134\rck1v134
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck1.obj: rck1v134.cfg tinfck1.c 

keenmain.obj: rck1v134.cfg keenmain.c 

keen1act.obj: rck1v134.cfg keen1act.c 

idlibc.obj: rck1v134.cfg idlibc.c 

keendemo.obj: rck1v134.cfg keendemo.c 

keenscrn.obj: rck1v134.cfg keenscrn.c 

rck1v134\idasm.obj: rck1v134.cfg idasm.asm 
	$(TASM) /MX /ZI /O /DNEWORDER idasm.asm,rck1v134\idasm.obj

#		*Compiler Configuration File*
rck1v134.cfg: rck1v134.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck1v134
-DVERSION=0x0134
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1v134.cfg



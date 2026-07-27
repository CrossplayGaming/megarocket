.AUTODEPEND

.PATH.obj = rck2v10

#		*Translator Definitions*
CC = tcc +rck2v10.cfg
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
 rck2v10\idasm.obj \
 rck2v10\endscrn.obj \
 rck2v10\sounds.obj \
 rck2v10\endtext.obj \
 rck2v10\helptext.obj \
 rck2v10\previews.obj \
 rck2v10\storytxt.obj

#		*Explicit Rules*
rck2v10\rck2v10.exe: rck2v10.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck2v10\tinfck2.obj+
rck2v10\keenmain.obj+
rck2v10\idlibc.obj+
rck2v10\keen2act.obj+
rck2v10\keendemo.obj+
rck2v10\keenscrn.obj+
rck2v10\idasm.obj+
rck2v10\endscrn.obj+
rck2v10\sounds.obj+
rck2v10\endtext.obj+
rck2v10\helptext.obj+
rck2v10\previews.obj+
rck2v10\storytxt.obj
rck2v10\rck2v10
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck2.obj: rck2v10.cfg tinfck2.c 

keenmain.obj: rck2v10.cfg keenmain.c 

idlibc.obj: rck2v10.cfg idlibc.c 

keen2act.obj: rck2v10.cfg keen2act.c 

keendemo.obj: rck2v10.cfg keendemo.c 

keenscrn.obj: rck2v10.cfg keenscrn.c 

rck2v10\idasm.obj: rck2v10.mak idasm.asm 
	$(TASM) /MX /ZI /O /DOLDKEYBOARD idasm.asm,rck2v10\idasm.obj

#		*Compiler Configuration File*
rck2v10.cfg: rck2v10.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck2v10
-DVERSION=0x0120
-I$(INCLUDEPATH)
-L$(LIBPATH)
-DEPISODE=2
-P-.C
| rck2v10.cfg



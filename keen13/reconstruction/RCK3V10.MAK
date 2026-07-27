.AUTODEPEND

.PATH.obj = rck3v10

#		*Translator Definitions*
CC = tcc +rck3v10.cfg
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
 rck3v10\idasm.obj \
 rck3v10\endscrn.obj \
 rck3v10\sounds.obj \
 rck3v10\helptext.obj \
 rck3v10\endtext.obj \
 rck3v10\previews.obj \
 rck3v10\storytxt.obj

#		*Explicit Rules*
rck3v10\rck3v10.exe: rck3v10.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck3v10\tinfck3.obj+
rck3v10\keenmain.obj+
rck3v10\idlibc.obj+
rck3v10\keen3act.obj+
rck3v10\keendemo.obj+
rck3v10\keenscrn.obj+
rck3v10\idasm.obj+
rck3v10\endscrn.obj+
rck3v10\sounds.obj+
rck3v10\helptext.obj+
rck3v10\endtext.obj+
rck3v10\previews.obj+
rck3v10\storytxt.obj
rck3v10\rck3v10
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfck3.obj: rck3v10.cfg tinfck3.c 

keenmain.obj: rck3v10.cfg keenmain.c 

idlibc.obj: rck3v10.cfg idlibc.c 

keen3act.obj: rck3v10.cfg keen3act.c 

keendemo.obj: rck3v10.cfg keendemo.c 

keenscrn.obj: rck3v10.cfg keenscrn.c 

rck3v10\idasm.obj: rck3v10.mak idasm.asm 
	$(TASM) /MX /ZI /O /DOLDKEYBOARD idasm.asm,rck3v10\idasm.obj

#		*Compiler Configuration File*
rck3v10.cfg: rck3v10.mak
  copy &&|
-f-
-v
-vi-
-weas
-nrck3v10
-DVERSION=0x0120
-I$(INCLUDEPATH)
-L$(LIBPATH)
-DEPISODE=3
-P-.C
| rck3v10.cfg



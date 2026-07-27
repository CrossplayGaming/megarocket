.AUTODEPEND

.PATH.obj = rck1beta

#		*Translator Definitions*
CC = tcc +rck1beta.cfg
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
 tinfk1b.obj \
 keenmain.obj \
 idlibc.obj \
 keen1act.obj \
 keendemo.obj \
 rck1beta\idasm.obj \
 rck1beta\endscrn.obj

#		*Explicit Rules*
rck1beta\rck1beta.exe: rck1beta.cfg $(EXE_dependencies)
  $(TLINK) /x/c @&&|
$(LIBPATH)\c0s.obj+
rck1beta\tinfk1b.obj+
rck1beta\keenmain.obj+
rck1beta\idlibc.obj+
rck1beta\keen1act.obj+
rck1beta\keendemo.obj+
rck1beta\idasm.obj+
rck1beta\endscrn.obj
rck1beta\rck1beta
		# no map file
$(LIBPATH)\cs.lib
|


#		*Individual File Dependencies*
tinfk1b.obj: rck1beta.cfg tinfk1b.c 

keenmain.obj: rck1beta.cfg keenmain.c 

keen1act.obj: rck1beta.cfg keen1act.c 

idlibc.obj: rck1beta.cfg idlibc.c 

keendemo.obj: rck1beta.cfg keendemo.c keenscrn.c 

rck1beta\idasm.obj: rck1beta.mak idasm.asm 
	$(TASM) /MX /ZI /O /DUSELOOPS /DOLDKEYBOARD /DBETA idasm.asm,rck1beta\idasm.obj

#		*Compiler Configuration File*
rck1beta.cfg: rck1beta.mak
  copy &&|
-a
-f-
-v
-G
-O
-Z
-vi-
-weas
-nrck1beta
-DVERSION=0x00B0
-I$(INCLUDEPATH)
-L$(LIBPATH)
-P-.C
| rck1beta.cfg


